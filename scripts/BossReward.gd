# BossReward.gd
# ボス報酬画面（スタブ）: ボス撃破後の特別報酬3択
extends Control

const UIF = preload("res://scripts/UIFactory.gd")

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self, Color(0.06, 0.05, 0.1))
	UIF.add_title(self, "ボス報酬", 40, 32, Color(0.95, 0.7, 0.2))
	UIF.add_subtitle(self, "特別な報酬を1つ選べ", 85, Color(0.7, 0.65, 0.5))

	# 3択カード
	var choices = [
		{"name": "呪いの素材", "desc": "強力だが代償を伴う素材", "color": Color(0.9, 0.3, 0.3)},
		{"name": "レア装備", "desc": "希少な装備品", "color": Color(0.3, 0.7, 0.9)},
		{"name": "スキルポイント×3", "desc": "大量のスキルポイント", "color": Color(0.5, 0.9, 0.4)},
	]

	var cards_container = HBoxContainer.new()
	cards_container.position = Vector2(165, 150)
	cards_container.size = Vector2(950, 320)
	cards_container.add_theme_constant_override("separation", 30)
	add_child(cards_container)

	for choice in choices:
		var panel = UIF.create_panel(Vector2.ZERO, Vector2(280, 320), Color(0.12, 0.1, 0.18), choice["color"] * 0.5, 2, 10)
		panel.custom_minimum_size = Vector2(280, 320)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 15)

		var name_l = Label.new()
		name_l.text = choice["name"]
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_size_override("font_size", 20)
		name_l.add_theme_color_override("font_color", choice["color"])
		vbox.add_child(name_l)

		var desc_l = Label.new()
		desc_l.text = choice["desc"]
		desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_l.add_theme_font_size_override("font_size", 14)
		desc_l.add_theme_color_override("font_color", UIF.TEXT_COLOR)
		vbox.add_child(desc_l)

		var coming = Label.new()
		coming.text = "（準備中）"
		coming.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coming.add_theme_font_size_override("font_size", 13)
		coming.add_theme_color_override("font_color", UIF.DIM_COLOR)
		vbox.add_child(coming)

		panel.add_child(vbox)
		cards_container.add_child(panel)

	UIF.add_button(self, "続ける", Vector2(515, 530), Vector2(250, 55), 22, func(): _on_continue())

func _on_continue() -> void:
	# ボス撃破後、次Actへ進む
	GameSession.current_act += 1
	GameSession.alert_level = 0
	if GameSession.current_act > 3:
		# Act 3クリア → エンディング（Phase 6実装予定）
		print("[BossReward] ゲームクリア（エンディング未実装）")
		GameSession.reset()
		SceneManager.go_to(SceneManager.TITLE)
	else:
		# 次Actのマップ生成
		GameSession.current_node = ""
		GameSession.completed_nodes = []
		var gen = load("res://scripts/MapGenerator.gd").new()
		GameSession.map_data = gen.generate(GameSession.map_seed, GameSession.race_theme)
		print("[BossReward] Act %d へ進行" % GameSession.current_act)
		SceneManager.go_to(SceneManager.MAP_SELECT)
