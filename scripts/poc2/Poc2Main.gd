class_name Poc2Main
extends Node2D

enum PlaceMode { NONE, HARVESTER, BARRACKS, FORTRESS }

var _grid: Poc2Grid
var _economy: Poc2Economy
var _battle: Poc2Battle

var _place_mode: PlaceMode = PlaceMode.NONE
var _resource_priority: int = 1  # 1=WOOD, 2=STONE, 3=WHEAT

var _harvesters: Array = []
var _buildings: Array = []

# UI要素
var _ui_layer: CanvasLayer
var _resource_label: Label
var _log_label: Label
var _status_label: Label
var _btn_harvester: Button
var _btn_barracks: Button
var _btn_fortress: Button
var _btn_start: Button
var _btn_prio_wood: Button
var _btn_prio_stone: Button
var _btn_prio_wheat: Button

var _is_battle_started: bool = false
var _log_lines: Array = []
const MAX_LOG_LINES := 8
const MAX_HARVESTERS := 3
const MAX_BARRACKS := 2
const MAX_FORTRESS := 1

func _ready() -> void:
	_setup_grid()
	_setup_economy()
	_setup_battle()
	_setup_ui()

func _setup_grid() -> void:
	_grid = Poc2Grid.new()
	_grid.origin = Vector2(60, 20)
	add_child(_grid)

func _setup_economy() -> void:
	_economy = Poc2Economy.new()
	_economy.harvester_starved.connect(_on_harvester_starved)
	add_child(_economy)

func _setup_battle() -> void:
	_battle = Poc2Battle.new()
	_battle.setup(_grid, _economy)
	_battle.log_message.connect(_add_log)
	_battle.battle_ended.connect(_on_battle_ended)
	add_child(_battle)

func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(180, 500)
	_ui_layer.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "PoC2 -- Economy Design"
	vbox.add_child(title)
	_resource_label = Label.new()
	_resource_label.text = "Wood:0 Stone:0 Wheat:10"
	_resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_resource_label)
	_btn_harvester = Button.new()
	_btn_harvester.text = "Harvester(0/%d)" % MAX_HARVESTERS
	_btn_harvester.pressed.connect(func(): _set_mode(PlaceMode.HARVESTER))
	vbox.add_child(_btn_harvester)
	_btn_barracks = Button.new()
	_btn_barracks.text = "Barracks(0/%d)" % MAX_BARRACKS
	_btn_barracks.pressed.connect(func(): _set_mode(PlaceMode.BARRACKS))
	vbox.add_child(_btn_barracks)
	_btn_fortress = Button.new()
	_btn_fortress.text = "Fortress(0/%d)" % MAX_FORTRESS
	_btn_fortress.pressed.connect(func(): _set_mode(PlaceMode.FORTRESS))
	vbox.add_child(_btn_fortress)
	var prio_label := Label.new()
	prio_label.text = "Priority resource:"
	vbox.add_child(prio_label)
	_btn_prio_wood = Button.new()
	_btn_prio_wood.text = "> Wood"
	_btn_prio_wood.pressed.connect(func(): _set_priority(1))
	vbox.add_child(_btn_prio_wood)
	_btn_prio_stone = Button.new()
	_btn_prio_stone.text = "  Stone"
	_btn_prio_stone.pressed.connect(func(): _set_priority(2))
	vbox.add_child(_btn_prio_stone)
	_btn_prio_wheat = Button.new()
	_btn_prio_wheat.text = "  Wheat"
	_btn_prio_wheat.pressed.connect(func(): _set_priority(3))
	vbox.add_child(_btn_prio_wheat)
	_btn_start = Button.new()
	_btn_start.text = "Battle Start"
	_btn_start.pressed.connect(_on_start_pressed)
	vbox.add_child(_btn_start)
	_status_label = Label.new()
	_status_label.text = "Design Phase"
	vbox.add_child(_status_label)
	var log_panel := PanelContainer.new()
	log_panel.position = Vector2(10, 520)
	log_panel.custom_minimum_size = Vector2(560, 120)
	_ui_layer.add_child(log_panel)
	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	log_panel.add_child(_log_label)

func _set_mode(mode: PlaceMode) -> void:
	if _is_battle_started:
		return
	_place_mode = mode

func _set_priority(p: int) -> void:
	_resource_priority = p
	_btn_prio_wood.text = ("> " if p == 1 else "  ") + "Wood"
	_btn_prio_stone.text = ("> " if p == 2 else "  ") + "Stone"
	_btn_prio_wheat.text = ("> " if p == 3 else "  ") + "Wheat"
	for h in _harvesters:
		h.target_resource_type = _resource_priority

