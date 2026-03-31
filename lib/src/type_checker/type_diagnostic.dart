/// Severity level for type diagnostics.
enum TypeSeverity {
  /// Error severity.
  error,

  /// Warning severity.
  warning;

  /// Returns the LSP DiagnosticSeverity numeric value.
  int get lspValue => switch (this) {
        error => 1,
        warning => 2,
      };
}

/// A diagnostic reported by the type checker.
class TypeDiagnostic {
  /// The file path where the diagnostic was reported.
  final String filePath;

  /// The human-readable diagnostic message.
  final String message;

  /// The severity level of this diagnostic.
  final TypeSeverity severity;

  /// The 1-based line number.
  final int line;

  /// The 1-based column number.
  final int column;

  /// The length of the source span covered by this diagnostic.
  final int length;

  /// Creates a type diagnostic with the given location and metadata.
  const TypeDiagnostic({
    required this.filePath,
    required this.message,
    required this.severity,
    required this.line,
    required this.column,
    required this.length,
  });

  @override
  String toString() =>
      '$filePath:$line:$column - ${severity.name} - $message';
}
