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
const HAND_DISPLAY_COUNT: int = 5
const EconUIScript := preload("res://scripts/econ_mvp/EconUI.gd")
const BuildQueueUIScript := preload("res://scripts/econ_mvp/ui/BuildQueueUI.gd")
const DetailPopupScript := preload("res://scripts/econ_mvp/ui/DetailPopup.gd")
const LogManagerScript := preload("res://scripts/econ_mvp/LogManager.gd")
const GameSessionScript := preload("res://scripts/econ_mvp/GameSession.gd")
const RewardSystemManagerScript := preload("res://scripts/econ_mvp/RewardSystemManager.gd")
const MilestoneWindowScript := preload("res://scripts/econ_mvp/MilestoneWindow.gd")
const RewardSelectionUIScript := preload("res://scripts/econ_mvp/RewardSelectionUI.gd")
const LandCardPlacementControllerScript := preload("res://scripts/econ_mvp/LandCardPlacementController.gd")
const ZoomControllerScript := preload("res://scripts/econ_mvp/ui/ZoomController.gd")
const HeaderUIScript := preload("res://scripts/econ_mvp/ui/HeaderUI.gd")
const FooterUIScript := preload("res://scripts/econ_mvp/ui/FooterUI.gd")

var _is_running: bool = false
var _selected_unit: EconUnit = null
var _guard_select_mode: bool = false
var _order_panel: PanelContainer = null
var _target_priority: int = 0
var _place_hint_label: Label = null
var _charge_mode: bool = false
var _flags: Array = []
var _next_flag_id: int = 0
var _next_construction_order: int = 1
var _connecting_building: EconBuilding = null
var _charge_btn: Button = null
var _land_reward_panel: PanelContainer = null
var _pending_reward_queue: Array = []


var _selected_card_btype: String = ""

var _selected_card_idx: int = -1


var _base_longpress_start_time: float = -1.0
var _base_longpress_cell: Vector2i = Vector2i(-1, -1)
const BASE_LONGPRESS_THRESHOLD := 0.6

# ZoomController は ZoomController.gd へ分離 (Sprint 8)
var _map_camera: Camera2D = null
var _zoom_ctrl = null  # ZoomController (ZoomController.gd)


var _start_button: Button = null
var _game_started: bool = false


var _header_ui = null  # HeaderUI (Sprint 9: 分離)
var _footer_ui = null  # FooterUI (Sprint 9: 分離)
var _header: PanelContainer = null
var _footer: PanelContainer = null
var _hand_container: HBoxContainer = null
var _hand_scroll_offset: int = 0
var _hand_left_arrow: Button = null        # 笳遏｢蜊ｰ
var _hand_right_arrow: Button = null       # 笆ｶ遏｢蜊ｰ
var _draw_gauge_bar: ColorRect = null
var _draw_gauge_bg: ColorRect = null
var _draw_gauge_label: Label = null
var _reload_gauge_bar: ColorRect = null    # リロードゲージバー（§2.2.3）
var _reload_gauge_bg: ColorRect = null     # リロードゲージ背景（§2.2.3）
var _reload_gauge_label: Label = null      # リロードゲージサブテキスト（§2.2.3）
var _force_charge_segs: Array = []
var _force_charge_turn_label: Label = null  # N/10 陦ｨ遉ｺ
var _force_charge_warn_label: Label = null
var _early_charge_btn: Button = null
var _deck_count_label: Label = null
var _discard_count_label: Label = null      # DISCARD 譫壽焚


var _pop_gauge_bar: ColorRect = null
var _pop_label: Label = null
var _pop_preview_label: Label = null
var _status_sat_label: Label = null        # Sat 0
var _troop_gauge_bar: ColorRect = null
var _troop_label: Label = null
var _gold_label: Label = null
var _status_food_label: Label = null
var _soldiers_header_label: Label = null
var _units_header_label: Label = null
var _header_detail_popup: PanelContainer = null
var _header_detail_label: Label = null
var _detail_popup = null  # DetailPopup インスタンス（preload経由）

# F12デバッグコンソール
var _debug_console_panel: PanelContainer = null
var _debug_console_input: LineEdit = null
var _debug_console_log: TextEdit = null
var _debug_console_history: Array = []


var _res_labels: Dictionary = {}


var _alloc_bar_bg: ColorRect = null
var _alloc_bar_work: ColorRect = null
var _alloc_handle: ColorRect = null
var _alloc_label: Label = null
var _force_charge_blink_timer: float = 0.0  # Sprint 9: HeaderUIに渡すタイマー
var _draw_flash_timer: float = 0.0  # Sprint 9: FooterUIフォールバック用
var _elapsed_time: float = 0.0

const COLOR_PANEL      := Color("#231F1B")
const COLOR_BORDER     := Color("#3C3628")
const COLOR_TEXT       := Color("#DCD2B9")
const COLOR_TEXT_DIM   := Color("#8A8070")
const COLOR_ACCENT_GOLD := Color("#B49448")
const COLOR_WOOD       := Color("#3F6932")
const COLOR_STONE      := Color("#5D5650")
const COLOR_RESIN      := Color("#9A8A3C")
const COLOR_WHEAT      := Color("#A9924F")

