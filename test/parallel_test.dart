import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:fast_linter/src/engine/runner.dart';
import 'package:test/test.dart';

import 'helpers/test_rules.dart';

List<AnalysisRule> _createRules() => [AvoidOptionalPositionalParameters()];

void main() {
  group('parallel execution', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fast_linter_test_');
      // Create test files with violations
      File('${tempDir.path}/a.dart')
          .writeAsStringSync('void a([int x = 0]) {}\n');
      File('${tempDir.path}/b.dart')
          .writeAsStringSync('void b([int y = 0]) {}\n');
      File('${tempDir.path}/c.dart')
          .writeAsStringSync('void c({int z = 0}) {}\n'); // no violation
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('sequential run finds violations', () async {
      final runner = LintRunner(rules: _createRules());
      final diagnostics = await runner.runOnDirectory(tempDir);

      expect(diagnostics, hasLength(2));
    });

    test('parallel run finds same violations', () async {
      final runner = LintRunner(
        rules: _createRules(),
        ruleFactory: _createRules,
      );
      final diagnostics = await runner.runOnDirectory(tempDir, concurrency: 2);

      expect(diagnostics, hasLength(2));
      final files = diagnostics.map((d) => d.filePath).toSet();
      expect(files, hasLength(2));
    });

    test('parallel with single file falls back to sequential', () async {
      final singleDir = Directory.systemTemp.createTempSync('fast_linter_single_');
      addTearDown(() => singleDir.deleteSync(recursive: true));
      File('${singleDir.path}/only.dart')
          .writeAsStringSync('void only([int x = 0]) {}\n');

      final runner = LintRunner(
        rules: _createRules(),
        ruleFactory: _createRules,
      );
      final diagnostics = await runner.runOnDirectory(singleDir);

      expect(diagnostics, hasLength(1));
    });
  });
}
