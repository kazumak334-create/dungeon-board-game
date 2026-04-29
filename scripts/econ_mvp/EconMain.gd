class_name EconMain
extends Node2D

var _grid: EconGrid
var _economy: EconEconomy
var _battle: EconBattle
var _ai: EconAI

var _ui_layer: CanvasLayer
var _resource_label: Label
var _ai_resource_label: Label
var _wheat_eval_label: Label
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
	# origin を先に確定 → エンティティ配置はすべてこの後
	var vp := get_viewport().get_visible_rect().size
	var hex_w := EconGrid.HEX_SIZE * sqrt(3.0)
	var grid_w := hex_w * 13.0
	var grid_h := EconGrid.HEX_SIZE * 2.0 * 0.75 * float(EconGrid.ROWS - 1) + EconGrid.HEX_SIZE * 2.0
	_grid.origin = Vector2(
		220.0 + (vp.x - 220.0 - grid_w) * 0.5 + hex_w * 0.5,
		(vp.y - grid_h) * 0.5 + EconGrid.HEX_SIZE
	)
	_grid.queue_redraw()
	_setup_ai()
	_setup_initial_entities()
	_setup_ui(vp)

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

func _setup_ai() -> void:
	_ai = EconAI.new()
	_battle.ai = _ai
	add_child(_ai)
	_ai.setup(_grid, _battle)

func _setup_initial_entities() -> void:
	# 敵BASE（固定: row 11 中央）
	var enemy_base := EconBuilding.new()
	enemy_base.setup(EconBuilding.BuildingType.BASE, Vector2i(6, 11), false)
	enemy_base.position = _grid.hex_to_pixel(6, 11)
	enemy_base.unit_produced.connect(_ai.on_unit_produced)
	_battle.enemy_buildings.append(enemy_base)
	_grid.add_child(enemy_base)
	# 敵初期ハーベスター × 2
	for ei in range(2):
		var eh := EconHarvester.new()
		var epos: Vector2i = [Vector2i(4, 10), Vector2i(6, 10)][ei]
		eh.grid_pos = epos
		eh.economy = _ai.economy
		eh.position = _grid.hex_to_pixel(epos.x, epos.y)
		eh.harvested.connect(func(rtype): _ai.economy.add_resource(rtype))
		eh.harvester_index = ei
		_battle.enemy_harvesters.append(eh)
		_grid.add_child(eh)
	# プレイヤーBASE（row 0 中央）自動配置
	var player_base := EconBuilding.new()
	player_base.setup(EconBuilding.BuildingType.BASE, Vector2i(6, 0), true)
	player_base.position = _grid.hex_to_pixel(6, 0)
	player_base.unit_produced.connect(func(pos: Vector2i, utype: int):
		if utype == -1:
			_spawn_harvester_at(pos.x, pos.y)
	)
	_battle.player_buildings.append(player_base)
	_grid.add_child(player_base)
	_spawn_harvester_at(6, 0)
	_spawn_harvester_at(6, 0)

func _spawn_harvester_at(col: int, row: int) -> void:
	var h := EconHarvester.new()
	h.grid_pos = Vector2i(col, row)
	h.economy = _economy
	h.position = _grid.hex_to_pixel(col, row)
	h.harvested.connect(func(rtype): _economy.add_resource(rtype))
	h.harvester_index = _battle.player_harvesters.size()
	_battle.player_harvesters.append(h)
	_grid.add_child(h)

