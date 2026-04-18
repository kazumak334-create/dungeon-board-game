# scripts/WaveManager.gd
# Phase 4 #0a: 継続ウェーブ進行管理システム
# 1Act = 1BW = 7小Wave + ボス2連戦（計9Wave）の進行・状態保持・敵強化係数適用・BW間RestScreen呼び出し
extends Node

# 参照ノード
var board_manager: Node = null
var deck_manager: Node = null
var enemy_ai: Node = null
var main_ref: Node = null

# Wave状態
enum WaveState {
	IDLE,
	COMBAT,
	BETWEEN_SMALL,
	REST,
	BW_COMPLETE,
}
var state: WaveState = WaveState.IDLE

# Signal
signal wave_started(big: int, small: int, scale: float)
signal wave_ended(big: int, small: int, victory: bool)
signal rest_screen_requested()
signal big_wave_completed(big: int)

# 内部スクリプト参照
var _WaveConfig = preload("res://scripts/WaveConfig.gd")
var _UnitDataScript = preload("res://scripts/UnitData.gd")

func setup(bm: Node, dm: Node, eai: Node, main: Node) -> void:
	board_manager = bm
	deck_manager = dm
	enemy_ai = eai
	main_ref = main
	state = WaveState.IDLE
	print("[WaveManager] setup完了")

func start_big_wave(big_index: int) -> void:
	print("[WaveManager] BW %d 開始" % big_index)
	GameSession.wave_current_big = big_index
	GameSession.wave_current_small = 1
	GameSession.wave_mana_carryover = 0.0
	GameSession.wave_unit_states = []
	GameSession.wave_dead_units = []
	GameSession.wave_rest_pending = false
	state = WaveState.IDLE

func start_next_small_wave() -> void:
	var next_wave: int = GameSession.wave_current_small + 1
	if next_wave > _WaveConfig.TOTAL_WAVES_PER_BW:
		push_error("[WaveManager] start_next_small_wave: すでにBW完了状態")
		return
	GameSession.wave_current_small = next_wave
	print("[WaveManager] 小Wave %d 開始" % next_wave)
	restore_wave_state()
	state = WaveState.COMBAT
	var scale: float = _WaveConfig.get_scale(next_wave)
	wave_started.emit(GameSession.wave_current_big, next_wave, scale)

func on_wave_victory() -> void:
	var current_small: int = GameSession.wave_current_small
	print("[WaveManager] on_wave_victory: Wave %d 勝利" % current_small)
	wave_ended.emit(GameSession.wave_current_big, current_small, true)
	
	if _WaveConfig.is_final_wave(current_small):
		print("[WaveManager] ボス第二形態勝利 -> BW完了")
		state = WaveState.REST
		GameSession.wave_rest_pending = true
		rest_screen_requested.emit()
		return
	
	save_wave_state()
	state = WaveState.BETWEEN_SMALL
	print("[WaveManager] 状態保存完了、2秒後に次Wave開始")
	get_tree().create_timer(2.0).timeout.connect(_start_next_wave_delayed)

func _start_next_wave_delayed() -> void:
	if state != WaveState.BETWEEN_SMALL:
		return
	start_next_small_wave()

func on_wave_defeat() -> void:
	print("[WaveManager] on_wave_defeat: 敗北")
	wave_ended.emit(GameSession.wave_current_big, GameSession.wave_current_small, false)
	state = WaveState.IDLE

func save_wave_state() -> void:
	print("[WaveManager] save_wave_state: Wave %d" % GameSession.wave_current_small)
	GameSession.wave_unit_states = []
	
	GameSession.wave_mana_carryover = deck_manager.mana
	print("[WaveManager]   マナ保存: %.1f" % deck_manager.mana)
	
	for row in range(3):
		for col in range(3):
			var unit = board_manager.board[0][row][col]
			if unit != null:
				var state_dict = _serialize_unit(unit, row, col)
				GameSession.wave_unit_states.append(state_dict)
				print("[WaveManager]   保存: %s (r%d c%d HP %d/%d)" % [unit.unit_name, row, col, unit.current_hp, unit.max_hp])
	
	print("[WaveManager] 保存完了: %d体" % GameSession.wave_unit_states.size())

