# Inventory.gd
# 持ち物画面（タスクバー🎒から遷移）
# DeckPrepの持ち物タブから独立させた画面
# 正方形グリッド(55×55)+装備統合+ソートタブ
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null
var _selected_filter: String = "all"

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.INVENTORY)

	var title = Label.new()
	title.text = "持ち物"
	title.position = Vector2(0, 50)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(title)

	# TODO: 正方形グリッド+ソートタブ（implementerが実装、DeckPrep.gdから移植）
	var placeholder = Label.new()
	placeholder.text = "（持ち物グリッド: DeckPrep.gdから移植予定）"
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
