# EnemyAI.gd
class_name EnemyAI
extends Node

var mana: float = 0.0
var MANA_MAX: float = 0.0    # v2設計: ユニット総コストで初期化
var MANA_REGEN: float = 1.0
var check_interval: float = 1.0
var _check_timer: float = 0.0

var enemy_deck: Array = []
var enemy_discard: Array = []
var deck: Array:  # SpellExecutor/EffectExecutor互換エイリアス
	get: return enemy_deck
	set(v): enemy_deck = v
var discard: Array:  # EffectExecutor互換エイリアス
	get: return enemy_discard
	set(v): enemy_discard = v
var next_card: Object = null  # 次に召喚するカード（表示用に事前決定）
var spell_executor: RefCounted = null  # SpellExecutor（Main.gd が設定）
var deck_manager_ref: Node = null      # DeckManager参照（Main.gd が設定）

var _EDB = null
var _UnitDataScript = null

func _ready() -> void:
	_EDB = load("res://scripts/EffectDB.gd")
	_UnitDataScript = load("res://scripts/UnitData.gd")
	_build_enemy_deck()
	_pick_next_card()

func _build_enemy_deck() -> void:
	# ボス戦の場合
	if GameSession.battle_type == "boss":
		_build_boss_deck()
		return

	# 通常戦・エリート戦: 警戒レベルに応じたプールキー決定
	var pool_key: String = _select_pool_key(GameSession.current_act, GameSession.alert_level)
	var pool: Array = CardDB.ENEMY_POOLS.get(pool_key, [])

	if pool.is_empty():
		print("[EnemyAI] WARNING: プールキー '%s' 未定義、ENEMY_DECKを使用" % pool_key)
		pool = CardDB.ENEMY_DECK

	for entry in pool:
		var d: Dictionary = CardDB.UNITS[entry["name"]]
		var u = _UnitDataScript.new()
		u.unit_name = entry["name"]
		u.max_hp = d["hp"]; u.current_hp = d["hp"]
		u.attack = d["atk"]; u.attack_interval = d["interval"]
		u.mana = d["mana"]; u.assigned_col = entry["col"]
		u.race = d["race"]; u.attack_range = d["range"]
		u.support_effect = ""; u.passive_skill = ""
		u.skills = d.get("skills", []).duplicate(true)
		enemy_deck.append(u)
	enemy_deck.shuffle()
	print("[EnemyAI] 敵デッキ構築: Act%d alert_lv=%d pool_key=%s %d枚" % [GameSession.current_act, GameSession.alert_level, pool_key, enemy_deck.size()])

func _select_pool_key(act: int, alert: int) -> String:
	# Act・警戒レベルに応じた敵プールキーを決定
	match act:
		1:
			if alert >= 5:
				return "act1_enhanced2"
			elif alert >= 3:
				return "act1_enhanced1"
			else:
				return "act1_weak"
		2:
			if alert >= 5:
				return "act2_enhanced2"
			elif alert >= 3:
				return "act2_enhanced1"
			else:
				return "act2_weak"
		3:
			if alert >= 3:
				return "act3_enhanced1"
			else:
				return "act3_weak"
		_:
			return "act1_weak"  # フォールバック

func _build_boss_deck() -> void:
	# ボス専用デッキ構築
	if GameSession.boss_id == "":
		print("[EnemyAI] ERROR: boss_idが未設定")
		return

	var boss = CardDB.BOSSES.get(GameSession.boss_id, {})
	if boss.is_empty():
		print("[EnemyAI] ERROR: ボスID未定義: %s" % GameSession.boss_id)
		return

	# フェーズと警戒レベルに応じたデッキIDを選択
	var deck_id: String = ""
	if GameSession.boss_phase == 2:
		# 第2戦: 警戒レベルに応じて強化版/超強化版
		if GameSession.alert_level >= 5:
			deck_id = boss.get("enemy_deck_id_phase2_lv5", "")
		elif GameSession.alert_level >= 4:
			deck_id = boss.get("enemy_deck_id_phase2_lv4", "")

	# デッキIDが空の場合は第1戦用デッキ
	if deck_id == "":
		deck_id = boss.get("enemy_deck_id", "")

	# deck_idから実際のデッキ構成を取得
	var pool: Array = CardDB.BOSS_DECKS.get(deck_id, [])
	if pool.is_empty():
		print("[EnemyAI] ERROR: デッキID '%s' が未定義、フォールバック" % deck_id)
		pool = CardDB.ENEMY_POOLS.get(str(GameSession.current_act), CardDB.ENEMY_DECK)

	print("[EnemyAI] ボスデッキ構築: %s (deck_id=%s, phase=%d, alert=%d)" % [boss.get("display", ""), deck_id, GameSession.boss_phase, GameSession.alert_level])

	# 警戒レベル別のバフ取得
	var buffs = boss.get("alert_level_buffs", {}).get(str(GameSession.alert_level), {"hp_bonus": 0, "atk_bonus": 0})
	var hp_bonus = buffs.get("hp_bonus", 0)
	var atk_bonus = buffs.get("atk_bonus", 0)

	for entry in pool:
		var d: Dictionary = CardDB.UNITS[entry["name"]]
		var u = _UnitDataScript.new()
		u.unit_name = entry["name"]
		u.max_hp = d["hp"] + hp_bonus
		u.current_hp = u.max_hp
		u.attack = d["atk"] + atk_bonus
		u.attack_interval = d["interval"]
		u.mana = d["mana"]; u.assigned_col = entry["col"]
		u.race = d["race"]; u.attack_range = d["range"]
		u.support_effect = ""; u.passive_skill = ""
		u.skills = d.get("skills", []).duplicate(true)
		enemy_deck.append(u)
	enemy_deck.shuffle()
	print("[EnemyAI] ボスデッキ構築完了: %d枚 (HP+%d, ATK+%d)" % [enemy_deck.size(), hp_bonus, atk_bonus])

