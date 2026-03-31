import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:dart_mcp/server.dart';
import 'package:stream_channel/stream_channel.dart';

import '../config/analysis_options_config.dart';
import '../config/config.dart';
import '../engine/diagnostic.dart';
import '../engine/runner.dart';

/// MCP server for fast_linter.
///
/// Exposes lint rules and analysis capabilities via the Model Context Protocol.
final class FastLintMcpServer extends MCPServer with ToolsSupport {
  final List<AbstractAnalysisRule> _rules;
  final RuleFactory? _ruleFactory;
  final String? _pluginName;
  final List<String>? _pluginNames;
  final AnalysisOptionsConfig _config;

  /// Creates a new MCP server with the given lint [rules].
  FastLintMcpServer(
    StreamChannel<String> channel, {
    required List<AbstractAnalysisRule> rules,
    RuleFactory? ruleFactory,
    String? pluginName,
    List<String>? pluginNames,
    AnalysisOptionsConfig? config,
  })  : _rules = rules,
        _ruleFactory = ruleFactory,
        _pluginName = pluginName,
        _pluginNames = pluginNames,
        _config = config ?? AnalysisOptionsConfig.empty,
        super.fromStreamChannel(
          channel,
          implementation: Implementation(
            name: 'fast_linter',
            version: '0.0.1',
          ),
          instructions:
              'A fast AST-only Dart linter. Use list_rules to see available lint rules.',
        );

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);

    registerTool(
      Tool(
        name: 'list_rules',
        description: 'List all available lint rules.',
        inputSchema: ObjectSchema(),
        annotations: ToolAnnotations(readOnlyHint: true),
      ),
      _handleListRules,
    );

    registerTool(
      Tool(
        name: 'analyze_files',
        description:
            'Analyze Dart files or directories and return lint diagnostics.',
        inputSchema: ObjectSchema(
          properties: {
            'paths': ListSchema(
              description: 'File or directory paths to analyze.',
              items: StringSchema(),
            ),
            'severity_filter': StringSchema(
              description:
                  'Filter diagnostics at this severity or above (info < warning < error).',
              enumValues: ['info', 'warning', 'error'],
            ),
          },
          required: ['paths'],
        ),
        annotations: ToolAnnotations(readOnlyHint: true),
      ),
      _handleAnalyzeFiles,
    );

    registerTool(
      Tool(
        name: 'get_config',
        description: 'Return the current linter configuration.',
        inputSchema: ObjectSchema(
          properties: {
            'directory': StringSchema(
              description:
                  'Directory to search for analysis_options.yaml. '
                  'If omitted, returns the server\'s stored config.',
            ),
          },
        ),
        annotations: ToolAnnotations(readOnlyHint: true),
      ),
      _handleGetConfig,
    );

    return result;
  }

  CallToolResult _handleGetConfig(CallToolRequest request) {
    final args = request.arguments;
    final directory = args?['directory'] as String?;

    AnalysisOptionsConfig config;
    if (directory != null) {
      final dir = Directory(directory);
      if (!dir.existsSync()) {
        return CallToolResult(
          content: [TextContent(text: 'Directory not found: $directory')],
          isError: true,
        );
      }
      if (_pluginNames != null && _pluginNames.isNotEmpty) {
        config = resolveConfigForPlugins(dir, pluginNames: _pluginNames);
      } else {
        config = resolveConfig(dir, pluginName: _pluginName);
      }
    } else {
      config = _config;
    }

    final result = {
      'rule_overrides': {
        for (final entry in config.ruleOverrides.entries)
          entry.key: {
            'enabled': entry.value.enabled,
            'severity': entry.value.severity?.name,
          },
      },
      'exclude_patterns': config.excludePatterns,
      'linter_rules': {
        for (final entry in config.linterRules.entries)
          entry.key: {
            'enabled': entry.value.enabled,
            'severity': entry.value.severity?.name,
          },
      },
    };

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result))],
    );
  }

  Future<CallToolResult> _handleAnalyzeFiles(CallToolRequest request) async {
    final args = request.arguments;
    final paths = (args?['paths'] as List?)?.cast<String>() ?? [];
    final severityFilterName = args?['severity_filter'] as String?;

    // Parse severity filter.
    LintSeverity? minSeverity;
    if (severityFilterName != null) {
      minSeverity = LintSeverity.values.asNameMap()[severityFilterName];
    }

    // Validate all paths and record their types.
    final pathTypes = <String, FileSystemEntityType>{};
    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.notFound) {
        return CallToolResult(
          content: [TextContent(text: 'Path not found: $path')],
          isError: true,
        );
      }
      pathTypes[path] = type;
    }

    final runner = LintRunner(
      rules: _rules,
      ruleFactory: _ruleFactory,
      config: _config,
    );

    final allDiagnostics = <LintDiagnostic>[];
    var filesAnalyzed = 0;

    for (final path in paths) {
      if (pathTypes[path] == FileSystemEntityType.directory) {
        final dir = Directory(path);
        var dartFiles = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
        if (_config.excludePatterns.isNotEmpty) {
          final compiledPatterns = _config.excludePatterns
              .map(compileGlob)
              .toList(growable: false);
          dartFiles = dartFiles
              .where((f) => !compiledPatterns.any((re) => re.hasMatch(f.path)))
              .toList();
        }
        filesAnalyzed += dartFiles.length;
        final diagnostics = await runner.runOnDirectory(
          dir,
          excludePatterns: _config.excludePatterns,
        );
        allDiagnostics.addAll(diagnostics);
      } else {
        filesAnalyzed++;
        allDiagnostics.addAll(runner.runOnFile(File(path)));
      }
    }

    // Apply severity filter.
    final filtered = minSeverity != null
        ? allDiagnostics
            .where((d) => d.severity.index >= minSeverity!.index)
            .toList()
        : allDiagnostics;

    // Build severity counts.
    final bySeverity = <String, int>{
      'info': 0,
      'warning': 0,
      'error': 0,
    };
    for (final d in filtered) {
      bySeverity[d.severity.name] = (bySeverity[d.severity.name] ?? 0) + 1;
    }

    final result = {
      'diagnostics': filtered
          .map((d) => {
                'file': d.filePath,
                'line': d.line,
                'column': d.column,
                'severity': d.severity.name,
                'code': d.code,
                'message': d.message,
              })
          .toList(),
      'skipped_rules': runner.skippedRules.toList()..sort(),
      'summary': {
        'files_analyzed': filesAnalyzed,
        'total_diagnostics': filtered.length,
        'by_severity': bySeverity,
      },
    };

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result))],
    );
  }

  CallToolResult _handleListRules(CallToolRequest request) {
    final rulesJson = _rules.map((rule) {
      final override = _config.ruleOverrides[rule.name];
      final enabled = override == null || override.enabled;
      final severity = _config.severityFor(rule.name)?.name;
      return {
        'name': rule.name,
        'enabled': enabled,
        'severity': severity,
      };
    }).toList();

    return CallToolResult(
      content: [
        TextContent(
          text: jsonEncode({
            'rules': rulesJson,
            'total': rulesJson.length,
          }),
        ),
      ],
    );
  }
}
