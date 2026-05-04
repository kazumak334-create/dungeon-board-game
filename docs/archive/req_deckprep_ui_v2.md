# 要件定義書: DeckPrep UI v2

作成日: 2026-04-24  
対象フェーズ: Phase 4  
対象ファイル: `scripts/RestScreenManager.gd`, `scripts/BoardManager.gd`, `scripts/GameSession.gd`

---

## 概要

RestScreenManager のカード操作UX改善・呪文タブ追加・マナ表示追加。  
BoardManager に盤面内D&D用新関数を追加。  
GameSession に `spell_available` 変数を追加。

---

## REQ-1: ドラッグプレビュー改善

### 対象
`scripts/RestScreenManager.gd` の `_card_get_drag_data()`

### 現状
- `Label.new()` で「移動中」文字をプレビューに使用

### 要件
- `create_card_view(card_data_dict, card_name, -1)` でカードビジュアルコピーを生成してプレビューに使用する
- 「移動中です」文字は削除する
- `-1` インデックスを渡すことでクリック/ドラッグイベントを付与しない（無限ループ防止）

### 実装方針
```gdscript
# _card_get_drag_data() 変更箇所
func _card_get_drag_data(at_position: Vector2, index: int) -> Variant:
    if index < 0:
        return null
    # カードデータ取得（selected_deck[index] から）
    var card_name = ...  # 既存ロジックで取得
    var card_data = ...  # 既存ロジックで取得
    var preview = create_card_view(card_data, card_name, -1)
    set_drag_preview(preview)
    return {"card_index": index}
```

---

## REQ-2: 盤面D&D拡張

### REQ-2a: 盤面→盤面入れ替え

#### 対象
`scripts/RestScreenManager.gd` の `_setup_board_click_overlay()` / `_cell_drop_data()`  
`scripts/BoardManager.gd` に新関数追加

#### 要件
1. `_setup_board_click_overlay()` の `cell_btn` に `_board_cell_get_drag_data` を `set_drag_forwarding` の第1引数に登録する
2. ドラッグデータ形式: `{"board_row": row, "board_col": col, "card_data": <UnitDataまたはDictionary>}`
3. `_cell_can_drop_data` を拡張して `board_row` キーも受け付ける（`card_index` と `board_row` の両方を許容）
4. `_cell_drop_data` を拡張して `board_row` キーがある場合に `BoardManager.swap_rest_cells()` を呼ぶ

#### BoardManager 新関数: `swap_rest_cells(from_r, from_c, to_r, to_c)`
```
- 引数: from_r: int, from_c: int, to_r: int, to_c: int
- 処理:
  1. from と to の board[0][row][col] を入れ替える
  2. GameSession.initial_units の該当インデックス（row*3+col）を入れ替える
  3. どちらかが null の場合も入れ替え（null ↔ データ も OK）
- 戻り値: なし（void）
```

#### `_board_cell_get_drag_data` 実装方針
```gdscript
func _board_cell_get_drag_data(at_position: Vector2, row: int, col: int) -> Variant:
    # board_manager.board[0][row][col] が null なら null を返す
    var cell_data = board_manager.board[0][row][col]
    if cell_data == null:
        return null
    # カード名取得: cell_data が UnitData なら .unit_name、Dictionary なら ["name"]
    var card_name = ...
    var card_data_dict = ...  # HP/ATK/mana/race等のDictionary
    var preview = create_card_view(card_data_dict, card_name, -1)
    set_drag_preview(preview)
    return {"board_row": row, "board_col": col, "card_data": cell_data}
```

### REQ-2b: 盤面→手持ち戻し

#### 対象
`scripts/RestScreenManager.gd` の `build_ui()` / `hand_area` 設定箇所  
`scripts/BoardManager.gd` に新関数追加

#### 要件
1. `hand_area`（GridContainer）に `set_drag_forwarding` を設定し、ドロップ受付を有効にする
2. `board_row` キーを持つデータがドロップされたら `BoardManager.remove_rest_unit(row, col)` を呼ぶ
3. 戻し後に `rebuild_hand_area()` を呼ぶ

#### BoardManager 新関数: `remove_rest_unit(row, col)`
```
- 引数: row: int, col: int
- 処理:
  1. board[0][row][col] を null にする
  2. GameSession.initial_units[row*3+col] を null にする
  3. render_cell(0, row, col) などの再描画処理があれば呼ぶ（既存の hide_rest_cell パターンに合わせる）
- 戻り値: なし（void）
```

