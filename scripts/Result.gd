# Result.gd
# バトル結果画面: 勝敗表示 + 報酬 + カード3択（StS方式）
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")
const RewardTableClass = preload("res://scripts/RewardTable.gd")

var _taskbar: RefCounted = null
var _reward_gold: int = 0
var _reward_sp: int = 0
var _reward_material: Dictionary = {}
var _card_choices: Array = []  # 3択カードの{name, data, is_unit}
var _card_selected: bool = false

# レアリティ色
const RARITY_COLORS = {
	"common": Color(0.7, 0.7, 0.7),
	"uncommon": Color(0.3, 0.8, 0.3),
	"rare": Color(0.3, 0.5, 0.9),
	"epic": Color(0.7, 0.3, 0.9),
	"legend": Color(0.9, 0.7, 0.2),
	"god": Color(0.9, 0.3, 0.3),
}

func _ready() -> void:
	_cleanup_battle_cards()
	_generate_rewards()
	if GameSession.last_result.get("win", false):
		_generate_card_choices()
	_build_ui()

func _cleanup_battle_cards() -> void:
	var new_deck: Array = []
	var new_config: Array = []
	for i in range(GameSession.selected_deck.size()):
		var entry = GameSession.selected_deck[i]
		var card_name = entry.get("name", "") if entry is Dictionary else str(entry)
		var persistence = _get_card_persistence(card_name)
		if persistence != "battle":
			new_deck.append(entry)
			if i < GameSession.placement_config.size():
				new_config.append(GameSession.placement_config[i])
	var removed = GameSession.selected_deck.size() - new_deck.size()
	GameSession.selected_deck = new_deck
	GameSession.placement_config = new_config
	if removed > 0:
		print("[Result] バトル後クリーンアップ: %d枚除去" % removed)

func _get_card_persistence(card_name: String) -> String:
	if CardDB.STATUS_SPELLS.has(card_name):
		return CardDB.STATUS_SPELLS[card_name].get("persistence", "permanent")
	if CardDB.UNITS.has(card_name):
		return CardDB.UNITS[card_name].get("persistence", "permanent")
	if CardDB.SPELLS.has(card_name):
		return CardDB.SPELLS[card_name].get("persistence", "permanent")
	return "permanent"

func _generate_rewards() -> void:
	var is_win = GameSession.last_result.get("win", false)
	if not is_win:
		return
	# バトル中の撃破ドロップgoldを確定加算
	var battle_gold: int = GameSession.last_result.get("battle_gold", GameSession.current_battle_gold)
	GameSession.gold += battle_gold
	# 固定報酬: 勝利ボーナス
	_reward_gold = 100
	_reward_sp = 3  # Phase 2: スキルツリー報酬（3SP固定）

	# レリック効果: gold_bonus
	var gold_bonus_total: float = 0.0
	for relic_id in GameSession.relics:
		if not CardDB.RELICS.has(relic_id):
			continue
		var relic = CardDB.RELICS[relic_id]
		var effect = relic.get("effect", {})
		if effect.get("type", "") == "gold_bonus":
			gold_bonus_total += effect.get("value", 0.0)
	if gold_bonus_total > 0.0:
		var bonus_amount = int(_reward_gold * gold_bonus_total)
		_reward_gold += bonus_amount
		print("[Result] レリック gold_bonus: +%d%% → +%dG (合計: %dG)" % [int(gold_bonus_total * 100), bonus_amount, _reward_gold])
	if CardDB.MATERIALS.size() > 0:
		var pool = CardDB.MATERIALS.duplicate()
		pool.shuffle()
		_reward_material = pool[0]
	GameSession.gold += _reward_gold
	GameSession.skill_points += _reward_sp
	# 素材報酬は廃止（装備・素材システム廃止により削除）
	# current_battle_goldをリセット（次バトルに持ち越さない）
	GameSession.current_battle_gold = 0

