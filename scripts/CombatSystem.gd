# CombatSystem.gd
# 戦闘処理（攻撃ループ・ダメージ計算・命中時スキル・撃破時・デバフ波及・バフ奪取）
extends RefCounted

var bm: Node = null
var _EDB = null

func setup(board_manager: Node) -> void:
	bm = board_manager
	_EDB = load("res://scripts/EffectDB.gd")

func process_combat(delta: float, base_hp: Array) -> void:
	# フォールバック：event_queue 未設定時のみサポート効果を再計算
	if bm._board_dirty:
		bm._board_dirty = false
		bm.support_system.apply_support_effects()

	# 前列ユニットの攻撃
	for side in range(2):
		var enemy_side: int = 1 - side
		var front_col: int = 2 if side == 0 else 0
		for row in range(3):
			var unit = bm.board[side][row][front_col]
			if unit == null:
				continue
			# 麻痺中は攻撃不能
			if unit.paralysis_turns > 0:
				continue
			bm.attack_timers[side][row][front_col] -= delta
			if bm.attack_timers[side][row][front_col] <= 0.0:
				# 凍結中は攻撃速度低下（逓減・最大50%）: reduction = 0.5 * stacks / (stacks + 2)
				var freeze_penalty: float = 0.0
				if unit.frozen_turns > 0:
					var freeze_reduction: float = 0.5 * float(unit.frozen_turns) / float(unit.frozen_turns + 2)
					freeze_penalty = unit.attack_interval * freeze_reduction
				var eff_interval: float = max(0.3, unit.attack_interval - unit._interval_bonus - unit._temp_spd_bonus + freeze_penalty)
				bm.attack_timers[side][row][front_col] = eff_interval
				_do_attack(side, row, front_col, unit, enemy_side, base_hp)

	# 後列・中列ユニットの攻撃（狙撃/支援攻撃サポート効果を持つ場合）
	for side in range(2):
		var enemy_side: int = 1 - side
		var back_col: int = 0 if side == 0 else 2
		var mid_col: int = 1
		# 後列
		for row in range(3):
			var unit = bm.board[side][row][back_col]
			if unit == null or not unit._can_attack_from_back:
				continue
			if unit.paralysis_turns > 0:
				continue
			bm.attack_timers[side][row][back_col] -= delta
			if bm.attack_timers[side][row][back_col] <= 0.0:
				var freeze_penalty: float = 0.0
				if unit.frozen_turns > 0:
					var freeze_reduction: float = 0.5 * float(unit.frozen_turns) / float(unit.frozen_turns + 2)
					freeze_penalty = unit.attack_interval * freeze_reduction
				var eff_interval: float = max(0.3, unit.attack_interval - unit._interval_bonus - unit._temp_spd_bonus + freeze_penalty)
				bm.attack_timers[side][row][back_col] = eff_interval
				var back_atk: int = max(1, int(unit.attack * unit._back_atk_factor) + unit._atk_bonus)
				_do_attack(side, row, back_col, unit, enemy_side, base_hp, back_atk, unit._back_target_rear, unit._back_no_on_hit)
		# 中列（支援攻撃のみ）
		for row in range(3):
			var unit = bm.board[side][row][mid_col]
			if unit == null or not unit._can_attack_from_mid:
				continue
			if unit.paralysis_turns > 0:
				continue
			bm.attack_timers[side][row][mid_col] -= delta
			if bm.attack_timers[side][row][mid_col] <= 0.0:
				var freeze_penalty: float = 0.0
				if unit.frozen_turns > 0:
					var freeze_reduction: float = 0.5 * float(unit.frozen_turns) / float(unit.frozen_turns + 2)
					freeze_penalty = unit.attack_interval * freeze_reduction
				var eff_interval: float = max(0.3, unit.attack_interval - unit._interval_bonus - unit._temp_spd_bonus + freeze_penalty)
				bm.attack_timers[side][row][mid_col] = eff_interval
				var mid_atk: int = max(1, int(unit.attack * unit._back_atk_factor) + unit._atk_bonus)
				_do_attack(side, row, mid_col, unit, enemy_side, base_hp, mid_atk, unit._back_target_rear, unit._back_no_on_hit)

	# 全イベントを優先度順に一括処理
	if bm.event_queue != null:
		bm.event_queue.flush(bm, base_hp)

