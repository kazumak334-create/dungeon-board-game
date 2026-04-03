# Main.gd
# メインシーン制御・UI描画・ゲームループ
extends Node

const BoardManagerScript = preload("res://scripts/BoardManager.gd")
const DeckManagerScript = preload("res://scripts/DeckManager.gd")
const EnemyAIScript = preload("res://scripts/EnemyAI.gd")

const CELL_W := 110
const CELL_H := 90
const BOARD_OFFSET_X := 60
const BOARD_OFFSET_Y := 120
const GAP := 20

var board_manager: Node
var deck_manager: Node
var enemy_ai: Node

var base_hp: Array = [30, 30]

var cell_rects: Array = []
var cell_labels: Array = []
var energy_label: Label
var next_card_label: Label
var player_base_label: Label
var enemy_base_label: Label
var log_label: Label
var game_over_label: Label

var game_over: bool = false
var log_lines: Array = []

func _ready() -> void:
	board_manager = Node.new()
	board_manager.set_script(BoardManagerScript)
	add_child(board_manager)
	board_manager.call("_setup")
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

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title := Label.new()
	title.text = "Dungeon Board Game - Phase 1 Prototype"
	title.position = Vector2(20, 10)
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(0.9, 0.85, 0.6)
	add_child(title)

	var pl := Label.new()
	pl.text = "自陣"
	pl.position = Vector2(BOARD_OFFSET_X + 100, BOARD_OFFSET_Y - 30)
	pl.modulate = Color(0.4, 0.8, 1.0)
	add_child(pl)

	var el := Label.new()
	el.text = "敵陣"
	el.position = Vector2(BOARD_OFFSET_X + 3 * CELL_W + GAP + 100, BOARD_OFFSET_Y - 30)
	el.modulate = Color(1.0, 0.4, 0.4)
	add_child(el)

	var col_names := ["前列", "中列", "後列"]
	for c in range(3):
		var lbl := Label.new()
		lbl.text = col_names[c]
		lbl.position = Vector2(BOARD_OFFSET_X + c * CELL_W + 30, BOARD_OFFSET_Y - 18)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.7, 0.7, 0.7)
		add_child(lbl)

	var enemy_col_names := ["後列", "中列", "前列"]
	for c in range(3):
		var lbl := Label.new()
		lbl.text = enemy_col_names[c]
		lbl.position = Vector2(BOARD_OFFSET_X + 3 * CELL_W + GAP + c * CELL_W + 25, BOARD_OFFSET_Y - 18)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.7, 0.7, 0.7)
		add_child(lbl)

	var row_names := ["上", "中", "下"]
	for r in range(3):
		var lbl := Label.new()
		lbl.text = row_names[r]
		lbl.position = Vector2(BOARD_OFFSET_X - 25, BOARD_OFFSET_Y + r * CELL_H + 30)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.7, 0.7, 0.7)
		add_child(lbl)

	cell_rects = [[], []]
	cell_labels = [[], []]
	for side in range(2):
		for r in range(3):
			cell_rects[side].append([])
			cell_labels[side].append([])
			for c in range(3):
				var rect := ColorRect.new()
				rect.size = Vector2(CELL_W - 4, CELL_H - 4)
				var draw_col: int
				var base_x: int
				if side == 0:
					draw_col = c
					base_x = BOARD_OFFSET_X
				else:
					draw_col = 2 - c
					base_x = BOARD_OFFSET_X + 3 * CELL_W + GAP
				rect.position = Vector2(base_x + draw_col * CELL_W + 2, BOARD_OFFSET_Y + r * CELL_H + 2)
				rect.color = Color(0.15, 0.15, 0.22)
				add_child(rect)
				cell_rects[side][r].append(rect)

				var lbl := Label.new()
				lbl.position = rect.position + Vector2(4, 4)
				lbl.size = rect.size
				lbl.add_theme_font_size_override("font_size", 11)
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				add_child(lbl)
				cell_labels[side][r].append(lbl)

	player_base_label = Label.new()
	player_base_label.position = Vector2(BOARD_OFFSET_X, BOARD_OFFSET_Y + 3 * CELL_H + 15)
	player_base_label.modulate = Color(0.4, 0.9, 0.4)
	add_child(player_base_label)

	enemy_base_label = Label.new()
	enemy_base_label.position = Vector2(BOARD_OFFSET_X + 3 * CELL_W + GAP, BOARD_OFFSET_Y + 3 * CELL_H + 15)
	enemy_base_label.modulate = Color(1.0, 0.4, 0.4)
	add_child(enemy_base_label)

	energy_label = Label.new()
	energy_label.position = Vector2(BOARD_OFFSET_X, BOARD_OFFSET_Y + 3 * CELL_H + 40)
	energy_label.modulate = Color(0.9, 0.8, 0.2)
	add_child(energy_label)

	next_card_label = Label.new()
	next_card_label.position = Vector2(BOARD_OFFSET_X, BOARD_OFFSET_Y + 3 * CELL_H + 65)
	next_card_label.modulate = Color(0.6, 0.9, 0.9)
	add_child(next_card_label)

	var log_bg := ColorRect.new()
	log_bg.position = Vector2(850, BOARD_OFFSET_Y - 10)
	log_bg.size = Vector2(400, 380)
	log_bg.color = Color(0.05, 0.05, 0.08)
	add_child(log_bg)

	var log_title_lbl := Label.new()
	log_title_lbl.text = "ログ"
	log_title_lbl.position = Vector2(860, BOARD_OFFSET_Y - 5)
	log_title_lbl.modulate = Color(0.7, 0.7, 0.5)
	add_child(log_title_lbl)

	log_label = Label.new()
	log_label.position = Vector2(858, BOARD_OFFSET_Y + 15)
	log_label.size = Vector2(390, 360)
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.modulate = Color(0.8, 0.8, 0.8)
	add_child(log_label)

	game_over_label = Label.new()
	game_over_label.position = Vector2(280, 280)
	game_over_label.add_theme_font_size_override("font_size", 64)
	game_over_label.visible = false
	add_child(game_over_label)

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
		game_over_label.text = "GAME OVER"
		game_over_label.modulate = Color(1.0, 0.3, 0.3)
		game_over_label.visible = true
	elif base_hp[1] <= 0:
		game_over = true
		game_over_label.text = "YOU WIN!"
		game_over_label.modulate = Color(0.3, 1.0, 0.5)
		game_over_label.visible = true

