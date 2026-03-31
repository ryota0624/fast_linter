import '../config/analysis_options_config.dart';

/// A diagnostic reported by a lint rule.
///
/// Contains the source location, rule code, message, and severity.
class LintDiagnostic {
  /// The path of the file containing this diagnostic.
  final String filePath;

  /// The rule code that produced this diagnostic.
  final String code;

  /// The human-readable diagnostic message.
  final String message;

  /// The 0-based offset in the source where the diagnostic starts.
  final int offset;

  /// The length of the source span covered by this diagnostic.
  final int length;

  /// The 1-based line number.
  final int line;

  /// The 1-based column number.
  final int column;

  /// The severity of this diagnostic.
  final LintSeverity severity;

  /// Creates a lint diagnostic with the given source location and metadata.
  const LintDiagnostic({
    required this.filePath,
    required this.code,
    required this.message,
    required this.offset,
    required this.length,
    required this.line,
    required this.column,
    this.severity = LintSeverity.warning,
  });

  @override
  String toString() => '$filePath:$line:$column - ${severity.name} - $code - $message';
}

/// Computes 1-based line and column from a 0-based [offset] in [source].
({int line, int column}) computeLineColumn(String source, int offset) {
  var line = 1;
  var lastNewline = -1;
  for (var i = 0; i < offset && i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) {
      line++;
      lastNewline = i;
    }
  }
  return (line: line, column: offset - lastNewline);
}
