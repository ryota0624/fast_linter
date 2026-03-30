import 'package:fast_linter/src/engine/ignore_comments.dart';
import 'package:fast_linter/src/engine/runner.dart';
import 'package:test/test.dart';

import 'helpers/test_rules.dart';

void main() {
  group('IgnoreInfo', () {
    test('parses ignore_for_file', () {
      final info = IgnoreInfo.parse('''
// ignore_for_file: rule_a, rule_b
void main() {}
''');
      expect(info.isIgnored('rule_a', 1), isTrue);
      expect(info.isIgnored('rule_a', 2), isTrue);
      expect(info.isIgnored('rule_b', 5), isTrue);
      expect(info.isIgnored('rule_c', 1), isFalse);
    });

    test('parses ignore comment on preceding line', () {
      final info = IgnoreInfo.parse('''
// ignore: my_rule
void foo([int x = 0]) {}
''');
      expect(info.isIgnored('my_rule', 2), isTrue);
      expect(info.isIgnored('my_rule', 1), isFalse);
      expect(info.isIgnored('my_rule', 3), isFalse);
    });

    test('parses prefixed codes like plugin_name/rule_name', () {
      final info = IgnoreInfo.parse('''
// ignore: my_lint/avoid_optional_positional_parameters
void foo([int x = 0]) {}
''');
      expect(
          info.isIgnored('avoid_optional_positional_parameters', 2), isTrue);
    });

    test('parses multiple codes', () {
      final info = IgnoreInfo.parse('''
// ignore: rule_a, rule_b
void foo() {}
''');
      expect(info.isIgnored('rule_a', 2), isTrue);
      expect(info.isIgnored('rule_b', 2), isTrue);
    });
  });

  group('ignore integration with LintRunner', () {
    test('respects ignore comment', () {
      final runner =
          LintRunner(rules: [AvoidOptionalPositionalParameters()]);

      final diagnostics = runner.runOnSource('''
// ignore: avoid_optional_positional_parameters
void foo([int x = 0]) {}
''', filePath: '/test.dart');

      expect(diagnostics, isEmpty);
    });

    test('respects ignore_for_file', () {
      final runner =
          LintRunner(rules: [AvoidOptionalPositionalParameters()]);

      final diagnostics = runner.runOnSource('''
// ignore_for_file: avoid_optional_positional_parameters
void foo([int x = 0]) {}
void bar([int y = 0]) {}
''', filePath: '/test.dart');

      expect(diagnostics, isEmpty);
    });

    test('does not suppress unrelated rule', () {
      final runner =
          LintRunner(rules: [AvoidOptionalPositionalParameters()]);

      final diagnostics = runner.runOnSource('''
// ignore: some_other_rule
void foo([int x = 0]) {}
''', filePath: '/test.dart');

      expect(diagnostics, hasLength(1));
    });
  });
}
