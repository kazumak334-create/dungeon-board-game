# Settings.gd
# 設定画面（タスクバー⚙から遷移）
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.SETTINGS)

	var title = Label.new()
	title.text = "設定"
	title.position = Vector2(0, 50)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(title)

	# TODO: 音量、速度、キー設定等（Phase 6実装）
	var placeholder = Label.new()
	placeholder.text = "（設定項目: Phase 6で実装予定）"
	placeholder.position = Vector2(0, 300)
	placeholder.size = Vector2(1280, 40)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.add_theme_font_size_override("font_size", 16)
	placeholder.add_theme_color_override("font_color", UIF.DIM_COLOR)
	add_child(placeholder)

	var back_btn = Button.new()
	back_btn.text = "戻る"
	back_btn.position = Vector2(590, 650)
	back_btn.size = Vector2(100, 36)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _on_back() -> void:
	SceneManager.go_to(SceneManager.MAP_SELECT)
