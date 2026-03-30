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

    test('reads analysis_options.yaml', () {
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

      final config = resolveConfig(tempDir);

      expect(config.ruleOverrides, isEmpty);
    });
  });
}
