# Inventory.gd
# 持ち物画面（タスクバーから遷移）
# DeckPrepの持ち物タブロジックを移植
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: Node = null
var _selected_filter: String = "all"
var _selected_material: Dictionary = {}
var _content_container: Control = null

# グリッド定数（DeckPrepと統一）
const CELL_SIZE = 55
const CELL_GAP  = 8
const GRID_COLS = 16   # 1280px幅: (1280 - 40) / (55+8) ≈ 19.7 → 余白考慮で16列
const GRID_ROWS = 8
const TOTAL_SLOTS = GRID_COLS * GRID_ROWS
const GRID_OFFSET_X = 140  # (1280 - (16*55+15*8)) / 2 = 140 で線対称
const GRID_OFFSET_Y = 44   # ソートタブ(32px) + 余白(12px)

# ソートタブ定義
const SORT_TABS = [
	{"id": "all",       "label": "全体"},
	{"id": "common",    "label": "Common"},
	{"id": "uncommon",  "label": "Uncommon"},
	{"id": "rare",      "label": "Rare"},
	{"id": "boss",      "label": "Boss"},
]

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.INVENTORY)

	UIF.add_title(self, "持ち物", 50)

	# コンテンツエリア（タスクバー下）
	_content_container = Control.new()
	_content_container.position = Vector2(0, 100)
	_content_container.size = Vector2(1280, 580)
	add_child(_content_container)

	_build_sort_tabs()
	_build_grid()

	var back_btn = Button.new()
	back_btn.text = "戻る"
	back_btn.position = Vector2(590, 680)
	back_btn.size = Vector2(100, 36)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _build_sort_tabs() -> void:
	# 5タブ × 80幅 + 4ギャップ × 8 = 432。中央揃え: (1280-432)/2=424
	var x = 424
	for tab in SORT_TABS:
		var btn = Button.new()
		btn.text = tab["label"]
		btn.position = Vector2(x, 5)
		btn.size = Vector2(80, 26)
		btn.add_theme_font_size_override("font_size", 12)
		if tab["id"] == _selected_filter:
			btn.modulate = Color(1.0, 1.0, 0.5)
		var tab_id = tab["id"]
		btn.pressed.connect(func(): _set_filter(tab_id))
		_content_container.add_child(btn)
		x += 88

func _set_filter(filter: String) -> void:
	_selected_filter = filter
	for child in _content_container.get_children():
		child.queue_free()
	_build_sort_tabs()
	_build_grid()

func _get_filtered_items() -> Array:
	var result: Array = []
	for artifact_id in GameSession.artifacts:
		var artifact_data = _get_artifact_data(artifact_id)
		if artifact_data.is_empty():
			continue
		var rarity = artifact_data.get("rarity", "common")
		match _selected_filter:
			"all":
				result.append({"type": "artifact", "data": artifact_data})
			"common":
				if rarity == "common":
					result.append({"type": "artifact", "data": artifact_data})
			"uncommon":
				if rarity == "uncommon":
					result.append({"type": "artifact", "data": artifact_data})
			"rare":
				if rarity == "rare":
					result.append({"type": "artifact", "data": artifact_data})
			"boss":
				if rarity == "boss":
					result.append({"type": "artifact", "data": artifact_data})
	return result

func _get_artifact_data(artifact_id: String) -> Dictionary:
	if CardDB.ARTIFACTS.has(artifact_id):
		return CardDB.ARTIFACTS[artifact_id]
	return {}


func _build_grid() -> void:
	var items = _get_filtered_items()
	var ox = GRID_OFFSET_X
	var oy = GRID_OFFSET_Y
	for i in range(TOTAL_SLOTS):
		var col_i = i % GRID_COLS
		var row_i = i / GRID_COLS
		var x = ox + col_i * (CELL_SIZE + CELL_GAP)
		var y = oy + row_i * (CELL_SIZE + CELL_GAP)
		if i < items.size():
			_build_item_cell(items[i], x, y)
		else:
			_build_empty_cell(x, y)

func _build_item_cell(item: Dictionary, x: int, y: int) -> void:
	var panel = Panel.new()
	panel.position = Vector2(x, y)
	panel.size = Vector2(CELL_SIZE, CELL_SIZE)
	var style = StyleBoxFlat.new()
	var rarity = item["data"].get("rarity", "common")
	style.bg_color = Color(0.12, 0.12, 0.18)
	# レアリティ別の枠線色
	match rarity:
		"common":
			style.border_color = Color(0.6, 0.6, 0.6)  # グレー
		"uncommon":
			style.border_color = Color(0.3, 0.7, 0.4)  # 緑
		"rare":
			style.border_color = Color(0.4, 0.5, 0.9)  # 青
		"boss":
			style.border_color = Color(0.9, 0.4, 0.2)  # オレンジ
		_:
			style.border_color = Color(0.5, 0.5, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	_content_container.add_child(panel)

	var icon_bg = ColorRect.new()
	icon_bg.position = Vector2(3, 3)
	icon_bg.size = Vector2(CELL_SIZE - 6, CELL_SIZE - 18)
	icon_bg.color = style.border_color * Color(1, 1, 1, 0.25)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_bg)

	# アーティファクト名表示
	var name_lbl = Label.new()
	name_lbl.text = item["data"].get("display", "???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(2, CELL_SIZE - 16)
	name_lbl.size = Vector2(CELL_SIZE - 4, 14)
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)

	var artifact_ref = item["data"]
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_material = artifact_ref
	)

func _build_empty_cell(x: int, y: int) -> void:
	var panel = Panel.new()
	panel.position = Vector2(x, y)
	panel.size = Vector2(CELL_SIZE, CELL_SIZE)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09)
	style.border_color = Color(0.12, 0.12, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	_content_container.add_child(panel)

func _on_back() -> void:
	var prev = GameSession.last_scene
	if prev == "":
		prev = SceneManager.MAP_SELECT
	SceneManager.go_to(prev)
