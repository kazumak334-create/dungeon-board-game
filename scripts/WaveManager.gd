# WaveManager.gd
# Wave進行管理の中核（Phase 4 #0-0a）
class_name WaveManager
extends Node

# シグナル（Main.gdで接続予定）
signal wave_started(big_wave: int, small_wave: int, scale: float)
signal wave_ended(big_wave: int, small_wave: int, victory: bool)
signal intermission_requested(shop_config: Dictionary)
signal big_wave_completed(next_act: int)

# 定数
const SMALL_WAVES_PER_BIG_WAVE: int = 2
const BOSS_WAVE_PHASE1: int = 3  # BW4の小Wave3（ボスPhase1）
const BOSS_WAVE_PHASE2: int = 4  # BW4の小Wave4（ボスPhase2）
const TOTAL_WAVES_PER_BW: int = 2  # 通常BW：小Wave2個、ボスBW：小Wave2個+ボス2
const TOTAL_BIG_WAVES: int = 4
const SHOP_TRIGGER_WAVES: Array[int] = [2, 4, 6]

# Wave強化係数テーブル（小Wave1-6 + ボス2段階）
const WAVE_SCALING_TABLE: Array = [
	0.6, 0.8, 1.0, 1.3, 1.6, 2.0, 2.5, 3.0
]

# WaveState列挙型
enum WaveState {
	SMALL_WAVE,
	BOSS_PHASE1,
	BOSS_PHASE2
}

# 外部参照
var board_manager: Node = null
var enemy_ai: Node = null
var deck_manager: Node = null

# 内部状態
var _is_running: bool = false
var _current_big: int = 1
var _current_small: int = 1
var state: WaveState = WaveState.SMALL_WAVE

func _init() -> void:
	print("[WaveManager] 初期化完了")

func setup(bm: Node, dm: Node, eai: Node, main: Node) -> void:
	board_manager = bm
	deck_manager = dm
	enemy_ai = eai
	print("[WaveManager] setup完了")

func start_wave_mode(big_wave: int = 1, small_wave: int = 1) -> void:
	if _is_running:
		print("[WaveManager] WARNING: 既にWaveモード実行中")
		return
	_is_running = true
	_current_big = big_wave
	_current_small = small_wave
	GameSession.wave_current_big = big_wave
	GameSession.wave_current_small = small_wave
	print("[WaveManager] Waveモード開始: BW%d-SW%d" % [big_wave, small_wave])
	_start_wave(_current_big, _current_small)

func _start_wave(big: int, small: int) -> void:
	print("[WaveManager] Wave開始: BW%d-SW%d" % [big, small])
	# WaveState更新
	if small == BOSS_WAVE_PHASE1:
		state = WaveState.BOSS_PHASE1
	elif small == BOSS_WAVE_PHASE2:
		state = WaveState.BOSS_PHASE2
	else:
		state = WaveState.SMALL_WAVE
	if small > 1:
		_restore_board_from_snapshot()
	_build_enemy_for_wave(big, small)
	var scaling: float = _get_wave_scaling(small)
	_apply_scaling_to_enemies(scaling)
	if small > 1 and deck_manager != null:
		deck_manager.mana = GameSession.wave_mana_carryover
		print("[WaveManager] マナ持ち越し: %.1f" % GameSession.wave_mana_carryover)
	else:
		if deck_manager != null:
			deck_manager.mana = 0.0
	GameSession.wave_current_big = big
	GameSession.wave_current_small = small
	wave_started.emit(big, small, scaling)
	print("[WaveManager] Wave開始シグナル発行: BW%d-SW%d scale=%.1f" % [big, small, scaling])

func on_wave_clear() -> void:
	print("[WaveManager] Wave突破: BW%d-SW%d" % [_current_big, _current_small])
	_save_board_snapshot()
	if _current_small < BOSS_WAVE_PHASE2:
		if deck_manager != null:
			GameSession.wave_mana_carryover = deck_manager.mana
			print("[WaveManager] マナ保存: %.1f" % GameSession.wave_mana_carryover)
	else:
		GameSession.wave_mana_carryover = 0.0
	wave_ended.emit(_current_big, _current_small, true)
	_advance_to_next_wave()

