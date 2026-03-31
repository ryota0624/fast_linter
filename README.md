# fast_linter

AST-only Dart linter for speed. Skips type analysis entirely — uses only `package:analyzer`'s `parseString()`, not `AnalysisServer` or `AnalysisDriver`.

Existing `AbstractAnalysisRule`-based lint rules (those that don't need type information) work **without code changes** through a compatibility layer.

## Why

`dart analyze` performs full type resolution, which is slow on large codebases. Many useful lint rules only inspect the AST and don't need type information. `fast_linter` runs those rules directly on parsed ASTs, giving you fast feedback in CI and editors.

## Limitations

**Type-aware linting is intentionally unsupported.** `fast_linter` only parses source code into an AST — it does not perform type resolution. Rules that access type information (e.g. `typeProvider`, `typeSystem` on `RuleContext`) will be automatically detected and skipped at runtime, with a warning reported to the user. This is a deliberate design choice: by excluding type analysis, `fast_linter` achieves significantly faster execution than `dart analyze`.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  fast_linter: ^0.0.1
```

```bash
dart pub get
```

## Usage

### Creating a custom linter executable

`fast_linter` is a framework — you bring your own rules. Create an executable that wires up your rules:

```dart
import 'package:fast_linter/fast_linter.dart';
import 'package:my_rules/rules.dart';

List<AbstractAnalysisRule> createRules() => [MyRule1(), MyRule2()];

void main(List<String> args) {
  runCli(args,
    rules: createRules(),
    ruleFactory: createRules,   // enables Isolate-based parallelism
    pluginName: 'my_lint',      // matches analysis_options.yaml plugin name
  );
}
```

### Multi-plugin support

Compose multiple lint plugins into a single executable using `PluginDescriptor`:

```dart
import 'package:fast_linter/fast_linter.dart';
import 'package:my_lint/fast_linter_plugin.dart' as my_lint;
import 'package:another_lint/fast_linter_plugin.dart' as another;

void main(List<String> args) {
  runCliWithPlugins(args, plugins: [my_lint.plugin, another.plugin]);
}
```

Each plugin package exports a `PluginDescriptor`:

```dart
import 'package:fast_linter/fast_linter.dart';

final plugin = (
  name: 'my_lint',
  createRules: createAllRules,
);

List<AbstractAnalysisRule> createAllRules() => [MyRule(), AnotherRule()];
```

### CLI options

```
Usage: fast_linter [options] [paths...]

-h, --help          Show usage.
    --version       Print version.
    --lsp           Run as LSP server.
    --mcp           Run as MCP server.
    --type-check    Enable type checking.
    --no-lint       Skip lint analysis (use with --type-check).
    --debounce-ms   Debounce interval for LSP type checking (ms). [default: 500]
-v, --verbose       Show verbose output.
```

### Type checking

`--type-check` enables type checking via `dart compile kernel` (CFE). This is significantly faster than `dart analyze` while still catching type errors.

```bash
# Lint + type check
dart run bin/my_linter.dart --type-check lib/

# Type check only (skip linting)
dart run bin/my_linter.dart --type-check --no-lint lib/

# Multiple paths
dart run bin/my_linter.dart --type-check lib/ test/
```

Benchmark on a ~3000-file project:

| Method | Time |
|--------|------|
| `fast_linter --type-check` | ~55s |
| `dart analyze` | ~180s |

Type check results are cached in `.dart_tool/fast_linter/`.

### LSP mode

Run with `--lsp` to start a JSON-RPC 2.0 LSP server over stdio. It publishes diagnostics on `textDocument/didOpen` and `textDocument/didChange`.

Type checking can be enabled in LSP mode with debounce control:

```bash
dart run bin/my_linter.dart --lsp --type-check --debounce-ms 300
```

Lint diagnostics are published immediately. Type check diagnostics are debounced (default 500ms) and merged into the same `publishDiagnostics` notification.

### MCP server mode

Run with `--mcp` to start a [Model Context Protocol](https://modelcontextprotocol.io/) server over stdio. This allows AI agents (Claude Code, etc.) and MCP-compatible IDEs to invoke lint analysis programmatically.

```bash
dart run bin/my_linter.dart --mcp
```

#### Provided tools

| Tool | Description |
|------|-------------|
| `analyze_files` | Analyze Dart files/directories and return diagnostics with severity filtering |
| `list_rules` | List all registered lint rules with enabled/severity status |
| `get_config` | Get current linter configuration (rule overrides, exclude patterns) |

#### Setting up with Claude Code

Add the following to your Claude Code MCP settings (`~/.claude/claude_desktop_config.json` or project `.claude/settings.json`):

```json
{
  "mcpServers": {
    "fast_linter": {
      "command": "dart",
      "args": ["run", "/path/to/your/bin/my_linter.dart", "--mcp"]
    }
  }
}
```

Replace `/path/to/your/bin/my_linter.dart` with the path to your custom linter executable.

#### Example: analyze_files

Request:
```json
{
  "name": "analyze_files",
  "arguments": {
    "paths": ["lib/"],
    "severity_filter": "warning"
  }
}
```

Response:
```json
{
  "diagnostics": [
    {
      "file": "lib/src/foo.dart",
      "line": 10,
      "column": 3,
      "severity": "warning",
      "code": "avoid_void_async",
      "message": "Avoid async functions that return void."
    }
  ],
  "skipped_rules": [],
  "summary": {
    "files_analyzed": 5,
    "total_diagnostics": 1,
    "by_severity": { "info": 0, "warning": 1, "error": 0 }
  }
}
```

## Configuration

### analysis_options.yaml

Configure rule severity and exclusions per plugin:

```yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "build/**"
  plugins:
    my_lint:
      diagnostics:
        my_rule_name: warning    # info | warning | error | ignore
        another_rule: ignore
```

### Ignore comments

Suppress diagnostics inline:

```dart
// ignore: my_rule_name
final x = badCode();
```

Or for an entire file:

```dart
// ignore_for_file: my_rule_name
```

## Architecture

```
[AbstractAnalysisRule rules] ← no code changes needed
      |
[Compatibility layer] (lib/src/compat/)
  - DiagnosticCollector: ErrorReporter impl, collects diagnostics
  - FastRuleContext: RuleContext stub (type-aware ops throw UnimplementedError)
      |
[LintRunner] (lib/src/engine/runner.dart)
  parseString() -> RuleVisitorRegistry -> AST walk -> List<LintDiagnostic>
      |                |
  [CLI output]    [LSP notifications]    [MCP tools]
```

### Key components

| Component | Path | Description |
|-----------|------|-------------|
| **LintRunner** | `lib/src/engine/runner.dart` | Core analysis engine. `runOnFile` / `runOnSource` / `runOnDirectory`. Isolate-based parallelism. |
| **CLI** | `lib/src/cli/main.dart` | `runCli()` and `runCliWithPlugins()`. `--lsp` flag starts LSP mode. |
| **LSP Server** | `lib/src/lsp/server.dart` | Minimal JSON-RPC 2.0 LSP over stdio. |
| **MCP Server** | `lib/src/mcp/server.dart` | MCP server with `analyze_files`, `list_rules`, `get_config` tools. |
| **Type Checker** | `lib/src/type_checker/` | Fast type checking via `dart compile kernel`. `SubprocessTypeChecker` implementation. |
| **Config** | `lib/src/config/` | `analysis_options.yaml` rule overrides, exclude patterns, `include:` directive resolution. |
| **Plugin** | `lib/src/plugin/plugin.dart` | `PluginDescriptor` typedef for multi-plugin composition. |
| **Compat** | `lib/src/compat/` | Compatibility layer for existing `AbstractAnalysisRule` rules. |

## Development

```bash
dart pub get                    # install dependencies
dart test                       # run all tests
dart test test/runner_test.dart # run a single test file
dart test -n "test name"        # filter by test name
dart analyze                    # static analysis
```

## License

See [LICENSE](LICENSE) for details.
