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
	# 自動前進（auto_promote持ちユニットが前マス空きなら移動）
	_process_auto_promote()

	# 前列ユニットの攻撃
	for side in range(2):
		var enemy_side: int = 1 - side
		var front_col: int = 2 if side == 0 else 0
		for row in range(3):
			var unit = bm.board[side][row][front_col]
			if unit == null or unit._is_sealed:
				continue
			bm.attack_timers[side][row][front_col] -= delta
			if bm.attack_timers[side][row][front_col] <= 0.0:
				# 凍結中は攻撃速度低下（逓減・最大50%）: reduction = 0.5 * stacks / (stacks + 2)
				var base_interval: float = unit.get_attack_interval()
				var freeze_penalty: float = 0.0
				if unit.frozen_turns > 0:
					var freeze_reduction: float = 0.5 * float(unit.frozen_turns) / float(unit.frozen_turns + 2)
					freeze_penalty = base_interval * freeze_reduction
				var eff_interval: float = max(0.3, base_interval - unit._interval_bonus - unit._temp_spd_bonus + freeze_penalty)
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
			if unit == null or not unit._can_attack_from_back or unit._is_sealed:
				continue
			bm.attack_timers[side][row][back_col] -= delta
			if bm.attack_timers[side][row][back_col] <= 0.0:
				var base_interval: float = unit.get_attack_interval()
				var freeze_penalty: float = 0.0
				if unit.frozen_turns > 0:
					var freeze_reduction: float = 0.5 * float(unit.frozen_turns) / float(unit.frozen_turns + 2)
					freeze_penalty = base_interval * freeze_reduction
				var eff_interval: float = max(0.3, base_interval - unit._interval_bonus - unit._temp_spd_bonus + freeze_penalty)
				bm.attack_timers[side][row][back_col] = eff_interval
				var back_atk: int = max(1, int(unit.attack * unit._back_atk_factor) + unit._atk_bonus)
				_do_attack(side, row, back_col, unit, enemy_side, base_hp, back_atk, unit._back_target_rear, unit._back_no_on_hit)
		# 中列（支援攻撃のみ）
		for row in range(3):
			var unit = bm.board[side][row][mid_col]
			if unit == null or not unit._can_attack_from_mid or unit._is_sealed:
				continue
			bm.attack_timers[side][row][mid_col] -= delta
			if bm.attack_timers[side][row][mid_col] <= 0.0:
				var base_interval: float = unit.get_attack_interval()
				var freeze_penalty: float = 0.0
				if unit.frozen_turns > 0:
					var freeze_reduction: float = 0.5 * float(unit.frozen_turns) / float(unit.frozen_turns + 2)
					freeze_penalty = base_interval * freeze_reduction
				var eff_interval: float = max(0.3, base_interval - unit._interval_bonus - unit._temp_spd_bonus + freeze_penalty)
				bm.attack_timers[side][row][mid_col] = eff_interval
				var mid_atk: int = max(1, int(unit.attack * unit._back_atk_factor) + unit._atk_bonus)
				_do_attack(side, row, mid_col, unit, enemy_side, base_hp, mid_atk, unit._back_target_rear, unit._back_no_on_hit)

	# v2設計: サポート効果発動（中列・後列のみ、SPD依存タイマー）
	_process_support_effects(delta)

	# 全イベントを優先度順に一括処理
	if bm.event_queue != null:
		bm.event_queue.flush(bm, base_hp)

