import 'dart:io';

import 'package:fast_linter/src/config/config.dart';
import 'package:test/test.dart';

void main() {
  group('resolveConfig', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('config_resolver_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('fast_lint.yaml takes priority over analysis_options.yaml', () {
      File('${tempDir.path}/fast_lint.yaml').writeAsStringSync('''
rules:
  - fast_rule
exclude:
  - "fast_exclude/**"
''');

      File('${tempDir.path}/analysis_options.yaml').writeAsStringSync('''
analyzer:
  plugins:
    test_lint:
      diagnostics:
        analysis_rule: true
  exclude:
    - "analysis_exclude/**"
''');

      final config = resolveConfig(tempDir, pluginName: 'test_lint');

      // fast_lint.yaml should win
      expect(config.ruleOverrides.containsKey('fast_rule'), isTrue);
      expect(config.ruleOverrides.containsKey('analysis_rule'), isFalse);
      expect(config.excludePatterns, ['fast_exclude/**']);
    });

    test('falls back to analysis_options.yaml when no fast_lint.yaml', () {
      File('${tempDir.path}/analysis_options.yaml').writeAsStringSync('''
analyzer:
  plugins:
    test_lint:
      diagnostics:
        my_rule: error
  exclude:
    - "**/*.g.dart"
''');

      final config = resolveConfig(tempDir, pluginName: 'test_lint');

      expect(config.ruleOverrides['my_rule']!.enabled, isTrue);
      expect(config.excludePatterns, ['**/*.g.dart']);
    });

    test('returns empty config when no config files exist', () {
      final config = resolveConfig(tempDir, pluginName: 'test_lint');

      expect(config.ruleOverrides, isEmpty);
      expect(config.excludePatterns, isEmpty);
    });

    test('returns empty config when no pluginName provided', () {
      File('${tempDir.path}/analysis_options.yaml').writeAsStringSync('''
analyzer:
  plugins:
    test_lint:
      diagnostics:
        my_rule: true
''');

      // Without pluginName, analysis_options.yaml is not read
      final config = resolveConfig(tempDir);

      expect(config.ruleOverrides, isEmpty);
    });
  });
}
