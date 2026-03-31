## 0.1.0

- MCP server mode (`--mcp` flag) with `analyze_files`, `list_rules`, `get_config` tools.
- Built-in lint rules (7 rules forked from dart-lang/sdk).
- Type checker integration (`--type-check` flag).

## 0.0.1

- AST-only analysis engine using `parseString()` (no type resolution).
- Compatibility layer for existing `AbstractAnalysisRule` lint rules.
- CLI entry points: `runCli()` and `runCliWithPlugins()`.
- Multi-plugin support with `PluginDescriptor`.
- LSP server mode (`--lsp` flag).
- `analysis_options.yaml` configuration support (severity overrides, exclude patterns, `include:` resolution).
- Isolate-based parallel file analysis.
- Inline ignore comments (`// ignore:` and `// ignore_for_file:`).