func _do_attack(side: int, row: int, col: int, attacker: Object, enemy_side: int, base_hp: Array, atk_override: int = -1, target_rear: bool = false, skip_on_hit: bool = false) -> void:
	var effective_atk: int = atk_override if atk_override >= 0 else attacker.attack + attacker._atk_bonus + attacker._temp_atk_bonus
	# powerバフ: スタック×1%ATK上昇
	if attacker.power_stacks > 0:
		var power_bonus: int = max(1, int(float(effective_atk) * attacker.power_stacks * 0.01))
		effective_atk += power_bonus
	# 火傷中はATK低下（逓減・最大80%）: reduction = 0.8 * stacks / (stacks + 2)
	if attacker.burn_turns > 0:
		var burn_reduction: float = 0.8 * float(attacker.burn_turns) / float(attacker.burn_turns + 2)
		effective_atk = max(1, int(float(effective_atk) * (1.0 - burn_reduction)))
	# クリティカル（senseバフでランダム判定）
	var is_critical: bool = false
	var crit_chance: float = 0.0
	if attacker.sense_stacks > 0:
		crit_chance = min(1.0, attacker.sense_stacks * 0.01)
		if randf() <= crit_chance:
			is_critical = true
	if is_critical:
		# 弱点狙い：クリティカル時×3、それ以外は×2
		if attacker._has_weakness_hunter:
			effective_atk *= 3
		else:
			effective_atk *= 2
	# damage_accumulate: 蓄積ダメージを追加ダメージとして反映
	for skill in attacker.skills:
		if skill.get("effect_id", "") == "damage_accumulate" and attacker._accumulated_damage > 0:
			effective_atk += attacker._accumulated_damage
			attacker._accumulated_damage = 0
			break
	var hit_any: bool = false
	var e_front_col: int = 0 if enemy_side == 1 else 2
	var e_mid_col: int = 1
	var e_back_col: int = 2 if enemy_side == 1 else 0
	# 単一ターゲット選択（最大1要素配列で既存ダメージブロックと互換維持）
	var _sel_target: Array = []
	if target_rear:
		var _tc: int = _get_rearmost_col(enemy_side, row)
		if _tc != -1:
			_sel_target = [{"row": row, "col": _tc}]
	else:
		# 優先度1: 同行の前列
		var _fc: int = get_frontmost_col(enemy_side, row)
		if _fc == e_front_col and bm.board[enemy_side][row][_fc] != null:
			_sel_target = [{"row": row, "col": _fc}]
		else:
			# 優先度2: 他行の前列（ランダム順）
			var _other_rows: Array = [0, 1, 2]
			_other_rows.erase(row)
			_other_rows.shuffle()
			for _r in _other_rows:
				var _oc: int = get_frontmost_col(enemy_side, _r)
				if _oc == e_front_col and bm.board[enemy_side][_r][_oc] != null:
					_sel_target = [{"row": _r, "col": _oc}]
					break
		# 優先度3: 同行の中列
		if _sel_target.is_empty() and bm.board[enemy_side][row][e_mid_col] != null:
			_sel_target = [{"row": row, "col": e_mid_col}]
		# 優先度4: 同行の後列
		if _sel_target.is_empty() and bm.board[enemy_side][row][e_back_col] != null:
			_sel_target = [{"row": row, "col": e_back_col}]
	for _sel in _sel_target:
		var target_row: int = _sel["row"]
		var target_col: int = _sel["col"]
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
			# full_hp_defense: HP100%時に被ダメージ減少
			for skill in target.skills:
				if skill.get("effect_id", "") == "full_hp_defense" and target.current_hp >= target.max_hp:
					var reduction: float = skill.get("params", {}).get("reduction", 0.5)
					actual_damage = int(float(actual_damage) * (1.0 - reduction))
					break
			if actual_damage > 0:
				# ダメージイベントをキューに積む
				bm.event_queue.push(
					1,
					attacker, target, "damage", float(actual_damage),
					{"enemy_side": enemy_side, "row": target_row, "col": target_col}
				)
				# 貫通処理（再定義）
				# 貫通：前列攻撃時に中列にも同じダメージ
				# 大貫通：前列攻撃時に中列・後列にも同じダメージ
				# 衝撃：後ろ1マス50%
				if attacker._has_big_penetrate:
					# 大貫通：前列攻撃時に中列100%・後列50%ダメージ
					if target_col == (0 if enemy_side == 0 else 2):
						var rear_col: int = 2 if enemy_side == 0 else 0
						for extra_col in [1, 2] if enemy_side == 0 else [1, 0]:
							var extra_target = bm.board[enemy_side][target_row][extra_col]
							if extra_target != null:
								var dmg_mult: float = 0.5 if extra_col == rear_col else 1.0
								var extra_armor: float = min(1.0, extra_target._damage_reduction * 0.1)
								var extra_dmg: int = max(0, int(float(actual_damage) * dmg_mult * (1.0 - extra_armor)))
								if extra_dmg > 0:
									bm.event_queue.push(
										1,
										attacker, extra_target, "damage", float(extra_dmg),
										{"enemy_side": enemy_side, "row": target_row, "col": extra_col}
									)
				elif attacker._has_penetrate:
					# 貫通：前列攻撃時に中列にも100%ダメージ
					if target_col == (0 if enemy_side == 0 else 2):
						var mid_col: int = 1
						var mid_target = bm.board[enemy_side][target_row][mid_col]
						if mid_target != null:
							var mid_armor: float = min(1.0, mid_target._damage_reduction * 0.1)
							var mid_dmg: int = max(0, int(float(actual_damage) * (1.0 - mid_armor)))
							if mid_dmg > 0:
								bm.event_queue.push(
									1,
									attacker, mid_target, "damage", float(mid_dmg),
									{"enemy_side": enemy_side, "row": target_row, "col": mid_col}
								)
				elif attacker._has_impact:
					# 衝撃：後ろ1マス50%
					var behind_col: int = _get_behind_col(enemy_side, target_row, target_col)
					if behind_col != -1:
						var behind_target = bm.board[enemy_side][target_row][behind_col]
						if behind_target != null:
							var pen_armor: float = min(1.0, behind_target._damage_reduction * 0.1)
							var pen_dmg: int = max(0, int(float(actual_damage) * 0.5 * (1.0 - pen_armor)))
							if pen_dmg > 0:
								bm.event_queue.push(
									1,
									attacker, behind_target, "damage", float(pen_dmg),
									{"enemy_side": enemy_side, "row": target_row, "col": behind_col}
								)
				# 命中時スキル（PRIORITY_ACTIVE）— skip_on_hit時はスキップ
				if not skip_on_hit:
					_push_on_hit_effects(side, row, col, attacker, target,
						enemy_side, target_row, target_col, actual_damage)
	if is_critical:
		bm.skill_triggered.emit(side, row, col, "クリティカル")
	if not hit_any:
		# 本体ダメージイベントをキューに積む
		bm.event_queue.push(
			1,
			attacker, null, "base_damage", float(effective_atk),
			{"side": enemy_side}
		)
	# v2設計: 攻撃発動時にマナ生成（両陣営）
	var mana_gain: float = float(attacker.mana) if attacker.mana >= 0 else 0.0
	# springバフ: スタック×1%マナ生成上昇
	if attacker.spring_stacks > 0:
		var spring_bonus: float = mana_gain * attacker.spring_stacks * 0.01
		mana_gain += spring_bonus
	if side == 0 and bm.deck_manager_ref != null:
		bm.deck_manager_ref.mana += mana_gain
		bm.deck_manager_ref.mana = min(bm.deck_manager_ref.mana, bm.deck_manager_ref.MANA_MAX)
	elif side == 1 and bm.enemy_ai_ref != null:
		bm.enemy_ai_ref.mana += mana_gain
		bm.enemy_ai_ref.mana = min(bm.enemy_ai_ref.mana, bm.enemy_ai_ref.MANA_MAX)
	# on_attack トリガー処理（self_damage_attack等）
	if bm.effect_executor != null:
		for skill in attacker.skills:
			if skill.get("trigger", "") == "on_attack":
				var _mp: Dictionary = skill.get("params", {}).duplicate()
				if skill.has("target"): _mp["target"] = skill["target"]
				bm.effect_executor.execute(skill["effect_id"], _mp, {
					"trigger": "on_attack", "side": side, "row": row, "col": col,
					"source": attacker, "target": null, "damage": 0,
					"board_manager": bm, "deck_manager": bm.deck_manager_ref, "enemy_ai": bm.enemy_ai_ref,
					"event_queue": bm.event_queue
				})

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
	# 旧方式は削除済み。全てskills配列で処理。