func _generate_card_choices() -> void:
	# ボス戦: レリック確定3択
	if GameSession.battle_type == "boss":
		_generate_boss_relic_choices()
		return

	# run_depthに応じた重みテーブル選択（エリート混入時はステージ+1）
	var weights: Dictionary = RewardTableClass.get_weights(GameSession.run_depth, GameSession.elite_injected_in_battle)
	var effective = RewardTableClass.effective_stage(GameSession.run_depth, GameSession.elite_injected_in_battle)
	print("[Result] run_depth=%d elite=%s stage=%d" % [GameSession.run_depth, GameSession.elite_injected_in_battle, effective])

	# 全ユニット+呪文からレアリティ付きプールを構築（レリックは除外）
	var pool: Array = []
	for name in CardDB.UNITS:
		var d = CardDB.UNITS[name]
		var rarity = d.get("rarity", "common")
		pool.append({"name": name, "data": d, "type": "unit", "rarity": rarity})
	for name in CardDB.SPELLS:
		var d = CardDB.SPELLS[name]
		var rarity = d.get("rarity", "common")
		pool.append({"name": name, "data": d, "type": "spell", "rarity": rarity})

	# レリック効果: reward_choices
	var choice_count = 3  # 基本選択肢数

	# エリート混入時: 選択肢+1
	if GameSession.elite_injected_in_battle:
		choice_count += 1
		print("[Result] エリート混入戦: 報酬選択肢+1 → %d枚" % choice_count)

	for relic_id in GameSession.relics:
		if not CardDB.RELICS.has(relic_id):
			continue
		var relic = CardDB.RELICS[relic_id]
		var effect = relic.get("effect", {})
		if effect.get("type", "") == "reward_choices":
			choice_count += effect.get("value", 0)
	if choice_count > 3:
		print("[Result] レリック reward_choices: 選択肢 %d 枚" % choice_count)

	# 重み付きランダム選択
	_card_choices = []
	var used_names: Array = []
	for _i in range(choice_count):
		var card = _weighted_pick(pool, weights, used_names)
		if card.size() > 0:
			_card_choices.append(card)
			used_names.append(card["name"])

func _weighted_pick(pool: Array, weights: Dictionary, exclude: Array) -> Dictionary:
	# 重み付きプールを構築
	var weighted: Array = []
	for card in pool:
		if card["name"] in exclude:
			continue
		var w = weights.get(card["rarity"], 0)
		if w > 0:
			for _j in range(w):
				weighted.append(card)
	if weighted.size() == 0:
		return {}
	return weighted[randi() % weighted.size()]

func _generate_boss_relic_choices() -> void:
	# ボス戦: レリック確定3択
	var relic_pool: Array = []
	for relic_id in CardDB.RELICS:
		var relic = CardDB.RELICS[relic_id]
		relic_pool.append({"name": relic_id, "data": relic, "type": "relic", "rarity": relic.get("rarity", "common")})

	# レアリティ重み（ボス報酬は高レアリティ優遇）
	var boss_weights = {
		"common": 2,
		"uncommon": 5,
		"rare": 3,
		"boss": 0,  # ボスレリックはボス報酬からは出ない
		"event": 0  # イベントレリックも出ない
	}

	_card_choices = []
	var used_names: Array = []
	for _i in range(3):
		var relic = _weighted_pick(relic_pool, boss_weights, used_names)
		if relic.size() > 0:
			_card_choices.append(relic)
			used_names.append(relic["name"])

	print("[Result] ボス報酬: レリック3択生成完了")

func _build_ui() -> void:
	UIF.add_bg(self)

	# 共通タスクバー（最上部36px）
	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.RESULT)

	var result = GameSession.last_result
	var is_win = result.get("win", false)
	var battle_gold_drop: int = result.get("battle_gold", 0)

	# 勝敗表示
	var result_label = Label.new()
	result_label.text = "VICTORY" if is_win else "DEFEAT"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.position = Vector2(0, 20)
	result_label.size = Vector2(1280, 50)
	result_label.add_theme_font_size_override("font_size", 42)
	result_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3) if is_win else Color(0.8, 0.2, 0.2))
	add_child(result_label)

	# 報酬パネル（勝利時）
	if is_win:
		_build_reward_panel(battle_gold_drop)

	# カード3択（勝利時のみ）
	if is_win and _card_choices.size() > 0:
		var pick_label = Label.new()
		pick_label.text = "── カードを1枚選べ ──"
		pick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pick_label.position = Vector2(0, 210)
		pick_label.size = Vector2(1280, 25)
		pick_label.add_theme_font_size_override("font_size", 16)
		pick_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
		add_child(pick_label)

		# BOOSTEDアイコン（エリート混入時）
		_add_boost_icon()

		var card_container = HBoxContainer.new()
		card_container.position = Vector2(80, 245)
		card_container.size = Vector2(1120, 400)
		card_container.add_theme_constant_override("separation", 20)
		add_child(card_container)

		for i in range(_card_choices.size()):
			var card = _card_choices[i]
			var panel = _create_card_panel(i, card)
			card_container.add_child(panel)

		# スキップボタン
		var skip_btn = Button.new()
		skip_btn.text = "スキップ（カードを取らない）"
		skip_btn.position = Vector2(440, 670)
		skip_btn.size = Vector2(400, 38)
		skip_btn.add_theme_font_size_override("font_size", 14)
		skip_btn.pressed.connect(func(): _on_continue())
		add_child(skip_btn)
	else:
		# 敗北時 or カード選択なし
		_build_defeat_ui(is_win)

