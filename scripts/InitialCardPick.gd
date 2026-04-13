# InitialCardPick.gd
# 初期カード選択画面（3枚から1枚を6回ピック）
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")
const CardViewScene = preload("res://scenes/ui/CardView.tscn")

# 状態変数
var _current_pick: int = 0
var _selected_idx: int = -1
var _picked_cards: Array = []
var _choice_pool: Array = []
var _is_animating: bool = false

# カードプール管理
var _initial_deck_counts: Dictionary = {}
var _same_race_pool: Array = []

# UI参照
var _taskbar: RefCounted = null
var _pick_dots: Array = []
var _pick_label: Label = null
var _card_views: Array = []
var _select_borders: Array = []
var _picked_slots: Array = []
var _picked_mini_cards: Array = []
var _confirm_button: Button = null

func _ready() -> void:
	print("[InitialCardPick] _ready() class_id=%s" % GameSession.class_id)
	_build_ui()
	_init_card_pool()
	_show_choices(_generate_choices())

func _build_ui() -> void:
	UIF.add_bg(self, UIColors.BG)
	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, "material_select")
	UIF.add_title(self, "初期デッキ編成", 10, 24, UIColors.TITLE)
	_build_progress_bar()
	_build_card_choices()
	_build_picked_area()
	_build_confirm_button()

func _build_progress_bar() -> void:
	var dot_w: int = 12
	var dot_h: int = 12
	var spacing: int = 20
	var total_w: int = dot_w * 6 + spacing * 5
	var start_x: int = (1280 - total_w) / 2
	
	for i in range(6):
		var dot = ColorRect.new()
		dot.color = UIColors.DIM
		dot.position = Vector2(start_x + i * (dot_w + spacing), 50)
		dot.size = Vector2(dot_w, dot_h)
		add_child(dot)
		_pick_dots.append(dot)
	
	_pick_label = Label.new()
	_pick_label.text = "PICK 1 / 6"
	_pick_label.position = Vector2(start_x + total_w + 30, 45)
	_pick_label.size = Vector2(200, 30)
	_pick_label.add_theme_font_size_override("font_size", 18)
	_pick_label.add_theme_color_override("font_color", UIColors.TEXT)
	add_child(_pick_label)
func _build_card_choices() -> void:
	var positions: Array = [
		Vector2(155, 130),
		Vector2(530, 130),
		Vector2(905, 130)
	]
	var border_positions: Array = [
		Vector2(152, 127),
		Vector2(527, 127),
		Vector2(902, 127)
	]
	
	for i in range(3):
		var border = ColorRect.new()
		border.color = Color.TRANSPARENT
		border.position = border_positions[i]
		border.size = Vector2(226, 326)
		add_child(border)
		_select_borders.append(border)
		
		var card_view = CardViewScene.instantiate()
		card_view.position = positions[i]
		add_child(card_view)
		_card_views.append(card_view)
		
		card_view.mouse_entered.connect(_on_card_hover.bind(i))
		card_view.mouse_exited.connect(_on_card_unhover.bind(i))
		card_view.gui_input.connect(_on_card_input.bind(i))

func _build_picked_area() -> void:
	var label = Label.new()
	label.text = "確定済みカード"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 490)
	label.size = Vector2(1280, 20)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UIColors.DIM)
	add_child(label)
	
	for i in range(6):
		var slot = ColorRect.new()
		slot.color = UIColors.PANEL
		slot.position = Vector2(410 + i * 80, 510)
		slot.size = Vector2(60, 86)
		add_child(slot)
		_picked_slots.append(slot)
		_picked_mini_cards.append(null)

func _build_confirm_button() -> void:
	_confirm_button = Button.new()
	_confirm_button.text = "冒険を始める"
	_confirm_button.position = Vector2(540, 635)
	_confirm_button.size = Vector2(200, 40)
	_confirm_button.modulate.a = 0.0
	_confirm_button.pressed.connect(_on_confirm_pressed)
	add_child(_confirm_button)
