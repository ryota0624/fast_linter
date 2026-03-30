# Dart公式lintルール調査結果

調査日: 2026-03-30

## ルール実装の所在

- **リポジトリ**: [dart-lang/sdk](https://github.com/dart-lang/sdk) の `pkg/linter/`
- **ルール数**: 252個（`pkg/linter/lib/src/rules/`）
- **公開状態**: `publish_to: none`（pubに公開されていない、SDK内部パッケージ）
- **SDK要求**: `sdk: ^3.12.0-0`（開発中バージョン）
- **登録**: `pkg/linter/lib/src/rules.dart` の `registerDefaultRules()` でanalyzerの`Registry`に一括登録

## APIの互換性

ルールは `package:analyzer/analysis_rule/analysis_rule.dart` の `AnalysisRule` を継承しており、fast_linterの互換レイヤーで**そのまま動作する**。

```dart
// 公式ルールの実装パターン（例: prefer_single_quotes.dart）
class PreferSingleQuotes extends AnalysisRule {
  @override
  DiagnosticCode get diagnosticCode => diag.preferSingleQuotes;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addSimpleStringLiteral(this, visitor);
    registry.addStringInterpolation(this, visitor);
  }
}
```

fast_linterのカスタムルール（stailer_lint）と全く同じAPI。

## AST-only vs Type-aware

ルールは2種類に分かれる:

| 種類 | 判別方法 | fast_linter対応 |
|------|---------|----------------|
| **AST-only** | `node.staticType`等を使わない | 動作する |
| **Type-aware** | `node.staticType`, `node.element`, `context.typeProvider`等を使用 | `TypeAwareAccessError`でスキップされる |

### AST-onlyルールの例
- `prefer_single_quotes` — 文字列リテラルの引用符チェック
- `camel_case_types` — 型名のUpperCamelCaseチェック
- `annotate_overrides` — @overrideアノテーションの有無
- `avoid_empty_else` — 空のelseブロック検出
- `unnecessary_new` — 不要なnewキーワード
- `slash_for_doc_comments` — ドキュメントコメントの形式

### Type-awareルールの例
- `unawaited_futures` — `node.staticType`でFuture型を判定
- `avoid_dynamic_calls` — 型情報に基づく動的呼び出し検出
- `unrelated_type_equality_checks` — 型比較の互換性チェック

## ヘルパー依存

ルールは以下のSDK内部ヘルパーに依存:

| ファイル | 内容 | fork難易度 |
|---------|------|-----------|
| `utils.dart` | `isCamelCase()`, `isLowerCamelCase()`等のユーティリティ | 低（スタンドアロン関数） |
| `extensions.dart` | AST extension methods | 中（一部は型情報を使う） |
| `diagnostic.dart` + `diagnostic.g.dart` | DiagnosticCode定義（生成コード） | 中（生成コードの再現が必要） |
| `lint_names.dart` + `lint_names.g.dart` | ルール名定数 | 低（単純な定数マップ） |
| `ast.dart` | AST関連ヘルパー | 低 |

## forkする場合の手順

1. `pkg/linter/lib/src/rules/<rule>.dart`をコピー
2. ヘルパー依存（`utils.dart`等）を必要最小限コピー
3. `diagnostic.g.dart`の`LintCode`定数を手動で定義
4. `lint_names.g.dart`のルール名定数を手動で定義
5. `extensions.dart`は型情報依存の部分を除外してfork
6. SDKバージョン差異（`namePart`等の新API）を旧APIに置き換え

## linterパッケージの取得方法

pubに公開されていないため、以下の方法が考えられる:

1. **GitHubから直接取得**: `gh api repos/dart-lang/sdk/contents/pkg/linter/lib/src/rules/<file>.dart`
2. **SDK monorepoをclone**: `git clone --depth 1 https://github.com/dart-lang/sdk.git` → `pkg/linter/`
3. **git依存**: `pubspec.yaml`でgit依存指定 → workspace解決の問題で不可

## 関連リンク

- [dart-lang/sdk pkg/linter](https://github.com/dart-lang/sdk/tree/main/pkg/linter)
- [lints package (YAML設定のみ)](https://pub.dev/packages/lints)
- [analyzer package (フレームワーク)](https://pub.dev/packages/analyzer)
