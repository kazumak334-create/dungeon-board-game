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
	var _CardDB = load("res://scripts/CardDB.gd")
	var UnitDataScript = load("res://scripts/UnitData.gd")
	for entry in _CardDB.PLAYER_DECK:
		var d: Dictionary = _CardDB.UNITS[entry["name"]]
		var u = UnitDataScript.new()
		u.unit_name = entry["name"]
		u.max_hp = d["hp"]; u.current_hp = d["hp"]
		u.attack = d["atk"]; u.attack_interval = d["interval"]
		u.cost = d["cost"]; u.assigned_col = entry["col"]
		u.race = d["race"]; u.attack_range = d["range"]
		u.support_effect = ""; u.active_skill = ""
		u.skills = d.get("skills", []).duplicate(true)
		deck.append(u)
	for spell_name in _CardDB.PLAYER_SPELLS:
		var d: Dictionary = _CardDB.SPELLS[spell_name]
		var u = UnitDataScript.new()
		u.unit_name = spell_name; u.card_type = "spell"
		u.spell_id = spell_name; u.cost = d["cost"]
		u.spell_target = d["target"]; u.spell_effect = d["effect"]
		u.skills = d.get("skills", []).duplicate(true)
		deck.append(u)
	deck.shuffle()

# シャッフルカードをデッキ最下部に保証する（バトルルール）
func ensure_shuffle_card() -> void:
	# 既存のシャッフルカードを除去（位置リセット）
	for i in range(deck.size() - 1, -1, -1):
		if deck[i].unit_name == "シャッフル":
			deck.remove_at(i)
	# 最下部に新規追加
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
	deck.append(card)

func process_deck(delta: float, board: Node) -> void:
	# 敵ユニットのmana_drainスキル（always）によるマナ回復妨害
	var _EDB_regen = load("res://scripts/EffectDB.gd")
	var drain_count: int = 0
	for r in range(3):
		for c in range(3):
			var u = board.board[1][r][c]
			if u == null:
				continue
			for sk in u.skills:
				if sk.get("trigger", "") == "always":
					var _eid_drain: String = sk.get("effect_id", "")
					var _edef_drain: Dictionary = _EDB_regen.EFFECTS.get(_eid_drain, {})
					if _edef_drain.get("type", "") == "mana_drain":
						drain_count += 1
						break
	var per_unit: float = -0.1
	for eid_d in _EDB_regen.EFFECTS:
		if _EDB_regen.EFFECTS[eid_d].get("type", "") == "mana_drain":
			per_unit = _EDB_regen.EFFECTS[eid_d].get("per_unit", -0.1)
			break
	var effective_regen: float = max(0.1, MANA_REGEN + drain_count * per_unit)
	# 永久効果型アーティファクト: mana_regen_modify type のスキルを反映
	for art_entry in board.player_artifacts:
		if not (art_entry is Dictionary):
			continue
		for sk in art_entry.get("skills", []):
			var _eid_regen: String = sk.get("effect_id", "")
			var _edef_regen: Dictionary = _EDB_regen.EFFECTS.get(_eid_regen, {})
			if _edef_regen.get("type", "") == "mana_regen_modify":
				var pct: float = sk.get("params", {}).get("pct", _edef_regen.get("pct", 0.2))
				effective_regen *= (1.0 + pct)
	mana = min(MANA_MAX, mana + effective_regen * delta)
	emit_signal("mana_changed", mana)

	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = check_interval

	if deck.is_empty():
		# フォールバック：デッキが空になった場合
		if discard.is_empty():
			return
		for card in discard:
			deck.append(card)
		discard.clear()
		deck.shuffle()
		ensure_shuffle_card()
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
		return
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
