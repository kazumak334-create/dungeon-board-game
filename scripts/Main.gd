# Main.gd
# メインシーン制御・UI描画・ゲームループ
extends Node

const BoardManagerScript   = preload("res://scripts/BoardManager.gd")
const DeckManagerScript    = preload("res://scripts/DeckManager.gd")
const EnemyAIScript        = preload("res://scripts/EnemyAI.gd")
const EventQueueScript     = preload("res://scripts/EventQueue.gd")
const SpellExecutorScript  = preload("res://scripts/SpellExecutor.gd")
var EffectExecutorScript = null  # 遅延ロード（preloadだとコンパイル時にフリーズ）

# ---- レイアウト定数 ----
const CELL_W    := 115
const CELL_H    := 95
const BOARD_TOP := 110   # 盤面上端Y

# 盤面X原点（画面中央を基準に左右対称）
# 画面幅1280, 中央=640
# 自陣: col0=後列(左端) → col2=前列(右端=中央側)
# 敵陣: col0=前列(左端=中央側) → col2=後列(右端)
# 中央GAP=20
const CENTER_X  := 640
const GAP       := 20    # 中央の隙間（自陣前列と敵陣前列の間）

# 自陣: 前列(col2)の右端 = CENTER_X - GAP/2
# 自陣: col2のX = CENTER_X - GAP/2 - CELL_W
# 自陣: col1のX = CENTER_X - GAP/2 - CELL_W*2
# 自陣: col0のX = CENTER_X - GAP/2 - CELL_W*3
const PLAYER_FRONT_X := CENTER_X - GAP / 2 - CELL_W  # 自陣前列左端X
# 敵陣: 前列(col0)の左端 = CENTER_X + GAP/2
const ENEMY_FRONT_X  := CENTER_X + GAP / 2            # 敵陣前列左端X

# ---- ノード ----
var board_manager: Node
var deck_manager: Node
var enemy_ai: Node

var base_hp: Array = [30, 30]

var cell_rects:  Array = []
var cell_labels: Array = []
var _cell_tooltip_panel: PanelContainer = null
var _cell_tooltip_label: Label = null

var mana_bar_cells: Array = []  # マナバー格子
var mana_value_label: Label
var next_card_panel: ColorRect
var next_card_name_label: Label
var next_card_detail_label: Label
var next_card_cost_label: Label
var next_card_timer_label: Label
var enemy_next_label: Label

var player_base_label: Label
var enemy_base_label:  Label
var log_label:         Label
var game_over_label:   Label
var restart_button:    Button
var deck_count_label:  Label
var discard_count_label: Label
var enemy_deck_count_label: Label

var dev_mode: bool = false
var dev_ui: RefCounted = null  # DevUI インスタンス
var mode_select_panel: Control = null  # モード選択画面
var game_started: bool = false
var game_paused: bool = false

var game_over: bool = false
var log_lines: Array  = []

var skill_flash_timers: Array = []  # [side][row][col] -> float
var skill_flash_names:  Array = []  # [side][row][col] -> String
var _cell_dirty:        Array = []  # [side][row][col] -> bool（UI更新フラグ）
var _support_log_timer: float = 5.0

