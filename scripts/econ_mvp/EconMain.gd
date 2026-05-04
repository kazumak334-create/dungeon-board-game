class_name EconMain
extends Node2D

var _grid: EconGrid
var _economy: EconEconomy
var _battle: EconBattle
var _ai: EconAI
var _game_session = null
var _reward_manager = null

var _ui_layer: CanvasLayer
var _econ_ui: Control = null
var _milestone_window = null
var _reward_selection_ui = null
var _land_placement_controller = null
var _build_queue_ui: Control = null
var _log_manager: Node = null
var _ai_resource_label: Label
var _log_label: Label
var _status_label: Label
var _difficulty_dialog: Control = null

var _log_lines: Array = []
const MAX_LOG_LINES := 10
const LABOR_COST_PER_UNIT := 5
const EconUIScript := preload("res://scripts/econ_mvp/EconUI.gd")
const BuildQueueUIScript := preload("res://scripts/econ_mvp/ui/BuildQueueUI.gd")
const LogManagerScript := preload("res://scripts/econ_mvp/LogManager.gd")
const GameSessionScript := preload("res://scripts/econ_mvp/GameSession.gd")
const RewardSystemManagerScript := preload("res://scripts/econ_mvp/RewardSystemManager.gd")
const MilestoneWindowScript := preload("res://scripts/econ_mvp/MilestoneWindow.gd")
const RewardSelectionUIScript := preload("res://scripts/econ_mvp/RewardSelectionUI.gd")
const LandCardPlacementControllerScript := preload("res://scripts/econ_mvp/LandCardPlacementController.gd")
const INITIAL_DECK: Array = [
	{"id": "card_house", "count": 3},
	{"id": "card_village", "count": 2},
	{"id": "card_wood_extractor", "count": 2},
	{"id": "card_stone_extractor", "count": 2},
	{"id": "card_diner", "count": 1},
	{"id": "card_barracks", "count": 1},
	{"id": "card_plaza", "count": 1},
	{"id": "card_trade_post", "count": 1},
]

var _is_running: bool = false
var _selected_unit: EconUnit = null
var _guard_select_mode: bool = false
var _order_panel: PanelContainer = null
var _target_priority: int = 0  # 0=讓呎ｺ・ 1=蜑咲ｷ壼宛蝨ｧ, 2=邨梧ｸ育ｴ螢・
var _place_hint_label: Label = null
var _charge_mode: bool = false  # 荳譁臥ｪ∵茶繝｢繝ｼ繝・
var _flags: Array = []
var _next_flag_id: int = 0
var _next_construction_order: int = 1
var _connecting_building: EconBuilding = null
var _charge_btn: Button = null
var _land_reward_panel: PanelContainer = null
var _pending_reward_queue: Array = []

# v0.2 謇区惆繧ｫ繝ｼ繝蛾∈謚樔ｸｭ縺ｮ蟒ｺ險ｭ繧ｿ繧､繝暦ｼ域枚蟄怜・・・var _selected_card_btype: String = ""
var _selected_card_btype: String = ""
# v0.2 謇区惆繧ｫ繝ｼ繝蛾∈謚樔ｸｭ縺ｮ繧､繝ｳ繝・ャ繧ｯ繧ｹ・・1=譛ｪ驕ｸ謚橸ｼ・
var _selected_card_idx: int = -1

# Phase 3: BASE髟ｷ謚ｼ縺嶺ｸ譁臥ｪ∵茶
var _base_longpress_start_time: float = -1.0
var _base_longpress_cell: Vector2i = Vector2i(-1, -1)
const BASE_LONGPRESS_THRESHOLD := 0.6

# Phase 4: START繝懊ち繝ｳ
var _start_button: Button = null
var _game_started: bool = false

# v0.2 HEADER / FOOTER UI隕∫ｴ
var _header: PanelContainer = null         # HEADER 繧ｳ繝ｳ繝・リ・医し繧､繧ｺ蜿門ｾ礼畑・・
var _hand_container: HBoxContainer = null  # 謇区惆繧ｳ繝ｳ繝・リ
var _hand_scroll_offset: int = 0           # 繧ｹ繧ｯ繝ｭ繝ｼ繝ｫ繧ｪ繝輔そ繝・ヨ・・-based・・
var _hand_left_arrow: Button = null        # 笳遏｢蜊ｰ
var _hand_right_arrow: Button = null       # 笆ｶ遏｢蜊ｰ
var _draw_gauge_bar: ColorRect = null      # 繝峨Ο繝ｼ繧ｲ繝ｼ繧ｸ繝舌・
var _draw_gauge_bg: ColorRect = null       # 繝峨Ο繝ｼ繧ｲ繝ｼ繧ｸ閭梧勹
var _draw_gauge_label: Label = null        # 繝峨Ο繝ｼ繧ｲ繝ｼ繧ｸ繧ｵ繝悶ユ繧ｭ繧ｹ繝・
var _reload_gauge_bar: ColorRect = null    # リロードゲージバー（§2.2.3）
var _reload_gauge_bg: ColorRect = null     # リロードゲージ背景（§2.2.3）
var _reload_gauge_label: Label = null      # リロードゲージサブテキスト（§2.2.3）
var _force_charge_segs: Array = []         # 蠑ｷ蛻ｶ遯∵茶繧ｲ繝ｼ繧ｸ繧ｻ繧ｰ繝｡繝ｳ繝暗・0
var _force_charge_turn_label: Label = null  # N/10 陦ｨ遉ｺ
var _force_charge_warn_label: Label = null  # 遯∵茶貅門ｙ謗ｨ螂ｨ繝ｩ繝吶Ν
var _early_charge_btn: Button = null        # 譌ｩ譛溽ｪ∵茶繝懊ち繝ｳ
var _deck_count_label: Label = null         # DECK 谿区椢謨ｰ
var _discard_count_label: Label = null      # DISCARD 譫壽焚

# v0.2 HEADER 荳頑ｮｵ繧ｹ繝・・繧ｿ繧ｹUI・按ｧ3.3縲慊ｧ3.6・・
var _pop_gauge_bar: ColorRect = null        # 莠ｺ蜿｣繧ｲ繝ｼ繧ｸ繝舌・
var _pop_label: Label = null               # 莠ｺ蜿｣ N/M
var _pop_preview_label: Label = null        # [+3] 繝励Ξ繝薙Η繝ｼ
var _status_sat_label: Label = null        # Sat 0
var _troop_gauge_bar: ColorRect = null     # 蜈ｵ蜉帙ご繝ｼ繧ｸ繝舌・
var _troop_label: Label = null             # 蜈ｵ蜉帶焚蛟､
var _gold_label: Label = null              # 雉・≡ NG
var _status_food_label: Label = null       # 鬟滓侭
var _soldiers_header_label: Label = null
var _units_header_label: Label = null
var _header_detail_popup: PanelContainer = null
var _header_detail_label: Label = null

# v0.2 HEADER 荳区ｮｵ雉・ｺ舌Λ繝吶Ν霎樊嶌
var _res_labels: Dictionary = {}           # key=雉・ｺ仙錐, value=Label

# ﾂｧ2.4.2 驟榊・繝舌・UI
var _alloc_bar_bg: ColorRect = null        # 驟榊・繝舌・閭梧勹
var _alloc_bar_work: ColorRect = null      # 菴懈･ｭ莠ｺ蜿｣驛ｨ蛻・ｼ亥承蛛ｴ・・
var _alloc_handle: ColorRect = null        # 繝峨Λ繝・げ繝上Φ繝峨Ν
var _alloc_label: Label = null             # 遞ｼ蜒康% / 菴懈･ｭN% 陦ｨ遉ｺ
var _alloc_dragging: bool = false          # 繝峨Λ繝・げ荳ｭ繝輔Λ繧ｰ

# 繧ｲ繝ｼ繧ｸ繧｢繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ逕ｨ
var _draw_gauge_blink_timer: float = 0.0
var _force_charge_blink_timer: float = 0.0
var _draw_flash_timer: float = 0.0  # 繝峨Ο繝ｼ逋ｺ蜍慕區繝輔Λ繝・す繝･
var _elapsed_time: float = 0.0      # 蜈ｵ蜉帙ご繝ｼ繧ｸ譏取ｻ・い繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ逕ｨ邏ｯ遨肴凾髢・

const COLOR_PANEL      := Color("#231F1B")
const COLOR_BORDER     := Color("#3C3628")
const COLOR_TEXT       := Color("#DCD2B9")
const COLOR_TEXT_DIM   := Color("#8A8070")
const COLOR_ACCENT_GOLD := Color("#B49448")
const COLOR_WOOD       := Color("#3F6932")
const COLOR_STONE      := Color("#5D5650")
const COLOR_RESIN      := Color("#9A8A3C")
const COLOR_WHEAT      := Color("#A9924F")
# UI莉墓ｧ俶嶌 ﾂｧ1.4 v0.2 譁ｰ隕剰牡螳壽焚
const COLOR_POP        := Color("#5D8FB8")  # 莠ｺ蜿｣繧ｲ繝ｼ繧ｸ髱堤ｳｻ
const COLOR_SAT        := Color("#B89AC7")  # 貅雜ｳ蠎ｦ繝代・繝励Ν邉ｻ・・0.3・・
const COLOR_TROOP      := Color("#B85A3C")  # 蜈ｵ蜉帙ご繝ｼ繧ｸ襍､闌ｶ
const COLOR_GOLD_COIN  := Color("#E0C060")  # 雉・≡繧ｳ繧､繝ｳ・域・繧九＞驥托ｼ・
# 譌｢蟄倡ｶ咏ｶ夊牡
const COLOR_ACCENT_GOLD_BRIGHT := Color("#D4B468")
const COLOR_ORANGE := Color("#C77A2C")
const COLOR_RED := Color("#9C3A2A")
const FOOTER_H := 180.0

func _ready() -> void:
	_game_session = GameSessionScript.new()
	_start_econ_logging()
	_setup_grid()
	_setup_economy()
	_setup_battle()
	var vp := get_viewport().get_visible_rect().size

	_setup_ui(vp)
	_setup_econ_ui()

	# HEADER縺ｮ螳滄圀縺ｮ繝ｬ繝ｳ繝繝ｪ繝ｳ繧ｰ鬮倥＆繧貞叙蠕暦ｼ医ヮ繝ｼ繝峨′繝・Μ繝ｼ縺ｫ霑ｽ蜉縺輔ｌ縺ｦ蛻昴ａ縺ｦ size 縺檎｢ｺ螳夲ｼ・
	await get_tree().process_frame
	var header_h: float = _header.size.y if _header else 56.0
	print("[EconMain] HEADER actual height: %f" % header_h)

	# 逶､髱｢鬮倥ｒ險育ｮ・
	var board_h: float = vp.y - header_h - FOOTER_H

	# FOOTER縺ｮ y菴咲ｽｮ繧貞虚逧・↓險育ｮ励＠縺ｦ險ｭ螳・
	var footer_y: float = header_h + board_h
	if _ui_layer.get_child_count() > 1:
		var footer = _ui_layer.get_child(1)
		footer.position.y = footer_y
		print("[EconMain] FOOTER position.y: %f (HEADER %f + BOARD %f)" % [footer_y, header_h, board_h])

	# grid 繧辿EADER縺ｮ荳九↓驟咲ｽｮ
	_grid.position.y = header_h

	# grid.origin 繧定ｨ育ｮ暦ｼ育乢髱｢蜀・〒縺ｮ繧ｻ繝ｳ繧ｿ繝ｪ繝ｳ繧ｰ・・
	var hex_w: float = EconGrid.HEX_SIZE * sqrt(3.0)
	var col_count: int = 26
	var grid_full_w := hex_w * float(col_count)
	var grid_full_h := EconGrid.HEX_SIZE * 2.0 * 0.75 * float(EconGrid.ROWS - 1) + EconGrid.HEX_SIZE * 2.0
	_grid.origin = Vector2(
		(vp.x - grid_full_w) * 0.5 + hex_w * 0.5,
		(board_h - grid_full_h) * 0.5 + EconGrid.HEX_SIZE
	)
	_grid.queue_redraw()
	_setup_ai()
	_setup_initial_entities()
	_setup_deck_manager()

func _start_econ_logging() -> void:
	var log_manager := get_node_or_null("/root/LogManager")
	if log_manager == null:
		log_manager = LogManagerScript.new()
		log_manager.name = "LogManager"
	_log_manager = log_manager
	var log_callable := Callable(self, "_add_log")
	if log_manager.has_signal("event_logged") and not log_manager.is_connected("event_logged", log_callable):
		log_manager.connect("event_logged", log_callable)
	if log_manager != null and log_manager.has_method("start_battle"):
		var battle_id := "econ_mvp_%d" % Time.get_unix_time_from_system()
		log_manager.start_battle(battle_id)
		print("[EconMain] LogManager started: %s" % battle_id)

func _setup_grid() -> void:
	_grid = EconGrid.new()
	add_child(_grid)

func _setup_economy() -> void:
	_economy = EconEconomy.new()
	add_child(_economy)
	# v0.2 蛻晄悄蛹厄ｼ按ｧ9.1・・
	_economy.initialize_v0_2()

func _setup_battle() -> void:
	_battle = EconBattle.new()
	_battle.setup(_grid, _economy)
	_battle.log_message.connect(_add_log)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.chest_acquired.connect(_on_chest_acquired)
	add_child(_battle)
	_reward_manager = RewardSystemManagerScript.new()
	add_child(_reward_manager)
	_reward_manager.setup(_game_session, _economy, _battle)
	_reward_manager.immediate_reward_awarded.connect(_on_immediate_reward_awarded)
	_reward_manager.special_milestone_added.connect(_on_special_milestone_added)
	_battle.set_reward_manager(_reward_manager)

func _setup_ai() -> void:
	_ai = EconAI.new()
	_battle.ai = _ai
	add_child(_ai)
	_ai.setup(_grid, _battle)

