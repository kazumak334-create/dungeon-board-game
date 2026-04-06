# Title.gd
# TOP画面: クラス選択 + 出発
extends Control

var _card_db: RefCounted
var _selected_class_id: String = ""
var _class_buttons: Dictionary = {}
var _description_label: Label
var _skill_label: Label
var _start_button: Button

func _ready() -> void:
	_card_db = load("res://scripts/CardDB.gd").new()
	_build_ui()
	# デフォルト選択
	var class_ids = _card_db.CLASSES.keys()
	if class_ids.size() > 0:
		_select_class(class_ids[0])

func _build_ui() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# タイトル
	var title = Label.new()
	title.text = "DUNGEON BOARD GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 60)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	add_child(title)

	# クラス選択ボタン群
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(190, 150)
	button_container.size = Vector2(900, 200)
	button_container.add_theme_constant_override("separation", 40)
	add_child(button_container)

	for class_id in _card_db.CLASSES:
		var cls = _card_db.CLASSES[class_id]
		var btn = _create_class_button(class_id, cls)
		button_container.add_child(btn)
		_class_buttons[class_id] = btn

	# クラス説明
	_description_label = Label.new()
	_description_label.position = Vector2(190, 380)
	_description_label.size = Vector2(900, 30)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.add_theme_font_size_override("font_size", 18)
	_description_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(_description_label)

	# パッシブスキル
	_skill_label = Label.new()
	_skill_label.position = Vector2(190, 420)
	_skill_label.size = Vector2(900, 80)
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_skill_label.add_theme_font_size_override("font_size", 14)
	_skill_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	add_child(_skill_label)

	# 出発ボタン
	_start_button = Button.new()
	_start_button.text = "出  発"
	_start_button.position = Vector2(515, 560)
	_start_button.size = Vector2(250, 60)
	_start_button.add_theme_font_size_override("font_size", 24)
	_start_button.pressed.connect(_on_start_pressed)
	add_child(_start_button)

func _create_class_button(class_id: String, cls: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 200)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.22)
	style_normal.border_color = Color(0.3, 0.3, 0.4)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style_normal)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# クラス名
	var name_label = Label.new()
	name_label.text = cls.get("display", class_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	vbox.add_child(name_label)

	# マナ情報
	var mana_label = Label.new()
	mana_label.text = "マナ上限: %d  リジェネ: %.1f/s" % [int(cls.get("mana_max", 10)), cls.get("mana_regen", 1.0)]
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label.add_theme_font_size_override("font_size", 13)
	mana_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	vbox.add_child(mana_label)

	# 説明（短縮版）
	var desc = Label.new()
	desc.text = cls.get("description", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc)

	panel.add_child(vbox)

	# クリック検出
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_class(class_id)
	)

	return panel

func _select_class(class_id: String) -> void:
	_selected_class_id = class_id
	var cls = _card_db.CLASSES.get(class_id, {})

	_description_label.text = cls.get("description", "")

	# スキル表示
	var skill_texts: Array = []
	var _edb = load("res://scripts/EffectDB.gd")
	for skill in cls.get("skills", []):
		var eid = skill.get("effect_id", "")
		var edef = _edb.EFFECTS.get(eid, {})
		skill_texts.append("▸ %s" % edef.get("display", eid))
	_skill_label.text = "パッシブスキル:\n" + "\n".join(skill_texts) if skill_texts.size() > 0 else ""

	# 選択枠の更新
	for cid in _class_buttons:
		var panel = _class_buttons[cid] as PanelContainer
		var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if cid == class_id:
			style.border_color = Color(0.9, 0.75, 0.3)
			style.set_border_width_all(3)
		else:
			style.border_color = Color(0.3, 0.3, 0.4)
			style.set_border_width_all(2)

func _on_start_pressed() -> void:
	if _selected_class_id == "":
		return
	GameSession.class_id = _selected_class_id
	SceneManager.go_to("material_select")
