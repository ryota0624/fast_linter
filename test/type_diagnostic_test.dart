import 'package:fast_linter/src/type_checker/type_diagnostic.dart';
import 'package:test/test.dart';

void main() {
  group('TypeDiagnostic', () {
    test('stores all fields correctly', () {
      final d = TypeDiagnostic(
        filePath: '/tmp/test.dart',
        message: "Undefined name 'foo'",
        severity: TypeSeverity.error,
        line: 10,
        column: 5,
        length: 3,
      );
      expect(d.filePath, '/tmp/test.dart');
      expect(d.message, "Undefined name 'foo'");
      expect(d.severity, TypeSeverity.error);
      expect(d.line, 10);
      expect(d.column, 5);
      expect(d.length, 3);
    });

    test('toString produces standard format', () {
      final d = TypeDiagnostic(
        filePath: '/tmp/test.dart',
        message: "Undefined name 'foo'",
        severity: TypeSeverity.error,
        line: 10,
        column: 5,
        length: 3,
      );
      expect(
        d.toString(),
        "/tmp/test.dart:10:5 - error - Undefined name 'foo'",
      );
    });
  });

  group('TypeSeverity', () {
    test('lspValue returns correct LSP severity codes', () {
      expect(TypeSeverity.error.lspValue, 1);
      expect(TypeSeverity.warning.lspValue, 2);
    });
  });
}
