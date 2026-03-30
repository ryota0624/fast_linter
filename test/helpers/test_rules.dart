import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity, LintCode;

/// Test rule that accesses [RuleContext.typeProvider], triggering a skip.
class TypeAwareTestRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'type_aware_test_rule',
    'Type-aware test rule',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  TypeAwareTestRule()
      : super(
          name: 'type_aware_test_rule',
          description: 'A test rule that requires type-aware analysis',
        );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    context.typeProvider; // triggers TypeAwareAccessError → rule is skipped
  }
}

/// Test rule: reports optional positional parameters.
class AvoidOptionalPositionalParameters extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_optional_positional_parameters',
    'Avoid optional positional parameters',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  AvoidOptionalPositionalParameters()
      : super(
          name: 'avoid_optional_positional_parameters',
          description: 'Avoid optional positional parameters',
        );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _Visitor(this);
    registry.addFunctionDeclaration(this, visitor);
    registry.addMethodDeclaration(this, visitor);
    registry.addConstructorDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AvoidOptionalPositionalParameters rule;

  _Visitor(this.rule);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final params = node.functionExpression.parameters?.parameters
            .where((p) => p.isOptionalPositional)
            .toList() ??
        [];
    for (final param in params) {
      rule.reportAtNode(param);
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final params = node.parameters?.parameters
            .where((p) => p.isOptionalPositional)
            .toList() ??
        [];
    for (final param in params) {
      rule.reportAtNode(param);
    }
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final params =
        node.parameters.parameters.where((p) => p.isOptionalPositional);
    for (final param in params) {
      rule.reportAtNode(param);
    }
  }
}