const COLOR_POP        := Color("#5D8FB8")
const COLOR_SAT        := Color("#B89AC7")
const COLOR_TROOP      := Color("#B85A3C")
const COLOR_GOLD_COIN  := Color("#E0C060")

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


	await get_tree().process_frame
	var header_h: float = _header.size.y if _header else 56.0
	print("[EconMain] HEADER actual height: %f" % header_h)


	var board_h: float = vp.y - header_h - FOOTER_H


	var footer_y: float = header_h + board_h
	if _footer != null:
		_footer.position.y = footer_y
		print("[EconMain] FOOTER position.y: %f (HEADER %f + BOARD %f)" % [footer_y, header_h, board_h])


	_grid.position.y = header_h


	var hex_w: float = EconGrid.HEX_SIZE * sqrt(3.0)
	var col_count: int = 26
	var grid_full_w := hex_w * float(col_count)
	var grid_full_h := EconGrid.HEX_SIZE * 2.0 * 0.75 * float(EconGrid.ROWS - 1) + EconGrid.HEX_SIZE * 2.0
	_grid.origin = Vector2(
		(vp.x - grid_full_w) * 0.5 + hex_w * 0.5,
		(board_h - grid_full_h) * 0.5 + EconGrid.HEX_SIZE
	)
	_grid.queue_redraw()
	# Camera2D initial position: grid center in world coordinates
	var hex_w_cam: float = EconGrid.HEX_SIZE * sqrt(3.0)
	var hex_h_cam: float = EconGrid.HEX_SIZE * 2.0
	var grid_full_w_cam := hex_w_cam * float(EconGrid.COLS)
	var grid_full_h_cam := hex_h_cam * 0.75 * float(EconGrid.ROWS - 1) + hex_h_cam
	var grid_center_in_world := _grid.global_position + _grid.origin + Vector2(grid_full_w_cam * 0.5, grid_full_h_cam * 0.5)
	_map_camera.position = grid_center_in_world
	_setup_ai()
	_setup_initial_entities()
	_setup_deck_manager()
	_create_debug_console()
	_zoom_ctrl = ZoomControllerScript.new()
	add_child(_zoom_ctrl)
	_zoom_ctrl.setup(_map_camera, _grid, _ui_layer, FOOTER_H, _header, _battle)

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
	_map_camera = Camera2D.new()
	_map_camera.name = "MapCamera"
	add_child(_map_camera)
	_grid = EconGrid.new()
	add_child(_grid)


func _setup_economy() -> void:
	_economy = EconEconomy.new()
	add_child(_economy)

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

	print("[EconMain] _setup_initial_entities: BASE only mode (Phase 2 clean start)")

	var enemy_base := EconBuilding.new()
	enemy_base.setup(EconBuilding.BuildingType.BASE, Vector2i(24, 6), false)
	enemy_base.position = _grid.hex_to_pixel(24, 6)
	enemy_base.unit_produced.connect(_ai.on_unit_produced)
	_battle.register_enemy_building(enemy_base)

	var player_base := EconBuilding.new()
	player_base.setup(EconBuilding.BuildingType.BASE, Vector2i(1, 6), true)
	player_base.position = _grid.hex_to_pixel(1, 6)
	player_base.unit_produced.connect(_battle._on_unit_produced)
	player_base.building_destroyed.connect(func(building: Node):
		_battle._on_building_destroyed(building)
	)
	_battle.register_player_building(player_base)

