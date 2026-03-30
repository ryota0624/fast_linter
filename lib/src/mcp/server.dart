import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:dart_mcp/server.dart';
import 'package:stream_channel/stream_channel.dart';

import '../config/analysis_options_config.dart';
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

    return result;
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

    // Validate all paths exist first.
    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.notFound) {
        return CallToolResult(
          content: [TextContent(text: 'Path not found: $path')],
          isError: true,
        );
      }
    }

    final runner = LintRunner(
      rules: _rules,
      ruleFactory: _ruleFactory,
      config: _config,
    );

    final allDiagnostics = <LintDiagnostic>[];
    var filesAnalyzed = 0;

    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        final dir = Directory(path);
        final dartFiles = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
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
