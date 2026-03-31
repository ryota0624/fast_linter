import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:dart_mcp/client.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'helpers/test_rules.dart';
import 'package:fast_linter/src/mcp/server.dart';

/// Minimal test client.
base class _TestMCPClient extends MCPClient {
  _TestMCPClient()
      : super(Implementation(name: 'test_client', version: '0.1.0'));
}

/// Helper to set up a connected client/server pair for testing.
class _TestEnv {
  final clientController = StreamController<String>();
  final serverController = StreamController<String>();

  late final clientChannel = StreamChannel<String>.withCloseGuarantee(
    serverController.stream,
    clientController.sink,
  );
  late final serverChannel = StreamChannel<String>.withCloseGuarantee(
    clientController.stream,
    serverController.sink,
  );

  final _TestMCPClient client;
  late final FastLintMcpServer server;
  late final ServerConnection serverConnection;

  _TestEnv({
    required List<AbstractAnalysisRule> rules,
    String? pluginName,
    List<String>? pluginNames,
  }) : client = _TestMCPClient() {
    server = FastLintMcpServer(
      serverChannel,
      rules: rules,
      pluginName: pluginName,
      pluginNames: pluginNames,
    );
    serverConnection = client.connectServer(clientChannel);
  }

  Future<InitializeResult> initialize() async {
    final result = await serverConnection.initialize(
      InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: client.capabilities,
        clientInfo: client.implementation,
      ),
    );
    if (result.protocolVersion?.isSupported == true) {
      serverConnection.notifyInitialized(InitializedNotification());
      await server.initialized;
    }
    return result;
  }

  Future<void> shutdown() async {
    await client.shutdown();
    await server.shutdown();
  }
}

