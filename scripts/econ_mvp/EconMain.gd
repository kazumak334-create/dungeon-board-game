class_name EconMain
extends Node2D

var _grid: EconGrid
var _economy: EconEconomy
var _battle: EconBattle

var _ui_layer: CanvasLayer
var _resource_label: Label
var _log_label: Label
var _status_label: Label
var _mode_label: Label

var _log_lines: Array = []
const MAX_LOG_LINES := 10

enum PlaceMode { NONE, BARRACKS, FORTRESS, WORKSHOP, VILLAGE }
var _place_mode: PlaceMode = PlaceMode.NONE
var _is_running: bool = false
var _selected_unit: EconUnit = null
var _guard_select_mode: bool = false
var _order_panel: PanelContainer = null

func _ready() -> void:
	_setup_grid()
	_setup_economy()
	_setup_battle()
	_setup_initial_entities()
	_setup_ui()
	var vp := get_viewport().get_visible_rect().size
	var hex_w := EconGrid.HEX_SIZE * sqrt(3.0)
	var grid_w := hex_w * 6.0
	var grid_h := EconGrid.HEX_SIZE * 2.0 * 0.75 * float(EconGrid.ROWS - 1) + EconGrid.HEX_SIZE * 2.0
	_grid.origin = Vector2(
		220.0 + (vp.x - 220.0 - grid_w) * 0.5 + hex_w * 0.5,
		(vp.y - grid_h) * 0.5 + EconGrid.HEX_SIZE
	)
	_grid.queue_redraw()

func _setup_grid() -> void:
	_grid = EconGrid.new()
	add_child(_grid)

func _setup_economy() -> void:
	_economy = EconEconomy.new()
	_economy.harvester_starved.connect(_on_harvester_starved)
	add_child(_economy)

func _setup_battle() -> void:
	_battle = EconBattle.new()
	_battle.setup(_grid, _economy)
	_battle.log_message.connect(_add_log)
	_battle.battle_ended.connect(_on_battle_ended)
	add_child(_battle)

func _setup_initial_entities() -> void:
	var player_base := EconBuilding.new()
	player_base.setup(EconBuilding.BuildingType.BASE, Vector2i(2, 2), true)
	player_base.position = _grid.hex_to_pixel(2, 2)
	_battle.player_buildings.append(player_base)
	_grid.add_child(player_base)
	var enemy_base := EconBuilding.new()
	enemy_base.setup(EconBuilding.BuildingType.BASE, Vector2i(2, 8), false)
	enemy_base.position = _grid.hex_to_pixel(2, 8)
	_battle.enemy_buildings.append(enemy_base)
	_grid.add_child(enemy_base)
	for col in [0, 2, 4]:
		if _grid.is_valid_cell(col, 8):
			var enemy := EconUnit.create(EconUnit.UnitType.ATTACKER, EconUnit.Side.ENEMY, col, 8)
			enemy.position = _grid.hex_to_pixel(col, 8)
			_battle.enemy_units.append(enemy)
			_grid.add_child(enemy)
	_spawn_harvester_at(0, 0)

func _spawn_harvester_at(col: int, row: int) -> void:
	var h := EconHarvester.new()
	h.grid_pos = Vector2i(col, row)
	h.economy = _economy
	h.position = _grid.hex_to_pixel(col, row)
	h.harvested.connect(func(rtype): _economy.add_resource(rtype))
	h.harvester_index = _battle.player_harvesters.size()
	_battle.player_harvesters.append(h)
	_grid.add_child(h)

