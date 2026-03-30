// Forked from dart-lang/sdk pkg/linter/lib/src/rules/unawaited_futures.dart
// Original: Copyright (c) 2016, the Dart project authors.
//
// NOTE: This rule requires type resolution to properly detect Future types.
// This is a placeholder that registers as a known rule but reports nothing
// in AST-only mode. When fast_linter gains type resolution support, this
// can be upgraded to the full implementation.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import 'codes.dart' as codes;

class UnawaitedFutures extends AnalysisRule {
  UnawaitedFutures()
      : super(
          name: 'unawaited_futures',
          description:
              '`Future` results in `async` function bodies must be '
              '`await`ed or marked `unawaited` using `dart:async`.',
        );

  @override
  DiagnosticCode get diagnosticCode => codes.unawaitedFutures;

  @override
  bool get canUseParsedResult => false;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // No-op: this rule requires type resolution which is not available
    // in fast_linter's AST-only mode.
  }
}