void main() {
  group('FastLintMcpServer', () {
    late _TestEnv env;

    tearDown(() async {
      await env.shutdown();
    });

    test('initialization reports tools capability', () async {
      env = _TestEnv(rules: []);
      final result = await env.initialize();

      expect(result.capabilities.tools, isNotNull);
    });

    group('list_rules tool', () {
      test('returns empty list when no rules are provided', () async {
        env = _TestEnv(rules: []);
        await env.initialize();

        final toolsResult = await env.serverConnection.listTools();
        expect(
          toolsResult.tools.map((t) => t.name),
          contains('list_rules'),
        );

        final callResult = await env.serverConnection.callTool(
          CallToolRequest(name: 'list_rules'),
        );

        expect(callResult.isError, isNot(true));
        final content = callResult.content;
        expect(content, hasLength(1));
        expect(content.first.isText, isTrue);

        final text = TextContent.fromMap(
          content.first as Map<String, Object?>,
        ).text;
        final json = jsonDecode(text) as Map<String, dynamic>;
        expect(json['rules'], isEmpty);
        expect(json['total'], 0);
      });

      test('returns rule information when rules are provided', () async {
        env = _TestEnv(rules: [AvoidOptionalPositionalParameters()]);
        await env.initialize();

        final callResult = await env.serverConnection.callTool(
          CallToolRequest(name: 'list_rules'),
        );

        expect(callResult.isError, isNot(true));
        final text = TextContent.fromMap(
          callResult.content.first as Map<String, Object?>,
        ).text;
        final json = jsonDecode(text) as Map<String, dynamic>;
        final rules = json['rules'] as List;
        expect(rules, hasLength(1));
        expect(rules[0]['name'], 'avoid_optional_positional_parameters');
        expect(rules[0]['enabled'], true);
        expect(rules[0]['severity'], isNull);
        expect(json['total'], 1);
      });
    });

    group('get_config', () {
      test('returns current configuration', () async {
        env = _TestEnv(rules: []);
        await env.initialize();

        final callResult = await env.serverConnection.callTool(
          CallToolRequest(name: 'get_config'),
        );

        expect(callResult.isError, isNot(true));
        final text = TextContent.fromMap(
          callResult.content.first as Map<String, Object?>,
        ).text;
        final json = jsonDecode(text) as Map<String, dynamic>;
        expect(json['rule_overrides'], isA<Map>());
        expect(json['exclude_patterns'], isA<List>());
        expect(json['linter_rules'], isA<Map>());
        // Empty config should have empty collections.
        expect(json['rule_overrides'], isEmpty);
        expect(json['exclude_patterns'], isEmpty);
        expect(json['linter_rules'], isEmpty);
      });

      test('with directory resolves config from that directory', () async {
        final tempDir = Directory.systemTemp.createTempSync('mcp_config_test_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        // Write an analysis_options.yaml with exclude patterns and a plugin config.
        final optionsFile = File('${tempDir.path}/analysis_options.yaml');
        optionsFile.writeAsStringSync('''
analyzer:
  exclude:
    - "**/*.g.dart"
    - "build/**"
  plugins:
    test_plugin:
      diagnostics:
        some_rule: error
''');

        env = _TestEnv(rules: [], pluginName: 'test_plugin');
        await env.initialize();

        final callResult = await env.serverConnection.callTool(
          CallToolRequest(
            name: 'get_config',
            arguments: {'directory': tempDir.path},
          ),
        );

        expect(callResult.isError, isNot(true));
        final text = TextContent.fromMap(
          callResult.content.first as Map<String, Object?>,
        ).text;
        final json = jsonDecode(text) as Map<String, dynamic>;
        final excludes = json['exclude_patterns'] as List;
        expect(excludes, contains('**/*.g.dart'));
        expect(excludes, contains('build/**'));
        final overrides = json['rule_overrides'] as Map<String, dynamic>;
        expect(overrides, containsPair('some_rule', {
          'enabled': true,
          'severity': 'error',
        }));
      });

      test('returns error for non-existent directory', () async {
        env = _TestEnv(rules: []);
        await env.initialize();

        final callResult = await env.serverConnection.callTool(
          CallToolRequest(
            name: 'get_config',
            arguments: {'directory': '/non/existent/directory'},
          ),
        );

        expect(callResult.isError, isTrue);
      });
    });

    group('analyze_files', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('mcp_test_');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('analyzes a single file and returns diagnostics', () async {
        env = _TestEnv(rules: [AvoidOptionalPositionalParameters()]);
        await env.initialize();

        final file = File('${tempDir.path}/test.dart');
        file.writeAsStringSync('void foo([int x = 0]) {}\n');

        final callResult = await env.serverConnection.callTool(
          CallToolRequest(
            name: 'analyze_files',
            arguments: {'paths': [file.path]},
          ),
        );

        expect(callResult.isError, isNot(true));
        final text = TextContent.fromMap(
          callResult.content.first as Map<String, Object?>,
        ).text;
        final json = jsonDecode(text) as Map<String, dynamic>;

        final diagnostics = json['diagnostics'] as List;
        expect(diagnostics, isNotEmpty);
        final diag = diagnostics.first as Map<String, dynamic>;
        expect(diag['file'], file.path);
        expect(diag['line'], isA<int>());
        expect(diag['column'], isA<int>());
        expect(diag['severity'], 'warning');
        expect(diag['code'], 'avoid_optional_positional_parameters');
        expect(diag['message'], isA<String>());

        final summary = json['summary'] as Map<String, dynamic>;
        expect(summary['files_analyzed'], 1);
        expect(summary['total_diagnostics'], diagnostics.length);
        final bySeverity = summary['by_severity'] as Map<String, dynamic>;
        expect(bySeverity['warning'], greaterThan(0));
      });

      test('analyzes a directory recursively', () async {
        env = _TestEnv(rules: [AvoidOptionalPositionalParameters()]);
        await env.initialize();

        final file1 = File('${tempDir.path}/a.dart');
        file1.writeAsStringSync('void foo([int x = 0]) {}\n');
        final subDir = Directory('${tempDir.path}/sub');
        subDir.createSync();
        final file2 = File('${subDir.path}/b.dart');
        file2.writeAsStringSync('void bar([String s = ""]) {}\n');

        final callResult = await env.serverConnection.callTool(
          CallToolRequest(
            name: 'analyze_files',
            arguments: {'paths': [tempDir.path]},
          ),
        );

        expect(callResult.isError, isNot(true));
        final text = TextContent.fromMap(
          callResult.content.first as Map<String, Object?>,
        ).text;
        final json = jsonDecode(text) as Map<String, dynamic>;
        final summary = json['summary'] as Map<String, dynamic>;
        expect(summary['files_analyzed'], 2);
        expect(summary['total_diagnostics'], greaterThanOrEqualTo(2));
      });

      test('filters by severity', () async {
        env = _TestEnv(rules: [AvoidOptionalPositionalParameters()]);
        await env.initialize();

        final file = File('${tempDir.path}/test.dart');
        file.writeAsStringSync('void foo([int x = 0]) {}\n');

        final callResult = await env.serverConnection.callTool(
          CallToolRequest(
            name: 'analyze_files',
            arguments: {
              'paths': [file.path],
              'severity_filter': 'error',
            },
          ),
        );

        expect(callResult.isError, isNot(true));
        final text = TextContent.fromMap(
          callResult.content.first as Map<String, Object?>,
        ).text;
        final json = jsonDecode(text) as Map<String, dynamic>;
        final diagnostics = json['diagnostics'] as List;
        expect(diagnostics, isEmpty);
        final summary = json['summary'] as Map<String, dynamic>;
        expect(summary['total_diagnostics'], 0);
      });

      test('includes skipped_rules for type-aware rules', () async {
        env = _TestEnv(rules: [
          AvoidOptionalPositionalParameters(),
          TypeAwareTestRule(),
        ]);
        await env.initialize();

        final file = File('${tempDir.path}/test.dart');
        file.writeAsStringSync('void foo([int x = 0]) {}\n');

        final callResult = await env.serverConnection.callTool(
          CallToolRequest(
            name: 'analyze_files',
            arguments: {'paths': [file.path]},
          ),
        );

        expect(callResult.isError, isNot(true));
        final text = TextContent.fromMap(
          callResult.content.first as Map<String, Object?>,
        ).text;
        final json = jsonDecode(text) as Map<String, dynamic>;

        final skippedRules = json['skipped_rules'] as List;
        expect(skippedRules, contains('type_aware_test_rule'));
        expect(skippedRules, isNot(contains('avoid_optional_positional_parameters')));

        // Normal rule should still produce diagnostics.
        final diagnostics = json['diagnostics'] as List;
        expect(diagnostics, isNotEmpty);
      });

      test('returns error for non-existent path', () async {
        env = _TestEnv(rules: [AvoidOptionalPositionalParameters()]);
        await env.initialize();

        final callResult = await env.serverConnection.callTool(
          CallToolRequest(
            name: 'analyze_files',
            arguments: {'paths': ['/non/existent/path.dart']},
          ),
        );

        expect(callResult.isError, isTrue);
      });
    });
  });
}
