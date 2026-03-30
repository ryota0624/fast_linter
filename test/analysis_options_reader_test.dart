import 'dart:io';

import 'package:fast_linter/src/config/analysis_options_config.dart';
import 'package:fast_linter/src/config/analysis_options_reader.dart';
import 'package:test/test.dart';

void main() {
  group('AnalysisOptionsReader', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('analysis_options_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('reads diagnostics from analysis_options.yaml', () {
      File('${tempDir.path}/analysis_options.yaml').writeAsStringSync('''
analyzer:
  plugins:
    test_lint:
      diagnostics:
        rule_a: true
        rule_b: false
  exclude:
    - "**/*.g.dart"
''');

      final config = AnalysisOptionsReader.findAndLoad(
        tempDir,
        pluginName: 'test_lint',
      );

      expect(config, isNotNull);
      expect(config!.ruleOverrides['rule_a']!.enabled, isTrue);
      expect(config.ruleOverrides['rule_b']!.enabled, isFalse);
      expect(config.excludePatterns, ['**/*.g.dart']);
    });

    test('resolves relative include', () {
      // Create base config
      File('${tempDir.path}/base_options.yaml').writeAsStringSync('''
analyzer:
  plugins:
    test_lint:
      diagnostics:
        base_rule: true
  exclude:
    - "**/*.g.dart"
''');

      // Create main config that includes base
      File('${tempDir.path}/analysis_options.yaml').writeAsStringSync('''
include: base_options.yaml

analyzer:
  plugins:
    test_lint:
      diagnostics:
        local_rule: error
''');

      final config = AnalysisOptionsReader.findAndLoad(
        tempDir,
        pluginName: 'test_lint',
      );

      expect(config, isNotNull);
      expect(config!.ruleOverrides['base_rule']!.enabled, isTrue);
      expect(config.ruleOverrides['local_rule']!.enabled, isTrue);
      expect(config.ruleOverrides['local_rule']!.severity, LintSeverity.error);
      expect(config.excludePatterns, contains('**/*.g.dart'));
    });

    test('walks up directories to find config', () {
      File('${tempDir.path}/analysis_options.yaml').writeAsStringSync('''
analyzer:
  plugins:
    test_lint:
      diagnostics:
        found_rule: true
''');

      final subDir = Directory('${tempDir.path}/src/lib')
        ..createSync(recursive: true);

      final config = AnalysisOptionsReader.findAndLoad(
        subDir,
        pluginName: 'test_lint',
      );

      expect(config, isNotNull);
      expect(config!.ruleOverrides['found_rule']!.enabled, isTrue);
    });

    test('returns null when no config exists', () {
      final config = AnalysisOptionsReader.findAndLoad(
        tempDir,
        pluginName: 'test_lint',
      );

      expect(config, isNull);
    });

    test('handles cycle in includes', () {
      File('${tempDir.path}/a.yaml').writeAsStringSync('''
include: b.yaml
analyzer:
  plugins:
    test_lint:
      diagnostics:
        rule_a: true
''');

      File('${tempDir.path}/b.yaml').writeAsStringSync('''
include: a.yaml
analyzer:
  plugins:
    test_lint:
      diagnostics:
        rule_b: true
''');

      File('${tempDir.path}/analysis_options.yaml').writeAsStringSync('''
include: a.yaml
''');

      // Should not hang or crash
      final config = AnalysisOptionsReader.findAndLoad(
        tempDir,
        pluginName: 'test_lint',
      );

      expect(config, isNotNull);
    });

    test('override takes precedence over included config', () {
      File('${tempDir.path}/base.yaml').writeAsStringSync('''
analyzer:
  plugins:
    test_lint:
      diagnostics:
        rule_a: true
        rule_b: true
''');

      File('${tempDir.path}/analysis_options.yaml').writeAsStringSync('''
include: base.yaml
analyzer:
  plugins:
    test_lint:
      diagnostics:
        rule_b: false
''');

      final config = AnalysisOptionsReader.findAndLoad(
        tempDir,
        pluginName: 'test_lint',
      );

      expect(config, isNotNull);
      expect(config!.ruleOverrides['rule_a']!.enabled, isTrue);
      expect(config.ruleOverrides['rule_b']!.enabled, isFalse);
    });
  });
}