func _on_start_pressed() -> void:
	if _is_battle_started:
		return
	if _harvesters.is_empty():
		_add_log("Place at least 1 harvester")
		return
	_is_battle_started = true
	_place_mode = PlaceMode.NONE
	_battle.harvesters = _harvesters
	_battle.buildings = _buildings
	_battle.start()
	_status_label.text = "Battle Phase"
	_btn_start.disabled = true

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _is_battle_started or _place_mode == PlaceMode.NONE:
		return
	var local_pos: Vector2 = _grid.to_local(get_global_mouse_position())
	var cell := _pixel_to_hex(local_pos)
	if cell == Vector2i(-1, -1):
		return
	if not _grid.is_valid_cell(cell.x, cell.y):
		return
	if cell.y > 2:
		_add_log("Place only in row0-2 (blue area)")
		return
	for h in _harvesters:
		if h.grid_pos == cell:
			_add_log("Cell already occupied")
			return
	for b in _buildings:
		if b.grid_pos == cell:
			_add_log("Cell already occupied")
			return
	match _place_mode:
		PlaceMode.HARVESTER:
			if _harvesters.size() >= MAX_HARVESTERS:
				_add_log("Harvester max %d" % MAX_HARVESTERS)
				return
			_place_harvester(cell)
		PlaceMode.BARRACKS:
			if _buildings.filter(func(b): return b.building_type == Poc2Building.BuildingType.BARRACKS).size() >= MAX_BARRACKS:
				_add_log("Barracks max %d" % MAX_BARRACKS)
				return
			_place_building(cell, Poc2Building.BuildingType.BARRACKS)
		PlaceMode.FORTRESS:
			if _buildings.filter(func(b): return b.building_type == Poc2Building.BuildingType.FORTRESS).size() >= MAX_FORTRESS:
				_add_log("Fortress max %d" % MAX_FORTRESS)
				return
			_place_building(cell, Poc2Building.BuildingType.FORTRESS)

func _place_harvester(cell: Vector2i) -> void:
	var h := Poc2Harvester.new()
	h.grid_pos = cell
	h.target_resource_type = _resource_priority
	h.position = _grid.hex_to_pixel(cell.x, cell.y)
	h.harvested.connect(func(rtype): _economy.add_resource(rtype))
	_harvesters.append(h)
	_grid.add_child(h)
	_btn_harvester.text = "Harvester(%d/%d)" % [_harvesters.size(), MAX_HARVESTERS]
	_add_log("Harvester placed at (%d,%d)" % [cell.x, cell.y])

func _place_building(cell: Vector2i, btype: Poc2Building.BuildingType) -> void:
	var b := Poc2Building.new()
	b.building_type = btype
	b.grid_pos = cell
	b.position = _grid.hex_to_pixel(cell.x, cell.y)
	b.unit_produced.connect(func(pos): _battle.spawn_player_unit(pos.x, pos.y))
	_buildings.append(b)
	_grid.add_child(b)
	var name_str := "Barracks" if btype == Poc2Building.BuildingType.BARRACKS else "Fortress"
	_add_log("%s placed at (%d,%d)" % [name_str, cell.x, cell.y])
	_update_building_buttons()

func _update_building_buttons() -> void:
	var barracks_count := _buildings.filter(func(b): return b.building_type == Poc2Building.BuildingType.BARRACKS).size()
	var fortress_count := _buildings.filter(func(b): return b.building_type == Poc2Building.BuildingType.FORTRESS).size()
	_btn_barracks.text = "Barracks(%d/%d)" % [barracks_count, MAX_BARRACKS]
	_btn_fortress.text = "Fortress(%d/%d)" % [fortress_count, MAX_FORTRESS]

func _on_harvester_starved() -> void:
	var alive := _harvesters.filter(func(h): return h.is_alive)
	if alive.is_empty():
		return
	alive.shuffle()
	var victim: Poc2Harvester = alive[0]
	victim.is_alive = false
	victim.visible = false
	_add_log("Wheat shortage! Harvester lost")

func _on_battle_ended(player_won: bool) -> void:
	if player_won:
		_status_label.text = "Victory!"
		_add_log("Victory! All waves cleared")
	else:
		_status_label.text = "Defeat..."
		_add_log("Defeat... defense line broken")

func _add_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	_log_label.text = chr(10).join(_log_lines)

func _pixel_to_hex(local_pos: Vector2) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_dist := 999.0
	for row in range(_grid.ROWS):
		for col in range(_grid.get_col_count(row)):
			var center := _grid.hex_to_pixel(col, row)
			var d := local_pos.distance_to(center)
			if d < best_dist and d < _grid.HEX_SIZE * 1.0:
				best_dist = d
				best_cell = Vector2i(col, row)
	return best_cell

func _process(delta: float) -> void:
	_battle.update(delta)
	if _is_battle_started:
		_resource_label.text = "Wood:%d Stone:%d Wheat:%d" % [_economy.wood, _economy.stone, _economy.wheat]