func _setup_initial_entities() -> void:
	# 謾ｹ險・: 髢句ｹ輔・螳悟・縺ｫ遨ｺ・亥・譛溯ｾｲ譚代・繝上・繝吶せ繧ｿ繝ｼ蜑企勁・・
	print("[EconMain] _setup_initial_entities: BASE only mode (Phase 2 clean start)")
	# 謨ｵBASE・亥崋螳・ row 11 荳ｭ螟ｮ・・
	var enemy_base := EconBuilding.new()
	enemy_base.setup(EconBuilding.BuildingType.BASE, Vector2i(24, 6), false)
	enemy_base.position = _grid.hex_to_pixel(24, 6)
	enemy_base.unit_produced.connect(_ai.on_unit_produced)
	_battle.register_enemy_building(enemy_base)
	# 繝励Ξ繧､繝､繝ｼBASE・・ow 0 荳ｭ螟ｮ・芽・蜍暮・鄂ｮ
	var player_base := EconBuilding.new()
	player_base.setup(EconBuilding.BuildingType.BASE, Vector2i(1, 6), true)
	player_base.position = _grid.hex_to_pixel(1, 6)
	player_base.unit_produced.connect(_battle._on_unit_produced)
	player_base.building_destroyed.connect(func(building: Node):
		_battle._on_building_destroyed(building)
	)
	_battle.register_player_building(player_base)

func _place_initial_village(is_player: bool) -> void:
	# 蟆城ｺｦ縺ｫ髫｣謗･縺吶ｋ繧ｿ繧､繝ｫ縺ｫ霎ｲ譚代ｒ1譽溯・蜍暮・鄂ｮ・・s_built=true・・
	var zone_cols: Array = range(0, 8) if is_player else range(18, 26)
	for col in zone_cols:
		for row in range(_grid.ROWS):
			var cell := Vector2i(col, row)
			# 雉・ｺ舌ち繧､繝ｫ繧・ｱｱ蟯ｳ縺ｯ髯､螟・
			if _grid.get_resource_type(cell) != EconGrid.ResourceType.NONE:
				continue
			if _grid.is_mountain(cell):
				continue
			# 譌｢蟄伜ｻｺ迚ｩ縺ｨ驥崎､・＠縺ｪ縺・
			var occupied := false
			var check_buildings: Array = _battle.player_buildings if is_player else _battle.enemy_buildings
			for b in check_buildings:
				if b.grid_pos == cell:
					occupied = true
					break
			if occupied:
				continue
			# 蟆城ｺｦ髫｣謗･繝√ぉ繝・け
			var has_wheat := false
			for nb in _grid.get_neighbors(col, row):
				if _grid.get_resource_type(nb) == EconGrid.ResourceType.WHEAT:
					has_wheat = true
					break
			if not has_wheat:
				continue
			# 驟咲ｽｮ
			var village := EconBuilding.new()
			village.setup(EconBuilding.BuildingType.VILLAGE, cell, is_player)
			village.position = _grid.hex_to_pixel(cell.x, cell.y)
			village.is_built = true
			if is_player:
				village.unit_produced.connect(_battle._on_unit_produced)
				village.building_destroyed.connect(func(building: Node):
					_battle._on_building_destroyed(building)
				)
				_battle.register_player_building(village)
			else:
				village.unit_produced.connect(_ai.on_unit_produced)
				_battle.register_enemy_building(village)
			_add_log("Initial Village at (%d,%d)" % [cell.x, cell.y])
			return

func _setup_ui(vp: Vector2) -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)

	# === HEADER (y=0, h=56, 謾ｹ險・ 2谿ｵ讒区・) ===
	_setup_header_ui(vp)

	# === FOOTER (y=540, h=180, 謾ｹ險・: HEADER56+BOARD464=520 竊・y=520) ===
	_setup_footer_ui(vp)

	# START繝懊ち繝ｳ・亥・蝗槭・縺ｿ逶､髱｢荳ｭ螟ｮ繝輔Ο繝ｼ繝・ぅ繝ｳ繧ｰ・・
	if not _game_started:
		_create_start_button()

	# Place-on-board hint (逶､髱｢荳翫ヵ繝ｭ繝ｼ繝・ぅ繝ｳ繧ｰ)
	_place_hint_label = Label.new()
	_place_hint_label.text = "笆ｶ place on board"
	_place_hint_label.position = Vector2(vp.x - 180.0, vp.y - 240.0)
	_place_hint_label.add_theme_font_size_override("font_size", 11)
	_place_hint_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_place_hint_label.visible = false
	_ui_layer.add_child(_place_hint_label)

	# === FLOATING LOG (board area, top-left) ===
	_log_label = Label.new()
	_log_label.position = Vector2(vp.x - 270.0, 60)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_log_label.custom_minimum_size = Vector2(260, 0)
	_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_label.add_theme_color_override("font_color", Color(1, 1, 0.75, 0.85))
	_ui_layer.add_child(_log_label)
	_log_label.text = "\n".join(_log_lines)

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
	_setup_sprint9_ui()

func _setup_econ_ui() -> void:
	# EconUI's left debug panel was folded into the header.
	_econ_ui = null

func _setup_sprint9_ui() -> void:
	_milestone_window = MilestoneWindowScript.new()
	_milestone_window.setup(_game_session, _get_sprint9_colors())
	_milestone_window.visible = false
	_ui_layer.add_child(_milestone_window)
	_setup_build_queue_ui()
	_reward_selection_ui = RewardSelectionUIScript.new()
	_reward_selection_ui.setup(_get_sprint9_colors())
	_reward_selection_ui.reward_selected.connect(_on_reward_selected)
	_reward_selection_ui.reward_skipped.connect(_on_reward_skipped)
	_ui_layer.add_child(_reward_selection_ui)
	_land_placement_controller = LandCardPlacementControllerScript.new()
	_land_placement_controller.land_card_placed.connect(_on_land_card_placed)
	_land_placement_controller.placement_failed.connect(_on_land_card_placement_failed)
	add_child(_land_placement_controller)

func _setup_build_queue_ui() -> void:
	_build_queue_ui = BuildQueueUIScript.new()
	_build_queue_ui.setup(_battle, _economy)
	_build_queue_ui.instant_build_requested.connect(_on_build_queue_instant_build_requested)
	_build_queue_ui.cancel_requested.connect(_on_build_queue_cancel_requested)
	_build_queue_ui.reorder_requested.connect(_on_build_queue_reorder_requested)
	_ui_layer.add_child(_build_queue_ui)

func _get_sprint9_colors() -> Dictionary:
	return {
		"bg": COLOR_PANEL.darkened(0.35),
		"panel": COLOR_PANEL,
		"border": COLOR_BORDER,
		"text": COLOR_TEXT,
		"text_dim": COLOR_TEXT_DIM,
		"accent": COLOR_ACCENT_GOLD,
		"wood": COLOR_WOOD,
		"pop": COLOR_POP,
		"sat": COLOR_SAT,
		"red": COLOR_RED,
	}

func _setup_header_ui(vp: Vector2) -> void:
	# 謾ｹ險・: HEADER (y=0, h=56) 2谿ｵ讒区・・亥推谿ｵ28px・・
	var header := PanelContainer.new()
	header.position = Vector2.ZERO
	header.custom_minimum_size = Vector2(vp.x, 56)
	_ui_layer.add_child(header)
	_header = header  # 蜿ら・繧剃ｿ晄戟・・ready 縺ｧ size.y 蜿門ｾ礼畑・・
	var hdr_vbox := VBoxContainer.new()
	hdr_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hdr_vbox.add_theme_constant_override("separation", 0)
	header.add_child(hdr_vbox)

	# --- 荳頑ｮｵ (y=0, h=28): POP / TROOP / GOLD / FOOD ---
	var row1 := HBoxContainer.new()
	row1.custom_minimum_size = Vector2(0, 28)
	row1.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row1.add_theme_constant_override("separation", 4)
	hdr_vbox.add_child(row1)

	# POP (x=8, w=130, h=28)
	_setup_pop_header(row1)

	# TROOP (x=146, w=130, h=28)
	_setup_troop_header(row1)

	# GOLD (x=292, w=110, h=28)
	_setup_gold_header(row1)

	# FOOD (x=410, w=90, h=28)
	var food_hbox := HBoxContainer.new()
	food_hbox.custom_minimum_size = Vector2(90, 28)
	food_hbox.add_theme_constant_override("separation", 2)
	row1.add_child(food_hbox)
	_register_header_detail_target(food_hbox, "food")
	var food_icon := Label.new()
	food_icon.text = "Fd"
	food_icon.add_theme_font_size_override("font_size", 10)
	food_icon.add_theme_color_override("font_color", COLOR_WHEAT)
	food_hbox.add_child(food_icon)
	_status_food_label = Label.new()
	_status_food_label.text = "30"
	_status_food_label.add_theme_font_size_override("font_size", 11)
	_status_food_label.add_theme_color_override("font_color", COLOR_WHEAT)
	food_hbox.add_child(_status_food_label)

	_soldiers_header_label = _make_header_metric("蜈ｵ0", COLOR_TROOP)
	row1.add_child(_soldiers_header_label)
	_register_header_detail_target(_soldiers_header_label, "soldiers")

	_units_header_label = _make_header_metric("U0", COLOR_TEXT)
	row1.add_child(_units_header_label)
	_register_header_detail_target(_units_header_label, "units")

	# 蜿ｳ遶ｯ繧ｹ繝・・繧ｿ繧ｹ繝ｩ繝吶Ν・・tart遲峨・荳譎ゅΛ繝吶Ν・・
	var ctrl_spacer := Control.new()
	ctrl_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(ctrl_spacer)
	_status_label = Label.new()
	_status_label.text = "Setup"
	_status_label.add_theme_font_size_override("font_size", 9)
	_status_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	row1.add_child(_status_label)

	# --- 荳区ｮｵ (y=28, h=28): 雉・ｺ・ + 貅雜ｳ蠎ｦ + Force Charge 繧ｲ繝ｼ繧ｸ ---
	var row2 := HBoxContainer.new()
	row2.custom_minimum_size = Vector2(0, 28)
	row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row2.add_theme_constant_override("separation", 2)
	hdr_vbox.add_child(row2)

	# 雉・ｺ・遞ｮ (x=8, w=440, h=28)
	var res_keys   := ["wood", "stone", "resin", "wheat", "iron", "cotton"]
	var res_icons  := ["W", "S", "R", "Wh", "I", "C"]
	var res_colors := [COLOR_WOOD, COLOR_STONE, COLOR_RESIN, COLOR_WHEAT, COLOR_STONE, COLOR_TEXT]
	_res_labels = {}
	for ri in range(res_keys.size()):
		var rc := HBoxContainer.new()
		rc.custom_minimum_size = Vector2(72, 0)
		rc.add_theme_constant_override("separation", 2)
		row2.add_child(rc)
		_register_header_detail_target(rc, "resource:%s" % res_keys[ri])
		var ri_lbl := Label.new()
		ri_lbl.text = res_icons[ri]
		ri_lbl.add_theme_font_size_override("font_size", 10)
		ri_lbl.add_theme_color_override("font_color", res_colors[ri])
		rc.add_child(ri_lbl)
		var rv_lbl := Label.new()
		rv_lbl.text = "0"
		rv_lbl.add_theme_font_size_override("font_size", 11)
		rv_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		rc.add_child(rv_lbl)
		_res_labels[res_keys[ri]] = rv_lbl

	# 蛹ｺ蛻・ｊ
	var res_sep := VSeparator.new()
	res_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(res_sep)

	# 貅雜ｳ蠎ｦ (x=456, w=120, h=28)
	_status_sat_label = Label.new()
	_status_sat_label.text = "貅雜ｳ蠎ｦ0(v0.3)"
	_status_sat_label.add_theme_font_size_override("font_size", 10)
	_status_sat_label.add_theme_color_override("font_color", COLOR_SAT)
	_status_sat_label.custom_minimum_size = Vector2(120, 0)
	row2.add_child(_status_sat_label)
	_register_header_detail_target(_status_sat_label, "satisfaction")

	# ﾂｧ2.4.2 驟榊・繝舌・ (遞ｼ蜒坂・竊剃ｽ懈･ｭ)
	_setup_alloc_bar(row2)

	# 蛹ｺ蛻・ｊ
	var fc_sep := VSeparator.new()
	fc_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(fc_sep)

	# Force Charge 繧ｲ繝ｼ繧ｸ (x=584, w=288, h=28) 10蛻・牡蜀・ラ繝・ヨ陦ｨ遉ｺ
	var fc_hbox := HBoxContainer.new()
	fc_hbox.custom_minimum_size = Vector2(288, 0)
	fc_hbox.add_theme_constant_override("separation", 2)
	fc_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(fc_hbox)
	var fc_lbl := Label.new()
	fc_lbl.text = "Force:"
	fc_lbl.add_theme_font_size_override("font_size", 9)
	fc_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	fc_hbox.add_child(fc_lbl)
	_force_charge_segs = []
	for si in range(10):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(22, 18)
		seg.color = COLOR_PANEL
		fc_hbox.add_child(seg)
		_force_charge_segs.append(seg)
	_force_charge_turn_label = Label.new()
	_force_charge_turn_label.text = "0/10"
	_force_charge_turn_label.add_theme_font_size_override("font_size", 9)
	_force_charge_turn_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	fc_hbox.add_child(_force_charge_turn_label)
	_force_charge_warn_label = Label.new()
	_force_charge_warn_label.text = "遯∵茶謗ｨ螂ｨ"
	_force_charge_warn_label.add_theme_font_size_override("font_size", 9)
	_force_charge_warn_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_force_charge_warn_label.visible = false
	fc_hbox.add_child(_force_charge_warn_label)

	# AI雉・ｺ舌Λ繝吶Ν・亥炎髯､貂医∩繝ｻ繝繝溘・螟画焚繧呈ｮ九☆・・
	_ai_resource_label = Label.new()  # 髱櫁｡ｨ遉ｺ繝ｻ_process蜀・・蜿ら・繧ｨ繝ｩ繝ｼ蝗樣∩逕ｨ
	_ai_resource_label.visible = false
	_setup_header_detail_popup()

