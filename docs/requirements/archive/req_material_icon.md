STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# 素材アイコン実装 要件定義書

作成日: 2026-04-26
ステータス: 要件定義完了・実装待ち

---

## 概要

素材アイコン画像（PNG）を以下2箇所に組み込む。

1. **REQ-MI-1**: Inventory.gdの素材タブに素材アイコンを表示
2. **REQ-MI-2**: バトル中、敵ユニット撃破時に素材ドロップエフェクト（アイコン飛び出しアニメーション）を表示

---

## 前提条件

### アイコン画像配置規則

| 項目 | 仕様 |
|---|---|
| 保存先 | assets/materials/{id}.png |
| ファイル名 | {id} は cards.json の materials[].id と一致させること |
| サイズ | 任意（コード側でリサイズ） |

既存素材ID（2026-04-26時点）:
- iron_ore
- herb_bundle
- magic_stone
- beast_fang
- old_bone

---

## REQ-MI-1: Inventory 素材タブ

### 実装対象

改修ファイル: scripts/Inventory.gd

### 変更1: SORT_TABSに素材タブを追加（L24-31付近）

変更前の最後の要素の後に以下を追加:
    {"id": "materials", "label": "素材"},

### 変更2: _get_filtered_items() に素材フィルター追加

match文の末尾に以下を追加:

```
"materials":
    for mat_id in GameSession.materials:
        var count = GameSession.materials[mat_id]
        if count <= 0:
            continue
        var mat_data = _get_material_data(mat_id)
        result.append({"type": "material", "data": mat_data, "count": count})
```

### 変更3: 新規関数 _get_material_data() を追加

```
func _get_material_data(material_id: String) -> Dictionary:
    for mat in CardDB.MATERIALS:
        if mat.get("id", "") == material_id:
            return mat
    return {"id": material_id, "display": material_id}
```

### 変更4: _build_item_cell() に素材セル分岐を追加

関数先頭に以下を追加:

```
if item["type"] == "material":
    _build_material_cell(item, x, y)
    return
```

### 変更5: 新規関数 _build_material_cell() を追加

```
func _build_material_cell(item: Dictionary, x: int, y: int) -> void:
    var panel = Panel.new()
    panel.position = Vector2(x, y)
    panel.size = Vector2(CELL_SIZE, CELL_SIZE)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.12, 0.18)
    style.border_color = Color(0.6, 0.5, 0.3)
    style.set_border_width_all(2)
    style.set_corner_radius_all(4)
    panel.add_theme_stylebox_override("panel", style)
    _content_container.add_child(panel)

    var icon_rect = TextureRect.new()
    icon_rect.position = Vector2(8, 5)
    icon_rect.size = Vector2(38, 38)
    icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var tex = _load_material_icon(item["data"].get("id", ""))
    if tex:
        icon_rect.texture = tex
    else:
        var fallback = ColorRect.new()
        fallback.position = Vector2(8, 5)
        fallback.size = Vector2(38, 38)
        fallback.color = Color(0.6, 0.5, 0.3, 0.4)
        panel.add_child(fallback)
    panel.add_child(icon_rect)

    var name_lbl = Label.new()
    name_lbl.text = item["data"].get("display", "???")
    name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_lbl.position = Vector2(2, CELL_SIZE - 16)
    name_lbl.size = Vector2(CELL_SIZE - 4, 14)
    name_lbl.add_theme_font_size_override("font_size", 8)
    name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
    name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(name_lbl)

    var count_lbl = Label.new()
    count_lbl.text = "x%d" % item["count"]
    count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    count_lbl.position = Vector2(CELL_SIZE - 20, CELL_SIZE - 16)
    count_lbl.size = Vector2(18, 12)
    count_lbl.add_theme_font_size_override("font_size", 8)
    count_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
    count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(count_lbl)
```

### 変更6: 新規関数 _load_material_icon() を追加

```
func _load_material_icon(material_id: String) -> Texture2D:
    if material_id == "":
        return null
    var path = "res://assets/materials/%s.png" % material_id
    if ResourceLoader.exists(path):
        return load(path)
    return null
```

### 実装前確認事項

CardDB.gd に MATERIALS 定数が存在するか grep で確認すること。
存在しない場合は CardDB.gd に以下を追加:

```
static var MATERIALS: Array = []
```

そして _load_db() 内で以下を追加:

```
MATERIALS = data.get("materials", [])
```