func _setup_ui(vp: Vector2) -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)


	# === HeaderUI (Sprint 9: 分離)
	_header_ui = HeaderUIScript.new()
	_ui_layer.add_child(_header_ui)
	_header_ui.setup(_economy, vp)
	_header = _header_ui.get_panel()
	# ヘッダー変数を HeaderUI から参照（後方互換）
	_pop_gauge_bar = _header_ui._pop_gauge_bar
	_pop_label = _header_ui._pop_label
	_pop_preview_label = _header_ui._pop_preview_label
	_status_sat_label = _header_ui._status_sat_label
	_troop_gauge_bar = _header_ui._troop_gauge_bar
	_troop_label = _header_ui._troop_label
	_gold_label = _header_ui._gold_label
	_status_food_label = _header_ui._status_food_label
	_soldiers_header_label = _header_ui._soldiers_header_label
	_units_header_label = _header_ui._units_header_label
	_res_labels = _header_ui._res_labels
	_alloc_bar_bg = _header_ui._alloc_bar_bg
	_alloc_bar_work = _header_ui._alloc_bar_work
	_alloc_handle = _header_ui._alloc_handle
	_alloc_label = _header_ui._alloc_label
	_force_charge_segs = _header_ui._force_charge_segs
	_force_charge_turn_label = _header_ui._force_charge_turn_label
	_force_charge_warn_label = _header_ui._force_charge_warn_label
	_header_detail_popup = _header_ui._header_detail_popup
	_header_detail_label = _header_ui._header_detail_label
	_ai_resource_label = _header_ui._ai_resource_label
	# === FooterUI (Sprint 9: 分離)
	_footer_ui = FooterUIScript.new()
	_ui_layer.add_child(_footer_ui)
	_footer_ui.setup(vp)
	_footer = _footer_ui.get_footer()
	_footer_ui.hand_scroll_left_pressed.connect(_on_hand_scroll_left)
	_footer_ui.hand_scroll_right_pressed.connect(_on_hand_scroll_right)
	# フッター変数をFooterUIから参照（後方互換）
	_hand_container = _footer_ui._hand_container
	_hand_left_arrow = _footer_ui._hand_left_arrow
	_hand_right_arrow = _footer_ui._hand_right_arrow
	_draw_gauge_bar = _footer_ui._draw_gauge_bar
	_draw_gauge_bg = _footer_ui._draw_gauge_bg
	_draw_gauge_label = _footer_ui._draw_gauge_label
	_reload_gauge_bar = _footer_ui._reload_gauge_bar
	_reload_gauge_bg = _footer_ui._reload_gauge_bg
	_reload_gauge_label = _footer_ui._reload_gauge_label
	_deck_count_label = _footer_ui._deck_count_label
	_discard_count_label = _footer_ui._discard_count_label

	# DetailPopup (建物詳細): HeaderUI非依存のため_setup_uiから直接初期化
	_setup_detail_popup()

	if not _game_started:
		_create_start_button()


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

func _setup_detail_popup() -> void:
	# 建物詳細ポップアップ初期化（要件定義書 REQUIREMENTS_SPRINT_8.md §6.6.3）
	_detail_popup = DetailPopupScript.new()
	_ui_layer.add_child(_detail_popup)
	print("[EconMain] DetailPopup initialized")


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
	_zoom_ctrl._set_zoom_level(1)       # Lv1 at battle start
	_zoom_ctrl._focus_player_base()     # focus player base
	if _status_label != null:
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
	_add_difficulty_button(row, "low", "Low\n+100G\nEasy")
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
		_add_log("初期難易度: %s / 通貨補正 %dG" % [difficulty, _game_session.current_battle_gold])
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
	# F12 デバッグコンソール
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_toggle_debug_console()
		get_tree().root.set_input_as_handled()
		return

	if _zoom_ctrl != null:
		if event is InputEventMouseMotion:
			if _zoom_ctrl.handle_input(event):
				_base_longpress_start_time = -1.0
				get_tree().root.set_input_as_handled()
				return
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP \
					or event.button_index == MOUSE_BUTTON_WHEEL_DOWN \
					or event.button_index == MOUSE_BUTTON_MIDDLE:
				if _zoom_ctrl.handle_input(event):
					get_tree().root.set_input_as_handled()
					return
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_zoom_ctrl.handle_input(event)
				elif _zoom_ctrl.handle_input(event):
					get_tree().root.set_input_as_handled()
					return
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_zoom_ctrl.handle_input(event)
				elif _zoom_ctrl.handle_input(event):
					get_tree().root.set_input_as_handled()
					return

	if not (event is InputEventMouseButton):
		return

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

			_base_longpress_start_time = -1.0
	if not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if _zoom_ctrl != null and _zoom_ctrl._is_panning:
			return
		var local_pos2: Vector2 = _grid.to_local(get_global_mouse_position())
		var rcell := _pixel_to_hex(local_pos2)
		if rcell == Vector2i(-1, -1):
			return

		for f in _flags:
			if f.grid_pos == rcell:
				_remove_flag(f)
				return

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

	if cell != Vector2i(-1, -1):
		for b in _battle.player_buildings:
			if b.is_alive and b.grid_pos == cell:
				# 建物詳細ポップアップ表示（要件定義書 REQUIREMENTS_SPRINT_8.md §6.6.3）
				if _detail_popup != null:
					_detail_popup.show_building(b, get_global_mouse_position())
				_connecting_building = b
				_add_log("Select flag to connect (ESC to cancel)")
				return
	# 何もない場所クリックでDetailPopupを閉じる
	if _detail_popup != null and _detail_popup.visible:
		_detail_popup.close()

	if _guard_select_mode:
		if cell != Vector2i(-1, -1):

			for u in _battle.player_units:
				if u.is_alive and u.grid_pos == cell and u != _selected_unit:
					_selected_unit.order = EconUnit.OrderType.GUARD
					_selected_unit.guard_target = u
					_add_log("Guard: unit at (%d,%d)" % [cell.x, cell.y])
					_guard_select_mode = false
					return

			for b in _battle.player_buildings:
				if b.is_alive and b.grid_pos == cell:
					_selected_unit.order = EconUnit.OrderType.GUARD
					_selected_unit.guard_target = b
					_add_log("Guard: building at (%d,%d)" % [cell.x, cell.y])
					_guard_select_mode = false
					return
		_guard_select_mode = false
		return

	if _selected_card_btype != "":
		if cell == Vector2i(-1, -1):
			return
		if not _grid.is_valid_cell(cell.x, cell.y):
			return
		if _battle.grid != null and _battle.grid.construction_sites.has(cell):
			_add_log("Cell under construction")
			return
		for b in _battle.player_buildings:
			if b.grid_pos == cell:
				print("[EconMain._input] card=%s, cell=(%d,%d), check=building_occupied FAILED" % [_selected_card_btype, cell.x, cell.y])
				_add_log("Cell occupied by building")
				return
		print("[EconMain._input] card=%s, cell=(%d,%d), check=all_passed -> _place_building_from_card" % [_selected_card_btype, cell.x, cell.y])
		_place_building_from_card(cell, _selected_card_btype)
		if _selected_card_btype == "" and _place_hint_label:
			_place_hint_label.visible = false
		return

	for b in _battle.player_buildings:
		if b.grid_pos == cell and not b.is_built:
			_battle.player_buildings.erase(b)
			b.queue_free()
			_add_log("建設キャンセル")
			return

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
	# 資源不足でも建設予約は可能（デッドロック防止）
	var success: bool = _battle.play_card_and_build(_selected_card_idx, cell)
	if not success:
		_add_log("Cannot place: %s" % card.get("name", btype_str))
		_selected_card_idx = -1
		_selected_card_btype = ""
		return
	_add_log("%s construction started at (%d,%d)" % [card.get("name", btype_str), cell.x, cell.y])
	_selected_card_idx = -1
	_selected_card_btype = ""
	_grid.fill_cells.clear()
	_grid.queue_redraw()
	_refresh_hand_ui()

