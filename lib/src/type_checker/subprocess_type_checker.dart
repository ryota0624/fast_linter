import 'dart:io';

import 'type_checker.dart';
import 'type_diagnostic.dart';
import 'wrapper_generator.dart';

/// Type checker that shells out to `dart compile kernel`.
///
/// Does not support true incremental compilation — [checkIncremental]
/// delegates to [check] (full rebuild each time).
class SubprocessTypeChecker implements TypeChecker {
  final String _cacheDir;
  late final WrapperGenerator _wrapper;

  /// Creates a type checker that caches results in [cacheDir].
  SubprocessTypeChecker({required String cacheDir}) : _cacheDir = cacheDir {
    _wrapper = WrapperGenerator(outputDir: cacheDir);
  }

  @override
  Future<List<TypeDiagnostic>> check(List<String> filePaths) async {
    final wrapperPath = _wrapper.generate(filePaths);
    final outputPath = '$_cacheDir/type_check.dill';

    final result = await Process.run(
      Platform.resolvedExecutable,
      ['compile', 'kernel', '--output=$outputPath', wrapperPath],
    );

    final diagnostics = <TypeDiagnostic>[];
    final stderr = result.stderr as String;
    for (final line in stderr.split('\n')) {
      final d = parseDiagnosticLine(line);
      if (d != null) {
        diagnostics.add(d);
      }
    }

    // Also parse stdout — some CFE versions write diagnostics there.
    final stdout = result.stdout as String;
    for (final line in stdout.split('\n')) {
      final d = parseDiagnosticLine(line);
      if (d != null) {
        diagnostics.add(d);
      }
    }

    return diagnostics;
  }

  @override
  Future<List<TypeDiagnostic>> checkIncremental(
      List<String> changedFilePaths) async {
    return check(changedFilePaths);
  }

  @override
  Future<void> dispose() async {
    _wrapper.cleanup();
    final cacheDir = Directory(_cacheDir);
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  }
}

/// Regex for CFE diagnostic output: `file:line:col: Severity: message`
final _diagnosticPattern =
    RegExp(r'^(.+):(\d+):(\d+): (Error|Warning): (.+)$');

/// Parses a single line of CFE diagnostic output into a [TypeDiagnostic].
///
/// Returns null if the line is not a diagnostic.
TypeDiagnostic? parseDiagnosticLine(String line) {
  final match = _diagnosticPattern.firstMatch(line);
  if (match == null) return null;

  return TypeDiagnostic(
    filePath: match.group(1)!,
    line: int.parse(match.group(2)!),
    column: int.parse(match.group(3)!),
    severity:
        match.group(4)! == 'Error' ? TypeSeverity.error : TypeSeverity.warning,
    message: match.group(5)!,
    length: 0,
  );
}
