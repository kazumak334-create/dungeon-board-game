class_name EconMain
extends Node2D

var _grid: EconGrid
var _economy: EconEconomy
var _battle: EconBattle
var _ai: EconAI

var _ui_layer: CanvasLayer
var _ai_resource_label: Label
var _log_label: Label
var _status_label: Label

var _log_lines: Array = []
const MAX_LOG_LINES := 10

var _is_running: bool = false
var _selected_unit: EconUnit = null
var _guard_select_mode: bool = false
var _order_panel: PanelContainer = null
var _target_priority: int = 0  # 0=標準, 1=前線制圧, 2=経済破壊
var _place_hint_label: Label = null
var _charge_mode: bool = false  # 一斉突撃モード
var _flags: Array = []
var _next_flag_id: int = 0
var _connecting_building: EconBuilding = null
var _charge_btn: Button = null  # 旗ボタン

# v0.2 手札カード選択中の建設タイプ（文字列）
var _selected_card_btype: String = ""

# v0.2 HEADER / FOOTER UI要素
var _hand_container: HBoxContainer = null  # 手札コンテナ
var _hand_scroll_offset: int = 0           # スクロールオフセット（0-based）
var _hand_left_arrow: Button = null        # ◀矢印
var _hand_right_arrow: Button = null       # ▶矢印
var _draw_gauge_bar: ColorRect = null      # ドローゲージバー
var _draw_gauge_bg: ColorRect = null       # ドローゲージ背景
var _draw_gauge_label: Label = null        # ドローゲージサブテキスト
var _force_charge_segs: Array = []         # 強制突撃ゲージセグメント×10
var _force_charge_turn_label: Label = null  # N/10 表示
var _force_charge_warn_label: Label = null  # 突撃準備推奨ラベル
var _early_charge_btn: Button = null        # 早期突撃ボタン
var _deck_count_label: Label = null         # DECK 残枚数
var _discard_count_label: Label = null      # DISCARD 枚数

# v0.2 HEADER 上段ステータスUI（§3.3〜§3.6）
var _pop_gauge_bar: ColorRect = null        # 人口ゲージバー
var _pop_label: Label = null               # 人口 N/M
var _pop_preview_label: Label = null        # [+3] プレビュー
var _status_sat_label: Label = null        # Sat 0
var _troop_gauge_bar: ColorRect = null     # 兵力ゲージバー
var _troop_label: Label = null             # 兵力数値
var _gold_label: Label = null              # 資金 NG
var _status_food_label: Label = null       # 食料

# v0.2 HEADER 下段資源ラベル辞書
var _res_labels: Dictionary = {}           # key=資源名, value=Label

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
# UI仕様書 §1.4 v0.2 新規色定数
const COLOR_POP        := Color("#5D8FB8")  # 人口ゲージ青系
const COLOR_SAT        := Color("#B89AC7")  # 満足度パープル系（v0.3）
const COLOR_TROOP      := Color("#B85A3C")  # 兵力ゲージ赤茶
const COLOR_GOLD_COIN  := Color("#E0C060")  # 資金コイン（明るい金）
# 既存継続色
const COLOR_ACCENT_GOLD_BRIGHT := Color("#D4B468")  # ドローゲージ満タン近
const COLOR_ORANGE := Color("#C77A2C")              # 強制突撃ゲージ警戒
const COLOR_RED    := Color("#9C3A2A")              # 危険・人口満タン・警告

func _ready() -> void:
	_setup_grid()
	_setup_economy()
	_setup_battle()
	# origin を先に確定 → エンティティ配置はすべてこの後
	var vp := get_viewport().get_visible_rect().size
	const HEADER_H := 80.0   # v0.2 拡張（56→80）
	const FOOTER_H := 120.0  # v0.2 縮小（180→120）
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
	# v0.2 初期化（§9.1）
	_economy.initialize_v0_2()

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
						_battle.spawn_player_harvester(Vector2i(pos.x, pos.y), _economy)
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