func _on_build_queue_instant_build_requested(site: Dictionary) -> void:
	if site.is_empty():
		return
	var pos: Vector2i = site.get("panel_id", Vector2i(-1, -1))
	if pos == Vector2i(-1, -1) or _battle == null or _battle.grid == null:
		return
	if not _battle.grid.construction_sites.has(pos):
		return
	var total_labor_units: float = float(site.get("construction_time", 1.0))
	var progress: float = clampf(float(site.get("construction_progress", 0.0)), 0.0, 1.0)
	var remaining_labor: float = maxf(0.0, total_labor_units * (1.0 - progress))
	var cost_g: int = int(ceil(remaining_labor * float(LABOR_COST_PER_UNIT)))
	if cost_g <= 0:
		return
	if _economy.currency < cost_g:
		_add_log("Gold insufficient: instant build needs %dG" % cost_g)
		return
	_economy.currency -= cost_g
	var _site_data: Dictionary = _battle.grid.construction_sites[pos]
	_site_data["construction_progress"] = 1.0
	_battle.grid.queue_redraw()
	_add_log("Instant build: %dG at (%d,%d)" % [cost_g, pos.x, pos.y])

func _on_build_queue_cancel_requested(site: Dictionary) -> void:
	if site.is_empty():
		return
	var pos: Vector2i = site.get("panel_id", Vector2i(-1, -1))
	if pos == Vector2i(-1, -1) or _battle == null or _battle.grid == null:
		return
	if _battle.grid.construction_sites.has(pos):
		_battle.grid.construction_sites.erase(pos)
	for b in _battle.player_buildings:
		if b is EconBuilding and b.grid_pos == pos:
			_battle.player_buildings.erase(b)
			b.queue_free()
			break
	_reindex_construction_queue()
	_add_log("建設キャンセル: (%d,%d)" % [pos.x, pos.y])

func _on_build_queue_reorder_requested(site: Dictionary, target_index: int) -> void:
	if site.is_empty():
		return
	var pos: Vector2i = site.get("panel_id", Vector2i(-1, -1))
	if pos == Vector2i(-1, -1) or _battle == null:
		return
	var building: EconBuilding = null
	for b in _battle.player_buildings:
		if b is EconBuilding and b.grid_pos == pos:
			building = b
			break
	if building == null:
		return
	var queue := _get_unbuilt_player_buildings_sorted()
	if queue.is_empty():
		return
	queue.erase(building)
	queue.insert(clampi(target_index - 1, 0, queue.size()), building)
	for i in range(queue.size()):
		queue[i].set_meta("construction_order", i + 1)
	_next_construction_order = queue.size() + 1
	_add_log("建設キュー変更: %d番へ" % target_index)

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
	if _status_label != null:
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
	_add_log("報酬獲得: %s" % str(card.get("name", card.get("card_id", "?"))))
	if str(card.get("card_type", "")) == "land_card":
		if _land_placement_controller.begin(card, _grid, _battle):
			_add_log("土地カード配置モード: 隣接未建設土地をクリック")
			return
	_show_next_reward()

func _on_reward_skipped(context: Dictionary) -> void:
	var record := context.duplicate(true)
	record["selected"] = "SKIP"
	record["skipped"] = true
	_reward_manager.record_reward_selection(record)
	_add_log("報酬スキップ")
	_show_next_reward()

