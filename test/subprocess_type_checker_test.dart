import 'dart:io';

import 'package:fast_linter/src/type_checker/subprocess_type_checker.dart';
import 'package:fast_linter/src/type_checker/type_diagnostic.dart';
import 'package:test/test.dart';

void main() {
  group('SubprocessTypeChecker', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sp_type_check_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('reports no errors for valid Dart code', () async {
      final file = File('${tempDir.path}/valid.dart')
        ..writeAsStringSync('void main() { print("hello"); }');

      final checker = SubprocessTypeChecker(
        cacheDir: '${tempDir.path}/.cache',
      );
      try {
        final diagnostics = await checker.check([file.path]);
        expect(diagnostics, isEmpty);
      } finally {
        await checker.dispose();
      }
    });

    test('reports type error for type mismatch', () async {
      final file = File('${tempDir.path}/invalid.dart')
        ..writeAsStringSync('''
void main() {
  int x = "not an int";
}
''');

      final checker = SubprocessTypeChecker(
        cacheDir: '${tempDir.path}/.cache',
      );
      try {
        final diagnostics = await checker.check([file.path]);
        expect(diagnostics, isNotEmpty);
        expect(diagnostics.first.severity, TypeSeverity.error);
        expect(diagnostics.first.filePath, contains('invalid.dart'));
      } finally {
        await checker.dispose();
      }
    });

    test('checkIncremental delegates to check', () async {
      final file = File('${tempDir.path}/valid.dart')
        ..writeAsStringSync('void main() {}');

      final checker = SubprocessTypeChecker(
        cacheDir: '${tempDir.path}/.cache',
      );
      try {
        final diagnostics = await checker.checkIncremental([file.path]);
        expect(diagnostics, isEmpty);
      } finally {
        await checker.dispose();
      }
    });
  });

  group('parseDiagnosticLine', () {
    test('parses standard CFE error output', () {
      final d = parseDiagnosticLine(
        "lib/foo.dart:10:5: Error: A value of type 'String' can't be assigned to a variable of type 'int'.",
      );
      expect(d, isNotNull);
      expect(d!.filePath, 'lib/foo.dart');
      expect(d.line, 10);
      expect(d.column, 5);
      expect(d.severity, TypeSeverity.error);
      expect(d.message,
          "A value of type 'String' can't be assigned to a variable of type 'int'.");
    });

    test('parses warning output', () {
      final d = parseDiagnosticLine(
        'lib/bar.dart:3:1: Warning: Unused import.',
      );
      expect(d, isNotNull);
      expect(d!.severity, TypeSeverity.warning);
    });

    test('returns null for non-diagnostic lines', () {
      expect(parseDiagnosticLine('Compiling...'), isNull);
      expect(parseDiagnosticLine(''), isNull);
    });
  });
}
