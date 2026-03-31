import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import '../config/config.dart';
import '../engine/runner.dart';

/// A minimal LSP server for fast_linter.
///
/// Supports:
/// - `initialize` / `initialized`
/// - `textDocument/didOpen`
/// - `textDocument/didChange`
/// - `textDocument/didClose`
/// - `shutdown` / `exit`
///
/// Publishes diagnostics via `textDocument/publishDiagnostics`.
class FastLintLspServer {
  final List<AbstractAnalysisRule> _allRules;
  final List<String> _pluginNames;
  late LintRunner _runner;
  final Map<String, String> _openDocuments = {};
  final Set<String> _reportedSkippedRules = {};

  late final IOSink _output;
  bool _shutdownRequested = false;

  FastLintLspServer({
    required List<AbstractAnalysisRule> rules,
    String? pluginName,
    List<String>? pluginNames,
  })  : _allRules = rules,
        _pluginNames = pluginNames ??
            (pluginName != null ? [pluginName] : const []) {
    _runner = LintRunner(rules: _allRules);
  }

  /// Starts the server, listening on stdin and writing to stdout.
  Future<void> start() async {
    _output = stdout;
    await _processInput(stdin);
  }

  /// Processes LSP messages from an input stream.
  /// Exposed for testing.
  Future<void> processStream(Stream<List<int>> input, IOSink output) async {
    _output = output;
    await _processInput(input);
  }

  Future<void> _processInput(Stream<List<int>> input) async {
    final buffer = StringBuffer();
    int? contentLength;

    await for (final chunk in input.transform(utf8.decoder)) {
      buffer.write(chunk);

      while (true) {
        final data = buffer.toString();

        if (contentLength == null) {
          final headerEnd = data.indexOf('\r\n\r\n');
          if (headerEnd == -1) break;

          final headers = data.substring(0, headerEnd);
          final match =
              RegExp(r'Content-Length:\s*(\d+)').firstMatch(headers);
          if (match == null) {
            buffer.clear();
            break;
          }
          contentLength = int.parse(match.group(1)!);

          buffer.clear();
          buffer.write(data.substring(headerEnd + 4));
        }

        final cl = contentLength;
        final current = buffer.toString();
        if (current.length < cl) break;

        final body = current.substring(0, cl);
        buffer.clear();
        buffer.write(current.substring(cl));
        contentLength = null;

        final message = jsonDecode(body) as Map<String, dynamic>;
        await _handleMessage(message);
      }
    }
  }

  Future<void> _handleMessage(Map<String, dynamic> message) async {
    final method = message['method'] as String?;
    final id = message['id'];
    final params = message['params'] as Map<String, dynamic>?;

    switch (method) {
      case 'initialize':
        // Load config from workspace root if available
        final rootUri = params?['rootUri'] as String?;
        if (rootUri != null) {
          _loadConfig(rootUri);
        }

        _sendResponse(id, {
          'capabilities': {
            'textDocumentSync': {
              'openClose': true,
              'change': 1, // Full sync
            },
          },
          'serverInfo': {
            'name': 'fast_linter',
            'version': '0.0.1',
          },
        });

      case 'initialized':
        break;

      case 'textDocument/didOpen':
        final textDocument = params!['textDocument'] as Map<String, dynamic>;
        final uri = textDocument['uri'] as String;
        final text = textDocument['text'] as String;
        _openDocuments[uri] = text;
        _publishDiagnostics(uri, text);

      case 'textDocument/didChange':
        final textDocument =
            params!['textDocument'] as Map<String, dynamic>;
        final uri = textDocument['uri'] as String;
        final changes = params['contentChanges'] as List<dynamic>;
        final text = (changes.last as Map<String, dynamic>)['text'] as String;
        _openDocuments[uri] = text;
        _publishDiagnostics(uri, text);

      case 'textDocument/didClose':
        final textDocument = params!['textDocument'] as Map<String, dynamic>;
        final uri = textDocument['uri'] as String;
        _openDocuments.remove(uri);
        _sendNotification('textDocument/publishDiagnostics', {
          'uri': uri,
          'diagnostics': [],
        });

      case 'shutdown':
        _shutdownRequested = true;
        _sendResponse(id, null);

      case 'exit':
        exit(_shutdownRequested ? 0 : 1);
    }
  }

  void _loadConfig(String rootUri) {
    final rootPath = Uri.parse(rootUri).toFilePath();
    final config = _pluginNames.isNotEmpty
        ? resolveConfigForPlugins(
            Directory(rootPath),
            pluginNames: _pluginNames,
          )
        : resolveConfig(Directory(rootPath));
    final activeRules = config.filterRules(_allRules);
    _runner = LintRunner(rules: activeRules, config: config);
  }

  void _publishDiagnostics(String uri, String text) {
    final filePath = _uriToPath(uri);
    final diagnostics = _runner.runOnSource(text, filePath: filePath);

    final lspDiagnostics = diagnostics.map((d) {
      return {
        'range': {
          'start': {'line': d.line - 1, 'character': d.column - 1},
          'end': {'line': d.line - 1, 'character': d.column - 1 + d.length},
        },
        'severity': d.severity.lspValue,
        'code': d.code,
        'source': 'fast_linter',
        'message': d.message,
      };
    }).toList();

    _sendNotification('textDocument/publishDiagnostics', {
      'uri': uri,
      'diagnostics': lspDiagnostics,
    });

    // Report newly discovered skipped rules via window/logMessage.
    final newSkipped = _runner.skippedRules.difference(_reportedSkippedRules);
    if (newSkipped.isNotEmpty) {
      _reportedSkippedRules.addAll(newSkipped);
      final names = newSkipped.toList()..sort();
      _sendNotification('window/logMessage', {
        'type': 2, // Warning
        'message': '[fast_linter] Skipped ${names.length} rule(s) requiring '
            'type-aware analysis: ${names.join(', ')}',
      });
    }
  }

  void _sendResponse(dynamic id, dynamic result) {
    _send({
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    });
  }

  void _sendNotification(String method, Map<String, dynamic> params) {
    _send({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });
  }

  void _send(Map<String, dynamic> message) {
    final body = jsonEncode(message);
    final bytes = utf8.encode(body);
    _output.write('Content-Length: ${bytes.length}\r\n\r\n');
    _output.write(body);
  }

  String _uriToPath(String uri) {
    if (uri.startsWith('file://')) {
      return Uri.parse(uri).toFilePath();
    }
    return uri;
  }
}