func _on_land_card_placed(card: Dictionary, pos: Vector2i) -> void:
	_game_session.record_land_card(card, pos)
	_add_log("土地カード配置完了 (%d,%d)" % [pos.x, pos.y])
	_show_next_reward()

func _on_land_card_placement_failed(card: Dictionary) -> void:
	_add_log("配置可能な土地がないため土地カード選択不可")
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

func _process(delta: float) -> void:
	_elapsed_time += delta

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

		_grid.queue_redraw()
	else:
		if _grid.base_longpress_cell != Vector2i(-1, -1):
			_grid.base_longpress_cell = Vector2i(-1, -1)
			_grid.base_longpress_progress = 0.0
			_grid.queue_redraw()
	_battle.update(delta)
	if _battle.deck_manager != null:
		_economy.unit_count = int(_battle.deck_manager.hand.size())

	_update_territory_highlight()
	_update_buildable_highlight()

	# === HeaderUI refresh (Sprint 9: 分離)
	if _header_ui != null:
		var ai_eco = _ai.economy if (_ai != null and _ai.economy != null) else null
		_header_ui.refresh(delta, ai_eco)
		if _battle.deck_manager != null:
			var turn: int = clampi(int(_battle.deck_manager.current_turn), 0, 10)
			_force_charge_blink_timer += delta
			_header_ui.refresh_force_charge_with_turn(turn, _force_charge_blink_timer)

	# === FooterUI refresh (Sprint 9: 分離)
	if _footer_ui != null and _battle.deck_manager != null:
		_footer_ui.refresh_draw_gauge(delta, _battle.deck_manager)
		_footer_ui.refresh_reload_gauge(_battle.deck_manager)
	if _milestone_window != null and _milestone_window.visible:
		_milestone_window.update_milestones()

func _update_territory_highlight() -> void:

	_grid.highlight_cells.clear()
	_grid.fill_cells.clear()
	_grid.resource_highlight_type = EconGrid.ResourceType.NONE
	_grid.land_highlight_cells.clear()

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

	# 土地参照型建物: 対象リソースを持つ revealed かつ建築可能パネルを強調
	var land_resource_keys: Array = _get_land_resource_keys_for_card(card)
	if not land_resource_keys.is_empty():
		var buildable_set: Dictionary = {}
		for cell in options:
			buildable_set[cell] = true
		for pos in _grid.land_panels.keys():
			var panel: Dictionary = _grid.land_panels[pos]
			if not panel.get("revealed", false):
				continue
			if not buildable_set.has(pos):
				continue
			var resources: Dictionary = panel.get("resources", {})
			for rkey in land_resource_keys:
				if rkey == "spice":
					if str(panel.get("special_tag", "none")) == "spice":
						_grid.land_highlight_cells[pos] = true
						break
				elif int(resources.get(rkey, 0)) > 0:
					_grid.land_highlight_cells[pos] = true
					break

func _get_land_resource_keys_for_card(card: Dictionary) -> Array:
	var btype_str: String = card.get("building_type", "")
	match btype_str:
		"SAWMILL", "WOOD_EXTRACTOR": return ["wood"]
		"MINE", "STONE_EXTRACTOR", "IRON_EXTRACTOR": return ["stone"]
		"RESIN_EXTRACTOR": return ["resin"]
		"VILLAGE", "WHEAT_EXTRACTOR": return ["wheat", "cotton"]
		"COTTON_EXTRACTOR": return ["cotton"]
		"MILL": return ["wheat"]  # パネル小麦値3以上でボーナス（EconBuilding.gd line 421）
		"DINER": return ["spice"]  # 香辛料パネル上: 食料値2倍ボーナス
	return []

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
	title.text = "土地カード配置"
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
	cancel_btn.text = "キャンセル"
	cancel_btn.custom_minimum_size = Vector2(120, 32)
	cancel_btn.pressed.connect(func():
		_add_log("土地カード配置をスキップ")
		if _land_reward_panel != null:
			_land_reward_panel.queue_free()
			_land_reward_panel = null
	)
	root.add_child(cancel_btn)
	print("[LandCardReward] shown: cards=%d placement_options=%d" % [cards.size(), placement_options.size()])

func _create_land_reward_choice(card: Dictionary, pos: Vector2i, own_positions: Array, occupied_positions: Array) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(190, 122)
	btn.text = "%s\n%s\n%s\n配置" % [
		_format_land_card_summary(card),
		_format_land_panel_summary(pos),
		"座標(%d,%d)" % [pos.x, pos.y],
	]
	btn.pressed.connect(func():
		_place_selected_land_card(card, pos, own_positions, occupied_positions)
	)
	return btn

func _format_land_card_summary(card: Dictionary) -> String:
	var panel_data: Dictionary = card.get("panel_data", {})
	var resources: Dictionary = panel_data.get("resources", {})
	return "カード: %s\n効果資源: %s" % [str(card.get("land_subtype", "")), str(resources)]

