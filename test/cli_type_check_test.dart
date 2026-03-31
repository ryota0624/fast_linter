import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('CLI --type-check', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cli_tc_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('--type-check reports type errors', () async {
      final file = File('${tempDir.path}/bad.dart')
        ..writeAsStringSync('''
void main() {
  int x = "not an int";
}
''');

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/fast_linter.dart', '--type-check', file.path],
      );
      expect(result.exitCode, isNot(0));
      final output = '${result.stdout}${result.stderr}';
      expect(output, contains('bad.dart'));
    });

    test('--type-check passes on valid code', () async {
      final file = File('${tempDir.path}/good.dart')
        ..writeAsStringSync('void main() { print("hello"); }');

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/fast_linter.dart', '--type-check', '--no-lint', file.path],
      );
      expect(result.exitCode, 0);
    });

    test('--no-lint without --type-check is an error', () async {
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/fast_linter.dart', '--no-lint', '.'],
      );
      expect(result.exitCode, 2);
      expect(result.stderr, contains('--no-lint'));
    });

    test('--no-lint --type-check skips linting', () async {
      final file = File('${tempDir.path}/ok.dart')
        ..writeAsStringSync('void main() { print("hello"); }');

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/fast_linter.dart', '--no-lint', '--type-check', file.path],
      );
      expect(result.exitCode, 0);
    });
  });
}
