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

enum PlaceMode { NONE, BARRACKS, FORTRESS, WORKSHOP, VILLAGE, SAWMILL, MINE, EQUIPMENT_SHOP, TRADE_POST }
var _place_mode: PlaceMode = PlaceMode.NONE
var _is_running: bool = false
var _selected_unit: EconUnit = null
var _guard_select_mode: bool = false
var _order_panel: PanelContainer = null
var _target_priority: int = 0  # 0=標準, 1=前線制圧, 2=経済破壊
var _harvester_ui_update: Callable = Callable()
var _next_h_label: Label = null
var _build_card_btns: Array = []
var _stack_bar: Control = null
var _alloc_harvesters_label: Label = null
var _alloc_subtitle: Label = null
var _place_hint_label: Label = null
var _charge_mode: bool = false  # 一斉突撃モード
var _flags: Array = []
var _next_flag_id: int = 0
var _connecting_building: EconBuilding = null
var _charge_btn: Button = null  # 旗ボタン

# 要件定義書 req_econ_draw_hand_circulation.md §5 UI要素
var _hand_container: HBoxContainer = null  # 手札コンテナ
var _draw_gauge_bar: ColorRect = null      # ドローゲージバー
var _draw_gauge_bg: ColorRect = null       # ドローゲージ背景
var _draw_gauge_label: Label = null        # ドローゲージ下サブテキスト
var _force_charge_segs: Array = []         # 強制突撃ゲージセグメント×10
var _force_charge_turn_label: Label = null  # Turn N/10 表示
var _force_charge_warn_label: Label = null  # 突撃準備推奨ラベル
var _pop_gauge_bar: ColorRect = null        # 人口ゲージバー
var _pop_label: Label = null               # 人口数字ラベル
var _pop_preview_label: Label = null        # [+3] プレビューラベル
var _early_charge_btn: Button = null        # 早期突撃ボタン
var _deck_count_label: Label = null         # Deck: N 表示
var _discard_count_label: Label = null      # Discard/Exiled 表示

# ゲージアニメーション用
var _draw_gauge_blink_timer: float = 0.0
var _force_charge_blink_timer: float = 0.0
var _draw_flash_timer: float = 0.0  # ドロー発動白フラッシュ

const COLOR_PANEL      := Color("#231F1B")
const COLOR_BORDER     := Color("#3C3628")
const COLOR_TEXT       := Color("#DCD2B9")
const COLOR_TEXT_DIM   := Color("#8A8070")
const COLOR_ACCENT_GOLD := Color("#B49448")
const COLOR_WOOD       := Color("#3F6932")
const COLOR_STONE      := Color("#5D5650")
const COLOR_SULFUR     := Color("#9A8A3C")
const COLOR_WHEAT      := Color("#A9924F")
const COLOR_BUILD_COL  := Color("#375590")
const COLOR_TRADE_COL  := Color("#783C8C")
# 要件定義書 req_econ_draw_hand_circulation.md §13.4 / UI仕様書 §7.3
const COLOR_ACCENT_GOLD_BRIGHT := Color("#D4B468")  # ドローゲージ満タン近
const COLOR_ORANGE := Color("#C77A2C")              # 強制突撃ゲージ警戒・突撃ボタン警戒
const COLOR_RED    := Color("#9C3A2A")              # 強制突撃ゲージ危険・人口満タン・警告

func _ready() -> void:
	_setup_grid()
	_setup_economy()
	_setup_battle()
	# origin を先に確定 → エンティティ配置はすべてこの後
	var vp := get_viewport().get_visible_rect().size
	const HEADER_H := 56.0
	const FOOTER_H := 180.0
	var hex_w := EconGrid.HEX_SIZE * sqrt(3.0)
	var col_count := 26
	var board_h := vp.y - HEADER_H - FOOTER_H
	var grid_full_w := hex_w * float(col_count)
	var grid_full_h := EconGrid.HEX_SIZE * 2.0 * 0.75 * float(EconGrid.ROWS - 1) + EconGrid.HEX_SIZE * 2.0
	_grid.origin = Vector2(
		(vp.x - grid_full_w) * 0.5 + hex_w * 0.5,
		HEADER_H + (board_h - grid_full_h) * 0.5 + EconGrid.HEX_SIZE
	)
	_grid.queue_redraw()
	_setup_ui(vp)
	_setup_ai()
	_setup_initial_entities()
	_setup_deck_manager()

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
	enemy_base.setup(EconBuilding.BuildingType.BASE, Vector2i(24, 6), false)
	enemy_base.position = _grid.hex_to_pixel(24, 6)
	enemy_base.unit_produced.connect(_ai.on_unit_produced)
	_battle.register_enemy_building(enemy_base)
	# 敵初期ハーベスター × 2
	for ei in range(2):
		var epos: Vector2i = [Vector2i(23, 5), Vector2i(23, 7)][ei]
		_battle.spawn_enemy_harvester(epos, _ai.economy)
	# AI側の初期農村を自動配置
	_place_initial_village(false)
	# プレイヤーBASE（row 0 中央）自動配置
	var player_base := EconBuilding.new()
	player_base.setup(EconBuilding.BuildingType.BASE, Vector2i(1, 6), true)
	player_base.position = _grid.hex_to_pixel(1, 6)
	player_base.unit_produced.connect(_battle._on_unit_produced)
	player_base.building_destroyed.connect(func(building: Node):
		_battle._on_building_destroyed(building)
	)
	_battle.register_player_building(player_base)
	# 初期農村を小麦隣接タイルに自動配置（is_built=true）
	_place_initial_village(true)
	# プレイヤー初期ハーベスター × 2
	for pi in range(2):
		var ppos: Vector2i = [Vector2i(2, 5), Vector2i(2, 7)][pi]
		_battle.spawn_player_harvester(ppos, _economy)

