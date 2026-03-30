import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity, LintCode;
import 'package:fast_linter/src/engine/runner.dart';
import 'package:test/test.dart';

import 'helpers/test_rules.dart';

/// Test rule: accesses type-aware context during registration.
class TypeAwareRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'type_aware_rule',
    'A rule that requires type-aware analysis',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  TypeAwareRule()
      : super(
          name: 'type_aware_rule',
          description: 'A rule that requires type-aware analysis',
        );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // This will throw because FastRuleContext doesn't support typeProvider.
    context.typeProvider;
  }
}

void main() {
  late LintRunner runner;

  setUp(() {
    runner = LintRunner(rules: [AvoidOptionalPositionalParameters()]);
  });

  test('detects optional positional parameter in function', () {
    final diagnostics = runner.runOnSource(
        'void foo([int x = 0]) {}\n', filePath: 'test.dart');

    expect(diagnostics, hasLength(1));
    expect(diagnostics.first.code, 'avoid_optional_positional_parameters');
    expect(diagnostics.first.line, 1);
    expect(diagnostics.first.column, greaterThan(0));
  });

  test('detects optional positional parameter in method', () {
    final diagnostics = runner.runOnSource('''
class MyClass {
  void bar([String s = '']) {}
}
''', filePath: 'test.dart');

    expect(diagnostics, hasLength(1));
  });

  test('detects optional positional parameter in constructor', () {
    final diagnostics = runner.runOnSource('''
class MyClass {
  MyClass([int value = 0]);
}
''', filePath: 'test.dart');

    expect(diagnostics, hasLength(1));
  });

  test('no diagnostics for named parameters', () {
    final diagnostics = runner.runOnSource('''
void foo({int x = 0}) {}
''', filePath: 'test.dart');

    expect(diagnostics, isEmpty);
  });

  test('no diagnostics for required positional parameters', () {
    final diagnostics = runner.runOnSource('''
void foo(int x, String y) {}
''', filePath: 'test.dart');

    expect(diagnostics, isEmpty);
  });

  test('multiple rules can run together', () {
    final runner2 = LintRunner(rules: [
      AvoidOptionalPositionalParameters(),
      AvoidOptionalPositionalParameters(), // same rule twice for testing
    ]);
    final diagnostics = runner2.runOnSource('''
void foo([int x = 0]) {}
''', filePath: 'test.dart');

    expect(diagnostics, hasLength(2));
  });

  group('type-aware rule detection', () {
    test('skips type-aware rule and reports it in skippedRules', () {
      final runner = LintRunner(rules: [TypeAwareRule()]);
      final diagnostics = runner.runOnSource(
        'void foo() {}',
        filePath: 'test.dart',
      );

      expect(diagnostics, isEmpty);
      expect(runner.skippedRules, contains('type_aware_rule'));
    });

    test('skips type-aware rule while other rules still work', () {
      final runner = LintRunner(rules: [
        TypeAwareRule(),
        AvoidOptionalPositionalParameters(),
      ]);
      final diagnostics = runner.runOnSource(
        'void foo([int x = 0]) {}',
        filePath: 'test.dart',
      );

      expect(diagnostics, hasLength(1));
      expect(diagnostics.first.code, 'avoid_optional_positional_parameters');
      expect(runner.skippedRules, contains('type_aware_rule'));
      expect(runner.skippedRules, hasLength(1));
    });

    test('skippedRules accumulates across multiple files', () {
      final runner = LintRunner(rules: [TypeAwareRule()]);
      runner.runOnSource('void a() {}', filePath: 'a.dart');
      runner.runOnSource('void b() {}', filePath: 'b.dart');

      // Same rule name only appears once in the set.
      expect(runner.skippedRules, hasLength(1));
      expect(runner.skippedRules, contains('type_aware_rule'));
    });
  });
}
