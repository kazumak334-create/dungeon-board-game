# CardSlot.gd
# DeckPrep手持ちカード1枚分のUI（縦長カード形式）
# ホバー時に上方向に移動、複数枚時に×Nバッジ表示
extends Control

const CARD_W = 90.0
const CARD_H = 130.0
const ILLUST_RATIO = 0.6
const COST_BADGE_SIZE = 20.0
const HOVER_OFFSET_Y = -40.0
const HOVER_TWEEN_DURATION = 0.15

# カードデータ
var card_name: String = ""
var card_cost: int = 0
var card_count: int = 1
var card_indices: Array = []
var card_color: Color = Color(0.3, 0.3, 0.4)

# ホバー状態
var _is_hovered: bool = false
var _original_y: float = 0.0
var _hover_tween: Tween = null

# 外部設定
var on_card_clicked: Callable = Callable()

signal card_hovered(slot: Control)
signal card_unhovered(slot: Control)

func _ready() -> void:
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)
	_original_y = position.y
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(cname: String, ccost: int, ccount: int, cindices: Array, ccolor: Color) -> void:
	card_name = cname
	card_cost = ccost
	card_count = ccount
	card_indices = cindices
	card_color = ccolor
	_build_card_ui()

func _build_card_ui() -> void:
	# カード枠（丸角矩形）
	var bg = PanelContainer.new()
	bg.size = Vector2(CARD_W, CARD_H)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # タスク#8: 子ノードをクリック透過
	bg.add_child(vbox)

	# 上部60%: イラストエリア
	var illust_h = CARD_H * ILLUST_RATIO
	var illust_area = ColorRect.new()
	illust_area.custom_minimum_size = Vector2(CARD_W - 2, illust_h)
	illust_area.color = card_color
	illust_area.mouse_filter = Control.MOUSE_FILTER_IGNORE  # タスク#8: 子ノードをクリック透過
	vbox.add_child(illust_area)

	# 左上コストバッジ（イラストエリア上に重ねる）
	var cost_badge = PanelContainer.new()
	cost_badge.position = Vector2(4, 4)
	cost_badge.custom_minimum_size = Vector2(COST_BADGE_SIZE, COST_BADGE_SIZE)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE  # タスク#8: 子ノードをクリック透過
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.2, 0.3, 0.5)
	badge_style.set_corner_radius_all(int(COST_BADGE_SIZE / 2))
	cost_badge.add_theme_stylebox_override("panel", badge_style)
	var cost_lbl = Label.new()
	cost_lbl.text = str(card_cost)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # タスク#8: 子ノードをクリック透過
	cost_badge.add_child(cost_lbl)
	illust_area.add_child(cost_badge)

	# 右上×Nバッジ（複数枚時のみ）
	if card_count > 1:
		var count_lbl = Label.new()
		count_lbl.text = "×%d" % card_count
		count_lbl.position = Vector2(CARD_W - 30, 4)
		count_lbl.size = Vector2(26, 16)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # タスク#8: 子ノードをクリック透過
		illust_area.add_child(count_lbl)

	# 下部40%: カード名・種族テキスト
	var text_area = VBoxContainer.new()
	text_area.custom_minimum_size = Vector2(CARD_W - 6, CARD_H - illust_h - 6)
	text_area.add_theme_constant_override("separation", 2)
	text_area.mouse_filter = Control.MOUSE_FILTER_IGNORE  # タスク#8: 子ノードをクリック透過

	var name_lbl = Label.new()
	# en_nameを使用（未設定の場合はcard_nameをそのまま表示）
	var display_name = card_name
	if CardDB.UNITS.has(card_name):
		display_name = CardDB.UNITS[card_name].get("en_name", card_name)
	elif CardDB.SPELLS.has(card_name):
		display_name = CardDB.SPELLS[card_name].get("en_name", card_name)
	name_lbl.text = display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # タスク#8: 子ノードをクリック透過
	text_area.add_child(name_lbl)

	# 種族・種類テキスト
	var race_text = _get_race_text()
	if race_text != "":
		var race_lbl = Label.new()
		race_lbl.text = race_text
		race_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		race_lbl.add_theme_font_size_override("font_size", 9)
		race_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		race_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # タスク#8: 子ノードをクリック透過
		text_area.add_child(race_lbl)

	vbox.add_child(text_area)

func _get_race_text() -> String:
	if CardDB.UNITS.has(card_name):
		return CardDB.UNITS[card_name].get("race", "")
	if CardDB.SPELLS.has(card_name):
		return "呪文"
	if CardDB.STATUS_SPELLS.has(card_name):
		return "状態呪文"
	return ""

func _on_mouse_entered() -> void:
	_is_hovered = true
	_tween_hover(true)
	card_hovered.emit(self)

func _on_mouse_exited() -> void:
	_is_hovered = false
	_tween_hover(false)
	card_unhovered.emit(self)

func _tween_hover(up: bool) -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	var target_y = _original_y + (HOVER_OFFSET_Y if up else 0.0)
	_hover_tween.tween_property(self, "position:y", target_y, HOVER_TWEEN_DURATION)
	if up:
		_hover_tween.set_ease(Tween.EASE_OUT)
	else:
		_hover_tween.set_ease(Tween.EASE_IN)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		print("[CardSlot] gui_input fired: pressed=", event.pressed, " btn=", event.button_index, " size=", size)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if on_card_clicked.is_valid():
			on_card_clicked.call(card_indices[0] if card_indices.size() > 0 else -1, event)
		accept_event()

func set_original_y(y: float) -> void:
	_original_y = y
	position.y = y
