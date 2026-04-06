# MaterialSelect.gd
# 素材選択画面: 15素材プールから3つランダム提示 + 運命に委ねる
extends Control

var _card_db: RefCounted
var _materials: Array = []       # 提示中の3素材
var _all_materials: Array = []   # 全素材プール
var _selected_index: int = -1    # 0-2: 素材選択, 3: 運命に委ねる
var _material_panels: Array = []
var _fate_panel: PanelContainer
var _deck_preview_container: VBoxContainer
var _decide_button: Button

# 色定義
const COLOR_BG         := Color(0.08, 0.08, 0.12)
const COLOR_PANEL      := Color(0.13, 0.13, 0.2)
const COLOR_CURSED     := Color(0.25, 0.1, 0.1)
const COLOR_BORDER     := Color(0.3, 0.3, 0.4)
const COLOR_SELECTED   := Color(0.9, 0.75, 0.3)
const COLOR_CURSED_SEL := Color(0.9, 0.3, 0.3)
const COLOR_FATE       := Color(0.15, 0.1, 0.2)
const COLOR_FATE_SEL   := Color(0.6, 0.3, 0.8)
const COLOR_TITLE      := Color(0.9, 0.85, 0.6)
const COLOR_BENEFIT    := Color(0.4, 0.85, 0.5)
const COLOR_DEMERIT    := Color(0.9, 0.35, 0.35)

func _ready() -> void:
	_card_db = load("res://scripts/CardDB.gd").new()
	_all_materials = _card_db.MATERIALS.duplicate()
	_pick_random_materials()
	_build_ui()

func _pick_random_materials() -> void:
	var pool = _all_materials.duplicate()
	pool.shuffle()
	_materials = pool.slice(0, 3)

func _build_ui() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# タイトル
	var title = Label.new()
	title.text = "素材を選べ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(1280, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	add_child(title)

	# クラス表示
	var cls = _card_db.CLASSES.get(GameSession.class_id, {})
	var class_label = Label.new()
	class_label.text = "クラス: %s" % cls.get("display", GameSession.class_id)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.position = Vector2(0, 58)
	class_label.size = Vector2(1280, 25)
	class_label.add_theme_font_size_override("font_size", 16)
	class_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	add_child(class_label)

	# 素材カード3枚 + 運命に委ねる
	var cards_container = HBoxContainer.new()
	cards_container.position = Vector2(40, 95)
	cards_container.size = Vector2(780, 320)
	cards_container.add_theme_constant_override("separation", 15)
	add_child(cards_container)

	_material_panels = []
	for i in range(3):
		var panel = _create_material_panel(i, _materials[i])
		cards_container.add_child(panel)
		_material_panels.append(panel)

	# 運命に委ねるカード
	_fate_panel = _create_fate_panel()
	cards_container.add_child(_fate_panel)

	# デッキプレビュー（右側）
	var preview_bg = PanelContainer.new()
	preview_bg.position = Vector2(850, 95)
	preview_bg.size = Vector2(400, 380)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.1, 0.1, 0.15)
	preview_style.set_corner_radius_all(6)
	preview_bg.add_theme_stylebox_override("panel", preview_style)
	add_child(preview_bg)

	var preview_scroll = ScrollContainer.new()
	preview_scroll.size = Vector2(390, 370)
	preview_bg.add_child(preview_scroll)

	_deck_preview_container = VBoxContainer.new()
	_deck_preview_container.add_theme_constant_override("separation", 2)
	preview_scroll.add_child(_deck_preview_container)

	_update_deck_preview()

	# 決定ボタン
	_decide_button = Button.new()
	_decide_button.text = "決  定"
	_decide_button.position = Vector2(515, 500)
	_decide_button.size = Vector2(250, 55)
	_decide_button.add_theme_font_size_override("font_size", 22)
	_decide_button.disabled = true
	_decide_button.pressed.connect(_on_decide_pressed)
	add_child(_decide_button)

	# 戻るボタン
	var back_button = Button.new()
	back_button.text = "← 戻る"
	back_button.position = Vector2(40, 500)
	back_button.size = Vector2(120, 45)
	back_button.add_theme_font_size_override("font_size", 16)
	back_button.pressed.connect(func(): SceneManager.go_to("title"))
	add_child(back_button)

