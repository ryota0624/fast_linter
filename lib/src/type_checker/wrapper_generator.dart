import 'dart:io';

import 'package:path/path.dart' as p;

/// Generates a wrapper Dart file that imports all target files.
///
/// Used to compile multiple files in a single `dart compile kernel` invocation.
class WrapperGenerator {
  /// The directory where wrapper files are generated.
  final String outputDir;
  String? _lastWrapperPath;

  /// Creates a generator targeting [outputDir].
  WrapperGenerator({required this.outputDir});

  /// Generates a wrapper file importing all [filePaths] and returns its path.
  String generate(List<String> filePaths) {
    final buffer = StringBuffer();
    for (final path in filePaths) {
      final absPath = p.normalize(File(path).absolute.path);
      buffer.writeln("import '$absPath';");
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
