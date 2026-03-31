// lib/src/type_checker/type_diagnostic.dart

/// Severity level for a type diagnostic.
enum TypeDiagnosticSeverity {
  error,
  warning,
  info,
  hint,
}

/// Represents a single diagnostic reported by the type checker.
class TypeDiagnostic {
  /// The file path where the diagnostic was reported.
  final String filePath;

  /// The 1-based line number.
  final int line;

  /// The 1-based column number.
  final int column;

  /// The human-readable diagnostic message.
  final String message;

  /// The severity level of this diagnostic.
  final TypeDiagnosticSeverity severity;

  /// The error code (e.g., "INVALID_ASSIGNMENT").
  final String? code;

  const TypeDiagnostic({
    required this.filePath,
    required this.line,
    required this.column,
    required this.message,
    required this.severity,
    this.code,
  });

  @override
  String toString() =>
      '${severity.name.toUpperCase()} $filePath:$line:$column - $message'
      '${code != null ? ' ($code)' : ''}';
}
