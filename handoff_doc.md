# fast_lint プロジェクト 引き継ぎドキュメント

## プロジェクト概要

Dartの高速linterを自作する。`dart analyzer`は型解析（type-aware）ゆえに遅いため、ASTのみを使ったtype-unawareな高速linterをDartで実装する。

---

## 確定した要件

- **type-aware lintは不要** → ASTのみで完結
- **使用場面**: CIでのコマンド実行 / エディタ上でのリアルタイム（LSP）
- **実装言語**: Dart（`package:analyzer`のパーサー部分のみ借用）
- **既存資産の活用**: 自作のanalyzer pluginルール群（型情報不要なもの）をコード修正なしで再利用したい

---

## 既存ルールの構造

- 基底クラス: analyzerパッケージ本体の `AnalysisRule` / `LintRule`
- AstVisitorを直接実装している（`SimpleAstVisitor<void>`など）
- エラー報告: `ErrorReporter` を使用（`LintRule.reporter`プロパティ経由で取得）
- 使用メソッド: `reportErrorForNode` / `reportErrorForToken`（それ以外は今のところ考慮しない）

---

## アーキテクチャ方針

### analyzerパッケージの使い方
| 部分 | 使う/使わない | 理由 |
|------|-------------|------|
| `parseString()` | **使う** | type解析なしで高速にAST取得できる |
| `LintRule` / `ErrorReporter` などの型 | **使う** | 既存ルールとの互換のため |
| `AnalysisServer` / `AnalysisDriver` | **使わない** | ここが遅さの原因 |
| analyzer server plugin機構 | **使わない** | analyzerが解析し終わるまで待つ設計のためオーバーヘッドがある |

### 全体フロー
```
[既存ルール群] ← コード変更なし
      ↓ AstVisitor + ErrorReporter（スタブ）だけ受け取る
[互換レイヤー]
  - FastErrorReporter（ErrorReporterのスタブ）
  - FastNodeLintRegistry（NodeLintRegistryのスタブ）
  - EmptyLinterContext（LinterContextの空実装）
      ↓
[LintRunner]（parseString → rule適用 → List<LintDiagnostic>）
      ↓              ↓
[CLI出力]      [LSP通知]
```

---

## ディレクトリ構成

```
fast_lint/
├── lib/
│   ├── src/
│   │   ├── compat/
│   │   │   ├── error_reporter.dart       # FastErrorReporter
│   │   │   ├── node_lint_registry.dart   # FastNodeLintRegistry
│   │   │   └── linter_context.dart       # EmptyLinterContext
│   │   ├── engine/
│   │   │   ├── runner.dart               # parseして全ruleを適用
│   │   │   └── diagnostic.dart           # LintDiagnostic型
│   │   ├── lsp/
│   │   │   └── server.dart               # LSPサーバー（フェーズ3）
│   │   └── cli/
│   │       └── main.dart                 # CLIエントリポイント（フェーズ2）
│   └── fast_lint.dart
└── rules/                                # 既存ルールをそのまま置く
```

---

## 実装済みコード

### `lib/src/engine/diagnostic.dart`
```dart
class LintDiagnostic {
  final String filePath;
  final String code;
  final String message;
  final int offset;
  final int length;

  const LintDiagnostic({
    required this.filePath,
    required this.code,
    required this.message,
    required this.offset,
    required this.length,
  });

  @override
  String toString() => '$filePath: [$code] $message (offset: $offset, length: $length)';
}
```

### `lib/src/compat/error_reporter.dart`
```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart';
import '../engine/diagnostic.dart';

class FastErrorReporter {
  final String filePath;
  final List<LintDiagnostic> _diagnostics = [];

  FastErrorReporter(this.filePath);

  List<LintDiagnostic> get diagnostics => List.unmodifiable(_diagnostics);

  void reportErrorForNode(
    ErrorCode code,
    AstNode node, [
    List<Object>? arguments,
    List<DiagnosticMessage>? messages,
    Object? data,
  ]) {
    _diagnostics.add(LintDiagnostic(
      filePath: filePath,
      code: code.name,
      message: code.problemMessage,
      offset: node.offset,
      length: node.length,
    ));
  }

  void reportErrorForToken(
    ErrorCode code,
    Token token, [
    List<Object>? arguments,
    List<DiagnosticMessage>? messages,
    Object? data,
  ]) {
    _diagnostics.add(LintDiagnostic(
      filePath: filePath,
      code: code.name,
      message: code.problemMessage,
      offset: token.offset,
      length: token.length,
    ));
  }
}
```

