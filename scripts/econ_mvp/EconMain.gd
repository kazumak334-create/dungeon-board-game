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
var _target_priority: int = 0  # 0=標準, 1=前線制圧, 2=経済破壊

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
	_setup_ui(vp)
	_setup_ai()
	_setup_initial_entities()

func _setup_grid() -> void:
	_grid = EconGrid.new()
	add_child(_grid)

func _setup_economy() -> void:
	_economy = EconEconomy.new()

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
	_battle.register_enemy_building(enemy_base)
	# 敵初期ハーベスター × 2
	for ei in range(2):
		var epos: Vector2i = [Vector2i(4, 10), Vector2i(6, 10)][ei]
		_battle.spawn_enemy_harvester(epos, _ai.economy)
	# AI側の初期農村を自動配置
	_place_initial_village(false)
	# プレイヤーBASE（row 0 中央）自動配置
	var player_base := EconBuilding.new()
	player_base.setup(EconBuilding.BuildingType.BASE, Vector2i(6, 0), true)
	player_base.position = _grid.hex_to_pixel(6, 0)
	player_base.unit_produced.connect(func(pos: Vector2i, utype: int):
		if utype == -2:
			_battle.spawn_player_builder(pos)
	)
	_battle.register_player_building(player_base)
	# 初期農村を小麦隣接タイルに自動配置（is_built=true）
	_place_initial_village(true)
	# プレイヤー初期ハーベスター × 2
	for pi in range(2):
		var ppos: Vector2i = [Vector2i(5, 0), Vector2i(7, 0)][pi]
		_battle.spawn_player_harvester(ppos, _economy)

func _place_initial_village(is_player: bool) -> void:
	# 小麦に隣接するタイルに農村を1棟自動配置（is_built=true）
	var zone_rows: Array = range(0, 3) if is_player else range(9, 12)
	for row in zone_rows:
		for col in range(_grid.get_col_count(row)):
			var cell := Vector2i(col, row)
			# 資源タイルや山岳は除外
			if _grid.get_resource_type(cell) != EconGrid.ResourceType.NONE:
				continue
			if _grid.is_mountain(cell):
				continue
			# 既存建物と重複しない
			var occupied := false
			var check_buildings: Array = _battle.player_buildings if is_player else _battle.enemy_buildings
			for b in check_buildings:
				if b.grid_pos == cell:
					occupied = true
					break
			if occupied:
				continue
			# 小麦隣接チェック
			var has_wheat := false
			for nb in _grid.get_neighbors(col, row):
				if _grid.get_resource_type(nb) == EconGrid.ResourceType.WHEAT:
					has_wheat = true
					break
			if not has_wheat:
				continue
			# 配置
			var village := EconBuilding.new()
			village.setup(EconBuilding.BuildingType.VILLAGE, cell, is_player)
			village.position = _grid.hex_to_pixel(cell.x, cell.y)
			village.is_built = true
			if is_player:
				village.unit_produced.connect(func(pos: Vector2i, utype: int):
					if utype == -1:
						_spawn_harvester_at(pos.x, pos.y)
				)
				_battle.register_player_building(village)
			else:
				village.unit_produced.connect(_ai.on_unit_produced)
				_battle.register_enemy_building(village)
			_add_log("Initial Village at (%d,%d)" % [cell.x, cell.y])
			return

func _spawn_harvester_at(col: int, row: int) -> void:
	_battle.spawn_player_harvester(Vector2i(col, row), _economy)

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
	var harvester_sep := HSeparator.new()
	harvester_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(harvester_sep)
	var harvester_alloc := _create_harvester_alloc_ui()
	vbox.add_child(harvester_alloc)
	# 建設方針切り替えボタン
	var builder_sep := HSeparator.new()
	builder_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(builder_sep)
	var builder_title := Label.new()
	builder_title.text = "-- Builder Mode --"
	vbox.add_child(builder_title)
	var builder_mode_label := Label.new()
	builder_mode_label.text = "Mode: Focus"
	vbox.add_child(builder_mode_label)
	var btn_focus := Button.new()
	btn_focus.text = "Focus (all->1 building)"
	btn_focus.pressed.connect(func():
		_battle.player_focus_mode = true
		builder_mode_label.text = "Mode: Focus"
	)
	vbox.add_child(btn_focus)
	var btn_parallel := Button.new()
	btn_parallel.text = "Parallel (split builds)"
	btn_parallel.pressed.connect(func():
		_battle.player_focus_mode = false
		builder_mode_label.text = "Mode: Parallel"
	)
	vbox.add_child(btn_parallel)
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
	var tp_sep := HSeparator.new()
	tp_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tp_sep)
	var tp_title := Label.new()
	tp_title.text = "-- Target Priority --"
	vbox.add_child(tp_title)
	var tp_label := Label.new()
	tp_label.text = "現在: 標準"
	vbox.add_child(tp_label)
	var btn_tp0 := Button.new()
	btn_tp0.text = "標準 (BASE>建物>兵>非戦)"
	btn_tp0.pressed.connect(func():
		_target_priority = 0
		tp_label.text = "現在: 標準"
		for u in _battle.player_units:
			u.target_priority = 0
	)
	vbox.add_child(btn_tp0)
	var btn_tp1 := Button.new()
	btn_tp1.text = "前線制圧 (兵>建物>BASE>非戦)"
	btn_tp1.pressed.connect(func():
		_target_priority = 1
		tp_label.text = "現在: 前線制圧"
		for u in _battle.player_units:
			u.target_priority = 1
	)
	vbox.add_child(btn_tp1)
	var btn_tp2 := Button.new()
	btn_tp2.text = "経済破壊 (建物>BASE>兵>非戦)"
	btn_tp2.pressed.connect(func():
		_target_priority = 2
		tp_label.text = "現在: 経済破壊"
		for u in _battle.player_units:
			u.target_priority = 2
	)
	vbox.add_child(btn_tp2)
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

