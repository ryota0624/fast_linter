import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:yaml/yaml.dart';

/// Severity level for a diagnostic.
enum LintSeverity {
  info,
  warning,
  error;

  /// Maps to LSP DiagnosticSeverity values.
  int get lspValue => switch (this) {
        LintSeverity.error => 1,
        LintSeverity.warning => 2,
        LintSeverity.info => 3,
      };
}

/// Configuration override for a single rule.
class RuleOverride {
  final bool enabled;
  final LintSeverity? severity;

  const RuleOverride({required this.enabled, this.severity});

  const RuleOverride.enabled([this.severity]) : enabled = true;
  const RuleOverride.disabled()
      : enabled = false,
        severity = null;
}

/// Configuration parsed from analysis_options.yaml.
class AnalysisOptionsConfig {
  /// Rule overrides keyed by rule name.
  ///
  /// Rules not present in this map use their default state (enabled).
  final Map<String, RuleOverride> ruleOverrides;

  /// Glob patterns for files to exclude from analysis.
  final List<String> excludePatterns;

  const AnalysisOptionsConfig({
    this.ruleOverrides = const {},
    this.excludePatterns = const [],
  });

  /// An empty config where all rules are enabled and nothing is excluded.
  static const empty = AnalysisOptionsConfig();

  /// Parses the relevant sections from a fully-merged analysis_options.yaml map.
  ///
  /// Extracts:
  /// - `analyzer.plugins.<pluginName>.diagnostics` → [ruleOverrides]
  /// - `analyzer.exclude` → [excludePatterns]
  factory AnalysisOptionsConfig.fromYamlMap(
    YamlMap map, {
    required String pluginName,
  }) {
    return AnalysisOptionsConfig.fromYamlMapMulti(
      map,
      pluginNames: [pluginName],
    );
  }

  /// Parses config for multiple plugins from a fully-merged
  /// analysis_options.yaml map.
  ///
  /// Rule overrides from all [pluginNames] are merged. If the same rule
  /// appears in multiple plugins, later plugins take precedence.
  factory AnalysisOptionsConfig.fromYamlMapMulti(
    YamlMap map, {
    required List<String> pluginNames,
  }) {
    final ruleOverrides = <String, RuleOverride>{};
    final excludePatterns = <String>[];

    // Parse analyzer.exclude
    final analyzer = map['analyzer'];
    if (analyzer is YamlMap) {
      final exclude = analyzer['exclude'];
      if (exclude is YamlList) {
        for (final pattern in exclude) {
          if (pattern is String) excludePatterns.add(pattern);
        }
      }

      // Parse analyzer.plugins.<pluginName>.diagnostics for each plugin
      final plugins = analyzer['plugins'];
      if (plugins is YamlMap) {
        for (final pluginName in pluginNames) {
          final plugin = plugins[pluginName];
          if (plugin is YamlMap) {
            final diagnostics = plugin['diagnostics'];
            if (diagnostics is YamlMap) {
              _parseDiagnostics(diagnostics, ruleOverrides);
            }
          }
        }
      }
    }

    return AnalysisOptionsConfig(
      ruleOverrides: ruleOverrides,
      excludePatterns: excludePatterns,
    );
  }

  /// Filters [allRules] based on [ruleOverrides].
  ///
  /// Rules not mentioned in overrides are kept (enabled by default).
  /// Rules explicitly set to `false` are removed.
  List<AbstractAnalysisRule> filterRules(List<AbstractAnalysisRule> allRules) {
    if (ruleOverrides.isEmpty) return allRules;
    return allRules.where((rule) {
      final override = ruleOverrides[rule.name];
      if (override == null) return true;
      return override.enabled;
    }).toList();
  }

  /// Returns the severity override for [ruleName], or null if not overridden.
  LintSeverity? severityFor(String ruleName) => ruleOverrides[ruleName]?.severity;

  static void _parseDiagnostics(
    YamlMap diagnostics,
    Map<String, RuleOverride> result,
  ) {
    for (final entry in diagnostics.entries) {
      final name = entry.key as String;
      final value = entry.value;

      if (value is bool) {
        result[name] =
            value ? const RuleOverride.enabled() : const RuleOverride.disabled();
      } else if (value is String) {
        final severity = _parseSeverity(value);
        if (severity != null) {
          result[name] = RuleOverride.enabled(severity);
        } else if (value == 'false' || value == 'disable') {
          result[name] = const RuleOverride.disabled();
        }
      }
    }
  }

  static LintSeverity? _parseSeverity(String value) => switch (value) {
        'info' => LintSeverity.info,
        'warning' => LintSeverity.warning,
        'error' => LintSeverity.error,
        _ => null,
      };
}