# _get_target_rows は REQ-B で廃止（多行攻撃廃止・単一ターゲット方式に移行）

func _process_support_effects(delta: float) -> void:
	# v2設計: 中列・後列のサポート効果をSPD依存で発動
	for side in range(2):
		var front_col: int = 2 if side == 0 else 0
		var mid_col: int = 1
		var back_col: int = 0 if side == 0 else 2

		for row in range(3):
			# 中列
			var mid_unit = bm.board[side][row][mid_col]
			if mid_unit != null and not mid_unit._is_sealed:
				bm.support_timers[side][row][mid_col] -= delta
				if bm.support_timers[side][row][mid_col] <= 0.0:
					var base_interval: float = mid_unit.get_attack_interval()
					var freeze_penalty: float = 0.0
					if mid_unit.frozen_turns > 0:
						var freeze_reduction: float = 0.5 * float(mid_unit.frozen_turns) / float(mid_unit.frozen_turns + 2)
						freeze_penalty = base_interval * freeze_reduction
					var eff_interval: float = max(0.3, base_interval - mid_unit._interval_bonus - mid_unit._temp_spd_bonus + freeze_penalty)
					bm.support_timers[side][row][mid_col] = eff_interval
					_trigger_support(side, row, mid_col, mid_unit)

			# 後列
			var back_unit = bm.board[side][row][back_col]
			if back_unit != null and not back_unit._is_sealed:
				bm.support_timers[side][row][back_col] -= delta
				if bm.support_timers[side][row][back_col] <= 0.0:
					var base_interval: float = back_unit.get_attack_interval()
					var freeze_penalty: float = 0.0
					if back_unit.frozen_turns > 0:
						var freeze_reduction: float = 0.5 * float(back_unit.frozen_turns) / float(back_unit.frozen_turns + 2)
						freeze_penalty = base_interval * freeze_reduction
					var eff_interval: float = max(0.3, base_interval - back_unit._interval_bonus - back_unit._temp_spd_bonus + freeze_penalty)
					bm.support_timers[side][row][back_col] = eff_interval
					_trigger_support(side, row, back_col, back_unit)

