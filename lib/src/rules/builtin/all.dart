import 'package:analyzer/analysis_rule/analysis_rule.dart';
import '../registry.dart';
import 'always_declare_return_types.dart';
import 'avoid_void_async.dart';
import 'directives_ordering.dart';
import 'implementation_imports.dart';
import 'prefer_single_quotes.dart';
import 'public_member_api_docs.dart';
import 'unawaited_futures.dart';

/// Creates a [RuleRegistry] with all forked built-in rules registered.
RuleRegistry createBuiltinRegistry() {
  return RuleRegistry()..registerAll(createBuiltinRules());
}

/// Creates instances of all forked built-in rules.
List<AbstractAnalysisRule> createBuiltinRules() => [
      AlwaysDeclareReturnTypes(),
      AvoidVoidAsync(),
      DirectivesOrdering(),
      ImplementationImports(),
      PreferSingleQuotes(),
      PublicMemberApiDocs(),
      UnawaitedFutures(),
    ];
