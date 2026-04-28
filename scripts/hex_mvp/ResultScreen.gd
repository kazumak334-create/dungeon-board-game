extends Node2D

const LOG_PREFIX := "[ResultScreen]"

var _ui_layer: CanvasLayer

func _ready() -> void:
	var player_won: bool = GameState.last_battle_won
	var wave: int = GameState.current_wave
	print(LOG_PREFIX, " _ready player_won=", player_won, " wave=", wave)
	_setup_ui(player_won, wave)

func _setup_ui(player_won: bool, wave: int) -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	add_child(_ui_layer)

	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.size = Vector2(1280, 720)
	_ui_layer.add_child(bg)

	# 結果ラベル
	var result_label := Label.new()
	result_label.add_theme_font_size_override("font_size", 56)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.size = Vector2(800, 100)
	result_label.position = Vector2(240, 240)

	if player_won:
		result_label.text = "ステージクリア！"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	else:
		result_label.text = "Wave %d で敗北" % wave
		result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

	_ui_layer.add_child(result_label)

	# サブラベル
	var sub_label := Label.new()
	sub_label.add_theme_font_size_override("font_size", 24)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.size = Vector2(600, 50)
	sub_label.position = Vector2(340, 360)
	if player_won:
		sub_label.text = "3Waveを制覇しました"
	else:
		sub_label.text = "次は配置を変えてみよう"
	_ui_layer.add_child(sub_label)

	# タイトルへボタン
	var btn := Button.new()
	btn.text = "タイトルへ"
	btn.size = Vector2(200, 60)
	btn.position = Vector2(540, 440)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_on_title_button_pressed)
	_ui_layer.add_child(btn)

func _on_title_button_pressed() -> void:
	print(LOG_PREFIX, " title button pressed")
	get_tree().change_scene_to_file("res://scenes/hex_mvp/TitleScreen.tscn")