func _do_attack(side: int, row: int, col: int, attacker: Object, enemy_side: int, base_hp: Array, atk_override: int = -1, target_rear: bool = false, skip_on_hit: bool = false) -> void:
	var effective_atk: int = atk_override if atk_override >= 0 else attacker.attack + attacker._atk_bonus + attacker._temp_atk_bonus
	# 火傷中はATK低下（逓減・最大80%）: reduction = 0.8 * stacks / (stacks + 2)
	if attacker.burn_turns > 0:
		var burn_reduction: float = 0.8 * float(attacker.burn_turns) / float(attacker.burn_turns + 2)
		effective_atk = max(1, int(float(effective_atk) * (1.0 - burn_reduction)))
	# クリティカル（初撃ATK×2）
	var is_critical: bool = false
	if attacker._first_attack and "クリティカル" in attacker.active_skill:
		effective_atk *= 2
		attacker._first_attack = false
		is_critical = true
	var target_rows: Array = _get_target_rows(row, attacker.attack_range)
	var hit_any: bool = false
	for target_row in target_rows:
		# ターゲット選択：最後列優先 or 最前列優先
		var target_col: int = _get_rearmost_col(enemy_side, target_row) if target_rear else get_frontmost_col(enemy_side, target_row)
		if target_col != -1:
			hit_any = true
			var target = bm.board[enemy_side][target_row][target_col]
			# アーティファクトへの攻撃処理
			if target == null:
				var art = bm.board_artifacts[enemy_side][target_row][target_col]
				if art != null:
					art["hp"] -= effective_atk
					if art["hp"] <= 0:
						bm.remove_artifact(enemy_side, target_row, target_col)
				continue
			# 鎧による軽減（1スタック=10%軽減・最大100%）+ 被弾で-1
			var armor_pct: float = min(1.0, target._damage_reduction * 0.1)
			var actual_damage: int = max(0, int(float(effective_atk) * (1.0 - armor_pct)))
			if target._damage_reduction > 0:
				target._damage_reduction -= 1
			# 呪われた地チェック
			var _te_curse = bm.board_effects[enemy_side][target_row][target_col]
			if _te_curse != null and not target.get("_is_flying") == true:
				var _tile_curse_def = _EDB.EFFECTS.get(_te_curse["effect_id"], {})
				if _tile_curse_def.has("damage_mult"):
					actual_damage = int(float(actual_damage) * _tile_curse_def["damage_mult"])
			if actual_damage > 0:
				# ダメージイベントをキューに積む
				bm.event_queue.push(
					1,
					attacker, target, "damage", float(actual_damage),
					{"enemy_side": enemy_side, "row": target_row, "col": target_col}
				)
				# 吸血バフ：ダメージの(3%×スタック)をHP回復
				if attacker.lifesteal_stacks > 0:
					var heal_pct: float = 0.03 * attacker.lifesteal_stacks
					var heal: int = max(1, int(actual_damage * heal_pct))
					bm.event_queue.push(
						4,
						target, attacker, "heal", float(heal),
						{"src_side": side, "src_row": row, "src_col": col, "skill_name": "吸血"}
					)
				# 衝撃/貫通/大貫通スキルによるダメージ波及
				var pen_depth: int = 0
				var pen_factors: Array = []
				if attacker._has_big_penetrate:
					pen_depth = 2
					pen_factors = [1.0, 0.5]
				elif attacker._has_penetrate:
					pen_depth = 1
					pen_factors = [1.0]
				elif attacker._has_impact:
					pen_depth = 1
					pen_factors = [0.5]
				if pen_depth > 0:
					var prev_col: int = target_col
					for d_idx in range(pen_depth):
						var behind_col: int = _get_behind_col(enemy_side, target_row, prev_col)
						if behind_col == -1:
							break
						prev_col = behind_col
						var behind_target = bm.board[enemy_side][target_row][behind_col]
						if behind_target != null:
							var pen_armor: float = min(1.0, behind_target._damage_reduction * 0.1)
							var pen_dmg: int = max(0, int(float(actual_damage) * pen_factors[d_idx] * (1.0 - pen_armor)))
							if pen_dmg > 0:
								bm.event_queue.push(
									1,
									attacker, behind_target, "damage", float(pen_dmg),
									{"enemy_side": enemy_side, "row": target_row, "col": behind_col}
								)
				# 命中時アクティブスキル（PRIORITY_ACTIVE）— skip_on_hit時はスキップ
				if not skip_on_hit:
					_push_on_hit_effects(side, row, col, attacker, target,
						enemy_side, target_row, target_col, actual_damage)
	if is_critical:
		bm.active_skill_used.emit(side, row, col, "クリティカル")
	if not hit_any:
		# 本体ダメージイベントをキューに積む
		bm.event_queue.push(
			1,
			attacker, null, "base_damage", float(effective_atk),
			{"side": enemy_side}
		)

