// lib/src/type_checker/type_checker.dart

import 'type_diagnostic.dart';

/// Abstract interface for type checking Dart files.
///
/// Two implementations exist:
/// - [FrontEndTypeChecker]: uses package:front_end API directly
/// - [SubprocessTypeChecker]: shells out to `dart compile kernel`
abstract class TypeChecker {
  /// Performs a full type check on the given files.
  Future<List<TypeDiagnostic>> check(List<String> filePaths);

  /// Performs an incremental type check on changed files.
  ///
  /// Uses cached state from a previous [check] or [checkIncremental] call.
  /// Falls back to a full check if no cached state is available.
  Future<List<TypeDiagnostic>> checkIncremental(List<String> changedFilePaths);

  /// Releases resources (e.g., cached .dill files, running processes).
  Future<void> dispose();
}
