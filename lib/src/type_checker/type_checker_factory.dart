import 'dart:io';

import 'package:path/path.dart' as p;

import 'subprocess_type_checker.dart';
import 'type_checker.dart';

/// Creates a [TypeChecker] instance.
///
/// Uses [SubprocessTypeChecker] which shells out to `dart compile kernel`.
///
/// [projectDir] is the project root directory (typically CWD).
/// The cache directory is placed under `{projectDir}/.dart_tool/fast_linter/`.
/// `.dart_tool/package_config.json` is discovered by walking up from
/// [projectDir] to support Dart workspace layouts.
Future<TypeChecker> createTypeChecker({
  required String projectDir,
}) async {
  final normalized = p.normalize(projectDir);
  final cacheDir = p.join(normalized, '.dart_tool', 'fast_linter');
  final packagesPath = _findPackageConfig(normalized);
  return SubprocessTypeChecker(
    cacheDir: cacheDir,
    packagesPath: packagesPath,
  );
}

/// Walks up from [startDir] to find `.dart_tool/package_config.json`.
///
/// Returns the path if found, or `null` if not found (in which case
/// `dart compile kernel` will try its own default resolution).
String? _findPackageConfig(String startDir) {
  var current = p.normalize(p.absolute(startDir));
  while (true) {
    final candidate = p.join(current, '.dart_tool', 'package_config.json');
    if (File(candidate).existsSync()) return candidate;
    final parent = p.dirname(current);
    if (parent == current) break;
    current = parent;
  }
  return null;
}
