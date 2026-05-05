class_name BuildQueueUI
extends PanelContainer

signal instant_build_requested(site: Dictionary)
signal cancel_requested(site: Dictionary)
signal reorder_requested(site: Dictionary, target_index: int)

const LABOR_COST_PER_UNIT := 5
const ITEM_HEIGHT := 56.0
const MAX_VISIBLE_ITEMS := 5

var battle: EconBattle = null
var economy: EconEconomy = null

var _list: VBoxContainer = null
var _empty_label: Label = null
var _worker_label: Label = null
var _drag_panel_id: Vector2i = Vector2i(-1, -1)
var _selected_panel_id: Vector2i = Vector2i(-1, -1)
var _drag_start_y: float = 0.0
var _dragging := false
var _items: Array = []

func setup(new_battle: EconBattle, new_economy: EconEconomy) -> void:
	battle = new_battle
	economy = new_economy
	position = Vector2(0.0, 100.0)
	custom_minimum_size = Vector2(100.0, 420.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.075, 0.055, 0.84)
	panel_style.border_color = Color(0.35, 0.29, 0.20, 0.95)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", panel_style)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var title := Label.new()
	title.text = "BUILD QUEUE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.70, 0.58, 0.28))
	root.add_child(title)
	_worker_label = Label.new()
	_worker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_worker_label.add_theme_font_size_override("font_size", 10)
	root.add_child(_worker_label)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	root.add_child(_list)
	_empty_label = Label.new()
	_empty_label.text = "empty"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 10)
	_empty_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.43))
	root.add_child(_empty_label)
	refresh()

func _process(_delta: float) -> void:
	if _drag_panel_id != Vector2i(-1, -1):
		return
	refresh()

func refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	_items.clear()
	var sites := get_queue_buildings()
	visible = true
	if _empty_label != null:
		_empty_label.visible = sites.is_empty()
	if _worker_label != null:
		_worker_label.text = ""
	for i in range(mini(MAX_VISIBLE_ITEMS, sites.size())):
		var site: Dictionary = sites[i]
		var item := _create_item(site, i + 1)
		_list.add_child(item)
		_items.append(item)

func get_queue_buildings() -> Array:
	if battle == null or battle.grid == null:
		return []
	var sites: Array = []
	for pos in battle.grid.construction_sites:
		sites.append(battle.grid.construction_sites[pos])
	sites.sort_custom(func(a, b): return a["started_at"] < b["started_at"])
	return sites

func calc_instant_build_cost_from_site(site: Dictionary) -> int:
	var total_labor_units: float = float(site.get("construction_time", 1.0))
	if total_labor_units <= 0.0:
		return 0
	var progress: float = clampf(float(site.get("construction_progress", 0.0)), 0.0, 1.0)
	var remaining_labor: float = maxf(0.0, total_labor_units * (1.0 - progress))
	if remaining_labor <= 0.0:
		return 0
	return int(ceil(remaining_labor * float(LABOR_COST_PER_UNIT)))

func _find_construction_site_by_pos(pos: Vector2i) -> Dictionary:
	if battle == null or battle.grid == null:
		return {}
	if battle.grid.construction_sites.has(pos):
		return battle.grid.construction_sites[pos]
	return {}

func _create_item(site: Dictionary, index: int) -> Control:
	var item := BuildQueueItem.new()
	item.custom_minimum_size = Vector2(100.0, ITEM_HEIGHT)
	var btype: int = int(site.get("building_type", 0))
	var raw_progress: float = float(site.get("construction_progress", 0.0))
	var progress: float = clampf(raw_progress, 0.0, 1.0)
	item.building = _find_construction_site_by_pos(site.get("panel_id", Vector2i(-1, -1)))
	item.queue_index = index
	item.building_name = _get_building_name(btype)
	item.progress = progress
	item.cost_g = calc_instant_build_cost_from_site(site)
	item.can_pay = economy != null and economy.currency >= item.cost_g
	item.stopped = not site.get("is_active", false)
	item.is_selected = (site.get("panel_id", Vector2i(-1, -1)) == _selected_panel_id)
	item.gui_input.connect(_on_item_gui_input.bind(site.get("panel_id", Vector2i(-1, -1))))
	return item

