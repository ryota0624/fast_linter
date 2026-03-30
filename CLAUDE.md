# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dartの高速linter。`dart analyze`は型解析(type-aware)で遅いため、ASTのみを使ったtype-unawareな高速linterをDartで実装している。`package:analyzer`のパーサー(`parseString()`)のみ借用し、`AnalysisServer`/`AnalysisDriver`は使わない。

既存の`AnalysisRule`ベースのlintルール(型情報不要なもの)をコード修正なしで再利用できる互換レイヤーを持つ。

## Commands

```bash
dart pub get                    # 依存パッケージ取得
dart test                       # 全テスト実行
dart test test/runner_test.dart # 単一テストファイル実行
dart test -n "test name"        # テスト名でフィルタ
dart analyze                    # 静的解析（Dart MCP利用時はmcp__dart__analyze_filesを優先）
dart run bin/fast_linter.dart   # CLI実行（ルールなしのプレースホルダー）
dart run bin/smoke_test.dart    # 外部ルールパッケージとの統合テスト
```

## Architecture

### 実行フロー
```
[既存AnalysisRuleルール群] ← コード変更なし
      ↓
[互換レイヤー] (lib/src/compat/)
  - DiagnosticCollector: ErrorReporter実装、diagnostics収集
  - FastRuleContext: RuleContextスタブ（type-aware操作はUnimplementedError）
      ↓
[LintRunner] (lib/src/engine/runner.dart)
  parseString() → RuleVisitorRegistry → AST walk → List<LintDiagnostic>
      ↓              ↓
[CLI出力]      [LSP通知]
```

### Key Components

- **LintRunner** (`engine/runner.dart`): メインの解析エンジン。`runOnFile`/`runOnSource`/`runOnDirectory`。Isolateによる並列化対応（`ruleFactory`が必要）
- **CLI** (`cli/main.dart`): `runCli(args, rules:, ruleFactory:, pluginName:)`。`--lsp`フラグでLSPモード起動
- **LSP Server** (`lsp/server.dart`): JSON-RPC 2.0ベースのミニマルLSP実装。didOpen/didChangeで即座にlint実行
- **Config** (`config/`): `analysis_options.yaml`のルールoverride・excludeパターン対応。`include:`ディレクティブの再帰解決
- **Ignore Comments** (`engine/ignore_comments.dart`): `// ignore:`と`// ignore_for_file:`コメントの解析

### 利用パターン

ユーザーは自前のルールを持つカスタム実行ファイルを作成する:
```dart
import 'package:fast_linter/fast_linter.dart';
import 'package:my_rules/rules.dart';

void main(List<String> args) {
  runCli(args,
    rules: [MyRule1(), MyRule2()],
    ruleFactory: () => [MyRule1(), MyRule2()],  // Isolate並列化用
    pluginName: 'my_lint',  // analysis_options.yamlのplugin名
  );
}
```

### 動作検証

`example_rules/`に外部ルールパッケージへのシンボリックリンクを配置して検証に使用する。このシンボリックリンクが有効でないと`integration_test.dart`と`smoke_test.dart`は失敗する。