func _format_land_panel_summary(pos: Vector2i) -> String:
	var panel: Dictionary = _grid.get_panel_at(pos)
	var resources: Dictionary = panel.get("resources", {})
	return "既存: %s\n地形: %s / タグ: %s" % [
		str(resources),
		str(panel.get("terrain_type", "grassland")),
		str(panel.get("special_tag", "none")),
	]

func _place_selected_land_card(card: Dictionary, pos: Vector2i, own_positions: Array, occupied_positions: Array) -> void:
	var placed: bool = _grid.place_land_card(card, pos, own_positions, occupied_positions)
	if not placed:
		_add_log("土地カード配置失敗 (%d,%d)" % [pos.x, pos.y])
		return
	_grid.reveal_panels_around(pos, 3)
	_grid.queue_redraw()
	_add_log("土地カード配置 (%d,%d)" % [pos.x, pos.y])
	if _land_reward_panel != null:
		_land_reward_panel.queue_free()
		_land_reward_panel = null

func _remove_flag(flag: EconRallyFlag) -> void:

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



func _build_initial_deck(all_cards_array: Array, deck_spec: Array) -> Array:
	var card_by_id: Dictionary = {}
	for card in all_cards_array:
		if not (card is Dictionary):
			continue
		var card_id: String = str(card.get("id", ""))
		if card_id == "":
			continue
		card_by_id[card_id] = card

	var deck: Array = []
	for entry in deck_spec:
		var card_id: String = str(entry.get("id", ""))
		var count: int = int(entry.get("count", 0))
		if not card_by_id.has(card_id):
			push_warning("[EconMain] INITIAL_DECK missing card id: %s" % card_id)
			continue
		for _i in range(count):
			deck.append(card_by_id[card_id].duplicate(true))
	return deck

func _setup_deck_manager() -> void:

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
	if not parsed.has("INITIAL_DECK"):
		_add_log("[DeckManager] INITIAL_DECK not found in cards_econ.json")
		return
	var initial_deck: Array = _build_initial_deck(parsed["cards"], parsed["INITIAL_DECK"])

	_battle.setup_deck(initial_deck, _on_card_drawn)
	print("[EconMain] _setup_deck_manager: %d cards loaded" % initial_deck.size())

func _on_card_drawn(card: Dictionary) -> void:

	_refresh_hand_ui()

	if _footer_ui != null:
		_footer_ui.trigger_draw_flash()
	else:
		_draw_flash_timer = 0.1

func _on_hand_scroll_left() -> void:
	if _hand_scroll_offset > 0:
		_hand_scroll_offset -= 1
		_refresh_hand_ui()

func _on_hand_scroll_right() -> void:
	if _battle.deck_manager == null:
		return
	var hand_size: int = int(_battle.deck_manager.hand.size())
	if _hand_scroll_offset + HAND_DISPLAY_COUNT < hand_size:
		_hand_scroll_offset += 1
		_refresh_hand_ui()

func _refresh_hand_ui() -> void:
	if _footer_ui == null or _battle.deck_manager == null:
		return
	var hand_size: int = int(_battle.deck_manager.hand.size())
	_hand_scroll_offset = clampi(_hand_scroll_offset, 0, max(0, hand_size - HAND_DISPLAY_COUNT))
	var display_count: int = mini(HAND_DISPLAY_COUNT, hand_size - _hand_scroll_offset)
	var card_nodes: Array = []
	for i in range(display_count):
		var actual_idx: int = _hand_scroll_offset + i
		var card_data: Dictionary = _battle.deck_manager.hand[actual_idx]
		card_nodes.append(_create_hand_card_node(card_data, actual_idx, false))
	_footer_ui.set_hand_cards(card_nodes)
	_footer_ui.update_hand_arrows(_hand_scroll_offset, hand_size)
	_footer_ui.update_deck_discard_counts(
		int(_battle.deck_manager.deck.size()),
		int(_battle.deck_manager.discard_pile.size())
	)

func _generate_card_description(card: Dictionary) -> String:
	var btype: String = card.get("building_type", "")
	match btype:
		"HOUSE":
			var supply: int = int(card.get("population_supply", 3))
			return "人口上限+%d" % supply
		"BARRACKS":
			return "兵力+1 / %.0fsec" % EconBuilding.BARRACKS_PRODUCE_INTERVAL
		"FORTRESS":
			return "防衛+1 / %.0fsec" % EconBuilding.FORTRESS_PRODUCE_INTERVAL
		"VILLAGE":
			return "パネル資源 / %.1fsec" % EconBuilding.VILLAGE_INTERVAL
		"SAWMILL":
			return "木材+パネル / %.1fsec" % EconBuilding.SAWMILL_PRODUCE_INTERVAL
		"MINE":
			return "石材+パネル / %.1fsec" % EconBuilding.MINE_PRODUCE_INTERVAL
		"DINER":
			return "食料+%d / %.0fsec" % [EconBuilding.DINER_FOOD_GAIN, EconBuilding.DINER_INTERVAL]
		"PLAZA":
			return "満足度+Lv / 隣接住居+1"
		"TRADE_POST":
			return "消費10回でドロー+1"
		"EXCHANGE":
			return "資源交換所"
		"SMITHY":
			return "隣接兵舎DPS+10%%"
		"WATCHTOWER":
			return "範囲%d防衛・壁回復" % EconBuilding.WATCHTOWER_RANGE_LV1
		"MILL":
			return "小麦%d→%d / %.0fsec" % [EconBuilding.MILL_WHEAT_COST, EconBuilding.MILL_WHEAT_GAIN, EconBuilding.MILL_INTERVAL]
	return card.get("description", "")

