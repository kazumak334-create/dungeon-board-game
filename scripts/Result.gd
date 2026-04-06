# Result.gd
# バトル結果画面（スタブ）: 勝敗表示 + 仮報酬 + 遷移
extends Control

var _reward_gold: int = 0
var _reward_sp: int = 0
var _reward_material: Dictionary = {}

func _ready() -> void:
	_generate_rewards()
	_build_ui()

func _generate_rewards() -> void:
	var is_win = GameSession.last_result.get("win", false)
	if not is_win:
		return
	# 仮報酬（将来: 敵に応じたアルゴリズム）
	_reward_gold = 100
	_reward_sp = 1
	if CardDB.MATERIALS.size() > 0:
		var pool = CardDB.MATERIALS.duplicate()
		pool.shuffle()
		_reward_material = pool[0]
	# GameSessionに反映
	GameSession.gold += _reward_gold
	GameSession.skill_points += _reward_sp
	if _reward_material.size() > 0:
		GameSession.materials.append(_reward_material)

func _build_ui() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var result = GameSession.last_result
	var is_win = result.get("win", false)

	# 勝敗表示
	var result_label = Label.new()
	result_label.text = "VICTORY" if is_win else "DEFEAT"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.position = Vector2(0, 80)
	result_label.size = Vector2(1280, 60)
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3) if is_win else Color(0.8, 0.2, 0.2))
	add_child(result_label)

	# バトル情報
	var info_panel = PanelContainer.new()
	info_panel.position = Vector2(390, 180)
	info_panel.size = Vector2(500, 150)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.set_corner_radius_all(6)
	info_panel.add_theme_stylebox_override("panel", style)
	add_child(info_panel)

	var info_vbox = VBoxContainer.new()
	info_vbox.position = Vector2(400, 195)
	info_vbox.size = Vector2(480, 130)
	info_vbox.add_theme_constant_override("separation", 5)
	add_child(info_vbox)

	var hp_label = Label.new()
	hp_label.text = "残りHP: %d" % result.get("player_hp_remaining", 0)
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	info_vbox.add_child(hp_label)

	var turns_label = Label.new()
	turns_label.text = "ターン数: %d" % result.get("turns", 0)
	turns_label.add_theme_font_size_override("font_size", 16)
	turns_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	info_vbox.add_child(turns_label)

	# 仮報酬
	var reward_header = Label.new()
	reward_header.text = "── 報酬 ──"
	reward_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_header.position = Vector2(0, 360)
	reward_header.size = Vector2(1280, 25)
	reward_header.add_theme_font_size_override("font_size", 16)
	reward_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	add_child(reward_header)

	var reward_vbox = VBoxContainer.new()
	reward_vbox.position = Vector2(490, 395)
	reward_vbox.size = Vector2(300, 100)
	reward_vbox.add_theme_constant_override("separation", 5)
	add_child(reward_vbox)

	if is_win:
		var gold_label = Label.new()
		gold_label.text = "通貨: %dG" % _reward_gold
		gold_label.add_theme_font_size_override("font_size", 15)
		gold_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		reward_vbox.add_child(gold_label)

		var sp_label = Label.new()
		sp_label.text = "スキルポイント: %d" % _reward_sp
		sp_label.add_theme_font_size_override("font_size", 15)
		sp_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
		reward_vbox.add_child(sp_label)

		var mat_name = _reward_material.get("display", "なし")
		var mat_label = Label.new()
		mat_label.text = "素材: %s" % mat_name
		mat_label.add_theme_font_size_override("font_size", 15)
		mat_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.5))
		reward_vbox.add_child(mat_label)
	else:
		var no_reward = Label.new()
		no_reward.text = "報酬なし"
		no_reward.add_theme_font_size_override("font_size", 15)
		no_reward.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		reward_vbox.add_child(no_reward)

	# 続けるボタン（勝利時）
	if is_win:
		var continue_btn = Button.new()
		continue_btn.text = "続ける"
		continue_btn.position = Vector2(515, 540)
		continue_btn.size = Vector2(250, 55)
		continue_btn.add_theme_font_size_override("font_size", 22)
		# ボス戦ならボス報酬画面へ、通常はデッキ準備へ
		var next_scene = "boss_reward" if GameSession.battle_type == "boss" else "deck_prep"
		continue_btn.pressed.connect(func(): SceneManager.go_to(next_scene))
		add_child(continue_btn)

	# タイトルへボタン
	var title_btn = Button.new()
	title_btn.text = "タイトルへ"
	title_btn.position = Vector2(515, 610)
	title_btn.size = Vector2(250, 45)
	title_btn.add_theme_font_size_override("font_size", 18)
	title_btn.pressed.connect(func():
		GameSession.reset()
		SceneManager.go_to("title")
	)
	add_child(title_btn)
