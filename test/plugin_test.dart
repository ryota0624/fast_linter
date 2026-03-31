import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:fast_linter/fast_linter.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'helpers/test_rules.dart';

List<AbstractAnalysisRule> _createPluginARules() => [
      AvoidOptionalPositionalParameters(),
    ];

List<AbstractAnalysisRule> _createPluginBRules() => [
      AvoidOptionalPositionalParameters(),
    ];

void main() {
  group('PluginDescriptor', () {
    test('bundles name and factory', () {
      final plugin = (
        name: 'test_lint',
        createRules: _createPluginARules,
      );

      expect(plugin.name, 'test_lint');
      expect(plugin.createRules(), hasLength(1));
    });

    test('multiple plugins produce combined rules', () {
      final plugins = <PluginDescriptor>[
        (name: 'plugin_a', createRules: _createPluginARules),
        (name: 'plugin_b', createRules: _createPluginBRules),
      ];

      final allRules = [for (final p in plugins) ...p.createRules()];
      expect(allRules, hasLength(2));
    });
  });

  group('AnalysisOptionsConfig.fromYamlMapMulti', () {
    test('merges diagnostics from multiple plugins', () {
      final yaml = loadYaml('''
analyzer:
  plugins:
    plugin_a:
      diagnostics:
        rule_a: true
        rule_b: false
    plugin_b:
      diagnostics:
        rule_c: error
        rule_d: false
''') as YamlMap;

      final config = AnalysisOptionsConfig.fromYamlMapMulti(
        yaml,
        pluginNames: ['plugin_a', 'plugin_b'],
      );

      expect(config.ruleOverrides['rule_a']!.enabled, isTrue);
      expect(config.ruleOverrides['rule_b']!.enabled, isFalse);
      expect(config.ruleOverrides['rule_c']!.enabled, isTrue);
      expect(config.ruleOverrides['rule_c']!.severity, LintSeverity.error);
      expect(config.ruleOverrides['rule_d']!.enabled, isFalse);
    });

    test('later plugin overrides earlier for same rule name', () {
      final yaml = loadYaml('''
analyzer:
  plugins:
    plugin_a:
      diagnostics:
        shared_rule: false
    plugin_b:
      diagnostics:
        shared_rule: error
''') as YamlMap;

      final config = AnalysisOptionsConfig.fromYamlMapMulti(
        yaml,
        pluginNames: ['plugin_a', 'plugin_b'],
      );

      // plugin_b should win
      expect(config.ruleOverrides['shared_rule']!.enabled, isTrue);
      expect(
          config.ruleOverrides['shared_rule']!.severity, LintSeverity.error);
    });

    test('works with single plugin (same as fromYamlMap)', () {
      final yaml = loadYaml('''
analyzer:
  plugins:
    my_lint:
      diagnostics:
        rule_a: warning
''') as YamlMap;

      final multi = AnalysisOptionsConfig.fromYamlMapMulti(
        yaml,
        pluginNames: ['my_lint'],
      );
      final single = AnalysisOptionsConfig.fromYamlMap(
        yaml,
        pluginName: 'my_lint',
      );

      expect(multi.ruleOverrides.keys, single.ruleOverrides.keys);
    });

    test('empty pluginNames returns only exclude patterns', () {
      final yaml = loadYaml('''
analyzer:
  exclude:
    - "**/*.g.dart"
  plugins:
    my_lint:
      diagnostics:
        rule_a: true
''') as YamlMap;

      final config = AnalysisOptionsConfig.fromYamlMapMulti(
        yaml,
        pluginNames: [],
      );

      expect(config.ruleOverrides, isEmpty);
      expect(config.excludePatterns, ['**/*.g.dart']);
    });
  });

  group('resolveConfigForPlugins', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('plugin_config_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('merges config from multiple plugins', () {
      File('${tempDir.path}/analysis_options.yaml').writeAsStringSync('''
analyzer:
  plugins:
    plugin_a:
      diagnostics:
        rule_a: true
    plugin_b:
      diagnostics:
        rule_b: warning
  exclude:
    - "**/*.g.dart"
''');

      final config = resolveConfigForPlugins(
        tempDir,
        pluginNames: ['plugin_a', 'plugin_b'],
      );

      expect(config.ruleOverrides['rule_a']!.enabled, isTrue);
      expect(config.ruleOverrides['rule_b']!.enabled, isTrue);
      expect(config.ruleOverrides['rule_b']!.severity, LintSeverity.warning);
      expect(config.excludePatterns, ['**/*.g.dart']);
    });

    test('returns empty when no analysis_options.yaml', () {
      final config = resolveConfigForPlugins(
        tempDir,
        pluginNames: ['plugin_a'],
      );

      expect(config.ruleOverrides, isEmpty);
      expect(config.excludePatterns, isEmpty);
    });
  });

  group('LintRunner with ruleFactories', () {
    test('accepts multiple factories', () {
      final runner = LintRunner(
        rules: [
          ..._createPluginARules(),
          ..._createPluginBRules(),
        ],
        ruleFactories: [_createPluginARules, _createPluginBRules],
      );

      final diagnostics = runner.runOnSource(
        'void foo([int x = 0]) {}',
        filePath: 'test.dart',
      );

      // Two instances of the same rule, so 2 diagnostics
      expect(diagnostics, hasLength(2));
    });

    test('single ruleFactory still works', () {
      final runner = LintRunner(
        rules: _createPluginARules(),
        ruleFactory: _createPluginARules,
      );

      final diagnostics = runner.runOnSource(
        'void foo([int x = 0]) {}',
        filePath: 'test.dart',
      );

      expect(diagnostics, hasLength(1));
    });
  });
}