func _count_in_construction_queue(btype_str: String) -> int:
	if _battle == null or _battle.grid == null:
		return 0
	if btype_str == "":
		return 0
	var count := 0
	for pos in _battle.grid.construction_sites:
		var site: Dictionary = _battle.grid.construction_sites[pos]
		var site_card: Dictionary = site.get("card", {})
		if str(site_card.get("building_type", "")) == btype_str:
			count += 1
	return count

func _create_hand_card_node(card_data: Dictionary, card_idx: int, in_queue: bool = false) -> Control:

	var card_btn := Button.new()
	card_btn.custom_minimum_size = Vector2(96, 140)
	card_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


	var state := _get_card_state(card_data)
	# 建設キューに入っているカードはグレーアウト・使用不可
	if in_queue:
		state = "queued"
		card_btn.disabled = true


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
		"queued":
			sb.border_color = Color(0.35, 0.35, 0.35, 1.0)
			sb.set_border_width_all(1)
			sb.bg_color = COLOR_PANEL.darkened(0.6)
		_:
			sb.border_color = COLOR_ACCENT_GOLD
			sb.set_border_width_all(2)
	card_btn.add_theme_stylebox_override("normal", sb)
	card_btn.add_theme_stylebox_override("hover", sb)
	card_btn.add_theme_stylebox_override("pressed", sb)


	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	card_btn.add_child(vbox)

	var icon_lbl := Label.new()
	icon_lbl.text = _get_card_icon(card_data.get("building_type", ""))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	icon_lbl.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = card_data.get("name", "?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(name_lbl)

	var cost_raw = card_data.get("cost")
	var cost: Dictionary = cost_raw if cost_raw is Dictionary else {}
	var cost_parts: Array = []
	if cost.get("wood", 0) > 0: cost_parts.append("木%d" % cost["wood"])
	if cost.get("stone", 0) > 0: cost_parts.append("石%d" % cost["stone"])
	if cost.get("resin", 0) > 0: cost_parts.append("樹%d" % cost["resin"])
	if cost.get("wheat", 0) > 0: cost_parts.append("小%d" % cost["wheat"])
	if cost.get("iron", 0) > 0: cost_parts.append("鉄%d" % cost["iron"])
	if cost.get("cotton", 0) > 0: cost_parts.append("綿%d" % cost["cotton"])
	var cost_lbl := Label.new()
	cost_lbl.text = " ".join(cost_parts) if not cost_parts.is_empty() else "Free"
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 10)
	var cost_color := COLOR_RED if state == "resource_short" else COLOR_TEXT_DIM
	cost_lbl.add_theme_color_override("font_color", cost_color)
	vbox.add_child(cost_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = _generate_card_description(card_data)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)


	var captured_card: Dictionary = card_data
	card_btn.pressed.connect(func():
		if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
			_add_log("突撃発動中: 建設停止")
			return
		var btype_str: String = captured_card.get("building_type", "")
		_selected_card_btype = btype_str
		_selected_card_idx = card_idx
		_add_log("Selected: %s" % captured_card.get("name", "?"))
		if _place_hint_label:
			_place_hint_label.visible = true
	)


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
		card_btn.accept_event()
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
	# 右クリック時は選択をキャンセル（手札順序変化による誤選択防止）
	_selected_card_idx = -1
	_selected_card_btype = ""
	# インデックス指定削除（discard_card_at は hand.remove_at を使うため内容比較なし）
	var discarded_card: Dictionary = _battle.deck_manager.discard_card_at(card_index)
	if discarded_card.is_empty():
		return
	print("[EconMain] _on_hand_card_right_clicked: discarded '%s'" % discarded_card.get("name", "?"))
	# DeckManager 経由でドロー（deck 空なら discard を reshuffle してドロー）
	var drawn_card: Dictionary = _battle.deck_manager.draw_card()
	if not drawn_card.is_empty():
		print("[EconMain] _on_hand_card_right_clicked: drew '%s'" % drawn_card.get("name", "?"))
	else:
		print("[EconMain] _on_hand_card_right_clicked: deck and discard both empty, no draw")
	# クールタイム開始
	_battle.deck_manager.start_reload_cooldown()
	# ログ記録
	if _log_manager != null and _log_manager.has_method("log_event"):
		_log_manager.log_event({
			"type": "HAND_CARD_REROLLED",
			"time": _elapsed_time,
			"discarded_card": discarded_card.get("id", ""),
			"drawn_card": drawn_card.get("id", "") if not drawn_card.is_empty() else "none",
		})
	# UI更新
	_refresh_hand_ui()

