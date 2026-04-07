# DeckView.gd
# デッキ確認画面（タスクバーから遷移）
# 現在のデッキ内容を一覧表示する
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null

# カード表示定数
const CARD_W = 140
const CARD_H = 80
const CARD_GAP_X = 10
const CARD_GAP_Y = 8
const GRID_COLS = 8
const GRID_START_X = 45  # (1280 - (8*140+7*10)) / 2 = 45 で線対称
const GRID_START_Y = 110

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.DECK_VIEW)

	UIF.add_title(self, "デッキ確認", 50)

	# デッキ枚数表示
	var count_lbl = Label.new()
	count_lbl.text = "デッキ: %d枚" % GameSession.selected_deck.size()
	count_lbl.position = Vector2(0, 82)
	count_lbl.size = Vector2(1280, 22)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 14)
	count_lbl.add_theme_color_override("font_color", UIF.DIM_COLOR)
	add_child(count_lbl)

	# カード一覧グリッド
	_build_card_list()

	# 戻るボタン
	var back_btn = Button.new()
	back_btn.text = "戻る"
	back_btn.position = Vector2(590, 680)
	back_btn.size = Vector2(100, 36)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _build_card_list() -> void:
	var deck = GameSession.selected_deck
	for i in range(deck.size()):
		var entry = deck[i]
		var card_name = entry.get("name", "") if entry is Dictionary else str(entry)
		var col_i = i % GRID_COLS
		var row_i = i / GRID_COLS
		var x = GRID_START_X + col_i * (CARD_W + CARD_GAP_X)
		var y = GRID_START_Y + row_i * (CARD_H + CARD_GAP_Y)
		_build_card_cell(card_name, x, y)

func _build_card_cell(card_name: String, x: int, y: int) -> void:
	var is_unit = CardDB.UNITS.has(card_name)
	var is_spell = CardDB.SPELLS.has(card_name) or CardDB.STATUS_SPELLS.has(card_name)
	var data: Dictionary = {}
	if is_unit:
		data = CardDB.UNITS[card_name]
	elif CardDB.SPELLS.has(card_name):
		data = CardDB.SPELLS[card_name]
	elif CardDB.STATUS_SPELLS.has(card_name):
		data = CardDB.STATUS_SPELLS[card_name]

	var panel = Panel.new()
	panel.position = Vector2(x, y)
	panel.size = Vector2(CARD_W, CARD_H)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.16)
	if is_unit:
		style.border_color = Color(0.3, 0.6, 0.4)
	elif is_spell:
		style.border_color = Color(0.3, 0.4, 0.7)
	else:
		style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# カード名
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(4, 4)
	name_lbl.size = Vector2(CARD_W - 8, 22)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)

	# コスト
	var cost_lbl = Label.new()
	cost_lbl.text = "コスト:%d" % data.get("cost", 0)
	cost_lbl.position = Vector2(4, 26)
	cost_lbl.size = Vector2(CARD_W - 8, 18)
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cost_lbl)

	# ユニット: HP/ATK
	if is_unit:
		var stats_lbl = Label.new()
		stats_lbl.text = "HP:%d ATK:%d" % [data.get("hp", 0), data.get("atk", 0)]
		stats_lbl.position = Vector2(4, 44)
		stats_lbl.size = Vector2(CARD_W - 8, 18)
		stats_lbl.add_theme_font_size_override("font_size", 10)
		stats_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
		stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(stats_lbl)

		var type_lbl = Label.new()
		type_lbl.text = "[ユニット]"
		type_lbl.position = Vector2(4, CARD_H - 16)
		type_lbl.size = Vector2(CARD_W - 8, 14)
		type_lbl.add_theme_font_size_override("font_size", 9)
		type_lbl.add_theme_color_override("font_color", Color(0.3, 0.6, 0.4))
		type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(type_lbl)
	else:
		var type_lbl = Label.new()
		type_lbl.text = "[呪文]"
		type_lbl.position = Vector2(4, CARD_H - 16)
		type_lbl.size = Vector2(CARD_W - 8, 14)
		type_lbl.add_theme_font_size_override("font_size", 9)
		type_lbl.add_theme_color_override("font_color", Color(0.3, 0.4, 0.7))
		type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(type_lbl)

func _on_back() -> void:
	var prev = GameSession.last_scene
	if prev == "":
		prev = SceneManager.MAP_SELECT
	SceneManager.go_to(prev)
