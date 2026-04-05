# EnemyAI.gd
class_name EnemyAI
extends Node

var mana: float = 3.0
const MANA_MAX: float = 10.0
const MANA_REGEN: float = 1.0
var check_interval: float = 1.0
var _check_timer: float = 0.0

var enemy_deck: Array = []
var enemy_discard: Array = []
var deck: Array:  # SpellExecutor互換エイリアス
	get: return enemy_deck
	set(v): enemy_deck = v
var next_card: Object = null  # 次に召喚するカード（表示用に事前決定）
var spell_executor: RefCounted = null  # SpellExecutor（Main.gd が設定）
var deck_manager_ref: Node = null      # DeckManager参照（Main.gd が設定）

func _ready() -> void:
	_build_enemy_deck()
	_pick_next_card()

func _build_enemy_deck() -> void:
	# プレイヤーと同じカードセット（バランス調整）
	var card_pool: Dictionary = {
		# ── スライム系 ──
		"スライム": {
			"hp": 15, "atk": 1, "interval": 4.0, "cost": 1, "race": "スライム", "range": "1行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "on_summon", "effect_id": "summon_same_row", "params": {"unit_id": "スライム", "chain": false}},
			],
		},
		"マッドスライム": {
			"hp": 40, "atk": 2, "interval": 3.8, "cost": 3, "race": "スライム", "range": "1行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "always", "effect_id": "armor_apply", "params": {"target": "self", "stacks": 1}},
			],
		},
		"ブラッドスライム": {
			"hp": 25, "atk": 2, "interval": 3.8, "cost": 4, "race": "スライム", "range": "1行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "on_summon", "effect_id": "lifesteal_apply", "params": {"target": "random_front_ally", "stacks": 5}},
				{"trigger": "on_summon", "effect_id": "deck_add_self", "params": {}},
			],
		},
		# ── アンデッド系 ──
		"スケルトン": {
			"hp": 20, "atk": 2, "interval": 3.0, "cost": 2, "race": "アンデッド", "range": "1行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "always", "effect_id": "enemy_mana_drain", "params": {}},
				{"trigger": "on_death", "effect_id": "self_revive", "params": {"hp": 5, "delay": 3.0}},
			],
		},
		"グール": {
			"hp": 25, "atk": 5, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "1行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "always", "effect_id": "debuff_spread", "params": {}},
				{"trigger": "on_hit", "effect_id": "lifesteal_apply", "params": {"stacks": 8}},
				{"trigger": "on_kill", "effect_id": "atk_accumulate", "params": {"amount": 2, "cap": 10}},
			],
		},
		"バンシー": {
			"hp": 10, "atk": 1, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "上下含む3行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "always", "effect_id": "support_fire", "params": {"atk_factor": 0.3}},
				{"trigger": "always", "effect_id": "spd_buff_apply", "params": {"target": "same_col_ally"}},
				{"trigger": "on_hit", "effect_id": "burn_apply", "params": {"stacks": 2}},
				{"trigger": "timer", "effect_id": "all_enemy_debuff", "params": {"interval": 15.0, "status": "burn", "stacks": 2}},
				{"trigger": "on_kill", "effect_id": "freeze_apply", "params": {"target": "all_enemies", "stacks": 4}},
			],
		},
		"リッチ": {
			"hp": 15, "atk": 2, "interval": 3.0, "cost": 3, "race": "アンデッド", "range": "上下含む3行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "always", "effect_id": "snipe", "params": {}},
				{"trigger": "always", "effect_id": "support_revive", "params": {"target": "same_row"}},
				{"trigger": "on_hit", "effect_id": "freeze_apply", "params": {"stacks": 3}},
				{"trigger": "timer", "effect_id": "poison_apply", "params": {"interval": 20.0, "target": "all_enemies", "stacks": 3}},
				{"trigger": "on_kill", "effect_id": "revive_undead", "params": {}},
			],
		},
		"ヴリコラカス": {
			"hp": 30, "atk": 6, "interval": 2.0, "cost": 3, "race": "アンデッド", "range": "1行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "always", "effect_id": "debuff_spread", "params": {}},
				{"trigger": "on_hit", "effect_id": "steal_buffs", "params": {}},
				{"trigger": "timer", "effect_id": "steal_all_buffs", "params": {"interval": 20.0}},
			],
		},
		# ── 獣系 ──
		"ゴブリン": {
			"hp": 15, "atk": 3, "interval": 1.0, "cost": 1, "race": "獣", "range": "1行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "always", "effect_id": "atk_buff_apply", "params": {"target": "adjacent_beast"}},
				{"trigger": "on_summon", "effect_id": "draw_cards", "params": {"count": 2}},
			],
		},
		"ウルフ": {
			"hp": 20, "atk": 5, "interval": 1.5, "cost": 2, "race": "獣", "range": "1行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "always", "effect_id": "spd_buff_apply", "params": {"target": "same_row_beast"}},
				{"trigger": "timer", "effect_id": "atk_buff_apply", "params": {"interval": 10.0, "target": "same_row_beast", "stacks": 3, "duration": 5.0}},
			],
		},
		"タイガー": {
			"hp": 25, "atk": 8, "interval": 2.0, "cost": 3, "race": "獣", "range": "下含む2行",
			"support": "", "active": "",
			"skills": [
				{"trigger": "always", "effect_id": "atk_buff_apply", "params": {"target": "adjacent_beast"}},
				{"trigger": "on_hit", "effect_id": "critical", "params": {"first_only": true, "factor": 2.0}},
				{"trigger": "on_summon", "effect_id": "force_front", "params": {}},
				{"trigger": "timer", "effect_id": "big_damage", "params": {"interval": 20.0}},
			],
		},
	}

	# 敵デッキ構成（プレイヤーと同じ9枚・前列3/中列3/後列3）
	var deck_list: Array = [
		{"name": "スライム",         "col": 1},  # 中列 / スライム
		{"name": "スケルトン",       "col": 0},  # 前列 / アンデッド
		{"name": "ゴブリン",         "col": 0},  # 前列 / 獣
		{"name": "マッドスライム",   "col": 1},  # 中列 / スライム
		{"name": "グール",           "col": 1},  # 中列 / アンデッド
		{"name": "ウルフ",           "col": 1},  # 中列 / 獣
		{"name": "ブラッドスライム", "col": 2},  # 後列 / スライム
		{"name": "バンシー",         "col": 2},  # 後列 / アンデッド
		{"name": "タイガー",         "col": 2},  # 後列 / 獣
		{"name": "リッチ",           "col": 2},  # 後列 / アンデッド
		{"name": "ヴリコラカス",     "col": 1},  # 中列 / アンデッド
	]

	var UnitDataScript = load("res://scripts/UnitData.gd")
	for entry in deck_list:
		var d: Dictionary = card_pool[entry["name"]]
		var u = UnitDataScript.new()
		u.unit_name = entry["name"]
		u.max_hp = d["hp"]
		u.current_hp = d["hp"]
		u.attack = d["atk"]
		u.attack_interval = d["interval"]
		u.cost = d["cost"]
		u.assigned_col = entry["col"]
		u.race = d["race"]
		u.attack_range = d["range"]
		u.support_effect = d.get("support", "")
		u.active_skill = d.get("active", "")
		u.skills = d.get("skills", []).duplicate(true)
		enemy_deck.append(u)
	enemy_deck.shuffle()