func ensure_shuffle_card() -> void:
	for i in range(enemy_deck.size() - 1, -1, -1):
		if enemy_deck[i].unit_name == "呪文回収":
			enemy_deck.remove_at(i)
	if not CardDB.SYSTEM_SPELLS.has("呪文回収"):
		return
	var sd = CardDB.SYSTEM_SPELLS["呪文回収"]
	var card = _UnitDataScript.new()
	card.unit_name = "呪文回収"
	card.card_type = "spell"
	card.spell_id = "呪文回収"
	card.mana = 0
	card.is_consumable = true
	card.spell_target = sd["target"]
	card.spell_effect = sd["effect"]
	card.skills = sd.get("skills", []).duplicate(true)
	enemy_deck.append(card)

func initialize_mana_from_deck() -> void:
	# v2設計: 敵の初期配置ユニット総コストをMANA_MAXに設定
	# TODO: 敵側もinitial_unitsを使うように変更（現状は暫定でenemy_deckから）
	var total_cost: float = 0.0
	for card in enemy_deck:
		if card.card_type == "unit" and card.mana >= 0:
			total_cost += float(card.mana)
	MANA_MAX = total_cost
	mana = 0.0
	print("[EnemyAI] マナ上限初期化: %.1f（ユニット総コスト・暫定）" % MANA_MAX)

func _pick_next_card() -> void:
	if enemy_deck.is_empty():
		# フォールバック：シャッフルカード発動前にデッキが空になった場合
		if enemy_discard.is_empty():
			next_card = null
			return
		for card in enemy_discard:
			enemy_deck.append(card)
		enemy_discard.clear()
		enemy_deck.shuffle()
		ensure_shuffle_card()
	next_card = enemy_deck[0]

func force_play_card(board: Node) -> void:
	if enemy_deck.is_empty():
		return
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
	# プレイヤーユニットのmana_drainスキル（always）によるマナ回復妨害
	var drain_count_ai: int = 0
	for r in range(3):
		for c in range(3):
			var u = board.board[0][r][c]
			if u == null:
				continue
			for sk in u.skills:
				if sk.get("trigger", "") == "always":
					var _eid_d: String = sk.get("effect_id", "")
					var _edef_d: Dictionary = _EDB.EFFECTS.get(_eid_d, {})
					if _edef_d.get("type", "") == "mana_drain":
						drain_count_ai += 1
						break
	var per_unit_ai: float = -0.1
	for eid_da in _EDB.EFFECTS:
		if _EDB.EFFECTS[eid_da].get("type", "") == "mana_drain":
			per_unit_ai = _EDB.EFFECTS[eid_da].get("per_unit", -0.1)
			break
	var effective_regen: float = max(0.1, MANA_REGEN + drain_count_ai * per_unit_ai)
	mana = min(MANA_MAX, mana + effective_regen * delta)

	# クールダウン中は発動しない
	if _check_timer > 0.0:
		_check_timer -= delta
		return

	if next_card == null:
		return
	# マナ上限超過チェック：コスト > マナ上限 → スキップ（捨て札へ）
	# スキップも詠唱扱い（クールダウン消費）
	if next_card.mana > int(MANA_MAX) and next_card.mana != -1:
		enemy_deck.remove_at(0)
		enemy_discard.append(next_card)
		_check_timer = check_interval  # スキップにもクールダウン適用
		_pick_next_card()
		return
	if mana < next_card.mana:
		return  # マナが足りるまで先頭で待機

	mana -= next_card.mana
	enemy_deck.remove_at(0)
	_check_timer = check_interval  # 発動後にクールダウン開始
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
