/// LintCode constants for forked built-in rules.
///
/// These mirror the diagnostic codes from dart-lang/sdk pkg/linter.
import 'package:analyzer/error/error.dart' show DiagnosticSeverity, LintCode;

// directives_ordering (MultiAnalysisRule)
const directivesOrderingAlphabetical = LintCode(
  'directives_ordering',
  'Sort directive sections alphabetically.',
  uniqueName: 'LintCode.directives_ordering_alphabetical',
  severity: DiagnosticSeverity.INFO,
);

const directivesOrderingDart = LintCode(
  'directives_ordering',
  'Place \'dart:\' {0} before other {0}.',
  uniqueName: 'LintCode.directives_ordering_dart',
  severity: DiagnosticSeverity.INFO,
);

const directivesOrderingExports = LintCode(
  'directives_ordering',
  'Specify exports in a separate section after all imports.',
  uniqueName: 'LintCode.directives_ordering_exports',
  severity: DiagnosticSeverity.INFO,
);

const directivesOrderingPackageBeforeRelative = LintCode(
  'directives_ordering',
  'Place \'package:\' {0} before relative {0}.',
  uniqueName: 'LintCode.directives_ordering_package_before_relative',
  severity: DiagnosticSeverity.INFO,
);

// prefer_single_quotes
const preferSingleQuotes = LintCode(
  'prefer_single_quotes',
  'Only use double quotes for strings containing single quotes.',
  severity: DiagnosticSeverity.INFO,
);

// always_declare_return_types (MultiAnalysisRule)
const alwaysDeclareReturnTypesOfFunctions = LintCode(
  'always_declare_return_types',
  "The function '{0}' should have a return type but doesn't.",
  uniqueName: 'LintCode.always_declare_return_types_of_functions',
  severity: DiagnosticSeverity.INFO,
);

const alwaysDeclareReturnTypesOfMethods = LintCode(
  'always_declare_return_types',
  "The method '{0}' should have a return type but doesn't.",
  uniqueName: 'LintCode.always_declare_return_types_of_methods',
  severity: DiagnosticSeverity.INFO,
);

// public_member_api_docs
const publicMemberApiDocs = LintCode(
  'public_member_api_docs',
  'Document all public members.',
  severity: DiagnosticSeverity.INFO,
);

// avoid_void_async
const avoidVoidAsync = LintCode(
  'avoid_void_async',
  "Avoid `async` functions that return `void`.",
  correctionMessage: "Try returning 'Future<void>' instead.",
  severity: DiagnosticSeverity.INFO,
);

// unawaited_futures
const unawaitedFutures = LintCode(
  'unawaited_futures',
  '`Future` results in `async` function bodies must be '
      '`await`ed or marked `unawaited` using `dart:async`.',
  severity: DiagnosticSeverity.INFO,
);