func _setup_ui(vp: Vector2) -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)

	# === HEADER (y=0, h=80, v0.2 2段構成 §3.1) ===
	_setup_header_ui(vp)

	# === FOOTER (y=500, h=220, v0.2 §4.1) ===
	_setup_footer_ui(vp)

	# Place-on-board hint (盤面上フローティング)
	_place_hint_label = Label.new()
	_place_hint_label.text = "▶ place on board"
	_place_hint_label.position = Vector2(vp.x - 180.0, vp.y - 240.0)
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

func _setup_header_ui(vp: Vector2) -> void:
	# §3.1 HEADER (y=0, h=80) 2段構成
	var header := PanelContainer.new()
	header.position = Vector2.ZERO
	header.custom_minimum_size = Vector2(vp.x, 80)
	_ui_layer.add_child(header)
	var hdr_vbox := VBoxContainer.new()
	hdr_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hdr_vbox.add_theme_constant_override("separation", 2)
	header.add_child(hdr_vbox)

	# --- 上段 (y=4, h=36): 人口・満足度・兵力・資金 §3.2 ---
	var row1 := HBoxContainer.new()
	row1.custom_minimum_size = Vector2(0, 36)
	row1.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row1.add_theme_constant_override("separation", 4)
	hdr_vbox.add_child(row1)

	# §3.3 人口 (x=8, w=200)
	_setup_pop_card(row1)

	# §3.4 満足度 (x=216, w=200)
	var sat_card := _make_status_card(200, 36)
	row1.add_child(sat_card)
	var sat_icon := Label.new()
	sat_icon.text = ":)"
	sat_icon.add_theme_font_size_override("font_size", 16)
	sat_icon.add_theme_color_override("font_color", COLOR_SAT)
	sat_card.add_child(sat_icon)
	var sat_vbox := VBoxContainer.new()
	sat_card.add_child(sat_vbox)
	var sat_lbl_title := Label.new()
	sat_lbl_title.text = "SATISFACTION (v0.3)"
	sat_lbl_title.add_theme_font_size_override("font_size", 9)
	sat_lbl_title.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	sat_vbox.add_child(sat_lbl_title)
	_status_sat_label = Label.new()
	_status_sat_label.text = "0"
	_status_sat_label.add_theme_font_size_override("font_size", 12)
	_status_sat_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	sat_vbox.add_child(_status_sat_label)

	# §3.5 兵力 (x=424, w=200)
	_setup_troop_card(row1)

	# §3.6 資金 (x=632, w=200)
	_setup_gold_card(row1)

	# 右端コントロールボタン群
	var ctrl_spacer := Control.new()
	ctrl_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(ctrl_spacer)

	_status_label = Label.new()
	_status_label.text = "Setup"
	_status_label.add_theme_font_size_override("font_size", 10)
	row1.add_child(_status_label)

	_charge_btn = Button.new()
	_charge_btn.text = "[Wait] Idle"
	_charge_btn.pressed.connect(_on_charge_btn_pressed)
	row1.add_child(_charge_btn)

	var btn_start_hdr := Button.new()
	btn_start_hdr.text = "Start"
	btn_start_hdr.pressed.connect(_on_start_pressed)
	row1.add_child(btn_start_hdr)

	# --- 下段 (y=44, h=32): 資源6+食料 | ドロー | 強制突撃 | EARLY §3.7〜§3.10 ---
	var row2 := HBoxContainer.new()
	row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row2.add_theme_constant_override("separation", 4)
	hdr_vbox.add_child(row2)

	# §3.7 資源6種 (x=8, 各40px)
	var res_keys   := ["wood", "stone", "sulfur", "wheat", "iron", "cotton"]
	var res_icons  := ["木", "石", "硫", "小", "鉄", "綿"]
	var res_colors := [COLOR_WOOD, COLOR_STONE, COLOR_SULFUR, COLOR_WHEAT, COLOR_STONE, COLOR_TEXT]
	_res_labels = {}
	for ri in range(res_keys.size()):
		var rc := VBoxContainer.new()
		rc.custom_minimum_size = Vector2(40, 0)
		rc.alignment = BoxContainer.ALIGNMENT_CENTER
		row2.add_child(rc)
		var ri_lbl := Label.new()
		ri_lbl.text = res_icons[ri]
		ri_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ri_lbl.add_theme_font_size_override("font_size", 10)
		ri_lbl.add_theme_color_override("font_color", res_colors[ri])
		rc.add_child(ri_lbl)
		var rv_lbl := Label.new()
		rv_lbl.text = "5"
		rv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rv_lbl.add_theme_font_size_override("font_size", 10)
		rv_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		rc.add_child(rv_lbl)
		_res_labels[res_keys[ri]] = rv_lbl

	# 区切り
	var res_sep := VSeparator.new()
	res_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(res_sep)

	# §3.7 食料 (x=310, w=60)
	var food_c := VBoxContainer.new()
	food_c.custom_minimum_size = Vector2(48, 0)
	food_c.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_child(food_c)
	var food_icon := Label.new()
	food_icon.text = "食"
	food_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	food_icon.add_theme_font_size_override("font_size", 10)
	food_icon.add_theme_color_override("font_color", COLOR_WHEAT)
	food_c.add_child(food_icon)
	_status_food_label = Label.new()
	_status_food_label.text = "30"
	_status_food_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_food_label.add_theme_font_size_override("font_size", 10)
	_status_food_label.add_theme_color_override("font_color", COLOR_WHEAT)
	food_c.add_child(_status_food_label)

	# §3.7 AI資源（補助情報）
	_ai_resource_label = Label.new()
	_ai_resource_label.text = "E:W0 St0 Su0 Wh0"
	_ai_resource_label.add_theme_font_size_override("font_size", 9)
	_ai_resource_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	row2.add_child(_ai_resource_label)

	var mid_spacer := Control.new()
	mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(mid_spacer)

	# §3.8 ドローゲージ (x=320, w=180, h=20)
	var dg_c := VBoxContainer.new()
	dg_c.custom_minimum_size = Vector2(160, 0)
	dg_c.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_child(dg_c)
	var dg_lbl := Label.new()
	dg_lbl.text = "Draw"
	dg_lbl.add_theme_font_size_override("font_size", 9)
	dg_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dg_c.add_child(dg_lbl)
	var dg_bar_bg := ColorRect.new()
	dg_bar_bg.custom_minimum_size = Vector2(160, 10)
	dg_bar_bg.color = COLOR_PANEL
	dg_c.add_child(dg_bar_bg)
	_draw_gauge_bg = dg_bar_bg
	_draw_gauge_bar = ColorRect.new()
	_draw_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_draw_gauge_bar.size = Vector2(0, 10)
	_draw_gauge_bar.color = COLOR_ACCENT_GOLD
	dg_bar_bg.add_child(_draw_gauge_bar)
	_draw_gauge_label = Label.new()
	_draw_gauge_label.text = "30s"
	_draw_gauge_label.add_theme_font_size_override("font_size", 9)
	_draw_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dg_c.add_child(_draw_gauge_label)

	# §3.9 強制突撃ゲージ (w=400, 10分割)
	var fc_c := VBoxContainer.new()
	fc_c.custom_minimum_size = Vector2(360, 0)
	fc_c.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_child(fc_c)
	var fc_lbl := Label.new()
	fc_lbl.text = "Force"
	fc_lbl.add_theme_font_size_override("font_size", 8)
	fc_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	fc_c.add_child(fc_lbl)
	var fc_segs_row := HBoxContainer.new()
	fc_segs_row.add_theme_constant_override("separation", 2)
	fc_c.add_child(fc_segs_row)
	_force_charge_segs = []
	for si in range(10):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(32, 14)
		seg.color = COLOR_PANEL
		fc_segs_row.add_child(seg)
		_force_charge_segs.append(seg)
	_force_charge_turn_label = Label.new()
	_force_charge_turn_label.text = "0/10"
	_force_charge_turn_label.add_theme_font_size_override("font_size", 9)
	_force_charge_turn_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	fc_c.add_child(_force_charge_turn_label)

	_force_charge_warn_label = Label.new()
	_force_charge_warn_label.text = "突撃推奨"
	_force_charge_warn_label.add_theme_font_size_override("font_size", 9)
	_force_charge_warn_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_force_charge_warn_label.visible = false
	row2.add_child(_force_charge_warn_label)

	# §3.10 EARLY CHARGE ボタン (w=120)
	_early_charge_btn = Button.new()
	_early_charge_btn.text = "EARLY CHARGE"
	_early_charge_btn.custom_minimum_size = Vector2(120, 28)
	var ec_sb := StyleBoxFlat.new()
	ec_sb.bg_color = COLOR_PANEL
	ec_sb.border_color = COLOR_BORDER
	ec_sb.set_border_width_all(1)
	ec_sb.set_corner_radius_all(3)
	_early_charge_btn.add_theme_stylebox_override("normal", ec_sb)
	_early_charge_btn.add_theme_font_size_override("font_size", 11)
	_early_charge_btn.add_theme_color_override("font_color", COLOR_TEXT)
	_early_charge_btn.pressed.connect(_on_early_charge_btn_pressed)
	row2.add_child(_early_charge_btn)