func _build_reward_panel(battle_gold_drop: int) -> void:
	# 報酬パネル背景
	var panel_bg = PanelContainer.new()
	panel_bg.position = Vector2(390, 75)
	panel_bg.size = Vector2(500, 120)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.14, 0.92)
	panel_style.set_corner_radius_all(10)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.5, 0.45, 0.2)
	panel_bg.add_theme_stylebox_override("panel", panel_style)
	add_child(panel_bg)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# タイトル行
	var title_lbl = Label.new()
	title_lbl.text = "── 報酬 ──"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5))
	vbox.add_child(title_lbl)

	# ドロップ通貨（バトル中撃破）
	if battle_gold_drop > 0:
		var drop_lbl = Label.new()
		drop_lbl.text = "撃破ドロップ:  %dG" % battle_gold_drop
		drop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		drop_lbl.add_theme_font_size_override("font_size", 13)
		drop_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
		vbox.add_child(drop_lbl)

	# 勝利ボーナス通貨
	var gold_lbl = Label.new()
	gold_lbl.text = "勝利ボーナス:  %dG" % _reward_gold
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 13)
	gold_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vbox.add_child(gold_lbl)

	# スキルポイント
	var sp_lbl = Label.new()
	sp_lbl.text = "スキルポイント:  +%d SP" % _reward_sp
	sp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sp_lbl.add_theme_font_size_override("font_size", 13)
	sp_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.95))
	vbox.add_child(sp_lbl)

	# 素材
	var mat_name: String = _reward_material.get("display", "なし")
	var mat_lbl = Label.new()
	mat_lbl.text = "素材:  %s" % mat_name
	mat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mat_lbl.add_theme_font_size_override("font_size", 13)
	mat_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	vbox.add_child(mat_lbl)

	# ドロップアイテム（Phase 3実装予定枠）
	var drop_items_lbl = Label.new()
	drop_items_lbl.text = "アイテムドロップ:  （Phase 3で実装予定）"
	drop_items_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_items_lbl.add_theme_font_size_override("font_size", 10)
	drop_items_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	vbox.add_child(drop_items_lbl)

	panel_bg.add_child(vbox)

func _create_card_panel(idx: int, card: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(355, 400)

	var rarity = card.get("rarity", "common")
	var rarity_color = RARITY_COLORS.get(rarity, Color(0.7, 0.7, 0.7))

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = rarity_color
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# レアリティ
	var rarity_label = Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	vbox.add_child(rarity_label)

	# カード名
	var name_label = Label.new()
	name_label.text = card["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(name_label)

	# ステータス
	var data = card["data"]
	var card_type = card.get("type", "unit")

	if card_type == "unit":
		var stats = "マナ:%d  HP:%d  ATK:%d  SPD:%.1fs" % [
			data.get("cost", 0), data.get("hp", 0), data.get("atk", 0), data.get("interval", 0)]
		var stats_label = Label.new()
		stats_label.text = stats
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.add_theme_font_size_override("font_size", 12)
		stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		vbox.add_child(stats_label)

		var race_label = Label.new()
		race_label.text = "種族: %s" % data.get("race", "")
		race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		race_label.add_theme_font_size_override("font_size", 12)
		race_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
		vbox.add_child(race_label)
	elif card_type == "spell":
		var cost_label = Label.new()
		cost_label.text = "マナ:%d  [呪文]" % data.get("cost", 0)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 12)
		cost_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
		vbox.add_child(cost_label)

		var effect_label = Label.new()
		effect_label.text = data.get("effect", "")
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		effect_label.add_theme_font_size_override("font_size", 11)
		effect_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(effect_label)
	elif card_type == "relic":
		var type_label = Label.new()
		type_label.text = "[レリック]"
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_size_override("font_size", 14)
		type_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.8))
		vbox.add_child(type_label)

		var desc_label = Label.new()
		desc_label.text = data.get("description", "")
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size = Vector2(340, 0)
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		vbox.add_child(desc_label)

	# スキル表示
	var _edb = load("res://scripts/EffectDB.gd")
	var skills = data.get("skills", [])
	if skills.size() > 0:
		var skill_header = Label.new()
		skill_header.text = "── スキル ──"
		skill_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_header.add_theme_font_size_override("font_size", 10)
		skill_header.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vbox.add_child(skill_header)

		var shown = 0
		for skill in skills:
			if shown >= 3:
				break
			var eid = skill.get("effect_id", "")
			var edef = _edb.EFFECTS.get(eid, {})
			var sl = Label.new()
			sl.text = "[%s] %s" % [skill.get("trigger", ""), edef.get("display", eid)]
			sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sl.add_theme_font_size_override("font_size", 10)
			sl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.6))
			vbox.add_child(sl)
			shown += 1

	# 選択ボタン
	var select_btn = Button.new()
	select_btn.text = "選択"
	select_btn.add_theme_font_size_override("font_size", 16)
	var card_idx = idx
	select_btn.pressed.connect(func(): _on_card_selected(card_idx))
	vbox.add_child(select_btn)

	panel.add_child(vbox)
	return panel