func _setup_ui(vp: Vector2) -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(5, 5)
	panel.custom_minimum_size = Vector2(215, vp.y - 10)
	_ui_layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(200, 0)
	scroll.add_child(vbox)
	var title := Label.new()
	title.text = "=== Econ MVP ==="
	vbox.add_child(title)
	_resource_label = Label.new()
	_resource_label.text = "Wood:0 Stone:0 Sulfur:0 Wheat:10"
	_resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_resource_label)
	_wheat_eval_label = Label.new()
	_wheat_eval_label.text = "農村: --"
	_wheat_eval_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_wheat_eval_label)
	var ai_sep := HSeparator.new()
	ai_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(ai_sep)
	var ai_label_title := Label.new()
	ai_label_title.text = "-- Enemy AI --"
	vbox.add_child(ai_label_title)
	_ai_resource_label = Label.new()
	_ai_resource_label.text = "W:0 St:0 Su:0 Wh:0"
	_ai_resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_ai_resource_label)
	var alloc_title := Label.new()
	alloc_title.text = "-- Alloc (drag handles) --"
	vbox.add_child(alloc_title)
	# 線分配分バー（LineSegmentAllocBar）
	var alloc_bar := _create_alloc_bar()
	vbox.add_child(alloc_bar)
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
	var btn_pwh := Button.new()
	btn_pwh.text = "Wh:%d" % _economy.priority_wheat
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
	btn_pwh.pressed.connect(func():
		_economy.priority_wheat = (_economy.priority_wheat % 3) + 1
		btn_pwh.text = "Wh:%d" % _economy.priority_wheat
	)
	prio_hbox.add_child(btn_pw)
	prio_hbox.add_child(btn_pst)
	prio_hbox.add_child(btn_psu)
	prio_hbox.add_child(btn_pwh)
	var build_title := Label.new()
	build_title.text = "-- Build (click map row 0-2) --"
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
	var terrain_sep := HSeparator.new()
	terrain_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(terrain_sep)
	var terrain_title := Label.new()
	terrain_title.text = "-- Terrain --"
	vbox.add_child(terrain_title)
	# Mountain ratio
	var m_hbox := HBoxContainer.new()
	vbox.add_child(m_hbox)
	var m_label := Label.new()
	m_label.text = "Mountain:"
	m_hbox.add_child(m_label)
	var m_slider := HSlider.new()
	m_slider.min_value = 0
	m_slider.max_value = 80
	m_slider.value = 35
	m_slider.custom_minimum_size = Vector2(100, 20)
	m_hbox.add_child(m_slider)
	var m_val_label := Label.new()
	m_val_label.text = "35%"
	m_hbox.add_child(m_val_label)
	# Desert ratio
	var d_hbox := HBoxContainer.new()
	vbox.add_child(d_hbox)
	var d_label := Label.new()
	d_label.text = "Desert:"
	d_hbox.add_child(d_label)
	var d_slider := HSlider.new()
	d_slider.min_value = 0
	d_slider.max_value = 80
	d_slider.value = 25
	d_slider.custom_minimum_size = Vector2(100, 20)
	d_hbox.add_child(d_slider)
	var d_val_label := Label.new()
	d_val_label.text = "25%"
	d_hbox.add_child(d_val_label)
	# Plain display
	var p_label := Label.new()
	p_label.text = "Plain: 40%"
	vbox.add_child(p_label)
	# Slider callbacks
	m_slider.value_changed.connect(func(v: float):
		m_val_label.text = "%d%%" % int(v)
		# desert をクランプ
		if int(v) + int(d_slider.value) > 100:
			d_slider.value = 100 - int(v)
		p_label.text = "Plain: %d%%" % (100 - int(m_slider.value) - int(d_slider.value))
	)
	d_slider.value_changed.connect(func(v: float):
		d_val_label.text = "%d%%" % int(v)
		if int(m_slider.value) + int(v) > 100:
			m_slider.value = 100 - int(v)
		p_label.text = "Plain: %d%%" % (100 - int(m_slider.value) - int(d_slider.value))
	)
	# 再生成ボタン
	var btn_regen := Button.new()
	btn_regen.text = "マップ再生成"
	btn_regen.pressed.connect(func():
		_grid.generate_terrain(int(m_slider.value), int(d_slider.value))
	)
	vbox.add_child(btn_regen)
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)
	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_log_label)
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
		_deselect_unit()
	)
	order_vbox.add_child(btn_cancel_order)