func _push_on_hit_effects(side: int, row: int, col: int, attacker: Object, target: Object,
		enemy_side: int, target_row: int, target_col: int, damage: int) -> void:
	# skills配列のon_hit処理（新方式）
	if bm.effect_executor != null:
		for skill in attacker.skills:
			if skill.get("trigger", "") == "on_hit":
				var _mp: Dictionary = skill.get("params", {}).duplicate()
				if skill.has("target"): _mp["target"] = skill["target"]
				bm.effect_executor.execute(skill["effect_id"], _mp, {
					"trigger": "on_hit", "side": side, "row": row, "col": col,
					"source": attacker, "target": target, "damage": damage,
					"target_row": target_row, "target_col": target_col,
					"board_manager": bm, "deck_manager": bm.deck_manager_ref, "enemy_ai": bm.enemy_ai_ref,
					"event_queue": bm.event_queue
				})
	# 旧方式（active_skill文字列パース）は削除済み。全てskills配列で処理。

func _get_target_rows(attacker_row: int, attack_range: String) -> Array:
	match attack_range:
		"上含む2行":
			if attacker_row > 0:
				return [attacker_row - 1, attacker_row]
			return [attacker_row]
		"下含む2行":
			if attacker_row < 2:
				return [attacker_row, attacker_row + 1]
			return [attacker_row]
		"上下含む3行":
			return [0, 1, 2]
		_:
			return [attacker_row]

func get_frontmost_col(side: int, row: int) -> int:
	# 前列→中列→後列の順で最初にユニットまたはアーティファクトがいる列を返す（-1=なし）
	var col_order: Array = [2, 1, 0] if side == 0 else [0, 1, 2]
	for c in col_order:
		if bm.board[side][row][c] != null or bm.board_artifacts[side][row][c] != null:
			return c
	return -1

func _get_rearmost_col(side: int, row: int) -> int:
	# 後列→中列→前列の順で最初にユニットがいる列を返す（-1=なし）
	var col_order: Array = [0, 1, 2] if side == 0 else [2, 1, 0]
	for c in col_order:
		if bm.board[side][row][c] != null:
			return c
	return -1

func _get_behind_col(side: int, row: int, front_col: int) -> int:
	# front_col の後ろにいるユニットの列を返す（-1=なし）
	var col_order: Array = [2, 1, 0] if side == 0 else [0, 1, 2]
	var found_front: bool = false
	for c in col_order:
		if c == front_col:
			found_front = true
			continue
		if found_front and bm.board[side][row][c] != null:
			return c
	return -1

func _get_adjacent_rows(row: int) -> Array:
	var rows: Array = []
	if row > 0: rows.append(row - 1)
	if row < 2: rows.append(row + 1)
	return rows