func _on_card_selected(idx: int) -> void:
	if _card_selected:
		return
	_card_selected = true

	var card = _card_choices[idx]
	var card_name = card["name"]
	var data = card["data"]
	var card_type = card.get("type", "unit")

	if card_type == "relic":
		# レリックをGameSession.relicsに追加
		GameSession.relics.append(card_name)
		print("[Result] レリック獲得: %s" % card_name)
	else:
		# カード（ユニット・呪文）をデッキに追加
		var col = data.get("col", 1) if card_type == "unit" else -1
		GameSession.selected_deck.append({"name": card_name, "col": col})

		# placement_config生成（ユニットのみ）
		if card_type == "unit":
			var PL = load("res://scripts/PlacementLogic.gd")
			var new_config = PL.generate_default_config([{"name": card_name, "col": col}])
			if new_config.size() > 0:
				GameSession.placement_config.append(new_config[0])

		print("[Result] カード選択: %s" % card_name)

	_on_continue()

func _on_continue() -> void:
	# run_depth加算（勝利時は必ずここで加算、カード選択スキップでも加算）
	if GameSession.last_result.get("win", false):
		GameSession.run_depth += 1
		print("[Result] run_depth: %d" % GameSession.run_depth)
	var next_scene = SceneManager.BOSS_REWARD if GameSession.battle_type == "boss" else SceneManager.MAP_SELECT
	SceneManager.go_to(next_scene)

func _build_defeat_ui(is_win: bool) -> void:
	if is_win:
		# 勝利だがカード選択がない場合
		var continue_btn = Button.new()
		continue_btn.text = "続ける"
		continue_btn.position = Vector2(515, 400)
		continue_btn.size = Vector2(250, 55)
		continue_btn.add_theme_font_size_override("font_size", 22)
		continue_btn.pressed.connect(func(): _on_continue())
		add_child(continue_btn)

	if not is_win:
		# 敗北時: もう一度挑戦ボタン
		var retry_btn = Button.new()
		retry_btn.text = "もう一度挑戦"
		retry_btn.position = Vector2(515, 490)
		retry_btn.size = Vector2(250, 55)
		retry_btn.add_theme_font_size_override("font_size", 22)
		retry_btn.pressed.connect(func(): SceneManager.go_to(SceneManager.BATTLE))
		add_child(retry_btn)

	# タイトルへボタン
	var title_btn = Button.new()
	title_btn.text = "タイトルへ"
	title_btn.position = Vector2(515, 560)
	title_btn.size = Vector2(250, 45)
	title_btn.add_theme_font_size_override("font_size", 18)
	title_btn.pressed.connect(func():
		GameSession.reset()
		SceneManager.go_to(SceneManager.TITLE)
	)
	add_child(title_btn)

func _add_boost_icon() -> void:
	# ブースト条件に合致しない場合は何もしない
	if not RewardTableClass.is_boosted(GameSession.run_depth, GameSession.elite_injected_in_battle):
		return

	var boost_icon = Label.new()
	boost_icon.text = "★ BOOSTED"
	boost_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	boost_icon.position = Vector2(820, 210)
	boost_icon.size = Vector2(200, 25)
	boost_icon.add_theme_font_size_override("font_size", 14)
	boost_icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(boost_icon)