func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(5, 5)
	panel.custom_minimum_size = Vector2(210, 680)
	_ui_layer.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "=== Econ MVP ==="
	vbox.add_child(title)
	_resource_label = Label.new()
	_resource_label.text = "Wood:0 Stone:0 Sulfur:0 Wheat:10"
	_resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_resource_label)
	var alloc_title := Label.new()
	alloc_title.text = "-- Alloc % (sliders) --"
	vbox.add_child(alloc_title)
	var lbl_w := Label.new()
	lbl_w.text = "Wood:%d%%" % _economy.alloc_wood
	vbox.add_child(lbl_w)
	var slider_w := HSlider.new()
	slider_w.min_value = 0
	slider_w.max_value = 100
	slider_w.step = 5
	slider_w.value = _economy.alloc_wood
	vbox.add_child(slider_w)
	var lbl_st := Label.new()
	lbl_st.text = "Stone:%d%%" % _economy.alloc_stone
	vbox.add_child(lbl_st)
	var slider_st := HSlider.new()
	slider_st.min_value = 0
	slider_st.max_value = 100
	slider_st.step = 5
	slider_st.value = _economy.alloc_stone
	vbox.add_child(slider_st)
	var lbl_su := Label.new()
	lbl_su.text = "Sulfur:%d%%" % _economy.alloc_sulfur
	vbox.add_child(lbl_su)
	var slider_su := HSlider.new()
	slider_su.min_value = 0
	slider_su.max_value = 100
	slider_su.step = 5
	slider_su.value = _economy.alloc_sulfur
	vbox.add_child(slider_su)
	slider_w.value_changed.connect(func(v):
		_economy.alloc_wood = int(v)
		lbl_w.text = "Wood:%d%%" % int(v)
	)
	slider_st.value_changed.connect(func(v):
		_economy.alloc_stone = int(v)
		lbl_st.text = "Stone:%d%%" % int(v)
	)
	slider_su.value_changed.connect(func(v):
		_economy.alloc_sulfur = int(v)
		lbl_su.text = "Sulfur:%d%%" % int(v)
	)
	var prio_title := Label.new()
	prio_title.text = "-- Priority (1=first) --"
	vbox.add_child(prio_title)
	var prio_hbox := HBoxContainer.new()
	vbox.add_child(prio_hbox)
	var btn_pw := Button.new()
	btn_pw.text = "W:%d" % _economy.priority_wood
	var btn_pst := Button.new()
	btn_pst.text = "St:%d" % _economy.priority_stone
	var btn_psu := Button.new()
	btn_psu.text = "Su:%d" % _economy.priority_sulfur
	btn_pw.pressed.connect(func():
		_economy.priority_wood = (_economy.priority_wood % 3) + 1
		btn_pw.text = "W:%d" % _economy.priority_wood
	)
	btn_pst.pressed.connect(func():
		_economy.priority_stone = (_economy.priority_stone % 3) + 1
		btn_pst.text = "St:%d" % _economy.priority_stone
	)
	btn_psu.pressed.connect(func():
		_economy.priority_sulfur = (_economy.priority_sulfur % 3) + 1
		btn_psu.text = "Su:%d" % _economy.priority_sulfur
	)
	prio_hbox.add_child(btn_pw)
	prio_hbox.add_child(btn_pst)
	prio_hbox.add_child(btn_psu)
	var build_title := Label.new()
	build_title.text = "-- Build (click map row0-4) --"
	vbox.add_child(build_title)
	var build_names := ["Barracks(W8)", "Fortress(St6)", "Workshop(Su6)", "Village(W6)"]
	var build_modes := [PlaceMode.BARRACKS, PlaceMode.FORTRESS, PlaceMode.WORKSHOP, PlaceMode.VILLAGE]
	for i in range(build_names.size()):
		var btn := Button.new()
		btn.text = build_names[i]
		var captured_idx: int = i
		btn.pressed.connect(func():
			_place_mode = build_modes[captured_idx]
			_mode_label.text = "Mode: " + build_names[captured_idx]
		)
		vbox.add_child(btn)
	_mode_label = Label.new()
	_mode_label.text = "Mode: None"
	vbox.add_child(_mode_label)
	var btn_cancel := Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.pressed.connect(func():
		_place_mode = PlaceMode.NONE
		_mode_label.text = "Mode: None"
	)
	vbox.add_child(btn_cancel)
	var bulk_title := Label.new()
	bulk_title.text = "-- Bulk Order --"
	vbox.add_child(bulk_title)
	var btn_bulk_atk := Button.new()
	btn_bulk_atk.text = "All: Attack Units"
	btn_bulk_atk.pressed.connect(func():
		for u in _battle.player_units:
			u.order = EconUnit.OrderType.ATTACK_UNITS
			u.guard_target = null
	)
	vbox.add_child(btn_bulk_atk)
	var btn_bulk_harv := Button.new()
	btn_bulk_harv.text = "All: Target Harvesters"
	btn_bulk_harv.pressed.connect(func():
		for u in _battle.player_units:
			u.order = EconUnit.OrderType.ATTACK_HARVESTERS
			u.guard_target = null
	)
	vbox.add_child(btn_bulk_harv)
	var btn_start := Button.new()
	btn_start.text = "Start Battle"
	btn_start.pressed.connect(_on_start_pressed)
	vbox.add_child(btn_start)
	_status_label = Label.new()
	_status_label.text = "Setup phase"
	vbox.add_child(_status_label)
	var log_panel := PanelContainer.new()
	log_panel.position = Vector2(5, 690)
	log_panel.custom_minimum_size = Vector2(210, 150)
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(log_panel)
	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.add_child(_log_label)
	# 個別ユニット指示パネル（初期非表示）
	_order_panel = PanelContainer.new()
	_order_panel.custom_minimum_size = Vector2(160, 120)
	_order_panel.visible = false
	_ui_layer.add_child(_order_panel)
	var order_vbox := VBoxContainer.new()
	_order_panel.add_child(order_vbox)
	var lbl_order := Label.new()
	lbl_order.text = "Unit Order:"
	order_vbox.add_child(lbl_order)
	var btn_atk := Button.new()
	btn_atk.text = "Attack Units"
	btn_atk.pressed.connect(func():
		if _selected_unit and _selected_unit.is_alive:
			_selected_unit.order = EconUnit.OrderType.ATTACK_UNITS
			_selected_unit.guard_target = null
	)
	order_vbox.add_child(btn_atk)
	var btn_harv := Button.new()
	btn_harv.text = "Target Harvesters"
	btn_harv.pressed.connect(func():
		if _selected_unit and _selected_unit.is_alive:
			_selected_unit.order = EconUnit.OrderType.ATTACK_HARVESTERS
			_selected_unit.guard_target = null
	)
	order_vbox.add_child(btn_harv)
	var btn_guard := Button.new()
	btn_guard.text = "Guard..."
	btn_guard.pressed.connect(func():
		if _selected_unit and _selected_unit.is_alive:
			_guard_select_mode = true
			_add_log("Click a unit/building to guard")
	)
	order_vbox.add_child(btn_guard)
	var btn_cancel_order := Button.new()
	btn_cancel_order.text = "Deselect"
	btn_cancel_order.pressed.connect(func():
		_selected_unit = null
		_order_panel.visible = false
		_guard_select_mode = false
	)
	order_vbox.add_child(btn_cancel_order)

