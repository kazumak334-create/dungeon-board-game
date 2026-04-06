# EnemyAI.gd
class_name EnemyAI
extends Node

var mana: float = 0.0
var MANA_MAX: float = 3.0    # マナ吸収で成長（constからvarに変更）
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
	for entry in CardDB.ENEMY_DECK:
		var d: Dictionary = CardDB.UNITS[entry["name"]]
		var u = _UnitDataScript.new()
		u.unit_name = entry["name"]
		u.max_hp = d["hp"]; u.current_hp = d["hp"]
		u.attack = d["atk"]; u.attack_interval = d["interval"]
		u.cost = d["cost"]; u.assigned_col = entry["col"]
		u.race = d["race"]; u.attack_range = d["range"]
		u.support_effect = ""; u.passive_skill = ""
		u.skills = d.get("skills", []).duplicate(true)
		enemy_deck.append(u)
	enemy_deck.shuffle()

func ensure_shuffle_card() -> void:
	for i in range(enemy_deck.size() - 1, -1, -1):
		if enemy_deck[i].unit_name == "マナ吸収":
			enemy_deck.remove_at(i)
	if not CardDB.SYSTEM_SPELLS.has("マナ吸収"):
		return
	var sd = CardDB.SYSTEM_SPELLS["マナ吸収"]
	var card = _UnitDataScript.new()
	card.unit_name = "マナ吸収"
	card.card_type = "spell"
	card.spell_id = "マナ吸収"
	card.cost = 0
	card.is_consumable = true
	card.spell_target = sd["target"]
	card.spell_effect = sd["effect"]
	card.skills = sd.get("skills", []).duplicate(true)
	enemy_deck.append(card)

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
	if next_card.cost > int(MANA_MAX) and next_card.cost != -1:
		enemy_deck.remove_at(0)
		enemy_discard.append(next_card)
		_check_timer = check_interval  # スキップにもクールダウン適用
		_pick_next_card()
		return
	if mana < next_card.cost:
		return  # マナが足りるまで先頭で待機

	mana -= next_card.cost
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
