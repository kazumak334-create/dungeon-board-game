# DeckPrep.gd
# デッキ準備画面（スタブ）: デッキ/素材一覧表示 + バトルへ遷移
extends Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# タイトル
	var title = Label.new()
	title.text = "デッキ準備"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(1280, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	add_child(title)

	# クラス表示
	var cls = CardDB.CLASSES.get(GameSession.class_id, {})
	var class_label = Label.new()
	class_label.text = "クラス: %s" % cls.get("display", GameSession.class_id)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.position = Vector2(0, 58)
	class_label.size = Vector2(1280, 25)
	class_label.add_theme_font_size_override("font_size", 16)
	class_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	add_child(class_label)

	# デッキ一覧（左側）
	var deck_panel = _create_section_panel(Vector2(40, 100), Vector2(380, 400), "デッキ (%d枚)" % GameSession.selected_deck.size())
	add_child(deck_panel)

	var deck_vbox = VBoxContainer.new()
	deck_vbox.position = Vector2(50, 140)
	deck_vbox.size = Vector2(360, 350)
	add_child(deck_vbox)

	for entry in GameSession.selected_deck:
		var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
		var cl = Label.new()
		cl.text = "  %s" % card_name
		cl.add_theme_font_size_override("font_size", 14)
		cl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		deck_vbox.add_child(cl)

	# 素材一覧（中央）
	var mat_panel = _create_section_panel(Vector2(450, 100), Vector2(380, 400), "素材")
	add_child(mat_panel)

	var mat_vbox = VBoxContainer.new()
	mat_vbox.position = Vector2(460, 140)
	mat_vbox.size = Vector2(360, 350)
	add_child(mat_vbox)

	var materials = GameSession.materials
	if materials.size() > 0:
		for mat in materials:
			var ml = Label.new()
			ml.text = "  %s" % mat.get("display", "???")
			ml.add_theme_font_size_override("font_size", 14)
			ml.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
			mat_vbox.add_child(ml)
	else:
		var empty_label = Label.new()
		empty_label.text = "  素材なし"
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		mat_vbox.add_child(empty_label)

	# 選択素材情報（右側）
	var info_panel = _create_section_panel(Vector2(860, 100), Vector2(380, 400), "選択中の素材")
	add_child(info_panel)

	var info_vbox = VBoxContainer.new()
	info_vbox.position = Vector2(870, 140)
	info_vbox.size = Vector2(360, 350)
	add_child(info_vbox)

	var sel_mat = GameSession.selected_material
	if sel_mat.size() > 0:
		var name_l = Label.new()
		name_l.text = "  %s" % sel_mat.get("display", "???")
		name_l.add_theme_font_size_override("font_size", 16)
		name_l.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
		info_vbox.add_child(name_l)

		var desc_l = Label.new()
		desc_l.text = "  %s" % sel_mat.get("description", "")
		desc_l.add_theme_font_size_override("font_size", 13)
		desc_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info_vbox.add_child(desc_l)

	# マップへボタン
	var map_btn = Button.new()
	map_btn.text = "マップへ"
	map_btn.position = Vector2(515, 550)
	map_btn.size = Vector2(250, 55)
	map_btn.add_theme_font_size_override("font_size", 22)
	map_btn.pressed.connect(func(): SceneManager.go_to("map_select"))
	add_child(map_btn)

	# タイトルへ戻る
	var back_btn = Button.new()
	back_btn.text = "← タイトルへ"
	back_btn.position = Vector2(40, 550)
	back_btn.size = Vector2(150, 45)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(func():
		GameSession.reset()
		SceneManager.go_to("title")
	)
	add_child(back_btn)

func _create_section_panel(pos: Vector2, sz: Vector2, header_text: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = pos
	panel.size = sz

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.25, 0.35)
	panel.add_theme_stylebox_override("panel", style)

	var header = Label.new()
	header.text = header_text
	header.position = Vector2(10, 5)
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	panel.add_child(header)

	return panel