func on_wave_victory() -> void:
	# Main.gd互換のためのエイリアス
	on_wave_clear()

func _build_shop_config() -> Dictionary:
	# MVP: 全ショップ共通（B案）
	return {
		"unit_count": 6,
		"spell_count": 3,
		"material_count": 3,
		"rarity_weights": {"common": 70, "uncommon": 20, "rare": 8, "epic": 2},
		"allow_duplicates": true
	}

func _advance_to_next_wave() -> void:
	if _current_small == BOSS_WAVE_PHASE2:
		# ボス第二形態突破 → BW完了
		if _current_big >= TOTAL_BIG_WAVES:
			print("[WaveManager] 全Wave突破")
			_is_running = false
			big_wave_completed.emit(4)
			return
		else:
			print("[WaveManager] BW%d突破 → 休憩画面へ" % _current_big)
			_current_big += 1
			_current_small = 1
			state = WaveState.SMALL_WAVE
			GameSession.wave_mana_carryover = 0.0
			GameSession.wave_board_snapshot = {}
			intermission_requested.emit(_build_shop_config())
			return

	# 通常Wave突破後のショップ判定
	if _current_small in SHOP_TRIGGER_WAVES:
		print("[WaveManager] SW%d突破 → ショップへ" % _current_small)
		_current_small += 1
		intermission_requested.emit(_build_shop_config())
		return

	_current_small += 1
	print("[WaveManager] 次Wave: BW%d-SW%d" % [_current_big, _current_small])
	_start_wave(_current_big, _current_small)

func resume_from_intermission() -> void:
	print("[WaveManager] 休憩完了 → 次BW開始: BW%d-SW%d" % [_current_big, _current_small])
	_start_wave(_current_big, _current_small)

func _get_wave_scaling(small: int) -> float:
	if small < 1 or small > WAVE_SCALING_TABLE.size():
		print("[WaveManager] WARNING: 範囲外のsmall_wave=%d" % small)
		return 1.0
	return WAVE_SCALING_TABLE[small - 1]

func _apply_scaling_to_enemies(scaling: float) -> void:
	if enemy_ai == null:
		print("[WaveManager] WARNING: enemy_ai未設定")
		return
	for unit in enemy_ai.enemy_deck:
		if unit != null:
			enemy_ai.apply_wave_scaling(unit, scaling)

func _build_enemy_for_wave(big: int, small: int) -> void:
	if enemy_ai == null:
		print("[WaveManager] WARNING: enemy_ai未設定")
		return
	if small == BOSS_WAVE_PHASE1 or small == BOSS_WAVE_PHASE2:
		GameSession.battle_type = "boss"
		print("[WaveManager] ボスWave構築: boss_id=%s (Phase %d)" % [GameSession.boss_id, 1 if small == BOSS_WAVE_PHASE1 else 2])
	else:
		GameSession.battle_type = "normal"
		print("[WaveManager] 通常Wave構築: BW%d-SW%d" % [big, small])
	enemy_ai._build_enemy_deck()
	enemy_ai.initialize_mana_from_deck()
	enemy_ai._pick_next_card()
	print("[WaveManager] 敵デッキ構築完了: %d枚" % enemy_ai.enemy_deck.size())

func _save_board_snapshot() -> void:
	if board_manager == null:
		print("[WaveManager] WARNING: board_manager未設定")
		return
	var snapshot: Dictionary = {}
	var player_side: int = board_manager.PLAYER_SIDE
	for r in range(3):
		for c in range(3):
			var unit = board_manager.board[player_side][r][c]
			if unit != null:
				snapshot["%d_%d" % [r, c]] = _serialize_unit(unit)
	GameSession.wave_board_snapshot = snapshot
	print("[WaveManager] 盤面保存: %d体" % snapshot.size())

