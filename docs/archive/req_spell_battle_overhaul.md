# 呪文バトル全体改修 要件定義書

## 1. 概要

本体HP廃止の残存UIを消去し、ターゲット選択を単一ターゲット方式に変更する。
あわせて呪文スロットのドローUIをバトル画面に追加し、廃止済みの呪文回収カードを削除する。

---

## REQ-A: 本体HP表示削除

### 2. 実装対象

- ファイル: `scripts/GameUI.gd`
  - L168-182: `player_base_label` / `enemy_base_label` 生成ブロック
  - L495-497: `update_base_hp()` 関数本体

### 3. データ構造

変更なし。`main.player_base_label` / `main.enemy_base_label` は `Main.gd` に宣言されているが、
生成を止めることで null になる。`update_base_hp()` を空関数にするため null 参照エラーも発生しない。

### 4. 実装詳細

**手順:**

1. `GameUI.gd` L167-182 のコメント「本体HP表示（行突破カウンター）」ブロック全体を削除
   - 削除対象: `player_base_label` の `Label.new()` から `add_child` まで（L170-175）
   - 削除対象: `enemy_base_label` の `Label.new()` から `add_child` まで（L177-182）
2. `GameUI.gd` L495-497 の `update_base_hp()` を空関数に置き換え:
   ```
   func update_base_hp() -> void:
       pass
   ```
3. `Main.gd` L497 の `_update_base_hp()` は変更しない（空の `update_base_hp()` を呼ぶだけ）

**呼び出し元の確認（変更不要):**
- `GameUI.gd` L361: `update_ui()` 内で `update_base_hp()` を呼んでいる → 空関数になるので無害
- `Main.gd` L497: `_update_base_hp()` → `game_ui.update_base_hp()` → 空関数 → 無害

### 5. 受け入れ基準

- [ ] バトル画面に「自陣 本体HP」「敵陣 本体HP」の文字列が表示されない
- [ ] バトル開始・進行中に null 参照エラーが発生しない
- [ ] 勝利条件（前列・中列全滅 OR 1行全滅）の判定ロジックは変化しない

### 6. 依存関係

- 前提タスク: なし
- 他ファイルへの影響: `Main.gd` の `player_base_label` / `enemy_base_label` 変数宣言は残存するが機能上無害
- 既存関数の再利用: なし

### 7. 制約・注意事項

- `Main.gd` の `base_hp` 配列自体は削除しない（`last_result` に `player_hp_remaining` として参照されている）
- `_on_base_damaged()` は残存するが呼び出される経路は廃止済み（変更不要）
- 用語: base_hp（SSOT準拠）

---

## REQ-B: 命中ターゲット優先順変更

### 2. 実装対象

- ファイル: `scripts/CombatSystem.gd`
  - `_do_attack()` L114-134: `_get_target_rows()` 呼び出し〜ターゲット選択ループ
  - `_get_target_rows()` L272-285: 廃止（削除可）

### 3. データ構造

変更なし。`attacker.attack_range` フィールドはカードデータに残るが、本ロジックでは参照しない。

### 4. 実装詳細

**col 定義（既存コードと統一）:**
- `front_col`: `enemy_side == 0` なら `col=2`、`enemy_side == 1` なら `col=0`（`get_frontmost_col` の先頭順と一致）
- `mid_col`: `col=1`（常に固定）
- `back_col`: `enemy_side == 0` なら `col=0`、`enemy_side == 1` なら `col=2`

**新しいターゲット選択ロジック（疑似コード）:**

```
# 既存の target_rows / ループを以下に置き換える

var target = null
var target_row: int = -1
var target_col: int = -1
var e_front_col: int = 2 if enemy_side == 0 else 0
var e_mid_col: int   = 1
var e_back_col: int  = 0 if enemy_side == 0 else 2

# 優先度1: 同行の前列
var c = get_frontmost_col(enemy_side, row)
if c == e_front_col and bm.board[enemy_side][row][c] != null:
    target_row = row
    target_col = c
else:
    # 優先度2: 他行の前列をランダム順
    var other_rows: Array = []
    for r in range(3):
        if r != row:
            other_rows.append(r)
    other_rows.shuffle()
    for r in other_rows:
        var oc = get_frontmost_col(enemy_side, r)
        if oc == e_front_col and bm.board[enemy_side][r][oc] != null:
            target_row = r
            target_col = oc
            break
    if target_col == -1:
        # 優先度3: 同行の中列
        if bm.board[enemy_side][row][e_mid_col] != null:
            target_row = row
            target_col = e_mid_col
    if target_col == -1:
        # 優先度4: 同行の後列
        if bm.board[enemy_side][row][e_back_col] != null:
            target_row = row
            target_col = e_back_col

if target_col == -1:
    # 優先度5: base_damage（現行ロジックそのまま）
    # hit_any = false のまま → 既存の base_hp 減算処理へ
    pass
else:
    var hit_any = true
    target = bm.board[enemy_side][target_row][target_col]
    # 以降の damage 計算・貫通処理は既存コードをそのまま使用
    # target_row / target_col を渡して既存の damage/penetrate ブロックを動かす
```

