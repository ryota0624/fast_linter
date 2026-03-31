---
name: verify
description: コード修正後にactrunでローカルCI検証を実行する。コード変更、実装完了、テスト修正、リファクタリングなど、コードを変更した後に使用する。
---

# コード修正後のローカル検証

コードを修正した後は、必ずactrunでCIワークフローをローカル実行して検証する。

## 手順

### 1. actrunでCI検証を実行

```bash
~/.local/bin/actrun workflow run .github/workflows/ci.yml \
  --skip-action actions/checkout \
  --skip-action dart-lang/setup-dart
```

このコマンドは以下の3ステップを順番に実行する:
1. **fast_linter** — AST-onlyの高速lint (builtinルール7個)
2. **dart test** — 全テスト実行
3. **dart analyze** — Dart公式の静的解析

### 2. 失敗時の対応

- **fast_linter失敗**: lint違反を修正し、再度actrunを実行
- **dart test失敗**: テストを修正し、再度actrunを実行
- **dart analyze失敗**: 静的解析の警告/エラーを修正し、再度actrunを実行

### 3. 全ステップ成功を確認してからcommit/push

actrunの出力が全てsuccessになるまで修正を繰り返す:
```
test/step_1: success
test/step_2: success
test/step_3: success
test/__finish: success
```
