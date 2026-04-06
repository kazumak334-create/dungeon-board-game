# DeckPrep.gd
# デッキ準備画面（スタブ）: デッキ/素材一覧表示 + マップへ遷移
extends Control

const UIF = preload("res://scripts/UIFactory.gd")

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)
	UIF.add_title(self, "デッキ準備", 20)

	var cls = CardDB.CLASSES.get(GameSession.class_id, {})
	UIF.add_subtitle(self, "クラス: %s" % cls.get("display", GameSession.class_id), 58)

	# デッキ一覧（左側）
	var deck_panel = UIF.create_panel(Vector2(40, 100), Vector2(380, 400))
	add_child(deck_panel)
	var deck_header = Label.new()
	deck_header.text = "デッキ (%d枚)" % GameSession.selected_deck.size()
	deck_header.position = Vector2(10, 5)
	deck_header.add_theme_font_size_override("font_size", 15)
	deck_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	deck_panel.add_child(deck_header)

	var deck_vbox = VBoxContainer.new()
	deck_vbox.position = Vector2(50, 140)
	deck_vbox.size = Vector2(360, 350)
	add_child(deck_vbox)

	for entry in GameSession.selected_deck:
		var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
		var cl = Label.new()
		cl.text = "  %s" % card_name
		cl.add_theme_font_size_override("font_size", 14)
		cl.add_theme_color_override("font_color", UIF.TEXT_COLOR)
		deck_vbox.add_child(cl)

	# 素材一覧（中央）
	var mat_panel = UIF.create_panel(Vector2(450, 100), Vector2(380, 400))
	add_child(mat_panel)
	var mat_header = Label.new()
	mat_header.text = "素材"
	mat_header.position = Vector2(10, 5)
	mat_header.add_theme_font_size_override("font_size", 15)
	mat_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	mat_panel.add_child(mat_header)

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
			ml.add_theme_color_override("font_color", UIF.BENEFIT_COLOR)
			mat_vbox.add_child(ml)
	else:
		var empty_label = Label.new()
		empty_label.text = "  素材なし"
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", UIF.DIM_COLOR)
		mat_vbox.add_child(empty_label)

	# 選択素材情報（右側）
	var info_panel = UIF.create_panel(Vector2(860, 100), Vector2(380, 400))
	add_child(info_panel)
	var info_header = Label.new()
	info_header.text = "選択中の素材"
	info_header.position = Vector2(10, 5)
	info_header.add_theme_font_size_override("font_size", 15)
	info_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	info_panel.add_child(info_header)

	var info_vbox = VBoxContainer.new()
	info_vbox.position = Vector2(870, 140)
	info_vbox.size = Vector2(360, 350)
	add_child(info_vbox)

	var sel_mat = GameSession.selected_material
	if sel_mat.size() > 0:
		var name_l = Label.new()
		name_l.text = "  %s" % sel_mat.get("display", "???")
		name_l.add_theme_font_size_override("font_size", 16)
		name_l.add_theme_color_override("font_color", UIF.TITLE_COLOR)
		info_vbox.add_child(name_l)

		var desc_l = Label.new()
		desc_l.text = "  %s" % sel_mat.get("description", "")
		desc_l.add_theme_font_size_override("font_size", 13)
		desc_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info_vbox.add_child(desc_l)

	UIF.add_button(self, "マップへ", Vector2(515, 550), Vector2(250, 55), 22, func(): SceneManager.go_to(SceneManager.MAP_SELECT))
	UIF.add_back_button(self, "← タイトルへ", func():
		GameSession.reset()
		SceneManager.go_to(SceneManager.TITLE)
	)