func _make_header_metric(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(56, 28)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	return label

func _setup_header_detail_popup() -> void:
	_header_detail_popup = PanelContainer.new()
	_header_detail_popup.visible = false
	_header_detail_popup.position = Vector2(8.0, 60.0)
	_header_detail_popup.custom_minimum_size = Vector2(330.0, 160.0)
	_ui_layer.add_child(_header_detail_popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_header_detail_popup.add_child(box)
	_header_detail_label = Label.new()
	_header_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_header_detail_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_header_detail_label)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(func(): _header_detail_popup.visible = false)
	box.add_child(close_button)

func _register_header_detail_target(control: Control, key: String) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_header_detail(key)
	)

func _show_header_detail(key: String) -> void:
	if _header_detail_popup == null or _header_detail_label == null or _economy == null:
		return
	_header_detail_label.text = _build_header_detail_text(key)
	_header_detail_popup.visible = true

func _build_header_detail_text(key: String) -> String:
	if key.begins_with("resource:"):
		var res_key: String = key.get_slice(":", 1)
		return "Resource: %s\nCurrent: %d" % [res_key, int(_economy.resources.get(res_key, 0))]
	match key:
		"population":
			var next_pop: int = _economy.get_next_population_milestone()
			return "Population\nCurrent: %.2fk\nDisplay: %dk\nCap: %d\nMin: %.0fk\nGrowth: %+.3f/sec\nNext: %dk (food %d)" % [
				_economy.population_float,
				_economy.get_display_population(),
				_economy.population_cap,
				_economy.population_min,
				_economy.population_float * _economy.get_population_growth_rate(),
				next_pop,
				_economy.get_population_milestone_food_cost(next_pop),
			]
		"food":
			return "Food\nCurrent: %d\nMaintenance: %d / 5s\nShortage count: %d" % [
				_economy.get_food_value(),
				_economy.get_maintenance_food_cost(),
				_economy.food_shortage_count,
			]
		"satisfaction":
			var b: Dictionary = _economy.get_satisfaction_slope_breakdown()
			return "Satisfaction\nStage: %s\nValue: %.1f%%\nSlope: %+.4f/sec\nBase: %+.4f\nPopulation scale: %+.4f\nPopulation growth: %+.4f\nBuilding: %+.4f\nFood penalty: -%.4f" % [
				_economy.get_satisfaction_stage(),
				_economy.satisfaction_value,
				float(b.get("total", 0.0)),
				float(b.get("base", 0.0)),
				float(b.get("population_scale", 0.0)),
				float(b.get("population_growth", 0.0)),
				float(b.get("building", 0.0)),
				float(b.get("food_shortage_penalty", 0.0)),
			]
		"military":
			return "Power\nCurrent: %d\nRaw: %.2f\nGain modifier: %.2f\nEffect modifier: %.2f" % [
				_economy.get_military_units(),
				_economy.military_power,
				_economy.get_military_gain_modifier(),
				_economy.get_military_effect_modifier(),
			]
		"gold":
			return "Gold\nCurrent: %dG" % _economy.currency
		"soldiers":
			return "Soldiers\nCurrent: %d\nConversion: floor(power / 5)" % _economy.get_soldiers_count()
		"units":
			return "Units\nCurrent hand units: %d" % _economy.get_unit_count()
		_:
			return ""

func _setup_pop_header(parent: Control) -> void:
	# 謾ｹ險・: 荳頑ｮｵ POP (w=130, h=28)
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(130, 28)
	hbox.add_theme_constant_override("separation", 2)
	parent.add_child(hbox)
	_register_header_detail_target(hbox, "population")
	var icon_lbl := Label.new()
	icon_lbl.text = "[P]"
	icon_lbl.add_theme_font_size_override("font_size", 11)
	icon_lbl.add_theme_color_override("font_color", COLOR_POP)
	hbox.add_child(icon_lbl)
	var vb := VBoxContainer.new()
	hbox.add_child(vb)
	var gauge_row := HBoxContainer.new()
	vb.add_child(gauge_row)
	var gauge_bg := ColorRect.new()
	gauge_bg.custom_minimum_size = Vector2(60, 6)
	gauge_bg.color = COLOR_PANEL
	gauge_row.add_child(gauge_bg)
	_pop_gauge_bar = ColorRect.new()
	_pop_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_pop_gauge_bar.size = Vector2(0, 6)
	_pop_gauge_bar.color = COLOR_POP
	gauge_bg.add_child(_pop_gauge_bar)
	_pop_label = Label.new()
	_pop_label.text = "0/50"
	_pop_label.add_theme_font_size_override("font_size", 10)
	_pop_label.add_theme_color_override("font_color", COLOR_TEXT)
	gauge_row.add_child(_pop_label)
	_pop_preview_label = Label.new()
	_pop_preview_label.text = "[+3]"
	_pop_preview_label.add_theme_font_size_override("font_size", 9)
	_pop_preview_label.add_theme_color_override("font_color", COLOR_WOOD)
	_pop_preview_label.visible = false
	vb.add_child(_pop_preview_label)

func _setup_troop_header(parent: Control) -> void:
	# 謾ｹ險・: 荳頑ｮｵ TROOP (w=130, h=28)
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(130, 28)
	hbox.add_theme_constant_override("separation", 2)
	parent.add_child(hbox)
	_register_header_detail_target(hbox, "military")
	var icon_lbl := Label.new()
	icon_lbl.text = "[S]"
	icon_lbl.add_theme_font_size_override("font_size", 11)
	icon_lbl.add_theme_color_override("font_color", COLOR_TROOP)
	hbox.add_child(icon_lbl)
	var vb := VBoxContainer.new()
	hbox.add_child(vb)
	var gauge_row := HBoxContainer.new()
	vb.add_child(gauge_row)
	var gauge_bg := ColorRect.new()
	gauge_bg.custom_minimum_size = Vector2(60, 6)
	gauge_bg.color = COLOR_PANEL
	gauge_row.add_child(gauge_bg)
	_troop_gauge_bar = ColorRect.new()
	_troop_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_troop_gauge_bar.size = Vector2(0, 6)
	_troop_gauge_bar.color = COLOR_TROOP
	gauge_bg.add_child(_troop_gauge_bar)
	_troop_label = Label.new()
	_troop_label.text = "0"
	_troop_label.add_theme_font_size_override("font_size", 10)
	_troop_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	gauge_row.add_child(_troop_label)

func _setup_gold_header(parent: Control) -> void:
	# 謾ｹ險・: 荳頑ｮｵ GOLD (w=110, h=28)
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(110, 28)
	hbox.add_theme_constant_override("separation", 2)
	parent.add_child(hbox)
	_register_header_detail_target(hbox, "gold")
	var icon_lbl := Label.new()
	icon_lbl.text = "[G]"
	icon_lbl.add_theme_font_size_override("font_size", 11)
	icon_lbl.add_theme_color_override("font_color", COLOR_GOLD_COIN)
	hbox.add_child(icon_lbl)
	_gold_label = Label.new()
	_gold_label.text = "100G"
	_gold_label.add_theme_font_size_override("font_size", 12)
	_gold_label.add_theme_color_override("font_color", COLOR_GOLD_COIN)
	hbox.add_child(_gold_label)

func _setup_alloc_bar(parent: Control) -> void:
	# ﾂｧ2.4.2 驟榊・繝舌・ (遞ｼ蜒坂・竊剃ｽ懈･ｭ) w=120, h=28
	# 蟾ｦ蛛ｴ=遞ｼ蜒堺ｺｺ蜿｣(髱・, 蜿ｳ蛛ｴ=菴懈･ｭ莠ｺ蜿｣(邱・, 繝上Φ繝峨Ν=逋ｽ邱・
	var container := HBoxContainer.new()
	container.custom_minimum_size = Vector2(140, 28)
	container.add_theme_constant_override("separation", 2)
	parent.add_child(container)

	var icon_lbl := Label.new()
	icon_lbl.text = "Alloc"
	icon_lbl.add_theme_font_size_override("font_size", 10)
	icon_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	container.add_child(icon_lbl)

	# 繝舌・閭梧勹・医け繝ｪ繝・き繝悶Ν繧ｨ繝ｪ繧｢・・
	_alloc_bar_bg = ColorRect.new()
	_alloc_bar_bg.custom_minimum_size = Vector2(80, 14)
	_alloc_bar_bg.color = COLOR_PANEL
	_alloc_bar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(_alloc_bar_bg)

	# 菴懈･ｭ莠ｺ蜿｣驛ｨ蛻・ｼ亥承縺九ｉ莨ｸ縺ｳ繧具ｼ・
	_alloc_bar_work = ColorRect.new()
	_alloc_bar_work.color = COLOR_WOOD
	_alloc_bar_work.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alloc_bar_bg.add_child(_alloc_bar_work)

	# 繝峨Λ繝・げ繝上Φ繝峨Ν・育ｸｦ邱夲ｼ・
	_alloc_handle = ColorRect.new()
	_alloc_handle.color = COLOR_TEXT
	_alloc_handle.custom_minimum_size = Vector2(2, 14)
	_alloc_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alloc_bar_bg.add_child(_alloc_handle)

	# 陦ｨ遉ｺ繝ｩ繝吶Ν・育ｨｼ蜒・5%/菴懈･ｭ25%・・
	_alloc_label = Label.new()
	_alloc_label.text = "遞ｼ75/菴・5"
	_alloc_label.add_theme_font_size_override("font_size", 9)
	_alloc_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	container.add_child(_alloc_label)

	# 繝槭え繧ｹ繧､繝吶Φ繝域磁邯・
	_alloc_bar_bg.gui_input.connect(_on_alloc_bar_input)

func _setup_pop_card(parent: Control) -> void:
	# 譌ｧ螳溯｣・ｼ域悴菴ｿ逕ｨ繝ｻ莠呈鋤諤ｧ菫晄戟・・
	var card := _make_status_card(200, 36)
	parent.add_child(card)
	var icon_lbl := Label.new()
	icon_lbl.text = "[P]"
	icon_lbl.add_theme_font_size_override("font_size", 16)
	icon_lbl.add_theme_color_override("font_color", COLOR_POP)
	card.add_child(icon_lbl)
	var vb := VBoxContainer.new()
	card.add_child(vb)
	var title_lbl := Label.new()
	title_lbl.text = "POPULATION"
	title_lbl.add_theme_font_size_override("font_size", 9)
	title_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vb.add_child(title_lbl)
	var gauge_row := HBoxContainer.new()
	vb.add_child(gauge_row)
	var gauge_bg := ColorRect.new()
	gauge_bg.custom_minimum_size = Vector2(80, 8)
	gauge_bg.color = COLOR_PANEL
	gauge_row.add_child(gauge_bg)
	_pop_gauge_bar = ColorRect.new()
	_pop_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_pop_gauge_bar.size = Vector2(0, 8)
	_pop_gauge_bar.color = COLOR_POP
	gauge_bg.add_child(_pop_gauge_bar)
	_pop_label = Label.new()
	_pop_label.text = "0/50"
	_pop_label.add_theme_font_size_override("font_size", 10)
	_pop_label.add_theme_color_override("font_color", COLOR_TEXT)
	gauge_row.add_child(_pop_label)
	_pop_preview_label = Label.new()
	_pop_preview_label.text = "[+3]"
	_pop_preview_label.add_theme_font_size_override("font_size", 9)
	_pop_preview_label.add_theme_color_override("font_color", COLOR_WOOD)
	_pop_preview_label.visible = false
	vb.add_child(_pop_preview_label)

func _setup_troop_card(parent: Control) -> void:
	# ﾂｧ3.5 蜈ｵ蜉帙き繝ｼ繝・(w=200, h=36)
	var card := _make_status_card(200, 36)
	parent.add_child(card)
	var icon_lbl := Label.new()
	icon_lbl.text = "[S]"
	icon_lbl.add_theme_font_size_override("font_size", 16)
	icon_lbl.add_theme_color_override("font_color", COLOR_TROOP)
	card.add_child(icon_lbl)
	var vb := VBoxContainer.new()
	card.add_child(vb)
	var title_lbl := Label.new()
	title_lbl.text = "TROOP"
	title_lbl.add_theme_font_size_override("font_size", 9)
	title_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vb.add_child(title_lbl)
	var gauge_row := HBoxContainer.new()
	vb.add_child(gauge_row)
	var gauge_bg := ColorRect.new()
	gauge_bg.custom_minimum_size = Vector2(80, 8)
	gauge_bg.color = COLOR_PANEL
	gauge_row.add_child(gauge_bg)
	_troop_gauge_bar = ColorRect.new()
	_troop_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_troop_gauge_bar.size = Vector2(0, 8)
	_troop_gauge_bar.color = COLOR_TROOP
	gauge_bg.add_child(_troop_gauge_bar)
	_troop_label = Label.new()
	_troop_label.text = "0"
	_troop_label.add_theme_font_size_override("font_size", 10)
	_troop_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	gauge_row.add_child(_troop_label)

func _setup_gold_card(parent: Control) -> void:
	# ﾂｧ3.6 雉・≡繧ｫ繝ｼ繝・(w=200, h=36)
	var card := _make_status_card(200, 36)
	parent.add_child(card)
	var icon_lbl := Label.new()
	icon_lbl.text = "[G]"
	icon_lbl.add_theme_font_size_override("font_size", 16)
	icon_lbl.add_theme_color_override("font_color", COLOR_GOLD_COIN)
	card.add_child(icon_lbl)
	var vb := VBoxContainer.new()
	card.add_child(vb)
	var title_lbl := Label.new()
	title_lbl.text = "GOLD"
	title_lbl.add_theme_font_size_override("font_size", 9)
	title_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vb.add_child(title_lbl)
	_gold_label = Label.new()
	_gold_label.text = "100G"
	_gold_label.add_theme_font_size_override("font_size", 12)
	_gold_label.add_theme_color_override("font_color", COLOR_GOLD_COIN)
	vb.add_child(_gold_label)

