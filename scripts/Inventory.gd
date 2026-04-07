# Inventory.gd
# 持ち物画面（タスクバーから遷移）
# DeckPrepの持ち物タブロジックを移植
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null
var _selected_filter: String = "all"
var _selected_material: Dictionary = {}
var _content_container: Control = null

# グリッド定数（DeckPrepと統一）
const CELL_SIZE = 55
const CELL_GAP  = 8
const GRID_COLS = 16   # 1280px幅: (1280 - 40) / (55+8) ≈ 19.7 → 余白考慮で16列
const GRID_ROWS = 8
const TOTAL_SLOTS = GRID_COLS * GRID_ROWS
const GRID_OFFSET_X = 20
const GRID_OFFSET_Y = 44   # ソートタブ(32px) + 余白(12px)

# ソートタブ定義
const SORT_TABS = [
	{"id": "all",       "label": "全体"},
	{"id": "equipment", "label": "装備"},
	{"id": "normal",    "label": "素材"},
	{"id": "cursed",    "label": "呪い"},
	{"id": "consumable","label": "消費"},
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
	var x = 20
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
	if _selected_filter == "all" or _selected_filter == "equipment":
		pass  # 将来: GameSession.equipment から生成
	if _selected_filter != "equipment":
		for mat in CardDB.MATERIALS:
			var is_cursed = mat.get("is_cursed", false)
			var is_consumable = mat.get("is_consumable", false)
			var count = _count_owned(mat.get("id", ""))
			if count <= 0:
				continue
			match _selected_filter:
				"all":
					result.append({"type": "material", "data": mat, "count": count})
				"normal":
					if not is_cursed and not is_consumable:
						result.append({"type": "material", "data": mat, "count": count})
				"cursed":
					if is_cursed:
						result.append({"type": "material", "data": mat, "count": count})
				"consumable":
					if is_consumable:
						result.append({"type": "material", "data": mat, "count": count})
	return result

func _count_owned(mat_id: String) -> int:
	var count = 0
	for m in GameSession.materials:
		if m is Dictionary and m.get("id", "") == mat_id:
			count += 1
	return count

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
	var item_type = item.get("type", "material")
	var is_cursed = item["data"].get("is_cursed", false) if item_type == "material" else false
	style.bg_color = Color(0.12, 0.12, 0.18)
	if item_type == "equipment":
		style.border_color = Color(0.6, 0.5, 0.2)
	elif is_cursed:
		style.border_color = Color(0.8, 0.3, 0.5)
	else:
		style.border_color = Color(0.3, 0.5, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	_content_container.add_child(panel)

	var icon_bg = ColorRect.new()
	icon_bg.position = Vector2(3, 3)
	icon_bg.size = Vector2(CELL_SIZE - 6, CELL_SIZE - 18)
	icon_bg.color = style.border_color * Color(1, 1, 1, 0.25)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_bg)

	var count = item.get("count", 1)
	if count >= 2:
		var stack_lbl = Label.new()
		stack_lbl.text = "×%d" % count
		stack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack_lbl.position = Vector2(2, CELL_SIZE - 16)
		stack_lbl.size = Vector2(CELL_SIZE - 4, 14)
		stack_lbl.add_theme_font_size_override("font_size", 9)
		stack_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		stack_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(stack_lbl)

	var mat_ref = item["data"]
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_material = mat_ref
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