# ---- 初期化 ----
func _ready() -> void:
	var event_queue = Node.new()
	event_queue.set_script(EventQueueScript)
	add_child(event_queue)

	board_manager = Node.new()
	board_manager.set_script(BoardManagerScript)
	add_child(board_manager)
	board_manager.event_queue = event_queue
	board_manager.base_hp_ref = base_hp
	board_manager.unit_placed.connect(_on_unit_placed)
	board_manager.unit_died.connect(_on_unit_died)
	board_manager.unit_revived.connect(_on_unit_revived)
	board_manager.unit_damaged.connect(_on_unit_damaged)
	board_manager.base_damaged.connect(_on_base_damaged)
	board_manager.active_skill_used.connect(_on_active_skill_used)
	board_manager.status_damage.connect(_on_status_damage)
	board_manager.status_cleared.connect(_on_status_cleared)
	board_manager.draw_cards_requested.connect(_on_draw_cards_requested)
	board_manager.spell_cast.connect(_on_spell_cast)
	board_manager.synthesis_done.connect(_on_synthesis_done)

	deck_manager = Node.new()
	deck_manager.set_script(DeckManagerScript)
	add_child(deck_manager)

	enemy_ai = Node.new()
	enemy_ai.set_script(EnemyAIScript)
	add_child(enemy_ai)

	# SpellExecutor 初期化・注入
	var spell_executor = SpellExecutorScript.new()
	deck_manager.spell_executor = spell_executor
	deck_manager.enemy_ai_ref = enemy_ai
	enemy_ai.spell_executor = spell_executor
	enemy_ai.deck_manager_ref = deck_manager

	# EffectExecutor 初期化・注入（遅延ロード）
	EffectExecutorScript = load("res://scripts/EffectExecutor.gd")
	var effect_executor = EffectExecutorScript.new()
	board_manager.effect_executor = effect_executor
	board_manager.deck_manager_ref = deck_manager
	board_manager.enemy_ai_ref = enemy_ai
	spell_executor.effect_executor = effect_executor

	_build_synthesis_registry()
	_build_ui()
	_build_mode_select()
	# スキルフラッシュタイマー初期化
	skill_flash_timers = [
		[[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]],
		[[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	]
	skill_flash_names = [
		[["", "", ""], ["", "", ""], ["", "", ""]],
		[["", "", ""], ["", "", ""], ["", "", ""]]
	]
	# 全セル初回描画
	_cell_dirty = [
		[[true, true, true], [true, true, true], [true, true, true]],
		[[true, true, true], [true, true, true], [true, true, true]]
	]
	_add_log("=== Dungeon Board Game 起動 ===")

# ---- 盤面合成レジストリ ----
func _build_synthesis_registry() -> void:
	var _CardDB = load("res://scripts/CardDB.gd")
	var UnitDataScript = preload("res://scripts/UnitData.gd")
	for recipe in _CardDB.SYNTHESIS:
		var r = _CardDB.UNITS[recipe["result"]]
		var u = UnitDataScript.new()
		u.unit_name = recipe["result"]
		u.max_hp = r["hp"]; u.current_hp = r["hp"]
		u.attack = r["atk"]; u.attack_interval = r["interval"]
		u.cost = r["cost"]; u.assigned_col = r["col"]
		u.race = r.get("race", "スライム")
		u.attack_range = r.get("range", "1行")
		u.support_effect = ""; u.active_skill = ""
		u.skills = r.get("skills", []).duplicate(true)
		board_manager.synthesis_registry.append({
			"base": recipe["base"],
			"card": recipe["card"],
			"result": u,
		})


func _build_mode_select() -> void:
	mode_select_panel = Control.new()
	add_child(mode_select_panel)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.85)
	overlay.size = Vector2(1280, 720)
	mode_select_panel.add_child(overlay)

	var title := Label.new()
	title.text = "Dungeon Board Game"
	title.position = Vector2(390, 180)
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(0.9, 0.85, 0.55)
	mode_select_panel.add_child(title)

	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.position = Vector2(440, 320)
	play_btn.size = Vector2(400, 60)
	play_btn.add_theme_font_size_override("font_size", 28)
	play_btn.pressed.connect(_on_mode_play)
	mode_select_panel.add_child(play_btn)

	var dev_btn := Button.new()
	dev_btn.text = "開発者モード"
	dev_btn.position = Vector2(440, 400)
	dev_btn.size = Vector2(400, 60)
	dev_btn.add_theme_font_size_override("font_size", 28)
	dev_btn.pressed.connect(_on_mode_dev)
	mode_select_panel.add_child(dev_btn)

func _on_mode_play() -> void:
	mode_select_panel.queue_free()
	mode_select_panel = null
	game_started = true
	# バトル開始時にシャッフルカードをデッキ最下部に挿入
	deck_manager.ensure_shuffle_card()
	enemy_ai.ensure_shuffle_card()
	_add_log("=== PLAY モード開始 ===")

func _on_mode_dev() -> void:
	mode_select_panel.queue_free()
	mode_select_panel = null
	dev_mode = true
	game_started = true
	game_paused = true  # 一時停止状態で開始
	# 初期デッキを空にする（開発者モードは手動構築、シャッフルカードは常に最下部に存在）
	deck_manager.deck.clear()
	deck_manager.discard.clear()
	deck_manager.ensure_shuffle_card()
	var DevUIScript = load("res://scripts/DevUI.gd")
	dev_ui = DevUIScript.new()
	dev_ui.setup(self, board_manager, deck_manager, enemy_ai)
	_add_log("=== 開発者モード開始（一時停止・デッキ空）===")

# ---- UI構築 ----
func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.11)
	bg.size  = Vector2(1280, 720)
	add_child(bg)

	# タイトル
	var title := Label.new()
	title.text = "Dungeon Board Game  Phase 1 Prototype"
	title.position = Vector2(20, 8)
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color(0.9, 0.85, 0.55)
	add_child(title)

	# 中央ライン
	var line := ColorRect.new()
	line.color    = Color(0.4, 0.4, 0.5, 0.5)
	line.size     = Vector2(2, 3 * CELL_H + 10)
	line.position = Vector2(CENTER_X - 1, BOARD_TOP - 5)
	add_child(line)

	# 行ラベル（左端）
	var row_names := ["上", "中", "下"]
	for r in range(3):
		var lbl := Label.new()
		lbl.text     = row_names[r]
		lbl.position = Vector2(PLAYER_FRONT_X - CELL_W * 2 - 22, BOARD_TOP + r * CELL_H + 35)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.modulate = Color(0.6, 0.6, 0.6)
		add_child(lbl)

	# 列ラベル
	# 自陣: 後→中→前（左→右）
	var player_col_labels := ["後列", "中列", "前列"]
	for c in range(3):
		var x: int = _cell_x(0, c)
		var lbl := Label.new()
		lbl.text     = player_col_labels[c]
		lbl.position = Vector2(x + 28, BOARD_TOP - 20)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.5, 0.75, 1.0)
		add_child(lbl)

	# 敵陣: 前→中→後（左→右）
	var enemy_col_labels := ["前列", "中列", "後列"]
	for c in range(3):
		var x: int = _cell_x(1, c)
		var lbl := Label.new()
		lbl.text     = enemy_col_labels[c]
		lbl.position = Vector2(x + 28, BOARD_TOP - 20)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(1.0, 0.5, 0.5)
		add_child(lbl)

	# 自陣・敵陣ラベル
	var pl := Label.new()
	pl.text     = "自  陣"
	pl.position = Vector2(_cell_x(0, 0) + 60, BOARD_TOP - 40)
	pl.add_theme_font_size_override("font_size", 15)
	pl.modulate = Color(0.4, 0.8, 1.0)
	add_child(pl)

	var el := Label.new()
	el.text     = "敵  陣"
	el.position = Vector2(_cell_x(1, 0) + 60, BOARD_TOP - 40)
	el.add_theme_font_size_override("font_size", 15)
	el.modulate = Color(1.0, 0.45, 0.45)
	add_child(el)

	# セル生成
	cell_rects  = [[], []]
	cell_labels = [[], []]
	for side in range(2):
		for r in range(3):
			cell_rects[side].append([])
			cell_labels[side].append([])
			for c in range(3):
				var x: int = _cell_x(side, c)
				var rect := ColorRect.new()
				rect.size     = Vector2(CELL_W - 4, CELL_H - 4)
				rect.position = Vector2(x + 2, BOARD_TOP + r * CELL_H + 2)
				rect.color    = Color(0.13, 0.13, 0.2)
				rect.mouse_entered.connect(_on_cell_hover.bind(side, r, c))
				rect.mouse_exited.connect(_on_cell_hover_end)
				add_child(rect)
				cell_rects[side][r].append(rect)

				var lbl := Label.new()
				lbl.position  = rect.position + Vector2(5, 4)
				lbl.size      = rect.size - Vector2(6, 6)
				lbl.add_theme_font_size_override("font_size", 12)
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				add_child(lbl)
				cell_labels[side][r].append(lbl)

	# ---- 本体HP ----
	var base_y: int = BOARD_TOP + 3 * CELL_H + 12
	player_base_label = Label.new()
	player_base_label.position = Vector2(_cell_x(0, 0), base_y)
	player_base_label.add_theme_font_size_override("font_size", 14)
	player_base_label.modulate = Color(0.4, 0.9, 0.4)
	add_child(player_base_label)

	enemy_base_label = Label.new()
	enemy_base_label.position = Vector2(_cell_x(1, 0), base_y)
	enemy_base_label.add_theme_font_size_override("font_size", 14)
	enemy_base_label.modulate = Color(1.0, 0.45, 0.45)
	add_child(enemy_base_label)

	# 盤面セルホバー用ツールチップ
	_cell_tooltip_panel = PanelContainer.new()
	_cell_tooltip_panel.position = Vector2(10, 10)
	_cell_tooltip_panel.visible = false
	_cell_tooltip_panel.z_index = 90
	var tt_style := StyleBoxFlat.new()
	tt_style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	tt_style.border_color = Color(0.4, 0.5, 0.7)
	tt_style.set_border_width_all(1)
	tt_style.set_content_margin_all(8)
	_cell_tooltip_panel.add_theme_stylebox_override("panel", tt_style)
	_cell_tooltip_label = Label.new()
	_cell_tooltip_label.add_theme_font_size_override("font_size", 11)
	_cell_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cell_tooltip_label.custom_minimum_size = Vector2(250, 0)
	_cell_tooltip_panel.add_child(_cell_tooltip_label)
	add_child(_cell_tooltip_panel)

	# ---- マナバー ----
	_build_mana_bar()

	# ---- 次カードパネル ----
	_build_next_card_panel()

	# ---- ログ ----
	var log_bg := ColorRect.new()
	log_bg.position = Vector2(1020, BOARD_TOP - 10)
	log_bg.size     = Vector2(245, 3 * CELL_H + 30)
	log_bg.color    = Color(0.04, 0.04, 0.07)
	add_child(log_bg)

	var log_title := Label.new()
	log_title.text     = "ログ"
	log_title.position = Vector2(1028, BOARD_TOP - 6)
	log_title.modulate = Color(0.7, 0.7, 0.5)
	add_child(log_title)

	log_label = Label.new()
	log_label.position       = Vector2(1025, BOARD_TOP + 14)
	log_label.size           = Vector2(235, 3 * CELL_H)
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	log_label.modulate       = Color(0.78, 0.78, 0.78)
	add_child(log_label)

	# ---- ゲームオーバー ----
	game_over_label = Label.new()
	game_over_label.position = Vector2(340, 270)
	game_over_label.add_theme_font_size_override("font_size", 72)
	game_over_label.visible  = false
	add_child(game_over_label)

	restart_button = Button.new()
	restart_button.text     = "もう一度"
	restart_button.position = Vector2(540, 380)
	restart_button.size     = Vector2(200, 56)
	restart_button.add_theme_font_size_override("font_size", 26)
	restart_button.visible  = false
	restart_button.pressed.connect(_on_restart_pressed)
	add_child(restart_button)

