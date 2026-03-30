import 'package:analyzer/analysis_rule/analysis_rule.dart';
import '../config/analysis_options_config.dart';

/// Registry that maps rule names to rule instances.
///
/// Used to resolve rules from `linter: rules:` in analysis_options.yaml.
///
/// ```dart
/// final registry = RuleRegistry()
///   ..registerAll([CamelCaseTypes(), PreferSingleQuotes()]);
///
/// final enabledRules = registry.resolveEnabled(config.linterRules);
/// ```
class RuleRegistry {
  final Map<String, AbstractAnalysisRule> _rules = {};

  /// All registered rule names.
  Iterable<String> get names => _rules.keys;

  /// Number of registered rules.
  int get length => _rules.length;

  /// Registers a single rule. Overwrites any existing rule with the same name.
  void register(AbstractAnalysisRule rule) {
    _rules[rule.name] = rule;
  }

  /// Registers multiple rules.
  void registerAll(Iterable<AbstractAnalysisRule> rules) {
    for (final rule in rules) {
      register(rule);
    }
  }

  /// Returns the rule instance for [name], or null if not registered.
  AbstractAnalysisRule? getByName(String name) => _rules[name];

  /// Resolves enabled rules from [linterRules] config.
  ///
  /// Only rules that are:
  /// 1. Registered in this registry, AND
  /// 2. Enabled in [linterRules]
  ///
  /// are returned. Rules not in [linterRules] are treated as disabled
  /// (opposite of plugin rules which default to enabled).
  List<AbstractAnalysisRule> resolveEnabled(
      Map<String, RuleOverride> linterRules) {
    final result = <AbstractAnalysisRule>[];
    for (final entry in linterRules.entries) {
      if (!entry.value.enabled) continue;
      final rule = _rules[entry.key];
      if (rule != null) {
        result.add(rule);
      }
    }
    return result;
  }

  /// Returns the names of rules that are in [linterRules] config but
  /// not registered in this registry.
  Set<String> unregisteredNames(Map<String, RuleOverride> linterRules) {
    return {
      for (final entry in linterRules.entries)
        if (entry.value.enabled && !_rules.containsKey(entry.key)) entry.key,
    };
  }
}
