# DeckManager.gd
class_name DeckManager
extends Node

var mana: float = 0.0
# v2設計: マナ生成は攻撃/スキル発動時にトリガー。上限なし（MANA_MAX廃止）

var deck: Array = []
var discard: Array = []
var spell_executor: RefCounted = null  # SpellExecutor（Main.gd が設定）
var enemy_ai_ref: Node = null          # EnemyAI参照（Main.gd が設定）
var _cost_reduction_remaining: int = 0 # 連鎖の触媒：残りコスト軽減枚数
var auto_play_enabled: bool = false    # 自動発動フラグ（廃止済み・常にfalse）

# 発動チェック間隔（初期値1秒。将来ユニット効果で変更可能）
var check_interval: float = 1.0
var _check_timer: float = 0.0

var _EDB = null
var _UnitDataScript = null

signal card_played(unit: Object)
signal mana_changed(current: float)

func _ready() -> void:
	_EDB = load("res://scripts/EffectDB.gd")
	_UnitDataScript = load("res://scripts/UnitData.gd")
	_build_default_deck()

func _get_placement_config(card: Object) -> Dictionary:
	var idx = card._deck_index if card._deck_index >= 0 else -1
	if idx >= 0 and idx < GameSession.placement_config.size():
		return GameSession.placement_config[idx]
	return {}

func _build_default_deck() -> void:
	# v2設計: デッキには呪文のみ（ユニットはGameSession.initial_unitsから配置）
	var session_deck = GameSession.selected_deck if GameSession.selected_deck.size() > 0 else []
	if session_deck.size() > 0:
		for i in range(session_deck.size()):
			var entry = session_deck[i]
			var card_name = entry.get("name", "") if entry is Dictionary else str(entry)
			# ユニットはスキップ（初期配置から配置する）
			if CardDB.UNITS.has(card_name):
				continue
			elif CardDB.SPELLS.has(card_name):
				var d: Dictionary = CardDB.SPELLS[card_name]
				var u = _UnitDataScript.new()
				u.unit_name = card_name; u.card_type = "spell"
				u.spell_id = card_name; u.mana = d["mana"]
				u.spell_target = d["target"]; u.spell_effect = d["effect"]
				u.skills = d.get("skills", []).duplicate(true)
				u._deck_index = i
				deck.append(u)
			elif CardDB.STATUS_SPELLS.has(card_name):
				var d: Dictionary = CardDB.STATUS_SPELLS[card_name]
				var u = _UnitDataScript.new()
				u.unit_name = card_name; u.card_type = "status_spell"
				u.spell_id = card_name; u.mana = d["mana"]
				u.is_consumable = d.get("is_consumable", false)
				u.persistence = d.get("persistence", "permanent")
				u.spell_target = d.get("target", ""); u.spell_effect = d.get("effect", "")
				u.skills = d.get("skills", []).duplicate(true)
				u._deck_index = i
				deck.append(u)
		deck.shuffle()
		return
	# v2設計: フォールバックも呪文のみ（ユニットはinitial_unitsから配置）
	for spell_name in CardDB.PLAYER_SPELLS:
		var d: Dictionary = CardDB.SPELLS[spell_name]
		var u = _UnitDataScript.new()
		u.unit_name = spell_name; u.card_type = "spell"
		u.spell_id = spell_name; u.mana = d["mana"]
		u.spell_target = d["target"]; u.spell_effect = d["effect"]
		u.skills = d.get("skills", []).duplicate(true)
		deck.append(u)
	deck.shuffle()

func ensure_shuffle_card() -> void:
	pass  # REQ-D: 呪文回収廃止

func process_deck(delta: float, board: Node) -> void:
	# v2設計: マナ生成は攻撃/スキル発動時にトリガー（BoardManagerで実行）
	emit_signal("mana_changed", mana)
	if not auto_play_enabled:
		return  # 自動発動無効（SpellSlotSystemの手動発動に移行済み）

	# クールダウン中は発動しない
	if _check_timer > 0.0:
		_check_timer -= delta
		return

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
	var effective_cost: int = top.mana
	if top.mana == -1:
		effective_cost = int(mana)  # コストXカード：マナ全額
		if effective_cost <= 0:
			return
	elif _cost_reduction_remaining > 0:
		effective_cost = max(0, top.mana - 1)
	# 錬金術師パッシブ: 異常状態カードコスト軽減
	if top.card_type == "status_spell" and board != null and board.player_data != null:
		for sk in board.player_data.skills:
			if sk.get("trigger", "") == "always":
				var edef = _EDB.EFFECTS.get(sk.get("effect_id", ""), {})
				if edef.get("type", "") == "cost_modifier" and edef.get("card_type", "") == top.card_type:
					var amount = sk.get("params", {}).get("amount", edef.get("amount", -1))
					effective_cost = max(0, effective_cost + amount)
					print("[DeckManager] 錬金術師コスト軽減: %s %d→%d" % [top.unit_name, top.mana, effective_cost])
	if mana < effective_cost:
		return
	mana -= effective_cost
	deck.remove_at(0)
	_check_timer = check_interval  # 発動後にクールダウン開始
	if _cost_reduction_remaining > 0 and top.mana != -1:
		_cost_reduction_remaining -= 1
	# カードタイプ別処理
	emit_signal("card_played", top)
	if top.card_type == "unit":
		var cfg = _get_placement_config(top)
		board.place_unit(0, top, cfg)
		discard.append(top)
	elif top.card_type in ["spell", "status_spell"]:
		# 呪文・異常状態カード → 盤面合成チェック
		if _try_spell_synthesis(0, top, board):
			if not top.is_consumable:
				discard.append(top)
		else:
			if top.mana == -1:
				top.mana = effective_cost
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
		var cfg = _get_placement_config(top)
		board.place_unit(0, top, cfg)
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

func initialize_mana_from_deck() -> void:
	# v2設計: マナ上限廃止。初期マナを0にリセット
	mana = 0.0
	print("[DeckManager] マナ初期化: 0（上限なし）")

func get_next_card() -> Object:
	if deck.is_empty():
		return null
	return deck[0]

func get_spell_card_by_name(spell_name: String) -> Object:
	# spell_nameからUnitDataオブジェクトを生成して返す
	if CardDB.SPELLS.has(spell_name):
		var d: Dictionary = CardDB.SPELLS[spell_name]
		var u = _UnitDataScript.new()
		u.unit_name = spell_name
		u.card_type = "spell"
		u.spell_id = spell_name
		u.mana = d.get("mana", 0)
		u.spell_target = d.get("target", "")
		u.spell_effect = d.get("effect", "")
		u.skills = d.get("skills", []).duplicate(true)
		return u
	elif CardDB.STATUS_SPELLS.has(spell_name):
		var d: Dictionary = CardDB.STATUS_SPELLS[spell_name]
		var u = _UnitDataScript.new()
		u.unit_name = spell_name
		u.card_type = "status_spell"
		u.spell_id = spell_name
		u.mana = d.get("mana", 0)
		u.is_consumable = d.get("is_consumable", false)
		u.spell_target = d.get("target", "")
		u.spell_effect = d.get("effect", "")
		u.skills = d.get("skills", []).duplicate(true)
		return u
	return null