func _create_material_panel(index: int, mat: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 320)

	var is_cursed = mat.get("is_cursed", false)
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_CURSED if is_cursed else COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# 呪いアイコン
	if is_cursed:
		var curse_label = Label.new()
		curse_label.text = "CURSED"
		curse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		curse_label.add_theme_font_size_override("font_size", 11)
		curse_label.add_theme_color_override("font_color", COLOR_DEMERIT)
		vbox.add_child(curse_label)

	# 素材名
	var name_label = Label.new()
	name_label.text = mat.get("display", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", COLOR_TITLE)
	vbox.add_child(name_label)

	# 説明
	var desc_label = Label.new()
	desc_label.text = mat.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_label)

	# メリット
	var benefit_header = Label.new()
	benefit_header.text = "── 効果 ──"
	benefit_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	benefit_header.add_theme_font_size_override("font_size", 11)
	benefit_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(benefit_header)

	for b in mat.get("benefits", []):
		var bl = Label.new()
		bl.text = _benefit_text(b)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD
		bl.add_theme_font_size_override("font_size", 13)
		bl.add_theme_color_override("font_color", COLOR_BENEFIT)
		vbox.add_child(bl)

	# デメリット
	for d in mat.get("demerits", []):
		var dl = Label.new()
		dl.text = _demerit_text(d)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD
		dl.add_theme_font_size_override("font_size", 13)
		dl.add_theme_color_override("font_color", COLOR_DEMERIT)
		vbox.add_child(dl)

	panel.add_child(vbox)

	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_material(index)
	)

	return panel

func _create_fate_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 320)

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_FATE
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)

	var q_label = Label.new()
	q_label.text = "?"
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.add_theme_font_size_override("font_size", 48)
	q_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.9))
	vbox.add_child(q_label)

	var name_label = Label.new()
	name_label.text = "運命に委ねる"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = "ランダムな素材が\n適用される\n\nデッキプレビュー不可"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(desc_label)

	panel.add_child(vbox)

	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_material(3)
	)

	return panel

func _select_material(index: int) -> void:
	_selected_index = index
	_decide_button.disabled = false

	# 枠の更新
	for i in range(3):
		var panel = _material_panels[i] as PanelContainer
		var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		var mat = _materials[i]
		if i == index:
			style.border_color = COLOR_CURSED_SEL if mat.get("is_cursed", false) else COLOR_SELECTED
			style.set_border_width_all(3)
		else:
			style.border_color = COLOR_BORDER
			style.set_border_width_all(2)

	# 運命パネル
	var fate_style = _fate_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if index == 3:
		fate_style.border_color = COLOR_FATE_SEL
		fate_style.set_border_width_all(3)
	else:
		fate_style.border_color = COLOR_BORDER
		fate_style.set_border_width_all(2)

	_update_deck_preview()

func _update_deck_preview() -> void:
	# 既存の子を削除
	for child in _deck_preview_container.get_children():
		child.queue_free()

	var header = Label.new()
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", COLOR_TITLE)

	if _selected_index == 3:
		header.text = "デッキプレビュー: ???"
		_deck_preview_container.add_child(header)
		var mystery = Label.new()
		mystery.text = "\n  運命に委ねたため\n  内容は不明"
		mystery.add_theme_font_size_override("font_size", 13)
		mystery.add_theme_color_override("font_color", Color(0.5, 0.4, 0.7))
		_deck_preview_container.add_child(mystery)
		return

	header.text = "デッキプレビュー"
	_deck_preview_container.add_child(header)

	# 基本デッキ
	var deck_cards: Array = []
	for entry in _card_db.BASE_DECK:
		deck_cards.append(entry.get("name", "???"))

	# クラス固有（initial_deckの先頭1枚を追加 — 仮）
	var cls = _card_db.CLASSES.get(GameSession.class_id, {})
	var initial = cls.get("initial_deck", [])
	if initial.size() > 0:
		deck_cards.append(initial[0] + " (固有)")

	# 素材ボーナス
	var bonus_cards: Array = []
	var bonus_texts: Array = []
	if _selected_index >= 0 and _selected_index < 3:
		var mat = _materials[_selected_index]
		for b in mat.get("benefits", []):
			match b.get("type", ""):
				"add_unit":
					bonus_cards.append("+ %s" % b.get("name", "???"))
				"add_spell":
					bonus_cards.append("+ %s" % b.get("name", "???"))
				"add_random_spell":
					bonus_cards.append("+ ランダム呪文")
				"remove_card":
					bonus_texts.append("カード%d枚除去" % b.get("count", 1))
				"equipment":
					bonus_texts.append("装備: %s" % b.get("id", "???"))
				"initial_mana":
					bonus_texts.append("初期マナ +%d" % b.get("amount", 0))
				"start_buff":
					var _edb = load("res://scripts/EffectDB.gd")
					var edef = _edb.EFFECTS.get(b.get("effect_id", ""), {})
					bonus_texts.append("開始時: %s ×%d" % [edef.get("display", b.get("effect_id", "")), b.get("stacks", 0)])
				"start_tile":
					bonus_texts.append("開始時: 敵陣に棘床")
		for d in mat.get("demerits", []):
			bonus_texts.append(_demerit_text(d))

	# カード一覧表示
	for card_name in deck_cards:
		var cl = Label.new()
		cl.text = "  %s" % card_name
		cl.add_theme_font_size_override("font_size", 13)
		cl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_deck_preview_container.add_child(cl)

	# ボーナスカード
	for bc in bonus_cards:
		var bl = Label.new()
		bl.text = "  %s" % bc
		bl.add_theme_font_size_override("font_size", 13)
		bl.add_theme_color_override("font_color", COLOR_BENEFIT)
		_deck_preview_container.add_child(bl)

	# その他効果
	if bonus_texts.size() > 0:
		var sep = Label.new()
		sep.text = "── 素材効果 ──"
		sep.add_theme_font_size_override("font_size", 11)
		sep.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_deck_preview_container.add_child(sep)
		for bt in bonus_texts:
			var btl = Label.new()
			btl.text = "  %s" % bt
			btl.add_theme_font_size_override("font_size", 13)
			# デメリットは赤、それ以外は緑
			if bt.begins_with("HP") or bt.begins_with("マナ") or bt.begins_with("本拠地") or bt.begins_with("SPD"):
				btl.add_theme_color_override("font_color", COLOR_DEMERIT)
			else:
				btl.add_theme_color_override("font_color", COLOR_BENEFIT)
			_deck_preview_container.add_child(btl)

