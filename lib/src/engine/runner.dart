import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/src/lint/linter_visitor.dart';
import '../compat/error_reporter.dart';
import '../compat/linter_context.dart';
import '../config/analysis_options_config.dart';
import 'diagnostic.dart';
import 'ignore_comments.dart';

/// Factory function that creates rule instances.
///
/// Must be a top-level or static function (not a closure) to work
/// across Isolate boundaries.
typedef RuleFactory = List<AbstractAnalysisRule> Function();

class LintRunner {
  final List<AbstractAnalysisRule> rules;
  final List<RuleFactory>? _ruleFactories;
  final AnalysisOptionsConfig? _config;

  /// Rule names that were skipped because they require type-aware analysis.
  final Set<String> skippedRules = {};

  /// Creates a runner with pre-instantiated [rules].
  ///
  /// For parallel directory scanning, provide [ruleFactory] (single factory)
  /// or [ruleFactories] (multiple factories, e.g. one per plugin).
  /// Provide [config] to apply severity overrides from analysis_options.yaml.
  LintRunner({
    required this.rules,
    RuleFactory? ruleFactory,
    List<RuleFactory>? ruleFactories,
    AnalysisOptionsConfig? config,
  })  : _ruleFactories = ruleFactories ??
            (ruleFactory != null ? [ruleFactory] : null),
        _config = config;

  List<LintDiagnostic> runOnFile(File file) {
    final source = file.readAsStringSync();
    return runOnSource(source, filePath: file.path);
  }

  List<LintDiagnostic> runOnSource(String source, {required String filePath}) {
    final result = _runOnSourceWithRules(source,
        filePath: filePath, rules: rules, config: _config);
    skippedRules.addAll(result.skippedRules);
    return result.diagnostics;
  }

  /// Runs lint rules on all .dart files in [dir].
  ///
  /// If [ruleFactory] was provided, uses Isolate-based parallelism.
  /// Otherwise runs sequentially.
  Future<List<LintDiagnostic>> runOnDirectory(
    Directory dir, {
    int? concurrency,
    List<String> excludePatterns = const [],
  }) async {
    var files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    if (excludePatterns.isNotEmpty) {
      final compiledPatterns =
          excludePatterns.map(_compileGlob).toList(growable: false);
      files = files.where((f) {
        return !compiledPatterns.any((re) => re.hasMatch(f.path));
      }).toList();
    }

    if (_ruleFactories == null || files.length <= 1) {
      return _runSequential(files);
    }

    return _runParallel(files, concurrency: concurrency);
  }

  List<LintDiagnostic> _runSequential(List<File> files) {
    final diagnostics = <LintDiagnostic>[];
    for (final file in files) {
      diagnostics.addAll(runOnFile(file));
    }
    return diagnostics;
  }

  Future<List<LintDiagnostic>> _runParallel(
    List<File> files, {
    int? concurrency,
  }) async {
    final numWorkers = concurrency ?? Platform.numberOfProcessors;
    final chunks = _chunkFiles(files, numWorkers);
    final factories = _ruleFactories!;

    final futures = chunks.map((chunk) {
      final inputs = chunk
          .map((f) => (path: f.path, source: f.readAsStringSync()))
          .toList();
      return Isolate.run(() => _processChunk(inputs, factories));
    });

    final chunkResults = await Future.wait(futures);
    final diagnostics = <LintDiagnostic>[];
    for (final result in chunkResults) {
      diagnostics.addAll(result.diagnostics);
      skippedRules.addAll(result.skippedRules);
    }
    return diagnostics;
  }

  static List<List<File>> _chunkFiles(List<File> files, int numChunks) {
    if (numChunks <= 0) numChunks = 1;
    final chunkSize = (files.length / numChunks).ceil();
    final chunks = <List<File>>[];
    for (var i = 0; i < files.length; i += chunkSize) {
      chunks.add(files.sublist(i, (i + chunkSize).clamp(0, files.length)));
    }
    return chunks;
  }

  static _AnalysisResult _runOnSourceWithRules(
    String source, {
    required String filePath,
    required List<AbstractAnalysisRule> rules,
    AnalysisOptionsConfig? config,
  }) {
    final parseResult = parseString(content: source);
    final unit = parseResult.unit;

    // Parse ignore comments ONCE per file (not per rule).
    final ignoreInfo = IgnoreInfo.parse(source);

    final registry = RuleVisitorRegistryImpl(enableTiming: false);
    final context = FastRuleContext();

    // Set up context ONCE per file (shared across rules).
    final sharedCollector = DiagnosticCollector(
      filePath, source,
      ignoreInfo: ignoreInfo,
    );
    final sharedReporter = sharedCollector.createReporter();
    context.setCurrentUnit(
      filePath: filePath,
      source: source,
      unit: unit,
      reporter: sharedReporter,
    );

    final collectors = <DiagnosticCollector>[];
    final skippedRules = <String>{};
    for (final rule in rules) {
      final severityOverride = config?.severityFor(rule.name);
      final collector = DiagnosticCollector(
        filePath, source,
        severityOverride: severityOverride,
        ignoreInfo: ignoreInfo,
      );
      rule.reporter = collector.createReporter();
      try {
        rule.registerNodeProcessors(registry, context);
        collectors.add(collector);
      } on UnimplementedError {
        skippedRules.add(rule.name);
      }
    }

    // Run all registered visitors over the AST.
    final visitor = AnalysisRuleVisitor(registry);
    unit.accept(visitor);

    return (
      diagnostics: collectors.expand((c) => c.diagnostics).toList(),
      skippedRules: skippedRules,
    );
  }
}

/// Result of running analysis on a source file or chunk.
typedef _AnalysisResult = ({
  List<LintDiagnostic> diagnostics,
  Set<String> skippedRules,
});

/// Isolate entry point: processes a chunk of files with freshly created rules.
_AnalysisResult _processChunk(
  List<({String path, String source})> inputs,
  List<RuleFactory> factories,
) {
  final rules = [for (final f in factories) ...f()];
  final diagnostics = <LintDiagnostic>[];
  final skippedRules = <String>{};
  for (final input in inputs) {
    final result = LintRunner._runOnSourceWithRules(
      input.source,
      filePath: input.path,
      rules: rules,
    );
    diagnostics.addAll(result.diagnostics);
    skippedRules.addAll(result.skippedRules);
  }
  return (diagnostics: diagnostics, skippedRules: skippedRules);
}

/// Pre-compiles a glob pattern to a [RegExp].
RegExp _compileGlob(String pattern) {
  final buf = StringBuffer('^');
  for (var i = 0; i < pattern.length; i++) {
    final c = pattern[i];
    if (c == '*') {
      if (i + 1 < pattern.length && pattern[i + 1] == '*') {
        buf.write('.*');
        i++;
        if (i + 1 < pattern.length && pattern[i + 1] == '/') {
          i++;
        }
      } else {
        buf.write('[^/]*');
      }
    } else if (c == '?') {
      buf.write('[^/]');
    } else if (c == '.') {
      buf.write(r'\.');
    } else {
      buf.write(c);
    }
  }
  buf.write(r'$');
  return RegExp(buf.toString());
}
