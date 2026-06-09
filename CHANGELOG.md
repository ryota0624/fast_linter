## 0.3.0

- Merge pull request #4 from ryota0624/copilot/fast-linter-mcp-cli-dart-activation
- fix: reorder LSP imports for CI
- Fix CI lint errors
- Centralize reported version
- Add global executable support
- fix README
- update CHANGELOG
- update version
- Merge pull request #3 from ryota0624/fix/type-checker-path-resolution
- feat: add type_check tool to MCP server
- fix: avoid mutating unmodifiable ArgResults.rest list
- refactor: detect part-of files by content instead of suffix list
- fix: exclude .mustache.dart from type checker wrapper imports
- fix: resolve type duplication and part-of import errors in type checker
- fix: resolve type checker path issues for workspace and subdirectory targets
- fix: resolve path double-joining in type checker wrapper generation
- Merge pull request #2 from ryota0624/feat/type-checker
- docs: add type checking usage to README
- Remove obsolete develop.md and handoff_doc.md docs
- chore: prepare for pub.dev publish (v0.1.0)
- fix: remove unused type_diagnostic import in CLI
- docs: add MCP server setup instructions to README
- feat: integrate type checking with debounce into LSP server
- feat: add --type-check, --no-lint, --debounce-ms flags to CLI
- fix: add missing doc comment to SubprocessTypeChecker constructor
- feat: add TypeChecker factory and exports
- fix: remove unused stream_channel import in MCP server
- feat: add SubprocessTypeChecker using dart compile kernel
- fix: use super parameter in MCP server and add missing doc comments
- feat: add WrapperGenerator for multi-file type checking
- fix: correct TypeDiagnostic to match spec and add tests
- fix: resolve all dart analyze info-level violations and enable --fatal-infos
- feat: add TypeDiagnostic data model and TypeChecker abstract interface
- fix: resolve all fast_linter violations in lib/
- feat: add verify skill to run actrun after code changes
- Update .gitignore and remove builtin_lint_rules_research.md
- Update .pubignore to exclude docs/superpowers and _build
- feat: add fast_linter step to CI workflow and enable builtin rules in CLI
- fix: resolve dart analyze errors and warnings in CI
- feat: include skipped_rules in analyze_files response
- feat: add --mcp flag to CLI for MCP server mode
- feat: add get_config tool to MCP server
- fix: correct filesAnalyzed count with exclude patterns and eliminate double typeSync
- feat: add analyze_files tool to MCP server
- fix: use package import in MCP server test
- fix: MCP server spec compliance for constructor params and list_rules response
- feat: add FastLintMcpServer with list_rules tool
- chore: add .claude/ to .gitignore for local-only agent docs
- chore: add dart_mcp dependency for MCP server support
- refactor: remove FastLintConfig and fast_lint.yaml support
- feat: add implementation_imports rule (AST approximation)
- feat: fork 6 built-in lint rules from dart-lang/sdk
- chore: remove internal project references and add packaging files
- feat: add linter:rules: parsing and RuleRegistry for official lint rules
- feat: add multi-plugin support with PluginDescriptor
- feat: fast_linter - AST-only Dart linter with compatibility layer

## 0.2.0

- Added `--mcp` flag to run in MCP server mode, providing tools like `analyze_files`, `list_rules`, and `get_config`.
- Integrated type checking with the `--type-check` flag, allowing rules to access type information during analysis.
- Updated built-in lint rules to include 7 rules forked from the dart-lang/sdk repository, enhancing the default rule set available to users.

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