func _setup_pop_card(parent: Control) -> void:
	# §3.3 人口カード (w=200, h=36)
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
	# §3.5 兵力カード (w=200, h=36)
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
	# §3.6 資金カード (w=200, h=36)
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
	# §3.2 水平カード型ステータスパネル共通
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
	# §4.1 FOOTER (y=500, h=220)
	var footer := PanelContainer.new()
	footer.position = Vector2(0, vp.y - 220.0)
	footer.custom_minimum_size = Vector2(vp.x, 220)
	_ui_layer.add_child(footer)
	var ftr_hbox := HBoxContainer.new()
	ftr_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ftr_hbox.add_theme_constant_override("separation", 4)
	footer.add_child(ftr_hbox)

	# 左ブロック (x=8, w=120): Deck / Discard §4.3
	_setup_deck_discard_block(ftr_hbox)

	var ftr_sep1 := VSeparator.new()
	ftr_sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ftr_hbox.add_child(ftr_sep1)

	# 中央ブロック (x=140, w=920): 手札 §4.2
	_setup_hand_center_block(ftr_hbox)

	var ftr_sep2 := VSeparator.new()
	ftr_sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ftr_hbox.add_child(ftr_sep2)

	# 右ブロック (x=1072, w=200): EVENT SELECT §4.4
	_setup_event_block(ftr_hbox)

