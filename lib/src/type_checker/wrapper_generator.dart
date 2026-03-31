import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

/// Matches a `part of` directive in Dart source.
final _partOfPattern = RegExp(r'^\s*part\s+of\b', multiLine: true);

/// Generates a wrapper Dart file that imports all target files.
///
/// Used to compile multiple files in a single `dart compile kernel` invocation.
class WrapperGenerator {
  /// The directory where wrapper files are generated.
  final String outputDir;

  /// Optional package configuration for converting file paths to
  /// `package:` URIs. When provided, files under a package's `lib/`
  /// directory are imported via `package:` URI instead of absolute path,
  /// avoiding type duplication caused by the same library being reachable
  /// through both a file path and a `package:` URI.
  final PackageConfig? packageConfig;

  String? _lastWrapperPath;

  /// Creates a generator targeting [outputDir].
  WrapperGenerator({required this.outputDir, this.packageConfig});

  /// Generates a wrapper file importing all [filePaths] and returns its path.
  ///
  /// Files containing a `part of` directive are excluded because they
  /// cannot be imported directly.
  String generate(List<String> filePaths) {
    final buffer = StringBuffer();
    for (final path in filePaths) {
      if (_isPartFile(path)) continue;

      final importUri = _resolveImportUri(path);
      buffer.writeln("import '$importUri';");
    }
    buffer.writeln();
    buffer.writeln('void main() {}');

    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final wrapperPath = p.join(outputDir, '_fast_linter_wrapper.dart');
    File(wrapperPath).writeAsStringSync(buffer.toString());
    _lastWrapperPath = wrapperPath;
    return wrapperPath;
  }

  /// Resolves the import URI for a file path.
  ///
  /// If [packageConfig] is available and the file is under a package's
  /// `lib/` directory, returns a `package:` URI string.
  /// Otherwise returns the normalized absolute file path.
  String _resolveImportUri(String path) {
    final absPath = p.normalize(File(path).absolute.path);
    final config = packageConfig;
    if (config != null) {
      final fileUri = Uri.file(absPath);
      final packageUri = config.toPackageUri(fileUri);
      if (packageUri != null) {
        return packageUri.toString();
      }
    }
    return absPath;
  }

  /// Returns `true` if [path] is a `part of` file that cannot be imported
  /// directly.
  ///
  /// Only files with a compound extension (e.g. `.g.dart`, `.freezed.dart`,
  /// `.mustache.dart`) are candidates — these are typically code-generated
  /// part files. For those candidates, the file content is parsed to confirm
  /// a `part of` directive is present.
  static bool _isPartFile(String path) {
    // Check for compound extension: basename without .dart still has a dot.
    final basename = p.basenameWithoutExtension(path);
    if (!basename.contains('.')) return false;

    // Compound extension found — read file to confirm `part of`.
    try {
      final content = File(path).readAsStringSync();
      return _partOfPattern.hasMatch(content);
    } catch (_) {
      return false;
    }
  }

  /// Removes the last generated wrapper file.
  void cleanup() {
    final path = _lastWrapperPath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
      _lastWrapperPath = null;
    }
  }
}
