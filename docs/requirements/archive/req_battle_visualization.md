STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# 要件定義書: バトル可視化（攻撃ライン・効果テキストポップアップ）

作成日: 2026-04-27

---

## 背景・目的

「なぜ負けたか分からない」「誰が誰を攻撃しているか見えない」という問題を解決する。
プレイヤーの「勝ち筋集中・リスクヘッジ」スキルが活きるためのバトル視覚フィードバック強化。

---

## 実装スコープ

### 1. 攻撃ライン表示

**内容**
- 攻撃が発生したとき、攻撃元セル中央 → 攻撃先セル中央へ線を0.3秒表示して消える

**仕様**
- 線の色: `Color(1.0, 0.7, 0.2, 0.8)`（オレンジ）
- 太さ: 2px（Line2Dのwidth）
- 表示時間: 0.3秒（timer減算でフェードアウト）
- 実装場所: `GameUIOverlay.gd` に `spawn_attack_line(src_side, src_row, src_col, dst_side, dst_row, dst_col)` 追加
- Line2Dノードをmain配下に追加し、タイマー管理配列で寿命管理
- セル中央座標: `_cell_x(side, col) + CELL_W/2`, `BOARD_TOP + row * CELL_H + CELL_H/2`
- z_index: 60（ダメージフロートの50より上）

**シグナル拡張**
- `BoardManager.gd` にシグナル追加: `signal attack_visual(src_side, src_row, src_col, dst_side, dst_row, dst_col)`
- `CombatSystem.gd` の `_do_attack` 内、ターゲット確定直後（`hit_any = true`の直後）に `bm.attack_visual.emit(side, row, col, enemy_side, target_row, target_col)` を発火
- `Main.gd` で接続: `board_manager.attack_visual.connect(_on_attack_visual)`
- `_on_attack_visual` で `game_ui.spawn_attack_line(...)` を呼ぶ

### 2. 効果テキストポップアップ

**内容**
- スキル・呪文発動時、発動元ユニット上にテキストをポップアップ（例：「回復+10」「毒」「貫通」）

**仕様**
- 実装場所: `GameUIOverlay.gd` に `spawn_effect_text(side, row, col, text, color)` 追加
- 挙動: `spawn_damage_float` と同じ（上に浮かんでフェードアウト、1秒）
- デフォルト色: `Color(0.9, 0.9, 0.3)`（黄色系）
- フォントサイズ: 14px
- z_index: 50

**接続**
- `Main.gd` の `_on_skill_triggered(side, row, col, skill_name)` 内で `game_ui.spawn_effect_text(side, row, col, skill_name, Color(0.9, 0.9, 0.3))` を呼ぶ
- `game_ui.spawn_effect_text` は `game_ui._overlay.spawn_effect_text(...)` に委譲

### 3. ダメージフロートの量修正

**内容**
- 現状 `_on_unit_damaged` でamount=0を渡しているため数値が表示されない
- `unit_damaged` シグナルを拡張してダメージ量を渡す

**仕様**
- `BoardManager.gd` のシグナル変更: `signal unit_damaged(side, row, col, amount: int)`
- `EventQueue.gd` の `"damage"` イベント処理内で `board_manager.unit_damaged.emit(enemy_side, row, col, dmg_value)` に変更（amountを追加）
- `Main.gd` の `_on_unit_damaged(side, row, col)` → `_on_unit_damaged(side, row, col, amount)` に変更し `spawn_damage_float(side, row, col, amount)` を呼ぶ

---

## 影響ファイル

| ファイル | 変更内容 |
|---------|---------|
| `scripts/BoardManager.gd` | シグナル追加: `attack_visual`, `unit_damaged`にamount追加 |
| `scripts/CombatSystem.gd` | `_do_attack`内でattack_visual発火 |
| `scripts/EventQueue.gd` | `unit_damaged`emit時にamount追加 |
| `scripts/GameUIOverlay.gd` | `spawn_attack_line`, `spawn_effect_text` 追加、`update_attack_lines` 追加 |
| `scripts/GameUI.gd` | `spawn_attack_line`, `spawn_effect_text` のラッパー追加 |
| `scripts/Main.gd` | シグナル接続追加・`_on_attack_visual`追加・`_on_unit_damaged`/`_on_skill_triggered`修正 |

---

## 実装しないもの

- ダメージ量以外のフロート（クリティカル表示等）— 今回スコープ外
- 呪文発動時の専用ビジュアル — 今回スコープ外
- アニメーション・トゥイーン — 今回はシンプルなフェードのみ

---

## 完了条件

- [ ] 攻撃時に攻撃元→攻撃先の線が0.3秒表示される
- [ ] ダメージ数値フロートに実際のダメージ量が表示される
- [ ] skill_triggered発火時にスキル名がユニット上にポップアップされる
- [ ] check_syntax.sh エラー0件