func _get_card_state(card_data: Dictionary) -> String:

	if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
		return "no_cell"
	var cost_raw = card_data.get("cost")
	var cost: Dictionary = cost_raw if cost_raw is Dictionary else {}
	var eco := _economy

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



func _on_early_charge_btn_pressed() -> void:

	_trigger_unified_charge()

func _trigger_unified_charge() -> void:

	if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
		return
	print("[EconMain] _trigger_unified_charge: activated")
	_battle.trigger_early_charge()
	_add_log("一斉突撃発動!")
	_charge_mode = true
	for u in _battle.player_units:
		if u.is_alive and u.is_idle:
			u.is_idle = false
	for f in _flags:
		f.is_assault_mode = true
		f.queue_redraw()

	var flash_rect := ColorRect.new()
	flash_rect.color = Color.WHITE
	flash_rect.modulate.a = 0.4
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(flash_rect)
	var tween := create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash_rect.queue_free)

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

# ===== F12 デバッグコンソール =====

func _create_debug_console() -> void:
	# パネル作成
	_debug_console_panel = PanelContainer.new()
	_debug_console_panel.custom_minimum_size = Vector2(400, 250)
	_debug_console_panel.position = Vector2(10, 10)
	_debug_console_panel.z_index = 9999
	_debug_console_panel.visible = false

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	panel_style.border_color = Color.GREEN
	panel_style.set_border_width_all(2)
	_debug_console_panel.add_theme_stylebox_override("panel", panel_style)

	# VBox：ログ + 入力
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_debug_console_panel.add_child(vbox)

	# ログ表示（TextEdit）
	_debug_console_log = TextEdit.new()
	_debug_console_log.custom_minimum_size = Vector2(380, 150)
	_debug_console_log.editable = false
	_debug_console_log.text = "[Debug Console]\nF12で開閉。入力フォーマット: WOOD 50 / STONE 20"
	var log_font_size := 11
	_debug_console_log.add_theme_font_size_override("font_size", log_font_size)
	vbox.add_child(_debug_console_log)

	# HBox：入力 + Apply
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(hbox)

	_debug_console_input = LineEdit.new()
	_debug_console_input.custom_minimum_size = Vector2(280, 30)
	_debug_console_input.placeholder_text = "WOOD 50"
	hbox.add_child(_debug_console_input)

	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(80, 30)
	apply_btn.pressed.connect(_on_debug_console_apply)
	hbox.add_child(apply_btn)

	_ui_layer.add_child(_debug_console_panel)

func _toggle_debug_console() -> void:
	if _debug_console_panel == null:
		return
	_debug_console_panel.visible = !_debug_console_panel.visible
	if _debug_console_panel.visible:
		_debug_console_input.grab_focus()

func _on_debug_console_apply() -> void:
	if _debug_console_input == null or _economy == null:
		return

	var cmd := _debug_console_input.text.strip_edges()
	if cmd.is_empty():
		return

	var parts := cmd.split(" ")
	if parts.size() < 2:
		_debug_log("エラー: フォーマット 'WOOD 50'")
		return

	var resource_name := parts[0].to_upper()
	var amount_str := parts[1]

	if not amount_str.is_valid_int():
		_debug_log("エラー: 数値が無効 '%s'" % amount_str)
		return

	var amount := int(amount_str)

	match resource_name:
		"WOOD":
			_economy.wood += amount
			_economy.resources["wood"] = _economy.wood
			_debug_log("WOOD +%d → %d" % [amount, _economy.wood])
		"STONE":
			_economy.stone += amount
			_economy.resources["stone"] = _economy.stone
			_debug_log("STONE +%d → %d" % [amount, _economy.stone])
		"RESIN":
			_economy.resin += amount
			_economy.resources["resin"] = _economy.resin
			_debug_log("RESIN +%d → %d" % [amount, _economy.resin])
		"IRON":
			_economy.iron += amount
			_economy.resources["iron"] = _economy.iron
			_debug_log("IRON +%d → %d" % [amount, _economy.iron])
		"COTTON":
			_economy.cotton += amount
			_economy.resources["cotton"] = _economy.cotton
			_debug_log("COTTON +%d → %d" % [amount, _economy.cotton])
		"CURRENCY":
			_economy.currency += amount
			_debug_log("Currency +%d → %d" % [amount, _economy.currency])
		_:
			_debug_log("エラー: 不明なリソース '%s'" % resource_name)

	_debug_console_input.text = ""
	print("[DebugConsole] 更新完了")

func _debug_log(msg: String) -> void:
	if _debug_console_log == null:
		return
	_debug_console_history.append(msg)
	if _debug_console_history.size() > 20:
		_debug_console_history.pop_front()
	_debug_console_log.text = "\n".join(_debug_console_history)


func _unhandled_input(event: InputEvent) -> void:
	if _zoom_ctrl != null and _zoom_ctrl.handle_input(event):
		get_viewport().set_input_as_handled()