func _build_mana_bar() -> void:
	var bar_y: int = BOARD_TOP + 3 * CELL_H + 42
	var bar_x: int = _cell_x(0, 0)

	var bar_title := Label.new()
	bar_title.text     = "Mana"
	bar_title.position = Vector2(bar_x, bar_y - 18)
	bar_title.add_theme_font_size_override("font_size", 12)
	bar_title.modulate = Color(1.0, 0.85, 0.2)
	add_child(bar_title)

	mana_bar_cells = []
	for i in range(10):
		var cell := ColorRect.new()
		cell.size     = Vector2(22, 18)
		cell.position = Vector2(bar_x + i * 25, bar_y)
		cell.color    = Color(0.2, 0.2, 0.1)
		add_child(cell)
		mana_bar_cells.append(cell)

	mana_value_label = Label.new()
	mana_value_label.position = Vector2(bar_x + 10 * 25 + 6, bar_y)
	mana_value_label.add_theme_font_size_override("font_size", 13)
	mana_value_label.modulate = Color(1.0, 0.9, 0.3)
	add_child(mana_value_label)

func _build_next_card_panel() -> void:
	# 次カードパネル：盤面下部中央
	var panel_w  := 360
	var panel_h  := 110
	var panel_x  := CENTER_X - panel_w / 2
	var panel_y  := BOARD_TOP + 3 * CELL_H + 36

	next_card_panel = ColorRect.new()
	next_card_panel.position = Vector2(panel_x, panel_y)
	next_card_panel.size     = Vector2(panel_w, panel_h)
	next_card_panel.color    = Color(0.08, 0.10, 0.17)
	add_child(next_card_panel)

	# 枠線風
	var border := ColorRect.new()
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.size     = Vector2(panel_w + 4, panel_h + 4)
	border.color    = Color(0.3, 0.5, 0.8, 0.6)
	border.z_index  = -1
	add_child(border)

	var title_lbl := Label.new()
	title_lbl.text     = "─── NEXT CARD ───"
	title_lbl.position = Vector2(panel_x + 85, panel_y + 4)
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.modulate = Color(0.5, 0.7, 1.0)
	add_child(title_lbl)

	# カード名（大きく）
	next_card_name_label = Label.new()
	next_card_name_label.position = Vector2(panel_x + 10, panel_y + 22)
	next_card_name_label.add_theme_font_size_override("font_size", 28)
	next_card_name_label.modulate = Color(1.0, 1.0, 0.85)
	add_child(next_card_name_label)

	# コスト（右上大きく）
	next_card_cost_label = Label.new()
	next_card_cost_label.position = Vector2(panel_x + panel_w - 70, panel_y + 16)
	next_card_cost_label.add_theme_font_size_override("font_size", 32)
	next_card_cost_label.modulate = Color(1.0, 0.85, 0.1)
	add_child(next_card_cost_label)

	# 詳細（HP/ATK/列/攻撃間隔）
	next_card_detail_label = Label.new()
	next_card_detail_label.position = Vector2(panel_x + 10, panel_y + 60)
	next_card_detail_label.add_theme_font_size_override("font_size", 13)
	next_card_detail_label.modulate = Color(0.75, 0.85, 0.75)
	add_child(next_card_detail_label)

	# 発動チェックタイマー表示
	next_card_timer_label = Label.new()
	next_card_timer_label.position = Vector2(panel_x + 10, panel_y + 88)
	next_card_timer_label.add_theme_font_size_override("font_size", 11)
	next_card_timer_label.modulate = Color(0.55, 0.55, 0.7)
	add_child(next_card_timer_label)

	# 次の敵カード表示（パネル右側）
	enemy_next_label = Label.new()
	enemy_next_label.position = Vector2(panel_x + panel_w + 8, panel_y + 20)
	enemy_next_label.add_theme_font_size_override("font_size", 13)
	enemy_next_label.modulate = Color(1.0, 0.5, 0.5)
	add_child(enemy_next_label)

	# デッキ・捨て札枚数
	var deck_y: int = panel_y + panel_h + 6
	deck_count_label = Label.new()
	deck_count_label.position = Vector2(panel_x, deck_y)
	deck_count_label.add_theme_font_size_override("font_size", 12)
	deck_count_label.modulate = Color(0.6, 0.8, 1.0)
	add_child(deck_count_label)

	discard_count_label = Label.new()
	discard_count_label.position = Vector2(panel_x + 130, deck_y)
	discard_count_label.add_theme_font_size_override("font_size", 12)
	discard_count_label.modulate = Color(0.5, 0.5, 0.7)
	add_child(discard_count_label)

	enemy_deck_count_label = Label.new()
	enemy_deck_count_label.position = Vector2(panel_x + panel_w + 8, panel_y + 60)
	enemy_deck_count_label.add_theme_font_size_override("font_size", 12)
	enemy_deck_count_label.modulate = Color(1.0, 0.5, 0.5)
	add_child(enemy_deck_count_label)

