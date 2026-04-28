extends Node2D

const LOG_PREFIX := "[RewardScreen]"

var _ui_layer: CanvasLayer
var _rng: RandomNumberGenerator
var _choices: Array[int] = []

func _ready() -> void:
	print(LOG_PREFIX, " _ready wave=", GameState.current_wave)
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_choices = RewardGenerator.generate_choices(_rng)
	_setup_ui()

func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	add_child(_ui_layer)

	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15)
	bg.size = Vector2(1280, 720)
	_ui_layer.add_child(bg)

	# ヘッダー
	var header_label := Label.new()
	header_label.text = "Wave %d 突破！ ユニットを1体獲得" % GameState.current_wave
	header_label.add_theme_font_size_override("font_size", 28)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.size = Vector2(900, 60)
	header_label.position = Vector2(190, 60)
	_ui_layer.add_child(header_label)

	# 3択カード
	var card_w := 280.0
	var card_h := 380.0
	var total_w := card_w * 3.0 + 40.0 * 2.0
	var start_x := 640.0 - total_w * 0.5
	var card_y := 160.0

	for i in range(_choices.size()):
		var unit_type: int = _choices[i]
		var card_x := start_x + i * (card_w + 40.0)
		_create_unit_card(unit_type, Vector2(card_x, card_y), card_w, card_h)

	# スキップボタン（任意）
	var skip_btn := Button.new()
	skip_btn.text = "スキップ"
	skip_btn.size = Vector2(140, 44)
	skip_btn.position = Vector2(570, 600)
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.pressed.connect(_on_skip_pressed)
	_ui_layer.add_child(skip_btn)

func _create_unit_card(unit_type: int, pos: Vector2, w: float, h: float) -> void:
	var type_names := ["突", "守", "崩"]
	var type_colors := [Color(0.7, 0.2, 0.2), Color(0.2, 0.3, 0.7), Color(0.2, 0.6, 0.2)]
	var counter_texts := ["崩にx2ダメージ", "突にx2ダメージ", "守にx2・範囲攻撃"]
	var stat_keys := ["ATTACKER", "TANK", "BREAKER"]

	var card := Panel.new()
	card.size = Vector2(w, h)
	card.position = pos
	_ui_layer.add_child(card)

	# 種類名
	var name_label := Label.new()
	name_label.text = type_names[unit_type]
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(w, 60)
	name_label.position = Vector2(0, 20)
	name_label.add_theme_color_override("font_color", type_colors[unit_type])
	card.add_child(name_label)

	# ステータス表示
	var stats: Dictionary = PoCUnit.UNIT_STATS[stat_keys[unit_type]]
	var stat_label := Label.new()
	stat_label.text = "HP: %.0f\nATK: %.0f\n移動: %.1f/s\n攻撃間隔: %.1fs" % [
		stats["hp"], stats["atk"], stats["move_spd"], stats["atk_interval"]
	]
	stat_label.add_theme_font_size_override("font_size", 16)
	stat_label.size = Vector2(w - 20, 120)
	stat_label.position = Vector2(10, 90)
	card.add_child(stat_label)

	# カウンター説明
	var counter_label := Label.new()
	counter_label.text = counter_texts[unit_type]
	counter_label.add_theme_font_size_override("font_size", 15)
	counter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	counter_label.size = Vector2(w - 20, 60)
	counter_label.position = Vector2(10, 220)
	card.add_child(counter_label)

	# 選択ボタン
	var select_btn := Button.new()
	select_btn.text = "選択"
	select_btn.size = Vector2(w - 40, 50)
	select_btn.position = Vector2(20, h - 70)
	select_btn.add_theme_font_size_override("font_size", 20)
	var captured_type := unit_type
	select_btn.pressed.connect(func(): _on_select_pressed(captured_type))
	card.add_child(select_btn)

func _on_select_pressed(unit_type: int) -> void:
	print(LOG_PREFIX, " selected unit_type=", unit_type)
	var ok := GameState.add_to_deck(unit_type)
	if not ok:
		# デッキ満杯（MVPでは通常発生しない）
		print(LOG_PREFIX, " deck full!")
	GameState.current_wave += 1
	print(LOG_PREFIX, " next wave=", GameState.current_wave)
	get_tree().change_scene_to_file("res://scenes/hex_mvp/DeploymentScreen.tscn")

func _on_skip_pressed() -> void:
	print(LOG_PREFIX, " skip pressed")
	GameState.current_wave += 1
	get_tree().change_scene_to_file("res://scenes/hex_mvp/DeploymentScreen.tscn")