func _setup_deck_discard_block(parent: Control) -> void:
	# §4.3 Deck / Discard 左ブロック
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(120, 0)
	vb.add_theme_constant_override("separation", 4)
	parent.add_child(vb)

	# DECK
	var deck_panel := PanelContainer.new()
	deck_panel.custom_minimum_size = Vector2(104, 88)
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
	_deck_count_label.text = "残13"
	_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_count_label.add_theme_font_size_override("font_size", 14)
	_deck_count_label.add_theme_color_override("font_color", COLOR_TEXT)
	dp_vb.add_child(_deck_count_label)

	# DISCARD
	var disc_panel := PanelContainer.new()
	disc_panel.custom_minimum_size = Vector2(104, 88)
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
	dsc_icon.text = "—"
	dsc_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dsc_icon.add_theme_font_size_override("font_size", 18)
	dsc_icon.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dsc_vb.add_child(dsc_icon)
	_discard_count_label = Label.new()
	_discard_count_label.text = "0枚"
	_discard_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_count_label.add_theme_font_size_override("font_size", 10)
	_discard_count_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dsc_vb.add_child(_discard_count_label)

func _setup_hand_center_block(parent: Control) -> void:
	# §4.2 手札中央ブロック (w=920, 6枚表示+スクロール矢印)
	var center_block := VBoxContainer.new()
	center_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_block.add_theme_constant_override("separation", 2)
	parent.add_child(center_block)

	# 矢印+カード行
	var hand_row := HBoxContainer.new()
	hand_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_row.add_theme_constant_override("separation", 4)
	center_block.add_child(hand_row)

	_hand_left_arrow = Button.new()
	_hand_left_arrow.text = "◀"
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
	_hand_right_arrow.text = "▶"
	_hand_right_arrow.custom_minimum_size = Vector2(40, 64)
	_hand_right_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hand_right_arrow.modulate.a = 0.3
	_hand_right_arrow.pressed.connect(_on_hand_scroll_right)
	hand_row.add_child(_hand_right_arrow)

