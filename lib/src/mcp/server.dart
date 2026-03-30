import 'dart:async';
import 'dart:convert';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:dart_mcp/server.dart';
import 'package:stream_channel/stream_channel.dart';

import '../config/analysis_options_config.dart';
import '../engine/runner.dart' show RuleFactory;

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

    return result;
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
