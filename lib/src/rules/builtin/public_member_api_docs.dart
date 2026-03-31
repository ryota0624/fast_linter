// Forked from dart-lang/sdk pkg/linter/lib/src/rules/public_member_api_docs.dart
// Original: Copyright (c) 2016, the Dart project authors.
//
// AST-only approximation: skips override detection (requires type resolution)
// and package/isInLibDir checks (requires resolved context).

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'codes.dart' as codes;

/// Lint rule that requires doc comments on all public members.
class PublicMemberApiDocs extends AnalysisRule {
  /// Creates the public_member_api_docs rule.
  PublicMemberApiDocs()
      : super(
          name: 'public_member_api_docs',
          description: 'Document all public members.',
        );

  @override
  DiagnosticCode get diagnosticCode => codes.publicMemberApiDocs;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // Only lint files in lib/ (AST approximation: check file path)
    final path = context.currentUnit?.file.path;
    if (path == null || !path.contains('/lib/')) return;

    var visitor = _Visitor(this);
    registry.addClassDeclaration(this, visitor);
    registry.addClassTypeAlias(this, visitor);
    registry.addCompilationUnit(this, visitor);
    registry.addConstructorDeclaration(this, visitor);
    registry.addEnumConstantDeclaration(this, visitor);
    registry.addEnumDeclaration(this, visitor);
    registry.addExtensionDeclaration(this, visitor);
    registry.addExtensionTypeDeclaration(this, visitor);
    registry.addFieldDeclaration(this, visitor);
    registry.addFunctionTypeAlias(this, visitor);
    registry.addGenericTypeAlias(this, visitor);
    registry.addMixinDeclaration(this, visitor);
    registry.addTopLevelVariableDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  bool _check(Declaration node) {
    if (node.documentationComment == null && !_hasOverrideAnnotation(node)) {
      rule.reportAtNode(node);
      return true;
    }
    return false;
  }

  /// AST approximation: check for @override annotation instead of
  /// resolved element.overriddenMember.
  bool _hasOverrideAnnotation(Declaration node) {
    for (final annotation in node.metadata) {
      if (annotation.name.name == 'override') return true;
    }
    return false;
  }

  void _checkMethods(List<ClassMember> members) {
    var getters = <String, MethodDeclaration>{};
    var setters = <MethodDeclaration>[];
    var methods = <MethodDeclaration>[];

    for (var member in members) {
      if (member is MethodDeclaration && !member.name.isPrivate) {
        if (member.isGetter) {
          getters[member.name.lexeme] = member;
        } else if (member.isSetter) {
          setters.add(member);
        } else {
          methods.add(member);
        }
      }
    }

    var missingDocs = <MethodDeclaration>{};
    for (var getter in getters.values) {
      if (_check(getter)) missingDocs.add(getter);
    }
    for (var setter in setters) {
      var getter = getters[setter.name.lexeme];
      if (getter != null && missingDocs.contains(getter)) {
        _check(setter);
      }
    }
    methods.forEach(_check);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.name.isPrivate) return;
    _check(node);
    _checkMethods(node.members);
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    if (!node.name.isPrivate) _check(node);
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    var getters = <String, FunctionDeclaration>{};
    var setters = <FunctionDeclaration>[];
    var functions = <FunctionDeclaration>[];

    for (var member in node.declarations) {
      if (member is FunctionDeclaration) {
        var name = member.name;
        if (!name.isPrivate && name.lexeme != 'main') {
          if (member.isGetter) {
            getters[member.name.lexeme] = member;
          } else if (member.isSetter) {
            setters.add(member);
          } else {
            functions.add(member);
          }
        }
      }
    }

    var missingDocs = <FunctionDeclaration>{};
    for (var getter in getters.values) {
      if (_check(getter)) missingDocs.add(getter);
    }
    for (var setter in setters) {
      var getter = getters[setter.name.lexeme];
      if (getter != null && missingDocs.contains(getter)) {
        _check(setter);
      }
    }
    functions.forEach(_check);

    super.visitCompilationUnit(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final name = node.name;
    if (name != null && name.isPrivate) return;
    var parent = node.parent;
    if (parent is EnumDeclaration) return;
    if (parent is ClassDeclaration && parent.name.isPrivate) return;
    _check(node);
  }

  @override
  void visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    if (!node.name.isPrivate) _check(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    if (node.name.isPrivate) return;
    _check(node);
    _checkMethods(node.members);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final name = node.name;
    if (name == null || name.isPrivate) return;
    _check(node);
    _checkMethods(node.members);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    if (node.name.isPrivate) return;
    _check(node);
    _checkMethods(node.members);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    var parent = node.parent;
    if (parent is ClassDeclaration && parent.name.isPrivate) return;
    for (var field in node.fields.variables) {
      if (!field.name.isPrivate) _check(field);
    }
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    if (!node.name.isPrivate) _check(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    if (!node.name.isPrivate) _check(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    if (node.name.isPrivate) return;
    _check(node);
    _checkMethods(node.members);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (var variable in node.variables.variables) {
      if (!variable.name.isPrivate) _check(variable);
    }
  }
}

extension on Token {
  bool get isPrivate => lexeme.startsWith('_');
}
