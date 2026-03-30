// ignore_for_file: depend_on_referenced_packages
import 'package:analyzer/src/lint/linter.dart' show AbstractAnalysisRule;
import 'package:fast_linter/fast_linter.dart';

// Import your own AbstractAnalysisRule implementations:
// import 'package:my_rules/rules.dart';

/// Top-level factory for Isolate-based parallelism.
List<AbstractAnalysisRule> createRules() => [
      // MyRule1(),
      // MyRule2(),
    ];

void main(List<String> args) {
  runCli(
    args,
    rules: createRules(),
    ruleFactory: createRules,
    pluginName: 'my_lint',
  );
}