func _place_initial_village(is_player: bool) -> void:
	# 小麦に隣接するタイルに農村を1棟自動配置（is_built=true）
	var zone_cols: Array = range(0, 8) if is_player else range(18, 26)
	for col in zone_cols:
		for row in range(_grid.ROWS):
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
					else:
						_battle._on_unit_produced(pos, utype)
				)
				village.building_destroyed.connect(func(building: Node):
					_battle._on_building_destroyed(building)
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

	# === HEADER (top 56px) ===
	var header := PanelContainer.new()
	header.position = Vector2.ZERO
	header.custom_minimum_size = Vector2(vp.x, 56)
	_ui_layer.add_child(header)
	var hdr_hbox := HBoxContainer.new()
	hdr_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hdr_hbox.add_theme_constant_override("separation", 16)
	header.add_child(hdr_hbox)
	_resource_label = Label.new()
	_resource_label.text = "Wood:0  Stone:0  Sulfur:0  Wheat:10"
	_resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hbox.add_child(_resource_label)
	_wheat_eval_label = Label.new()
	_wheat_eval_label.text = "農村: --"
	_wheat_eval_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hbox.add_child(_wheat_eval_label)
	var hdr_vsep := VSeparator.new()
	hdr_vsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_hbox.add_child(hdr_vsep)
	_ai_resource_label = Label.new()
	_ai_resource_label.text = "Enemy — W:0  St:0  Su:0  Wh:0"
	hdr_hbox.add_child(_ai_resource_label)
	var hdr_vsep2 := VSeparator.new()
	hdr_vsep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_hbox.add_child(hdr_vsep2)
	_status_label = Label.new()
	_status_label.text = "Setup"
	hdr_hbox.add_child(_status_label)
	var hdr_vsep3 := VSeparator.new()
	hdr_vsep3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_hbox.add_child(hdr_vsep3)
	var hdr_vsep4 := VSeparator.new()
	hdr_vsep4.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_hbox.add_child(hdr_vsep4)
	_charge_btn = Button.new()
	_charge_btn.text = "[Wait] Idle"
	_charge_btn.pressed.connect(_on_charge_btn_pressed)
	hdr_hbox.add_child(_charge_btn)
	var btn_start_hdr := Button.new()
	btn_start_hdr.text = "▶ Start"
	btn_start_hdr.pressed.connect(_on_start_pressed)
	hdr_hbox.add_child(btn_start_hdr)

	# === FOOTER (bottom 180px) ===
	var footer := PanelContainer.new()
	footer.position = Vector2(0, vp.y - 180.0)
	footer.custom_minimum_size = Vector2(vp.x, 180)
	_ui_layer.add_child(footer)
	var ftr_hbox := HBoxContainer.new()
	ftr_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	footer.add_child(ftr_hbox)

	# Left: Harvester allocation (expand fill)
	var alloc := _create_harvester_alloc_ui()
	alloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ftr_hbox.add_child(alloc)

	var vsep1 := VSeparator.new()
	vsep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ftr_hbox.add_child(vsep1)

	# Center: Build panel (fixed ~400px)
	ftr_hbox.add_child(_create_build_panel())

	# 手札UI・ゲージUI追加（§5 UI要件）
	_setup_hand_ui(vp)
	_setup_deck_gauge_ui(vp)

	# Place-on-board hint (floating over board, bottom-left of footer area)
	_place_hint_label = Label.new()
	_place_hint_label.text = "▶ place on board"
	_place_hint_label.position = Vector2(vp.x - 180.0, vp.y - 175.0)
	_place_hint_label.add_theme_font_size_override("font_size", 11)
	_place_hint_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_place_hint_label.visible = false
	_ui_layer.add_child(_place_hint_label)

	# === FLOATING LOG (board area, top-left) ===
	_log_label = Label.new()
	_log_label.position = Vector2(8, 64)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_log_label.custom_minimum_size = Vector2(260, 0)
	_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_label.add_theme_color_override("font_color", Color(1, 1, 0.75, 0.85))
	_ui_layer.add_child(_log_label)

	# === UNIT ORDER PANEL (floating, initially hidden) ===
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

func _create_build_panel() -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(400, 0)
	var sb_root := StyleBoxFlat.new()
	sb_root.bg_color = COLOR_PANEL
	root.add_theme_stylebox_override("panel", sb_root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "— BUILD —"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(title_lbl)

	var cards_hbox := GridContainer.new()
	cards_hbox.columns = 4
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_hbox.add_theme_constant_override("h_separation", 6)
	cards_hbox.add_theme_constant_override("v_separation", 6)
	vbox.add_child(cards_hbox)

	var build_data := [
		# 上段（軍事）4つ
		{"mode": PlaceMode.BARRACKS,       "icon": "⚔",  "name": "兵舎",   "cost": "20W · 10S"},
		{"mode": PlaceMode.FORTRESS,       "icon": "🛡",  "name": "要塞",   "cost": "48S · 15W"},
		{"mode": PlaceMode.WORKSHOP,       "icon": "⚒",  "name": "工房",   "cost": "25W · 5S"},
		{"mode": PlaceMode.EQUIPMENT_SHOP, "icon": "⚙",  "name": "装備屋", "cost": "5W · 3Su"},
		# 下段（経済）4つ
		{"mode": PlaceMode.VILLAGE,        "icon": "⌂",  "name": "農村",   "cost": "15W · 5W"},
		{"mode": PlaceMode.SAWMILL,        "icon": "🪚",  "name": "製材所", "cost": "8W·3S"},
		{"mode": PlaceMode.MINE,           "icon": "⛏",  "name": "鉱山",   "cost": "10S·4Su"},
		{"mode": PlaceMode.TRADE_POST,     "icon": "$",   "name": "交易所", "cost": "5W · 5S"},
	]
	var build_modes_arr := [PlaceMode.BARRACKS, PlaceMode.FORTRESS, PlaceMode.WORKSHOP, PlaceMode.EQUIPMENT_SHOP, PlaceMode.VILLAGE, PlaceMode.SAWMILL, PlaceMode.MINE, PlaceMode.TRADE_POST]

	_build_card_btns = []
	for i in range(build_data.size()):
		var data: Dictionary = build_data[i]
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if i >= 4:  # 下段4つ
			card.add_theme_constant_override("margin_top", 60)
		card.flat = true
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv.add_theme_constant_override("separation", 1)
		cv.add_theme_constant_override("margin_left", 0)
		cv.add_theme_constant_override("margin_right", 0)
		cv.add_theme_constant_override("margin_top", 0)
		cv.add_theme_constant_override("margin_bottom", 0)
		card.add_child(cv)
		var icon_l := Label.new()
		icon_l.text = data["icon"]
		icon_l.add_theme_font_size_override("font_size", 16)
		icon_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_l.add_theme_color_override("font_color", COLOR_TEXT)
		icon_l.add_theme_constant_override("margin_left", 0)
		icon_l.add_theme_constant_override("margin_right", 0)
		icon_l.add_theme_constant_override("margin_top", 0)
		icon_l.add_theme_constant_override("margin_bottom", 0)
		cv.add_child(icon_l)
		var name_l := Label.new()
		name_l.text = data["name"]
		name_l.add_theme_font_size_override("font_size", 10)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_color_override("font_color", COLOR_TEXT)
		name_l.add_theme_constant_override("margin_left", 0)
		name_l.add_theme_constant_override("margin_right", 0)
		name_l.add_theme_constant_override("margin_top", 0)
		name_l.add_theme_constant_override("margin_bottom", 0)
		cv.add_child(name_l)
		var cost_l := Label.new()
		cost_l.text = data["cost"]
		cost_l.add_theme_font_size_override("font_size", 8)
		cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_l.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		cost_l.add_theme_constant_override("margin_left", 0)
		cost_l.add_theme_constant_override("margin_right", 0)
		cost_l.add_theme_constant_override("margin_top", 0)
		cost_l.add_theme_constant_override("margin_bottom", 0)
		cv.add_child(cost_l)
		var cap_mode: int = int(data["mode"])
		var cap_i: int = i
		card.pressed.connect(func():
			if _place_mode == cap_mode:
				_place_mode = PlaceMode.NONE
			else:
				_place_mode = cap_mode
			_update_build_card_styles()
			if _place_hint_label:
				_place_hint_label.visible = (_place_mode != PlaceMode.NONE)
		)
		_build_card_btns.append(card)
		cards_hbox.add_child(card)

	# _mode_label dummy (referenced in _input / _place_building but not displayed)
	_mode_label = Label.new()
	_update_build_card_styles()
	return root

func _update_build_card_styles() -> void:
	var build_modes_arr := [PlaceMode.BARRACKS, PlaceMode.FORTRESS, PlaceMode.WORKSHOP, PlaceMode.EQUIPMENT_SHOP, PlaceMode.VILLAGE, PlaceMode.SAWMILL, PlaceMode.MINE, PlaceMode.TRADE_POST]
	for i in range(_build_card_btns.size()):
		var card: Button = _build_card_btns[i]
		var selected: bool = (_place_mode == build_modes_arr[i])
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLOR_PANEL
		sb.border_color = COLOR_ACCENT_GOLD if selected else COLOR_BORDER
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		card.add_theme_stylebox_override("normal", sb)
		card.add_theme_stylebox_override("pressed", sb)
		var sb_h := StyleBoxFlat.new()
		sb_h.bg_color = Color(COLOR_PANEL.r + 0.06, COLOR_PANEL.g + 0.06, COLOR_PANEL.b + 0.06)
		sb_h.border_color = COLOR_ACCENT_GOLD if selected else COLOR_BORDER
		sb_h.set_border_width_all(2)
		sb_h.set_corner_radius_all(4)
		card.add_theme_stylebox_override("hover", sb_h)
		card.modulate.a = 1.0 if selected else 0.8

func _create_control_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(250, 0)
	scroll.add_child(vbox)
	# Bulk order
	var bulk_title := Label.new()
	bulk_title.text = "-- Bulk / Priority --"
	vbox.add_child(bulk_title)
	var bulk_hbox := HBoxContainer.new()
	vbox.add_child(bulk_hbox)
	var btn_bulk_atk := Button.new()
	btn_bulk_atk.text = "All: Units"
	btn_bulk_atk.pressed.connect(func():
		for u in _battle.player_units:
			u.order = EconUnit.OrderType.ATTACK_UNITS
			u.guard_target = null
	)
	bulk_hbox.add_child(btn_bulk_atk)
	var btn_bulk_harv := Button.new()
	btn_bulk_harv.text = "All: Harvesters"
	btn_bulk_harv.pressed.connect(func():
		for u in _battle.player_units:
			u.order = EconUnit.OrderType.ATTACK_HARVESTERS
			u.guard_target = null
	)
	bulk_hbox.add_child(btn_bulk_harv)
	# Target Priority
	var tp_label := Label.new()
	tp_label.text = "Priority: 標準"
	vbox.add_child(tp_label)
	var tp_hbox := HBoxContainer.new()
	vbox.add_child(tp_hbox)
	var tp_names := ["標準", "前線", "経済"]
	for i in range(3):
		var btn := Button.new()
		btn.text = tp_names[i]
		var captured_i: int = i
		btn.pressed.connect(func():
			_target_priority = captured_i
			tp_label.text = "Priority: " + tp_names[captured_i]
			for u in _battle.player_units:
				u.target_priority = captured_i
		)
		tp_hbox.add_child(btn)
	# Start
	var start_sep := HSeparator.new()
	start_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(start_sep)
	var btn_start := Button.new()
	btn_start.text = "Start Battle"
	btn_start.pressed.connect(_on_start_pressed)
	vbox.add_child(btn_start)
	# Terrain
	var terrain_sep := HSeparator.new()
	terrain_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(terrain_sep)
	var m_hbox := HBoxContainer.new()
	vbox.add_child(m_hbox)
	var m_label := Label.new()
	m_label.text = "Mtn:"
	m_hbox.add_child(m_label)
	var m_slider := HSlider.new()
	m_slider.min_value = 0
	m_slider.max_value = 80
	m_slider.value = 35
	m_slider.custom_minimum_size = Vector2(80, 20)
	m_hbox.add_child(m_slider)
	var m_val_label := Label.new()
	m_val_label.text = "35%"
	m_hbox.add_child(m_val_label)
	var d_hbox := HBoxContainer.new()
	vbox.add_child(d_hbox)
	var d_label := Label.new()
	d_label.text = "Dst:"
	d_hbox.add_child(d_label)
	var d_slider := HSlider.new()
	d_slider.min_value = 0
	d_slider.max_value = 80
	d_slider.value = 25
	d_slider.custom_minimum_size = Vector2(80, 20)
	d_hbox.add_child(d_slider)
	var d_val_label := Label.new()
	d_val_label.text = "25%"
	d_hbox.add_child(d_val_label)
	var p_label := Label.new()
	p_label.text = "Pln: 40%"
	vbox.add_child(p_label)
	m_slider.value_changed.connect(func(v: float):
		m_val_label.text = "%d%%" % int(v)
		if int(v) + int(d_slider.value) > 100:
			d_slider.value = 100 - int(v)
		p_label.text = "Pln: %d%%" % (100 - int(m_slider.value) - int(d_slider.value))
	)
	d_slider.value_changed.connect(func(v: float):
		d_val_label.text = "%d%%" % int(v)
		if int(m_slider.value) + int(v) > 100:
			m_slider.value = 100 - int(v)
		p_label.text = "Pln: %d%%" % (100 - int(m_slider.value) - int(d_slider.value))
	)
	var btn_regen := Button.new()
	btn_regen.text = "Regen Map"
	btn_regen.pressed.connect(func():
		_grid.generate_terrain(int(m_slider.value), int(d_slider.value))
	)
	vbox.add_child(btn_regen)
	return scroll

func _create_harvester_alloc_ui() -> Control:
	var all_keys := [
		EconGrid.ResourceType.WOOD,
		EconGrid.ResourceType.STONE,
		EconGrid.ResourceType.SULFUR,
		EconGrid.ResourceType.WHEAT,
		EconGrid.ResourceType.IRON,
		EconGrid.ResourceType.COTTON,
		EconEconomy.ROLE_BUILD,
		EconEconomy.ROLE_TRADE,
	]
	var col_names  := ["WOOD", "STONE", "SULFUR", "WHEAT", "IRON", "COTTON", "BUILD", "TRADE"]
	var col_icons  := ["🌲", "◆", "✦", "🌾", "⚙", "☁", "⚒", "⚖"]
	var col_colors := [COLOR_WOOD, COLOR_STONE, COLOR_SULFUR, COLOR_WHEAT, Color(0.55, 0.45, 0.35), Color(0.95, 0.92, 0.85), COLOR_BUILD_COL, COLOR_TRADE_COL]

	# Root panel
	var root := PanelContainer.new()
	var sb_root := StyleBoxFlat.new()
	sb_root.bg_color = COLOR_PANEL
	root.add_theme_stylebox_override("panel", sb_root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(vbox)

	# Header row
	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)
	var title_lbl := Label.new()
	title_lbl.text = "— HARVESTER ALLOCATION —"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title_lbl)
	_alloc_subtitle = Label.new()
	_alloc_subtitle.text = "total 0 · weights drive distribution"
	_alloc_subtitle.add_theme_font_size_override("font_size", 11)
	_alloc_subtitle.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	hdr.add_child(_alloc_subtitle)

	# 6 columns
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 0)
	vbox.add_child(cols)

	var count_labels: Array = []
	for i in range(all_keys.size()):
		if i > 0:
			var colsep := VSeparator.new()
			colsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cols.add_child(colsep)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		cols.add_child(col)
		var icon_lbl := Label.new()
		icon_lbl.text = col_icons[i]
		icon_lbl.add_theme_font_size_override("font_size", 18)
		icon_lbl.add_theme_color_override("font_color", col_colors[i])
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(icon_lbl)
		var name_lbl := Label.new()
		name_lbl.text = col_names[i]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_lbl)
		var ctrl_row := HBoxContainer.new()
		ctrl_row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(ctrl_row)
		var btn_m := Button.new()
		btn_m.text = "−"
		btn_m.custom_minimum_size = Vector2(26, 26)
		var ci: int = i
		btn_m.pressed.connect(func():
			var cur: int = _economy.target_count.get(all_keys[ci], 0)
			var tot: int = 0
			for k in all_keys: tot += _economy.target_count.get(k, 0)
			if cur > 0 and tot > 1:
				_economy.target_count[all_keys[ci]] = cur - 1
			_harvester_ui_update.call()
		)
		ctrl_row.add_child(btn_m)
		var cnt_lbl := Label.new()
		cnt_lbl.text = str(_economy.target_count.get(all_keys[i], 0))
		cnt_lbl.custom_minimum_size = Vector2(32, 0)
		cnt_lbl.add_theme_font_size_override("font_size", 16)
		cnt_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_labels.append(cnt_lbl)
		ctrl_row.add_child(cnt_lbl)
		var btn_p := Button.new()
		btn_p.text = "+"
		btn_p.custom_minimum_size = Vector2(26, 26)
		btn_p.pressed.connect(func():
			var cur: int = _economy.target_count.get(all_keys[ci], 0)
			var alive: int = _battle.player_harvesters.size()
			var tot: int = 0
			for k in all_keys: tot += _economy.target_count.get(k, 0)
			if tot < alive + 6:
				_economy.target_count[all_keys[ci]] = cur + 1
			_harvester_ui_update.call()
		)
		ctrl_row.add_child(btn_p)

	# Stack bar
	_stack_bar = Control.new()
	_stack_bar.custom_minimum_size = Vector2(0, 20)
	_stack_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack_bar.draw.connect(func():
		var bw: float = _stack_bar.size.x - 32.0
		var bx: float = 16.0
		var by: float = 1.0
		var bh: float = 16.0
		var alive: int = _battle.player_harvesters.size()
		var tot_t: int = 0
		for k in all_keys: tot_t += _economy.target_count.get(k, 0)
		var scale_v: int = max(alive, tot_t, 1)
		var alive_w: float = bw * float(alive) / float(scale_v)
		_stack_bar.draw_rect(Rect2(bx, by, bw, bh), Color("#1A1814"))
		var x: float = bx
		for ii in range(all_keys.size()):
			var cnt_v: int = _economy.target_count.get(all_keys[ii], 0)
			var sw: float = bw * float(cnt_v) / float(scale_v)
			if sw <= 0.0:
				continue
			var c: Color = col_colors[ii]
			var solid_end: float = min(x + sw, bx + alive_w)
			if solid_end > x:
				_stack_bar.draw_rect(Rect2(x, by, solid_end - x, bh), c)
			if x + sw > bx + alive_w:
				var ts: float = max(x, bx + alive_w)
				_stack_bar.draw_rect(Rect2(ts, by, x + sw - ts, bh), Color(c.r, c.g, c.b, 0.35))
			x += sw
		if alive < scale_v:
			_stack_bar.draw_line(Vector2(bx + alive_w, by), Vector2(bx + alive_w, by + bh), COLOR_TEXT_DIM, 1.5)
		if x < bx + bw:
			_stack_bar.draw_rect(Rect2(x, by, bx + bw - x, bh), COLOR_BORDER)
		_stack_bar.draw_rect(Rect2(bx, by, bw, bh), COLOR_BORDER, false, 1.0)
	)
	vbox.add_child(_stack_bar)

	# Footer row
	var ftr := HBoxContainer.new()
	vbox.add_child(ftr)
	var dist_lbl := Label.new()
	dist_lbl.text = "DISTRIBUTION · READ-ONLY"
	dist_lbl.add_theme_font_size_override("font_size", 10)
	dist_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dist_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ftr.add_child(dist_lbl)
	_next_h_label = Label.new()
	_next_h_label.add_theme_font_size_override("font_size", 10)
	_next_h_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_next_h_label.text = "次H: --"
	ftr.add_child(_next_h_label)
	_alloc_harvesters_label = Label.new()
	_alloc_harvesters_label.text = "0 HARVESTERS"
	_alloc_harvesters_label.add_theme_font_size_override("font_size", 11)
	_alloc_harvesters_label.add_theme_color_override("font_color", COLOR_TEXT)
	ftr.add_child(_alloc_harvesters_label)

	# Update function (called every frame from _process)
	var _update := func():
		var alive: int = _battle.player_harvesters.size()
		_alloc_harvesters_label.text = "%d HARVESTERS" % alive
		var tot: int = 0
		for k in all_keys: tot += _economy.target_count.get(k, 0)
		_alloc_subtitle.text = "total %d · weights drive distribution" % tot
		for i2 in range(all_keys.size()):
			count_labels[i2].text = str(_economy.target_count.get(all_keys[i2], 0))
		if _stack_bar != null:
			_stack_bar.queue_redraw()
		var min_rem: float = INF
		for b in _battle.player_buildings:
			if b.is_alive and b.is_built and b.get("building_type") != null:
				if b.building_type == EconBuilding.BuildingType.VILLAGE:
					min_rem = minf(min_rem, EconBuilding.VILLAGE_HARVESTER_INTERVAL - b._harvester_timer)
		_next_h_label.text = "次H: %.0fs" % min_rem if min_rem < INF else "次H: 農村なし"
	_harvester_ui_update = _update
	_update.call()
	return root

