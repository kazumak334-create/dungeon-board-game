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
	var _CardDB = load("res://scripts/CardDB.gd")
	var UnitDataScript = load("res://scripts/UnitData.gd")
	for entry in _CardDB.ENEMY_DECK:
		var d: Dictionary = _CardDB.UNITS[entry["name"]]
		var u = UnitDataScript.new()
		u.unit_name = entry["name"]
		u.max_hp = d["hp"]; u.current_hp = d["hp"]
		u.attack = d["atk"]; u.attack_interval = d["interval"]
		u.cost = d["cost"]; u.assigned_col = entry["col"]
		u.race = d["race"]; u.attack_range = d["range"]
		u.support_effect = ""; u.active_skill = ""
		u.skills = d.get("skills", []).duplicate(true)
		enemy_deck.append(u)
	enemy_deck.shuffle()
	_insert_shuffle_card()

func _insert_shuffle_card() -> void:
	var _CDB = load("res://scripts/CardDB.gd")
	if not _CDB.SYSTEM_SPELLS.has("シャッフル"):
		return
	var sd = _CDB.SYSTEM_SPELLS["シャッフル"]
	var UnitDataScript = load("res://scripts/UnitData.gd")
	var card = UnitDataScript.new()
	card.unit_name = "シャッフル"
	card.card_type = "spell"
	card.spell_id = "シャッフル"
	card.cost = 0
	card.is_consumable = true
	card.spell_target = sd["target"]
	card.spell_effect = sd["effect"]
	card.skills = sd.get("skills", []).duplicate(true)
	enemy_deck.append(card)

func _pick_next_card() -> void:
	# 山札が空なら捨て札をシャッフルして山札に戻す
	if enemy_deck.is_empty():
		if enemy_discard.is_empty():
			next_card = null
			return
		enemy_deck = enemy_discard.duplicate()
		enemy_discard.clear()
		enemy_deck.shuffle()
		_insert_shuffle_card()
	next_card = enemy_deck[0]

func force_play_card(board: Node) -> void:
	if enemy_deck.is_empty():
		if enemy_discard.is_empty():
			return
		enemy_deck = enemy_discard.duplicate()
		enemy_discard.clear()
		enemy_deck.shuffle()
		_insert_shuffle_card()
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
