import 'package:path/path.dart' as p;

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
  final normalized = p.normalize(projectDir);
  final cacheDir = p.join(normalized, '.dart_tool', 'fast_linter');
  return SubprocessTypeChecker(
    projectDir: normalized,
    cacheDir: cacheDir,
  );
}
