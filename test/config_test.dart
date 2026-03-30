import 'dart:io';

import 'package:fast_linter/src/config/config.dart';
import 'package:test/test.dart';

void main() {
  group('FastLintConfig', () {
    test('parses rules from YAML', () {
      final config = FastLintConfig.fromYaml('''
rules:
  - avoid_optional_positional_parameters
  - avoid_roundabout_null_matcher
''');
      expect(config.enabledRules, {
        'avoid_optional_positional_parameters',
        'avoid_roundabout_null_matcher',
      });
    });

    test('parses exclude patterns', () {
      final config = FastLintConfig.fromYaml('''
rules:
  - my_rule
exclude:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
''');
      expect(config.excludePatterns, [
        '**/*.g.dart',
        '**/*.freezed.dart',
      ]);
    });

    test('handles empty config', () {
      final config = FastLintConfig.fromYaml('');
      expect(config.enabledRules, isEmpty);
      expect(config.excludePatterns, isEmpty);
    });

    test('handles missing rules key', () {
      final config = FastLintConfig.fromYaml('exclude:\n  - "*.g.dart"\n');
      expect(config.enabledRules, isEmpty);
    });

    test('loads from file', () {
      final tempDir = Directory.systemTemp.createTempSync('fast_lint_config_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final configFile = File('${tempDir.path}/fast_lint.yaml')
        ..writeAsStringSync('''
rules:
  - test_rule
''');

      final config = FastLintConfig.fromFile(configFile);
      expect(config, isNotNull);
      expect(config!.enabledRules, {'test_rule'});
    });

    test('returns null for non-existent file', () {
      final config = FastLintConfig.fromFile(File('/nonexistent/fast_lint.yaml'));
      expect(config, isNull);
    });

    test('findAndLoad walks up directories', () {
      final tempDir = Directory.systemTemp.createTempSync('fast_lint_find_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // Create config in parent
      File('${tempDir.path}/fast_lint.yaml')
          .writeAsStringSync('rules:\n  - found_rule\n');

      // Create subdirectory
      final subDir = Directory('${tempDir.path}/sub')..createSync();

      final config = FastLintConfig.findAndLoad(subDir);
      expect(config, isNotNull);
      expect(config!.enabledRules, {'found_rule'});
    });
  });
}
