extends Control

signal popup_closed()
signal battle_ready()

var _bg_darken: ColorRect = null
var _main_panel: Panel = null
var _close_button: Button = null
var _start_button: Button = null

func _ready() -> void:
	# 背景暗転
	_bg_darken = ColorRect.new()
	_bg_darken.size = Vector2(1280, 720)
	_bg_darken.color = Color(0, 0, 0, 0.7)
	add_child(_bg_darken)

	# メインパネル（中央）
	_main_panel = Panel.new()
	_main_panel.position = Vector2(140, 60)
	_main_panel.size = Vector2(1000, 600)
	add_child(_main_panel)

	# 閉じるボタン（右上）
	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.position = Vector2(140 + 960, 60 + 10)
	_close_button.size = Vector2(30, 30)
	_close_button.pressed.connect(_on_close_pressed)
	add_child(_close_button)

	# 冒険ボタン（下部中央）
	_start_button = Button.new()
	_start_button.text = "冒険を始める"
	_start_button.position = Vector2(140 + 70, 60 + 555)
	_start_button.size = Vector2(860, 35)
	_start_button.pressed.connect(_on_start_pressed)
	add_child(_start_button)

	# TODO: DeckPrepBoard/DeckPrepInfo統合（Sprint 2後半）

func _on_close_pressed() -> void:
	popup_closed.emit()

func _on_start_pressed() -> void:
	battle_ready.emit()