#### `hand_area` の drag_forwarding 実装方針
```gdscript
# build_ui() または build_hand_area() 内で hand_area に設定
hand_area.set_drag_forwarding(
    Callable(),  # drag_data不要
    _hand_area_can_drop_data,
    _hand_area_drop_data
)

func _hand_area_can_drop_data(at_position: Vector2, data: Variant) -> bool:
    return data is Dictionary and data.has("board_row")

func _hand_area_drop_data(at_position: Vector2, data: Variant) -> void:
    if not (data is Dictionary and data.has("board_row")):
        return
    var row = data["board_row"]
    var col = data["board_col"]
    board_manager.remove_rest_unit(row, col)
    rebuild_hand_area()
```

---

## REQ-3: カードフレームビジュアル

### 対象
`scripts/RestScreenManager.gd` の `create_card_view()`

### 現状
- 単一背景色 `Color(0.15,0.15,0.2)` / ボーダー色 `Color(0.4,0.4,0.5)` / 1px
- HP/ATK のみ表示、カード名 size=10

### 要件

#### レアリティ別背景色
| rarity | bg_color |
|--------|----------|
| common | `Color(0.15, 0.15, 0.20)` |
| uncommon | `Color(0.10, 0.18, 0.10)` |
| rare | `Color(0.10, 0.12, 0.22)` |
| epic | `Color(0.18, 0.10, 0.22)` |
| (デフォルト) | `Color(0.15, 0.15, 0.20)` |

#### レアリティ別ボーダー色
| rarity | border_color |
|--------|--------------|
| common | `Color(0.5, 0.5, 0.55)` |
| uncommon | `Color(0.3, 0.6, 0.3)` |
| rare | `Color(0.3, 0.4, 0.8)` |
| epic | `Color(0.6, 0.3, 0.8)` |
| (デフォルト) | `Color(0.5, 0.5, 0.55)` |

#### ボーダー太さ
- common: 1px
- uncommon/rare/epic: 2px

#### テキスト配置（カードサイズ 60x95px 固定）
| 要素 | y座標 | font_size | 備考 |
|------|-------|-----------|------|
| カード名 | y=2 | 9 | x=2, w=56, autowrap |
| 種族2文字 | y=33 | 8 | race の先頭2文字 |
| HP | y=48 | 9 | "HP %d" |
| ATK | y=58 | 9 | "ATK %d" |
| Mana | y=68 | 9 | "Mana %d", font_color=`Color(0.4, 0.7, 1.0)` |

#### rarity の取得方法
- `card_data_dict.get("rarity", "common")` で取得

---

## REQ-4: 呪文タブ

### REQ-4a: GameSession への変数追加

#### 対象
`scripts/GameSession.gd`

#### 要件
- `spell_slots` 変数の直下に以下を追加:
  ```gdscript
  var spell_available: Array = []  # 入手済み呪文リスト（今回は空スタート）
  ```
- `reset()` 関数内で `spell_available = []` を追加する（`spell_slots = []` の直下）

### REQ-4b: RestScreenManager へのタブ追加

#### 対象
`scripts/RestScreenManager.gd` の `build_ui()` および手持ちエリア構築箇所

#### 要件

##### TabBar の追加
- 手持ちカードリスト（card_list バー）の上部に TabBar を追加
- タブ構成: `["ユニット", "呪文"]`（インデックス 0=ユニット, 1=呪文）
- タブ切り替えで表示コンテンツを切り替える

##### 呪文タブUI（タブ1選択時）
- スロット表示: `game_session.spell_slots` を3枠縦並びで表示
  - 空スロット: "（空）" を表示
  - 設定済みスロット: spell_name と condition を表示
- spell_available スクロールリスト: `game_session.spell_available` をリスト表示
  - 今回は空配列スタートのため「呪文なし」ラベルを表示

##### 実装方針
- `var _tab_index: int = 0` をフィールドに追加
- `_on_tab_changed(tab: int)` を新規追加:
  ```gdscript
  func _on_tab_changed(tab: int) -> void:
      _tab_index = tab
      rebuild_hand_area()
  ```
- `build_hand_area()` 内で `_tab_index` に応じてユニットリストまたは呪文UIを表示

---

## REQ-5: マナ総量表示

### 対象
`scripts/RestScreenManager.gd` の `build_ui()` / フッター構築箇所

### 既存フッター
- `LAYOUT.footer = {x:200, y:680, w:780, h:40}`

### 要件
フッター左端付近（x=205 付近）に以下の2ラベルを追加（縦に並べる or 横並び）:

