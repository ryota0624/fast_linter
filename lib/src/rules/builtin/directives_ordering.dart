// Forked from dart-lang/sdk pkg/linter/lib/src/rules/directives_ordering.dart
// Original: Copyright (c) 2017, the Dart project authors.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'codes.dart' as codes;

/// Compares directives by package name, then file name in the package.
int compareDirectives(String a, String b) {
  if (!a.startsWith('package:') || !b.startsWith('package:')) {
    if (!a.startsWith('/') && !b.startsWith('/')) {
      return a.compareTo(b);
    }
  }
  var indexA = a.indexOf('/');
  var indexB = b.indexOf('/');
  if (indexA == -1 || indexB == -1) return a.compareTo(b);
  var result = a.substring(0, indexA).compareTo(b.substring(0, indexB));
  if (result != 0) return result;
  return a.substring(indexA + 1).compareTo(b.substring(indexB + 1));
}

bool _isAbsoluteDirective(NamespaceDirective node) {
  var uriContent = node.uri.stringValue;
  return uriContent != null && uriContent.contains(':');
}

bool _isDartDirective(NamespaceDirective node) {
  var uriContent = node.uri.stringValue;
  return uriContent != null && uriContent.startsWith('dart:');
}

bool _isExportDirective(Directive node) => node is ExportDirective;

bool _isNotDartDirective(NamespaceDirective node) => !_isDartDirective(node);

bool _isPackageDirective(NamespaceDirective node) {
  var uriContent = node.uri.stringValue;
  return uriContent != null && uriContent.startsWith('package:');
}

bool _isPartDirective(Directive node) => node is PartDirective;

bool _isRelativeDirective(NamespaceDirective node) =>
    !_isAbsoluteDirective(node);

class DirectivesOrdering extends MultiAnalysisRule {
  static const List<DiagnosticCode> allCodes = [
    codes.directivesOrderingAlphabetical,
    codes.directivesOrderingDart,
    codes.directivesOrderingExports,
    codes.directivesOrderingPackageBeforeRelative,
  ];

  DirectivesOrdering()
      : super(
          name: 'directives_ordering',
          description:
              'Adhere to Effective Dart Guide directives sorting conventions.',
        );

  @override
  List<DiagnosticCode> get diagnosticCodes => allCodes;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _Visitor(this);
    registry.addCompilationUnit(this, visitor);
  }

  void _reportDart(AstNode node, String type) {
    reportAtNode(
      node,
      diagnosticCode: codes.directivesOrderingDart,
      arguments: ['${type}s'],
    );
  }

  void _reportAlphabetical(AstNode node) {
    reportAtNode(node, diagnosticCode: codes.directivesOrderingAlphabetical);
  }

  void _reportExports(AstNode node) {
    reportAtNode(node, diagnosticCode: codes.directivesOrderingExports);
  }

  void _reportPackageBeforeRelative(AstNode node, String type) {
    reportAtNode(
      node,
      diagnosticCode: codes.directivesOrderingPackageBeforeRelative,
      arguments: ['${type}s'],
    );
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final DirectivesOrdering rule;

  _Visitor(this.rule);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    var lintedNodes = <AstNode>{};
    _checkDartDirectiveGoFirst(lintedNodes, node);
    _checkPackageDirectiveBeforeRelative(lintedNodes, node);
    _checkExportDirectiveAfterImportDirective(lintedNodes, node);
    _checkDirectiveSectionOrderedAlphabetically(lintedNodes, node);
  }

  void _checkDartDirectiveGoFirst(
    Set<AstNode> lintedNodes,
    CompilationUnit node,
  ) {
    for (var import in node.importDirectives._withDartUrisSkippingFirstSet) {
      if (lintedNodes.add(import)) {
        rule._reportDart(import, 'import');
      }
    }
    for (var export in node.exportDirectives._withDartUrisSkippingFirstSet) {
      if (lintedNodes.add(export)) {
        rule._reportDart(export, 'export');
      }
    }
  }

  void _checkDirectiveSectionOrderedAlphabetically(
    Set<AstNode> lintedNodes,
    CompilationUnit node,
  ) {
    _checkSectionInOrder(
        lintedNodes, node.importDirectives.where(_isDartDirective));
    _checkSectionInOrder(
        lintedNodes, node.exportDirectives.where(_isDartDirective));
    _checkSectionInOrder(
        lintedNodes, node.importDirectives.where(_isRelativeDirective));
    _checkSectionInOrder(
        lintedNodes, node.exportDirectives.where(_isRelativeDirective));
    _checkSectionInOrder(
        lintedNodes, node.importDirectives.where(_isPackageDirective));
    _checkSectionInOrder(
        lintedNodes, node.exportDirectives.where(_isPackageDirective));
  }

  void _checkExportDirectiveAfterImportDirective(
    Set<AstNode> lintedNodes,
    CompilationUnit node,
  ) {
    for (var directive in node.directives.reversed
        .skipWhile(_isPartDirective)
        .skipWhile(_isExportDirective)
        .where(_isExportDirective)) {
      if (lintedNodes.add(directive)) {
        rule._reportExports(directive);
      }
    }
  }

  void _checkPackageDirectiveBeforeRelative(
    Set<AstNode> lintedNodes,
    CompilationUnit node,
  ) {
    for (var import
        in node.importDirectives._withPackageUrisSkippingAbsoluteUris) {
      if (lintedNodes.add(import)) {
        rule._reportPackageBeforeRelative(import, 'import');
      }
    }
    for (var export
        in node.exportDirectives._withPackageUrisSkippingAbsoluteUris) {
      if (lintedNodes.add(export)) {
        rule._reportPackageBeforeRelative(export, 'export');
      }
    }
  }

  void _checkSectionInOrder(
    Set<AstNode> lintedNodes,
    Iterable<UriBasedDirective> nodes,
  ) {
    if (nodes.isEmpty) return;
    var previousUri = nodes.first.uri.stringValue;
    for (var directive in nodes.skip(1)) {
      var directiveUri = directive.uri.stringValue;
      if (previousUri != null &&
          directiveUri != null &&
          compareDirectives(previousUri, directiveUri) > 0) {
        if (lintedNodes.add(directive)) {
          rule._reportAlphabetical(directive);
        }
      }
      previousUri = directive.uri.stringValue;
    }
  }
}

extension on CompilationUnit {
  Iterable<ExportDirective> get exportDirectives =>
      directives.whereType<ExportDirective>();

  Iterable<ImportDirective> get importDirectives =>
      directives.whereType<ImportDirective>();
}

extension on Iterable<NamespaceDirective> {
  Iterable<NamespaceDirective> get _withDartUrisSkippingFirstSet =>
      skipWhile(_isDartDirective).where(_isDartDirective);

  Iterable<NamespaceDirective> get _withPackageUrisSkippingAbsoluteUris =>
      where(_isNotDartDirective)
          .skipWhile(_isAbsoluteDirective)
          .where(_isPackageDirective);
}
