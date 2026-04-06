# Gather.gd
# 素材採集画面（スタブ）: ランダム素材を入手
extends Control

var _gathered: Array = []

func _ready() -> void:
	_gather_materials()
	_build_ui()

func _gather_materials() -> void:
	# 仮: ランダム素材を1〜2個入手
	if CardDB.MATERIALS.size() == 0:
		return
	var pool = CardDB.MATERIALS.duplicate()
	pool.shuffle()
	var count = randi_range(1, 2)
	for i in range(min(count, pool.size())):
		_gathered.append(pool[i])
		GameSession.materials.append(pool[i])

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title = Label.new()
	title.text = "素材採集"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	add_child(title)

	var result_label = Label.new()
	result_label.text = "以下の素材を入手した！"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.position = Vector2(0, 120)
	result_label.size = Vector2(1280, 25)
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.5))
	add_child(result_label)

	# 入手素材カード表示
	var cards_container = HBoxContainer.new()
	cards_container.position = Vector2(390, 180)
	cards_container.size = Vector2(500, 200)
	cards_container.add_theme_constant_override("separation", 20)
	add_child(cards_container)

	for mat in _gathered:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(200, 180)
		var style = StyleBoxFlat.new()
		var is_cursed = mat.get("is_cursed", false)
		style.bg_color = Color(0.25, 0.1, 0.1) if is_cursed else Color(0.13, 0.13, 0.2)
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		style.border_color = Color(0.9, 0.3, 0.3) if is_cursed else Color(0.4, 0.6, 0.3)
		panel.add_theme_stylebox_override("panel", style)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)

		var name_l = Label.new()
		name_l.text = mat.get("display", "???")
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_size_override("font_size", 18)
		name_l.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
		vbox.add_child(name_l)

		var desc_l = Label.new()
		desc_l.text = mat.get("description", "")
		desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_l.add_theme_font_size_override("font_size", 13)
		desc_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(desc_l)

		panel.add_child(vbox)
		cards_container.add_child(panel)

	if _gathered.size() == 0:
		var empty = Label.new()
		empty.text = "何も見つからなかった..."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.position = Vector2(0, 250)
		empty.size = Vector2(1280, 25)
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		add_child(empty)

	var back_btn = Button.new()
	back_btn.text = "マップへ戻る"
	back_btn.position = Vector2(515, 450)
	back_btn.size = Vector2(250, 55)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(func(): SceneManager.go_to("map_select"))
	add_child(back_btn)
