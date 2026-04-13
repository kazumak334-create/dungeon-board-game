# BoardManager.gd
class_name BoardManager
extends Node

var board: Array = []
var attack_timers: Array = []
var support_timers: Array = []  # v2設計: サポート効果発動タイマー（attack_intervalと同じ）
var board_effects: Array = []  # board_effects[side][row][col] = null or {effect_id, remaining, tick_timer, tick_interval}
var board_artifacts: Array = []  # board_artifacts[side][row][col] = null or {name, hp, max_hp, skills, protect_tiles, timers}
var player_artifacts: Array = []  # 永久効果型アーティファクト（プレイヤー側）
var enemy_artifacts: Array = []   # 永久効果型アーティファクト（敵側）
var event_queue: Node = null          # EventQueue（Main.gd が設定）
var base_hp_ref: Array = []           # Main.gd の base_hp への参照（Timer tick 用）
var effect_executor: RefCounted = null  # EffectExecutor（Main.gd が設定）
var deck_manager_ref: Node = null     # DeckManager（Main.gd が設定）
var enemy_ai_ref: Node = null         # EnemyAI（Main.gd が設定）
var player_data: RefCounted = null    # PlayerData（Main.gd が設定）
var _board_dirty: bool = true       # true のときのみサポート効果を再計算
var _status_timer: Timer = null
var _regen_tick: int = 0            # リジェネ用：2秒ごとにカウント
var _pending_revives: Array = []    # [{timer: float, side: int, row: int, unit: Object}]
var tile_system: RefCounted = null  # TileSystem（盤面効果処理）
var tick_system: RefCounted = null  # TickSystem（毎秒Tick処理）
var combat_system: RefCounted = null  # CombatSystem（攻撃ループ・ダメージ計算）
var support_system: RefCounted = null  # SupportSystem（サポート効果再計算）
var relic_revive_used: bool = false  # レリック revive_first の発動済みフラグ（バトルごとにリセット）

signal unit_placed(side: int, row: int, col: int, unit: Object)
signal unit_died(side: int, row: int, col: int, unit: Object)
signal unit_revived(side: int, row: int, col: int)
signal unit_damaged(side: int, row: int, col: int)
signal base_damaged(side: int, amount: int)
signal skill_triggered(side: int, row: int, col: int, skill_name: String)
signal status_damage(unit_name: String, status: String, damage: int, stacks: int)
signal status_applied(unit_name: String, status: String, stacks: int)
signal status_cleared(unit_name: String, status: String)
signal draw_cards_requested(side: int, count: int)
signal spell_cast(side: int, spell_name: String)
signal synthesis_done(side: int, row: int, col: int, base_name: String, result_name: String)

func _ready() -> void:
	_setup()

func _setup() -> void:
	board = []
	attack_timers = []
	support_timers = []
	board_effects = []
	board_artifacts = []
	for s in range(2):
		board.append([])
		attack_timers.append([])
		support_timers.append([])
		board_effects.append([])
		board_artifacts.append([])
		for r in range(3):
			board[s].append([null, null, null])
			attack_timers[s].append([0.0, 0.0, 0.0])
			support_timers[s].append([0.0, 0.0, 0.0])
			board_effects[s].append([null, null, null])
			board_artifacts[s].append([null, null, null])
	# 状態異常・HP回復を1秒ごとに処理するTimerノード
	_status_timer = Timer.new()
	_status_timer.wait_time  = 1.0
	_status_timer.autostart  = true
	_status_timer.timeout.connect(_on_status_tick)
	add_child(_status_timer)
	# TileSystem初期化
	var _TS = load("res://scripts/TileSystem.gd")
	tile_system = _TS.new()
	tile_system.setup(self)
	var _TkS = load("res://scripts/TickSystem.gd")
	tick_system = _TkS.new()
	tick_system.setup(self)
	# CombatSystem初期化
	var _CS = load("res://scripts/CombatSystem.gd")
	combat_system = _CS.new()
	combat_system.setup(self)
	# SupportSystem初期化
	var _SS = load("res://scripts/SupportSystem.gd")
	support_system = _SS.new()
	support_system.setup(self)