func _init_card_pool() -> void:
	var cls = CardDB.CLASSES.get(GameSession.class_id, {})
	var initial_deck = cls.get("initial_deck", [])
	
	var unit_cards: Array = []
	for card_name in initial_deck:
		if CardDB.UNITS.has(card_name):
			unit_cards.append(card_name)
	
	_initial_deck_counts.clear()
	for card_name in unit_cards:
		_initial_deck_counts[card_name] = _initial_deck_counts.get(card_name, 0) + 1
	
	_same_race_pool.clear()
	if unit_cards.size() > 0:
		var first_card = unit_cards[0]
		var race = CardDB.UNITS.get(first_card, {}).get("race", "")
		
		for card_name in CardDB.UNITS.keys():
			var data = CardDB.UNITS.get(card_name, {})
			if data.get("race", "") == race:
				var rarity = data.get("rarity", "")
				if rarity == "common" or rarity == "uncommon":
					_same_race_pool.append(card_name)
	
	print("[InitialCardPick] initial_deck_counts=%s" % _initial_deck_counts)
	print("[InitialCardPick] same_race_pool size=%d" % _same_race_pool.size())

func _generate_choices() -> Array:
	var choices: Array = []
	
	var available_cards: Array = []
	for card_name in _initial_deck_counts.keys():
		var picked_count: int = _picked_cards.count(card_name)
		var needed_count: int = _initial_deck_counts[card_name]
		if picked_count < needed_count:
			available_cards.append(card_name)
	
	if available_cards.size() > 0:
		available_cards.shuffle()
		choices.append(available_cards[0])
	
	var pool_copy: Array = _same_race_pool.duplicate()
	pool_copy.shuffle()
	
	for card_name in pool_copy:
		if choices.size() >= 3:
			break
		if not choices.has(card_name):
			choices.append(card_name)
	
	while choices.size() < 3 and _initial_deck_counts.size() > 0:
		var keys = _initial_deck_counts.keys()
		keys.shuffle()
		var card_name = keys[0]
		if not choices.has(card_name):
			choices.append(card_name)
	
	print("[InitialCardPick] _generate_choices() -> %s" % choices)
	return choices
