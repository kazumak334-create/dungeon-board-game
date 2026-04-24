# UI継承チェック

## 概要
UI操作を行っているのに`RefCounted`を継承している問題を自動検知するスクリプト。

## 問題パターン
以下の組み合わせは実行時エラーを引き起こす：

- `extends RefCounted` を継承
- かつ、UI操作関数を使用（`add_child()`, `set_position()`, `position =` 等）

## 使用方法

### 単体実行
```bash
bash tools/ci/check_ui_inheritance.sh
```

### 構文チェックと統合実行
```bash
bash tools/ci/check_syntax.sh
```
（tools/ci/check_syntax.shが自動的にUI継承チェックを呼び出します）

## 検知対象

### UI操作関数
- `.set_position()`
- `.add_child()`
- `.set_size()`
- `.position =`
- `.size =`
- `.add_theme*`
- `.set_text()`
- `.set_visible()`
- `.queue_free()`
- `.get_node()`
- `.modulate =`
- `.rotation =`
- `.scale =`

### 除外対象
- `Test*.gd` ファイル（テストコード）

## 出力例

### 問題なしの場合
```
=== UI継承チェック開始 ===

=== チェック完了 ===
チェックファイル数: 87
✓ 問題なし
```

### 問題検出時
```
=== UI継承チェック開始 ===

❌ 問題検出: scripts/SomeClass.gd
   継承: RefCounted
   UI操作箇所:
  Line 25: node.set_position(Vector2(100, 100))
  Line 30: add_child(label)

   推奨修正:
   - extends Control に変更

=== チェック完了 ===
チェックファイル数: 87
❌ 問題数: 1 ファイル

FAILED: RefCountedを継承しているのにUI操作を行っているファイルがあります
```

## 修正方法

問題が検出された場合、以下の手順で修正：

1. **継承元を変更**
   ```gdscript
   # 修正前
   extends RefCounted
   
   # 修正後（UI操作が必要な場合）
   extends Control  # または extends Node
   ```

2. **推奨継承元の判断基準**
   - UI要素を操作する場合 → `extends Control`
   - 2Dノード操作の場合 → `extends Node2D`
   - それ以外のノード操作 → `extends Node`
   - データクラスのみ → `extends RefCounted`（UI操作しない）

3. **検証**
   ```bash
   bash tools/ci/check_syntax.sh
   ```

## 背景

### なぜこの問題が発生するか
- `RefCounted`: メモリ管理のみのクラス（シーンツリーに追加できない）
- `Node`/`Control`: シーンツリーノード（UI操作可能）
- RefCountedでUI操作を行うと実行時エラー

### 過去の事例
- シナジーアイコン生成で`RefCounted`を使用→`add_child()`でエラー
- 戦闘ログ表示で`RefCounted`を使用→`set_position()`でエラー

## 現在検出されている問題ファイル（2026-04-19時点）

以下8ファイルが問題を抱えています：

1. `CardUIComponent.gd` - カードUI生成
2. `DeckPrepBoard.gd` - デッキ準備盤面
3. `DeckPrepBoardSpells.gd` - スペル盤面
4. `DeckPrepInfo.gd` - デッキ情報パネル
5. `DeckPrepRightPanel.gd` - 右パネル
6. `DeckPrepSidebar.gd` - サイドバー
7. `DevUI.gd` - 開発UI
8. `UIFactory.gd` - UI生成ファクトリ

これらは全て `extends Control` への変更が必要です。

## トラブルシューティング

### チェックが通らない
- 該当ファイルの`extends`行を確認
- UI操作関数を削除するか、継承元を変更

### 誤検知が発生する
- `.new()`のみの使用は除外されます
- Test*.gdファイルは除外されます
- それ以外の誤検知は報告してください

## 関連ドキュメント
- [CLAUDE.md](../../CLAUDE.md) — 構文チェック徹底ルール
- [tools/ci/check_syntax.sh](../../tools/ci/check_syntax.sh) — 構文チェックスクリプト