var synthesis_registry: Array = []  # [{base, card, result_name, result_data}] Main.gdで設定

func place_unit(side: int, unit_data: Object, config_entry: Dictionary = {}) -> bool:
	var row: int = -1
	var col: int = -1
	if config_entry.size() > 0:
		# PlacementLogicで空きマスを探す
		var PL = load("res://scripts/PlacementLogic.gd")
		var result = PL.resolve_placement(config_entry, board, board)
		if result[0] >= 0:
			row = result[0]
			col = result[1]
		else:
			# 空きマスなし → 合成候補を探す（優先列の全マス）
			var pref_col = config_entry.get("col", -1)
			var synthesis_found = _try_synthesis_in_area(side, pref_col, unit_data)
			if synthesis_found:
				return true
			print("[BoardManager] PlacementLogic: 配置・合成先なし")
			return false
	else:
		# 従来ロジック（後方互換：DevUI等）
		col = unit_data.assigned_col
		if side == 0:
			col = 2 - col
		var rows: Array = [0, 1, 2]
		rows.shuffle()
		row = rows[0]
	if board[side][row][col] == null:
		# アーティファクト排他チェック
		if board_artifacts[side][row][col] != null:
			print("[BoardManager] アーティファクトにより召喚不可: side=%d row=%d col=%d" % [side, row, col])
			return false
		# 穴チェック：召喚不可
		var _te_check = board_effects[side][row][col]
		if _te_check != null:
			var _EDB_check = load("res://scripts/EffectDB.gd")
			var _def_check = _EDB_check.EFFECTS.get(_te_check["effect_id"], {})
			if _def_check.get("block_summon", false):
				print("[BoardManager] 穴により召喚不可: side=%d row=%d col=%d" % [side, row, col])
				return false
		# 空きマス → 通常配置
		var placed = unit_data.clone()
		# 死霊術師パッシブ: アンデッドHP+10%
		if player_data != null and side == 0 and placed.race == "アンデッド":
			var _EDB_hp = load("res://scripts/EffectDB.gd")
			for sk in player_data.skills:
				if sk.get("trigger", "") == "always":
					var edef = _EDB_hp.EFFECTS.get(sk.get("effect_id", ""), {})
					if edef.get("type", "") == "hp_pct_buff":
						var race_filter = sk.get("params", {}).get("race", edef.get("race", ""))
						if race_filter == "" or placed.race == race_filter:
							var pct = sk.get("params", {}).get("pct", edef.get("pct", 0.1))
							var bonus = int(float(placed.max_hp) * pct)
							placed.max_hp += bonus
							placed.current_hp += bonus
							print("[BoardManager] 死霊術師HP補正: %s max_hp+%d" % [placed.unit_name, bonus])
		board[side][row][col] = placed
		attack_timers[side][row][col] = placed.get_attack_interval()
		support_timers[side][row][col] = placed.get_attack_interval()
		emit_signal("unit_placed", side, row, col, placed)
		on_board_changed()
		if col == 1 and event_queue != null:
			var front_col: int = 2 if side == 0 else 0
			event_queue.push(EventQueue.PRIORITY_BOARD, null, null, "promote_check", 0.0,
				{"side": side, "row": row, "col": front_col})
		_init_skill_timers(placed)
		_push_summon_effects(side, row, col, placed)
		# 盤面効果 on_enter チェック
		tile_system.check_tile_on_enter(side, row, col, placed)
		return true
	else:
		# マスが埋まっている → 盤面合成チェック
		var existing = board[side][row][col]
		var result = _check_synthesis(existing.unit_name, unit_data)
		if result != null:
			_execute_synthesis(side, row, col, existing, result)
			return true
	# 合成不成立 → 召喚失敗
	print("[BoardManager] 召喚失敗: side=%d row=%d col=%d" % [side, row, col])
	return false

