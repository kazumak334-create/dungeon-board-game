# Main.gd
# メインシーン制御・UI描画・ゲームループ
extends Node

const BoardManagerScript = preload("res://scripts/BoardManager.gd")
const DeckManagerScript = preload("res://scripts/DeckManager.gd")
const EnemyAIScript = preload("res://scripts/EnemyAI.gd")

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

var energy_bar_cells: Array = []  # エネルギーバー格子
var energy_value_label: Label
var next_card_panel: ColorRect
var next_card_name_label: Label
var next_card_detail_label: Label
var next_card_cost_label: Label
var next_card_timer_label: Label

var player_base_label: Label
var enemy_base_label:  Label
var log_label:         Label
var game_over_label:   Label

var game_over: bool = false
var log_lines: Array  = []

# ---- 初期化 ----
func _ready() -> void:
	board_manager = Node.new()
	board_manager.set_script(BoardManagerScript)
	add_child(board_manager)
	board_manager.unit_died.connect(_on_unit_died)
	board_manager.base_damaged.connect(_on_base_damaged)

	deck_manager = Node.new()
	deck_manager.set_script(DeckManagerScript)
	add_child(deck_manager)

	enemy_ai = Node.new()
	enemy_ai.set_script(EnemyAIScript)
	add_child(enemy_ai)

	_build_ui()
	_add_log("=== Dungeon Board Game 起動 ===")

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

	# ---- エネルギーバー ----
	_build_energy_bar()

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

func _build_energy_bar() -> void:
	var bar_y: int = BOARD_TOP + 3 * CELL_H + 42
	var bar_x: int = _cell_x(0, 0)

	var bar_title := Label.new()
	bar_title.text     = "Energy"
	bar_title.position = Vector2(bar_x, bar_y - 18)
	bar_title.add_theme_font_size_override("font_size", 12)
	bar_title.modulate = Color(1.0, 0.85, 0.2)
	add_child(bar_title)

	energy_bar_cells = []
	for i in range(10):
		var cell := ColorRect.new()
		cell.size     = Vector2(22, 18)
		cell.position = Vector2(bar_x + i * 25, bar_y)
		cell.color    = Color(0.2, 0.2, 0.1)
		add_child(cell)
		energy_bar_cells.append(cell)

	energy_value_label = Label.new()
	energy_value_label.position = Vector2(bar_x + 10 * 25 + 6, bar_y)
	energy_value_label.add_theme_font_size_override("font_size", 13)
	energy_value_label.modulate = Color(1.0, 0.9, 0.3)
	add_child(energy_value_label)

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

# ---- ゲームループ ----
func _process(delta: float) -> void:
	if game_over:
		return
	deck_manager.process_deck(delta, board_manager)
	enemy_ai.process_ai(delta, board_manager)
	board_manager.process_combat(delta, base_hp)
	_check_game_over()
	_update_ui()

func _check_game_over() -> void:
	if base_hp[0] <= 0:
		game_over = true
		game_over_label.text    = "GAME OVER"
		game_over_label.modulate = Color(1.0, 0.3, 0.3)
		game_over_label.visible = true
	elif base_hp[1] <= 0:
		game_over = true
		game_over_label.text    = "YOU WIN!"
		game_over_label.modulate = Color(0.3, 1.0, 0.5)
		game_over_label.visible = true

# ---- UI更新 ----
func _update_ui() -> void:
	_update_cells()
	_update_base_hp()
	_update_energy()
	_update_next_card()

func _update_cells() -> void:
	for side in range(2):
		for r in range(3):
			for c in range(3):
				var unit   = board_manager.get_unit(side, r, c)
				var rect: ColorRect = cell_rects[side][r][c]
				var lbl:  Label     = cell_labels[side][r][c]
				if unit != null:
					var hp_ratio: float = float(unit.current_hp) / float(unit.max_hp)
					if side == 0:
						rect.color = Color(0.08, 0.22 * hp_ratio + 0.04, 0.45 * hp_ratio + 0.08)
					else:
						rect.color = Color(0.45 * hp_ratio + 0.08, 0.06, 0.06)
					# 列マーカー（論理col基準）
					var col_mark: String = "【前】" if c == 2 else ("【中】" if c == 1 else "【後】")
					if side == 1:
						col_mark = "【前】" if c == 0 else ("【中】" if c == 1 else "【後】")
					lbl.text = "%s%s\nHP %d/%d  ATK %d" % [
						col_mark, unit.unit_name, unit.current_hp, unit.max_hp, unit.attack
					]
				else:
					rect.color = Color(0.11, 0.11, 0.17)
					lbl.text   = ""

func _update_base_hp() -> void:
	player_base_label.text = "自陣 本体HP: %d / 30" % base_hp[0]
	enemy_base_label.text  = "敵陣 本体HP: %d / 30" % base_hp[1]

func _update_energy() -> void:
	var filled: int = int(deck_manager.energy)
	for i in range(10):
		var cell: ColorRect = energy_bar_cells[i]
		if i < filled:
			cell.color = Color(1.0, 0.85, 0.1)
		else:
			cell.color = Color(0.18, 0.17, 0.07)
	energy_value_label.text = "%.1f / 10" % deck_manager.energy

func _update_next_card() -> void:
	var next = deck_manager.get_next_card()
	if next == null:
		next_card_name_label.text   = "（なし）"
		next_card_detail_label.text = ""
		next_card_cost_label.text   = ""
		next_card_timer_label.text  = ""
		return

	var col_names: Array = ["前列", "中列", "後列"]
	var col_name: String = col_names[next.assigned_col]

	next_card_name_label.text = next.unit_name

	# コスト表示：足りているかで色変化
	next_card_cost_label.text = "Cost %d" % next.cost
	if deck_manager.energy >= next.cost:
		next_card_cost_label.modulate = Color(0.3, 1.0, 0.4)   # 緑=発動可能
	else:
		next_card_cost_label.modulate = Color(1.0, 0.85, 0.1)  # 黄=待機中

	next_card_detail_label.text = "HP %d  ATK %d  配置:%s  攻撃間隔:%.1fs" % [
		next.max_hp, next.attack, col_name, next.attack_interval
	]

	# 発動チェックまでの残り時間
	var remain: float = deck_manager._check_timer
	var interval: float = deck_manager.check_interval
	next_card_timer_label.text = "発動チェック: %.1fs 後（間隔 %.1fs）" % [remain, interval]

# ---- シグナルハンドラ ----
func _on_unit_died(side: int, row: int, col: int) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	var col_names: Array  = ["前列", "中列", "後列"]
	_add_log("倒 %s %d行%s" % [side_name, row + 1, col_names[col]])

func _on_base_damaged(side: int, amount: int) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	_add_log("! %s本体 -%d (残:%d)" % [side_name, amount, base_hp[side]])

func _add_log(text: String) -> void:
	var ms: float = float(Time.get_ticks_msec()) * 0.001
	log_lines.append("[%.1fs] %s" % [ms, text])
	if log_lines.size() > 22:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