| ラベル | テキスト形式 | font_color | font_size |
|--------|------------|------------|-----------|
| 盤面Mana | "盤面Mana: XX" | `Color(0.4, 0.7, 1.0)` | 12 |
| 呪文Mana | "呪文Mana: XX" | `Color(0.7, 0.5, 1.0)` | 12 |

#### 計算式
- 盤面Mana: `game_session.initial_units` の各要素（非null）の mana 合計
  - `initial_units[i]` は `{"name": ..., "row": ..., "col": ...}` のDictionary
  - カード名から `CardDB.UNITS[name].get("mana", 0)` を参照して合計する
- 呪文Mana: `game_session.spell_slots` の各要素（非null）の mana 合計
  - `spell_slots[i]` は `{"spell_name": ..., "condition": ...}` のDictionary
  - 呪文マナ計算は今回はプレースホルダ（0固定でも可）

#### マナラベル更新タイミング
- `build_ui()` 時に初回設定
- `rebuild_hand_area()` 呼び出し後にも更新（関数 `_refresh_mana_labels()` を新規追加）

---

## 受け入れ基準

- [ ] ドラッグ時にカードビジュアルが表示される（「移動中」文字なし）
- [ ] 盤面→盤面D&Dでユニット入れ替えができる（`swap_rest_cells` 動作）
- [ ] 盤面→手持ちエリアD&Dでカードが戻る（`remove_rest_unit` + `rebuild_hand_area` 動作）
- [ ] 手持ちカードがレアリティ別カードフレームで表示される
- [ ] ユニット/呪文タブが切り替えられる
- [ ] 呪文タブに「呪文なし」が表示される（spell_available 空配列）
- [ ] 盤面Mana・呪文Manaがフッターに表示される
- [ ] `check_syntax.sh` エラー0件

---

## 変更対象ファイルまとめ

| ファイル | 変更内容 |
|---------|---------|
| `scripts/RestScreenManager.gd` | REQ-1,2,3,4b,5 |
| `scripts/BoardManager.gd` | REQ-2a(swap_rest_cells), REQ-2b(remove_rest_unit) 新規追加 |
| `scripts/GameSession.gd` | REQ-4a: spell_available 変数追加・reset()更新 |

---

## 制約・注意事項

- `BoardManager.board` は `board[side][row][col]` のアクセス形式（side=0が自陣）
- `GameSession` は `get_node_or_null("/root/GameSession")` で取得（BoardManager内）
- `create_card_view()` は index=-1 時にはイベント登録しない（既存実装通り）
- 手持ちエリア (`hand_area`) の drag_forwarding は `build_hand_area()` でなく `build_ui()` 内で1回だけ設定する（rebuild 時に二重設定しない）

---

## REQ-6: 呪文カード形式UI＆デッキ編成

作成日: 2026-04-24

### 概要

`spell_available` の呪文をカード形式で表示し、ダブルクリックで `spell_deck` に追加、右クリックで削除できるUIを実装する。マナ制約（spell_deck総マナ ≤ 盤面ユニット総マナ）を超える追加は拒否し、視覚的フィードバックを表示する。

---

### REQ-6a: GameSession への spell_deck 追加

#### 対象
`scripts/GameSession.gd`

#### 要件
- `spell_available` 変数の直下に以下を追加:
  ```gdscript
  var spell_deck: Array = []  # 選択済み呪文デッキ（マナ制約あり・枚数上限なし）
  ```
- `reset()` 関数内で `spell_available = []` の直下に追加:
  ```gdscript
  spell_deck = []
  ```

---

### REQ-6b: 呪文タブUI（RestScreenManager）

#### 対象
`scripts/RestScreenManager.gd` の呪文タブ表示部分（`_tab_index == 1` のブランチ）

#### 現状
- `spell_available` をラベル文字列で表示している
- `spell_deck` の概念・表示なし

#### 要件

##### レイアウト構造
呪文タブ（`_tab_index == 1`）のコンテンツを以下に差し替える:

1. **上部: spell_available 一覧（カード形式）**
   - `create_card_view()` を流用して `CARD_MINI` サイズで表示
   - 呪文カードデータは `CardDB.SPELLS[spell_name]` から取得（キーがない場合は `{}` 扱い）
   - 空の場合: "入手済み呪文なし" ラベル表示
   - ダブルクリック検知: `InputEventMouseButton` の `double_click == true` かつ `button_index == MOUSE_BUTTON_LEFT`
   - ダブルクリック時: `_on_spell_available_double_click(spell_name)` を呼ぶ