func _setup_event_block(parent: Control) -> void:
	# §4.4 Event Select 右ブロック（ロック状態）
	var ev_panel := PanelContainer.new()
	ev_panel.custom_minimum_size = Vector2(200, 0)
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
	ev_title.text = "EVENT SELECT"
	ev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_title.add_theme_font_size_override("font_size", 10)
	ev_title.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	ev_vb.add_child(ev_title)
	# 2×2 グリッド
	var ev_grid := GridContainer.new()
	ev_grid.columns = 2
	ev_grid.add_theme_constant_override("h_separation", 4)
	ev_grid.add_theme_constant_override("v_separation", 4)
	ev_vb.add_child(ev_grid)
	for _ei in range(4):
		var cell_panel := PanelContainer.new()
		cell_panel.custom_minimum_size = Vector2(88, 72)
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
	ev_sub.text = "v0.3 開放"
	ev_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_sub.add_theme_font_size_override("font_size", 9)
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
	if mouse_y < 80.0 or mouse_y > vp_h - 220.0:  # v0.2: HEADER=80, FOOTER=220
		return
	var local_pos: Vector2 = _grid.to_local(get_global_mouse_position())
	var cell := _pixel_to_hex(local_pos)
	# 旗クリック検出（接続モード中）
	if _connecting_building != null:
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
				_add_log("Building (%d,%d) → Flag %d" % [b.grid_pos.x, b.grid_pos.y, f.flag_id])
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
	# 手札カード選択後の建設モード（v0.2 hand→board 配置）
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
		_selected_card_btype = ""
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

