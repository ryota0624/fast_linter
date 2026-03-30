import '../engine/runner.dart';

/// A lint plugin descriptor that bundles a plugin name with its rule factory.
///
/// Each lint package should export a top-level `plugin` constant from
/// `package:<name>/fast_linter_plugin.dart`:
///
/// ```dart
/// import 'package:analyzer/analysis_rule/analysis_rule.dart';
///
/// final plugin = (
///   name: 'my_lint',
///   createRules: createAllRules,
/// );
///
/// List<AbstractAnalysisRule> createAllRules() => [MyRule(), AnotherRule()];
/// ```
typedef PluginDescriptor = ({
  String name,
  RuleFactory createRules,
});