func _on_start_pressed() -> void:
	if _is_running:
		return
	_is_running = true
	_battle.start()
	_status_label.text = "Battle running..."

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local_pos: Vector2 = _grid.to_local(get_global_mouse_position())
	var cell := _pixel_to_hex(local_pos)
	# ガード対象選択モード
	if _guard_select_mode:
		if cell != Vector2i(-1, -1):
			# 味方ユニットをクリック
			for u in _battle.player_units:
				if u.is_alive and u.grid_pos == cell and u != _selected_unit:
					_selected_unit.order = EconUnit.OrderType.GUARD
					_selected_unit.guard_target = u
					_add_log("Guard: unit at (%d,%d)" % [cell.x, cell.y])
					_guard_select_mode = false
					return
			# 味方建物をクリック
			for b in _battle.player_buildings:
				if b.is_alive and b.grid_pos == cell:
					_selected_unit.order = EconUnit.OrderType.GUARD
					_selected_unit.guard_target = b
					_add_log("Guard: building at (%d,%d)" % [cell.x, cell.y])
					_guard_select_mode = false
					return
		_guard_select_mode = false
		return
	# 建設モード
	if _place_mode != PlaceMode.NONE:
		if cell == Vector2i(-1, -1):
			return
		if not _grid.is_valid_cell(cell.x, cell.y):
			return
		if cell.y > 4:
			_add_log("Player area: row0-4 only")
			return
		for h in _battle.player_harvesters:
			if h.grid_pos == cell:
				_add_log("Cell occupied by harvester")
				return
		for b in _battle.player_buildings:
			if b.grid_pos == cell:
				_add_log("Cell occupied by building")
				return
		_place_building(cell, _place_mode)
		_place_mode = PlaceMode.NONE
		_mode_label.text = "Mode: None"
		return
	# ユニット選択
	if cell == Vector2i(-1, -1):
		_selected_unit = null
		_order_panel.visible = false
		return
	for u in _battle.player_units:
		if u.is_alive and u.grid_pos == cell:
			_selected_unit = u
			_order_panel.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(80, 60)
			_order_panel.visible = true
			return
	# 何もない場所をクリック → 選択解除
	_selected_unit = null
	_order_panel.visible = false