func _benefit_text(b: Dictionary) -> String:
	match b.get("type", ""):
		"equipment":
			return "装備: %s" % b.get("id", "???")
		"add_unit":
			return "%s を追加" % b.get("name", "???")
		"add_spell":
			return "%s を追加" % b.get("name", "???")
		"add_random_spell":
			return "ランダム呪文を追加"
		"remove_card":
			return "カード%d枚除去" % b.get("count", 1)
		"initial_mana":
			return "初期マナ +%d" % b.get("amount", 0)
		"start_buff":
			var _edb = load("res://scripts/EffectDB.gd")
			var edef = _edb.EFFECTS.get(b.get("effect_id", ""), {})
			return "%s ×%d で開始" % [edef.get("display", ""), b.get("stacks", 0)]
		"start_tile":
			return "敵陣に棘床で開始"
	return str(b)

func _demerit_text(d: Dictionary) -> String:
	match d.get("type", ""):
		"max_hp_pct":
			return "HP %d%%" % int(d.get("amount", 0) * 100)
		"mana_regen":
			return "マナリジェネ %.1f/s (%d秒間)" % [d.get("amount", 0), d.get("duration", 0)]
		"spd_pct":
			return "SPD %d%%" % int(d.get("amount", 0) * 100)
		"base_hp":
			return "本拠地HP %d" % d.get("amount", 0)
		"start_debuff":
			return "毒が %d秒ごとに回る" % d.get("interval", 0)
	return str(d)

func _on_decide_pressed() -> void:
	if _selected_index < 0:
		return

	# 素材決定
	var chosen_material: Dictionary
	if _selected_index == 3:
		# 運命に委ねる: 全プールからランダム1つ
		var pool = _all_materials.duplicate()
		pool.shuffle()
		chosen_material = pool[0]
	else:
		chosen_material = _materials[_selected_index]

	# GameSessionに保存
	GameSession.selected_material = chosen_material

	# デッキ構築
	var deck: Array = []
	for entry in _card_db.BASE_DECK:
		deck.append(entry.duplicate())

	# クラス固有カード追加
	var cls = _card_db.CLASSES.get(GameSession.class_id, {})
	var initial = cls.get("initial_deck", [])
	if initial.size() > 0:
		deck.append({"name": initial[0], "col": 1})

	# 素材ボーナスのカード追加
	for b in chosen_material.get("benefits", []):
		match b.get("type", ""):
			"add_unit":
				deck.append({"name": b.get("name", ""), "col": b.get("col", 1)})
			"add_spell":
				deck.append({"name": b.get("name", ""), "col": -1})
			"add_random_spell":
				var spell_names = _card_db.SPELLS.keys()
				if spell_names.size() > 0:
					spell_names.shuffle()
					deck.append({"name": spell_names[0], "col": -1})

	GameSession.selected_deck = deck
	SceneManager.go_to_battle(GameSession.class_id)
