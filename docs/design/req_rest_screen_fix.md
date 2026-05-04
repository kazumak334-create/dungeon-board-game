# RestScreenManager バグ修正 要件定義書

## 1. 概要

DeckPrep後の配置画面（RestScreenManager）に存在する2バグを修正する。
バグ1はカード配置後の盤面セル描画が更新されない問題、バグ2は手持ちカードのD&D未実装。

## 2. 実装対象

| ファイル | 変更関数 |
|---|---|
| `scripts/BoardManager.gd` | `on_rest_drop()` — 約575行目 |
| `scripts/RestScreenManager.gd` | `on_board_cell_clicked()` — 526行目 |
| `scripts/RestScreenManager.gd` | `create_card_view()` — 264行目 |
| `scripts/RestScreenManager.gd` | `_setup_board_click_overlay()` — 408行目 |

## 3. データ構造

変更なし。既存の `board[side][row][col]`（Object型・UnitData）および `GameSession.initial_units`（Array、9要素）を使用する。

## 4. 実装詳細

### 4.1 バグ1修正: BoardManager.on_rest_drop() への board 書き込み追加

**問題**: `on_rest_drop()` は `GameSession.initial_units[index]` を更新するが、`board[0][row][col]` を更新していない。`GameUI.render_cell()` は `board_manager.get_unit(side, r, c)` を読むため、`board` が更新されないと描画が変わらない。

**変更箇所**: `scripts/BoardManager.gd` の `on_rest_drop()` 関数末尾（現在の `return true` の直前）

**追加コード**:

```gdscript
# board配列を更新（render_cell参照用）
board[side][row][col] = card_data
```

- `side` は関数内ですでに `var side: int = 0` と定義済みのため流用する
- `card_data` は引数で渡されてくる UnitData オブジェクトをそのまま代入する
- 既存の上書きチェック（`board[side][row][col] != null` の print）は変更不要

### 4.2 バグ1修正: RestScreenManager.on_board_cell_clicked() への render_cell 呼び出し追加

**問題**: 配置成功後に `render_cell()` が呼ばれていないため、盤面セルの Label が更新されない。

**変更箇所**: `scripts/RestScreenManager.gd` の `on_board_cell_clicked()` 関数内、`if board_manager.on_rest_drop(unit_data, row, col):` ブロックの先頭（`game_session.selected_deck.remove_at()` の直前）

**追加コード**:

```gdscript
# 盤面セル描画を更新
var main = get_node_or_null("/root/Main")
if main and main.get("game_ui") != null:
    main.game_ui.render_cell(0, row, col)
```

- `render_cell(side: int, r: int, c: int)` は `GameUI.gd` 380行目に定義済み
- `side = 0` は自陣固定
- `get_node_or_null` 失敗時は描画スキップのみ（エラー表示不要）

### 4.3 バグ2修正: create_card_view() への _get_drag_data 追加

**問題**: 手持ちカードの PanelContainer にドラッグ処理が未実装。

**変更箇所**: `scripts/RestScreenManager.gd` の `create_card_view()` 関数内、`if index >= 0:` ブロック（クリックイベント登録の後）

**追加コード**:

```gdscript
if index >= 0:
    card_panel.gui_input.connect(_on_hand_card_gui_input.bind(index))
    card_panel.set_drag_forwarding(
        _card_get_drag_data.bind(index),
        Callable(),
        Callable()
    )
```

`RestScreenManager.gd` に以下の関数を追加する（`create_card_view()` の近傍）:

```gdscript
func _card_get_drag_data(at_position: Vector2, index: int) -> Variant:
    if index < 0:
        return null
    var preview = Label.new()
    preview.text = "移動中"
    preview.add_theme_font_size_override("font_size", 12)
    set_drag_preview(preview)
    return {"card_index": index}
```

- 戻り値型 `Variant`（null または Dictionary `{"card_index": int}`）
- `set_drag_preview` は最小限のラベルで可（見た目の精緻化は対象外）

### 4.4 バグ2修正: _setup_board_click_overlay() への _can_drop_data / _drop_data 追加

**問題**: 盤面セルの Button にドロップ受け取り処理が未実装。

**変更箇所**: `scripts/RestScreenManager.gd` の `_setup_board_click_overlay()` 関数内、`cell_btn.pressed.connect(on_board_cell_clicked.bind(row, col))` の後

**追加コード**:

```gdscript
cell_btn.set_drag_forwarding(
    Callable(),
    _cell_can_drop_data.bind(row, col),
    _cell_drop_data.bind(row, col)
)
```

`RestScreenManager.gd` に以下の関数を追加する（`_setup_board_click_overlay()` の近傍）:

```gdscript
func _cell_can_drop_data(at_position: Vector2, data: Variant, _row: int, _col: int) -> bool:
    return data is Dictionary and data.has("card_index")

func _cell_drop_data(at_position: Vector2, data: Variant, row: int, col: int) -> void:
    if not (data is Dictionary and data.has("card_index")):
        return
    _selected_hand_index = data["card_index"]
    on_board_cell_clicked(row, col)
```

- `_cell_drop_data` は `_selected_hand_index` をセットしてから既存の `on_board_cell_clicked()` を呼ぶ
- `on_board_cell_clicked()` 内でクリアされるため、状態は整合する
- クリック配置（`_on_hand_card_gui_input` 経由）は変更なし

## 5. 受け入れ基準

- [ ] 手持ちカードをクリック選択後、盤面セルをクリックすると配置成功し、セルに `ユニット名\nHP xx/xx` が表示される
- [ ] 手持ちカードをドラッグして盤面セルにドロップすると配置成功し、セルにユニット名が表示される
- [ ] D&D配置後もクリック配置方式が引き続き動作する（`_selected_hand_index` による選択→セルクリック）
- [ ] 既存の上書き配置（既にユニットがいるセルへの配置）が正常に動作する
- [ ] `bash check_syntax.sh` エラー0件

## 6. 依存関係

- 前提タスク: なし（単独修正）
- 他ファイルへの影響:
  - `scripts/GameUI.gd` — 変更不要（`render_cell()` を呼び出すのみ）
  - `scripts/UnitData.gd` — 変更不要
  - `scripts/CardDB.gd` — 変更不要
- 既存関数の再利用:
  - `BoardManager.get_unit(side, row, col)` — `render_cell()` が内部で呼ぶ（変更不要）
  - `GameUI.render_cell(side, r, c)` — バグ1修正で呼び出し追加
  - `RestScreenManager.on_board_cell_clicked(row, col)` — バグ2修正で再利用

## 7. 制約・注意事項

- **足し算禁止**: 上記4箇所以外は変更しない
- **既存クリック動作の破壊禁止**: `_on_hand_card_gui_input` → `on_hand_card_clicked` のフローは変更しない
- `board[0][row][col]` への代入は UnitData オブジェクト（`card_data` 引数）をそのまま入れる。Dictionary 変換不要（`get_unit()` は `Object` を返す型定義）
- D&D の `set_drag_forwarding` 引数で不使用な Callable は `Callable()` で渡す（GDScript 4.x の流儀）
- `_cell_can_drop_data` / `_cell_drop_data` の引数 `_row`/`_col` のアンダースコアは未使用変数警告回避のためだが、`_drop_data` の `row`/`col` は使用するためアンダースコック不要
- 用語: `spd`（攻撃速度）/ `mana` / `col`（列）/ `range` は ssot_canonical_terms.txt 準拠（既存コードがすでに使用中、変更なし）
