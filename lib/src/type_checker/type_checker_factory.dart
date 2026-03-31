import 'subprocess_type_checker.dart';
import 'type_checker.dart';

/// Creates a [TypeChecker] instance.
///
/// Uses [SubprocessTypeChecker] which shells out to `dart compile kernel`.
///
/// [projectDir] is used to determine the cache directory
/// (`.dart_tool/fast_linter/`).
Future<TypeChecker> createTypeChecker({
  required String projectDir,
}) async {
  final cacheDir = '$projectDir/.dart_tool/fast_linter';
  return SubprocessTypeChecker(cacheDir: cacheDir);
}