**貫通処理の扱い:**
- `_has_penetrate` / `_has_big_penetrate` / `_has_impact` はターゲット決定後の damage 適用部分に残す
- 既存の penetrate ブロック（L169-215）は `target_row` / `target_col` を使うのでそのまま動く

**削除対象:**
- `_get_target_rows()` L272-285（全体削除）
- L114 の `var target_rows: Array = _get_target_rows(row, attacker.attack_range)`
- L124 の `for target_row in target_rows:` ループ外枠

**`target_rear` フラグの扱い:**
- `_do_attack()` の引数 `target_rear: bool` は後列・中列ユニットの支援攻撃で使用（L126）
- 新ロジックは前列ユニット（`front_col` からの攻撃）にのみ適用
- `target_rear = true` の呼び出し（L60, L76）は既存の `_get_rearmost_col` を使う分岐を維持する

**`target_rear` 分岐:**
```
if target_rear:
    # 既存ロジック: _get_rearmost_col で単一行のみ（1ターゲット）
    target_col = _get_rearmost_col(enemy_side, row)
    target_row = row
else:
    # 新ロジック: 上記優先順
```

### 5. 受け入れ基準

- [ ] 攻撃ユニットと同行の前列に敵がいる場合、そこを優先してヒットする
- [ ] 同行前列に敵がおらず他行前列に敵がいる場合、他行前列にヒットする（行はランダム）
- [ ] 前列が全滅していて中列に敵がいる場合、同行中列にヒットする
- [ ] 前列・中列が全滅していて後列に敵がいる場合、同行後列にヒットする
- [ ] 全列全滅の場合は base_damage（本体ダメージ）が適用される
- [ ] `_has_penetrate` / `_has_big_penetrate` / `_has_impact` の挙動が変化しない
- [ ] `target_rear = true`（支援攻撃）は従来通り後列ターゲットを選ぶ

### 6. 依存関係

- 前提タスク: なし
- 他ファイルへの影響: `_get_target_rows()` 削除後、呼び出し元は `_do_attack()` のみであるため他ファイルへの影響なし
- 既存関数の再利用: `get_frontmost_col()` L388、`_get_rearmost_col()` L396

### 7. 制約・注意事項

- `attacker.attack_range` フィールドは `cards.json` に残るが、バトルロジックでは参照しない
- 廃止済み設計: 多行攻撃（DEP相当）は本変更で完全廃止
- 用語: col / row / front_col（SSOT準拠）

---

## REQ-C: 呪文スロットUI（バトル画面）

### 2. 実装対象

- ファイル: `scripts/SpellSlotSystem.gd`
  - `setup()` L51: バトル開始時の初期ドロー呼び出しを追加
  - 新規メソッド `draw_to_fill_slots()` を追加
- ファイル: `scripts/GameSession.gd`
  - L47付近: `spell_hand` / `spell_discard` フィールドを追加
  - `reset()` 内: 追加フィールドの初期化
- ファイル: `scripts/GameUI.gd`
  - `_on_wave_started()` L558 付近: `draw_to_fill_slots()` 呼び出しを追加
  - スロットUI表示ノードの生成・更新ロジックを追加（UI描画関数として新設）

### 3. データ構造

**GameSession への追加フィールド:**

| フィールド | 型 | 初期値 | 用途 |
|---|---|---|---|
| `spell_hand` | `Array` | `[]` | スロット表示中の呪文名配列（最大3要素） |
| `spell_discard` | `Array` | `[]` | 使用・破棄済み呪文名配列 |

**スロットUI ノード構造（GameUI内で生成）:**

```
spell_slot_container: HBoxContainer
  └─ slot_panels[0..2]: PanelContainer  (各スロット)
       ├─ spell_name_label: Label
       ├─ mana_cost_label: Label
       └─ unavail_overlay: ColorRect    (使用不可時オーバーレイ)
```

### 4. 実装詳細

**A. GameSession への追加（GameSession.gd）:**

```gdscript
# L47直後に追加
var spell_hand: Array = []     # スロット表示中の呪文名配列（最大3）
var spell_discard: Array = []  # 使用・破棄した呪文名配列
```

