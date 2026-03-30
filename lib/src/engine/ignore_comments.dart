/// Parses `// ignore:` and `// ignore_for_file:` comments from source code.
class IgnoreInfo {
  /// Rule names ignored for the entire file.
  final Set<String> _fileIgnores;

  /// Rule names ignored for specific lines (1-based line number → set of codes).
  final Map<int, Set<String>> _lineIgnores;

  IgnoreInfo._(this._fileIgnores, this._lineIgnores);

  /// Parses ignore comments from [source].
  factory IgnoreInfo.parse(String source) {
    final fileIgnores = <String>{};
    final lineIgnores = <int, Set<String>>{};
    final lines = source.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lineNumber = i + 1; // 1-based

      // // ignore_for_file: code1, code2
      final fileMatch = _ignoreForFilePattern.firstMatch(line);
      if (fileMatch != null) {
        fileIgnores.addAll(_parseCodes(fileMatch.group(1)!));
        continue;
      }

      // // ignore: code1, code2
      final lineMatch = _ignorePattern.firstMatch(line);
      if (lineMatch != null) {
        final codes = _parseCodes(lineMatch.group(1)!);
        // ignore comment applies to the NEXT line
        (lineIgnores[lineNumber + 1] ??= {}).addAll(codes);
      }

      // Inline: someCode(); // ignore: code1
      final inlineMatch = _inlineIgnorePattern.firstMatch(line);
      if (inlineMatch != null) {
        final codes = _parseCodes(inlineMatch.group(1)!);
        (lineIgnores[lineNumber] ??= {}).addAll(codes);
      }
    }

    return IgnoreInfo._(fileIgnores, lineIgnores);
  }

  /// Returns true if [code] should be ignored at [line] (1-based).
  bool isIgnored(String code, int line) {
    if (_fileIgnores.contains(code)) return true;
    final lineSet = _lineIgnores[line];
    if (lineSet == null) return false;
    return lineSet.contains(code);
  }

  static List<String> _parseCodes(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim())
        // Handle prefixed codes like "my_lint/avoid_foo" → "avoid_foo"
        .map((s) => s.contains('/') ? s.split('/').last : s)
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // Matches: // ignore_for_file: code1, code2
  static final _ignoreForFilePattern =
      RegExp(r'^//\s*ignore_for_file:\s*(.+)$');

  // Matches standalone: // ignore: code1, code2  (line is only comment)
  static final _ignorePattern =
      RegExp(r'^//\s*ignore:\s*(.+)$');

  // Matches inline: <code> // ignore: code1, code2
  static final _inlineIgnorePattern =
      RegExp(r'\S.*//\s*ignore:\s*(.+)$');
}
