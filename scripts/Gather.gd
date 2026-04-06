# Gather.gd
# 素材採集画面（スタブ）: ランダム素材を入手
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
var _gathered: Array = []

func _ready() -> void:
	_gather_materials()
	_build_ui()

func _gather_materials() -> void:
	if CardDB.MATERIALS.size() == 0:
		return
	var pool = CardDB.MATERIALS.duplicate()
	pool.shuffle()
	var count = randi_range(1, 2)
	for i in range(min(count, pool.size())):
		_gathered.append(pool[i])
		GameSession.materials.append(pool[i])

func _build_ui() -> void:
	UIF.add_bg(self)
	UIF.add_title(self, "素材採集")
	UIF.add_subtitle(self, "以下の素材を入手した！", 120, UIF.BENEFIT_COLOR)

	# 入手素材カード表示
	var cards_container = HBoxContainer.new()
	cards_container.position = Vector2(390, 180)
	cards_container.size = Vector2(500, 200)
	cards_container.add_theme_constant_override("separation", 20)
	add_child(cards_container)

	for mat in _gathered:
		var is_cursed = mat.get("is_cursed", false)
		var panel = UIF.create_panel(Vector2.ZERO, Vector2(200, 180),
			Color(0.25, 0.1, 0.1) if is_cursed else Color(0.13, 0.13, 0.2),
			Color(0.9, 0.3, 0.3) if is_cursed else Color(0.4, 0.6, 0.3), 2, 8)
		panel.custom_minimum_size = Vector2(200, 180)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)

		var name_l = Label.new()
		name_l.text = mat.get("display", "???")
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_size_override("font_size", 18)
		name_l.add_theme_color_override("font_color", UIF.TITLE_COLOR)
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
		UIF.add_subtitle(self, "何も見つからなかった...", 250, UIF.DIM_COLOR)

	UIF.add_button(self, "マップへ戻る", Vector2(515, 450), Vector2(250, 55), 20, func(): SceneManager.go_to(SceneManager.MAP_SELECT))