# ---- セルのX座標計算 ----
# 自陣: col0=後列(最左), col1=中列, col2=前列(中央寄り右)
# 敵陣: col0=前列(中央寄り左), col1=中列, col2=後列(最右)
func _cell_x(side: int, col: int) -> int:
	if side == 0:
		# 自陣: 前列(col2)が右端
		# col2のX = CENTER_X - GAP/2 - CELL_W
		# col1のX = col2X - CELL_W
		# col0のX = col1X - CELL_W
		return CENTER_X - GAP / 2 - (3 - col) * CELL_W
	else:
		# 敵陣: 前列(col0)が左端
		# col0のX = CENTER_X + GAP/2
		return CENTER_X + GAP / 2 + col * CELL_W

# ---- 入力処理（開発者モード用） ----
func _input(event: InputEvent) -> void:
	if not dev_mode or dev_ui == null:
		return
	# 盤面効果設置モード：クリックでセルに効果設置
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dev_ui._pending_tile_effect != "":
			var pos: Vector2 = event.position
			for side in range(2):
				for r in range(3):
					for c in range(3):
						var rect: ColorRect = cell_rects[side][r][c]
						if Rect2(rect.position, rect.size).has_point(pos):
							dev_ui.on_drop(side, r, c)
							return
	# ドラッグ中のマウスリリース → セル判定
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dev_ui._dragging:
			var pos: Vector2 = event.position
			var dropped: bool = false
			# デッキエリアにドロップ → デッキに追加
			if pos.x <= 155:
				dev_ui.on_drop_to_deck()
				dropped = true
			else:
				for side in range(2):
					for r in range(3):
						for c in range(3):
							var rect: ColorRect = cell_rects[side][r][c]
							if Rect2(rect.position, rect.size).has_point(pos):
								dev_ui.on_drop(side, r, c)
								dropped = true
			if not dropped:
				dev_ui.on_drop_outside()
			dev_ui._stop_drag()

