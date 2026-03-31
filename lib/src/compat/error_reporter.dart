import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/listener.dart';
// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';
import '../config/analysis_options_config.dart';
import '../engine/diagnostic.dart';
import '../engine/ignore_comments.dart';

/// [DiagnosticListener] implementation that collects diagnostics as
/// [LintDiagnostic]s.
/// [DiagnosticListener] that collects diagnostics as [LintDiagnostic]s.
class DiagnosticCollector implements DiagnosticListener {
  /// The file path associated with collected diagnostics.
  final String filePath;
  final String _source;
  final LintSeverity? _severityOverride;
  final IgnoreInfo _ignoreInfo;
  final List<LintDiagnostic> _diagnostics = [];

  /// Creates a collector for the given [filePath] and source code.
  DiagnosticCollector(this.filePath, this._source,
      {LintSeverity? severityOverride, IgnoreInfo? ignoreInfo})
      : _severityOverride = severityOverride,
        _ignoreInfo = ignoreInfo ?? IgnoreInfo.parse(_source);

  /// The collected diagnostics (unmodifiable).
  List<LintDiagnostic> get diagnostics => List.unmodifiable(_diagnostics);

  @override
  void onDiagnostic(Diagnostic diagnostic) {
    final loc = computeLineColumn(_source, diagnostic.offset);
    final code = diagnostic.diagnosticCode.name;

    // Respect // ignore: and // ignore_for_file: comments
    if (_ignoreInfo.isIgnored(code, loc.line)) return;

    _diagnostics.add(LintDiagnostic(
      filePath: filePath,
      code: code,
      message: diagnostic.message,
      offset: diagnostic.offset,
      length: diagnostic.length,
      line: loc.line,
      column: loc.column,
      severity: _severityOverride ?? LintSeverity.warning,
    ));
  }

  /// Creates a [DiagnosticReporter] backed by this collector.
  DiagnosticReporter createReporter() {
    final src = StringSource(_source, filePath);
    return DiagnosticReporter(this, src);
  }
}
