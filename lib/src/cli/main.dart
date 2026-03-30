import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:args/args.dart';
import '../config/analysis_options_config.dart';
import '../config/config.dart';
import '../engine/diagnostic.dart';
import '../engine/runner.dart';
import '../lsp/server.dart';

/// CLI exit codes.
class ExitCode {
  static const success = 0;
  static const lintFound = 1;
  static const error = 2;
}

/// Runs the fast_linter CLI with the given [rules].
///
/// Provide [pluginName] to enable reading rule configuration from
/// `analysis_options.yaml` (e.g., `analyzer: plugins: <pluginName>: diagnostics:`).
///
/// Provide [ruleFactory] (a top-level function) to enable Isolate-based
/// parallel analysis for directories.
///
/// ```dart
/// List<AbstractAnalysisRule> createRules() => [MyRule(), AnotherRule()];
///
/// void main(List<String> args) {
///   runCli(args,
///     rules: createRules(),
///     ruleFactory: createRules,
///     pluginName: 'my_lint',
///   );
/// }
/// ```
Future<void> runCli(
  List<String> args, {
  required List<AbstractAnalysisRule> rules,
  RuleFactory? ruleFactory,
  String? pluginName,
}) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
    ..addFlag('version', negatable: false, help: 'Print version.')
    ..addFlag('lsp', negatable: false, help: 'Run as LSP server.')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Show verbose output.');

  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln();
    _printUsage(parser);
    exit(ExitCode.error);
  }

  if (results.flag('help')) {
    _printUsage(parser);
    return;
  }

  if (results.flag('version')) {
    print('fast_linter 0.0.1');
    return;
  }

  final verbose = results.flag('verbose');
  final paths = results.rest;

  if (paths.isEmpty) {
    paths.add('.');
  }

  // Resolve config from fast_lint.yaml or analysis_options.yaml
  final targetDir = Directory(paths.first);
  final workDir = targetDir.existsSync() && FileSystemEntity.isDirectorySync(paths.first)
      ? targetDir
      : Directory.current;
  final config = resolveConfig(workDir, pluginName: pluginName);

  // Filter rules based on config
  final activeRules = config.filterRules(rules);

  if (verbose) {
    stderr.writeln('${activeRules.length}/${rules.length} rule(s) active');
    if (config.excludePatterns.isNotEmpty) {
      stderr.writeln('Exclude patterns: ${config.excludePatterns}');
    }
  }

  if (results.flag('lsp')) {
    final server = FastLintLspServer(
      rules: activeRules,
      pluginName: pluginName,
    );
    await server.start();
    return;
  }

  final runner = LintRunner(
    rules: activeRules,
    ruleFactory: ruleFactory,
    config: config,
  );
  final allDiagnostics = <LintDiagnostic>[];

  for (final path in paths) {
    final entity = FileSystemEntity.typeSync(path);
    switch (entity) {
      case FileSystemEntityType.file:
        allDiagnostics.addAll(runner.runOnFile(File(path)));
      case FileSystemEntityType.directory:
        allDiagnostics.addAll(await runner.runOnDirectory(
          Directory(path),
          excludePatterns: config.excludePatterns,
        ));
      default:
        stderr.writeln('Not found: $path');
        exit(ExitCode.error);
    }
  }

  if (runner.skippedRules.isNotEmpty) {
    final names = runner.skippedRules.toList()..sort();
    stderr.writeln(
      '[fast_linter] Skipped ${names.length} rule(s) requiring '
      'type-aware analysis: ${names.join(', ')}',
    );
  }

  _printDiagnostics(allDiagnostics);

  if (allDiagnostics.isNotEmpty) {
    stderr.writeln('\n${allDiagnostics.length} issue(s) found.');
    exit(ExitCode.lintFound);
  }

  if (verbose) {
    stderr.writeln('No issues found.');
  }
}

void _printUsage(ArgParser parser) {
  stderr.writeln('Usage: fast_linter [options] [paths...]');
  stderr.writeln();
  stderr.writeln(parser.usage);
}

void _printDiagnostics(List<LintDiagnostic> diagnostics) {
  for (final d in diagnostics) {
    print('${d.filePath}:${d.line}:${d.column} - ${d.severity.name} - ${d.code} - ${d.message}');
  }
}
