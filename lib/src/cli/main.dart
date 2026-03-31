import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:args/args.dart';
import 'package:dart_mcp/stdio.dart';
import '../config/config.dart';
import '../engine/diagnostic.dart';
import '../engine/runner.dart';
import '../lsp/server.dart';
import '../mcp/server.dart';
import '../plugin/plugin.dart';
import '../rules/registry.dart';
import '../type_checker/type_checker_factory.dart';
import '../type_checker/type_diagnostic.dart';

/// CLI exit codes.
class ExitCode {
  /// Normal successful exit.
  static const success = 0;

  /// Lint violations were found.
  static const lintFound = 1;

  /// A usage or runtime error occurred.
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
/// Provide [registry] to also resolve rules from the `linter: rules:`
/// section of analysis_options.yaml.
Future<void> runCli(
  List<String> args, {
  required List<AbstractAnalysisRule> rules,
  RuleFactory? ruleFactory,
  String? pluginName,
  RuleRegistry? registry,
}) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
    ..addFlag('version', negatable: false, help: 'Print version.')
    ..addFlag('lsp', negatable: false, help: 'Run as LSP server.')
    ..addFlag('mcp', negatable: false, help: 'Run as MCP server.')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Show verbose output.')
    ..addFlag('type-check',
        negatable: false, help: 'Enable type checking.')
    ..addFlag('no-lint',
        negatable: false, help: 'Skip lint analysis (use with --type-check).')
    ..addOption('debounce-ms',
        defaultsTo: '500',
        help: 'Debounce interval for LSP type checking (ms).');

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

  final typeCheck = results.flag('type-check');
  final noLint = results.flag('no-lint');

  if (noLint && !typeCheck) {
    stderr.writeln('Error: --no-lint requires --type-check.');
    exit(ExitCode.error);
  }

  // Resolve config from analysis_options.yaml
  final targetDir = Directory(paths.first);
  final workDir = targetDir.existsSync() && FileSystemEntity.isDirectorySync(paths.first)
      ? targetDir
      : Directory.current;
  final config = resolveConfig(workDir, pluginName: pluginName);

  // Filter plugin rules based on config
  final activeRules = config.filterRules(rules);

  // Resolve linter rules from registry if provided
  if (registry != null && config.linterRules.isNotEmpty) {
    activeRules.addAll(registry.resolveEnabled(config.linterRules));
  }

  if (verbose) {
    stderr.writeln('${activeRules.length}/${rules.length} rule(s) active');
    if (config.excludePatterns.isNotEmpty) {
      stderr.writeln('Exclude patterns: ${config.excludePatterns}');
    }
  }

  if (results.flag('mcp')) {
    final server = FastLintMcpServer(
      stdioChannel(input: stdin, output: stdout),
      rules: activeRules,
      ruleFactory: ruleFactory,
      pluginName: pluginName,
      config: config,
    );
    await server.done;
    return;
  }

  if (results.flag('lsp')) {
    final server = FastLintLspServer(
      rules: activeRules,
      pluginName: pluginName,
      typeCheck: typeCheck,
      debounceMs: int.parse(results.option('debounce-ms')!),
    );
    await server.start();
    return;
  }

  final allDiagnostics = <LintDiagnostic>[];

  if (!noLint) {
    final runner = LintRunner(
      rules: activeRules,
      ruleFactory: ruleFactory,
      config: config,
    );

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
  }

  var hasTypeErrors = false;
  if (typeCheck) {
    final checker = await createTypeChecker(projectDir: workDir.path);
    try {
      final dartFiles = <String>[];
      for (final path in paths) {
        final entity = FileSystemEntity.typeSync(path);
        switch (entity) {
          case FileSystemEntityType.file:
            if (path.endsWith('.dart')) dartFiles.add(path);
          case FileSystemEntityType.directory:
            dartFiles.addAll(
              Directory(path)
                  .listSync(recursive: true)
                  .whereType<File>()
                  .where((f) => f.path.endsWith('.dart'))
                  .map((f) => f.path),
            );
          default:
            break;
        }
      }

      if (dartFiles.isNotEmpty) {
        final typeDiagnostics = await checker.check(dartFiles);
        for (final d in typeDiagnostics) {
          print('${d.filePath}:${d.line}:${d.column} - ${d.severity.name} - ${d.message}');
        }
        if (typeDiagnostics.isNotEmpty) {
          stderr.writeln('\n${typeDiagnostics.length} type issue(s) found.');
          hasTypeErrors = true;
        }
      }
    } finally {
      await checker.dispose();
    }
  }

  if (allDiagnostics.isNotEmpty || hasTypeErrors) {
    if (allDiagnostics.isNotEmpty) {
      stderr.writeln('\n${allDiagnostics.length} lint issue(s) found.');
    }
    exit(ExitCode.lintFound);
  }