func _place_building_from_card(cell: Vector2i, btype_str: String) -> void:
	# v0.2 手札カードから建物を配置（§4.2 手札→盤面ドロップ）
	var btype_map: Dictionary = {
		"BARRACKS":        EconBuilding.BuildingType.BARRACKS,
		"HOUSE":           EconBuilding.BuildingType.VILLAGE,
		"LIBRARY":         EconBuilding.BuildingType.TRADE_POST,
		"MARKET":          EconBuilding.BuildingType.TRADE_POST,
		"WOOD_EXTRACTOR":  EconBuilding.BuildingType.SAWMILL,
		"STONE_EXTRACTOR": EconBuilding.BuildingType.MINE,
		"SULFUR_EXTRACTOR":EconBuilding.BuildingType.MINE,
		"WHEAT_EXTRACTOR": EconBuilding.BuildingType.VILLAGE,
		"IRON_EXTRACTOR":  EconBuilding.BuildingType.MINE,
		"COTTON_EXTRACTOR":EconBuilding.BuildingType.VILLAGE,
	}
	if not btype_map.has(btype_str):
		_add_log("Unknown building type: %s" % btype_str)
		return
	var btype: int = int(btype_map[btype_str])
	# 自建物のいずれかから半径3hex以内チェック
	var in_range := false
	for pb in _battle.player_buildings:
		if pb.is_alive and _grid.hex_distance(cell, pb.grid_pos) <= 3:
			in_range = true
			break
	if not in_range:
		_add_log("自建物から半径3hex以内にのみ建設できます")
		return
	var b := EconBuilding.new()
	b.setup(btype, cell, true)
	b.position = _grid.hex_to_pixel(cell.x, cell.y)
	b.unit_produced.connect(func(pos: Vector2i, utype: int):
		if utype == -1:
			_battle.spawn_player_harvester(Vector2i(pos.x, pos.y), _economy)
		elif _charge_mode:
			_battle.spawn_player_unit(pos.x, pos.y, utype, _charge_mode)
			_battle._on_unit_produced(pos, utype)
		else:
			var idle_count: int = 0
			for u in _battle.player_units:
				if u.is_alive and u.is_idle and u.grid_pos == pos:
					idle_count += 1
			if idle_count < EconGrid.MAX_STACK:
				_battle.spawn_player_unit(pos.x, pos.y, utype, _charge_mode)
				_battle._on_unit_produced(pos, utype)
	)
	b.building_destroyed.connect(func(building: Node):
		_battle._on_building_destroyed(building)
	)
	_battle.register_player_building(b)
	_add_log("%s placed at (%d,%d)" % [btype_str, cell.x, cell.y])


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
	# v0.2 資源ラベル辞書更新（§3.7）
	for res_key in _res_labels.keys():
		var lbl: Label = _res_labels[res_key]
		lbl.text = "%d" % _economy.resources.get(res_key, 0)
	if _ai != null and _ai.economy != null:
		var eco := _ai.economy
		_ai_resource_label.text = "W:%d St:%d Su:%d Wh:%d" % [eco.wood, eco.stone, eco.sulfur, eco.wheat]
	# v0.2 highlight更新（建設モードなし → 領土表示のみ）
	_update_territory_highlight()
	# v0.2 ステータスUI更新（§5.1）
	_update_status_ui()
	# ドロー・ゲージ・人口UI更新（§5 pull型）
	_update_draw_gauge_ui(delta)
	_update_force_charge_gauge_ui(delta)
	_update_population_ui()

func _update_territory_highlight() -> void:
	# v0.2: 建設モード廃止により fill_cells は常に空。領土表示のみ更新。
	_grid.highlight_cells.clear()
	_grid.fill_cells.clear()
	_grid.resource_highlight_type = EconGrid.ResourceType.NONE
	# highlight_cells: 建設済みplayer_buildingsから半径3の和集合
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
	# enemy_territory_cells: 建設済みenemy_buildingsから半径3の和集合
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
	# 手札UIを再構築（§4.2 スクロール対応・6枚表示）
	if _hand_container == null:
		return
	for child in _hand_container.get_children():
		child.queue_free()
	if _battle.deck_manager == null:
		return
	var hand_size: int = int(_battle.deck_manager.hand.size())
	# スクロールオフセット範囲補正
	_hand_scroll_offset = clampi(_hand_scroll_offset, 0, max(0, hand_size - 6))
	# 6枚表示（offset〜offset+5）
	var display_count: int = mini(6, hand_size - _hand_scroll_offset)
	for i in range(display_count):
		var actual_idx: int = _hand_scroll_offset + i
		var card_data: Dictionary = _battle.deck_manager.hand[actual_idx]
		var card_node := _create_hand_card_node(card_data, actual_idx)
		_hand_container.add_child(card_node)
	# 矢印 enabled 更新 §4.2.4
	if _hand_left_arrow != null:
		_hand_left_arrow.modulate.a = 1.0 if _hand_scroll_offset > 0 else 0.3
	if _hand_right_arrow != null:
		_hand_right_arrow.modulate.a = 1.0 if (_hand_scroll_offset + 6 < hand_size) else 0.3
	# デッキ・捨て札表示更新 §4.3
	if _deck_count_label != null:
		_deck_count_label.text = "残%d" % int(_battle.deck_manager.deck.size())
	if _discard_count_label != null:
		_discard_count_label.text = "%d枚" % int(_battle.deck_manager.discard_pile.size())

