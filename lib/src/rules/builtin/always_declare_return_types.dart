// Forked from dart-lang/sdk pkg/linter/lib/src/rules/always_declare_return_types.dart
// Original: Copyright (c) 2015, the Dart project authors.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'codes.dart' as codes;

/// Lint rule that requires explicit return type declarations.
class AlwaysDeclareReturnTypes extends MultiAnalysisRule {
  /// Creates the always_declare_return_types rule.
  AlwaysDeclareReturnTypes()
      : super(
          name: 'always_declare_return_types',
          description: 'Declare method return types.',
        );

  @override
  List<DiagnosticCode> get diagnosticCodes => [
        codes.alwaysDeclareReturnTypesOfFunctions,
        codes.alwaysDeclareReturnTypesOfMethods,
      ];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _Visitor(this);
    registry.addFunctionDeclaration(this, visitor);
    registry.addFunctionTypeAlias(this, visitor);
    registry.addMethodDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final MultiAnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (!node.isSetter && node.returnType == null) {
      rule.reportAtToken(
        node.name,
        arguments: [node.name.lexeme],
        diagnosticCode: codes.alwaysDeclareReturnTypesOfFunctions,
      );
    }
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    if (node.returnType == null) {
      rule.reportAtToken(
        node.name,
        arguments: [node.name.lexeme],
        diagnosticCode: codes.alwaysDeclareReturnTypesOfFunctions,
      );
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.returnType != null) return;
    if (node.isSetter) return;
    if (node.name.type == TokenType.INDEX_EQ) return;

    rule.reportAtToken(
      node.name,
      arguments: [node.name.lexeme],
      diagnosticCode: codes.alwaysDeclareReturnTypesOfMethods,
    );
  }
}