### `lib/src/compat/node_lint_registry.dart`
```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class FastNodeLintRegistry {
  final _visitors = <AstVisitor>[];

  void addMethodInvocation(Object rule, AstVisitor visitor) => _visitors.add(visitor);
  void addClassDeclaration(Object rule, AstVisitor visitor) => _visitors.add(visitor);
  void addFunctionDeclaration(Object rule, AstVisitor visitor) => _visitors.add(visitor);
  void addVariableDeclaration(Object rule, AstVisitor visitor) => _visitors.add(visitor);
  void addImportDirective(Object rule, AstVisitor visitor) => _visitors.add(visitor);
  void addSimpleIdentifier(Object rule, AstVisitor visitor) => _visitors.add(visitor);
  void addAssignmentExpression(Object rule, AstVisitor visitor) => _visitors.add(visitor);
  void addIfStatement(Object rule, AstVisitor visitor) => _visitors.add(visitor);
  void addReturnStatement(Object rule, AstVisitor visitor) => _visitors.add(visitor);

  void run(CompilationUnit unit) {
    for (final visitor in _visitors) {
      unit.accept(visitor);
    }
  }
}
```

### `lib/src/compat/linter_context.dart`
```dart
import 'package:analyzer/src/lint/linter.dart';

class EmptyLinterContext implements LinterContext {
  const EmptyLinterContext();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'LinterContext.${invocation.memberName} is not supported in fast_lint. '
      'This rule may require type-aware analysis.',
    );
  }
}
```

### `lib/src/engine/runner.dart`
```dart
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/src/lint/linter.dart';
import '../compat/error_reporter.dart';
import '../compat/linter_context.dart';
import '../compat/node_lint_registry.dart';
import 'diagnostic.dart';

class LintRunner {
  final List<LintRule> rules;

  const LintRunner({required this.rules});

  List<LintDiagnostic> runOnFile(File file) {
    final source = file.readAsStringSync();
    return runOnSource(source, filePath: file.path);
  }

  List<LintDiagnostic> runOnSource(String source, {required String filePath}) {
    final parseResult = parseString(content: source);
    final unit = parseResult.unit;
    final diagnostics = <LintDiagnostic>[];

    for (final rule in rules) {
      final reporter = FastErrorReporter(filePath);
      rule.reporter = reporter as dynamic; // TODO: analyzerのバージョンに応じてセッター名を確認
      
      final registry = FastNodeLintRegistry();
      rule.registerNodeProcessors(registry as dynamic, const EmptyLinterContext());
      registry.run(unit);

      diagnostics.addAll(reporter.diagnostics);
    }

    return diagnostics;
  }

  Future<List<LintDiagnostic>> runOnDirectory(Directory dir) async {
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // TODO: フェーズ2でIsolateによる並列化
    final results = <LintDiagnostic>[];
    for (final file in files) {
      results.addAll(runOnFile(file));
    }
    return results;
  }
}
```

---

## 未解決の課題・TODO

### 優先度高
- [ ] **`rule.reporter`のセッター名の確認**
  - `LintRule.reporter`のセッターはanalyzerのバージョンによって異なる可能性がある
  - 以下で確認する：
    ```bash
    grep -r "reporter" $(dart pub cache dir)/hosted/pub.dev/analyzer-*/lib/src/lint/linter.dart
    ```
  - `internalSetReporter(ErrorReporter reporter)` という形の可能性あり

- [ ] **既存ルール1本で実際に動かして検証**
  - エラーが出たらその内容に応じてcompat層を修正

### 優先度中
- [ ] `FastNodeLintRegistry`のaddXxxメソッドを既存ルールが使っているものに合わせて追加
- [ ] `ErrorCode.problemMessage`のテンプレートに`arguments`を展開する処理

### 優先度低（後のフェーズ）
- [ ] フェーズ2: CLIエントリポイント・設定ファイル（`fast_lint.yaml`）・Isolate並列化
- [ ] フェーズ3: LSPサーバー実装（`textDocument/didOpen`, `didChange`, `publishDiagnostics`）

---

## 実装フェーズ

| フェーズ | 内容 | 状態 |
|---------|------|------|
| 1 | 互換レイヤー + エンジン | 骨格実装済み・検証待ち |
| 2 | CLI + 設定ファイル + 並列化 | 未着手 |
| 3 | LSPサーバー | 未着手 |
