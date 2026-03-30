import 'dart:io';

import 'package:yaml/yaml.dart';

import 'analysis_options_config.dart';
import 'analysis_options_reader.dart';

/// Configuration loaded from a `fast_lint.yaml` file.
@Deprecated('Use AnalysisOptionsConfig with analysis_options.yaml instead')
class FastLintConfig {
  final Set<String> enabledRules;
  final List<String> excludePatterns;

  const FastLintConfig({
    required this.enabledRules,
    this.excludePatterns = const [],
  });

  /// Loads config from [file]. Returns null if the file doesn't exist.
  static FastLintConfig? fromFile(File file) {
    if (!file.existsSync()) return null;
    final content = file.readAsStringSync();
    return fromYaml(content);
  }

  /// Parses config from a YAML string.
  static FastLintConfig fromYaml(String yamlContent) {
    final doc = loadYaml(yamlContent);
    if (doc is! YamlMap) {
      return const FastLintConfig(enabledRules: {});
    }

    final rules = <String>{};
    final rulesNode = doc['rules'];
    if (rulesNode is YamlList) {
      for (final rule in rulesNode) {
        if (rule is String) rules.add(rule);
      }
    }

    final excludes = <String>[];
    final excludeNode = doc['exclude'];
    if (excludeNode is YamlList) {
      for (final pattern in excludeNode) {
        if (pattern is String) excludes.add(pattern);
      }
    }

    return FastLintConfig(
      enabledRules: rules,
      excludePatterns: excludes,
    );
  }

  /// Finds and loads the nearest `fast_lint.yaml` starting from [dir]
  /// and walking up parent directories.
  static FastLintConfig? findAndLoad([Directory? dir]) {
    dir ??= Directory.current;
    var current = dir;
    while (true) {
      final configFile = File('${current.path}/fast_lint.yaml');
      if (configFile.existsSync()) {
        return fromFile(configFile);
      }
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
    return null;
  }

  /// Converts this config to an [AnalysisOptionsConfig].
  AnalysisOptionsConfig toAnalysisOptionsConfig() {
    return AnalysisOptionsConfig(
      ruleOverrides: {
        for (final name in enabledRules) name: const RuleOverride.enabled(),
      },
      excludePatterns: excludePatterns,
    );
  }
}

/// Resolves configuration by checking sources in priority order:
///
/// 1. `fast_lint.yaml` (if exists) — takes full precedence
/// 2. `analysis_options.yaml` (with [pluginName]) — standard Dart config
/// 3. Default — all rules enabled, no exclusions
AnalysisOptionsConfig resolveConfig(
  Directory dir, {
  String? pluginName,
}) {
  if (pluginName != null) {
    return resolveConfigForPlugins(dir, pluginNames: [pluginName]);
  }

  // Priority 1: fast_lint.yaml
  // ignore: deprecated_member_use_from_same_package
  final fastLintConfig = FastLintConfig.findAndLoad(dir);
  if (fastLintConfig != null) {
    return fastLintConfig.toAnalysisOptionsConfig();
  }

  // Default: all rules enabled
  return AnalysisOptionsConfig.empty;
}

/// Resolves configuration for multiple plugins by checking sources in
/// priority order:
///
/// 1. `fast_lint.yaml` (if exists) — takes full precedence
/// 2. `analysis_options.yaml` — merges config from all [pluginNames]
/// 3. Default — all rules enabled, no exclusions
AnalysisOptionsConfig resolveConfigForPlugins(
  Directory dir, {
  required List<String> pluginNames,
}) {
  // Priority 1: fast_lint.yaml
  // ignore: deprecated_member_use_from_same_package
  final fastLintConfig = FastLintConfig.findAndLoad(dir);
  if (fastLintConfig != null) {
    return fastLintConfig.toAnalysisOptionsConfig();
  }

  // Priority 2: analysis_options.yaml (merge all plugin sections)
  if (pluginNames.isNotEmpty) {
    final analysisConfig = AnalysisOptionsReader.findAndLoadMulti(
      dir,
      pluginNames: pluginNames,
    );
    if (analysisConfig != null) return analysisConfig;
  }

  // Default: all rules enabled
  return AnalysisOptionsConfig.empty;
}
