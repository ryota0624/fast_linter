// Forked from dart-lang/sdk pkg/linter/lib/src/rules/implementation_imports.dart
// Original: Copyright (c) 2015, the Dart project authors.
//
// AST-only approximation: determines own package name from file path
// instead of resolved libraryElement.uri.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'codes.dart' as codes;

class ImplementationImports extends AnalysisRule {
  ImplementationImports()
      : super(
          name: 'implementation_imports',
          description: "Don't import implementation files from another package.",
        );

  @override
  DiagnosticCode get diagnosticCode => codes.implementationImports;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final path = context.currentUnit?.file.path;
    if (path == null) return;

    // Infer own package name from file path.
    // Looks for /packages/<name>/ or /lib/ pattern.
    final ownPackage = _inferPackageName(path);

    var visitor = _Visitor(this, ownPackage);
    registry.addImportDirective(this, visitor);
  }

  static String? _inferPackageName(String path) {
    // Match: .../packages/<name>/lib/... or .../packages/<name>/test/...
    final packagesMatch =
        RegExp(r'/packages/([^/]+)/(?:lib|test|bin)/').firstMatch(path);
    if (packagesMatch != null) return packagesMatch.group(1);

    // Match: .../<name>/lib/...
    final libMatch = RegExp(r'/([^/]+)/lib/').firstMatch(path);
    if (libMatch != null) return libMatch.group(1);

    return null;
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final String? ownPackage;

  _Visitor(this.rule, this.ownPackage);

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri == null) return;

    // Only check package: imports
    if (!uri.startsWith('package:')) return;

    // Must be importing from /src/
    if (!uri.contains('/src/')) return;

    // Extract package name from import URI: package:<name>/src/...
    final slash = uri.indexOf('/');
    if (slash == -1) return;
    final importPackage = uri.substring('package:'.length, slash);

    // Same package is ok
    if (importPackage == ownPackage) return;

    rule.reportAtNode(node.uri);
  }
}