func _restore_board_from_snapshot() -> void:
	if board_manager == null:
		print("[WaveManager] WARNING: board_manager未設定")
		return
	var snapshot: Dictionary = GameSession.wave_board_snapshot
	if snapshot.is_empty():
		print("[WaveManager] スナップショット空")
		return
	var player_side: int = board_manager.PLAYER_SIDE
	var UnitDataScript = load("res://scripts/UnitData.gd")
	for r in range(3):
		for c in range(3):
			board_manager.board[player_side][r][c] = null
	for key in snapshot.keys():
		var parts: Array = key.split("_")
		var r: int = int(parts[0])
		var c: int = int(parts[1])
		var data: Dictionary = snapshot[key]
		var unit = UnitDataScript.new()
		_deserialize_unit(unit, data)
		board_manager.board[player_side][r][c] = unit
		# on_summon再発動防止: tile_system.check_tile_on_enter/attack_timers設定/on_board_changed呼び出し
		board_manager.tile_system.check_tile_on_enter(player_side, r, c, unit)
		board_manager.attack_timers[player_side][r][c] = unit.get_attack_interval()
	print("[WaveManager] 盤面復元: %d体" % snapshot.size())
	board_manager.on_board_changed()

func _serialize_unit(unit: Object) -> Dictionary:
	return {
		"unit_name": unit.unit_name,
		"max_hp": unit.max_hp,
		"current_hp": unit.current_hp,
		"atk": unit.atk,
		"spd": unit.spd,
		"interval": unit.interval,
		"mana": unit.mana,
		"race": unit.race,
		"col": unit.col,
		"range": unit.range,
		"rarity": unit.rarity,
		"cost": unit.cost,
		"_attack_timer": unit._attack_timer,
		"_atk_bonus": unit._atk_bonus,
		"_interval_bonus": unit._interval_bonus,
		"_regen": unit._regen,
		"_has_penetrate": unit._has_penetrate,
		"_kill_atk_bonus": unit._kill_atk_bonus,
		"_stolen_atk": unit._stolen_atk,
		"regen_stacks": unit.regen_stacks,
		"boots_stacks": unit.boots_stacks,
		"power_stacks": unit.power_stacks,
		"effects": unit.effects.duplicate(true),
		"is_support": unit.is_support,
		"is_boss": unit.is_boss,
		"is_elited": unit.is_elited,
	}

func _deserialize_unit(unit: Object, data: Dictionary) -> void:
	unit.unit_name = data.get("unit_name", "")
	unit.max_hp = data.get("max_hp", 1)
	unit.current_hp = data.get("current_hp", 1)
	unit.atk = data.get("atk", 1)
	unit.spd = data.get("spd", 1.0)
	unit.interval = data.get("interval", 1.0)
	unit.mana = data.get("mana", 1)
	unit.race = data.get("race", "")
	unit.col = data.get("col", 0)
	unit.range = data.get("range", "1行")
	unit.rarity = data.get("rarity", "Common")
	unit.cost = data.get("cost", 1)
	unit._attack_timer = data.get("_attack_timer", 0.0)
	unit._atk_bonus = data.get("_atk_bonus", 0)
	unit._interval_bonus = data.get("_interval_bonus", 0.0)
	unit._regen = data.get("_regen", 0)
	unit._has_penetrate = data.get("_has_penetrate", false)
	unit._kill_atk_bonus = data.get("_kill_atk_bonus", 0)
	unit._stolen_atk = data.get("_stolen_atk", 0)
	unit.regen_stacks = data.get("regen_stacks", 0)
	unit.boots_stacks = data.get("boots_stacks", 0)
	unit.power_stacks = data.get("power_stacks", 0)
	unit.effects = data.get("effects", []).duplicate(true)
	unit.is_support = data.get("is_support", false)
	unit.is_boss = data.get("is_boss", false)
	unit.is_elited = data.get("is_elited", false)
