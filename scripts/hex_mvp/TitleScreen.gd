extends Node2D

var _ui_layer: CanvasLayer
var _start_button: Button

func _ready() -> void:
	print("[TitleScreen] _ready called")
	_setup_ui()

func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	add_child(_ui_layer)

	# 背景
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.1, 0.1, 0.15)
	bg.size = Vector2(1280, 720)
	_ui_layer.add_child(bg)

	# タイトルラベル
	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "ヘックスバトルMVP"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size = Vector2(600, 80)
	title_label.position = Vector2(340, 200)
	_ui_layer.add_child(title_label)

	# ゲーム開始ボタン
	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "ゲーム開始"
	_start_button.size = Vector2(200, 60)
	_start_button.position = Vector2(540, 360)
	_start_button.add_theme_font_size_override("font_size", 24)
	_ui_layer.add_child(_start_button)
	_start_button.pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed() -> void:
	print("[TitleScreen] start button pressed")
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/hex_mvp/DeploymentScreen.tscn")
