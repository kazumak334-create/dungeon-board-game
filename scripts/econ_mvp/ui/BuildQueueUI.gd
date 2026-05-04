class_name BuildQueueUI
extends PanelContainer

signal instant_build_requested(building: EconBuilding)
signal cancel_requested(building: EconBuilding)
signal reorder_requested(building: EconBuilding, target_index: int)

const LABOR_COST_PER_UNIT := 5
const ITEM_HEIGHT := 56.0
const MAX_VISIBLE_ITEMS := 5

var battle: EconBattle = null
var economy: EconEconomy = null

var _list: VBoxContainer = null
var _empty_label: Label = null
var _drag_building: EconBuilding = null
var _drag_start_y: float = 0.0
var _dragging := false
var _items: Array = []

func setup(new_battle: EconBattle, new_economy: EconEconomy) -> void:
	battle = new_battle
	economy = new_economy
	position = Vector2(0.0, 100.0)
	custom_minimum_size = Vector2(140.0, 420.0)
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
	refresh()

func refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	_items.clear()
	var buildings := get_queue_buildings()
	visible = not buildings.is_empty()
	if _empty_label != null:
		_empty_label.visible = buildings.is_empty()
	for i in range(mini(MAX_VISIBLE_ITEMS, buildings.size())):
		var building: EconBuilding = buildings[i]
		var item := _create_item(building, i + 1)
		_list.add_child(item)
		_items.append(item)

func get_queue_buildings() -> Array:
	if battle == null:
		return []
	var buildings: Array = battle.player_buildings.filter(func(b):
		return b is EconBuilding and b.is_alive and not b.is_built
	)
	buildings.sort_custom(func(a: EconBuilding, b: EconBuilding) -> bool:
		return _get_order(a) < _get_order(b)
	)
	return buildings

func calc_instant_build_cost(building: EconBuilding) -> int:
	if building == null:
		return 0
	var required: float = float(EconBuilding.REQUIRED_CONSTRUCTION.get(int(building.building_type), 1.0))
	if required <= 0.0:
		return 0
	var remaining_labor: float = maxf(0.0, required - building.build_progress)
	if remaining_labor <= 0.0:
		return 0
	return int(ceil(remaining_labor * float(LABOR_COST_PER_UNIT)))

func _create_item(building: EconBuilding, index: int) -> Control:
	var item := BuildQueueItem.new()
	item.custom_minimum_size = Vector2(132.0, ITEM_HEIGHT)
	item.building = building
	item.queue_index = index
	item.building_name = _get_building_name(int(building.building_type))
	item.progress = building.get_build_progress_ratio()
	item.cost_g = calc_instant_build_cost(building)
	item.can_pay = economy != null and economy.currency >= item.cost_g
	item.stopped = not building._construction_ready
	item.gui_input.connect(func(event: InputEvent):
		_on_item_gui_input(event, building, index)
	)
	return item

func _on_item_gui_input(event: InputEvent, building: EconBuilding, index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_building = building
				_drag_start_y = get_global_mouse_position().y
				_dragging = false
			else:
				if _drag_building == building and _dragging:
					var target_index := clampi(int(floor((get_global_mouse_position().y - global_position.y - 20.0) / ITEM_HEIGHT)) + 1, 1, max(1, get_queue_buildings().size()))
					reorder_requested.emit(building, target_index)
				elif _drag_building == building:
					instant_build_requested.emit(building)
				_drag_building = null
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			cancel_requested.emit(building)
	elif event is InputEventMouseMotion and _drag_building == building:
		if absf(get_global_mouse_position().y - _drag_start_y) >= 10.0:
			_dragging = true

func _get_order(building: EconBuilding) -> int:
	if building.has_meta("construction_order"):
		return int(building.get_meta("construction_order"))
	return 0

func _get_building_name(building_type: int) -> String:
	var names: Dictionary = {
		EconBuilding.BuildingType.BARRACKS: "Barracks",
		EconBuilding.BuildingType.FORTRESS: "Fortress",
		EconBuilding.BuildingType.WORKSHOP: "Workshop",
		EconBuilding.BuildingType.VILLAGE: "Farm",
		EconBuilding.BuildingType.SAWMILL: "Sawmill",
		EconBuilding.BuildingType.MINE: "Quarry",
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

	var building: EconBuilding = null
	var queue_index := 0
	var building_name := ""
	var progress := 0.0
	var cost_g := 0
	var can_pay := true
	var stopped := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.10, 0.075, 0.92)
		sb.border_color = Color(0.35, 0.29, 0.20, 0.95)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		add_theme_stylebox_override("panel", sb)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.add_theme_constant_override("separation", 1)
		add_child(box)
		var title := Label.new()
		title.text = "%d  %s" % [queue_index, building_name]
		title.add_theme_font_size_override("font_size", 11)
		title.add_theme_color_override("font_color", Color(0.76, 0.70, 0.60))
		box.add_child(title)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 18)
		box.add_child(spacer)
		var bottom := Label.new()
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
