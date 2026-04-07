# DeckView.gd
# デッキ確認画面（タスクバー🎴から遷移）
# 現在のデッキ内容を一覧表示する
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null
var _prev_scene: String = ""

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.DECK_VIEW)

	var title = Label.new()
	title.text = "デッキ確認"
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(title)

	# TODO: デッキ一覧表示（implementerが実装）
	var placeholder = Label.new()
	placeholder.text = "（デッキ一覧表示：実装予定）"
	placeholder.position = Vector2(0, 300)
	placeholder.size = Vector2(1280, 40)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.add_theme_font_size_override("font_size", 16)
	placeholder.add_theme_color_override("font_color", UIF.DIM_COLOR)
	add_child(placeholder)

	# 戻るボタン
	var back_btn = Button.new()
	back_btn.text = "戻る"
	back_btn.position = Vector2(590, 650)
	back_btn.size = Vector2(100, 36)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _on_back() -> void:
	# 前の画面に戻る（呼び出し元から記憶しておく想定）
	SceneManager.go_to(SceneManager.MAP_SELECT)