func _create_alloc_bar() -> Control:
	# 線分配分バー：幅200px、ハンドル3つで4セクション（WOOD/STONE/SULFUR/WHEAT）
	var bar_container := VBoxContainer.new()
	bar_container.custom_minimum_size = Vector2(200, 0)
	# --- プリセットボタン行 ---
	var preset_hbox := HBoxContainer.new()
	bar_container.add_child(preset_hbox)
	var preset_data := [
		["初心者", 30, 20, 10, 40],
		["突特化", 55, 15, 20, 10],
		["守特化", 20, 50, 10, 20],
		["崩特化", 25, 10, 55, 10],
	]
	# --- 線分バー本体 ---
	var bar_inner := Control.new()
	bar_inner.custom_minimum_size = Vector2(200, 60)
	bar_inner.mouse_filter = Control.MOUSE_FILTER_STOP
	bar_container.add_child(bar_inner)
	const BAR_W := 196.0
	const BAR_H := 18.0
	const BAR_Y := 10.0
	const HANDLE_R := 7.0
	# セクション色
	var seg_colors := [
		Color(0.2, 0.6, 0.1),   # WOOD
		Color(0.5, 0.5, 0.5),   # STONE
		Color(0.8, 0.7, 0.1),   # SULFUR
		Color(0.9, 0.9, 0.3),   # WHEAT
	]
	var seg_names := ["W", "St", "Su", "Wh"]
	# 初期alloc値からハンドル位置（0.0〜1.0）を計算
	var total_alloc: float = float(_economy.alloc_wood + _economy.alloc_stone + _economy.alloc_sulfur + _economy.alloc_wheat)
	if total_alloc <= 0.0:
		total_alloc = 100.0
	var handles: Array = []  # 0.0〜1.0 の境界位置
	handles.append(float(_economy.alloc_wood) / total_alloc)
	handles.append(handles[0] + float(_economy.alloc_stone) / total_alloc)
	handles.append(handles[1] + float(_economy.alloc_sulfur) / total_alloc)
	var drag_idx: int = -1
	var bar_draw := Control.new()
	bar_draw.custom_minimum_size = Vector2(200, 60)
	bar_draw.mouse_filter = Control.MOUSE_FILTER_STOP
	bar_inner.add_child(bar_draw)
	var ratio_label := Label.new()
	ratio_label.position = Vector2(0, 35)
	ratio_label.custom_minimum_size = Vector2(200, 20)
	ratio_label.add_theme_font_size_override("font_size", 10)
	bar_inner.add_child(ratio_label)
	# alloc更新関数
	var update_economy := func():
		var segs: Array = [handles[0], handles[1] - handles[0], handles[2] - handles[1], 1.0 - handles[2]]
		const TOTAL := 100
		_economy.alloc_wood   = int(segs[0] * TOTAL + 0.5)
		_economy.alloc_stone  = int(segs[1] * TOTAL + 0.5)
		_economy.alloc_sulfur = int(segs[2] * TOTAL + 0.5)
		_economy.alloc_wheat  = int(segs[3] * TOTAL + 0.5)
		ratio_label.text = "W:%d St:%d Su:%d Wh:%d" % [
			_economy.alloc_wood, _economy.alloc_stone, _economy.alloc_sulfur, _economy.alloc_wheat
		]
		bar_draw.queue_redraw()
	update_economy.call()
	# プリセットボタンのコールバック登録（update_economy参照のためここで接続）
	for pd in preset_data:
		var btn := Button.new()
		btn.text = pd[0]
		btn.add_theme_font_size_override("font_size", 9)
		var w: int = pd[1]; var st: int = pd[2]; var su: int = pd[3]; var wh: int = pd[4]
		btn.pressed.connect(func():
			_economy.alloc_wood   = w
			_economy.alloc_stone  = st
			_economy.alloc_sulfur = su
			_economy.alloc_wheat  = wh
			var t: float = float(w + st + su + wh)
			handles[0] = float(w) / t
			handles[1] = float(w + st) / t
			handles[2] = float(w + st + su) / t
			update_economy.call()
		)
		preset_hbox.add_child(btn)
	# 描画
	bar_draw.draw.connect(func():
		var segs: Array = [handles[0], handles[1] - handles[0], handles[2] - handles[1], 1.0 - handles[2]]
		var x := 0.0
		for si in range(4):
			var sw: float = segs[si] * BAR_W
			bar_draw.draw_rect(Rect2(x, BAR_Y, sw, BAR_H), seg_colors[si])
			if sw > 14.0:
				bar_draw.draw_string(
					ThemeDB.fallback_font,
					Vector2(x + sw * 0.5 - 6.0, BAR_Y + 13.0),
					seg_names[si], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE
				)
			x += sw
		bar_draw.draw_rect(Rect2(0.0, BAR_Y, BAR_W, BAR_H), Color.WHITE, false, 1.0)
		for hi in range(3):
			var hx: float = handles[hi] * BAR_W
			bar_draw.draw_circle(Vector2(hx, BAR_Y + BAR_H * 0.5), HANDLE_R,
				Color.WHITE if drag_idx != hi else Color.YELLOW)
	)
	# マウス入力
	bar_draw.gui_input.connect(func(ev):
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					var mx: float = ev.position.x
					for hi in range(3):
						if abs(mx - handles[hi] * BAR_W) <= HANDLE_R + 4.0:
							drag_idx = hi
							break
				else:
					drag_idx = -1
		elif ev is InputEventMouseMotion and drag_idx >= 0:
			var mx: float = clampf(ev.position.x / BAR_W, 0.0, 1.0)
			# 境界点の順序を守る（最小間隔: 0.02）
			const MIN_SEG := 0.02
			if drag_idx == 0:
				handles[0] = clampf(mx, MIN_SEG, handles[1] - MIN_SEG)
			elif drag_idx == 1:
				handles[1] = clampf(mx, handles[0] + MIN_SEG, handles[2] - MIN_SEG)
			else:
				handles[2] = clampf(mx, handles[1] + MIN_SEG, 1.0 - MIN_SEG)
			update_economy.call()
	)
	return bar_container

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
		if cell.y > 2:   # 旧: cell.y > 4
			_add_log("Player area: row 0-2 only")
			return
		# 山岳セルへの建設を禁止
		if _grid.is_mountain(cell):
			_add_log("Cannot build on mountain")
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
		_deselect_unit()
		return
	for u in _battle.player_units:
		if u.is_alive and u.grid_pos == cell:
			_deselect_unit()
			_selected_unit = u
			u.is_selected = true
			u.queue_redraw()
			_order_panel.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(80, 60)
			_order_panel.visible = true
			return
	# 何もない場所をクリック → 選択解除
	_deselect_unit()

