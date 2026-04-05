# DeckManager.gd
class_name DeckManager
extends Node

var mana: float = 3.0
const MANA_MAX: float = 10.0
const MANA_REGEN: float = 1.0

var deck: Array = []
var discard: Array = []
var spell_executor: RefCounted = null  # SpellExecutor（Main.gd が設定）
var enemy_ai_ref: Node = null          # EnemyAI参照（Main.gd が設定）
var _cost_reduction_remaining: int = 0 # 連鎖の触媒：残りコスト軽減枚数

# 発動チェック間隔（初期値1秒。将来ユニット効果で変更可能）
var check_interval: float = 1.0
var _check_timer: float = 0.0

signal card_played(unit: Object)
signal mana_changed(current: float)

func _ready() -> void:
	_build_default_deck()

func _build_default_deck() -> void:
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

	# 呪文card_pool
	var spell_pool: Dictionary = {
		"召喚加速":   {"cost": 1, "target": "self",         "effect": "マナ即時+3回復",
			"skills": [{"trigger": "on_play", "effect_id": "mana_boost", "params": {"amount": 3}}]},
		"生命の雫":   {"cost": 2, "target": "single_ally",  "effect": "対象ユニットHP15%回復",
			"skills": [{"trigger": "on_play", "effect_id": "heal_pct", "params": {"target": "single_ally", "factor": 0.15}}]},
		"盤面強化":   {"cost": 3, "target": "all_allies",   "effect": "全味方HP+10・ATK+2",
			"skills": [{"trigger": "on_play", "effect_id": "all_stat_boost", "params": {"atk": 2, "hp": 10}}]},
	}

	# 初期デッキ構成（ユニット9枚 + 呪文3枚 = 12枚）
	var deck_list: Array = [
		{"name": "スライム",       "col": 1},  # 推奨列: 中
		{"name": "スケルトン",     "col": 0},
		{"name": "ゴブリン",       "col": 0},
		{"name": "マッドスライム", "col": 1},
		{"name": "グール",         "col": 1},
		{"name": "ウルフ",         "col": 1},
		{"name": "ブラッドスライム","col": 2},
		{"name": "バンシー",       "col": 2},
		{"name": "タイガー",       "col": 2},
		{"name": "リッチ",         "col": 2},  # 後列: 後列攻撃持ち
		{"name": "ヴリコラカス",   "col": 1},  # 中列: 前線バフ奪取
	]
	var spell_list: Array = ["召喚加速", "生命の雫", "盤面強化"]

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
		deck.append(u)
	for spell_name in spell_list:
		var d: Dictionary = spell_pool[spell_name]
		var u = UnitDataScript.new()
		u.unit_name = spell_name
		u.card_type = "spell"
		u.spell_id = spell_name
		u.cost = d["cost"]
		u.spell_target = d["target"]
		u.spell_effect = d["effect"]
		u.skills = d.get("skills", []).duplicate(true)
		deck.append(u)
	deck.shuffle()

func process_deck(delta: float, board: Node) -> void:
	# 敵スケルトンによるマナ回復妨害（1体につき-0.1/s）
	var enemy_skeletons: int = board.count_units_by_name(1, "スケルトン")
	var effective_regen: float = max(0.1, MANA_REGEN - enemy_skeletons * 0.1)
	mana = min(MANA_MAX, mana + effective_regen * delta)
	emit_signal("mana_changed", mana)

	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = check_interval

	if deck.is_empty():
		if discard.is_empty():
			return
		deck = discard.duplicate()
		discard.clear()
		deck.shuffle()
	var top = deck[0]
	# コスト計算（連鎖の触媒によるコスト軽減）
	var effective_cost: int = top.cost
	if top.cost == -1:
		effective_cost = int(mana)  # コストXカード：マナ全額
		if effective_cost <= 0:
			return
	elif _cost_reduction_remaining > 0:
		effective_cost = max(0, top.cost - 1)
	if mana < effective_cost:
		return
	mana -= effective_cost
	deck.remove_at(0)
	if _cost_reduction_remaining > 0 and top.cost != -1:
		_cost_reduction_remaining -= 1
	# カードタイプ別処理
	emit_signal("card_played", top)
	if top.card_type == "unit":
		board.place_unit(0, top)
		discard.append(top)
	elif top.card_type in ["spell", "status_spell"]:
		# 呪文・異常状態カード → 盤面合成チェック
		if _try_spell_synthesis(0, top, board):
			if not top.is_consumable:
				discard.append(top)
		else:
			if top.cost == -1:
				top.cost = effective_cost
			if top.card_type == "status_spell":
				spell_executor.execute(top, 0, board, self, enemy_ai_ref)
				# 消滅：捨て札に行かない
			else:
				var to_discard: bool = spell_executor.execute(top, 0, board, self, enemy_ai_ref)
				if to_discard:
					discard.append(top)

func _try_spell_synthesis(side: int, spell: Object, board: Node) -> bool:
	# 呪文カードで盤面合成が成立するかチェック
	var card_name: String = spell.spell_id if spell.spell_id != "" else spell.unit_name
	for entry in board.synthesis_registry:
		if entry["card"] != card_name:
			continue
		# 盤面上に合成元ユニットがいるか探す
		var candidates: Array = []
		for r in range(3):
			for c in range(3):
				var u = board.board[side][r][c]
				if u != null and u.unit_name == entry["base"]:
					candidates.append({"row": r, "col": c})
		if not candidates.is_empty():
			candidates.shuffle()
			var pick = candidates[0]
			board._execute_synthesis(side, pick["row"], pick["col"],
				board.board[side][pick["row"]][pick["col"]], entry["result"])
			return true
	return false

func force_play_card(board: Node) -> void:
	if deck.is_empty():
		if discard.is_empty():
			return
		deck = discard.duplicate()
		discard.clear()
		deck.shuffle()
	var top = deck[0]
	deck.remove_at(0)
	if top.card_type == "unit":
		board.place_unit(0, top)
		emit_signal("card_played", top)
		discard.append(top)
	elif top.card_type == "spell":
		emit_signal("card_played", top)
		var to_discard: bool = spell_executor.execute(top, 0, board, self, enemy_ai_ref)
		if to_discard:
			discard.append(top)
	elif top.card_type == "status_spell":
		emit_signal("card_played", top)
		spell_executor.execute(top, 0, board, self, enemy_ai_ref)

func get_next_card() -> Object:
	if deck.is_empty():
		return null
	return deck[0]
