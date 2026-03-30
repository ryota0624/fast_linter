// Forked from dart-lang/sdk pkg/linter/lib/src/rules/prefer_single_quotes.dart
// Original: Copyright (c) 2017, the Dart project authors.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'codes.dart' as codes;

class PreferSingleQuotes extends AnalysisRule {
  PreferSingleQuotes()
      : super(
          name: 'prefer_single_quotes',
          description:
              'Only use double quotes for strings containing single quotes.',
        );

  @override
  DiagnosticCode get diagnosticCode => codes.preferSingleQuotes;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _QuoteVisitor(this);
    registry.addSimpleStringLiteral(this, visitor);
    registry.addStringInterpolation(this, visitor);
  }
}

class _QuoteVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _QuoteVisitor(this.rule);

  bool _isNestedString(AstNode node) =>
      node.parent?.thisOrAncestorOfType<StringInterpolation>() != null;

  bool _containsString(StringInterpolation string) {
    var visitor = _IsOrContainsStringVisitor();
    return string.elements.any((child) => child.accept(visitor) ?? false);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.isSingleQuoted || node.value.contains("'")) return;
    if (!_isNestedString(node)) {
      rule.reportAtToken(node.literal);
    }
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    if (node.isSingleQuoted) return;
    if (node.elements.any(
      (e) => e is InterpolationString && e.value.contains("'"),
    )) {
      return;
    }
    if (!_containsString(node) && !_isNestedString(node)) {
      rule.reportAtNode(node);
    }
  }
}

class _IsOrContainsStringVisitor extends UnifyingAstVisitor<bool> {
  @override
  bool visitNode(AstNode node) {
    var children = <AstNode>[];
    node.visitChildren(_ChildCollector(children));
    return children.any((child) => child.accept(this) ?? false);
  }

  @override
  bool visitSimpleStringLiteral(SimpleStringLiteral string) => true;

  @override
  bool visitStringInterpolation(StringInterpolation string) => true;
}

class _ChildCollector extends UnifyingAstVisitor<void> {
  final List<AstNode> children;
  _ChildCollector(this.children);

  @override
  void visitNode(AstNode node) => children.add(node);
}