func _on_start_pressed() -> void:
	if _is_running:
		return
	_is_running = true
	_battle.start()
	_status_label.text = "Battle running..."


func _on_charge_btn_pressed() -> void:
	_charge_mode = not _charge_mode
	if _charge_mode:
		_charge_btn.text = "[Atk] CHARGE!"
		for u in _battle.player_units:
			if u.is_alive and u.is_idle:
				u.is_idle = false
		for f in _flags:
			f.is_assault_mode = true
			f.queue_redraw()
		_add_log("ALL CHARGE!")
	else:
		_charge_btn.text = "[Wait] Idle"
		for f in _flags:
			f.is_assault_mode = false
			f.queue_redraw()
		_add_log("Idle mode (new units will wait)")

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		return
	# 右クリック: 旗設置
	if event.button_index == MOUSE_BUTTON_RIGHT:
		var local_pos2: Vector2 = _grid.to_local(get_global_mouse_position())
		var rcell := _pixel_to_hex(local_pos2)
		if rcell == Vector2i(-1, -1):
			return
		# 既存の旗があれば削除（同じ位置を右クリック）
		for f in _flags:
			if f.grid_pos == rcell:
				_remove_flag(f)
				return
		# 建物タイルには設置不可
		for b in _battle.player_buildings:
			if b.grid_pos == rcell:
				return
		_place_flag(rcell)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Ignore clicks in header / footer UI areas
	var mouse_y: float = event.position.y
	var vp_h: float = get_viewport().get_visible_rect().size.y
	if mouse_y < 56.0 or mouse_y > vp_h - 180.0:
		return
	var local_pos: Vector2 = _grid.to_local(get_global_mouse_position())
	var cell := _pixel_to_hex(local_pos)
	# 旗クリック検出（接続モード中）
	if _connecting_building != null:
		for f in _flags:
			if f.grid_pos == cell:
				_connect_building_to_flag(_connecting_building, f)
				_connecting_building = null
				return
		_connecting_building = null
		return
	# 建物クリック → 接続元として選択
	if cell != Vector2i(-1, -1):
		for b in _battle.player_buildings:
			if b.is_alive and b.grid_pos == cell:
				_connecting_building = b
				_add_log("Select flag to connect (ESC to cancel)")
				return
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
		_update_build_card_styles()
		if _place_hint_label: _place_hint_label.visible = false
		return
	# 未建設建物のキャンセル
	for b in _battle.player_buildings:
		if b.grid_pos == cell and not b.is_built:
			_battle.player_buildings.erase(b)
			b.queue_free()
			_add_log("建設キャンセル")
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
		PlaceMode.SAWMILL:  EconBuilding.BuildingType.SAWMILL,
		PlaceMode.MINE:     EconBuilding.BuildingType.MINE,
		PlaceMode.EQUIPMENT_SHOP: EconBuilding.BuildingType.EQUIPMENT_SHOP,
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
		_update_build_card_styles()
		if _place_hint_label: _place_hint_label.visible = false
		return
	# SAWMILL: WOODタイル隣接必須
	if btype == int(EconBuilding.BuildingType.SAWMILL):
		var has_wood := false
		for nb in _grid.get_neighbors(cell.x, cell.y):
			if _grid.get_resource_type(nb) == EconGrid.ResourceType.WOOD:
				has_wood = true
				break
		if not has_wood:
			_add_log("製材所は木材タイルに隣接して建設してください")
			_place_mode = PlaceMode.NONE
			_update_build_card_styles()
			if _place_hint_label: _place_hint_label.visible = false
			return
	# MINE: STONE/SULFUR/IRONタイル隣接必須
	if btype == int(EconBuilding.BuildingType.MINE):
		var has_ore := false
		for nb in _grid.get_neighbors(cell.x, cell.y):
			var ntype := _grid.get_resource_type(nb)
			if ntype in [EconGrid.ResourceType.STONE, EconGrid.ResourceType.SULFUR, EconGrid.ResourceType.IRON]:
				has_ore = true
				break
		if not has_ore:
			_add_log("鉱山は石材・硫黄・鉄鉱タイルに隣接して建設してください")
			_place_mode = PlaceMode.NONE
			_update_build_card_styles()
			if _place_hint_label: _place_hint_label.visible = false
			return
	var b := EconBuilding.new()
	b.setup(btype, cell, true)
	b.position = _grid.hex_to_pixel(cell.x, cell.y)
	b.unit_produced.connect(func(pos: Vector2i, utype: int):
		if utype == -1:
			_spawn_harvester_at(pos.x, pos.y)
		elif _charge_mode:
			_battle.spawn_player_unit(pos.x, pos.y, utype, _charge_mode)
			# ユニット生成後のバフ適用は _battle._on_unit_produced() で処理（疎結合）
			_battle._on_unit_produced(pos, utype)
		else:
			var idle_count: int = 0
			for u in _battle.player_units:
				if u.is_alive and u.is_idle and u.grid_pos == pos:
					idle_count += 1
			if idle_count < EconGrid.MAX_STACK:
				_battle.spawn_player_unit(pos.x, pos.y, utype, _charge_mode)
				# ユニット生成後のバフ適用は _battle._on_unit_produced() で処理（疎結合）
				_battle._on_unit_produced(pos, utype)
	)
	b.building_destroyed.connect(func(building: Node):
		_battle._on_building_destroyed(building)
	)
	_battle.register_player_building(b)
	var names := ["Barracks", "Fortress", "Workshop", "Village", "BASE", "Sawmill", "Mine", "Equipment_Shop"]
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
	if _harvester_ui_update.is_valid():
		_harvester_ui_update.call()
	# ドロー・ゲージ・人口UI更新（§5 pull型）
	_update_draw_gauge_ui(delta)
	_update_force_charge_gauge_ui(delta)
	_update_population_ui()