`reset()` 関数内（L118付近）に追加:
```gdscript
spell_hand = []
spell_discard = []
```

**B. `draw_to_fill_slots()` の追加（SpellSlotSystem.gd）:**

シグネチャ: `func draw_to_fill_slots() -> void`

処理フロー:
```
for i in range(3):
    if slots[i]["spell"] == null:
        # spell_deck が空なら spell_discard をシャッフルしてデッキに戻す
        if GameSession.spell_deck.is_empty():
            if GameSession.spell_discard.is_empty():
                continue  # 引けるカードなし
            GameSession.spell_deck = GameSession.spell_discard.duplicate()
            GameSession.spell_discard.clear()
            GameSession.spell_deck.shuffle()
        var spell_name: String = GameSession.spell_deck.pop_front()
        GameSession.spell_hand.append(spell_name)
        # DeckManager経由でカードオブジェクトを取得してセット
        var spell_obj = deck_manager.get_spell_card_by_name(spell_name)
        if spell_obj != null:
            set_slot(i, spell_obj, "always")
```

**C. バトル開始時の呼び出し（GameUI.gd）:**

`_on_wave_started()` L558 内に追記:
```gdscript
if main.spell_slot_system != null:
    main.spell_slot_system.draw_to_fill_slots()
    _update_spell_slot_ui()
```

**D. スロットUIの生成（GameUI.gd の `_create_ui()` または専用関数）:**

UI座標:
- `spell_slot_container` の position.y = `BOARD_TOP + 3 * CELL_H + 12` + 40 = 445付近
  - 具体値: y = 88 + 3 * 95 + 12 + 40 = 425 px（本体HP表示の base_y = 385 から +40）
  - x = 自陣前列の左端（`_cell_x(0, 0)` 相当）
- 各スロットパネル: 幅 120px、高さ 60px、間隔 8px

**E. スロットUI更新（`_update_spell_slot_ui()`）:**

```
func _update_spell_slot_ui() -> void:
    for i in range(3):
        var slot = main.spell_slot_system.slots[i]
        if slot["spell"] == null:
            spell_name_labels[i].text = "---"
            mana_cost_labels[i].text = ""
            unavail_overlays[i].visible = false
        else:
            spell_name_labels[i].text = slot["spell"].unit_name
            mana_cost_labels[i].text = "MP:%d" % slot["mana_cost"]
            var castable: bool = main.spell_slot_system.can_cast(i)
            unavail_overlays[i].visible = not castable
```

**F. インタラクション（Input処理）:**

- ダブルクリック検知: `_on_slot_gui_input(event, index)` を各スロットパネルの `gui_input` シグナルに接続
  - `InputEventMouseButton` かつ `button_index == MOUSE_BUTTON_LEFT` かつ `double_click == true` → `main.spell_slot_system.cast_spell(index)` 呼び出し後 `_update_spell_slot_ui()`
- 右クリック: `button_index == MOUSE_BUTTON_RIGHT` かつ `pressed == true` → `main.spell_slot_system.discard_slot(index)` 呼び出し後 `draw_to_fill_slots()` → `_update_spell_slot_ui()`

**G. 使用不可オーバーレイの仕様:**

- ノード型: `ColorRect`
- color: `Color(0, 0, 0, 0.5)` (alpha=0.5 の黒)
- サイズ: 親 PanelContainer と同サイズ (120px × 60px)
- `visible`: `can_cast(i) == false` のとき true

### 5. 受け入れ基準

- [ ] バトル開始時（wave_started シグナル後）にスロット3枠が `spell_deck` の先頭3枚で埋まる
- [ ] スロットUIが y=425 付近（自陣盤面下）に3枠横並びで表示される
- [ ] マナ不足のスロットに alpha=0.5 の黒オーバーレイが表示される
- [ ] スロットをダブルクリックで `cast_spell()` が呼ばれ、呪文が発動する
- [ ] スロットを右クリックで `discard_slot()` が呼ばれ、即座に次のカードがドローされる
- [ ] `spell_deck` が空のとき `spell_discard` をシャッフルしてデッキに戻し再ドローする
- [ ] `spell_deck` / `spell_discard` の両方が空のとき、スロットは「---」表示のまま（エラーなし）
- [ ] `GameSession.spell_hand` と実際のスロット表示が一致する

### 6. 依存関係

- 前提タスク: REQ-A（本体HP表示削除）完了後に実施推奨（UI座標の base_y が確定するため）
- 他ファイルへの影響:
  - `GameSession.gd`: `spell_hand` / `spell_discard` フィールド追加
  - `SpellSlotSystem.gd`: `draw_to_fill_slots()` 追加、`setup()` は変更しない