func _dev_update_drag() -> void:
	if dev_ui != null and dev_ui._dragging and dev_ui._drag_label != null:
		dev_ui._drag_label.position = get_viewport().get_mouse_position() + Vector2(12, -8)

# ---- ゲームループ ----
func _process(delta: float) -> void:
	# ドラッグ中のラベル追従
	if dev_mode:
		_dev_update_drag()
	# フラッシュタイマー更新（game_over中も継続）
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if skill_flash_timers[s][r][c] > 0.0:
					skill_flash_timers[s][r][c] = max(0.0, skill_flash_timers[s][r][c] - delta)
					if skill_flash_timers[s][r][c] == 0.0:
						_cell_dirty[s][r][c] = true  # フラッシュ終了→通常色に戻す

	if not game_started or game_over:
		return
	if not game_paused:
		deck_manager.process_deck(delta, board_manager)
		enemy_ai.process_ai(delta, board_manager)
		board_manager.process_combat(delta, base_hp)
		if not dev_mode:
			_check_game_over()
		# 開発者モード: デッキ表示を更新（サイズ変化時のみ）
		if dev_mode and dev_ui != null:
			dev_ui._refresh_deck_list(false)

	# サポート効果ログ（5秒ごと）
	_support_log_timer -= delta
	if _support_log_timer <= 0.0:
		_support_log_timer = 5.0
		_log_support_effects()

	_update_ui()

func _check_game_over() -> void:
	if base_hp[0] <= 0:
		game_over = true
		game_over_label.text     = "GAME OVER"
		game_over_label.modulate = Color(1.0, 0.3, 0.3)
		game_over_label.visible  = true
		restart_button.visible   = true
	elif base_hp[1] <= 0:
		game_over = true
		game_over_label.text     = "YOU WIN!"
		game_over_label.modulate = Color(0.3, 1.0, 0.5)
		game_over_label.visible  = true
		restart_button.visible   = true

