import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity, LintCode;
import 'package:fast_linter/src/lsp/server.dart';
import 'package:test/test.dart';

/// Simple test rule for LSP testing.
class _TestRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'test_rule',
    'Test violation found',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  _TestRule()
      : super(name: 'test_rule', description: 'Test rule');

  @override
  void registerNodeProcessors(
      RuleVisitorRegistry registry, RuleContext context) {
    registry.addFunctionDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final _TestRule rule;
  _Visitor(this.rule);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Report on every function declaration
    rule.reportAtNode(node);
  }
}

/// Helper to create an LSP message with Content-Length header.
List<int> _lspMessage(Map<String, dynamic> json) {
  final body = jsonEncode(json);
  final bytes = utf8.encode(body);
  final header = 'Content-Length: ${bytes.length}\r\n\r\n';
  return utf8.encode('$header$body');
}

/// Helper to parse LSP responses from output.
List<Map<String, dynamic>> _parseLspOutput(String output) {
  final messages = <Map<String, dynamic>>[];
  var remaining = output;

  while (remaining.isNotEmpty) {
    final headerEnd = remaining.indexOf('\r\n\r\n');
    if (headerEnd == -1) break;

    final headers = remaining.substring(0, headerEnd);
    final match = RegExp(r'Content-Length:\s*(\d+)').firstMatch(headers);
    if (match == null) break;

    final length = int.parse(match.group(1)!);
    final bodyStart = headerEnd + 4;
    if (bodyStart + length > remaining.length) break;

    final body = remaining.substring(bodyStart, bodyStart + length);
    messages.add(jsonDecode(body) as Map<String, dynamic>);
    remaining = remaining.substring(bodyStart + length);
  }

  return messages;
}

void main() {
  group('FastLintLspServer', () {
    late FastLintLspServer server;

    setUp(() {
      server = FastLintLspServer(rules: [_TestRule()]);
    });

    test('responds to initialize', () async {
      final input = StreamController<List<int>>();
      final output = _TestSink();

      final serverFuture = server.processStream(input.stream, output);

      // Send initialize
      input.add(_lspMessage({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'capabilities': {},
        },
      }));

      // Give server time to process
      await Future.delayed(Duration(milliseconds: 50));

      final messages = _parseLspOutput(output.content);
      expect(messages, hasLength(1));
      expect(messages.first['id'], 1);
      expect(messages.first['result']['capabilities'], isNotNull);
      expect(
        messages.first['result']['serverInfo']['name'],
        'fast_linter',
      );

      await input.close();
      await serverFuture;
    });

    test('publishes diagnostics on didOpen', () async {
      final input = StreamController<List<int>>();
      final output = _TestSink();

      final serverFuture = server.processStream(input.stream, output);

      // Send initialize
      input.add(_lspMessage({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'capabilities': {}},
      }));

      // Send didOpen with a function declaration (triggers test rule)
      input.add(_lspMessage({
        'jsonrpc': '2.0',
        'method': 'textDocument/didOpen',
        'params': {
          'textDocument': {
            'uri': 'file:///test.dart',
            'languageId': 'dart',
            'version': 1,
            'text': 'void main() {}\n',
          },
        },
      }));

      await Future.delayed(Duration(milliseconds: 50));

      final messages = _parseLspOutput(output.content);
      // Should have: initialize response + publishDiagnostics notification
      expect(messages.length, greaterThanOrEqualTo(2));

      final diagNotification = messages.firstWhere(
        (m) => m['method'] == 'textDocument/publishDiagnostics',
      );
      final diags = (diagNotification['params']['diagnostics'] as List);
      expect(diags, hasLength(1));
      expect(diags.first['code'], 'test_rule');
      expect(diags.first['source'], 'fast_linter');

      await input.close();
      await serverFuture;
    });

    test('clears diagnostics on didClose', () async {
      final input = StreamController<List<int>>();
      final output = _TestSink();

      final serverFuture = server.processStream(input.stream, output);

      // Open a document
      input.add(_lspMessage({
        'jsonrpc': '2.0',
        'method': 'textDocument/didOpen',
        'params': {
          'textDocument': {
            'uri': 'file:///test.dart',
            'languageId': 'dart',
            'version': 1,
            'text': 'void main() {}\n',
          },
        },
      }));

      await Future.delayed(Duration(milliseconds: 50));

      // Close the document
      input.add(_lspMessage({
        'jsonrpc': '2.0',
        'method': 'textDocument/didClose',
        'params': {
          'textDocument': {'uri': 'file:///test.dart'},
        },
      }));

      await Future.delayed(Duration(milliseconds: 50));

      final messages = _parseLspOutput(output.content);
      final closeNotification = messages.lastWhere(
        (m) => m['method'] == 'textDocument/publishDiagnostics',
      );
      expect(closeNotification['params']['diagnostics'], isEmpty);

      await input.close();
      await serverFuture;
    });
  });
}

/// A simple IOSink that collects output as a string.
class _TestSink implements IOSink {
  final _buffer = StringBuffer();

  String get content => _buffer.toString();

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _buffer.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  void add(List<int> data) => _buffer.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future flush() async {}

  @override
  Future close() async {}

  @override
  Future get done => Future.value();

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}
}