func steal_buffs(stealer: Object, victim: Object, multiplier: float) -> void:
	# _stolen_* に蓄積することでサポート効果リセット後も永続する
	# ATKボーナス奪取
	if victim._atk_bonus > 0:
		stealer._stolen_atk += int(victim._atk_bonus * multiplier)
	# SPDボーナス奪取
	if victim._interval_bonus > 0.0:
		stealer._stolen_spd += victim._interval_bonus * multiplier
	# 吸血奪取（スタック移動）
	if victim.lifesteal_stacks > 0:
		stealer.lifesteal_stacks += int(victim.lifesteal_stacks * multiplier)
		victim.lifesteal_stacks = 0
	# 貫通奪取（スキルフラグ移動）
	if victim._has_penetrate:
		stealer._has_penetrate = true
		victim._has_penetrate = false
	if victim._has_impact:
		stealer._has_impact = true
		victim._has_impact = false
	if victim._has_big_penetrate:
		stealer._has_big_penetrate = true
		victim._has_big_penetrate = false
	# リジェネ奪取（スタック直接移動）
	if victim._regen_stacks > 0:
		stealer._regen_stacks += int(victim._regen_stacks * multiplier)
		victim._regen_stacks = 0
	# 鎧奪取
	if victim._damage_reduction > 0:
		stealer._stolen_armor += int(victim._damage_reduction * multiplier)

func process_on_kill(killer: Object) -> void:
	# killerの盤面位置を探す
	var k_side: int = -1
	var k_row: int = -1
	var k_col: int = -1
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if bm.board[s][r][c] == killer:
					k_side = s; k_row = r; k_col = c
	if k_side == -1:
		return
	var enemy_side: int = 1 - k_side
	# skills配列のon_kill処理（新方式）
	if bm.effect_executor != null:
		for skill in killer.skills:
			if skill.get("trigger", "") == "on_kill":
				var _mp: Dictionary = skill.get("params", {}).duplicate()
				if skill.has("target"): _mp["target"] = skill["target"]
				bm.effect_executor.execute(skill["effect_id"], _mp, {
					"trigger": "on_kill", "side": k_side, "row": k_row, "col": k_col,
					"source": killer, "target": null, "damage": 0,
					"board_manager": bm, "deck_manager": bm.deck_manager_ref, "enemy_ai": bm.enemy_ai_ref,
					"event_queue": bm.event_queue
				})
	# 旧方式active_skill文字列パースは削除済み。全てskills配列で処理。

func process_debuff_spread(killer: Object, victim: Object, victim_side: int, victim_row: int, victim_col: int) -> void:
	# 死亡した敵の周囲（上下左右）の敵にデバフを波及
	var k_side: int = -1
	var k_row: int = -1
	var k_col: int = -1
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if bm.board[s][r][c] == killer:
					k_side = s; k_row = r; k_col = c
	for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
		var r2: int = victim_row + d[0]
		var c2: int = victim_col + d[1]
		if r2 < 0 or r2 >= 3 or c2 < 0 or c2 >= 3:
			continue
		var adj = bm.board[victim_side][r2][c2]
		if adj == null or not adj.is_alive():
			continue
		# 死亡ユニットが持っていたデバフを半減して波及
		if victim.poison_stacks > 0:
			bm.event_queue.push(4, killer, adj, "status_apply", 0.0,
				{"status": "毒", "stacks": max(1, victim.poison_stacks / 2),
				 "side": victim_side, "row": r2, "col": c2,
				 "src_side": k_side, "src_row": k_row, "src_col": k_col, "skill_name": "デバフ波及"})
		if victim.frozen_turns > 0:
			bm.event_queue.push(4, killer, adj, "status_apply", 0.0,
				{"status": "凍結", "stacks": max(1, victim.frozen_turns / 2),
				 "side": victim_side, "row": r2, "col": c2,
				 "src_side": k_side, "src_row": k_row, "src_col": k_col, "skill_name": "デバフ波及"})
		if victim.burn_turns > 0:
			bm.event_queue.push(4, killer, adj, "status_apply", 0.0,
				{"status": "火傷", "stacks": max(1, victim.burn_turns / 2),
				 "side": victim_side, "row": r2, "col": c2,
				 "src_side": k_side, "src_row": k_row, "src_col": k_col, "skill_name": "デバフ波及"})
	if k_side >= 0:
		bm.active_skill_used.emit(k_side, k_row, k_col, "デバフ波及")
