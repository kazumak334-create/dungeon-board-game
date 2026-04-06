# TickSystem.gd
# 毎秒Tick処理（状態異常/リジェネ/タイマースキル/復活/アーティファクトタイマー）
# BoardManagerから委譲される
extends RefCounted

var bm: Node = null  # BoardManagerへの参照

func setup(board_manager: Node) -> void:
	bm = board_manager

func on_tick() -> void:
	if bm.event_queue == null:
		return
	var main_node = bm.get_parent()
	if main_node != null and main_node.get("game_paused") == true:
		return
	_process_pending_revives()
	_apply_regen()
	bm._regen_tick += 1
	if bm._regen_tick >= 2:
		bm._regen_tick = 0
		_apply_regen_buff()
	bm.tile_system.process_tile_effects()
	_process_artifact_timers()
	_process_timed_skills()
	_check_hp_thresholds()
	_process_status_ticks()
	bm.event_queue.flush(bm, bm.base_hp_ref)

func _process_pending_revives() -> void:
	var revived: Array = []
	for i in range(bm._pending_revives.size()):
		bm._pending_revives[i]["timer"] -= 1.0
		if bm._pending_revives[i]["timer"] <= 0.0:
			revived.append(i)
			var rev = bm._pending_revives[i]
			var s: int = rev["side"]
			var r: int = rev["row"]
			var u: Object = rev["unit"]
			var placed: bool = false
			for c in range(3):
				if bm.board[s][r][c] == null:
					u.current_hp = rev["hp"]
					bm.board[s][r][c] = u
					bm.attack_timers[s][r][c] = u.attack_interval
					bm.emit_signal("unit_revived", s, r, c)
					bm.on_board_changed()
					placed = true
					break
			if not placed:
				pass
	for i in range(revived.size() - 1, -1, -1):
		bm._pending_revives.remove_at(revived[i])

func _apply_regen() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = bm.board[s][r][c]
				if u != null and u._regen > 0.0:
					bm.event_queue.push(1, null, u, "heal", float(roundi(u._regen)),
						{"src_side": s, "src_row": r, "src_col": c})

func _apply_regen_buff() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = bm.board[s][r][c]
				if u == null:
					continue
				if u._regen_stacks > 0:
					var heal: int = max(1, u.max_hp * 5 * u._regen_stacks / 100)
					bm.event_queue.push(1, null, u, "heal", float(heal),
						{"src_side": s, "src_row": r, "src_col": c})
					u._regen_stacks -= 1
				if u.lifesteal_stacks > 0:
					u.lifesteal_stacks -= 1
					u._has_lifesteal = u.lifesteal_stacks > 0

func init_skill_timers(unit: Object) -> void:
	unit._skill_timers.clear()
	for i in range(unit.skills.size()):
		var skill = unit.skills[i]
		if skill.get("trigger", "") == "timer":
			var interval: float = skill.get("params", {}).get("interval", 0.0)
			if interval > 0.0:
				unit._skill_timers["timer_%d" % i] = interval
	for i in range(unit.skills.size()):
		var skill = unit.skills[i]
		if skill.get("trigger", "") == "always" and skill.get("params", {}).has("interval"):
			var interval: float = skill["params"]["interval"]
			if interval > 0.0:
				unit._skill_timers["support_" + str(i)] = interval
	# 旧方式passive_skill文字列パース（時間経過）は削除済み。timer triggerをskills配列で処理。

func _parse_skill_interval(entry: String) -> float:
	var marker: String = "時間経過"
	var idx: int = entry.find(marker)
	if idx == -1:
		return 0.0
	var after: int = idx + marker.length()
	var s_idx: int = entry.find("s", after)
	if s_idx == -1:
		return 0.0
	return float(entry.substr(after, s_idx - after))

func _process_artifact_timers() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var art = bm.board_artifacts[s][r][c]
				if art == null:
					continue
				var timers: Dictionary = art.get("timers", {})
				if timers.is_empty():
					continue
				var fired: Array = []
				for key in timers:
					timers[key] -= 1.0
					if timers[key] <= 0.0:
						fired.append(key)
				for key in fired:
					if key.begins_with("timer_"):
						var idx: int = int(key.substr(6))
						var skills: Array = art.get("skills", [])
						if idx < skills.size():
							var sk = skills[idx]
							var _mp: Dictionary = sk.get("params", {}).duplicate()
							if sk.has("target"): _mp["target"] = sk["target"]
							bm._execute_artifact_skill(s, r, c, art, sk["effect_id"], _mp)
							timers[key] = sk.get("params", {}).get("interval", 1.0)