func _make_status_card(w: int, h: int) -> HBoxContainer:
	# ﾂｧ3.2 豌ｴ蟷ｳ繧ｫ繝ｼ繝牙梛繧ｹ繝・・繧ｿ繧ｹ繝代ロ繝ｫ蜈ｱ騾・
	var card := HBoxContainer.new()
	card.custom_minimum_size = Vector2(w, h)
	card.add_theme_constant_override("separation", 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(4)
	return card

func _setup_footer_ui(vp: Vector2) -> void:
	# 謾ｹ險・: FOOTER
	var footer := PanelContainer.new()
	footer.position = Vector2(0, max(56.0, vp.y - FOOTER_H))
	footer.custom_minimum_size = Vector2(vp.x, FOOTER_H)
	_ui_layer.add_child(footer)
	var ftr_hbox := HBoxContainer.new()
	ftr_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ftr_hbox.add_theme_constant_override("separation", 4)
	footer.add_child(ftr_hbox)

	# 蟾ｦ繝悶Ο繝・け (x=8, w=90): Deck / Discard ﾂｧ4.3 謾ｹ險・
	_setup_deck_discard_block(ftr_hbox)

	var ftr_sep1 := VSeparator.new()
	ftr_sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ftr_hbox.add_child(ftr_sep1)

	# 荳ｭ螟ｮ繝悶Ο繝・け (x=140, w=920): 謇区惆 ﾂｧ4.2
	_setup_hand_center_block(ftr_hbox)

	var ftr_sep2 := VSeparator.new()
	ftr_sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ftr_hbox.add_child(ftr_sep2)

	# 蜿ｳ繝悶Ο繝・け (x=1120, w=160): EVENT SELECT ﾂｧ4.4 謾ｹ險・
	_setup_event_block(ftr_hbox)

func _setup_deck_discard_block(parent: Control) -> void:
	# ﾂｧ4.3 Deck / Discard 蟾ｦ繝悶Ο繝・け 謾ｹ險・: w=90
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(90, 0)
	vb.add_theme_constant_override("separation", 4)
	parent.add_child(vb)

	# DECK
	var deck_panel := PanelContainer.new()
	deck_panel.custom_minimum_size = Vector2(90, 80)
	deck_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dp_sb := StyleBoxFlat.new()
	dp_sb.bg_color = COLOR_PANEL
	dp_sb.border_color = COLOR_BORDER
	dp_sb.set_border_width_all(1)
	deck_panel.add_theme_stylebox_override("panel", dp_sb)
	vb.add_child(deck_panel)
	var dp_vb := VBoxContainer.new()
	dp_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dp_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_panel.add_child(dp_vb)
	var dp_title := Label.new()
	dp_title.text = "DECK"
	dp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dp_title.add_theme_font_size_override("font_size", 10)
	dp_title.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dp_vb.add_child(dp_title)
	var dp_back := ColorRect.new()
	dp_back.custom_minimum_size = Vector2(48, 36)
	dp_back.color = COLOR_PANEL
	dp_vb.add_child(dp_back)
	var dp_back_border := Label.new()
	dp_back_border.text = "[DECK]"
	dp_back_border.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dp_back_border.add_theme_font_size_override("font_size", 9)
	dp_back_border.add_theme_color_override("font_color", COLOR_ACCENT_GOLD)
	dp_vb.add_child(dp_back_border)
	_deck_count_label = Label.new()
	_deck_count_label.text = "谿・3"
	_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_count_label.add_theme_font_size_override("font_size", 14)
	_deck_count_label.add_theme_color_override("font_color", COLOR_TEXT)
	dp_vb.add_child(_deck_count_label)

	# DISCARD
	var disc_panel := PanelContainer.new()
	disc_panel.custom_minimum_size = Vector2(90, 80)
	disc_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dsc_sb := StyleBoxFlat.new()
	dsc_sb.bg_color = COLOR_PANEL
	dsc_sb.border_color = COLOR_BORDER
	dsc_sb.set_border_width_all(1)
	disc_panel.add_theme_stylebox_override("panel", dsc_sb)
	vb.add_child(disc_panel)
	var dsc_vb := VBoxContainer.new()
	dsc_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dsc_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	disc_panel.add_child(dsc_vb)
	var dsc_title := Label.new()
	dsc_title.text = "DISCARD"
	dsc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dsc_title.add_theme_font_size_override("font_size", 10)
	dsc_title.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dsc_vb.add_child(dsc_title)
	var dsc_icon := Label.new()
	dsc_icon.text = "Discard"
	dsc_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dsc_icon.add_theme_font_size_override("font_size", 18)
	dsc_icon.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dsc_vb.add_child(dsc_icon)
	_discard_count_label = Label.new()
	_discard_count_label.text = "0"
	_discard_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_count_label.add_theme_font_size_override("font_size", 10)
	_discard_count_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dsc_vb.add_child(_discard_count_label)

func _setup_hand_center_block(parent: Control) -> void:
	# 謾ｹ險・: 謇区惆荳ｭ螟ｮ繝悶Ο繝・け + Draw繧ｲ繝ｼ繧ｸ蜿ｳ荳企・鄂ｮ
	var center_block := VBoxContainer.new()
	center_block.custom_minimum_size = Vector2(1016, 160)
	center_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_block.add_theme_constant_override("separation", 2)
	parent.add_child(center_block)

	# Draw繧ｲ繝ｼ繧ｸ・・OOTER謇区惆繧ｹ繧ｯ繝ｭ繝ｼ繝ｫ蜿ｳ荳・x=920, y=0, w=196, h=24・・
	var dg_row := HBoxContainer.new()
	dg_row.custom_minimum_size = Vector2(0, 24)
	dg_row.add_theme_constant_override("separation", 4)
	center_block.add_child(dg_row)
	var dg_spacer := Control.new()
	dg_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dg_row.add_child(dg_spacer)
	var dg_lbl := Label.new()
	dg_lbl.text = "Draw"
	dg_lbl.add_theme_font_size_override("font_size", 9)
	dg_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dg_row.add_child(dg_lbl)
	var dg_bar_bg := ColorRect.new()
	dg_bar_bg.custom_minimum_size = Vector2(140, 12)
	dg_bar_bg.color = COLOR_PANEL
	dg_row.add_child(dg_bar_bg)
	_draw_gauge_bg = dg_bar_bg
	_draw_gauge_bar = ColorRect.new()
	_draw_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_draw_gauge_bar.size = Vector2(0, 12)
	_draw_gauge_bar.color = COLOR_ACCENT_GOLD
	dg_bar_bg.add_child(_draw_gauge_bar)
	_draw_gauge_label = Label.new()
	_draw_gauge_label.text = "30s"
	_draw_gauge_label.add_theme_font_size_override("font_size", 9)
	_draw_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dg_row.add_child(_draw_gauge_label)

	# Reloadゲージ（§2.2.3）：Drawゲージ直下
	var rg_row := HBoxContainer.new()
	rg_row.custom_minimum_size = Vector2(0, 20)
	rg_row.add_theme_constant_override("separation", 4)
	center_block.add_child(rg_row)
	var rg_spacer := Control.new()
	rg_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rg_row.add_child(rg_spacer)
	var rg_lbl_static := Label.new()
	rg_lbl_static.text = "Reload"
	rg_lbl_static.add_theme_font_size_override("font_size", 9)
	rg_lbl_static.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	rg_row.add_child(rg_lbl_static)
	var rg_bar_bg := ColorRect.new()
	rg_bar_bg.custom_minimum_size = Vector2(140, 10)
	rg_bar_bg.color = COLOR_PANEL
	rg_row.add_child(rg_bar_bg)
	_reload_gauge_bg = rg_bar_bg
	_reload_gauge_bar = ColorRect.new()
	_reload_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_reload_gauge_bar.size = Vector2(0, 10)
	_reload_gauge_bar.color = COLOR_ACCENT_GOLD
	rg_bar_bg.add_child(_reload_gauge_bar)
	_reload_gauge_label = Label.new()
	_reload_gauge_label.text = ""
	_reload_gauge_label.add_theme_font_size_override("font_size", 9)
	_reload_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	rg_row.add_child(_reload_gauge_label)

	# 遏｢蜊ｰ+繧ｫ繝ｼ繝芽｡・
	var hand_row := HBoxContainer.new()
	hand_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_row.add_theme_constant_override("separation", 4)
	center_block.add_child(hand_row)

	_hand_left_arrow = Button.new()
	_hand_left_arrow.text = "笳"
	_hand_left_arrow.custom_minimum_size = Vector2(40, 64)
	_hand_left_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hand_left_arrow.modulate.a = 0.3
	_hand_left_arrow.pressed.connect(_on_hand_scroll_left)
	hand_row.add_child(_hand_left_arrow)

	_hand_container = HBoxContainer.new()
	_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hand_container.add_theme_constant_override("separation", 8)
	hand_row.add_child(_hand_container)

	_hand_right_arrow = Button.new()
	_hand_right_arrow.text = "笆ｶ"
	_hand_right_arrow.custom_minimum_size = Vector2(40, 64)
	_hand_right_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hand_right_arrow.modulate.a = 0.3
	_hand_right_arrow.pressed.connect(_on_hand_scroll_right)
	hand_row.add_child(_hand_right_arrow)

func _setup_event_block(parent: Control) -> void:
	# ﾂｧ4.4 Event Select 蜿ｳ繝悶Ο繝・け・医Ο繝・け迥ｶ諷具ｼ画隼險・: w=144, 2ﾃ・・・繧ｻ繝ｫ・・
	var ev_panel := PanelContainer.new()
	ev_panel.custom_minimum_size = Vector2(144, 0)
	var ep_sb := StyleBoxFlat.new()
	ep_sb.bg_color = Color(COLOR_PANEL.r * 0.5, COLOR_PANEL.g * 0.5, COLOR_PANEL.b * 0.5, 0.9)
	ep_sb.border_color = COLOR_BORDER
	ep_sb.set_border_width_all(1)
	ev_panel.add_theme_stylebox_override("panel", ep_sb)
	ev_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ev_panel)
	var ev_vb := VBoxContainer.new()
	ev_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ev_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	ev_panel.add_child(ev_vb)
	var ev_title := Label.new()
	ev_title.text = "EVENT"
	ev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_title.add_theme_font_size_override("font_size", 10)
	ev_title.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	ev_vb.add_child(ev_title)
	# 2ﾃ・ 繧ｰ繝ｪ繝・ラ・域隼險・: 4繧ｻ繝ｫ蠕ｩ蜈・ｼ牙推繧ｻ繝ｫ 68ﾃ・8px
	var ev_grid := GridContainer.new()
	ev_grid.columns = 2
	ev_grid.add_theme_constant_override("h_separation", 4)
	ev_grid.add_theme_constant_override("v_separation", 4)
	ev_vb.add_child(ev_grid)
	for _ei in range(4):
		var cell_panel := PanelContainer.new()
		cell_panel.custom_minimum_size = Vector2(68, 68)
		var cp_sb := StyleBoxFlat.new()
		cp_sb.bg_color = Color(COLOR_PANEL.r, COLOR_PANEL.g, COLOR_PANEL.b, 0.5)
		cp_sb.border_color = COLOR_BORDER
		cp_sb.set_border_width_all(1)
		cell_panel.add_theme_stylebox_override("panel", cp_sb)
		cell_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ev_grid.add_child(cell_panel)
		var cell_vb := VBoxContainer.new()
		cell_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cell_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		cell_panel.add_child(cell_vb)
		var lock_lbl := Label.new()
		lock_lbl.text = "[L]"
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_size_override("font_size", 18)
		lock_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		cell_vb.add_child(lock_lbl)
		var locked_lbl := Label.new()
		locked_lbl.text = "LOCKED"
		locked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_lbl.add_theme_font_size_override("font_size", 9)
		locked_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		cell_vb.add_child(locked_lbl)
	var ev_sub := Label.new()
	ev_sub.text = "v0.3 髢区叛"
	ev_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_sub.add_theme_font_size_override("font_size", 8)
	ev_sub.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	ev_vb.add_child(ev_sub)

func _on_hand_scroll_left() -> void:
	if _hand_scroll_offset > 0:
		_hand_scroll_offset -= 1
		_refresh_hand_ui()

func _on_hand_scroll_right() -> void:
	if _battle.deck_manager == null:
		return
	var hand_size: int = int(_battle.deck_manager.hand.size())
	if _hand_scroll_offset + 6 < hand_size:
		_hand_scroll_offset += 1
		_refresh_hand_ui()

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
	tp_label.text = "Priority: Default"
	vbox.add_child(tp_label)
	var tp_hbox := HBoxContainer.new()
	vbox.add_child(tp_hbox)
	var tp_names := ["Default", "Front", "Economy"]
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

func _on_start_pressed() -> void:
	if _is_running:
		return
	if _game_session.initial_difficulty == "":
		_show_initial_difficulty_dialog()
		return
	_start_battle_after_difficulty()

func _start_battle_after_difficulty() -> void:
	if _is_running:
		return
	_is_running = true
	if _reward_manager != null:
		_reward_manager.generate_milestones(_game_session.initial_difficulty)
	if _milestone_window != null:
		_milestone_window.visible = true
		_milestone_window.update_milestones()
	_battle.start()
	_status_label.text = "Battle running..."

func _show_initial_difficulty_dialog() -> void:
	if _difficulty_dialog != null:
		return
	_difficulty_dialog = Control.new()
	_difficulty_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_difficulty_dialog)
	var dim := ColorRect.new()
	dim.color = COLOR_PANEL.darkened(0.35)
	dim.color.a = 0.86
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_difficulty_dialog.add_child(dim)
	var box := VBoxContainer.new()
	box.position = Vector2(440.0, 210.0)
	box.custom_minimum_size = Vector2(400.0, 240.0)
	_difficulty_dialog.add_child(box)
	var title := Label.new()
	title.text = "INITIAL DIFFICULTY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_ACCENT_GOLD)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_add_difficulty_button(row, "low", "菴蚕n+100G\n讌ｵ菴・菴・荳ｭ")
	_add_difficulty_button(row, "normal", "Normal\n+0G\nBalanced")
	_add_difficulty_button(row, "high", "High\n-100G\nHard")