func _on_item_gui_input(event: InputEvent, panel_id: Vector2i) -> void:
	var building: Dictionary = _find_construction_site_by_pos(panel_id)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_panel_id = panel_id
				_drag_start_y = mb.global_position.y
				_dragging = false
			else:
				if _drag_panel_id != Vector2i(-1, -1) and _dragging:
					var sites: Array = get_queue_buildings()
					var tgt: int = clampi(int(floor((mb.global_position.y - global_position.y - 20.0) / ITEM_HEIGHT)) + 1, 1, maxi(1, sites.size()))
					if not building.is_empty():
						reorder_requested.emit(building, tgt)
				elif _drag_panel_id == panel_id and panel_id != Vector2i(-1, -1):
					if _selected_panel_id == panel_id:
						print("[BQ] instant_build_requested: pos=", panel_id, " building=", building)
						instant_build_requested.emit(building)
						_selected_panel_id = Vector2i(-1, -1)
					else:
						print("[BQ] selected panel: ", panel_id)
						_selected_panel_id = panel_id
				_drag_panel_id = Vector2i(-1, -1)
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not building.is_empty():
				cancel_requested.emit(building)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _drag_panel_id != Vector2i(-1, -1):
			if absf(event.global_position.y - _drag_start_y) >= 10.0:
				_dragging = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var local_y: float = mb.position.y
		var sites: Array = get_queue_buildings()
		var site_idx: int = _get_site_index_at_y(local_y, sites.size())
		var site: Dictionary = sites[site_idx] if site_idx >= 0 else {}
		var panel_id: Vector2i = site.get("panel_id", Vector2i(-1, -1)) if not site.is_empty() else Vector2i(-1, -1)
		var building: Dictionary = _find_construction_site_by_pos(panel_id)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_panel_id = panel_id
				_drag_start_y = mb.global_position.y
				_dragging = false
			else:
				if _drag_panel_id != Vector2i(-1, -1) and _dragging:
					var tgt: int = clampi(int(floor((mb.global_position.y - global_position.y - 20.0) / ITEM_HEIGHT)) + 1, 1, maxi(1, sites.size()))
					if not building.is_empty():
						reorder_requested.emit(building, tgt)
				elif _drag_panel_id == panel_id and panel_id != Vector2i(-1, -1):
					if _selected_panel_id == panel_id:
						print("[BQ] instant_build_requested: pos=", panel_id, " building=", building)
						instant_build_requested.emit(building)
						_selected_panel_id = Vector2i(-1, -1)
					else:
						print("[BQ] selected panel: ", panel_id)
						_selected_panel_id = panel_id
				_drag_panel_id = Vector2i(-1, -1)
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not building.is_empty():
				cancel_requested.emit(building)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _drag_panel_id != Vector2i(-1, -1):
			if absf(event.global_position.y - _drag_start_y) >= 10.0:
				_dragging = true

func _get_site_index_at_y(local_y: float, total_count: int) -> int:
	if _list == null or total_count == 0:
		return -1
	var list_top: float = (_list.global_position - global_position).y
	var sep: float = float(_list.get_theme_constant("separation"))
	for i in range(mini(MAX_VISIBLE_ITEMS, total_count)):
		var item_top: float = list_top + i * (ITEM_HEIGHT + sep)
		var item_bottom: float = item_top + ITEM_HEIGHT
		if local_y >= item_top and local_y < item_bottom:
			return i
	return -1

func _get_building_name(building_type: int) -> String:
	var names: Dictionary = {
		EconBuilding.BuildingType.BARRACKS: "Barracks",
		EconBuilding.BuildingType.FORTRESS: "Fortress",
		EconBuilding.BuildingType.WORKSHOP: "Workshop",
		EconBuilding.BuildingType.VILLAGE: "Farm",
		EconBuilding.BuildingType.SAWMILL: "森小屋",
		EconBuilding.BuildingType.MINE: "採掘場",
		EconBuilding.BuildingType.EQUIPMENT_SHOP: "Equip",
		EconBuilding.BuildingType.TRADE_POST: "Trade",
		EconBuilding.BuildingType.PLAZA: "Plaza",
		EconBuilding.BuildingType.HOUSE: "House",
		EconBuilding.BuildingType.EXCHANGE: "Exchange",
		EconBuilding.BuildingType.SMITHY: "Smithy",
		EconBuilding.BuildingType.WATCHTOWER: "Tower",
		EconBuilding.BuildingType.DINER: "Diner",
		EconBuilding.BuildingType.MILL: "Mill",
	}
	return str(names.get(building_type, "Building"))

class BuildQueueItem:
	extends PanelContainer

	var building: Dictionary = {}
	var queue_index := 0
	var building_name := ""
	var progress := 0.0
	var cost_g := 0
	var can_pay := true
	var stopped := false
	var is_selected := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.10, 0.075, 0.92)
		sb.border_color = Color(0.75, 0.65, 0.35, 1.0) if is_selected else Color(0.35, 0.29, 0.20, 0.95)
		sb.border_width_top = 2 if is_selected else 1
		sb.border_width_bottom = 2 if is_selected else 1
		sb.border_width_left = 2 if is_selected else 1
		sb.border_width_right = 2 if is_selected else 1
		sb.set_corner_radius_all(2)
		add_theme_stylebox_override("panel", sb)
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.add_theme_constant_override("separation", 1)
		add_child(box)
		var title := Label.new()
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.text = "%d  %s" % [queue_index, building_name]
		title.add_theme_font_size_override("font_size", 11)
		title.add_theme_color_override("font_color", Color(0.76, 0.70, 0.60))
		box.add_child(title)
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.custom_minimum_size = Vector2(0, 18)
		box.add_child(spacer)
		var bottom := Label.new()
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom.text = "X work" if stopped else "G:%d" % cost_g
		bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bottom.add_theme_font_size_override("font_size", 10)
		bottom.add_theme_color_override("font_color", Color(0.64, 0.18, 0.14) if (not can_pay or stopped) else Color(0.70, 0.58, 0.28))
		box.add_child(bottom)

	func _draw() -> void:
		var h := size.y * clampf(progress, 0.0, 1.0)
		if h <= 0.0:
			return
		var overlay_color := Color(0.55, 0.50, 0.43, 0.30) if stopped else Color(0.70, 0.58, 0.28, 0.40)
		draw_rect(Rect2(Vector2.ZERO + Vector2(0.0, size.y - h), Vector2(size.x, h)), overlay_color)