func _process_timed_skills() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = bm.board[s][r][c]
				if u == null:
					continue
				if u._temp_atk_timer > 0.0:
					u._temp_atk_timer -= 1.0
					if u._temp_atk_timer <= 0.0:
						u._temp_atk_bonus = 0
				if u._temp_spd_timer > 0.0:
					u._temp_spd_timer -= 1.0
					if u._temp_spd_timer <= 0.0:
						u._temp_spd_bonus = 0.0
				if u._invincible_timer > 0.0:
					u._invincible_timer -= 1.0
				if u._skill_timers.is_empty():
					continue
				var fired: Array = []
				for entry in u._skill_timers:
					u._skill_timers[entry] -= 1.0
					if u._skill_timers[entry] <= 0.0:
						fired.append(entry)
				for entry in fired:
					if entry.begins_with("support_"):
						var front_col: int = 2 if s == 0 else 0
						if c == front_col:
							var idx2: int = int(entry.substr(8))
							if idx2 < u.skills.size():
								u._skill_timers[entry] = u.skills[idx2].get("params", {}).get("interval", 1.0)
							continue
						var idx2: int = int(entry.substr(8))
						if idx2 < u.skills.size():
							var skill2 = u.skills[idx2]
							if bm.effect_executor != null:
								bm.effect_executor.execute(skill2["effect_id"], skill2.get("params", {}), {
									"trigger": "always", "side": s, "row": r, "col": c,
									"source": u, "target": null, "damage": 0,
									"board_manager": bm, "deck_manager": bm.deck_manager_ref, "enemy_ai": bm.enemy_ai_ref,
									"event_queue": bm.event_queue
								})
							u._skill_timers[entry] = skill2.get("params", {}).get("interval", 1.0)
						continue
					if entry.begins_with("timer_") and bm.effect_executor != null:
						var idx: int = int(entry.substr(6))
						if idx < u.skills.size():
							var skill = u.skills[idx]
							var _mp: Dictionary = skill.get("params", {}).duplicate()
							if skill.has("target"): _mp["target"] = skill["target"]
							bm.effect_executor.execute(skill["effect_id"], _mp, {
								"trigger": "timer", "side": s, "row": r, "col": c,
								"source": u, "target": null, "damage": 0,
								"board_manager": bm, "deck_manager": bm.deck_manager_ref, "enemy_ai": bm.enemy_ai_ref,
								"event_queue": bm.event_queue
							})
							u._skill_timers[entry] = skill.get("params", {}).get("interval", 1.0)
					else:
						_fire_timed_skill(s, r, c, u, entry)
						u._skill_timers[entry] = _parse_skill_interval(entry)

func _check_hp_thresholds() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = bm.board[s][r][c]
				if u == null or not u.is_alive():
					continue
				# 旧方式passive_skill文字列パースは削除済み
				# skills配列のon_hp_threshold処理（新方式）
				for i in range(u.skills.size()):
					var skill = u.skills[i]
					if skill.get("trigger", "") != "on_hp_threshold":
						continue
					var key: String = "skill_hp_%d" % i
					if u._hp_threshold_triggered.get(key, false):
						continue
					var threshold: float = skill.get("params", {}).get("threshold", 0.5)
					var hp_ratio: float = float(u.current_hp) / float(u.max_hp)
					if hp_ratio <= threshold:
						u._hp_threshold_triggered[key] = true
						if bm.effect_executor != null:
							var _mp: Dictionary = skill.get("params", {}).duplicate()
							if skill.has("target"):
								_mp["target"] = skill["target"]
							bm.effect_executor.execute(skill["effect_id"], _mp, {
								"trigger": "on_hp_threshold", "side": s, "row": r, "col": c,
								"source": u, "target": null, "damage": 0,
								"board_manager": bm, "deck_manager": bm.deck_manager_ref, "enemy_ai": bm.enemy_ai_ref,
								"event_queue": bm.event_queue
							})

func _parse_hp_threshold(entry: String) -> float:
	var idx: int = entry.find("HP")
	if idx == -1:
		return 0.0
	var after: int = idx + 2
	var pct_idx: int = entry.find("%", after)
	if pct_idx == -1:
		return 0.0
	return float(entry.substr(after, pct_idx - after)) / 100.0