func _try_synthesis_in_area(side: int, pref_col: int, unit_data: Object) -> bool:
	# 優先列→他列の順で合成可能なマスを探す
	var cols: Array
	if pref_col >= 0 and pref_col <= 2:
		cols = [pref_col]
		for c in range(3):
			if c != pref_col:
				cols.append(c)
	else:
		cols = [0, 1, 2]
	var rows = [0, 1, 2]
	rows.shuffle()
	for c in cols:
		for r in rows:
			var existing = board[side][r][c]
			if existing != null:
				var result = _check_synthesis(existing.unit_name, unit_data)
				if result != null:
					_execute_synthesis(side, r, c, existing, result)
					return true
	return false

func _check_synthesis(base_name: String, card: Object) -> Object:
	# 発動カード名を決定（ユニットならunit_name、呪文ならspell_id）
	var card_name: String = card.spell_id if card.card_type != "unit" else card.unit_name
	for entry in synthesis_registry:
		if entry["base"] == base_name and entry["card"] == card_name:
			return entry["result"]
	return null

func _execute_synthesis(side: int, row: int, col: int, existing: Object, result_data: Object) -> void:
	var synthesized = result_data.clone()
	# バフ継続
	synthesized._atk_bonus = existing._atk_bonus
	synthesized._interval_bonus = existing._interval_bonus
	synthesized._has_lifesteal = existing._has_lifesteal
	synthesized._has_penetrate = existing._has_penetrate
	synthesized._regen_stacks = existing._regen_stacks
	synthesized._temp_atk_bonus = existing._temp_atk_bonus
	synthesized._temp_atk_timer = existing._temp_atk_timer
	synthesized._temp_spd_bonus = existing._temp_spd_bonus
	synthesized._temp_spd_timer = existing._temp_spd_timer
	synthesized.lifesteal_stacks = existing.lifesteal_stacks
	synthesized._kill_atk_bonus = existing._kill_atk_bonus
	synthesized._stolen_atk = existing._stolen_atk
	synthesized._stolen_spd = existing._stolen_spd
	synthesized._stolen_lifesteal = existing._stolen_lifesteal
	synthesized._stolen_penetrate = existing._stolen_penetrate
	synthesized._stolen_regen = existing._stolen_regen
	synthesized._stolen_armor = existing._stolen_armor
	# デバフ10スタック解除
	synthesized.burn_turns = max(0, existing.burn_turns - 10)
	synthesized.frozen_turns = max(0, existing.frozen_turns - 10)
	synthesized.paralysis_turns = max(0, existing.paralysis_turns - 10)
	synthesized.poison_stacks = max(0, existing.poison_stacks - 10)
	# 攻撃タイマー継続
	synthesized.get_attack_interval() = result_data.get_attack_interval()
	var timer_ratio: float = attack_timers[side][row][col] / max(0.01, existing.get_attack_interval())
	attack_timers[side][row][col] = synthesized.get_attack_interval() * timer_ratio
	support_timers[side][row][col] = synthesized.get_attack_interval() * timer_ratio
	# 盤面に配置
	board[side][row][col] = synthesized
	_init_skill_timers(synthesized)
	emit_signal("unit_placed", side, row, col, synthesized)
	on_board_changed()
	_push_summon_effects(side, row, col, synthesized)
	synthesis_done.emit(side, row, col, existing.unit_name, synthesized.unit_name)
	print("[BoardManager] 盤面合成: %s → %s (side=%d row=%d col=%d)" % [existing.unit_name, synthesized.unit_name, side, row, col])

# ---- アーティファクト配置・除去 ----

func place_artifact(side: int, row: int, col: int, artifact_data: Dictionary) -> bool:
	# ユニットがいる場合は配置不可（排他）
	if board[side][row][col] != null:
		print("[BoardManager] ユニットありのためアーティファクト配置不可: side=%d row=%d col=%d" % [side, row, col])
		return false
	var art_name: String = artifact_data.get("name", "")
	var art_def: Dictionary = CardDB.ARTIFACTS.get(art_name, artifact_data)
	var hp: int = art_def.get("hp", 10)
	# タイマー初期化（skills配列のtimerエントリ）
	var timers: Dictionary = {}
	var skills: Array = art_def.get("skills", [])
	for i in range(skills.size()):
		var sk = skills[i]
		if sk.get("trigger", "") == "timer":
			var interval: float = sk.get("params", {}).get("interval", 0.0)
			if interval > 0.0:
				timers["timer_%d" % i] = interval
	board_artifacts[side][row][col] = {
		"name": art_name,
		"hp": hp,
		"max_hp": hp,
		"skills": skills.duplicate(true),
		"protect_tiles": art_def.get("protect_tiles", false),
		"timers": timers,
	}
	print("[BoardManager] アーティファクト配置: %s side=%d row=%d col=%d" % [art_name, side, row, col])
	# on_summonスキルを発火
	_push_artifact_summon_effects(side, row, col, board_artifacts[side][row][col])
	on_board_changed()
	return true

