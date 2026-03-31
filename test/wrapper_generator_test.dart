import 'dart:io';

import 'package:fast_linter/src/type_checker/wrapper_generator.dart';
import 'package:test/test.dart';

void main() {
  group('WrapperGenerator', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('wrapper_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('generates wrapper importing all given files', () {
      final file1 = File('${tempDir.path}/lib/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('class A {}');
      final file2 = File('${tempDir.path}/lib/b.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('class B {}');

      final generator = WrapperGenerator(outputDir: tempDir.path);
      final wrapperPath = generator.generate([file1.path, file2.path]);

      final content = File(wrapperPath).readAsStringSync();
      expect(content, contains("import '${file1.path}'"));
      expect(content, contains("import '${file2.path}'"));
      expect(content, contains('void main() {}'));
    });

    test('generates wrapper for single file', () {
      final file = File('${tempDir.path}/lib/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('class A {}');

      final generator = WrapperGenerator(outputDir: tempDir.path);
      final wrapperPath = generator.generate([file.path]);

      final content = File(wrapperPath).readAsStringSync();
      expect(content, contains("import '${file.path}'"));
      expect(content, contains('void main() {}'));
    });

    test('cleanup removes generated wrapper', () {
      final file = File('${tempDir.path}/lib/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('class A {}');

      final generator = WrapperGenerator(outputDir: tempDir.path);
      final wrapperPath = generator.generate([file.path]);
      expect(File(wrapperPath).existsSync(), isTrue);

      generator.cleanup();
      expect(File(wrapperPath).existsSync(), isFalse);
    });
  });
}