func _update_build_highlight() -> void:
	_grid.highlight_cells.clear()
	_grid.fill_cells.clear()
	# 資源タイル強調（建設モード時のみ）
	var resource_highlight_map: Dictionary = {
		PlaceMode.BARRACKS: EconGrid.ResourceType.WOOD,
		PlaceMode.FORTRESS: EconGrid.ResourceType.STONE,
		PlaceMode.WORKSHOP: EconGrid.ResourceType.SULFUR,
		PlaceMode.VILLAGE:  EconGrid.ResourceType.WHEAT,
		PlaceMode.SAWMILL:  EconGrid.ResourceType.WOOD,
		PlaceMode.MINE:     EconGrid.ResourceType.STONE,
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
	# fill_cells（建設モード時のみ塗りつぶし）: col 0-7フィルタ
	if _place_mode != PlaceMode.NONE:
		for col in range(0, 8):
			for row in range(_grid.ROWS):
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
				# 敵領土内には建設不可
				if _grid.enemy_territory_cells.has(cell):
					continue
				if _place_mode == PlaceMode.SAWMILL:
					var has_wood := false
					for nb in _grid.get_neighbors(col, row):
						if _grid.get_resource_type(nb) == EconGrid.ResourceType.WOOD:
							has_wood = true
							break
					if not has_wood:
						continue
				if _place_mode == PlaceMode.MINE:
					var has_ore := false
					for nb in _grid.get_neighbors(col, row):
						var ntype := _grid.get_resource_type(nb)
						if ntype in [EconGrid.ResourceType.STONE, EconGrid.ResourceType.SULFUR, EconGrid.ResourceType.IRON]:
							has_ore = true
							break
					if not has_ore:
						continue
				_grid.fill_cells[cell] = true
	_grid.queue_redraw()

func _place_flag(pos: Vector2i) -> void:
	var f = load("res://scripts/econ_mvp/EconRallyFlag.gd").new()
	f.setup(_next_flag_id, pos)
	f.grid_ref = _grid
	f.buildings_ref = _battle.player_buildings
	_next_flag_id += 1
	f.position = _grid.hex_to_pixel(pos.x, pos.y)
	_grid.add_child(f)
	_flags.append(f)
	_battle.set_player_flags(_flags)
	_add_log("Flag placed at (%d,%d)" % [pos.x, pos.y])

func _connect_building_to_flag(b: EconBuilding, f) -> void:
	if b.connected_flag_id >= 0:
		for old_f in _flags:
			if old_f.flag_id == b.connected_flag_id:
				old_f.remove_building(b.grid_pos)
				old_f.queue_redraw()
	b.connected_flag_id = f.flag_id
	f.add_building(b.grid_pos)
	f.queue_redraw()
	_add_log("Building (%d,%d) → Flag %d" % [b.grid_pos.x, b.grid_pos.y, f.flag_id])

func get_building_cluster_center(building_pos: Vector2i) -> Vector2:
	var idle_units: Array = _battle.player_units.filter(func(u):
		return u._spawn_building_pos == building_pos and u.is_idle and u.is_alive
	)
	if idle_units.is_empty():
		return Vector2(building_pos)
	var sum := Vector2.ZERO
	for u in idle_units:
		sum += Vector2(u.grid_pos)
	return sum / idle_units.size()

func get_flag_cluster_center(flag) -> Vector2:
	var idle_units: Array = _battle.player_units.filter(func(u):
		return flag.connected_buildings.has(u._spawn_building_pos) and u.is_idle and u.is_alive
	)
	if idle_units.is_empty():
		return Vector2(flag.grid_pos)
	var sum := Vector2.ZERO
	for u in idle_units:
		sum += Vector2(u.grid_pos)
	return sum / idle_units.size()

func get_enemy_base_position() -> Vector2i:
	for b in _battle.enemy_buildings:
		if b.building_type == EconBuilding.BuildingType.BASE and b.is_alive:
			return b.grid_pos
	return Vector2i(-1, -1)

func _remove_flag(flag: EconRallyFlag) -> void:
	# 接続していた建物の connected_flag_id をリセット
	for b in _battle.player_buildings:
		if b.connected_flag_id == flag.flag_id:
			b.connected_flag_id = -1
	_flags.erase(flag)
	_battle.set_player_flags(_flags)
	flag.queue_free()
	_add_log("Flag removed at (%d,%d)" % [flag.grid_pos.x, flag.grid_pos.y])

func get_flag_for_building(bpos: Vector2i) -> EconRallyFlag:
	for f in _flags:
		if f.connected_buildings.has(bpos):
			return f
	return null

# ---- ドロー・手札・ゲージシステム（§5 UI要件） ----

func _setup_deck_manager() -> void:
	# §7.1 cards_econ.json からデッキをロード
	var path := "res://data/cards_econ.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_add_log("[DeckManager] cards_econ.json not found")
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary) or not parsed.has("cards"):
		_add_log("[DeckManager] cards_econ.json parse error")
		return
	var initial_deck: Array = parsed["cards"]
	# デッキシャッフルは v0.1 では行わない（KISS）
	_battle.setup_deck(initial_deck, _on_card_drawn)
	print("[EconMain] _setup_deck_manager: %d cards loaded" % initial_deck.size())

