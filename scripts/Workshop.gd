# Workshop.gd
# 工房画面: 合成レシピ一覧（装備/カード合成）+ モンハン鍛冶屋式UI
extends Control

const UIF = preload("res://scripts/UIFactory.gd")

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)
	UIF.add_title(self, "工房", 40, 28)

	# 所持素材サマリ（上部）
	var mat_summary = ""
	var mat_counts: Dictionary = {}
	for mat in GameSession.materials:
		var name = mat.get("display", "???")
		mat_counts[name] = mat_counts.get(name, 0) + 1
	for name in mat_counts:
		if mat_summary != "":
			mat_summary += "  "
		mat_summary += "%s×%d" % [name, mat_counts[name]]
	if mat_summary == "":
		mat_summary = "素材なし"

	var mat_label = Label.new()
	mat_label.text = "所持素材: %s" % mat_summary
	mat_label.position = Vector2(30, 80)
	mat_label.size = Vector2(900, 20)
	mat_label.add_theme_font_size_override("font_size", 12)
	mat_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
	add_child(mat_label)

	# 合成レシピ一覧（左側）
	var recipe_panel = UIF.create_panel(Vector2(30, 110), Vector2(550, 450))
	add_child(recipe_panel)

	var recipe_header = Label.new()
	recipe_header.text = "合成レシピ"
	recipe_header.position = Vector2(45, 118)
	recipe_header.add_theme_font_size_override("font_size", 15)
	recipe_header.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(recipe_header)

	# フィルタ（将来: [全部] [装備] [消費] [カード]）
	var filter_label = Label.new()
	filter_label.text = "[全部]  [装備]  [カード]"
	filter_label.position = Vector2(45, 140)
	filter_label.add_theme_font_size_override("font_size", 11)
	filter_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(filter_label)

	# レシピ一覧（仮: cards.jsonのsynthesisから）
	var y = 165
	var found = false
	for recipe in CardDB.SYNTHESIS:
		var base = recipe.get("base", "")
		var card = recipe.get("card", "")
		var result_name = recipe.get("result", "")

		# 素材チェック（簡易: デッキ内カード枚数）
		var can_craft = false  # 将来: 素材照合

		var lbl = Label.new()
		lbl.text = "%s + %s → %s" % [base, card, result_name]
		lbl.position = Vector2(45, y)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", UIF.BENEFIT_COLOR if can_craft else UIF.DIM_COLOR)
		add_child(lbl)
		y += 22
		found = true

		if y > 530:
			break

	if not found:
		var empty = Label.new()
		empty.text = "レシピなし"
		empty.position = Vector2(45, y)
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", UIF.DIM_COLOR)
		add_child(empty)

	# 合成結果プレビュー（右側）
	var preview_panel = UIF.create_panel(Vector2(610, 110), Vector2(350, 450))
	add_child(preview_panel)

	var preview_header = Label.new()
	preview_header.text = "合成プレビュー"
	preview_header.position = Vector2(625, 118)
	preview_header.add_theme_font_size_override("font_size", 15)
	preview_header.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(preview_header)

	var preview_hint = Label.new()
	preview_hint.text = "レシピを選択すると\n詳細が表示されます"
	preview_hint.position = Vector2(625, 250)
	preview_hint.add_theme_font_size_override("font_size", 13)
	preview_hint.add_theme_color_override("font_color", UIF.DIM_COLOR)
	add_child(preview_hint)

	# 装備スロット（右下）
	var equip_label = Label.new()
	equip_label.text = "── 装備中 ──"
	equip_label.position = Vector2(625, 470)
	equip_label.add_theme_font_size_override("font_size", 12)
	equip_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.6))
	add_child(equip_label)

	var equip_hint = Label.new()
	equip_hint.text = "装備なし"
	equip_hint.position = Vector2(625, 490)
	equip_hint.add_theme_font_size_override("font_size", 11)
	equip_hint.add_theme_color_override("font_color", UIF.DIM_COLOR)
	add_child(equip_hint)

	# マップへ戻る
	UIF.add_back_button(self, "← マップへ", func(): SceneManager.go_to(SceneManager.MAP_SELECT), 600)