func _trigger_support(side: int, row: int, col: int, unit: Object) -> void:
	# v2設計: サポート効果発動 + マナ生成

	# サポート効果発動（skills配列から実行）
	# v2設計: 前列ではサポート効果発動しない
	var front_col: int = 2 if side == 0 else 0
	if col != front_col and bm.effect_executor != null:
		for skill in unit.skills:
			# v2設計: on_hit以外のスキルをサポート効果として実行
			var trigger = skill.get("trigger", "")
			if trigger == "on_hit":
				continue

			# サポート効果実行（always, on_tick など）
			var merged_params: Dictionary = skill.get("params", {}).duplicate()
			if skill.has("target"):
				merged_params["target"] = skill["target"]

			bm.effect_executor.execute(skill["effect_id"], merged_params, {
				"trigger": "support",
				"side": side,
				"row": row,
				"col": col,
				"source": unit,
				"target": null,
				"damage": 0,
				"board_manager": bm,
				"deck_manager": bm.deck_manager_ref,
				"enemy_ai": bm.enemy_ai_ref,
				"event_queue": bm.event_queue
			})

	# マナ生成（両陣営）
	var mana_gain: float = float(unit.mana) if unit.mana >= 0 else 0.0
	if side == 0 and bm.deck_manager_ref != null:
		bm.deck_manager_ref.mana += mana_gain
		bm.deck_manager_ref.mana = min(bm.deck_manager_ref.mana, bm.deck_manager_ref.MANA_MAX)
	elif side == 1 and bm.enemy_ai_ref != null:
		bm.enemy_ai_ref.mana += mana_gain
		bm.enemy_ai_ref.mana = min(bm.enemy_ai_ref.mana, bm.enemy_ai_ref.MANA_MAX)

func _process_auto_promote() -> void:
	for side in range(2):
		for row in range(3):
			for col in range(3):
				var unit = bm.board[side][row][col]
				if unit == null or not unit._auto_promote:
					continue
				# 前方のマスが空いていれば移動（side0: col+1方向、side1: col-1方向）
				var next_col: int = col + 1 if side == 0 else col - 1
				if next_col < 0 or next_col >= 3:
					continue
				if bm.board[side][row][next_col] != null:
					continue
				if bm.board_artifacts[side][row][next_col] != null:
					continue
				# 移動実行
				bm.tile_system.check_tile_on_leave(side, row, col, unit)
				bm.board[side][row][next_col] = unit
				bm.attack_timers[side][row][next_col] = unit.get_attack_interval()
				bm.board[side][row][col] = null
				bm.attack_timers[side][row][col] = 0.0
				bm.tile_system.check_tile_on_enter(side, row, next_col, unit)
				bm.on_board_changed()

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
	if victim.regen_stacks > 0:
		stealer.regen_stacks += int(victim.regen_stacks * multiplier)
		victim.regen_stacks = 0
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
	# 旧方式は削除済み。全てskills配列で処理。

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
		bm.skill_triggered.emit(k_side, k_row, k_col, "デバフ波及")