func _deselect_unit() -> void:
	if _selected_unit != null:
		_selected_unit.is_selected = false
		_selected_unit.queue_redraw()
		_selected_unit = null
	_order_panel.visible = false
	_guard_select_mode = false

func _place_building(cell: Vector2i, mode: PlaceMode) -> void:
	var btype_map: Dictionary = {
		PlaceMode.BARRACKS: EconBuilding.BuildingType.BARRACKS,
		PlaceMode.FORTRESS: EconBuilding.BuildingType.FORTRESS,
		PlaceMode.WORKSHOP: EconBuilding.BuildingType.WORKSHOP,
		PlaceMode.VILLAGE:  EconBuilding.BuildingType.VILLAGE,
	}
	var btype: int = int(btype_map[mode])
	# #3: Village数が生産棟の上限（兵舎/要塞/工房のみ）
	if btype in [0, 1, 2]:  # BARRACKS / FORTRESS / WORKSHOP
		var village_count: int = 0
		var production_count: int = 0
		for b in _battle.player_buildings:
			if not b.is_alive:
				continue
			if b.building_type == EconBuilding.BuildingType.VILLAGE:
				village_count += 1
			elif b.building_type != EconBuilding.BuildingType.BASE:
				production_count += 1
		var max_prod: int = village_count * 2 + 1
		if production_count >= max_prod:
			_add_log("Village not enough! (%d/%d)" % [production_count, max_prod])
			_place_mode = PlaceMode.NONE
			_mode_label.text = "Mode: None"
			return
	# VILLAGE 建設前：隣接小麦チェック
	if btype == EconBuilding.BuildingType.VILLAGE:
		var neighbors = _grid.get_neighbors(cell.x, cell.y)
		var has_wheat := false
		for nb in neighbors:
			if _grid.get_resource_type(nb) == EconGrid.ResourceType.WHEAT:
				has_wheat = true
				break
		if not has_wheat:
			_status_label.text = "農村は小麦マスに隣接して建設してください"
			return
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

func _on_harvester_starved(kill_count: int) -> void:
	var alive_u := _battle.player_units.filter(func(u): return u.is_alive)
	if alive_u.is_empty():
		return
	alive_u.shuffle()
	var killed: int = 0
	for i in range(mini(kill_count, alive_u.size())):
		alive_u[i].is_alive = false
		alive_u[i].visible = false
		killed += 1
	_add_log("Wheat shortage! %d unit(s) lost" % killed)

func _on_battle_ended(player_won: bool) -> void:
	_status_label.text = "Victory!" if player_won else "Defeat..."
	_add_log("Victory!" if player_won else "Defeat!")
	var btn_restart := Button.new()
	btn_restart.text = "Restart"
	btn_restart.custom_minimum_size = Vector2(120, 40)
	btn_restart.pressed.connect(func(): get_tree().reload_current_scene())
	_ui_layer.add_child(btn_restart)
	var vp := get_viewport().get_visible_rect().size
	btn_restart.position = Vector2(vp.x * 0.5 - 60.0, vp.y * 0.5 - 20.0)

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

func _get_wheat_eval() -> Dictionary:
	var village_count: int = 0
	for b in _battle.player_buildings:
		if b.is_alive and b.is_built and b.building_type == EconBuilding.BuildingType.VILLAGE:
			village_count += 1
	# #7: 戦闘ユニットのみカウント（ハーベスター除外）
	var unit_count: int = _battle.player_units.filter(func(u): return u.is_alive).size()
	var income: float = village_count * 0.4
	var cost: float = unit_count * 0.1
	var net: float = income - cost
	var rating: String
	var color: Color
	if net >= 0.2:
		rating = "✓ 余裕"
		color = Color.LIME_GREEN
	elif net >= 0.0:
		rating = "△ 適正"
		color = Color.YELLOW
	else:
		rating = "⚠ 不足"
		color = Color(1.0, 0.35, 0.35)
	var text: String = "農村: %s  %+.1f/s\n(村%d, 兵%d)" % [rating, net, village_count, unit_count]
	return {"text": text, "color": color}

func _process(delta: float) -> void:
	_battle.update(delta)
	_resource_label.text = _economy.get_display_text()
	if _ai != null and _ai.economy != null:
		var eco := _ai.economy
		_ai_resource_label.text = "W:%d St:%d Su:%d Wh:%d" % [eco.wood, eco.stone, eco.sulfur, eco.wheat]
	var eval: Dictionary = _get_wheat_eval()
	_wheat_eval_label.text = eval["text"]
	_wheat_eval_label.add_theme_color_override("font_color", eval["color"])