func _on_cell_hover(side: int, r: int, c: int) -> void:
	var unit = board_manager.board[side][r][c]
	var te_hover = board_manager.board_effects[side][r][c]
	if unit == null and te_hover == null:
		_cell_tooltip_panel.visible = false
		return
	if unit == null:
		# 盤面効果のみ表示
		var _EDB_h = load("res://scripts/EffectDB.gd")
		var tile_def_h = _EDB_h.EFFECTS.get(te_hover["effect_id"], {})
		var tile_display_h: String = tile_def_h.get("display", te_hover["effect_id"])
		var remaining_str_h: String = "永続" if te_hover["remaining"] < 0 else "%ds" % int(te_hover["remaining"])
		_cell_tooltip_label.text = "■ 盤面効果: %s（%s）" % [tile_display_h, remaining_str_h]
		_cell_tooltip_panel.visible = true
		_cell_tooltip_panel.size = Vector2(265, 0)
		return
	var _EDB = load("res://scripts/EffectDB.gd")
	var trigger_jp: Dictionary = {"always": "常時", "on_summon": "召喚時", "on_hit": "命中時", "on_kill": "撃破時", "on_death": "死亡時", "timer": "時間経過"}
	var target_jp: Dictionary = {"self": "自身", "front_one": "前方1体", "same_row": "同段", "same_row_beast": "同段の獣", "same_col_ally": "同深度の味方", "adjacent_beast": "隣接の獣", "all_allies": "味方全体", "all_enemies": "敵全体", "hit_target": "攻撃対象", "enemy_most_buffs": "バフ最多の敵", "ally_undead_lowest": "最低HPアンデッド", "enemy_max_hp": "最大HP敵", "self_deck": "自デッキ", "front_enemy": "前列の敵", "adjacent_enemy": "隣接の敵", "enemy": "敵"}
	var lines: Array = []
	lines.append("[%s] %s" % [unit.race, unit.unit_name])
	lines.append("Cost: %d / HP: %d/%d / ATK: %d / SPD: %.1fs" % [unit.cost, unit.current_hp, unit.max_hp, unit.attack, unit.attack_interval])
	var support_lines: Array = []
	var active_lines: Array = []
	for skill in unit.skills:
		var eid: String = skill.get("effect_id", "")
		var display: String = eid
		if _EDB != null and _EDB.EFFECTS.has(eid):
			display = _EDB.EFFECTS[eid].get("display", eid)
		var trigger: String = skill.get("trigger", "")
		var tgt: String = skill.get("target", "")
		var t_jp: String = trigger_jp.get(trigger, trigger)
		var tgt_jp: String = target_jp.get(tgt, tgt)
		if trigger == "timer":
			var interval = skill.get("params", {}).get("interval", 0)
			t_jp = "%ds毎" % int(interval)
		var entry: String = "- %s（%s, %s）" % [display, t_jp, tgt_jp]
		if trigger == "always":
			support_lines.append(entry)
		else:
			active_lines.append(entry)
	if support_lines.size() > 0:
		lines.append("")
		lines.append("■ サポート効果:")
		lines.append_array(support_lines)
	if active_lines.size() > 0:
		lines.append("")
		lines.append("■ アクティブスキル:")
		lines.append_array(active_lines)
	# 盤面効果表示
	if te_hover != null:
		var _EDB_hover = load("res://scripts/EffectDB.gd")
		var tile_def_hover = _EDB_hover.EFFECTS.get(te_hover["effect_id"], {})
		var tile_display_hover: String = tile_def_hover.get("display", te_hover["effect_id"])
		var remaining_str: String = "永続" if te_hover["remaining"] < 0 else "%ds" % int(te_hover["remaining"])
		lines.append("")
		lines.append("■ 盤面効果: %s（%s）" % [tile_display_hover, remaining_str])
	_cell_tooltip_label.text = "\n".join(lines)
	_cell_tooltip_panel.visible = true
	_cell_tooltip_panel.size = Vector2(265, 0)

func _on_cell_hover_end() -> void:
	_cell_tooltip_panel.visible = false

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

# ---- UI更新 ----
func _update_ui() -> void:
	_update_cells()
	_update_base_hp()
	_update_mana()
	_update_next_card()
	_update_deck_counts()

func _update_cells() -> void:
	for side in range(2):
		for r in range(3):
			for c in range(3):
				var has_flash: bool = skill_flash_timers[side][r][c] > 0.0
				# 盤面効果があるセルは常に再描画（持続時間変化を反映）
				var has_tile_effect: bool = board_manager.board_effects[side][r][c] != null
				if not _cell_dirty[side][r][c] and not has_flash and not has_tile_effect:
					continue  # 変化なし・フラッシュなし・盤面効果なし → スキップ
				_render_cell(side, r, c)
				if not has_flash:
					_cell_dirty[side][r][c] = false