  if (verbose) {
    stderr.writeln('No issues found.');
  }
}

/// Runs the fast_linter CLI with plugin descriptors.
///
/// Each [PluginDescriptor] bundles a plugin name with a rule factory,
/// enabling automatic config resolution per plugin from
/// `analysis_options.yaml`.
///
/// ```dart
/// import 'package:fast_linter/fast_linter.dart';
/// import 'package:my_lint/fast_linter_plugin.dart' as my_lint;
///
/// void main(List<String> args) {
///   runCliWithPlugins(args, plugins: [my_lint.plugin]);
/// }
/// ```
Future<void> runCliWithPlugins(
  List<String> args, {
  required List<PluginDescriptor> plugins,
  RuleRegistry? registry,
}) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
    ..addFlag('version', negatable: false, help: 'Print version.')
    ..addFlag('lsp', negatable: false, help: 'Run as LSP server.')
    ..addFlag('mcp', negatable: false, help: 'Run as MCP server.')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Show verbose output.')
    ..addFlag('type-check',
        negatable: false, help: 'Enable type checking.')
    ..addFlag('no-lint',
        negatable: false, help: 'Skip lint analysis (use with --type-check).')
    ..addOption('debounce-ms',
        defaultsTo: '500',
        help: 'Debounce interval for LSP type checking (ms).');

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

  final typeCheck = results.flag('type-check');
  final noLint = results.flag('no-lint');

  if (noLint && !typeCheck) {
    stderr.writeln('Error: --no-lint requires --type-check.');
    exit(ExitCode.error);
  }

  // Resolve config from analysis_options.yaml
  final targetDir = Directory(paths.first);
  final workDir =
      targetDir.existsSync() && FileSystemEntity.isDirectorySync(paths.first)
          ? targetDir
          : Directory.current;

  final pluginNames = plugins.map((p) => p.name).toList();
  final allRules = [for (final p in plugins) ...p.createRules()];
  final factories = plugins.map((p) => p.createRules).toList();

  final config = resolveConfigForPlugins(workDir, pluginNames: pluginNames);
  final activeRules = config.filterRules(allRules);

  // Resolve linter rules from registry if provided
  if (registry != null && config.linterRules.isNotEmpty) {
    activeRules.addAll(registry.resolveEnabled(config.linterRules));
  }

  if (verbose) {
    stderr.writeln('${activeRules.length}/${allRules.length} rule(s) active');
    if (config.excludePatterns.isNotEmpty) {
      stderr.writeln('Exclude patterns: ${config.excludePatterns}');
    }
  }

  if (results.flag('mcp')) {
    final server = FastLintMcpServer(
      stdioChannel(input: stdin, output: stdout),
      rules: activeRules,
      pluginNames: pluginNames,
      config: config,
    );
    await server.done;
    return;
  }

  if (results.flag('lsp')) {
    final server = FastLintLspServer(
      rules: activeRules,
      pluginNames: pluginNames,
      typeCheck: typeCheck,
      debounceMs: int.parse(results.option('debounce-ms')!),
    );
    await server.start();
    return;
  }

  final allDiagnostics = <LintDiagnostic>[];

  if (!noLint) {
    final runner = LintRunner(
      rules: activeRules,
      ruleFactories: factories,
      config: config,
    );

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

    _printDiagnostics(allDiagnostics);
  }

  var hasTypeErrors = false;
  if (typeCheck) {
    final checker = await createTypeChecker(projectDir: workDir.path);
    try {
      final dartFiles = <String>[];
      for (final path in paths) {
        final entity = FileSystemEntity.typeSync(path);
        switch (entity) {
          case FileSystemEntityType.file:
            if (path.endsWith('.dart')) dartFiles.add(path);
          case FileSystemEntityType.directory:
            dartFiles.addAll(
              Directory(path)
                  .listSync(recursive: true)
                  .whereType<File>()
                  .where((f) => f.path.endsWith('.dart'))
                  .map((f) => f.path),
            );
          default:
            break;
        }
      }

      if (dartFiles.isNotEmpty) {
        final typeDiagnostics = await checker.check(dartFiles);
        for (final d in typeDiagnostics) {
          print('${d.filePath}:${d.line}:${d.column} - ${d.severity.name} - ${d.message}');
        }
        if (typeDiagnostics.isNotEmpty) {
          stderr.writeln('\n${typeDiagnostics.length} type issue(s) found.');
          hasTypeErrors = true;
        }
      }
    } finally {
      await checker.dispose();
    }
  }

  if (allDiagnostics.isNotEmpty || hasTypeErrors) {
    if (allDiagnostics.isNotEmpty) {
      stderr.writeln('\n${allDiagnostics.length} lint issue(s) found.');
    }
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