func remove_artifact(side: int, row: int, col: int) -> void:
	var art = board_artifacts[side][row][col]
	if art == null:
		return
	print("[BoardManager] アーティファクト破壊: %s side=%d row=%d col=%d" % [art.get("name", "?"), side, row, col])
	# on_deathスキルを発火
	if effect_executor != null:
		for skill in art.get("skills", []):
			if skill.get("trigger", "") == "on_death":
				var _mp: Dictionary = skill.get("params", {}).duplicate()
				if skill.has("target"): _mp["target"] = skill["target"]
				_execute_artifact_skill(side, row, col, art, skill["effect_id"], _mp)
	board_artifacts[side][row][col] = null
	on_board_changed()

func _push_artifact_summon_effects(side: int, row: int, col: int, art: Dictionary) -> void:
	if effect_executor == null:
		return
	for skill in art.get("skills", []):
		if skill.get("trigger", "") == "on_summon":
			var _mp: Dictionary = skill.get("params", {}).duplicate()
			if skill.has("target"): _mp["target"] = skill["target"]
			_execute_artifact_skill(side, row, col, art, skill["effect_id"], _mp)

func _execute_artifact_skill(side: int, row: int, col: int, art: Dictionary, effect_id: String, params: Dictionary) -> void:
	if effect_executor == null:
		return
	# アーティファクトはUnitDataを持たないため source=null で実行
	effect_executor.execute(effect_id, params, {
		"trigger": params.get("trigger", "artifact"),
		"side": side, "row": row, "col": col,
		"source": null, "target": null, "damage": 0,
		"artifact": art,
		"board_manager": self, "deck_manager": deck_manager_ref, "enemy_ai": enemy_ai_ref,
		"event_queue": event_queue
	})

func get_unit(side: int, row: int, col: int) -> Object:
	return board[side][row][col]

func remove_unit(side: int, row: int, col: int) -> void:
	var unit = board[side][row][col]
	if unit == null:
		return  # 既に削除済み（EventQueue の二重処理対策）
	# 撃破時スキル（on_death）処理
	if unit != null:
		for skill in unit.skills:
			if skill.get("trigger", "") == "on_death":
				if effect_executor != null:
					var _mp: Dictionary = skill.get("params", {}).duplicate()
					if skill.has("target"): _mp["target"] = skill["target"]
					effect_executor.execute(skill["effect_id"], _mp, {
						"trigger": "on_death", "side": side, "row": row, "col": col,
						"source": unit, "target": null, "damage": 0,
						"board_manager": self, "deck_manager": deck_manager_ref, "enemy_ai": enemy_ai_ref,
						"event_queue": event_queue
					})
	# レリック効果: revive_first（最初の死亡ユニット1体復活）
	if unit != null and not relic_revive_used and side == 0:  # プレイヤー側のみ
		for relic_id in GameSession.relics:
			if not CardDB.RELICS.has(relic_id):
				continue
			var relic = CardDB.RELICS[relic_id]
			var effect = relic.get("effect", {})
			if effect.get("type", "") == "revive_first":
				var hp_percent = effect.get("hp_percent", 50)
				var revive_hp = max(1, int(unit.max_hp * hp_percent / 100.0))
				unit.current_hp = revive_hp
				attack_timers[side][row][col] = unit.get_attack_interval()
				support_timers[side][row][col] = unit.get_attack_interval()
				relic_revive_used = true
				print("[BoardManager] レリック効果: %s → %s 復活 (HP %d/%d)" % [relic.get("display", ""), unit.unit_name, revive_hp, unit.max_hp])
				emit_signal("unit_revived", side, row, col)
				return

	# サポート効果由来の再起チェック（1回限り）
	if unit != null and unit._support_revive and not unit._support_revive_used:
		unit._support_revive_used = true
		unit.current_hp = 1
		attack_timers[side][row][col] = unit.get_attack_interval()
		support_timers[side][row][col] = unit.get_attack_interval()
		emit_signal("unit_revived", side, row, col)
		return
	# 盤面効果 on_leave チェック
	tile_system.check_tile_on_leave(side, row, col, unit)
	var died_unit = unit  # emit後もunitを参照できるよう保持
	board[side][row][col] = null
	attack_timers[side][row][col] = 0.0
	support_timers[side][row][col] = 0.0
	emit_signal("unit_died", side, row, col, died_unit)
	# 前列が空になったら promote_check を遅延キューに積む（イベント駆動・1フレームラグ）
	var front_col_ref: int = 2 if side == 0 else 0
	if col == front_col_ref and event_queue != null:
		event_queue.push(EventQueue.PRIORITY_BOARD, null, null, "promote_check", 0.0,
			{"side": side, "row": row, "col": col})
	on_board_changed()