func _pick_next_card() -> void:
	# 山札が空なら捨て札をシャッフルして山札に戻す
	if enemy_deck.is_empty():
		if enemy_discard.is_empty():
			next_card = null
			return
		enemy_deck = enemy_discard.duplicate()
		enemy_discard.clear()
		enemy_deck.shuffle()
	next_card = enemy_deck[0]  # 山札先頭を次の召喚カードとして確定

func force_play_card(board: Node) -> void:
	if enemy_deck.is_empty():
		if enemy_discard.is_empty():
			return
		enemy_deck = enemy_discard.duplicate()
		enemy_discard.clear()
		enemy_deck.shuffle()
	var top = enemy_deck[0]
	enemy_deck.remove_at(0)
	if top.card_type == "unit":
		board.place_unit(1, top)
		enemy_discard.append(top)
	elif top.card_type == "spell" and spell_executor != null:
		var to_discard: bool = spell_executor.execute(top, 1, board, deck_manager_ref, self)
		if to_discard:
			enemy_discard.append(top)
	elif top.card_type == "status_spell" and spell_executor != null:
		spell_executor.execute(top, 1, board, deck_manager_ref, self)
	_pick_next_card()

func get_next_card() -> Object:
	return next_card

func process_ai(delta: float, board: Node) -> void:
	# プレイヤースケルトンによるマナ回復妨害（1体につき-0.1/s）
	var player_skeletons: int = board.count_units_by_name(0, "スケルトン")
	var effective_regen: float = max(0.1, MANA_REGEN - player_skeletons * 0.1)
	mana = min(MANA_MAX, mana + effective_regen * delta)

	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = check_interval

	if next_card == null:
		return
	if mana < next_card.cost:
		return  # マナが足りるまで先頭で待機

	mana -= next_card.cost
	enemy_deck.remove_at(0)
	if next_card.card_type == "unit":
		board.place_unit(1, next_card)
		enemy_discard.append(next_card)
	elif next_card.card_type in ["spell", "status_spell"] and spell_executor != null:
		if _try_spell_synthesis(1, next_card, board):
			if not next_card.is_consumable:
				enemy_discard.append(next_card)
		else:
			if next_card.card_type == "status_spell":
				spell_executor.execute(next_card, 1, board, deck_manager_ref, self)
			else:
				var to_discard: bool = spell_executor.execute(next_card, 1, board, deck_manager_ref, self)
				if to_discard:
					enemy_discard.append(next_card)
	_pick_next_card()

func _try_spell_synthesis(side: int, spell: Object, board_mgr: Node) -> bool:
	var card_name: String = spell.spell_id if spell.spell_id != "" else spell.unit_name
	for entry in board_mgr.synthesis_registry:
		if entry["card"] != card_name:
			continue
		var candidates: Array = []
		for r in range(3):
			for c in range(3):
				var u = board_mgr.board[side][r][c]
				if u != null and u.unit_name == entry["base"]:
					candidates.append({"row": r, "col": c})
		if not candidates.is_empty():
			candidates.shuffle()
			var pick = candidates[0]
			board_mgr._execute_synthesis(side, pick["row"], pick["col"],
				board_mgr.board[side][pick["row"]][pick["col"]], entry["result"])
			return true
	return false
