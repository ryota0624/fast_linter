import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity, LintCode;
import 'package:fast_linter/src/config/analysis_options_config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

class _StubRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'stub_rule',
    'Stub',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  _StubRule({required String name})
      : super(name: name, description: 'Stub rule');

  @override
  void registerNodeProcessors(
      RuleVisitorRegistry registry, RuleContext context) {}
}

void main() {
  group('AnalysisOptionsConfig', () {
    test('parses diagnostics with boolean values', () {
      final yaml = loadYaml('''
analyzer:
  plugins:
    my_lint:
      diagnostics:
        rule_a: true
        rule_b: false
''') as YamlMap;

      final config =
          AnalysisOptionsConfig.fromYamlMap(yaml, pluginName: 'my_lint');

      expect(config.ruleOverrides['rule_a']!.enabled, isTrue);
      expect(config.ruleOverrides['rule_b']!.enabled, isFalse);
    });

    test('parses diagnostics with severity strings', () {
      final yaml = loadYaml('''
analyzer:
  plugins:
    my_lint:
      diagnostics:
        rule_a: info
        rule_b: warning
        rule_c: error
''') as YamlMap;

      final config =
          AnalysisOptionsConfig.fromYamlMap(yaml, pluginName: 'my_lint');

      expect(config.ruleOverrides['rule_a']!.enabled, isTrue);
      expect(config.ruleOverrides['rule_a']!.severity, LintSeverity.info);
      expect(config.ruleOverrides['rule_b']!.severity, LintSeverity.warning);
      expect(config.ruleOverrides['rule_c']!.severity, LintSeverity.error);
    });

    test('parses exclude patterns', () {
      final yaml = loadYaml('''
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
''') as YamlMap;

      final config =
          AnalysisOptionsConfig.fromYamlMap(yaml, pluginName: 'my_lint');

      expect(config.excludePatterns, ['**/*.g.dart', '**/*.freezed.dart']);
    });

    test('returns empty config for missing plugin', () {
      final yaml = loadYaml('''
analyzer:
  plugins:
    other_lint:
      diagnostics:
        rule_a: true
''') as YamlMap;

      final config =
          AnalysisOptionsConfig.fromYamlMap(yaml, pluginName: 'my_lint');

      expect(config.ruleOverrides, isEmpty);
    });

    test('filterRules removes disabled rules', () {
      final config = AnalysisOptionsConfig(ruleOverrides: {
        'rule_a': const RuleOverride.enabled(),
        'rule_b': const RuleOverride.disabled(),
      });

      final rules = [
        _StubRule(name: 'rule_a'),
        _StubRule(name: 'rule_b'),
        _StubRule(name: 'rule_c'), // not in config = enabled
      ];

      final filtered = config.filterRules(rules);

      expect(filtered.map((r) => r.name), ['rule_a', 'rule_c']);
    });

    test('severityFor returns override', () {
      final config = AnalysisOptionsConfig(ruleOverrides: {
        'rule_a': const RuleOverride.enabled(LintSeverity.error),
        'rule_b': const RuleOverride.enabled(),
      });

      expect(config.severityFor('rule_a'), LintSeverity.error);
      expect(config.severityFor('rule_b'), isNull);
      expect(config.severityFor('rule_c'), isNull);
    });

    test('LintSeverity.lspValue returns correct values', () {
      expect(LintSeverity.error.lspValue, 1);
      expect(LintSeverity.warning.lspValue, 2);
      expect(LintSeverity.info.lspValue, 3);
    });
  });
}