---

## REQ-MI-2: バトル中ドロップエフェクト

### 実装対象

改修ファイル: scripts/Main.gd および scripts/GameUI.gd

### Main.gd 変更

変更箇所: L109 board_manager.synthesis_done.connect() の次の行に追加

追加内容:
```
board_manager.material_dropped.connect(_on_material_dropped)
```

追加関数:
```
func _on_material_dropped(material_id: String, count: int, side: int, row: int, col: int) -> void:
    game_ui.spawn_material_drop(material_id, count, side, row, col)
```

_process()内に追加（既存の update_damage_floats 呼び出し付近）:
```
game_ui.update_drop_effects(delta)
```

### GameUI.gd 変更

クラス先頭の変数定義エリアに追加:
```
var _active_drop_effects: Array = []
const MAX_DROP_EFFECTS = 3
```

追加関数群（spawn_damage_float 付近に追加）:

```
func spawn_material_drop(material_id: String, _count: int, side: int, row: int, col: int) -> void:
    if _active_drop_effects.size() >= MAX_DROP_EFFECTS:
        return
    var cell_x = _cell_x(side, col) + 59
    var cell_y = 80 + row * 108 + 52
    var icon_node = TextureRect.new()
    icon_node.size = Vector2(32, 32)
    icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var path = "res://assets/materials/%s.png" % material_id
    if ResourceLoader.exists(path):
        icon_node.texture = load(path)
    icon_node.position = Vector2(cell_x - 16, cell_y - 16)
    _main.add_child(icon_node)
    _active_drop_effects.append({
        "node": icon_node,
        "timer": 0.8,
        "start_x": float(cell_x - 16),
        "start_y": float(cell_y - 16),
        "offset_x": randf_range(-20.0, 20.0),
    })

func update_drop_effects(delta: float) -> void:
    var finished: Array = []
    for effect in _active_drop_effects:
        effect["timer"] -= delta
        var t = 1.0 - (effect["timer"] / 0.8)
        var node = effect["node"]
        if not is_instance_valid(node):
            finished.append(effect)
            continue
        node.position.x = effect["start_x"] + effect["offset_x"] * t
        node.position.y = effect["start_y"] - 60.0 * t
        if t > 0.5:
            node.modulate.a = 1.0 - (t - 0.5) * 2.0
        if effect["timer"] <= 0.0:
            node.queue_free()
            finished.append(effect)
    for done in finished:
        _active_drop_effects.erase(done)
```

### 注意: _main 変数名の確認

GameUI.gd の setup() 関数内で Main.gd への参照変数名を確認してから実装すること。
現在の変数名が _main でない場合は上記コードの変数名を合わせること。

---

## アニメーション仕様

| 項目 | 仕様 |
|---|---|
| アイコンサイズ | 32x32px |
| 開始位置 | 撃破セル中央座標 |
| 移動量 | Y方向 -60px + X方向 ランダム±20px |
| 所要時間 | 0.8秒 |
| フェードアウト | 0.4秒時点から透明度0に |
| 同時表示上限 | 3個 |

---

## 実装チェックリスト

### REQ-MI-1 実装前
- [ ] assets/materials/ ディレクトリを作成してアイコン画像を配置
- [ ] CardDB.gd に MATERIALS 定数が存在するか grep で確認
- [ ] GameSession.materials が Dictionary 型であることを確認（確認済み）

### REQ-MI-1 実装後
- [ ] bash check_syntax.sh エラー0件
- [ ] Inventory画面で「素材」タブが表示される
- [ ] 素材セルにアイコン画像が表示される（フォールバックも確認）
- [ ] 個数バッジ（x1など）が右下に表示される

### REQ-MI-2 実装前
- [ ] Main.gd に material_dropped 未接続を確認（確認済み）
- [ ] GameUI.gd の setup() 内の Main 参照変数名を確認

### REQ-MI-2 実装後
- [ ] bash check_syntax.sh エラー0件
- [ ] バトル中に敵撃破でエフェクトが出る
- [ ] エフェクトが 0.8秒で消える
- [ ] 4個以上同時ドロップ時に3個で止まる

---

## 実装順序

1. assets/materials/ ディレクトリを作成してアイコン画像を配置（ユーザー作業）
2. REQ-MI-1（Inventory.gd改修）を実装・テスト
3. REQ-MI-2（Main.gd + GameUI.gd改修）を実装・テスト
