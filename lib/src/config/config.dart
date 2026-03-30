import 'dart:io';

import 'analysis_options_config.dart';
import 'analysis_options_reader.dart';

/// Resolves configuration from `analysis_options.yaml`.
///
/// Returns [AnalysisOptionsConfig.empty] if no config file is found
/// or [pluginName] is not provided.
AnalysisOptionsConfig resolveConfig(
  Directory dir, {
  String? pluginName,
}) {
  if (pluginName != null) {
    return resolveConfigForPlugins(dir, pluginNames: [pluginName]);
  }
  return AnalysisOptionsConfig.empty;
}

/// Resolves configuration for multiple plugins from `analysis_options.yaml`.
///
/// Merges config from all [pluginNames] sections.
/// Returns [AnalysisOptionsConfig.empty] if no config file is found.
AnalysisOptionsConfig resolveConfigForPlugins(
  Directory dir, {
  required List<String> pluginNames,
}) {
  if (pluginNames.isNotEmpty) {
    final analysisConfig = AnalysisOptionsReader.findAndLoadMulti(
      dir,
      pluginNames: pluginNames,
    );
    if (analysisConfig != null) return analysisConfig;
  }

  return AnalysisOptionsConfig.empty;
}