func _create_harvester_alloc_ui() -> Control:
	# ハーベスター割り当てUI: 棒グラフ + [-][+]ボタンで直接人数指定
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(200, 0)
	var title := Label.new()
	title.text = "-- Harvesters --"
	container.add_child(title)
	# 各資源の行データ
	var resource_types := [
		EconGrid.ResourceType.WOOD,
		EconGrid.ResourceType.STONE,
		EconGrid.ResourceType.SULFUR,
		EconGrid.ResourceType.WHEAT,
	]
	var resource_names := ["Wood  ", "Stone ", "Sulfur", "Wheat "]
	var resource_colors := [
		Color(0.2, 0.6, 0.1),   # WOOD
		Color(0.5, 0.5, 0.5),   # STONE
		Color(0.8, 0.7, 0.1),   # SULFUR
		Color(0.9, 0.9, 0.3),   # WHEAT
	]
	const BAR_MAX_W := 100.0
	const BAR_H := 14.0
	var total_label := Label.new()
	var row_bars: Array = []  # 棒グラフControl refs
	var count_labels: Array = []  # 人数ラベル refs
	# 合計表示更新関数
	var _update_total := func():
		var total: int = 0
		for rtype in resource_types:
			total += _economy.target_count.get(rtype, 0)
		var harvester_count: int = _battle.player_harvesters.size()
		total_label.text = "計: %d / %d" % [total, harvester_count]
	# 全行の棒グラフを再描画する関数
	var _redraw_bars := func():
		var harvester_count: int = max(1, _battle.player_harvesters.size())
		for i in range(resource_types.size()):
			var rtype: int = resource_types[i]
			var cnt: int = _economy.target_count.get(rtype, 0)
			count_labels[i].text = str(cnt)
			row_bars[i].queue_redraw()
	# 各資源の行を生成
	for i in range(resource_types.size()):
		var rtype: int = resource_types[i]
		var hbox := HBoxContainer.new()
		container.add_child(hbox)
		var name_lbl := Label.new()
		name_lbl.text = resource_names[i]
		name_lbl.custom_minimum_size = Vector2(40, 0)
		name_lbl.add_theme_font_size_override("font_size", 10)
		hbox.add_child(name_lbl)
		# 棒グラフ
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(BAR_MAX_W, BAR_H + 2)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var captured_rtype: int = rtype
		var captured_color: Color = resource_colors[i]
		bar.draw.connect(func():
			var harvester_count: int = max(1, _battle.player_harvesters.size())
			var cnt: int = _economy.target_count.get(captured_rtype, 0)
			var fill_w: float = BAR_MAX_W * float(cnt) / float(harvester_count)
			# 空バー背景
			bar.draw_rect(Rect2(0, 1, BAR_MAX_W, BAR_H), Color(0.2, 0.2, 0.2))
			# 塗り
			if fill_w > 0:
				bar.draw_rect(Rect2(0, 1, fill_w, BAR_H), captured_color)
			# 枠
			bar.draw_rect(Rect2(0, 1, BAR_MAX_W, BAR_H), Color.WHITE, false, 1.0)
		)
		row_bars.append(bar)
		hbox.add_child(bar)
		# 人数ラベル
		var cnt_lbl := Label.new()
		cnt_lbl.text = str(_economy.target_count.get(rtype, 0))
		cnt_lbl.custom_minimum_size = Vector2(16, 0)
		cnt_lbl.add_theme_font_size_override("font_size", 10)
		count_labels.append(cnt_lbl)
		hbox.add_child(cnt_lbl)
		# [-]ボタン
		var btn_minus := Button.new()
		btn_minus.text = "-"
		btn_minus.custom_minimum_size = Vector2(20, 0)
		var captured_i: int = i
		btn_minus.pressed.connect(func():
			var cur: int = _economy.target_count.get(resource_types[captured_i], 0)
			# 合計が1以上になるよう制限
			var total_all: int = 0
			for rt in resource_types:
				total_all += _economy.target_count.get(rt, 0)
			if cur > 0 and total_all > 1:
				_economy.target_count[resource_types[captured_i]] = cur - 1
			_update_total.call()
			_redraw_bars.call()
		)
		hbox.add_child(btn_minus)
		# [+]ボタン
		var btn_plus := Button.new()
		btn_plus.text = "+"
		btn_plus.custom_minimum_size = Vector2(20, 0)
		btn_plus.pressed.connect(func():
			var cur: int = _economy.target_count.get(resource_types[captured_i], 0)
			var harvester_count: int = max(1, _battle.player_harvesters.size())
			# 合計がharvester_countを超えないよう制限
			var total_all: int = 0
			for rt in resource_types:
				total_all += _economy.target_count.get(rt, 0)
			if total_all < harvester_count:
				_economy.target_count[resource_types[captured_i]] = cur + 1
			_update_total.call()
			_redraw_bars.call()
		)
		hbox.add_child(btn_plus)
	container.add_child(total_label)
	_update_total.call()
	return container

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
	# 自建物のいずれかから半径3hex以内チェック
	var in_range := false
	for pb in _battle.player_buildings:
		if pb.is_alive and _grid.hex_distance(cell, pb.grid_pos) <= 3:
			in_range = true
			break
	if not in_range:
		_add_log("自建物から半径3hex以内にのみ建設できます")
		_place_mode = PlaceMode.NONE
		_mode_label.text = "Mode: None"
		return
	# VILLAGEのみ小麦タイル隣接チェック（仕様3：戦闘建物の資源隣接制限削除）
	if btype == int(EconBuilding.BuildingType.VILLAGE):
		var has_wheat := false
		for nb in _grid.get_neighbors(cell.x, cell.y):
			if _grid.get_resource_type(nb) == EconGrid.ResourceType.WHEAT:
				has_wheat = true
				break
		if not has_wheat:
			_add_log("農村は小麦タイルに隣接して建設してください")
			_place_mode = PlaceMode.NONE
			_mode_label.text = "Mode: None"
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
	_battle.register_player_building(b)
	var names := ["Barracks", "Fortress", "Workshop", "Village"]
	_add_log("%s placed at (%d,%d)" % [names[btype], cell.x, cell.y])


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
	_update_build_highlight()

