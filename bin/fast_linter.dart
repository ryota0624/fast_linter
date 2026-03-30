import 'package:fast_linter/fast_linter.dart';

/// Entry point for the fast_linter CLI.
///
/// To use with your own rules, create a separate Dart executable that
/// calls [runCli] with your rule instances:
///
/// ```dart
/// import 'package:fast_linter/fast_linter.dart';
/// import 'package:my_rules/rules.dart';
///
/// void main(List<String> args) {
///   runCli(args, rules: [MyRule1(), MyRule2()]);
/// }
/// ```
void main(List<String> args) {
  // No built-in rules; this is a placeholder.
  // Users should create their own entry point with their rules.
  runCli(args, rules: []);
}