func _update_ui() -> void:
	for side in range(2):
		for r in range(3):
			for c in range(3):
				var unit = board_manager.get_unit(side, r, c)
				var rect: ColorRect = cell_rects[side][r][c]
				var lbl: Label = cell_labels[side][r][c]
				if unit != null:
					var hp_ratio: float = float(unit.current_hp) / float(unit.max_hp)
					if side == 0:
						rect.color = Color(0.1, 0.3 * hp_ratio, 0.5 * hp_ratio + 0.1)
					else:
						rect.color = Color(0.5 * hp_ratio + 0.1, 0.1, 0.1)
					var col_markers: Array = ["[前]", "[中]", "[後]"]
					var col_marker: String = col_markers[c]
					lbl.text = "%s%s\nHP:%d/%d\nATK:%d" % [
						col_marker, unit.unit_name, unit.current_hp, unit.max_hp, unit.attack
					]
				else:
					rect.color = Color(0.12, 0.12, 0.18)
					lbl.text = ""

	player_base_label.text = "自陣 本体HP: %d / 30" % base_hp[0]
	enemy_base_label.text = "敵陣 本体HP: %d / 30" % base_hp[1]

	var filled: int = int(deck_manager.energy)
	var bars: String = ""
	for i in range(10):
		bars += "|" if i < filled else "."
	energy_label.text = "Energy [%s] %.1f/10" % [bars, deck_manager.energy]

	var next = deck_manager.get_next_card()
	if next != null:
		var col_names_arr: Array = ["前列", "中列", "後列"]
		var col_name: String = col_names_arr[next.assigned_col]
		next_card_label.text = "Next: [%s] %s cost:%d atk:%d hp:%d" % [
			col_name, next.unit_name, next.cost, next.attack, next.max_hp
		]

func _on_unit_died(side: int, row: int, col: int) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	var col_names_arr: Array = ["前列", "中列", "後列"]
	_add_log("倒 %s %d行%s" % [side_name, row + 1, col_names_arr[col]])

func _on_base_damaged(side: int, amount: int) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	_add_log("! %s本体 -%d (残:%d)" % [side_name, amount, base_hp[side]])

func _add_log(text: String) -> void:
	var ms: float = float(Time.get_ticks_msec()) * 0.001
	log_lines.append("[%.1fs] %s" % [ms, text])
	if log_lines.size() > 20:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