func _create_hand_card_node(card_data: Dictionary, card_idx: int) -> Control:
	# §5.2.1 手札カード1枚のノードを生成（96×112px・v0.2 縮小）
	var card_btn := Button.new()
	card_btn.custom_minimum_size = Vector2(96, 112)
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
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	icon_lbl.custom_minimum_size = Vector2(0, 44)  # §5.2.2 サムネ44px
	vbox.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = card_data.get("name", "?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)  # §5.2.2 10px太字
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

	# クリックで建設モード起動（v0.2 §4.2 手札→盤面配置）
	var captured_card: Dictionary = card_data
	card_btn.pressed.connect(func():
		if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
			_add_log("突撃発動中: 建設停止")
			return
		var btype_str: String = captured_card.get("building_type", "")
		_selected_card_btype = btype_str
		_add_log("手札: %s を選択（盤面クリックで配置）" % captured_card.get("name", "?"))
		if _place_hint_label:
			_place_hint_label.visible = true
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
	# §5.2.3 状態決定ツリー（優先順位降順）
	if _battle.deck_manager != null and bool(_battle.deck_manager.force_charge_triggered):
		return "no_cell"
	var cost_raw = card_data.get("cost")
	var cost: Dictionary = cost_raw if cost_raw is Dictionary else {}
	var eco := _economy
	# 人口チェック
	var pop_req: int = card_data.get("population_required", 0)
	if eco.population_used + pop_req > eco.population_cap:
		return "pop_short"
	# 資源チェック（v0.2 resources辞書を使用）
	for res_key in cost.keys():
		if cost.get(res_key, 0) > eco.resources.get(res_key, 0):
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

# _setup_deck_gauge_ui / _setup_hand_ui は v0.2 で廃止（_setup_header_ui / _setup_footer_ui に統合）

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
		sub_text = "MAX (8/8)"
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

	# ゲージバーは親ColorRect(bg)の幅に対して相対的に伸縮
	var bg_w: float = _draw_gauge_bg.size.x if _draw_gauge_bg.size.x > 0.0 else 160.0
	_draw_gauge_bar.size = Vector2(bg_w * progress, _draw_gauge_bg.size.y)
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
	var pbg_w: float = _pop_gauge_bar.get_parent().size.x if _pop_gauge_bar.get_parent() != null and _pop_gauge_bar.get_parent().size.x > 0.0 else 80.0
	_pop_gauge_bar.size = Vector2(pbg_w * clampf(ratio, 0.0, 1.0), _pop_gauge_bar.size.y)
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

func _update_status_ui() -> void:
	# §5.1 HEADER ステータスUI 毎フレーム更新（v0.2）
	# 満足度（§3.4）
	if _status_sat_label != null:
		_status_sat_label.text = "Sat %d" % _economy.satisfaction
	# 兵力（§3.5）
	if _troop_label != null:
		var mil_int: int = int(floor(_economy.military_power))
		_troop_label.text = "%d" % mil_int
		var mil_color := COLOR_TROOP if mil_int > 0 else COLOR_TEXT_DIM
		_troop_label.add_theme_color_override("font_color", mil_color)
	# 兵力ゲージ（§3.5）
	if _troop_gauge_bar != null:
		var troop_ratio: float = clampf(float(_economy.military_power) / 20.0, 0.0, 1.0)
		var tbg_w: float = _troop_gauge_bar.get_parent().size.x if _troop_gauge_bar.get_parent() != null and _troop_gauge_bar.get_parent().size.x > 0.0 else 80.0
		_troop_gauge_bar.size = Vector2(tbg_w * troop_ratio, _troop_gauge_bar.size.y)
	# 資金（§3.6）
	if _gold_label != null:
		_gold_label.text = "%dG" % _economy.currency
		var cur_color := COLOR_TEXT_DIM if _economy.currency <= 0 else COLOR_GOLD_COIN
		_gold_label.add_theme_color_override("font_color", cur_color)
	# 食料（§3.7）
	if _status_food_label != null:
		_status_food_label.text = "食%d" % _economy.food
		var food_color := COLOR_RED if _economy.food < 5 else COLOR_WHEAT
		_status_food_label.add_theme_color_override("font_color", food_color)

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