func _render_cell(side: int, r: int, c: int) -> void:
	var unit   = board_manager.get_unit(side, r, c)
	var rect: ColorRect = cell_rects[side][r][c]
	var lbl:  Label     = cell_labels[side][r][c]
	if unit != null:
		var hp_ratio: float = float(unit.current_hp) / float(unit.max_hp)
		# スキル発動フラッシュ or 通常色
		if skill_flash_timers[side][r][c] > 0.0:
			var f: float = skill_flash_timers[side][r][c]
			rect.color = Color(0.9, 0.75 * f + 0.1, 0.0)
		elif side == 0:
			rect.color = Color(0.08, 0.22 * hp_ratio + 0.04, 0.45 * hp_ratio + 0.08)
		else:
			rect.color = Color(0.45 * hp_ratio + 0.08, 0.06, 0.06)
		# 列マーカー
		var col_mark: String
		if side == 0:
			col_mark = "【前】" if c == 2 else ("【中】" if c == 1 else "【後】")
		else:
			col_mark = "【前】" if c == 0 else ("【中】" if c == 1 else "【後】")
		# HPバー（8ブロック）
		var bar_filled: int = int(hp_ratio * 8)
		var hp_bar: String = "█".repeat(bar_filled) + "░".repeat(8 - bar_filled)
		# アクティブバフ略称
		var buffs: Array = []
		# バフ（スタック値）
		if unit._atk_bonus > 0:        buffs.append("ATK+%d" % unit._atk_bonus)
		if unit._interval_bonus > 0.0:  buffs.append("SPD+")
		if unit._damage_reduction > 0:  buffs.append("鎧%d" % unit._damage_reduction)
		if unit.lifesteal_stacks > 0:   buffs.append("吸血%d" % unit.lifesteal_stacks)
		if unit._regen_stacks > 0:      buffs.append("再生%d" % unit._regen_stacks)
		if unit._temp_atk_bonus > 0:    buffs.append("ATK↑%d" % unit._temp_atk_bonus)
		if unit._temp_spd_bonus > 0.0:  buffs.append("SPD↑")
		# デバフ
		if unit.burn_turns > 0:         buffs.append("火傷%d" % unit.burn_turns)
		if unit.frozen_turns > 0:       buffs.append("凍結%d" % unit.frozen_turns)
		if unit.paralysis_turns > 0:    buffs.append("麻痺%d" % unit.paralysis_turns)
		if unit.poison_stacks > 0:      buffs.append("毒%d" % unit.poison_stacks)
		if unit._invincible_timer > 0.0: buffs.append("無敵")
		var buff_line: String = (" ".join(buffs)) if not buffs.is_empty() else ""
		# スキルフラッシュ
		var flash_line: String = ""
		if skill_flash_timers[side][r][c] > 0.0:
			flash_line = "★" + skill_flash_names[side][r][c] + "!"
		# 組み立て
		var lines: Array = [
			"%s%s" % [col_mark, unit.unit_name],
			"HP %d/%d ATK %d" % [unit.current_hp, unit.max_hp, unit.attack],
			hp_bar,
		]
		if buff_line != "": lines.append(buff_line)
		if flash_line != "": lines.append(flash_line)
		lbl.text = "\n".join(lines)
	else:
		rect.color = Color(0.11, 0.11, 0.17)
		lbl.text   = ""
	# 盤面効果の可視化（ユニット有無に関わらずオーバーレイ）
	var te_vis = board_manager.board_effects[side][r][c]
	if te_vis != null:
		var tile_id: String = te_vis["effect_id"]
		match tile_id:
			"tile_curse":        rect.color = rect.color.lerp(Color(0.5, 0.0, 0.5), 0.3)
			"tile_fire":         rect.color = rect.color.lerp(Color(0.8, 0.2, 0.0), 0.3)
			"tile_beast_forest": rect.color = rect.color.lerp(Color(0.0, 0.5, 0.0), 0.3)
			"tile_fortress":     rect.color = rect.color.lerp(Color(0.3, 0.3, 0.6), 0.3)
			"tile_crack":        rect.color = rect.color.lerp(Color(0.4, 0.3, 0.2), 0.3)
			"tile_poison":       rect.color = rect.color.lerp(Color(0.3, 0.0, 0.4), 0.3)
			"tile_hole":         rect.color = rect.color.lerp(Color(0.1, 0.1, 0.1), 0.5)

func _update_base_hp() -> void:
	player_base_label.text = "自陣 本体HP: %d / 30" % base_hp[0]
	enemy_base_label.text  = "敵陣 本体HP: %d / 30" % base_hp[1]

func _update_mana() -> void:
	var filled: int = int(deck_manager.mana)
	for i in range(10):
		var cell: ColorRect = mana_bar_cells[i]
		if i < filled:
			cell.color = Color(1.0, 0.85, 0.1)
		else:
			cell.color = Color(0.18, 0.17, 0.07)
	mana_value_label.text = "%.1f / 10" % deck_manager.mana

func _update_next_card() -> void:
	var next = deck_manager.get_next_card()
	if next == null:
		next_card_name_label.text   = "（なし）"
		next_card_detail_label.text = ""
		next_card_cost_label.text   = ""
		next_card_timer_label.text  = ""
		return

	# 呪文カード表示分岐
	if next.card_type != "unit":
		var prefix: String = "【呪文】" if next.card_type == "spell" else "【異常】"
		next_card_name_label.text = prefix + next.unit_name
		next_card_name_label.modulate = Color(0.8, 0.6, 1.0)
		var cost_text: String = "Cost X" if next.cost == -1 else "Cost %d" % next.cost
		next_card_cost_label.text = cost_text
		next_card_cost_label.modulate = Color(0.3, 1.0, 0.4) if deck_manager.mana >= next.cost else Color(1.0, 0.85, 0.1)
		next_card_detail_label.text = next.spell_effect
	else:
		next_card_name_label.modulate = Color(1.0, 1.0, 0.85)
		var col_names: Array = ["前列", "中列", "後列"]
		var col_name: String = col_names[next.assigned_col]

		next_card_name_label.text = next.unit_name

		# コスト表示：足りているかで色変化
		next_card_cost_label.text = "Cost %d" % next.cost
		if deck_manager.mana >= next.cost:
			next_card_cost_label.modulate = Color(0.3, 1.0, 0.4)
		else:
			next_card_cost_label.modulate = Color(1.0, 0.85, 0.1)

		next_card_detail_label.text = "HP %d  ATK %d  配置:%s  攻撃間隔:%.1fs" % [
			next.max_hp, next.attack, col_name, next.attack_interval
	]

	# 発動チェックまでの残り時間
	var remain: float = deck_manager._check_timer
	var interval: float = deck_manager.check_interval
	next_card_timer_label.text = "発動チェック: %.1fs 後（間隔 %.1fs）" % [remain, interval]

	# 次の敵カード
	var enemy_next = enemy_ai.get_next_card()
	if enemy_next != null:
		var cost_ok: bool = enemy_ai.mana >= enemy_next.cost
		enemy_next_label.modulate = Color(0.3, 1.0, 0.4) if cost_ok else Color(1.0, 0.5, 0.5)
		enemy_next_label.text = "次の敵：%s\nマナ %.1f/10  Cost %d" % [
			enemy_next.unit_name, enemy_ai.mana, enemy_next.cost
		]
	else:
		enemy_next_label.text = ""