func _fire_timed_skill(side: int, row: int, col: int, unit: Object, entry: String) -> void:
	var enemy_side: int = 1 - side
	if "SPD低下" in entry:
		for c2 in range(3):
			var target = bm.board[enemy_side][row][c2]
			if target != null and target.is_alive():
				bm.event_queue.push(4, unit, target, "status_apply", 0.0,
					{"status": "凍結", "stacks": 2, "side": enemy_side, "row": row, "col": c2,
					 "src_side": side, "src_row": row, "src_col": col, "skill_name": "SPD低下"})
		bm.skill_triggered.emit(side, row, col, "SPD低下")
	elif "全体回復" in entry:
		var hp_cost: int = max(1, unit.max_hp / 5)
		if unit.current_hp > hp_cost:
			bm.event_queue.push(4, unit, unit, "damage", float(hp_cost),
				{"enemy_side": side, "row": row, "col": col})
			for r2 in range(3):
				for c2 in range(3):
					var ally = bm.board[side][r2][c2]
					if ally != null and ally.is_alive():
						bm.event_queue.push(4, unit, ally, "heal", 10.0,
							{"src_side": side, "src_row": row, "src_col": col, "skill_name": "全体回復"})
	elif "全体ATK低下" in entry:
		for r2 in range(3):
			for c2 in range(3):
				var target = bm.board[enemy_side][r2][c2]
				if target != null and target.is_alive():
					bm.event_queue.push(4, unit, target, "status_apply", 0.0,
						{"status": "火傷", "stacks": 2, "side": enemy_side, "row": r2, "col": c2,
						 "src_side": side, "src_row": row, "src_col": col, "skill_name": "全体ATK低下"})
		bm.skill_triggered.emit(side, row, col, "全体ATK低下")
	elif "ATKバフ" in entry:
		for c2 in range(3):
			var ally = bm.board[side][row][c2]
			if ally != null and ally.is_alive() and ally.race == "獣":
				ally._temp_atk_bonus = 3
				ally._temp_atk_timer = 5.0
		bm.skill_triggered.emit(side, row, col, "ATKバフ")
	elif "単体大ダメージ" in entry:
		var best_target: Object = null
		var best_info: Dictionary = {}
		for r2 in range(3):
			for c2 in range(3):
				var target = bm.board[enemy_side][r2][c2]
				if target != null and target.is_alive():
					if best_target == null or target.current_hp > best_target.current_hp:
						best_target = target
						best_info = {"enemy_side": enemy_side, "row": r2, "col": c2}
		if best_target != null:
			var big_dmg: int = unit.attack * 3
			bm.event_queue.push(4, unit, best_target, "damage", float(big_dmg), best_info)
			bm.skill_triggered.emit(side, row, col, "単体大ダメージ")
	elif "全バフ奪取" in entry:
		var best_target: Object = null
		var best_info: Dictionary = {}
		var best_buff_count: int = 0
		for r2 in range(3):
			for c2 in range(3):
				var target = bm.board[enemy_side][r2][c2]
				if target != null and target.is_alive():
					var buff_count: int = 0
					if target._atk_bonus > 0: buff_count += 1
					if target._interval_bonus > 0.0: buff_count += 1
					if target.lifesteal_stacks > 0: buff_count += 1
					if target._has_penetrate: buff_count += 1
					if target._regen_stacks > 0: buff_count += 1
					if target._damage_reduction > 0: buff_count += 1
					if buff_count > best_buff_count:
						best_buff_count = buff_count
						best_target = target
						best_info = {"enemy_side": enemy_side, "row": r2, "col": c2}
		if best_target != null and best_buff_count > 0:
			bm._steal_buffs(unit, best_target, 1.5)
			bm.skill_triggered.emit(side, row, col, "全バフ奪取")
	elif "呪い付与" in entry:
		for r2 in range(3):
			for c2 in range(3):
				var target = bm.board[enemy_side][r2][c2]
				if target != null and target.is_alive():
					bm.event_queue.push(4, unit, target, "status_apply", 0.0,
						{"status": "毒", "stacks": 3, "side": enemy_side, "row": r2, "col": c2,
						 "src_side": side, "src_row": row, "src_col": col, "skill_name": "呪い付与"})
		bm.skill_triggered.emit(side, row, col, "呪い付与")
	elif "全体凍結" in entry:
		for c2 in range(3):
			var target = bm.board[enemy_side][row][c2]
			if target != null and target.is_alive():
				bm.event_queue.push(4, unit, target, "status_apply", 0.0,
					{"status": "凍結", "stacks": 4, "side": enemy_side, "row": row, "col": c2,
					 "src_side": side, "src_row": row, "src_col": col, "skill_name": "全体凍結"})
		bm.skill_triggered.emit(side, row, col, "全体凍結")
	elif "強力な毒" in entry:
		for c2 in range(3):
			var target = bm.board[enemy_side][row][c2]
			if target != null and target.is_alive():
				bm.event_queue.push(4, unit, target, "status_apply", 0.0,
					{"status": "毒", "stacks": 5, "side": enemy_side, "row": row, "col": c2,
					 "src_side": side, "src_row": row, "src_col": col, "skill_name": "強力な毒"})
		bm.skill_triggered.emit(side, row, col, "強力な毒")
	elif "全体麻痺" in entry:
		for c2 in range(3):
			var target = bm.board[enemy_side][row][c2]
			if target != null and target.is_alive():
				bm.event_queue.push(4, unit, target, "status_apply", 0.0,
					{"status": "麻痺", "stacks": 2, "side": enemy_side, "row": row, "col": c2,
					 "src_side": side, "src_row": row, "src_col": col, "skill_name": "全体麻痺"})
		bm.skill_triggered.emit(side, row, col, "全体麻痺")

func _process_status_ticks() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = bm.board[s][r][c]
				if u == null:
					continue
				if u.poison_stacks > 0:
					bm.event_queue.push(2, null, u, "poison_damage",
						float(u.poison_stacks),
						{"enemy_side": s, "row": r, "col": c, "unit_name": u.unit_name})
				for status_pair in [["frozen_turns", "凍結"], ["burn_turns", "火傷"], ["paralysis_turns", "麻痺"]]:
					var val: int = u.get(status_pair[0])
					if val > 0:
						u.set(status_pair[0], val - 1)
						if val - 1 == 0:
							bm.event_queue.push(2, null, u, "status_clear", 0.0,
								{"unit_name": u.unit_name, "status": status_pair[1]})