func restore_wave_state() -> void:
	print("[WaveManager] restore_wave_state: Wave %d" % GameSession.wave_current_small)
	
	deck_manager.mana = GameSession.wave_mana_carryover
	print("[WaveManager]   マナ復元: %.1f" % deck_manager.mana)
	
	for state_dict in GameSession.wave_unit_states:
		var unit = _deserialize_unit(state_dict)
		var row: int = state_dict["row"]
		var col: int = state_dict["col"]
		board_manager.board[0][row][col] = unit
		board_manager.attack_timers[0][row][col] = unit.get_attack_interval()
		print("[WaveManager]   復元: %s (r%d c%d HP %d/%d)" % [unit.unit_name, row, col, unit.current_hp, unit.max_hp])
		if board_manager.tile_system != null:
			board_manager.tile_system.check_tile_on_enter(0, row, col, unit)
	
	board_manager.on_board_changed()
	print("[WaveManager] 復元完了: %d体" % GameSession.wave_unit_states.size())

func _serialize_unit(unit, row: int, col: int) -> Dictionary:
	var initial_slot: int = row * 3 + col
	return {
		"row": row,
		"col": col,
		"initial_slot": initial_slot,
		"unit_name": unit.unit_name,
		"current_hp": unit.current_hp,
		"max_hp": unit.max_hp,
		"attack": unit.attack,
		"spd": unit.spd,
		"mana": unit.mana,
		"race": unit.race,
		"rarity": unit.rarity,
		"range": unit.range,
		"col_range": unit.col_range,
		"_atk_bonus": unit._atk_bonus,
		"_interval_bonus": unit._interval_bonus,
		"_kill_atk_bonus": unit._kill_atk_bonus,
		"_stolen_atk": unit._stolen_atk,
		"_stolen_spd": unit._stolen_spd,
		"_stolen_armor": unit._stolen_armor,
		"_has_penetrate": unit._has_penetrate,
		"_has_big_penetrate": unit._has_big_penetrate,
		"_has_impact": unit._has_impact,
		"_damage_reduction": unit._damage_reduction,
		"regen_stacks": unit.regen_stacks,
		"power_stacks": unit.power_stacks,
		"boots_stacks": unit.boots_stacks,
		"spring_stacks": unit.spring_stacks,
		"sense_stacks": unit.sense_stacks,
		"skills": unit.skills.duplicate(),
		"is_synthesized": unit.is_synthesized,
	}

func _deserialize_unit(state: Dictionary):
	var unit = _UnitDataScript.new()
	unit.unit_name = state["unit_name"]
	unit.current_hp = state["current_hp"]
	unit.max_hp = state["max_hp"]
	unit.attack = state["attack"]
	unit.spd = state["spd"]
	unit.mana = state["mana"]
	unit.race = state["race"]
	unit.rarity = state["rarity"]
	unit.range = state["range"]
	unit.col_range = state["col_range"]
	unit._atk_bonus = state["_atk_bonus"]
	unit._interval_bonus = state["_interval_bonus"]
	unit._kill_atk_bonus = state["_kill_atk_bonus"]
	unit._stolen_atk = state["_stolen_atk"]
	unit._stolen_spd = state["_stolen_spd"]
	unit._stolen_armor = state["_stolen_armor"]
	unit._has_penetrate = state["_has_penetrate"]
	unit._has_big_penetrate = state["_has_big_penetrate"]
	unit._has_impact = state["_has_impact"]
	unit._damage_reduction = state["_damage_reduction"]
	unit.regen_stacks = state["regen_stacks"]
	unit.power_stacks = state["power_stacks"]
	unit.boots_stacks = state["boots_stacks"]
	unit.spring_stacks = state["spring_stacks"]
	unit.sense_stacks = state["sense_stacks"]
	unit.skills = state["skills"].duplicate()
	unit.is_synthesized = state["is_synthesized"]
	unit.poison_stacks = 0
	unit.frozen_turns = 0
	unit.burn_turns = 0
	unit._temp_atk_bonus = 0
	unit._temp_spd_bonus = 0.0
	return unit

func apply_enemy_scale(wave_index: int) -> void:
	var scale: float = _WaveConfig.get_scale(wave_index)
	enemy_ai.apply_wave_scale(scale, scale)
	print("[WaveManager] Wave %d スケール適用: x%.2f" % [wave_index, scale])

func get_current_scale() -> float:
	return _WaveConfig.get_scale(GameSession.wave_current_small)

func is_boss_wave() -> bool:
	return _WaveConfig.is_boss_wave(GameSession.wave_current_small)

func is_big_wave_complete() -> bool:
	return GameSession.wave_rest_pending

func get_remaining_waves() -> int:
	return _WaveConfig.TOTAL_WAVES_PER_BW - GameSession.wave_current_small

func on_rest_screen_completed(next_act: int) -> void:
	print("[WaveManager] RestScreen完了、次Act %d へ" % next_act)
	state = WaveState.BW_COMPLETE
	big_wave_completed.emit(next_act)
