import '../config/analysis_options_config.dart';

class LintDiagnostic {
  final String filePath;
  final String code;
  final String message;
  final int offset;
  final int length;
  final int line;
  final int column;
  final LintSeverity severity;

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
