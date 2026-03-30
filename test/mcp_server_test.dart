import 'dart:async';
import 'dart:convert';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/server.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'helpers/test_rules.dart';
import '../lib/src/mcp/server.dart';

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

  _TestEnv({required List<AbstractAnalysisRule> rules}) : client = _TestMCPClient() {
    server = FastLintMcpServer(serverChannel, rules: rules);
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
  });
}
