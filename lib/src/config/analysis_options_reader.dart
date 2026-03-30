import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'analysis_options_config.dart';

/// Reads and resolves `analysis_options.yaml` files, including `include:`
/// directives.
class AnalysisOptionsReader {
  /// Finds the nearest `analysis_options.yaml` starting from [dir],
  /// resolves `include:` directives, and extracts config for [pluginName].
  static AnalysisOptionsConfig? findAndLoad(
    Directory dir, {
    required String pluginName,
  }) {
    return findAndLoadMulti(dir, pluginNames: [pluginName]);
  }

  /// Finds the nearest `analysis_options.yaml` starting from [dir],
  /// resolves `include:` directives, and extracts config for multiple plugins.
  static AnalysisOptionsConfig? findAndLoadMulti(
    Directory dir, {
    required List<String> pluginNames,
  }) {
    final file = _findAnalysisOptions(dir);
    if (file == null) return null;

    final merged = _loadAndMerge(file.path, dir);
    if (merged == null) return null;

    return AnalysisOptionsConfig.fromYamlMapMulti(
      merged,
      pluginNames: pluginNames,
    );
  }

  /// Finds the nearest analysis_options.yaml walking up from [dir].
  static File? _findAnalysisOptions(Directory dir) {
    var current = dir;
    while (true) {
      final file = File(p.join(current.path, 'analysis_options.yaml'));
      if (file.existsSync()) return file;
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
    return null;
  }

  /// Loads a YAML file, resolves includes recursively, and returns the
  /// merged result.
  static YamlMap? _loadAndMerge(
    String filePath, [
    Directory? projectDir,
    Set<String>? visited,
  ]) {
    final absPath = p.normalize(p.absolute(filePath));
    visited ??= {};
    if (visited.contains(absPath)) return null; // cycle detection
    visited.add(absPath);

    final file = File(absPath);
    if (!file.existsSync()) return null;

    final content = file.readAsStringSync();
    final doc = loadYaml(content);
    if (doc is! YamlMap) return null;

    final includeValue = doc['include'];
    if (includeValue == null) return doc;

    final fileDir = Directory(p.dirname(absPath));
    final includes = includeValue is List
        ? includeValue.cast<String>()
        : [includeValue as String];

    // Start with includes as base, then overlay current file on top
    var result = YamlMap();
    for (final include in includes) {
      final resolved = _resolveInclude(include, fileDir, projectDir);
      if (resolved == null) continue;

      final included = _loadAndMerge(resolved, projectDir, visited);
      if (included != null) {
        result = _mergeMaps(result, included);
      }
    }

    // Overlay current file (without include key) on top of included configs
    result = _mergeMaps(result, doc);
    return result;
  }

  /// Resolves an include path to an absolute file path.
  static String? _resolveInclude(
    String include,
    Directory fileDir,
    Directory? projectDir,
  ) {
    if (include.startsWith('package:')) {
      return _resolvePackageUri(include, projectDir ?? fileDir);
    }
    // Relative path
    return p.normalize(p.join(fileDir.path, include));
  }

  /// Resolves a `package:` URI using `.dart_tool/package_config.json`.
  static String? _resolvePackageUri(String uri, Directory projectDir) {
    // Parse the URI: package:<package_name>/<path>
    final packageUri = Uri.parse(uri);
    if (packageUri.scheme != 'package') return null;

    final segments = packageUri.pathSegments;
    if (segments.isEmpty) return null;

    final packageName = segments.first;
    final relativePath = segments.skip(1).join('/');

    // Find package_config.json
    final configFile = _findPackageConfig(projectDir);
    if (configFile == null) return null;

    try {
      final configContent = configFile.readAsStringSync();
      final configJson = jsonDecode(configContent) as Map<String, dynamic>;
      final packages = configJson['packages'] as List<dynamic>?;
      if (packages == null) return null;

      for (final pkg in packages) {
        final pkgMap = pkg as Map<String, dynamic>;
        if (pkgMap['name'] == packageName) {
          final rootUri = pkgMap['rootUri'] as String;
          final packageRoot = rootUri.startsWith('file://')
              ? Uri.parse(rootUri).toFilePath()
              : p.normalize(p.join(p.dirname(configFile.path), rootUri));
          return p.join(packageRoot, 'lib', relativePath);
        }
      }
    } catch (_) {
      // Silently fail on parse errors
    }
    return null;
  }

  /// Finds .dart_tool/package_config.json walking up from [dir].
  static File? _findPackageConfig(Directory dir) {
    var current = dir;
    while (true) {
      final file = File(p.join(current.path, '.dart_tool', 'package_config.json'));
      if (file.existsSync()) return file;
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
    return null;
  }

  /// Merges two YamlMaps. [override] values take precedence over [base].
  /// Maps are merged recursively; lists are concatenated (deduplicated).
  static YamlMap _mergeMaps(YamlMap base, YamlMap override) {
    final result = <dynamic, dynamic>{...base};

    for (final entry in override.entries) {
      final key = entry.key;
      if (key == 'include') continue; // Don't propagate include directives

      final baseValue = result[key];
      final overrideValue = entry.value;

      if (baseValue is YamlMap && overrideValue is YamlMap) {
        result[key] = _mergeMaps(baseValue, overrideValue);
      } else if (baseValue is YamlList && overrideValue is YamlList) {
        final merged = [...baseValue, ...overrideValue];
        // Deduplicate (preserve order)
        final seen = <dynamic>{};
        result[key] = YamlList.wrap(
          merged.where((e) => seen.add(e)).toList(),
        );
      } else {
        result[key] = overrideValue;
      }
    }

    return YamlMap.wrap(result);
  }
}
