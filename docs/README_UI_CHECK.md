# UI継承チェック 使い方

## 概要
`RefCounted`を継承しているのにUI操作（`add_child()`, `position =`, `add_theme*`等）を行っているクラスを自動検出するスクリプトです。

## 実行方法

### 方法1: 構文チェックと同時実行（推奨）
```bash
bash check_syntax.sh
```
構文チェック後に自動的にUI継承チェックが実行されます。

### 方法2: UI継承チェックのみ実行
```bash
bash check_ui_inheritance.sh
```

## 検出される問題

以下のパターンを自動検出します：

```gdscript
# ❌ NG: RefCountedでUI操作
extends RefCounted

func create_label():
    var label = Label.new()
    add_child(label)  # エラー！RefCountedはノードツリーに追加できない
    label.position = Vector2(10, 10)  # エラー！
```

```gdscript
# ✅ OK: ControlまたはNodeを継承
extends Control

func create_label():
    var label = Label.new()
    add_child(label)  # OK
    label.position = Vector2(10, 10)  # OK
```

## 現在の問題（2026-04-19時点）

以下8ファイルが検出されています：

1. CardUIComponent.gd
2. DeckPrepBoard.gd
3. DeckPrepBoardSpells.gd
4. DeckPrepInfo.gd
5. DeckPrepRightPanel.gd
6. DeckPrepSidebar.gd
7. DevUI.gd
8. UIFactory.gd

**修正方法:** 全て `extends Control` への変更が必要です。

## 詳細ドキュメント

詳しい使い方・修正方法は以下を参照：
- [docs/dev/ui_inheritance_check.md](docs/dev/ui_inheritance_check.md)

## スクリプトの仕組み

1. scripts/内の全.gdファイルを走査（Test*.gdは除外）
2. `extends RefCounted`を継承しているファイルを抽出
3. UI操作関数の使用を検出（正規表現パターンマッチ）
4. 問題箇所を行番号付きで報告
5. 推奨される継承元を提案

## トラブルシューティング

### チェックが失敗する
```bash
❌ 問題数: 8 ファイル
FAILED: RefCountedを継承しているのにUI操作を行っているファイルがあります
```

→ 報告されたファイルの `extends RefCounted` を `extends Control` に変更してください。

### 誤検知が発生する
- `.new()`のみの使用は除外されます
- Test*.gdは自動除外されます
- それ以外は報告してください

## 関連ファイル

- `check_ui_inheritance.sh` - チェックスクリプト本体
- `check_syntax.sh` - 構文チェック（UI継承チェックを含む）
- `docs/dev/ui_inheritance_check.md` - 詳細ドキュメント