func process_combat(delta: float, base_hp: Array) -> void:
	combat_system.process_combat(delta, base_hp)

func _push_summon_effects(side: int, row: int, col: int, unit: Object) -> void:
	support_system.push_summon_effects(side, row, col, unit)

func _try_promote(side: int, row: int, col: int) -> void:
	var front_col: int = 2 if side == 0 else 0
	# 前列が空になった場合のみ中列（col=1）を繰り上げ
	if col != front_col:
		return
	if board[side][row][front_col] != null:
		return  # 前列が既に埋まっている場合は何もしない
	var mid_unit = board[side][row][1]
	if mid_unit == null:
		return
	# 中列ユニットを前列に移動（HPそのまま・タイマーは新規設定）
	# 盤面効果: 移動元 on_leave
	tile_system.check_tile_on_leave(side, row, 1, mid_unit)
	board[side][row][front_col] = mid_unit
	attack_timers[side][row][front_col] = mid_unit.get_attack_interval()
	board[side][row][1] = null
	attack_timers[side][row][1] = 0.0
	# 盤面効果: 移動先 on_enter
	tile_system.check_tile_on_enter(side, row, front_col, mid_unit)
	on_board_changed()

func _get_frontmost_col(side: int, row: int) -> int:
	return combat_system.get_frontmost_col(side, row)

# ---- サポート効果システム ----

func _apply_support_effects() -> void:
	support_system.apply_support_effects()

func count_units_by_name(side: int, unit_name: String) -> int:
	var count: int = 0
	for r in range(3):
		for c in range(3):
			var u = board[side][r][c]
			if u != null and u.unit_name == unit_name:
				count += 1
	return count

func on_board_changed() -> void:
	if event_queue != null:
		# PRIORITY_SUPPORT：盤面変化後にサポート効果を再計算
		event_queue.push(EventQueue.PRIORITY_SUPPORT, null, null, "support_apply", 0.0)
	else:
		_board_dirty = true  # フォールバック（event_queue 未設定時）

func _on_status_tick() -> void:
	tick_system.on_tick()

func _init_skill_timers(unit: Object) -> void:
	tick_system.init_skill_timers(unit)

# ---- バフ奪取ヘルパー ----

func _steal_buffs(stealer: Object, victim: Object, multiplier: float) -> void:
	combat_system.steal_buffs(stealer, victim, multiplier)

# ---- 撃破時スキルシステム ----

func _process_on_kill(killer: Object) -> void:
	combat_system.process_on_kill(killer)

# ---- デバフ波及システム ----

func _process_debuff_spread(killer: Object, victim: Object, victim_side: int, victim_row: int, victim_col: int) -> void:
	combat_system.process_debuff_spread(killer, victim, victim_side, victim_row, victim_col)

# ---- HP閾値スキルシステム ----