2. **下部: spell_deck 選択済みリスト（カード形式）**
   - セクションラベル: "選択済み呪文デッキ" (font_size=11)
   - `game_session.spell_deck` をカード形式で表示
   - 空の場合: "なし" ラベル表示
   - 右クリック検知: `InputEventMouseButton` の `button_index == MOUSE_BUTTON_RIGHT`
   - 右クリック時: `_on_spell_deck_right_click(index)` を呼ぶ

3. **マナ制約表示ラベル**
   - "呪文Mana: XX / 盤面Mana: XX" 形式のラベルをセクション上部に表示
   - font_color: `Color(0.7, 0.5, 1.0)` / font_size: 11
   - `rebuild_hand_area()` のたびに再計算・更新

---

### REQ-6c: マナ制約チェック関数

#### 対象
`scripts/RestScreenManager.gd` に新規追加

#### 関数: `_calc_board_mana() -> int`
```gdscript
func _calc_board_mana() -> int:
    var total: int = 0
    for unit_entry in game_session.initial_units:
        if unit_entry == null:
            continue
        var unit_name: String = unit_entry.get("name", "")
        if unit_name != "" and CardDB.UNITS.has(unit_name):
            total += CardDB.UNITS[unit_name].get("mana", 0)
    return total
```

#### 関数: `_calc_spell_deck_mana() -> int`
```gdscript
func _calc_spell_deck_mana() -> int:
    var total: int = 0
    for spell_name in game_session.spell_deck:
        if CardDB.SPELLS.has(spell_name):
            total += CardDB.SPELLS[spell_name].get("mana", 0)
    return total
```

#### 関数: `_on_spell_available_double_click(spell_name: String) -> void`
```gdscript
func _on_spell_available_double_click(spell_name: String) -> void:
    var spell_mana: int = 0
    if CardDB.SPELLS.has(spell_name):
        spell_mana = CardDB.SPELLS[spell_name].get("mana", 0)
    var board_mana: int = _calc_board_mana()
    var current_spell_mana: int = _calc_spell_deck_mana()
    if current_spell_mana + spell_mana > board_mana:
        _show_spell_mana_error()
        return
    game_session.spell_deck.append(spell_name)
    rebuild_hand_area()
```

#### 関数: `_on_spell_deck_right_click(index: int) -> void`
```gdscript
func _on_spell_deck_right_click(index: int) -> void:
    if index < 0 or index >= game_session.spell_deck.size():
        return
    game_session.spell_deck.remove_at(index)
    rebuild_hand_area()
```

#### 関数: `_show_spell_mana_error() -> void`
```gdscript
func _show_spell_mana_error() -> void:
    # error_label にエラーメッセージを表示（既存の error_label フィールドを流用）
    if error_label:
        error_label.text = "マナ不足: 呪文Manaが盤面Manaを超えます"
        error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
        # 2秒後にクリア（既存パターンに合わせる）
        get_tree().create_timer(2.0).timeout.connect(func():
            if error_label:
                error_label.text = ""
        )
```

---

### REQ-6d: _refresh_mana_labels() の更新

#### 対象
`scripts/RestScreenManager.gd` の `_refresh_mana_labels()`

#### 現状
- `spell_mana` が `0` 固定（プレースホルダ）

#### 要件
- `spell_mana` の計算を `_calc_spell_deck_mana()` に置き換える:
  ```gdscript
  var spell_mana: int = _calc_spell_deck_mana()
  ```

---

### 制約・注意事項

- `CardDB.SPELLS` が存在しない場合は `{}` を返すか、`has()` チェックを徹底する
- `spell_deck` には呪文名（String）を格納する（辞書ではなく文字列）
- カードビジュアルに登録するクリックイベントは `index >= 0` のときのみ（`create_card_view()` 既存ルール通り）
- 呪文カードのダブルクリック検知は `_input_event` コールバックを `PanelContainer` の `gui_input` シグナルに接続する形式で実装する
- `_tab_index == 1` のブランチを全面差し替えするが、スロット表示（REQ-4b由来）は削除して spell_available + spell_deck の2セクション構成に変更する

---

### 受け入れ基準

- [ ] `GameSession.spell_deck` 変数が存在し、`reset()` で初期化される
- [ ] 呪文タブに spell_available がカード形式で表示される（空時は「入手済み呪文なし」）
- [ ] 呪文タブに spell_deck がカード形式で表示される（空時は「なし」）
- [ ] ダブルクリックで spell_deck に追加される
- [ ] マナ上限超過時は追加拒否 + error_label にエラーメッセージ表示
- [ ] 右クリックで spell_deck から削除される
- [ ] _refresh_mana_labels() が spell_deck の実際のマナを表示する
- [ ] `check_syntax.sh` エラー0件
