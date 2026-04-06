# Event.gd
# イベント画面（スタブ）: 将来はランダムイベント選択肢
extends Control

const UIF = preload("res://scripts/UIFactory.gd")

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)
	UIF.add_title(self, "イベント")

	# イベントパネル
	var panel = UIF.create_panel(Vector2(340, 150), Vector2(600, 300), Color(0.12, 0.12, 0.18), Color(0.3, 0.3, 0.4))
	add_child(panel)

	var desc = Label.new()
	desc.text = "道端で不思議な老人に出会った...\n\n「何か選ぶがよい」"
	desc.position = Vector2(370, 180)
	desc.size = Vector2(540, 100)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", UIF.TEXT_COLOR)
	add_child(desc)

	UIF.add_button(self, "話を聞く（準備中）", Vector2(440, 320), Vector2(400, 45), 16)
	UIF.add_button(self, "無視して進む", Vector2(440, 375), Vector2(400, 45), 16, func(): SceneManager.go_to(SceneManager.MAP_SELECT))
	UIF.add_back_button(self, "← マップへ", func(): SceneManager.go_to(SceneManager.MAP_SELECT))