- 既存関数の再利用:
  - `SpellSlotSystem.set_slot()` L68
  - `SpellSlotSystem.can_cast()` L248
  - `SpellSlotSystem.cast_spell()` L275
  - `SpellSlotSystem.discard_slot()` L326
  - `GameUI._on_wave_started()` L558

### 7. 制約・注意事項

- `spell_deck` は文字列配列（呪文名）。`draw_to_fill_slots()` 内で名前からカードオブジェクトを取得する処理が必要
  - `DeckManager.get_spell_card_by_name(name)` が存在しない場合は `DeckManager` に追加する（別タスク扱い可）
- 既存の `SpellSlotSystem.slots` はカードオブジェクト（Dict）を保持するため、文字列から変換が必要
- `GameSession.spell_deck` が空の状態でバトル開始した場合（呪文未選択）はスロット全空で開始（エラーなし）
- 用語: spell_deck / spell_hand / spell_discard / mana（SSOT準拠）

---

## REQ-D: 呪文回収廃止

### 2. 実装対象

- ファイル: `scripts/DeckManager.gd`
  - `ensure_shuffle_card()` L80-116: 空関数にする
- ファイル: `scripts/EnemyAI.gd`
  - `ensure_shuffle_card()` L138付近: 空関数にする
- ファイル: `data/cards.json`
  - `"system_spells"` 内の `"呪文回収"` エントリを削除

### 3. データ構造

`data/cards.json` の `system_spells["呪文回収"]` エントリ（L2276-2280付近）を削除。

### 4. 実装詳細

**手順1: DeckManager.gd**

`ensure_shuffle_card()` L80-116 を以下に置き換え:
```gdscript
func ensure_shuffle_card() -> void:
    pass  # REQ-D: 呪文回収廃止
```

**手順2: EnemyAI.gd**

`ensure_shuffle_card()` L138付近を以下に置き換え:
```gdscript
func ensure_shuffle_card() -> void:
    pass  # REQ-D: 呪文回収廃止
```

**手順3: data/cards.json**

`"system_spells"` オブジェクト内の `"呪文回収": { ... }` エントリを削除。
削除範囲: L2276の `"呪文回収": {` から対応する閉じ括弧 `}` まで（カンマ含む）。

### 5. 受け入れ基準

- [ ] `ensure_shuffle_card()` を呼び出しても何も起きない（エラーなし）
- [ ] `data/cards.json` に `"呪文回収"` キーが存在しない
- [ ] デッキ構築画面・バトル中に「呪文回収」が選択肢や手札に出現しない
- [ ] 既存の `ensure_shuffle_card()` 呼び出し元（DeckManager L117 等）でエラーが発生しない

### 6. 依存関係

- 前提タスク: REQ-C（呪文スロットUI）と同時または前に実施
- 他ファイルへの影響:
  - `DeckManager.gd` L117: `draw_card()` 内で `ensure_shuffle_card()` を呼んでいる → 空関数になるので無害
  - `cards.json` からエントリ削除後、ロード時にキーが存在しなくなる
- 既存関数の再利用: なし

### 7. 制約・注意事項

- 関数シグネチャは保持（削除しない）。呼び出し元が複数あるため空関数で対応
- `data/cards.json` 編集時は JSON 構文エラーに注意（末尾カンマの有無を確認）
- 廃止済み設計（CLAUDE.md「廃止済み設計」リスト）への追記は別途 PMO が対応
- 用語: spell_deck（SSOT準拠）

---

## 実装可能性チェックリスト（自己検証）

- [x] 座標・サイズ・色が具体値で指定されているか — REQ-C: y=425px、120x60px、Color(0,0,0,0.5)
- [x] 関数シグネチャ（引数・戻り値・型）が確定しているか — 全REQで明記
- [x] 条件分岐の全ケース（正常系・異常系・エッジケース）が網羅されているか — 各REQの受け入れ基準に記載
- [x] 既存コードとの連携箇所（呼び出し先・呼び出し元）が明記されているか — 各REQの依存関係に記載
- [x] エッジケース（空・null・上限値・下限値）の扱いが決まっているか — spell_deck/spell_discard両空、null参照等を記載
- [x] 失敗時の挙動（エラー表示・リトライ・ログ）が定義されているか — 空スロット維持でエラーなし
- [x] パフォーマンス要件 — 特記なし（フレーム毎処理なし・イベント駆動）
- [x] 用語が ssot_canonical_terms.txt と一致しているか — col / row / mana / spd / spell_deck を使用