func _place_building(cell: Vector2i, mode: PlaceMode) -> void:
	var btype_map: Dictionary = {
		PlaceMode.BARRACKS: EconBuilding.BuildingType.BARRACKS,
		PlaceMode.FORTRESS: EconBuilding.BuildingType.FORTRESS,
		PlaceMode.WORKSHOP: EconBuilding.BuildingType.WORKSHOP,
		PlaceMode.VILLAGE:  EconBuilding.BuildingType.VILLAGE,
	}
	var btype: int = int(btype_map[mode])
	var b := EconBuilding.new()
	b.setup(btype, cell, true)
	b.position = _grid.hex_to_pixel(cell.x, cell.y)
	b.unit_produced.connect(func(pos: Vector2i, utype: int):
		if utype == -1:
			_spawn_harvester_at(pos.x, pos.y)
		else:
			_battle.spawn_player_unit(pos.x, pos.y, utype)
	)
	_battle.player_buildings.append(b)
	_grid.add_child(b)
	_battle.add_building_to_queue(b)
	var names := ["Barracks", "Fortress", "Workshop", "Village"]
	_add_log("%s queued at (%d,%d)" % [names[btype], cell.x, cell.y])

func _on_harvester_starved() -> void:
	var alive := _battle.player_harvesters.filter(func(h): return h.is_alive)
	if alive.is_empty():
		return
	alive.shuffle()
	var victim: EconHarvester = alive[0]
	victim.is_alive = false
	victim.visible = false
	_add_log("Wheat shortage! Harvester lost")

func _on_battle_ended(player_won: bool) -> void:
	_status_label.text = "Victory!" if player_won else "Defeat..."
	_add_log("Victory!" if player_won else "Defeat!")

func _add_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	_log_label.text = "
".join(_log_lines)

func _pixel_to_hex(local_pos: Vector2) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_dist := 999.0
	for row in range(_grid.ROWS):
		for col in range(_grid.get_col_count(row)):
			var center := _grid.hex_to_pixel(col, row)
			var d := local_pos.distance_to(center)
			if d < best_dist and d < EconGrid.HEX_SIZE * 1.0:
				best_dist = d
				best_cell = Vector2i(col, row)
	return best_cell

func _process(delta: float) -> void:
	_battle.update(delta)
	_resource_label.text = _economy.get_display_text()
