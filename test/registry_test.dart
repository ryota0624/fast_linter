import 'package:fast_linter/src/config/analysis_options_config.dart';
import 'package:fast_linter/src/rules/registry.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'helpers/test_rules.dart';

void main() {
  group('RuleRegistry', () {
    late RuleRegistry registry;

    setUp(() {
      registry = RuleRegistry()
        ..register(AvoidOptionalPositionalParameters());
    });

    test('register and lookup by name', () {
      expect(registry.length, 1);
      expect(registry.getByName('avoid_optional_positional_parameters'),
          isNotNull);
      expect(registry.getByName('nonexistent'), isNull);
    });

    test('registerAll adds multiple rules', () {
      final reg = RuleRegistry()
        ..registerAll([AvoidOptionalPositionalParameters()]);
      expect(reg.length, 1);
    });

    test('resolveEnabled returns only enabled registered rules', () {
      final linterRules = {
        'avoid_optional_positional_parameters':
            const RuleOverride.enabled(),
        'unknown_rule': const RuleOverride.enabled(),
      };

      final resolved = registry.resolveEnabled(linterRules);
      expect(resolved, hasLength(1));
      expect(resolved.first.name, 'avoid_optional_positional_parameters');
    });

    test('resolveEnabled skips disabled rules', () {
      final linterRules = {
        'avoid_optional_positional_parameters':
            const RuleOverride.disabled(),
      };

      final resolved = registry.resolveEnabled(linterRules);
      expect(resolved, isEmpty);
    });

    test('unregisteredNames identifies missing rules', () {
      final linterRules = {
        'avoid_optional_positional_parameters':
            const RuleOverride.enabled(),
        'unknown_rule': const RuleOverride.enabled(),
        'disabled_rule': const RuleOverride.disabled(),
      };

      final missing = registry.unregisteredNames(linterRules);
      expect(missing, {'unknown_rule'});
    });
  });

  group('AnalysisOptionsConfig linterRules parsing', () {
    test('parses list format', () {
      final yaml = loadYaml('''
linter:
  rules:
    - prefer_single_quotes
    - camel_case_types
''') as YamlMap;

      final config =
          AnalysisOptionsConfig.fromYamlMapMulti(yaml, pluginNames: []);

      expect(config.linterRules, hasLength(2));
      expect(config.linterRules['prefer_single_quotes']!.enabled, isTrue);
      expect(config.linterRules['camel_case_types']!.enabled, isTrue);
    });

    test('parses map format with booleans', () {
      final yaml = loadYaml('''
linter:
  rules:
    prefer_single_quotes: true
    avoid_void_async: false
''') as YamlMap;

      final config =
          AnalysisOptionsConfig.fromYamlMapMulti(yaml, pluginNames: []);

      expect(config.linterRules['prefer_single_quotes']!.enabled, isTrue);
      expect(config.linterRules['avoid_void_async']!.enabled, isFalse);
    });

    test('returns empty for missing linter section', () {
      final yaml = loadYaml('''
analyzer:
  exclude:
    - "**/*.g.dart"
''') as YamlMap;

      final config =
          AnalysisOptionsConfig.fromYamlMapMulti(yaml, pluginNames: []);

      expect(config.linterRules, isEmpty);
    });

    test('enabledLinterRuleNames returns only enabled names', () {
      final config = AnalysisOptionsConfig(linterRules: {
        'rule_a': const RuleOverride.enabled(),
        'rule_b': const RuleOverride.disabled(),
        'rule_c': const RuleOverride.enabled(LintSeverity.error),
      });

      expect(config.enabledLinterRuleNames, {'rule_a', 'rule_c'});
    });

    test('severityFor checks both plugin and linter rules', () {
      final config = AnalysisOptionsConfig(
        ruleOverrides: {
          'plugin_rule': const RuleOverride.enabled(LintSeverity.error),
        },
        linterRules: {
          'linter_rule': const RuleOverride.enabled(LintSeverity.info),
        },
      );

      expect(config.severityFor('plugin_rule'), LintSeverity.error);
      expect(config.severityFor('linter_rule'), LintSeverity.info);
      expect(config.severityFor('unknown'), isNull);
    });

    test('parses from stailer-server-style config', () {
      final yaml = loadYaml('''
linter:
  rules:
    avoid_void_async: true
    always_declare_return_types: true
    prefer_single_quotes: true
    unawaited_futures: true
    prefer_function_declarations_over_variables: false
    constant_identifier_names: false
    directives_ordering: true
''') as YamlMap;

      final config =
          AnalysisOptionsConfig.fromYamlMapMulti(yaml, pluginNames: []);

      expect(config.linterRules['avoid_void_async']!.enabled, isTrue);
      expect(config.linterRules['prefer_single_quotes']!.enabled, isTrue);
      expect(config.linterRules['constant_identifier_names']!.enabled,
          isFalse);
      expect(config.linterRules['directives_ordering']!.enabled, isTrue);
    });
  });
}
