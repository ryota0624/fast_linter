import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:path/path.dart' as p;

/// Thrown when a rule accesses a type-aware property on [FastRuleContext].
class TypeAwareAccessError extends UnimplementedError {
  /// The [RuleContext] member that was accessed (e.g. `typeProvider`).
  final String member;

  /// Creates a [TypeAwareAccessError] for the given [member].
  TypeAwareAccessError({required this.member, required String message})
      : super(message);
}

/// Minimal [RuleContext] for parsed-only (type-unaware) analysis.
///
/// Supports [currentUnit] (used by most rules for file-path checks) but
/// throws on type-system properties like [typeProvider] and [typeSystem].
class FastRuleContext implements RuleContext {
  RuleContextUnit? _currentUnit;

  @override
  RuleContextUnit? get currentUnit => _currentUnit;

  @override
  RuleContextUnit get definingUnit =>
      _currentUnit ?? (throw StateError('No unit set'));

  @override
  List<RuleContextUnit> get allUnits =>
      _currentUnit != null ? [_currentUnit!] : [];

  @override
  bool get isInLibDir => false;

  @override
  bool get isInTestDirectory => false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = '${invocation.memberName}'.replaceAll('Symbol("', '').replaceAll('")', '');
    throw TypeAwareAccessError(
      member: memberName,
      message: 'RuleContext.$memberName is not supported in fast_linter. '
          'This rule requires type-aware analysis.',
    );
  }

  /// Sets up [currentUnit] for the given file.
  void setCurrentUnit({
    required String filePath,
    required String source,
    required CompilationUnit unit,
    required DiagnosticReporter reporter,
  }) {
    final absolutePath = p.isAbsolute(filePath) ? filePath : p.absolute(filePath);
    final resourceProvider = MemoryResourceProvider();
    resourceProvider.newFile(absolutePath, source);
    final file = resourceProvider.getFile(absolutePath);
    _currentUnit = RuleContextUnit(
      file: file,
      content: source,
      diagnosticReporter: reporter,
      unit: unit,
    );
  }
}