func _update_deck_counts() -> void:
	deck_count_label.text    = "自デッキ: %d枚" % deck_manager.deck.size()
	discard_count_label.text = "捨て札: %d枚" % deck_manager.discard.size()
	enemy_deck_count_label.text = "敵デッキ: %d枚\n敵捨て札: %d枚" % [
		enemy_ai.enemy_deck.size(), enemy_ai.enemy_discard.size()
	]

# ---- シグナルハンドラ ----
func _on_unit_placed(side: int, row: int, col: int, _unit: Object) -> void:
	_mark_all_cells_dirty()  # サポート効果が全体に波及する可能性

func _on_unit_died(side: int, row: int, col: int) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	var display_col: int = (2 - col) if side == 0 else col
	var col_names: Array  = ["前列", "中列", "後列"]
	_add_log("倒 %s %d行%s" % [side_name, row + 1, col_names[display_col]])
	_mark_all_cells_dirty()

func _on_unit_damaged(side: int, row: int, col: int) -> void:
	if side >= 0 and row >= 0 and col >= 0:
		_cell_dirty[side][row][col] = true

func _on_unit_revived(side: int, row: int, col: int) -> void:
	var unit = board_manager.get_unit(side, row, col)
	var name: String = unit.unit_name if unit != null else "?"
	_add_log("[アクティブ] %s の 自己再起 発動（撃破時）HP5で復活" % name)
	skill_flash_timers[side][row][col] = 1.0
	skill_flash_names[side][row][col]  = "再起"
	_cell_dirty[side][row][col] = true

func _on_base_damaged(side: int, amount: int) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	_add_log("! %s本体 -%d (残:%d)" % [side_name, amount, base_hp[side]])

func _on_active_skill_used(side: int, row: int, col: int, skill_name: String) -> void:
	var unit = board_manager.get_unit(side, row, col)
	var name: String = unit.unit_name if unit != null else "?"
	_add_log("[アクティブ] %s の %s 発動" % [name, skill_name])
	skill_flash_timers[side][row][col] = 0.6
	skill_flash_names[side][row][col]  = skill_name
	_cell_dirty[side][row][col] = true  # ATK累積等の永続変化を即反映
	_cell_dirty[side][row][col] = true

func _log_support_effects() -> void:
	for side in range(2):
		for r in range(3):
			for c in range(3):
				var unit = board_manager.get_unit(side, r, c)
				if unit == null: continue
				for entry in unit.support_effect.split(" / "):
					if "常時発動" not in entry or "後列攻撃" in entry: continue
					var bs: int = entry.find("〈")
					var be: int = entry.find("〉")
					if bs == -1 or be == -1: continue
					var parts: Array = entry.substr(bs + 1, be - bs - 1).split("・")
					var target_desc: String = parts[1] if parts.size() > 1 else ""
					var targets: Array = board_manager._get_support_targets(side, r, c, target_desc)
					if targets.is_empty(): continue
					var eff_name: String = ""
					if   "ATKバフ"  in entry: eff_name = "ATKバフ +2"
					elif "SPDバフ"  in entry: eff_name = "SPDバフ -0.3s"
					elif "HPバフ"   in entry: eff_name = "HPバフ +1/s"
					elif "障壁付与" in entry: eff_name = "障壁 -1ダメ"
					if eff_name.is_empty(): continue
					for t in targets:
						_add_log("[サポート] %s → %s に %s" % [unit.unit_name, t.unit_name, eff_name])

func _mark_all_cells_dirty() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				_cell_dirty[s][r][c] = true

func _on_status_damage(unit_name: String, status: String, damage: int, stacks: int) -> void:
	_add_log("[状態異常] %s: %s -%d (スタック:%d)" % [unit_name, status, damage, stacks])

func _on_status_cleared(unit_name: String, status: String) -> void:
	_add_log("[状態解除] %s の %s が解除" % [unit_name, status])

func _on_synthesis_done(side: int, row: int, col: int, base_name: String, result_name: String) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	_add_log("[合成] %s %s → %s" % [side_name, base_name, result_name])
	skill_flash_timers[side][row][col] = 1.0
	skill_flash_names[side][row][col] = "合成"
	_cell_dirty[side][row][col] = true

func _on_spell_cast(side: int, spell_name: String) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	_add_log("[呪文] %s %s 発動" % [side_name, spell_name])
	_mark_all_cells_dirty()

func _on_draw_cards_requested(side: int, count: int) -> void:
	for i in range(count):
		if side == 0:
			deck_manager.force_play_card(board_manager)
		else:
			enemy_ai.force_play_card(board_manager)

func _add_log(text: String) -> void:
	var ms: float = float(Time.get_ticks_msec()) * 0.001
	log_lines.append("[%.1fs] %s" % [ms, text])
	if log_lines.size() > 22:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
