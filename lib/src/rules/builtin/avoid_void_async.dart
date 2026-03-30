// Forked from dart-lang/sdk pkg/linter/lib/src/rules/avoid_void_async.dart
// Original: Copyright (c) 2018, the Dart project authors.
//
// AST-only approximation: checks for syntactic `void` return type + `async`
// keyword instead of resolved element type. This catches the common case
// but may miss cases where the return type is a typedef or alias for void.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'codes.dart' as codes;

class AvoidVoidAsync extends AnalysisRule {
  AvoidVoidAsync()
      : super(
          name: 'avoid_void_async',
          description: "Avoid `async` functions that return `void`.",
        );

  @override
  DiagnosticCode get diagnosticCode => codes.avoidVoidAsync;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _Visitor(this);
    registry.addFunctionDeclaration(this, visitor);
    registry.addMethodDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Skip main()
    if (node.name.lexeme == 'main' && node.parent is CompilationUnit) return;
    _check(node.returnType, node.functionExpression.body, node.name);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _check(node.returnType, node.body, node.name);
  }

  void _check(TypeAnnotation? returnType, FunctionBody body, dynamic name) {
    if (returnType == null) return;
    if (!body.isAsynchronous) return;
    if (body.isGenerator) return;

    // AST approximation: check if the return type is syntactically "void"
    if (returnType is NamedType && returnType.name.lexeme == 'void') {
      rule.reportAtToken(name);
    }
  }
}