func _add_difficulty_button(parent: Control, difficulty: String, label_text: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(120.0, 120.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.pressed.connect(func():
		_game_session.set_initial_difficulty(difficulty, _economy)
		_add_log("蛻晄悄髮｣譏灘ｺｦ: %s / 騾夊ｲｨ陬懈ｭ｣ %dG" % [difficulty, _game_session.current_battle_gold])
		if _difficulty_dialog != null:
			_difficulty_dialog.queue_free()
			_difficulty_dialog = null
		_start_battle_after_difficulty()
	)
	parent.add_child(btn)


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
	# BASE髟ｷ謚ｼ縺鈴幕蟋九・邨ゆｺ・ｼ亥ｷｦ繧ｯ繝ｪ繝・け・・
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_check := _grid.to_local(get_global_mouse_position())
			var click_cell := _pixel_to_hex(local_check)
			var is_player_base := false
			for b in _battle.player_buildings:
				if b.building_type == EconBuilding.BuildingType.BASE and b.is_alive and b.grid_pos == click_cell:
					is_player_base = true
					break
			if is_player_base:
				_base_longpress_start_time = Time.get_ticks_msec() / 1000.0
				_base_longpress_cell = click_cell
				print("[EconMain] BASE longpress start at (%d,%d)" % [click_cell.x, click_cell.y])
		else:
			# 繝ｪ繝ｪ繝ｼ繧ｹ: 髟ｷ謚ｼ縺励ｒ繝ｪ繧ｻ繝・ヨ・育匱蜍募燕縺ｪ繧我ｽ輔ｂ縺励↑縺・ｼ・
			_base_longpress_start_time = -1.0
	if not event.pressed:
		return
	# 蜿ｳ繧ｯ繝ｪ繝・け: 譌苓ｨｭ鄂ｮ
	if event.button_index == MOUSE_BUTTON_RIGHT:
		var local_pos2: Vector2 = _grid.to_local(get_global_mouse_position())
		var rcell := _pixel_to_hex(local_pos2)
		if rcell == Vector2i(-1, -1):
			return
		# 譌｢蟄倥・譌励′縺ゅｌ縺ｰ蜑企勁・亥酔縺倅ｽ咲ｽｮ繧貞承繧ｯ繝ｪ繝・け・・
		for f in _flags:
			if f.grid_pos == rcell:
				_remove_flag(f)
				return
		# 蟒ｺ迚ｩ繧ｿ繧､繝ｫ縺ｫ縺ｯ險ｭ鄂ｮ荳榊庄
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
	if mouse_y < 56.0 or mouse_y > vp_h - FOOTER_H:
		return
	var local_pos: Vector2 = _grid.to_local(get_global_mouse_position())
	var cell := _pixel_to_hex(local_pos)
	if _land_placement_controller != null and _land_placement_controller.active:
		if cell != Vector2i(-1, -1):
			_land_placement_controller.handle_cell_click(cell)
		return
	# 譌励け繝ｪ繝・け讀懷・・域磁邯壹Δ繝ｼ繝我ｸｭ・・	if _connecting_building != null:
		for f in _flags:
			if f.grid_pos == cell:
				var b := _connecting_building
				if b.connected_flag_id >= 0:
					for old_f in _flags:
						if old_f.flag_id == b.connected_flag_id:
							old_f.remove_building(b.grid_pos)
							old_f.queue_redraw()
				b.connected_flag_id = f.flag_id
				f.add_building(b.grid_pos)
				f.queue_redraw()
				_add_log("Building (%d,%d) 竊・Flag %d" % [b.grid_pos.x, b.grid_pos.y, f.flag_id])
				_connecting_building = null
				return
		_connecting_building = null
		return
	# 蟒ｺ迚ｩ繧ｯ繝ｪ繝・け 竊・謗･邯壼・縺ｨ縺励※驕ｸ謚・
	if cell != Vector2i(-1, -1):
		for b in _battle.player_buildings:
			if b.is_alive and b.grid_pos == cell:
				_connecting_building = b
				_add_log("Select flag to connect (ESC to cancel)")
				return
	# 繧ｬ繝ｼ繝牙ｯｾ雎｡驕ｸ謚槭Δ繝ｼ繝・
	if _guard_select_mode:
		if cell != Vector2i(-1, -1):
			# 蜻ｳ譁ｹ繝ｦ繝九ャ繝医ｒ繧ｯ繝ｪ繝・け
			for u in _battle.player_units:
				if u.is_alive and u.grid_pos == cell and u != _selected_unit:
					_selected_unit.order = EconUnit.OrderType.GUARD
					_selected_unit.guard_target = u
					_add_log("Guard: unit at (%d,%d)" % [cell.x, cell.y])
					_guard_select_mode = false
					return
			# 蜻ｳ譁ｹ蟒ｺ迚ｩ繧偵け繝ｪ繝・け
			for b in _battle.player_buildings:
				if b.is_alive and b.grid_pos == cell:
					_selected_unit.order = EconUnit.OrderType.GUARD
					_selected_unit.guard_target = b
					_add_log("Guard: building at (%d,%d)" % [cell.x, cell.y])
					_guard_select_mode = false
					return
		_guard_select_mode = false
		return
	# 謇区惆繧ｫ繝ｼ繝蛾∈謚槫ｾ後・蟒ｺ險ｭ繝｢繝ｼ繝会ｼ・0.2 hand竊鍛oard 驟咲ｽｮ・・
	if _selected_card_btype != "":
		if cell == Vector2i(-1, -1):
			return
		if not _grid.is_valid_cell(cell.x, cell.y):
			return
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
		_place_building_from_card(cell, _selected_card_btype)
		if _selected_card_btype == "" and _place_hint_label:
			_place_hint_label.visible = false
		return
	# 譛ｪ蟒ｺ險ｭ蟒ｺ迚ｩ縺ｮ繧ｭ繝｣繝ｳ繧ｻ繝ｫ
	for b in _battle.player_buildings:
		if b.grid_pos == cell and not b.is_built:
			_battle.player_buildings.erase(b)
			b.queue_free()
			_add_log("蟒ｺ險ｭ繧ｭ繝｣繝ｳ繧ｻ繝ｫ")
			return
	# 繝ｦ繝九ャ繝磯∈謚・
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
	# 菴輔ｂ縺ｪ縺・ｴ謇繧偵け繝ｪ繝・け 竊・驕ｸ謚櫁ｧ｣髯､
	_deselect_unit()

func _deselect_unit() -> void:
	if _selected_unit != null:
		_selected_unit.is_selected = false
		_selected_unit.queue_redraw()
		_selected_unit = null
	_order_panel.visible = false
	_guard_select_mode = false

func _place_building_from_card(cell: Vector2i, btype_str: String) -> void:
	if _battle.deck_manager == null or _selected_card_idx < 0:
		return
	if _selected_card_idx >= _battle.deck_manager.hand.size():
		_selected_card_idx = -1
		_selected_card_btype = ""
		return
	var card: Dictionary = _battle.deck_manager.hand[_selected_card_idx]
	if not _economy.can_afford_card(card):
		_add_log("Resource insufficient: %s" % card.get("name", "?"))
		return
	var success: bool = _battle.play_card_and_build(_selected_card_idx, cell)
	if not success:
		_add_log("Cannot place: %s" % card.get("name", btype_str))
		return
	_add_log("%s construction started at (%d,%d)" % [card.get("name", btype_str), cell.x, cell.y])
	_selected_card_idx = -1
	_selected_card_btype = ""
	_grid.fill_cells.clear()
	_grid.queue_redraw()

func _on_build_queue_instant_build_requested(building: EconBuilding) -> void:
	if building == null or not is_instance_valid(building) or building.is_built:
		return
	var cost_g := _calc_instant_build_cost(building)
	if cost_g <= 0:
		return
	if _economy.currency < cost_g:
		_add_log("Gold insufficient: instant build needs %dG" % cost_g)
		return
	var build_cost: Dictionary = EconBuilding.BUILD_COSTS.get(int(building.building_type), {})
	if not _economy.can_afford(build_cost):
		building._construction_ready = false
		building.queue_redraw()
		_add_log("雉・ｺ蝉ｸ崎ｶｳ: 蜊ｳ譎ょｻｺ險ｭ荳榊庄")
		return
	_economy.currency -= cost_g
	_economy.spend(build_cost)
	var required: float = float(EconBuilding.REQUIRED_CONSTRUCTION.get(int(building.building_type), 1.0))
	building.build_progress = required
	building.is_built = true
	building._construction_ready = true
	if building.building_type == EconBuilding.BuildingType.HOUSE:
		_economy.population_cap = _economy.calculate_population_cap()
	if _grid != null:
		_grid.reveal_panels_around(building.grid_pos)
	if _battle != null:
		_battle._on_building_constructed(building)
	building.queue_redraw()
	_add_log("Instant build: %dG at (%d,%d)" % [cost_g, building.grid_pos.x, building.grid_pos.y])

func _on_build_queue_cancel_requested(building: EconBuilding) -> void:
	if building == null or not is_instance_valid(building) or building.is_built:
		return
	if _battle != null:
		_battle.player_buildings.erase(building)
	_reindex_construction_queue()
	_add_log("蟒ｺ險ｭ繧ｭ繝｣繝ｳ繧ｻ繝ｫ: (%d,%d)" % [building.grid_pos.x, building.grid_pos.y])
	building.queue_free()

func _on_build_queue_reorder_requested(building: EconBuilding, target_index: int) -> void:
	if building == null or not is_instance_valid(building):
		return
	var queue := _get_unbuilt_player_buildings_sorted()
	if queue.is_empty():
		return
	queue.erase(building)
	queue.insert(clampi(target_index - 1, 0, queue.size()), building)
	for i in range(queue.size()):
		queue[i].set_meta("construction_order", i + 1)
	_next_construction_order = queue.size() + 1
	_add_log("蟒ｺ險ｭ繧ｭ繝･繝ｼ螟画峩: %d逡ｪ縺ｸ" % target_index)

func _calc_instant_build_cost(building: EconBuilding) -> int:
	var required: float = float(EconBuilding.REQUIRED_CONSTRUCTION.get(int(building.building_type), 1.0))
	if required <= 0.0:
		return 0
	var remaining_labor: float = maxf(0.0, required - building.build_progress)
	if remaining_labor <= 0.0:
		return 0
	return int(ceil(remaining_labor * float(LABOR_COST_PER_UNIT)))

func _get_unbuilt_player_buildings_sorted() -> Array:
	if _battle == null:
		return []
	var queue: Array = _battle.player_buildings.filter(func(b):
		return b is EconBuilding and b.is_alive and not b.is_built
	)
	queue.sort_custom(func(a: EconBuilding, b: EconBuilding) -> bool:
		var a_order: int = int(a.get_meta("construction_order")) if a.has_meta("construction_order") else 0
		var b_order: int = int(b.get_meta("construction_order")) if b.has_meta("construction_order") else 0
		return a_order < b_order
	)
	return queue

func _reindex_construction_queue() -> void:
	var queue := _get_unbuilt_player_buildings_sorted()
	for i in range(queue.size()):
		queue[i].set_meta("construction_order", i + 1)
	_next_construction_order = queue.size() + 1

func _on_battle_ended(player_won: bool) -> void:
	_status_label.text = "Victory!" if player_won else "Defeat..."
	_add_log("Victory!" if player_won else "Defeat!")
	if _milestone_window != null:
		_milestone_window.visible = false
	_build_reward_queue()
	if player_won and not _pending_reward_queue.is_empty():
		_show_next_reward()
		return
	_show_restart_button()

func _show_restart_button() -> void:
	var btn_restart := Button.new()
	btn_restart.text = "Restart"
	btn_restart.custom_minimum_size = Vector2(120, 40)
	btn_restart.pressed.connect(func(): get_tree().reload_current_scene())
	_ui_layer.add_child(btn_restart)
	var vp := get_viewport().get_visible_rect().size
	btn_restart.position = Vector2(vp.x * 0.5 - 60.0, vp.y * 0.5 - 20.0)

func _build_reward_queue() -> void:
	_pending_reward_queue.clear()
	for raw in _game_session.achieved_milestones:
		var record: Dictionary = raw
		var is_special := bool(record.get("is_special", false))
		var difficulty := str(record.get("difficulty", ""))
		if not is_special and difficulty == "normal":
			continue
		_pending_reward_queue.append(record.duplicate(true))

func _show_next_reward() -> void:
	if _pending_reward_queue.is_empty():
		_show_restart_button()
		return
	var record: Dictionary = _pending_reward_queue.pop_front()
	var difficulty := "special" if bool(record.get("is_special", false)) else str(record.get("difficulty", "low"))
	var options: Array = _reward_manager.offer_reward(str(record.get("system", "")), difficulty)
	if options.is_empty():
		_show_next_reward()
		return
	_reward_selection_ui.show_rewards(options, record)

func _on_reward_selected(card: Dictionary) -> void:
	var context: Dictionary = _reward_selection_ui.current_context.duplicate(true)
	context["selected"] = str(card.get("card_id", card.get("id", "")))
	context["options"] = _reward_selection_ui.current_options.duplicate(true)
	context["skipped"] = false
	_reward_manager.record_reward_selection(context)
	_add_log("蝣ｱ驟ｬ迯ｲ蠕・ %s" % str(card.get("name", card.get("card_id", "?"))))
	if str(card.get("card_type", "")) == "land_card":
		if _land_placement_controller.begin(card, _grid, _battle):
			_add_log("蝨溷慍繧ｫ繝ｼ繝蛾・鄂ｮ繝｢繝ｼ繝・ 髫｣謗･譛ｪ蟒ｺ險ｭ蝨溷慍繧偵け繝ｪ繝・け")
			return
	_show_next_reward()

func _on_reward_skipped(context: Dictionary) -> void:
	var record := context.duplicate(true)
	record["selected"] = "SKIP"
	record["skipped"] = true
	_reward_manager.record_reward_selection(record)
	_add_log("蝣ｱ驟ｬ繧ｹ繧ｭ繝・・")
	_show_next_reward()

func _on_land_card_placed(card: Dictionary, pos: Vector2i) -> void:
	_game_session.record_land_card(card, pos)
	_add_log("蝨溷慍繧ｫ繝ｼ繝蛾・鄂ｮ螳御ｺ・(%d,%d)" % [pos.x, pos.y])
	_show_next_reward()

func _on_land_card_placement_failed(card: Dictionary) -> void:
	_add_log("驟咲ｽｮ蜿ｯ閭ｽ縺ｪ蝨溷慍縺後↑縺・◆繧∝悄蝨ｰ繧ｫ繝ｼ繝蛾∈謚樔ｸ榊庄")
	_show_next_reward()

func _on_immediate_reward_awarded(system: String, reward: Dictionary) -> void:
	_show_reward_telop("%s MILESTONE" % system.to_upper(), str(reward.get("label", "")))

func _on_special_milestone_added(record: Dictionary) -> void:
	if _milestone_window != null:
		_milestone_window.notify_special_added()

func _on_chest_acquired(result: Dictionary) -> void:
	var reward: Dictionary = result.get("reward", {})
	_show_reward_telop("CHEST OBTAINED", "%s\n+1 SPECIAL MILESTONE" % str(reward.get("label", "reward")))
	if _milestone_window != null:
		_milestone_window.notify_special_added()

func _show_reward_telop(title_text: String, body_text: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 90)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.bg_color.a = 0.85
	sb.border_color = COLOR_ACCENT_GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	_ui_layer.add_child(panel)
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2(vp.x * 0.5 - 170.0, 100.0)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", COLOR_ACCENT_GOLD)
	box.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(body)
	var tween := create_tween()
	panel.modulate.a = 0.0
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(panel.queue_free)

func _add_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	if _log_label == null:
		return
	_log_label.text = "\n".join(_log_lines)

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
	# #7: 謌ｦ髣倥Θ繝九ャ繝医・縺ｿ繧ｫ繧ｦ繝ｳ繝茨ｼ医ワ繝ｼ繝吶せ繧ｿ繝ｼ髯､螟厄ｼ・
	var unit_count: int = _battle.player_units.filter(func(u): return u.is_alive).size()
	var income: float = village_count * 0.4
	var cost: float = unit_count * 0.1
	var net: float = income - cost
	var rating: String
	var color: Color
	if net >= 0.2:
		rating = "OK"
		color = Color.LIME_GREEN
	elif net >= 0.0:
		rating = "笆ｳ 驕ｩ豁｣"
		color = Color.YELLOW
	else:
		rating = "笞 荳崎ｶｳ"
		color = Color(1.0, 0.35, 0.35)
	var text: String = "Farm: %s  %+.1f/s\n(village%d, unit%d)" % [rating, net, village_count, unit_count]
	return {"text": text, "color": color}

func _process(delta: float) -> void:
	_elapsed_time += delta
	# BASE髟ｷ謚ｼ縺怜愛螳夲ｼ・.6遘偵〒荳譁臥ｪ∵茶・・
	if _base_longpress_start_time >= 0.0:
		var elapsed := Time.get_ticks_msec() / 1000.0 - _base_longpress_start_time
		var progress := clampf(elapsed / BASE_LONGPRESS_THRESHOLD, 0.0, 1.0)
		_grid.base_longpress_cell = _base_longpress_cell
		_grid.base_longpress_progress = progress
		if elapsed >= BASE_LONGPRESS_THRESHOLD:
			_trigger_unified_charge()
			_base_longpress_start_time = -1.0
			_grid.base_longpress_cell = Vector2i(-1, -1)
			_grid.base_longpress_progress = 0.0
		# 繝ｪ繝ｳ繧ｰ騾ｲ謐玲緒逕ｻ譖ｴ譁ｰ
		_grid.queue_redraw()
	else:
		if _grid.base_longpress_cell != Vector2i(-1, -1):
			_grid.base_longpress_cell = Vector2i(-1, -1)
			_grid.base_longpress_progress = 0.0
			_grid.queue_redraw()
	_battle.update(delta)
	if _battle.deck_manager != null:
		_economy.unit_count = int(_battle.deck_manager.hand.size())
	# v0.2 雉・ｺ舌Λ繝吶Ν霎樊嶌譖ｴ譁ｰ・按ｧ3.7・・
	for res_key in _res_labels.keys():
		var lbl: Label = _res_labels[res_key]
		lbl.text = "%d" % _economy.resources.get(res_key, 0)
	if _ai != null and _ai.economy != null:
		var eco := _ai.economy
		_ai_resource_label.text = "W:%d St:%d Re:%d Wh:%d" % [eco.wood, eco.stone, eco.resin, eco.wheat]
	# v0.2 highlight譖ｴ譁ｰ・亥ｻｺ險ｭ繝｢繝ｼ繝峨↑縺・竊・鬆伜悄陦ｨ遉ｺ縺ｮ縺ｿ・・
	_update_territory_highlight()
	_update_buildable_highlight()
	# v0.2 繧ｹ繝・・繧ｿ繧ｹUI譖ｴ譁ｰ・按ｧ5.1・・
	_update_status_ui()
	# 繝峨Ο繝ｼ繝ｻ繧ｲ繝ｼ繧ｸ繝ｻ莠ｺ蜿｣UI譖ｴ譁ｰ・按ｧ5 pull蝙具ｼ・
	_update_draw_gauge_ui(delta)
	_update_reload_gauge_ui()
	_update_force_charge_gauge_ui(delta)
	_update_population_ui()
	_update_alloc_bar_ui()
	if _milestone_window != null and _milestone_window.visible:
		_milestone_window.update_milestones()

func _update_territory_highlight() -> void:
	# v0.2: 蟒ｺ險ｭ繝｢繝ｼ繝牙ｻ・ｭ｢縺ｫ繧医ｊ fill_cells 縺ｯ蟶ｸ縺ｫ遨ｺ縲る伜悄陦ｨ遉ｺ縺ｮ縺ｿ譖ｴ譁ｰ縲・
	_grid.highlight_cells.clear()
	_grid.fill_cells.clear()
	_grid.resource_highlight_type = EconGrid.ResourceType.NONE
	# highlight_cells: 蟒ｺ險ｭ貂医∩player_buildings縺九ｉ蜊雁ｾ・縺ｮ蜥碁寔蜷・
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
	# enemy_territory_cells: 蟒ｺ險ｭ貂医∩enemy_buildings縺九ｉ蜊雁ｾ・縺ｮ蜥碁寔蜷・
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
	_grid.queue_redraw()

func _update_buildable_highlight() -> void:
	if _selected_card_idx < 0 or _battle.deck_manager == null:
		return
	if _selected_card_idx >= _battle.deck_manager.hand.size():
		return
	var card: Dictionary = _battle.deck_manager.hand[_selected_card_idx]
	var options: Array = _grid.get_buildable_cells_for_card(card, _get_own_building_positions(), _get_occupied_positions())
	for cell in options:
		_grid.fill_cells[cell] = true

func _get_own_building_positions() -> Array:
	var positions: Array = []
	for b in _battle.player_buildings:
		if b.is_alive and b.is_built:
			positions.append(b.grid_pos)
	return positions

func _get_occupied_positions() -> Array:
	var positions: Array = []
	for b in _battle.player_buildings:
		if b.is_alive:
			positions.append(b.grid_pos)
	for h in _battle.player_harvesters:
		if h.is_alive:
			positions.append(h.grid_pos)
	return positions

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

func _get_player_building_positions(include_unbuilt: bool = false) -> Array:
	var positions: Array = []
	for b in _battle.player_buildings:
		if not b.is_alive:
			continue
		if not include_unbuilt and not b.is_built:
			continue
		positions.append(b.grid_pos)
	return positions

func _show_land_card_reward() -> void:
	if _land_reward_panel != null:
		_land_reward_panel.queue_free()
		_land_reward_panel = null
	var own_positions: Array = _get_player_building_positions(false)
	var occupied_positions: Array = _get_player_building_positions(true)
	var placement_options: Array = _grid.get_land_card_placement_options(own_positions, occupied_positions)
	if placement_options.is_empty():
		_add_log("No land placement target")
		print("[LandCardReward] no placement options")
		return

	var cards: Array = generate_land_card_candidates()
	var option_count: int = mini(3, mini(cards.size(), placement_options.size()))
	var panel := PanelContainer.new()
	_land_reward_panel = panel
	panel.custom_minimum_size = Vector2(620, 230)
	_ui_layer.add_child(panel)
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2(vp.x * 0.5 - 310.0, vp.y * 0.5 - 150.0)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var title := Label.new()
	title.text = "繝ｩ繝ｳ繝峨き繝ｼ繝蛾・鄂ｮ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)
	var note := Label.new()
	note.text = "Enemy defeated. Expand land after battle."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(note)

	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	root.add_child(choices)
	for i in range(option_count):
		choices.add_child(_create_land_reward_choice(cards[i], placement_options[i], own_positions, occupied_positions))

	var cancel_btn := Button.new()
	cancel_btn.text = "繧ｭ繝｣繝ｳ繧ｻ繝ｫ"
	cancel_btn.custom_minimum_size = Vector2(120, 32)
	cancel_btn.pressed.connect(func():
		_add_log("蝨溷慍繧ｫ繝ｼ繝蛾・鄂ｮ繧偵せ繧ｭ繝・・")
		if _land_reward_panel != null:
			_land_reward_panel.queue_free()
			_land_reward_panel = null
	)
	root.add_child(cancel_btn)
	print("[LandCardReward] shown: cards=%d placement_options=%d" % [cards.size(), placement_options.size()])

func _create_land_reward_choice(card: Dictionary, pos: Vector2i, own_positions: Array, occupied_positions: Array) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(190, 122)
	btn.text = "%s\n%s\n%s\n驟咲ｽｮ" % [
		_format_land_card_summary(card),
		_format_land_panel_summary(pos),
		"蠎ｧ讓・(%d,%d)" % [pos.x, pos.y],
	]
	btn.pressed.connect(func():
		_place_selected_land_card(card, pos, own_positions, occupied_positions)
	)
	return btn

func _format_land_card_summary(card: Dictionary) -> String:
	var panel_data: Dictionary = card.get("panel_data", {})
	var resources: Dictionary = panel_data.get("resources", {})
	return "繧ｫ繝ｼ繝・ %s\n蜉ｹ譫懆ｳ・ｺ・ %s" % [str(card.get("land_subtype", "")), str(resources)]

func _format_land_panel_summary(pos: Vector2i) -> String:
	var panel: Dictionary = _grid.get_panel_at(pos)
	var resources: Dictionary = panel.get("resources", {})
	return "譌｢蟄・ %s\n蝨ｰ蠖｢: %s / 繧ｿ繧ｰ: %s" % [
		str(resources),
		str(panel.get("terrain_type", "grassland")),
		str(panel.get("special_tag", "none")),
	]

func _place_selected_land_card(card: Dictionary, pos: Vector2i, own_positions: Array, occupied_positions: Array) -> void:
	var placed: bool = _grid.place_land_card(card, pos, own_positions, occupied_positions)
	if not placed:
		_add_log("蝨溷慍繧ｫ繝ｼ繝蛾・鄂ｮ螟ｱ謨・(%d,%d)" % [pos.x, pos.y])
		return
	_grid.reveal_panels_around(pos, 3)
	_grid.queue_redraw()
	_add_log("蝨溷慍繧ｫ繝ｼ繝蛾・鄂ｮ (%d,%d)" % [pos.x, pos.y])
	if _land_reward_panel != null:
		_land_reward_panel.queue_free()
		_land_reward_panel = null

func _remove_flag(flag: EconRallyFlag) -> void:
	# 謗･邯壹＠縺ｦ縺・◆蟒ｺ迚ｩ縺ｮ connected_flag_id 繧偵Μ繧ｻ繝・ヨ
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

func generate_land_card_candidates() -> Array:
	var candidates: Array = []
	var available_types: Array = ["high_single", "high_composite", "special_tag", "terrain"]
	available_types.shuffle()
	for i in range(3):
		var subtype: String = str(available_types[i])
		var card: Dictionary = _generate_land_card(subtype)
		candidates.append(card)
	print("[LandCardReward] generated")
	if _log_manager != null and _log_manager.has_method("log_event"):
		var subtypes: Array = []
		for candidate_raw in candidates:
			var candidate: Dictionary = candidate_raw
			subtypes.append(str(candidate.get("land_subtype", "")))
		_log_manager.log_event({
			"type": "LAND_CARD_REWARD",
			"time": _elapsed_time,
			"count": candidates.size(),
			"subtypes": subtypes,
		})
	return candidates

func _generate_land_card(subtype: String) -> Dictionary:
	var card: Dictionary = {"card_type": "land", "land_subtype": subtype, "panel_data": {}}
	match subtype:
		"high_single":
			var resource_type: String = str(["wood", "stone", "wheat"].pick_random())
			card["panel_data"] = {"resources": {resource_type: 6}, "terrain": "grassland"}
		"high_composite":
			var composite: Dictionary = [{"wheat": 3, "cotton": 3}, {"wood": 3, "resin": 3}].pick_random()
			card["panel_data"] = {"resources": composite, "terrain": "grassland"}
		"special_tag":
			card["panel_data"] = {"resources": {"wheat": 2, "cotton": 2}, "special_tag": "spice", "terrain": "grassland"}
		"terrain":
			var terrain: String = str(["grassland", "desert", "wasteland", "wetland"].pick_random())
			card["panel_data"] = {"resources": {"wood": 2, "stone": 2}, "terrain": terrain}
		_:
			card["panel_data"] = {"resources": {"wood": 2}, "terrain": "grassland"}
	return card

# ---- 繝峨Ο繝ｼ繝ｻ謇区惆繝ｻ繧ｲ繝ｼ繧ｸ繧ｷ繧ｹ繝・Β・按ｧ5 UI隕∽ｻｶ・・----

func _build_initial_deck(all_cards_array: Array) -> Array:
	var card_by_id: Dictionary = {}
	for card in all_cards_array:
		if not (card is Dictionary):
			continue
		var card_id: String = str(card.get("id", ""))
		if card_id == "":
			continue
		card_by_id[card_id] = card

	var deck: Array = []
	for entry in INITIAL_DECK:
		var card_id: String = str(entry.get("id", ""))
		var count: int = int(entry.get("count", 0))
		if not card_by_id.has(card_id):
			push_warning("[EconMain] INITIAL_DECK missing card id: %s" % card_id)
			continue
		for _i in range(count):
			deck.append(card_by_id[card_id].duplicate(true))
	return deck

func _setup_deck_manager() -> void:
	# ﾂｧ7.1 cards_econ.json 縺九ｉ繝・ャ繧ｭ繧偵Ο繝ｼ繝・
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
	var initial_deck: Array = _build_initial_deck(parsed["cards"])
	# 繝・ャ繧ｭ繧ｷ繝｣繝・ヵ繝ｫ縺ｯ v0.1 縺ｧ縺ｯ陦後ｏ縺ｪ縺・ｼ・ISS・・
	_battle.setup_deck(initial_deck, _on_card_drawn)
	print("[EconMain] _setup_deck_manager: %d cards loaded" % initial_deck.size())

func _on_card_drawn(card: Dictionary) -> void:
	# 繝峨Ο繝ｼ譎ゅ・UI譖ｴ譁ｰ・医き繝ｼ繝蛾｣帶擂Tween襍ｷ轤ｹ・・
	print("[EconMain] _on_card_drawn: %s" % card.get("name", "?"))
	_refresh_hand_ui()
	# 繝峨Ο繝ｼ逋ｺ蜍慕區繝輔Λ繝・す繝･・按ｧ5.1.1 繝峨Ο繝ｼ逋ｺ蜍慕椪髢難ｼ・
	_draw_flash_timer = 0.1

func _refresh_hand_ui() -> void:
	# 謇区惆UI繧貞・讒狗ｯ会ｼ按ｧ4.2 繧ｹ繧ｯ繝ｭ繝ｼ繝ｫ蟇ｾ蠢懊・6譫夊｡ｨ遉ｺ・・
	if _hand_container == null:
		return
	for child in _hand_container.get_children():
		child.queue_free()
	if _battle.deck_manager == null:
		return
	var hand_size: int = int(_battle.deck_manager.hand.size())
	# 繧ｹ繧ｯ繝ｭ繝ｼ繝ｫ繧ｪ繝輔そ繝・ヨ遽・峇陬懈ｭ｣
	_hand_scroll_offset = clampi(_hand_scroll_offset, 0, max(0, hand_size - 5))
	# 6譫夊｡ｨ遉ｺ・・ffset縲徙ffset+5・・
	var display_count: int = mini(5, hand_size - _hand_scroll_offset)
	for i in range(display_count):
		var actual_idx: int = _hand_scroll_offset + i
		var card_data: Dictionary = _battle.deck_manager.hand[actual_idx]
		var card_node := _create_hand_card_node(card_data, actual_idx)
		_hand_container.add_child(card_node)
	# 遏｢蜊ｰ enabled 譖ｴ譁ｰ ﾂｧ4.2.4
	if _hand_left_arrow != null:
		_hand_left_arrow.modulate.a = 1.0 if _hand_scroll_offset > 0 else 0.3
	if _hand_right_arrow != null:
		_hand_right_arrow.modulate.a = 1.0 if (_hand_scroll_offset + 5 < hand_size) else 0.3
	# 繝・ャ繧ｭ繝ｻ謐ｨ縺ｦ譛ｭ陦ｨ遉ｺ譖ｴ譁ｰ ﾂｧ4.3
	if _deck_count_label != null:
		_deck_count_label.text = "残%d" % int(_battle.deck_manager.deck.size())
	if _discard_count_label != null:
		_discard_count_label.text = "%d" % int(_battle.deck_manager.discard_pile.size())

func _create_hand_card_node(card_data: Dictionary, card_idx: int) -> Control:
	# ﾂｧ4.2.1 謇区惆繧ｫ繝ｼ繝・譫壹・繝弱・繝峨ｒ逕滓・・・0ﾃ・6px繝ｻ謾ｹ險・ 邵ｮ蟆擾ｼ・
	var card_btn := Button.new()
	card_btn.custom_minimum_size = Vector2(96, 140)
	card_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# 迥ｶ諷句愛螳夲ｼ按ｧ5.3.2 6迥ｶ諷九・蜆ｪ蜈磯・ｽ阪メ繧ｧ繝・け・・
	var state := _get_card_state(card_data)

	# 繧ｹ繧ｿ繧､繝ｫ驕ｩ逕ｨ
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

	# 繧ｫ繝ｼ繝牙・繝ｬ繧､繧｢繧ｦ繝茨ｼ按ｧ5.3.1・・
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	card_btn.add_child(vbox)

	var icon_lbl := Label.new()
	icon_lbl.text = _get_card_icon(card_data.get("building_type", ""))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	icon_lbl.custom_minimum_size = Vector2(0, 44)  # ﾂｧ5.2.2 繧ｵ繝繝・4px
	vbox.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = card_data.get("name", "?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)  # ﾂｧ5.2.2 10px螟ｪ蟄・
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(name_lbl)

	var pop_lbl := Label.new()
	pop_lbl.text = "莠ｺ蜿｣:%d" % card_data.get("population_required", 0)
	pop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop_lbl.add_theme_font_size_override("font_size", 10)
	pop_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vbox.add_child(pop_lbl)

	var cost_raw = card_data.get("cost")
	var cost: Dictionary = cost_raw if cost_raw is Dictionary else {}
	var cost_parts: Array = []
	if cost.get("wood", 0) > 0: cost_parts.append("譛ｨ%d" % cost["wood"])
	if cost.get("stone", 0) > 0: cost_parts.append("遏ｳ%d" % cost["stone"])
	if cost.get("resin", 0) > 0: cost_parts.append("讓ｹ%d" % cost["resin"])
	if cost.get("wheat", 0) > 0: cost_parts.append("小%d" % cost["wheat"])
	if cost.get("iron", 0) > 0: cost_parts.append("鉄%d" % cost["iron"])
	if cost.get("cotton", 0) > 0: cost_parts.append("邯ｿ%d" % cost["cotton"])
	var cost_lbl := Label.new()
	cost_lbl.text = " ".join(cost_parts) if not cost_parts.is_empty() else "Free"
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

	# 繧ｯ繝ｪ繝・け縺ｧ蟒ｺ險ｭ繝｢繝ｼ繝芽ｵｷ蜍包ｼ・0.2 ﾂｧ4.2 謇区惆竊堤乢髱｢驟咲ｽｮ・・
	var captured_card: Dictionary = card_data
	card_btn.pressed.connect(func():
		if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
			_add_log("遯∵茶逋ｺ蜍穂ｸｭ: 蟒ｺ險ｭ蛛懈ｭ｢")
			return
		var btype_str: String = captured_card.get("building_type", "")
		_selected_card_btype = btype_str
		_selected_card_idx = card_idx
		_add_log("Selected: %s" % captured_card.get("name", "?"))
		if _place_hint_label:
			_place_hint_label.visible = true
	)

	# 菴丞ｱ・・繝舌・譎ゅ・莠ｺ蜿｣繝励Ξ繝薙Η繝ｼ・按ｧ5.5.3・・
	card_btn.mouse_entered.connect(func():
		if card_data.get("building_type", "") == "HOUSE" and _pop_preview_label != null:
			_pop_preview_label.text = "[+%d]" % card_data.get("population_supply", 3)
			_pop_preview_label.visible = true
	)
	card_btn.mouse_exited.connect(func():
		if _pop_preview_label != null:
			_pop_preview_label.visible = false
	)

	# 右クリックでリロール（§2.2.3 / §3.2）
	var captured_idx: int = card_idx
	card_btn.gui_input.connect(func(event: InputEvent):
		if not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_RIGHT or not mb.pressed:
			return
		_on_hand_card_right_clicked(captured_idx)
	)

	return card_btn

func _on_hand_card_right_clicked(card_index: int) -> void:
	# §2.2.3 / §3.2 手札カードリロール（右クリック）
	if _battle.deck_manager == null:
		return
	if _battle.deck_manager.reload_timer > 0.0:
		print("[EconMain] _on_hand_card_right_clicked: cooldown remaining=%.1f" % _battle.deck_manager.reload_timer)
		return
	var hand_size: int = int(_battle.deck_manager.hand.size())
	if card_index < 0 or card_index >= hand_size:
		print("[EconMain] _on_hand_card_right_clicked: invalid index=%d" % card_index)
		return
	var discarded_card: Dictionary = _battle.deck_manager.hand[card_index]
	# discard に移動
	_battle.deck_manager.hand.remove_at(card_index)
	_battle.deck_manager.discard_pile.append(discarded_card)
	print("[EconMain] _on_hand_card_right_clicked: discarded '%s'" % discarded_card.get("name", "?"))
	# 1枚ドロー
	var drawn_card: Dictionary = {}
	if not _battle.deck_manager.deck.is_empty():
		drawn_card = _battle.deck_manager.deck.pop_front()
		_battle.deck_manager.hand.append(drawn_card)
		print("[EconMain] _on_hand_card_right_clicked: drew '%s'" % drawn_card.get("name", "?"))
	# クールタイム開始
	_battle.deck_manager.reload_timer = _battle.deck_manager.RELOAD_COOLDOWN_SEC
	# ログ記録
	if _log_manager != null and _log_manager.has_method("log_event"):
		_log_manager.log_event({
			"type": "RELOAD",
			"time": _elapsed_time,
			"discarded_card": discarded_card.get("id", ""),
			"drawn_card": drawn_card.get("id", "") if not drawn_card.is_empty() else "none",
		})
	# UI更新
	_refresh_hand_ui()

func _get_card_state(card_data: Dictionary) -> String:
	# ﾂｧ5.2.3 迥ｶ諷区ｱｺ螳壹ヤ繝ｪ繝ｼ・亥━蜈磯・ｽ埼剄鬆・ｼ・
	if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
		return "no_cell"
	var cost_raw = card_data.get("cost")
	var cost: Dictionary = cost_raw if cost_raw is Dictionary else {}
	var eco := _economy
	# 莠ｺ蜿｣繝√ぉ繝・け
	var pop_req: int = card_data.get("population_required", 0)
	if eco.population_used + pop_req > eco.population_cap:
		return "pop_short"
	# 雉・ｺ舌メ繧ｧ繝・け・・0.2 resources霎樊嶌繧剃ｽｿ逕ｨ・・
	for res_key in cost.keys():
		if cost.get(res_key, 0) > eco.resources.get(res_key, 0):
			return "resource_short"
	return "available"

func _get_card_icon(building_type: String) -> String:
	var icons: Dictionary = {
		"BARRACKS": "B",
		"HOUSE": "H",
		"LIBRARY": "L",
		"MARKET": "$",
		"WOOD_EXTRACTOR": "W",
		"STONE_EXTRACTOR": "S",
		"RESIN_EXTRACTOR": "R",
		"WHEAT_EXTRACTOR": "Wh",
		"IRON_EXTRACTOR": "I",
		"COTTON_EXTRACTOR": "C",
		"VILLAGE": "F",
		"DINER": "D",
		"PLAZA": "P",
		"EXCHANGE": "X",
	}
	return icons.get(building_type, "?")
# _setup_deck_gauge_ui / _setup_hand_ui 縺ｯ v0.2 縺ｧ蟒・ｭ｢・・setup_header_ui / _setup_footer_ui 縺ｫ邨ｱ蜷茨ｼ・

func _update_draw_gauge_ui(delta: float) -> void:
	# ﾂｧ5.1 繝峨Ο繝ｼ繧ｲ繝ｼ繧ｸUI 豈弱ヵ繝ｬ繝ｼ繝譖ｴ譁ｰ・・process 縺九ｉ蜻ｼ縺ｶ・・
	if _draw_gauge_bar == null or _battle.deck_manager == null:
		return
	var gauge_val: float = float(_battle.deck_manager.draw_gauge_value)
	var gauge_max: float = 30.0  # TURN_DURATION_SEC 蝗ｺ螳壼､・・ariant蜿ら・蝗樣∩・・
	var pending: int = int(_battle.deck_manager.pending_draws)
	var progress: float = clampf(gauge_val / gauge_max, 0.0, 1.0)

	# ﾂｧ5.1.1 4迥ｶ諷九・繝舌・濶ｲ縺ｨ貍泌・
	_draw_gauge_blink_timer += delta
	var bar_color: Color = COLOR_ACCENT_GOLD
	var sub_text: String = "%.0fs" % (gauge_max - gauge_val)

	if pending > 0:
		# 謇区惆MAX菫晉蕗・按ｧ5.1.1・・
		bar_color = COLOR_TEXT_DIM
		sub_text = "MAX (8/8)"
		_draw_gauge_label.add_theme_color_override("font_color", COLOR_RED)
	elif _draw_flash_timer > 0.0:
		# 繝峨Ο繝ｼ逋ｺ蜍慕椪髢難ｼ育區繝輔Λ繝・す繝･ ﾂｧ5.1.1・・
		_draw_flash_timer -= delta
		bar_color = Color.WHITE
		sub_text = ""
	elif progress >= 0.8:
		# 繧ゅ≧縺吶＄繝峨Ο繝ｼ・按ｧ5.1.1・・
		var blink_period: float = 0.5 if progress >= 0.9 else 1.0
		var blink_alpha: float = 0.7 + 0.3 * sin(_draw_gauge_blink_timer * PI * 2.0 / blink_period)
		bar_color = COLOR_ACCENT_GOLD_BRIGHT
		bar_color.a = blink_alpha
		sub_text = "Soon..."
		_draw_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	else:
		_draw_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)

	# 繧ｲ繝ｼ繧ｸ繝舌・縺ｯ隕ｪColorRect(bg)縺ｮ蟷・↓蟇ｾ縺励※逶ｸ蟇ｾ逧・↓莨ｸ邵ｮ
	var bg_w: float = _draw_gauge_bg.size.x if _draw_gauge_bg.size.x > 0.0 else 160.0
	_draw_gauge_bar.size = Vector2(bg_w * progress, _draw_gauge_bg.size.y)
	_draw_gauge_bar.color = bar_color
	_draw_gauge_label.text = sub_text

func _update_reload_gauge_ui() -> void:
	# §2.2.3 リロードゲージUI 毎フレーム更新
	if _reload_gauge_bar == null or _battle.deck_manager == null:
		return
	var reload_timer_val: float = float(_battle.deck_manager.reload_timer)
	var reload_max: float = float(_battle.deck_manager.RELOAD_COOLDOWN_SEC)
	var progress: float = clampf(1.0 - (reload_timer_val / reload_max), 0.0, 1.0)
	var bg_w: float = _reload_gauge_bg.size.x if _reload_gauge_bg.size.x > 0.0 else 140.0
	_reload_gauge_bar.size = Vector2(bg_w * progress, _reload_gauge_bg.size.y)
	# クールタイム中は残り秒数表示、完了時は "Ready"
	if reload_timer_val > 0.0:
		_reload_gauge_bar.color = Color(0.75, 0.58, 0.28)
		_reload_gauge_label.text = "%.1fs" % reload_timer_val
	else:
		_reload_gauge_bar.color = COLOR_ACCENT_GOLD
		_reload_gauge_label.text = "Ready"

func _update_force_charge_gauge_ui(delta: float) -> void:
	# ﾂｧ5.2 蠑ｷ蛻ｶ遯∵茶繧ｲ繝ｼ繧ｸUI 豈弱ヵ繝ｬ繝ｼ繝譖ｴ譁ｰ
	if _force_charge_segs.is_empty() or _battle.deck_manager == null:
		return
	var turn: int = clampi(int(_battle.deck_manager.current_turn), 0, 10)

	_force_charge_blink_timer += delta

	# 繧ｻ繧ｰ繝｡繝ｳ繝郁牡譖ｴ譁ｰ
	for i in range(10):
		var seg: ColorRect = _force_charge_segs[i]
		if i < turn:
			# ﾂｧ5.2.1 谿ｵ髫手牡
			var seg_color: Color
			var seg_turn := i + 1  # 1蟋九∪繧・
			if seg_turn <= 3:
				seg_color = COLOR_WOOD        # 邱・蟷ｳ蟶ｸ
			elif seg_turn <= 6:
				seg_color = COLOR_WHEAT       # 鮟・豕ｨ諢・
			elif seg_turn <= 9:
				# 讖・隴ｦ謌抵ｼ・.8遘貞捉譛滓・貊・ｼ・
				var blink := 0.7 + 0.3 * sin(_force_charge_blink_timer * PI * 2.0 / 0.8)
				seg_color = COLOR_ORANGE
				seg_color.a = blink
			else:
				# 襍､ 蜊ｱ髯ｺ・・.4遘貞捉譛溷ｼｷ譏取ｻ・ｼ・
				var blink := 0.5 + 0.5 * sin(_force_charge_blink_timer * PI * 2.0 / 0.4)
				seg_color = COLOR_RED
				seg_color.a = blink
			seg.color = seg_color
		else:
			seg.color = COLOR_PANEL

	if _force_charge_turn_label != null:
		_force_charge_turn_label.text = "Turn %d/10" % turn

	# Turn7莉･髯・遯∵茶貅門ｙ謗ｨ螂ｨ繝ｩ繝吶Ν・按ｧ5.2.1・・
	if _force_charge_warn_label != null:
		_force_charge_warn_label.visible = (turn >= 7)

	# 譌ｩ譛溽ｪ∵茶繝懊ち繝ｳ縺ｮ濶ｲ騾｣蜍包ｼ按ｧ5.2.2・・
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

func _on_alloc_bar_input(event: InputEvent) -> void:
	# ﾂｧ2.4.2 驟榊・繝舌・繝峨Λ繝・げ蜈･蜉帛・逅・
	if _alloc_bar_bg == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_alloc_dragging = mb.pressed
			if mb.pressed:
				_apply_alloc_from_mouse(mb.position.x)
	elif event is InputEventMouseMotion and _alloc_dragging:
		_apply_alloc_from_mouse(event.position.x)

func _apply_alloc_from_mouse(local_x: float) -> void:
	# 繝槭え繧ｹX菴咲ｽｮ縺九ｉ alloc_work_ratio 繧定ｨ育ｮ励＠縺ｦ繧ｹ繝翫ャ繝鈴←逕ｨ
	var bar_w: float = _alloc_bar_bg.size.x
	if bar_w <= 0.0:
		return
	var raw_ratio: float = clampf(local_x / bar_w, 0.0, 1.0)
	_economy.set_alloc_work_ratio(raw_ratio)
	_update_alloc_bar_ui()

func _update_alloc_bar_ui() -> void:
	# ﾂｧ2.4.2 驟榊・繝舌・UI譖ｴ譁ｰ・・ull蝙具ｼ・
	if _alloc_bar_bg == null or _alloc_bar_work == null or _alloc_handle == null:
		return
	var ratio: float = _economy.alloc_work_ratio  # 菴懈･ｭ蜑ｲ蜷・
	var bar_w: float = _alloc_bar_bg.size.x
	if bar_w <= 0.0:
		return
	var work_x: float = bar_w * (1.0 - ratio)  # 菴懈･ｭ驛ｨ蛻・・髢句ｧ宜
	# 菴懈･ｭ莠ｺ蜿｣驛ｨ蛻・ｼ亥承蛛ｴ繝ｻ邱托ｼ・
	_alloc_bar_work.position = Vector2(work_x, 0.0)
	_alloc_bar_work.size = Vector2(bar_w - work_x, _alloc_bar_bg.size.y)
	# 繝上Φ繝峨Ν菴咲ｽｮ
	_alloc_handle.position = Vector2(work_x - 1.0, 0.0)
	_alloc_handle.size = Vector2(2.0, _alloc_bar_bg.size.y)
	# 繝ｩ繝吶Ν譖ｴ譁ｰ
	if _alloc_label != null:
		var work_pct: int = roundi(ratio * 100.0)
		var ops_pct: int = 100 - work_pct
		var ops_labor: int = _economy.get_operation_labor()
		var work_labor: int = _economy.get_work_labor()
		_alloc_label.text = "OPS %d%% %d / WORK %d%% %d" % [ops_pct, ops_labor, work_pct, work_labor]
		# 人手不足時: 1.0sサイクルsin波点滅（REQUIREMENTS_SPRINT_7.md §6.2）
		var is_shortage: bool = (ops_labor <= 0 or work_labor <= 0)
		if is_shortage:
			var blink_alpha: float = 0.5 + 0.5 * sin(fmod(_elapsed_time, 1.0) * TAU)
			_alloc_label.add_theme_color_override("font_color", Color(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, blink_alpha))
		else:
			_alloc_label.add_theme_color_override("font_color", COLOR_TEXT)

func _update_population_ui() -> void:
	# ﾂｧ5.5 莠ｺ蜿｣陦ｨ遉ｺUI 豈弱ヵ繝ｬ繝ｼ繝譖ｴ譁ｰ・・ull蝙具ｼ・
	if _pop_gauge_bar == null or _pop_label == null:
		return
	var pop_used: int = _economy.population_used
	var pop_cap: int = _economy.population_cap
	if pop_cap <= 0:
		return
	var ratio: float = float(pop_used) / float(pop_cap)
	var pbg_w: float = _pop_gauge_bar.get_parent().size.x if _pop_gauge_bar.get_parent() != null and _pop_gauge_bar.get_parent().size.x > 0.0 else 80.0
	_pop_gauge_bar.size = Vector2(pbg_w * clampf(ratio, 0.0, 1.0), _pop_gauge_bar.size.y)
	# ﾂｧ5.5.1 濶ｲ蛻・￠
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

func _update_status_ui() -> void:
	# ﾂｧ5.1 HEADER 繧ｹ繝・・繧ｿ繧ｹUI 豈弱ヵ繝ｬ繝ｼ繝譖ｴ譁ｰ・・0.2・・
	# 貅雜ｳ蠎ｦ・域隼險・: 荳区ｮｵ繝ｩ繝吶Ν縺ｮ縺ｿ・・
	if _status_sat_label != null:
		_status_sat_label.text = "貅雜ｳ蠎ｦ%d(v0.3)" % _economy.satisfaction
	# 蜈ｵ蜉・+ 蜈ｵ蜉帙ご繝ｼ繧ｸ 4谿ｵ髫取ｼ泌・・按ｧ3.5・・
	var mil_power: float = _economy.military_power
	if _troop_label != null:
		_troop_label.text = "%d" % int(floor(mil_power))
	var gauge_progress: float = clampf(mil_power / 60.0, 0.0, 1.0)
	if mil_power == 0.0:
		# Stage 0: 證励￥髱呎ｭ｢
		if _troop_gauge_bar != null:
			_troop_gauge_bar.modulate.a = 0.3
			_troop_gauge_bar.self_modulate = COLOR_TROOP
		if _troop_label != null:
			_troop_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
			_troop_label.remove_theme_font_size_override("font_size")
	elif mil_power <= 30.0:
		# Stage 1: 騾壼ｸｸ陦ｨ遉ｺ
		if _troop_gauge_bar != null:
			_troop_gauge_bar.modulate.a = 1.0
			_troop_gauge_bar.self_modulate = COLOR_TROOP
		if _troop_label != null:
			_troop_label.add_theme_color_override("font_color", COLOR_TEXT)
			_troop_label.remove_theme_font_size_override("font_size")
	elif mil_power <= 50.0:
		# Stage 2: 1.0遘貞捉譛・ﾎｱ=0.7竊・.0 譏取ｻ・+ 螟ｪ蟄・
		var cycle2: float = fmod(_elapsed_time, 1.0)
		var alpha2: float = lerp(0.7, 1.0, sin(cycle2 * PI) * 0.5 + 0.5)
		if _troop_gauge_bar != null:
			_troop_gauge_bar.modulate.a = alpha2
			_troop_gauge_bar.self_modulate = COLOR_TROOP
		if _troop_label != null:
			_troop_label.add_theme_color_override("font_color", COLOR_TEXT)
			_troop_label.add_theme_font_size_override("font_size", 14)
	else:
		# Stage 3: 0.5遘貞捉譛溷ｼｷ譏取ｻ・+ 襍､濶ｲ
		var cycle3: float = fmod(_elapsed_time, 0.5)
		var alpha3: float = 0.5 if cycle3 < 0.25 else 1.0
		if _troop_gauge_bar != null:
			_troop_gauge_bar.modulate.a = alpha3
			_troop_gauge_bar.self_modulate = COLOR_RED
		if _troop_label != null:
			_troop_label.add_theme_color_override("font_color", COLOR_RED)
			_troop_label.add_theme_font_size_override("font_size", 14)
	# 繧ｲ繝ｼ繧ｸ繝舌・繧ｵ繧､繧ｺ譖ｴ譁ｰ・亥・騾夲ｼ・
	if _troop_gauge_bar != null:
		var tbg_w: float = _troop_gauge_bar.get_parent().size.x if _troop_gauge_bar.get_parent() != null and _troop_gauge_bar.get_parent().size.x > 0.0 else 80.0
		_troop_gauge_bar.size = Vector2(tbg_w * gauge_progress, _troop_gauge_bar.size.y)
	# 雉・≡・按ｧ3.6・・
	if _gold_label != null:
		_gold_label.text = "%dG" % _economy.currency
		var cur_color := COLOR_TEXT_DIM if _economy.currency <= 0 else COLOR_GOLD_COIN
		_gold_label.add_theme_color_override("font_color", cur_color)
	if _status_food_label != null:
		_status_food_label.text = "食%d" % _economy.food
		var food_color := COLOR_RED if _economy.food < 5 else COLOR_WHEAT
		_status_food_label.add_theme_color_override("font_color", food_color)
	if _soldiers_header_label != null:
		_soldiers_header_label.text = "蜈ｵ%d" % _economy.get_soldiers_count()
	if _units_header_label != null:
		_units_header_label.text = "U%d" % _economy.get_unit_count()

func _on_early_charge_btn_pressed() -> void:
	# 譌ｧ譌ｩ譛溽ｪ∵茶繝懊ち繝ｳ・亥炎髯､貂医∩UI縺ｮ莠呈鋤髢｢謨ｰ・・
	_trigger_unified_charge()

func _trigger_unified_charge() -> void:
	# Phase 3: BASE髟ｷ謚ｼ縺・+ 繧ｿ繝ｼ繝ｳ10 縺ｮ邨ｱ荳荳譁臥ｪ∵茶蜃ｦ逅・
	if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
		return
	print("[EconMain] _trigger_unified_charge: activated")
	_battle.trigger_early_charge()
	_add_log("荳譁臥ｪ∵茶逋ｺ蜍・")
	_charge_mode = true
	for u in _battle.player_units:
		if u.is_alive and u.is_idle:
			u.is_idle = false
	for f in _flags:
		f.is_assault_mode = true
		f.queue_redraw()
	# 逕ｻ髱｢繝輔Λ繝・す繝･・育區繝ｻ0.3遘抵ｼ・
	var flash_rect := ColorRect.new()
	flash_rect.color = Color.WHITE
	flash_rect.modulate.a = 0.4
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(flash_rect)
	var tween := create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash_rect.queue_free)
	# 縲靴HARGE!縲阪ユ繧ｭ繧ｹ繝茨ｼ育乢髱｢荳ｭ螟ｮ繝ｻ襍､繝ｻ64px・・
	var vp := get_viewport().get_visible_rect().size
	var charge_label := Label.new()
	charge_label.text = "CHARGE!"
	charge_label.add_theme_font_size_override("font_size", 64)
	charge_label.add_theme_color_override("font_color", COLOR_RED)
	charge_label.position = vp / 2.0 - Vector2(160.0, 40.0)
	_ui_layer.add_child(charge_label)
	var tween2 := create_tween()
	tween2.tween_property(charge_label, "modulate:a", 0.0, 1.0)
	tween2.tween_callback(charge_label.queue_free)
	_base_longpress_start_time = -1.0

func _create_start_button() -> void:
	# Phase 4: START繝懊ち繝ｳ・亥・蝗槭・縺ｿ逶､髱｢荳ｭ螟ｮ繝輔Ο繝ｼ繝・ぅ繝ｳ繧ｰ・・
	_start_button = Button.new()
	_start_button.text = "Start"
	_start_button.position = Vector2(560.0, 288.0)
	_start_button.custom_minimum_size = Vector2(160.0, 64.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	_start_button.add_theme_stylebox_override("normal", sb)
	_start_button.add_theme_font_size_override("font_size", 20)
	_start_button.add_theme_color_override("font_color", COLOR_ACCENT_GOLD)
	_start_button.pressed.connect(func():
		_game_started = true
		_on_start_pressed()
		_start_button.queue_free()
		_start_button = null
	)
	_ui_layer.add_child(_start_button)