func _on_card_drawn(card: Dictionary) -> void:
	# ドロー時のUI更新（カード飛来Tween起点）
	print("[EconMain] _on_card_drawn: %s" % card.get("name", "?"))
	_refresh_hand_ui()
	# ドロー発動白フラッシュ（§5.1.1 ドロー発動瞬間）
	_draw_flash_timer = 0.1

func _refresh_hand_ui() -> void:
	# 手札UIを再構築（§5.3）
	if _hand_container == null:
		return
	# 既存カードを全削除
	for child in _hand_container.get_children():
		child.queue_free()
	if _battle.deck_manager == null:
		return
	# 手札カードを左→右で配置（ドロー順固定 §5.3 §2.8）
	var hand_size: int = int(_battle.deck_manager.hand.size())
	for i in range(hand_size):
		var card_data: Dictionary = _battle.deck_manager.hand[i]
		var card_node := _create_hand_card_node(card_data, i)
		_hand_container.add_child(card_node)
	# 山札枚数表示更新（§5.6）
	if _deck_count_label != null:
		_deck_count_label.text = "Deck:%d" % int(_battle.deck_manager.deck.size())
	if _discard_count_label != null:
		_discard_count_label.text = "Exiled:%d" % int(_battle.deck_manager.excluded.size())

func _create_hand_card_node(card_data: Dictionary, card_idx: int) -> Control:
	# §5.3 手札カード1枚のノードを生成（120×160px）
	var card_btn := Button.new()
	card_btn.custom_minimum_size = Vector2(120, 160)
	card_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# 状態判定（§5.3.2 6状態の優先順位チェック）
	var state := _get_card_state(card_data)

	# スタイル適用
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.set_corner_radius_all(4)
	match state:
		"available":
			sb.border_color = COLOR_ACCENT_GOLD
			sb.set_border_width_all(2)
		"resource_short":
			sb.border_color = Color("#5A4A2C")
			sb.set_border_width_all(2)
			sb.bg_color = COLOR_PANEL.darkened(0.2)
		"pop_short":
			sb.border_color = COLOR_RED
			sb.set_border_width_all(2)
			sb.bg_color = COLOR_PANEL.darkened(0.4)
		"no_cell":
			sb.border_color = Color("#5A4A2C")
			sb.set_border_width_all(1)
			sb.bg_color = COLOR_PANEL.darkened(0.5)
		_:
			sb.border_color = COLOR_ACCENT_GOLD
			sb.set_border_width_all(2)
	card_btn.add_theme_stylebox_override("normal", sb)
	card_btn.add_theme_stylebox_override("hover", sb)
	card_btn.add_theme_stylebox_override("pressed", sb)

	# カード内レイアウト（§5.3.1）
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	card_btn.add_child(vbox)

	var icon_lbl := Label.new()
	icon_lbl.text = _get_card_icon(card_data.get("building_type", ""))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 24)
	icon_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	icon_lbl.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = card_data.get("name", "?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(name_lbl)

	var pop_lbl := Label.new()
	pop_lbl.text = "人口:%d" % card_data.get("population_required", 0)
	pop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop_lbl.add_theme_font_size_override("font_size", 10)
	pop_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vbox.add_child(pop_lbl)

	var cost_raw = card_data.get("cost")
	var cost: Dictionary = cost_raw if cost_raw is Dictionary else {}
	var cost_parts: Array = []
	if cost.get("wood", 0) > 0: cost_parts.append("木%d" % cost["wood"])
	if cost.get("stone", 0) > 0: cost_parts.append("石%d" % cost["stone"])
	var cost_lbl := Label.new()
	cost_lbl.text = " ".join(cost_parts) if not cost_parts.is_empty() else "無料"
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 10)
	var cost_color := COLOR_RED if state == "resource_short" else COLOR_TEXT_DIM
	cost_lbl.add_theme_color_override("font_color", cost_color)
	vbox.add_child(cost_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = card_data.get("description", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	# クリックで建設モード起動（v0.1 PlaceMode 連携）
	var captured_idx: int = card_idx
	var captured_card: Dictionary = card_data
	card_btn.pressed.connect(func():
		if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
			_add_log("突撃発動中: 建設停止")
			return
		_add_log("手札: %s を選択（盤面クリックで配置）" % captured_card.get("name", "?"))
		# v0.1 は既存 PlaceMode に対応する建物タイプにマッピング
		_set_place_mode_from_card(captured_card, captured_idx)
	)

	# 住居ホバー時の人口プレビュー（§5.5.3）
	card_btn.mouse_entered.connect(func():
		if card_data.get("building_type", "") == "HOUSE" and _pop_preview_label != null:
			_pop_preview_label.text = "[+%d]" % card_data.get("population_supply", 3)
			_pop_preview_label.visible = true
	)
	card_btn.mouse_exited.connect(func():
		if _pop_preview_label != null:
			_pop_preview_label.visible = false
	)

	return card_btn

func _get_card_state(card_data: Dictionary) -> String:
	# §5.3.2.1 状態決定ツリー（優先順位降順）
	if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
		return "no_cell"
	var cost_raw = card_data.get("cost")
	var cost: Dictionary = cost_raw if cost_raw is Dictionary else {}
	var eco := _economy
	# 人口チェック
	var pop_req: int = card_data.get("population_required", 0)
	if eco.population_used + pop_req > eco.population_cap:
		return "pop_short"
	# 資源チェック
	if cost.get("wood", 0) > eco.wood or cost.get("stone", 0) > eco.stone or cost.get("sulfur", 0) > eco.sulfur:
		return "resource_short"
	return "available"

func _get_card_icon(building_type: String) -> String:
	var icons: Dictionary = {
		"BARRACKS": "⚔",
		"HOUSE": "⌂",
		"LIBRARY": "📚",
		"MARKET": "$",
		"WOOD_EXTRACTOR": "🪵",
		"STONE_EXTRACTOR": "⛏",
		"SULFUR_EXTRACTOR": "🔥",
		"WHEAT_EXTRACTOR": "🌾",
		"IRON_EXTRACTOR": "⚙",
		"COTTON_EXTRACTOR": "🌿",
	}
	return icons.get(building_type, "?")

func _set_place_mode_from_card(card_data: Dictionary, card_idx: int) -> void:
	# 手札カードから既存 PlaceMode を設定（v0.1 統合）
	var btype: String = card_data.get("building_type", "")
	var mode_map: Dictionary = {
		"BARRACKS": PlaceMode.BARRACKS,
		"HOUSE": PlaceMode.VILLAGE,
		"LIBRARY": PlaceMode.TRADE_POST,
		"MARKET": PlaceMode.TRADE_POST,
		"WOOD_EXTRACTOR": PlaceMode.SAWMILL,
		"STONE_EXTRACTOR": PlaceMode.MINE,
		"SULFUR_EXTRACTOR": PlaceMode.MINE,
		"WHEAT_EXTRACTOR": PlaceMode.VILLAGE,
		"IRON_EXTRACTOR": PlaceMode.MINE,
		"COTTON_EXTRACTOR": PlaceMode.VILLAGE,
	}
	if mode_map.has(btype):
		_place_mode = mode_map[btype]
		_update_build_card_styles()
		if _place_hint_label:
			_place_hint_label.visible = true

func _setup_deck_gauge_ui(vp: Vector2) -> void:
	# §5.1 ドローゲージUI（x=970, y=600, 160×20）
	var draw_gauge_root := Control.new()
	draw_gauge_root.position = Vector2(970, 580)
	_ui_layer.add_child(draw_gauge_root)

	var draw_label_top := Label.new()
	draw_label_top.text = "NEXT DRAW"
	draw_label_top.position = Vector2(0, 0)
	draw_label_top.add_theme_font_size_override("font_size", 10)
	draw_label_top.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	draw_gauge_root.add_child(draw_label_top)

	_draw_gauge_bg = ColorRect.new()
	_draw_gauge_bg.position = Vector2(0, 14)
	_draw_gauge_bg.size = Vector2(160, 20)
	_draw_gauge_bg.color = COLOR_PANEL
	draw_gauge_root.add_child(_draw_gauge_bg)

	_draw_gauge_bar = ColorRect.new()
	_draw_gauge_bar.position = Vector2(0, 14)
	_draw_gauge_bar.size = Vector2(0, 20)
	_draw_gauge_bar.color = COLOR_ACCENT_GOLD
	draw_gauge_root.add_child(_draw_gauge_bar)

	_draw_gauge_label = Label.new()
	_draw_gauge_label.position = Vector2(0, 36)
	_draw_gauge_label.add_theme_font_size_override("font_size", 10)
	_draw_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	draw_gauge_root.add_child(_draw_gauge_label)

	# §5.2 強制突撃ゲージUI（x=440, y=14, 400×24, 10分割）
	var fc_root := Control.new()
	fc_root.position = Vector2(440, 2)
	_ui_layer.add_child(fc_root)

	var fc_label_top := Label.new()
	fc_label_top.text = "FORCED CHARGE"
	fc_label_top.position = Vector2(0, 0)
	fc_label_top.add_theme_font_size_override("font_size", 10)
	fc_label_top.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	fc_root.add_child(fc_label_top)

	_force_charge_segs = []
	for i in range(10):
		var seg := ColorRect.new()
		seg.position = Vector2(i * 40, 14)
		seg.size = Vector2(38, 24)
		seg.color = COLOR_PANEL
		fc_root.add_child(seg)
		_force_charge_segs.append(seg)

	_force_charge_turn_label = Label.new()
	_force_charge_turn_label.text = "Turn 0/10"
	_force_charge_turn_label.position = Vector2(0, 40)
	_force_charge_turn_label.add_theme_font_size_override("font_size", 9)
	_force_charge_turn_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	fc_root.add_child(_force_charge_turn_label)

	_force_charge_warn_label = Label.new()
	_force_charge_warn_label.text = "突撃準備推奨"
	_force_charge_warn_label.position = Vector2(280, 40)
	_force_charge_warn_label.add_theme_font_size_override("font_size", 11)
	_force_charge_warn_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_force_charge_warn_label.visible = false
	fc_root.add_child(_force_charge_warn_label)

	# §5.2.2 早期突撃ボタン（x=890, y=12, 100×32）
	_early_charge_btn = Button.new()
	_early_charge_btn.text = "EARLY CHARGE"
	_early_charge_btn.position = Vector2(890, 12)
	_early_charge_btn.custom_minimum_size = Vector2(100, 32)
	var ec_sb := StyleBoxFlat.new()
	ec_sb.bg_color = COLOR_PANEL
	ec_sb.border_color = COLOR_BORDER
	ec_sb.set_border_width_all(1)
	ec_sb.set_corner_radius_all(3)
	_early_charge_btn.add_theme_stylebox_override("normal", ec_sb)
	_early_charge_btn.add_theme_font_size_override("font_size", 11)
	_early_charge_btn.add_theme_color_override("font_color", COLOR_TEXT)
	_early_charge_btn.pressed.connect(_on_early_charge_btn_pressed)
	_ui_layer.add_child(_early_charge_btn)

	# §5.5 人口表示UI（x=1140, y=600, w=80）
	var pop_root := Control.new()
	pop_root.position = Vector2(1140, 580)
	_ui_layer.add_child(pop_root)

	var pop_label_top := Label.new()
	pop_label_top.text = "POPULATION"
	pop_label_top.position = Vector2(0, 0)
	pop_label_top.add_theme_font_size_override("font_size", 10)
	pop_label_top.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	pop_root.add_child(pop_label_top)

	var pop_bar_bg := ColorRect.new()
	pop_bar_bg.position = Vector2(0, 14)
	pop_bar_bg.size = Vector2(80, 12)
	pop_bar_bg.color = COLOR_PANEL
	pop_root.add_child(pop_bar_bg)

	_pop_gauge_bar = ColorRect.new()
	_pop_gauge_bar.position = Vector2(0, 14)
	_pop_gauge_bar.size = Vector2(40, 12)
	_pop_gauge_bar.color = COLOR_WOOD
	pop_root.add_child(_pop_gauge_bar)

	_pop_label = Label.new()
	_pop_label.text = "0/3"
	_pop_label.position = Vector2(0, 28)
	_pop_label.add_theme_font_size_override("font_size", 12)
	_pop_label.add_theme_color_override("font_color", COLOR_TEXT)
	pop_root.add_child(_pop_label)

	_pop_preview_label = Label.new()
	_pop_preview_label.text = "[+3]"
	_pop_preview_label.position = Vector2(0, 44)
	_pop_preview_label.add_theme_font_size_override("font_size", 11)
	_pop_preview_label.add_theme_color_override("font_color", COLOR_WOOD)
	_pop_preview_label.visible = false
	pop_root.add_child(_pop_preview_label)

	# §5.6 山札・除外枚数表示
	_deck_count_label = Label.new()
	_deck_count_label.text = "Deck:13"
	_deck_count_label.position = Vector2(336, vp.y - 178)
	_deck_count_label.add_theme_font_size_override("font_size", 10)
	_deck_count_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_ui_layer.add_child(_deck_count_label)

	_discard_count_label = Label.new()
	_discard_count_label.text = "Exiled:0"
	_discard_count_label.position = Vector2(336, vp.y - 165)
	_discard_count_label.add_theme_font_size_override("font_size", 10)
	_discard_count_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_ui_layer.add_child(_discard_count_label)

func _setup_hand_ui(vp: Vector2) -> void:
	# §5.3 手札UI（FOOTER中央 x=336, y=560, w=632）
	var hand_root := Control.new()
	hand_root.position = Vector2(336, vp.y - 175)
	hand_root.custom_minimum_size = Vector2(632, 160)
	_ui_layer.add_child(hand_root)

	_hand_container = HBoxContainer.new()
	_hand_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hand_container.add_theme_constant_override("separation", 8)
	hand_root.add_child(_hand_container)

func _update_draw_gauge_ui(delta: float) -> void:
	# §5.1 ドローゲージUI 毎フレーム更新（_process から呼ぶ）
	if _draw_gauge_bar == null or _battle.deck_manager == null:
		return
	var gauge_val: float = float(_battle.deck_manager.draw_gauge_value)
	var gauge_max: float = 30.0  # TURN_DURATION_SEC 固定値（Variant参照回避）
	var pending: int = int(_battle.deck_manager.pending_draws)
	var progress: float = clampf(gauge_val / gauge_max, 0.0, 1.0)

	# §5.1.1 4状態のバー色と演出
	_draw_gauge_blink_timer += delta
	var bar_color: Color = COLOR_ACCENT_GOLD
	var sub_text: String = "%.0fs" % (gauge_max - gauge_val)

	if pending > 0:
		# 手札MAX保留（§5.1.1）
		bar_color = COLOR_TEXT_DIM
		sub_text = "MAX (5/5)"
		_draw_gauge_label.add_theme_color_override("font_color", COLOR_RED)
	elif _draw_flash_timer > 0.0:
		# ドロー発動瞬間（白フラッシュ §5.1.1）
		_draw_flash_timer -= delta
		bar_color = Color.WHITE
		sub_text = ""
	elif progress >= 0.8:
		# もうすぐドロー（§5.1.1）
		var blink_period: float = 0.5 if progress >= 0.9 else 1.0
		var blink_alpha: float = 0.7 + 0.3 * sin(_draw_gauge_blink_timer * PI * 2.0 / blink_period)
		bar_color = COLOR_ACCENT_GOLD_BRIGHT
		bar_color.a = blink_alpha
		sub_text = "Soon..."
		_draw_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	else:
		_draw_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)

	_draw_gauge_bar.size = Vector2(160.0 * progress, 20)
	_draw_gauge_bar.color = bar_color
	_draw_gauge_label.text = sub_text

func _update_force_charge_gauge_ui(delta: float) -> void:
	# §5.2 強制突撃ゲージUI 毎フレーム更新
	if _force_charge_segs.is_empty() or _battle.deck_manager == null:
		return
	var turn: int = clampi(int(_battle.deck_manager.current_turn), 0, 10)

	_force_charge_blink_timer += delta

	# セグメント色更新
	for i in range(10):
		var seg: ColorRect = _force_charge_segs[i]
		if i < turn:
			# §5.2.1 段階色
			var seg_color: Color
			var seg_turn := i + 1  # 1始まり
			if seg_turn <= 3:
				seg_color = COLOR_WOOD        # 緑 平常
			elif seg_turn <= 6:
				seg_color = COLOR_WHEAT       # 黄 注意
			elif seg_turn <= 9:
				# 橙 警戒（0.8秒周期明滅）
				var blink := 0.7 + 0.3 * sin(_force_charge_blink_timer * PI * 2.0 / 0.8)
				seg_color = COLOR_ORANGE
				seg_color.a = blink
			else:
				# 赤 危険（0.4秒周期強明滅）
				var blink := 0.5 + 0.5 * sin(_force_charge_blink_timer * PI * 2.0 / 0.4)
				seg_color = COLOR_RED
				seg_color.a = blink
			seg.color = seg_color
		else:
			seg.color = COLOR_PANEL

	if _force_charge_turn_label != null:
		_force_charge_turn_label.text = "Turn %d/10" % turn

	# Turn7以降 突撃準備推奨ラベル（§5.2.1）
	if _force_charge_warn_label != null:
		_force_charge_warn_label.visible = (turn >= 7)

	# 早期突撃ボタンの色連動（§5.2.2）
	if _early_charge_btn != null:
		var ec_sb := StyleBoxFlat.new()
		ec_sb.bg_color = COLOR_PANEL
		ec_sb.set_corner_radius_all(3)
		if turn >= 10:
			ec_sb.border_color = COLOR_RED
			ec_sb.set_border_width_all(2)
			_early_charge_btn.add_theme_color_override("font_color", COLOR_RED)
		elif turn >= 7:
			ec_sb.border_color = COLOR_ORANGE
			ec_sb.set_border_width_all(2)
			_early_charge_btn.add_theme_color_override("font_color", COLOR_ORANGE)
		else:
			ec_sb.border_color = COLOR_BORDER
			ec_sb.set_border_width_all(1)
			_early_charge_btn.add_theme_color_override("font_color", COLOR_TEXT)
		_early_charge_btn.add_theme_stylebox_override("normal", ec_sb)

func _update_population_ui() -> void:
	# §5.5 人口表示UI 毎フレーム更新（pull型）
	if _pop_gauge_bar == null or _pop_label == null:
		return
	var pop_used: int = _economy.population_used
	var pop_cap: int = _economy.population_cap
	if pop_cap <= 0:
		return
	var ratio: float = float(pop_used) / float(pop_cap)
	_pop_gauge_bar.size = Vector2(80.0 * clampf(ratio, 0.0, 1.0), 12)
	# §5.5.1 色分け
	if ratio >= 1.0:
		_pop_gauge_bar.color = COLOR_RED
		_pop_label.add_theme_color_override("font_color", COLOR_RED)
	elif ratio >= 0.7:
		_pop_gauge_bar.color = COLOR_WHEAT
		_pop_label.add_theme_color_override("font_color", COLOR_TEXT)
	else:
		_pop_gauge_bar.color = COLOR_WOOD
		_pop_label.add_theme_color_override("font_color", COLOR_TEXT)
	_pop_label.text = "%d/%d" % [pop_used, pop_cap]

func _on_early_charge_btn_pressed() -> void:
	# §5.2.2 早期突撃ボタン押下
	if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
		return
	_battle.trigger_early_charge()
	if _early_charge_btn != null:
		_early_charge_btn.disabled = true
	_add_log("早期突撃発動!")
	_charge_mode = true
	for u in _battle.player_units:
		if u.is_alive and u.is_idle:
			u.is_idle = false
	for f in _flags:
		f.is_assault_mode = true
		f.queue_redraw()