func _fire_hp_threshold_skill(side: int, row: int, col: int, unit: Object, entry: String) -> void:
	# 後退（後列に自動退避）
	if "後退" in entry:
		var back_col: int = 0 if side == 0 else 2
		if col != back_col and board[side][row][back_col] == null:
			board[side][row][back_col] = unit
			attack_timers[side][row][back_col] = unit.get_attack_interval()
			support_timers[side][row][back_col] = unit.get_attack_interval()
			board[side][row][col] = null
			attack_timers[side][row][col] = 0.0
			support_timers[side][row][col] = 0.0
			on_board_changed()
			skill_triggered.emit(side, row, back_col, "後退")
	# 結晶化（完全無敵3s）
	elif "結晶化" in entry:
		unit._invincible_timer = 3.0
		skill_triggered.emit(side, row, col, "結晶化")
	# 前列強制突撃
	elif "前列強制突撃" in entry:
		var front_col: int = 2 if side == 0 else 0
		if col != front_col and board[side][row][front_col] == null:
			board[side][row][front_col] = unit
			attack_timers[side][row][front_col] = unit.get_attack_interval()
			support_timers[side][row][front_col] = unit.get_attack_interval()
			board[side][row][col] = null
			attack_timers[side][row][col] = 0.0
			support_timers[side][row][col] = 0.0
			on_board_changed()
			skill_triggered.emit(side, row, front_col, "前列強制突撃")
	# ATK/SPD2倍（10秒間）
	elif "2倍" in entry:
		unit._temp_atk_bonus = unit.attack  # ATK2倍 = 現ATK分を加算
		unit._temp_atk_timer = 10.0
		unit._temp_spd_bonus = unit.get_attack_interval() * 0.5  # 攻撃間隔半減
		unit._temp_spd_timer = 10.0
		skill_triggered.emit(side, row, col, "ATK/SPD2倍")

# ---- 盤面効果システム ----

# 外部IFを変えないための薄いラッパー（処理はTileSystemに委譲）
func _check_tile_on_enter(side: int, row: int, col: int, unit: Object) -> void:
	tile_system.check_tile_on_enter(side, row, col, unit)

func _check_tile_on_leave(side: int, row: int, col: int, unit: Object) -> void:
	tile_system.check_tile_on_leave(side, row, col, unit)

func set_tile_effect(side: int, row: int, col: int, effect_id: String, duration: float = -1.0) -> void:
	tile_system.set_tile_effect(side, row, col, effect_id, duration)

func clear_tile_effect(side: int, row: int, col: int) -> void:
	tile_system.clear_tile_effect(side, row, col)

func _summon_unit_to_random_empty(side: int, unit_id: String) -> void:
	# 指定サイドのランダムな空きマスにユニットを召喚
	if not CardDB.UNITS.has(unit_id):
		return
	var ud = CardDB.UNITS[unit_id]
	var empty_cells: Array = []
	for r2 in range(3):
		for c2 in range(3):
			if board[side][r2][c2] == null and board_artifacts[side][r2][c2] == null:
				empty_cells.append([r2, c2])
	if empty_cells.is_empty():
		return
	empty_cells.shuffle()
	var pos: Array = empty_cells[0]
	var UDS = load("res://scripts/UnitData.gd")
	var new_unit = UDS.new()
	new_unit.unit_name = unit_id
	new_unit.max_hp = ud["hp"]; new_unit.current_hp = ud["hp"]
	new_unit.attack = ud["atk"]; new_unit.spd = ud.get("spd", 1.0)
	new_unit.mana = ud["mana"]; new_unit.race = ud.get("race", "")
	new_unit.attack_range = ud.get("range", "1行")
	new_unit.assigned_col = ud.get("col", 0)
	new_unit.skills = ud.get("skills", []).duplicate(true)
	board[side][pos[0]][pos[1]] = new_unit
	attack_timers[side][pos[0]][pos[1]] = new_unit.get_attack_interval()
	emit_signal("unit_placed", side, pos[0], pos[1], new_unit)
	on_board_changed()
	_init_skill_timers(new_unit)
	print("[BoardManager] 盤面効果召喚: %s → side=%d row=%d col=%d" % [unit_id, side, pos[0], pos[1]])