func _update_build_highlight() -> void:
	_grid.highlight_cells.clear()
	_grid.fill_cells.clear()
	# 資源タイル強調（建設モード時のみ）
	var resource_highlight_map: Dictionary = {
		PlaceMode.BARRACKS: EconGrid.ResourceType.WOOD,
		PlaceMode.FORTRESS: EconGrid.ResourceType.STONE,
		PlaceMode.WORKSHOP: EconGrid.ResourceType.SULFUR,
		PlaceMode.VILLAGE:  EconGrid.ResourceType.WHEAT,
	}
	_grid.resource_highlight_type = resource_highlight_map.get(_place_mode, EconGrid.ResourceType.NONE)
	# 占有セルを収集（建設モード時のfill_cells除外に使用）
	var occupied: Dictionary = {}
	if _place_mode != PlaceMode.NONE:
		for h in _battle.player_harvesters:
			if h.is_alive:
				occupied[h.grid_pos] = true
		for b in _battle.player_buildings:
			if b.is_alive:
				occupied[b.grid_pos] = true
	# highlight_cells: 建設済みplayer_buildingsから半径3の和集合（row制限なし）
	for pb in _battle.player_buildings:
		if not pb.is_alive:
			continue
		if not pb.is_built:
			continue
		for row in range(EconGrid.ROWS):
			for col in range(_grid.get_col_count(row)):
				var cell := Vector2i(col, row)
				if _grid.is_mountain(cell):
					continue
				if _grid.hex_distance(cell, pb.grid_pos) <= 3:
					_grid.highlight_cells[cell] = true
	# enemy_territory_cells: 建設済みenemy_buildingsから半径3の和集合（row制限なし）
	_grid.enemy_territory_cells.clear()
	for eb in _battle.enemy_buildings:
		if not eb.is_alive:
			continue
		if not eb.is_built:
			continue
		for row in range(EconGrid.ROWS):
			for col in range(_grid.get_col_count(row)):
				var cell := Vector2i(col, row)
				if _grid.is_mountain(cell):
					continue
				if _grid.hex_distance(cell, eb.grid_pos) <= 3:
					_grid.enemy_territory_cells[cell] = true
	# fill_cells（建設モード時のみ塗りつぶし）: row 0-2フィルタ維持
	if _place_mode != PlaceMode.NONE:
		for row in range(0, 3):
			for col in range(_grid.get_col_count(row)):
				var cell := Vector2i(col, row)
				if _grid.is_mountain(cell):
					continue
				if occupied.has(cell):
					continue
				var in_range := false
				for pb in _battle.player_buildings:
					if pb.is_alive and _grid.hex_distance(cell, pb.grid_pos) <= 3:
						in_range = true
						break
				if not in_range:
					continue
				if _place_mode == PlaceMode.VILLAGE:
					var has_wheat := false
					for nb in _grid.get_neighbors(col, row):
						if _grid.get_resource_type(nb) == EconGrid.ResourceType.WHEAT:
							has_wheat = true
							break
					if not has_wheat:
						continue
				_grid.fill_cells[cell] = true
	_grid.queue_redraw()