func _show_choices(cards: Array) -> void:
	_choice_pool = cards
	_selected_idx = -1

	const CARD_Y_ORIGINAL = 130
	const CARD_Y_OFFSET = 30
	var positions: Array = [
		Vector2(155, CARD_Y_ORIGINAL),
		Vector2(530, CARD_Y_ORIGINAL),
		Vector2(905, CARD_Y_ORIGINAL)
	]

	for i in range(3):
		if i < cards.size():
			_bind_card(_card_views[i], cards[i])
			# 状態を完全にリセット
			_card_views[i].scale = Vector2(1.0, 1.0)
			_card_views[i].modulate = Color(1, 1, 1, 0)
			_card_views[i].position = positions[i] + Vector2(0, CARD_Y_OFFSET)

			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(_card_views[i], "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
			tween.tween_property(_card_views[i], "position", positions[i], 0.3).set_ease(Tween.EASE_OUT)

		_select_borders[i].color = Color.TRANSPARENT

func _bind_card(view: CardView, card_name: String) -> void:
	var data = CardDB.UNITS.get(card_name, {})
	view.card_name = card_name
	view.mana = data.get("mana", 0)
	view.hp = data.get("hp", 0)
	view.atk = data.get("atk", 0)
	view.spd = int(data.get("interval", 1.0))
	view.card_kind = CardView.CardKind.UNIT

	# レアリティ設定
	var rarity_str = data.get("rarity", "common").to_lower()
	match rarity_str:
		"common":
			view.rarity = CardView.Rarity.COMMON
		"uncommon":
			view.rarity = CardView.Rarity.UNCOMMON
		"rare":
			view.rarity = CardView.Rarity.RARE
		"epic":
			view.rarity = CardView.Rarity.EPIC
		"legend":
			view.rarity = CardView.Rarity.LEGEND
		"god":
			view.rarity = CardView.Rarity.GOD
		_:
			view.rarity = CardView.Rarity.COMMON

	# 特性バッジ設定
	if data.has("traits"):
		var traits_data = data.get("traits", [])
		if traits_data is Array:
			# Array[String]への型変換
			var typed_traits: Array[String] = []
			typed_traits.assign(traits_data)
			view.traits = typed_traits

	var tex_path = "res://assets/cards/units/%s.png" % card_name.to_lower().replace(" ", "_")
	if ResourceLoader.exists(tex_path):
		view.art_texture = load(tex_path)

func _on_card_hover(idx: int) -> void:
	if _is_animating:
		return
	if _selected_idx != -1 and _selected_idx != idx:
		return
	
	var tween = create_tween()
	tween.tween_property(_card_views[idx], "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT)

func _on_card_unhover(idx: int) -> void:
	if _is_animating:
		return
	if _selected_idx == idx:
		return
	
	var tween = create_tween()
	tween.tween_property(_card_views[idx], "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN)

func _on_card_input(event: InputEvent, idx: int) -> void:
	if _is_animating:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_card_clicked(idx)

func _on_card_clicked(idx: int) -> void:
	if _is_animating:
		return
	
	if _selected_idx == idx:
		_confirm_card(idx)
	else:
		_select_card(idx)
func _select_card(idx: int) -> void:
	_selected_idx = idx
	
	for i in range(3):
		if i == idx:
			_select_borders[i].color = UIColors.SELECTED
			var tween = create_tween()
			tween.tween_property(_card_views[i], "modulate:a", 1.0, 0.2)
		else:
			_select_borders[i].color = Color.TRANSPARENT
			var tween = create_tween()
			tween.tween_property(_card_views[i], "modulate:a", 0.4, 0.2)

func _confirm_card(idx: int) -> void:
	_is_animating = true

	var card_name = _choice_pool[idx]
	var card_view = _card_views[idx]
	# スロット位置に直接配置（オフセット不要）
	var target_pos = _picked_slots[_current_pick].position

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_view, "position", target_pos, 0.4).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card_view, "scale", Vector2(0.27, 0.27), 0.4).set_ease(Tween.EASE_IN_OUT)
	
	tween.finished.connect(func():
		_picked_cards.append(card_name)
		_add_to_picked_slot(card_name)
		_current_pick += 1
		_update_progress()

		card_view.scale = Vector2(1.0, 1.0)
		card_view.modulate.a = 1.0

		_is_animating = false

		if _current_pick < 6:
			_show_choices(_generate_choices())
		else:
			# ピック完了: 残っている選択肢カードを全て削除
			for view in _card_views:
				if is_instance_valid(view):
					view.queue_free()
			_card_views.clear()

			# 選択枠も削除
			for border in _select_borders:
				if is_instance_valid(border):
					border.queue_free()
			_select_borders.clear()

			var btn_tween = create_tween()
			btn_tween.tween_property(_confirm_button, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	)

func _add_to_picked_slot(card_name: String) -> void:
	var slot_idx = _current_pick
	var mini_card = CardViewScene.instantiate()
	_bind_card(mini_card, card_name)
	mini_card.scale = Vector2(0.27, 0.27)
	# スロット位置に直接配置（オフセット不要）
	mini_card.position = _picked_slots[slot_idx].position
	add_child(mini_card)
	_picked_mini_cards[slot_idx] = mini_card

func _update_progress() -> void:
	for i in range(6):
		if i < _current_pick:
			var tween = create_tween()
			tween.tween_property(_pick_dots[i], "color", UIColors.PICKED, 0.2)
	
	_pick_label.text = "PICK %d / 6" % (_current_pick + 1)

func _on_confirm_pressed() -> void:
	print("[InitialCardPick] _on_confirm_pressed() picked_cards=%s" % _picked_cards)
	
	var deck: Array = []
	for card_name in _picked_cards:
		var data = CardDB.UNITS.get(card_name, {})
		deck.append({"name": card_name, "col": data.get("col", 1)})
	
	var cls = CardDB.CLASSES.get(GameSession.class_id, {})
	var initial = cls.get("initial_deck", [])
	for name in initial:
		if CardDB.SPELLS.has(name) or CardDB.STATUS_SPELLS.has(name) or CardDB.SYSTEM_SPELLS.has(name):
			deck.append({"name": name, "col": -1})
	
	GameSession.selected_deck = deck
	print("[InitialCardPick] GameSession.selected_deck=%s" % GameSession.selected_deck)
	SceneManager.go_to(SceneManager.MAP_SELECT)
