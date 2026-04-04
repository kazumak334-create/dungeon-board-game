# BoardManager.gd
class_name BoardManager
extends Node

var board: Array = []
var attack_timers: Array = []
var event_queue: Node = null   # EventQueue（Main.gd が設定）
var base_hp_ref: Array = []    # Main.gd の base_hp への参照（Timer tick 用）
var _board_dirty: bool = true  # true のときのみサポート効果を再計算
var _status_timer: Timer = null
var _regen_tick: int = 0       # リジェネ用：2秒ごとにカウント

signal unit_placed(side: int, row: int, col: int, unit: Object)
signal unit_died(side: int, row: int, col: int)
signal unit_revived(side: int, row: int, col: int)
signal unit_damaged(side: int, row: int, col: int)
signal base_damaged(side: int, amount: int)
signal active_skill_used(side: int, row: int, col: int, skill_name: String)
signal status_damage(unit_name: String, status: String, damage: int, stacks: int)
signal status_applied(unit_name: String, status: String, stacks: int)
signal status_cleared(unit_name: String, status: String)
signal draw_cards_requested(side: int, count: int)
signal spell_cast(side: int, spell_name: String)

func _ready() -> void:
	_setup()

func _setup() -> void:
	board = []
	attack_timers = []
	for s in range(2):
		board.append([])
		attack_timers.append([])
		for r in range(3):
			board[s].append([null, null, null])
			attack_timers[s].append([0.0, 0.0, 0.0])
	# 状態異常・HP回復を1秒ごとに処理するTimerノード
	_status_timer = Timer.new()
	_status_timer.wait_time  = 1.0
	_status_timer.autostart  = true
	_status_timer.timeout.connect(_on_status_tick)
	add_child(_status_timer)

func place_unit(side: int, unit_data: Object) -> bool:
	var col: int = unit_data.assigned_col
	if side == 0:
		col = 2 - col  # 自陣は前列=col2なのでインデックスを反転
	var rows: Array = [0, 1, 2]
	rows.shuffle()
	for row in rows:
		if board[side][row][col] == null:
			var placed = unit_data.clone()
			board[side][row][col] = placed
			attack_timers[side][row][col] = placed.attack_interval
			emit_signal("unit_placed", side, row, col, placed)
			on_board_changed()
			# 中列に配置されたとき前列が空なら promote_check を積む（遅延1フレーム）
			if col == 1 and event_queue != null:
				var front_col: int = 2 if side == 0 else 0
				event_queue.push(EventQueue.PRIORITY_BOARD, null, null, "promote_check", 0.0,
					{"side": side, "row": row, "col": front_col})
			_init_skill_timers(placed)
			_push_summon_effects(side, row, col, placed)
			return true
	print("[BoardManager] 配置失敗: side=%d col=%d は満杯" % [side, col])
	return false

func get_unit(side: int, row: int, col: int) -> Object:
	return board[side][row][col]

func remove_unit(side: int, row: int, col: int) -> void:
	var unit = board[side][row][col]
	if unit == null:
		return  # 既に削除済み（EventQueue の二重処理対策）
	# 自己再起チェック（撃破時・1回限り）
	if unit != null and "自己再起" in unit.active_skill and not unit._has_revived:
		unit._has_revived = true
		unit.current_hp = 5
		attack_timers[side][row][col] = unit.attack_interval
		emit_signal("unit_revived", side, row, col)
		return
	board[side][row][col] = null
	attack_timers[side][row][col] = 0.0
	emit_signal("unit_died", side, row, col)
	# 前列が空になったら promote_check を遅延キューに積む（イベント駆動・1フレームラグ）
	var front_col_ref: int = 2 if side == 0 else 0
	if col == front_col_ref and event_queue != null:
		event_queue.push(EventQueue.PRIORITY_BOARD, null, null, "promote_check", 0.0,
			{"side": side, "row": row, "col": col})
	on_board_changed()

func process_combat(delta: float, base_hp: Array) -> void:
	# フォールバック：event_queue 未設定時のみサポート効果を再計算
	if _board_dirty:
		_board_dirty = false
		_apply_support_effects()

	# 前列ユニットの攻撃
	for side in range(2):
		var enemy_side: int = 1 - side
		var front_col: int = 2 if side == 0 else 0
		for row in range(3):
			var unit = board[side][row][front_col]
			if unit == null:
				continue
			# 麻痺中は攻撃不能
			if unit.paralysis_turns > 0:
				continue
			attack_timers[side][row][front_col] -= delta
			if attack_timers[side][row][front_col] <= 0.0:
				# 凍結中は攻撃速度低下（逓減・最大50%）: reduction = 0.5 * stacks / (stacks + 2)
				var freeze_penalty: float = 0.0
				if unit.frozen_turns > 0:
					var freeze_reduction: float = 0.5 * float(unit.frozen_turns) / float(unit.frozen_turns + 2)
					freeze_penalty = unit.attack_interval * freeze_reduction
				var eff_interval: float = max(0.3, unit.attack_interval - unit._interval_bonus - unit._temp_spd_bonus + freeze_penalty)
				attack_timers[side][row][front_col] = eff_interval
				_do_attack(side, row, front_col, unit, enemy_side, base_hp)

	# 後列ユニットの攻撃（後列攻撃サポート効果を持つ場合）
	for side in range(2):
		var enemy_side: int = 1 - side
		var back_col: int = 0 if side == 0 else 2
		for row in range(3):
			var unit = board[side][row][back_col]
			if unit == null or not unit._can_attack_from_back:
				continue
			if unit.paralysis_turns > 0:
				continue
			attack_timers[side][row][back_col] -= delta
			if attack_timers[side][row][back_col] <= 0.0:
				var freeze_penalty: float = 0.0
				if unit.frozen_turns > 0:
					var freeze_reduction: float = 0.5 * float(unit.frozen_turns) / float(unit.frozen_turns + 2)
					freeze_penalty = unit.attack_interval * freeze_reduction
				var eff_interval: float = max(0.3, unit.attack_interval - unit._interval_bonus - unit._temp_spd_bonus + freeze_penalty)
				attack_timers[side][row][back_col] = eff_interval
				var back_atk: int = max(1, int(unit.attack * unit._back_atk_factor) + unit._atk_bonus)
				_do_attack(side, row, back_col, unit, enemy_side, base_hp, back_atk)

	# 全イベントを優先度順に一括処理
	if event_queue != null:
		event_queue.flush(self, base_hp)

func _do_attack(side: int, row: int, col: int, attacker: Object, enemy_side: int, base_hp: Array, atk_override: int = -1) -> void:
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
		# 前列→中列→後列の順で最初にいるユニットを攻撃（案A）
		var target_col: int = _get_frontmost_col(enemy_side, target_row)
		if target_col != -1:
			hit_any = true
			var target = board[enemy_side][target_row][target_col]
			# 鎧による軽減（1スタック=10%軽減・最大100%）
			var armor_pct: float = min(1.0, target._damage_reduction * 0.1)
			var actual_damage: int = max(0, int(float(effective_atk) * (1.0 - armor_pct)))
			if actual_damage > 0:
				# ダメージイベントをキューに積む
				event_queue.push(
					EventQueue.PRIORITY_IMMEDIATE,
					attacker, target, "damage", float(actual_damage),
					{"enemy_side": enemy_side, "row": target_row, "col": target_col}
				)
				# 吸血バフ：ダメージの30%をHP回復
				if attacker._has_lifesteal:
					var heal: int = max(1, int(actual_damage * 0.3))
					event_queue.push(
						EventQueue.PRIORITY_ACTIVE,
						target, attacker, "heal", float(heal),
						{"src_side": side, "src_row": row, "src_col": col, "skill_name": "吸血"}
					)
				# 貫通バフ：後ろ1マスにも同量ダメージ（攻撃時効果なし）
				if attacker._has_penetrate:
					var behind_col: int = _get_behind_col(enemy_side, target_row, target_col)
					if behind_col != -1:
						var behind_target = board[enemy_side][target_row][behind_col]
						if behind_target != null:
							var pen_armor: float = min(1.0, behind_target._damage_reduction * 0.1)
							var pen_dmg: int = max(0, int(float(actual_damage) * (1.0 - pen_armor)))
							if pen_dmg > 0:
								event_queue.push(
									EventQueue.PRIORITY_IMMEDIATE,
									attacker, behind_target, "damage", float(pen_dmg),
									{"enemy_side": enemy_side, "row": target_row, "col": behind_col}
								)
				# 命中時アクティブスキル（PRIORITY_ACTIVE）
				_push_on_hit_effects(side, row, col, attacker, target,
					enemy_side, target_row, target_col, actual_damage)
	if is_critical:
		active_skill_used.emit(side, row, col, "クリティカル")
	if not hit_any:
		# 本体ダメージイベントをキューに積む
		event_queue.push(
			EventQueue.PRIORITY_IMMEDIATE,
			attacker, null, "base_damage", float(effective_atk),
			{"side": enemy_side}
		)

func _push_on_hit_effects(side: int, row: int, col: int, attacker: Object, target: Object,
		enemy_side: int, target_row: int, target_col: int, damage: int) -> void:
	for entry in attacker.active_skill.split(" / "):
		if "命中時" not in entry:
			continue
		# 火傷付与（PRIORITY_ACTIVE）
		if "火傷付与" in entry:
			event_queue.push(
				EventQueue.PRIORITY_ACTIVE,
				attacker, target, "status_apply", 0.0,
				{"status": "火傷", "side": enemy_side, "row": target_row, "col": target_col,
				 "src_side": side, "src_row": row, "src_col": col, "skill_name": "火傷付与"}
			)
		# 毒付与（PRIORITY_ACTIVE）
		if "毒付与" in entry:
			event_queue.push(
				EventQueue.PRIORITY_ACTIVE,
				attacker, target, "status_apply", 0.0,
				{"status": "毒", "stacks": 1, "side": enemy_side, "row": target_row, "col": target_col,
				 "src_side": side, "src_row": row, "src_col": col, "skill_name": "毒付与"}
			)
		# 凍結付与（PRIORITY_ACTIVE）
		if "凍結付与" in entry:
			event_queue.push(
				EventQueue.PRIORITY_ACTIVE,
				attacker, target, "status_apply", 0.0,
				{"status": "凍結", "stacks": 3, "side": enemy_side, "row": target_row, "col": target_col,
				 "src_side": side, "src_row": row, "src_col": col, "skill_name": "凍結付与"}
			)
		# 麻痺付与（PRIORITY_ACTIVE）
		if "麻痺付与" in entry:
			event_queue.push(
				EventQueue.PRIORITY_ACTIVE,
				attacker, target, "status_apply", 0.0,
				{"status": "麻痺", "stacks": 1, "side": enemy_side, "row": target_row, "col": target_col,
				 "src_side": side, "src_row": row, "src_col": col, "skill_name": "麻痺付与"}
			)
		# 連鎖（PRIORITY_ACTIVE：隣接行の敵に50%ダメージ波及）
		if "連鎖" in entry:
			var chain_damage: int = max(1, damage / 2)
			for adj_row in _get_adjacent_rows(target_row):
				var adj_col: int = _get_frontmost_col(enemy_side, adj_row)
				if adj_col != -1:
					var adj_target = board[enemy_side][adj_row][adj_col]
					event_queue.push(
						EventQueue.PRIORITY_ACTIVE,
						attacker, adj_target, "damage", float(chain_damage),
						{"enemy_side": enemy_side, "row": adj_row, "col": adj_col}
					)
			active_skill_used.emit(side, row, col, "連鎖")

func _push_summon_effects(side: int, row: int, col: int, unit: Object) -> void:
	if event_queue == null:
		return
	for entry in unit.active_skill.split(" / "):
		if "召喚時" not in entry:
			continue
		if "追加召喚" in entry:
			event_queue.push(EventQueue.PRIORITY_ACTIVE, unit, null, "extra_summon", 0.0,
				{"side": side, "row": row, "col": col})
		if "ドロー" in entry:
			var count: int = 2 if "2枚" in entry else 1
			event_queue.push(EventQueue.PRIORITY_ACTIVE, unit, null, "draw_cards", float(count),
				{"side": side, "src_side": side, "src_row": row, "src_col": col,
				 "skill_name": "2枚ドロー"})
		if "最前列" in entry and "突撃" in entry:
			event_queue.push(EventQueue.PRIORITY_ACTIVE, unit, null, "force_move_front", 0.0,
				{"side": side, "row": row, "col": col,
				 "src_side": side, "src_row": row, "src_col": col, "skill_name": "最前列突撃"})

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
	board[side][row][front_col] = mid_unit
	attack_timers[side][row][front_col] = mid_unit.attack_interval
	board[side][row][1] = null
	attack_timers[side][row][1] = 0.0
	on_board_changed()

func _get_frontmost_col(side: int, row: int) -> int:
	# 前列→中列→後列の順で最初にユニットがいる列を返す（-1=なし）
	var col_order: Array = [2, 1, 0] if side == 0 else [0, 1, 2]
	for c in col_order:
		if board[side][row][c] != null:
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
		if found_front and board[side][row][c] != null:
			return c
	return -1

func _get_adjacent_rows(row: int) -> Array:
	var rows: Array = []
	if row > 0: rows.append(row - 1)
	if row < 2: rows.append(row + 1)
	return rows

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

# ---- サポート効果システム ----

func _apply_support_effects() -> void:
	# ボーナスをリセット
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board[s][r][c]
				if u != null:
					u._atk_bonus = 0
					u._interval_bonus = 0.0
					u._regen = 0.0
					u._can_attack_from_back = false
					u._back_atk_factor = 1.0
					u._damage_reduction = 0
					u._has_lifesteal = false
					u._has_penetrate = false
					u._regen_stacks = 0
	# 各ユニットのサポート効果を適用
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board[s][r][c]
				if u != null:
					_process_unit_support(s, r, c, u)
	# アクティブスキル由来のバフ + ATKバフ上限適用
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board[s][r][c]
				if u == null:
					continue
				if "吸血" in u.active_skill:
					u._has_lifesteal = true
				if "貫通" in u.active_skill:
					u._has_penetrate = true
				u._atk_bonus = min(u._atk_bonus, 10)  # ATKバフ重複上限+10

func _process_unit_support(side: int, row: int, col: int, unit: Object) -> void:
	for entry in unit.support_effect.split(" / "):
		if "常時発動" not in entry:
			continue
		# 後列攻撃は自ユニットへの自己効果
		if "後列攻撃" in entry:
			unit._can_attack_from_back = true
			unit._back_atk_factor = 0.3 if "極低ATK" in entry else 1.0
			continue
		# 〈〉内のターゲット記述を取得
		var bs: int = entry.find("〈")
		var be: int = entry.find("〉")
		if bs == -1 or be == -1:
			continue
		var parts: Array = entry.substr(bs + 1, be - bs - 1).split("・")
		var target_desc: String = parts[1] if parts.size() > 1 else ""
		var targets: Array = _get_support_targets(side, row, col, target_desc)
		if "ATKバフ" in entry:
			for t in targets:
				t._atk_bonus += 2
		elif "SPDバフ" in entry:
			for t in targets:
				t._interval_bonus += 0.3
		elif "HPバフ" in entry:
			for t in targets:
				t._regen += 1.0
		elif "障壁付与" in entry:
			for t in targets:
				t._damage_reduction += 1
		elif "吸血付与" in entry:
			for t in targets:
				t._has_lifesteal = true
		elif "貫通付与" in entry:
			for t in targets:
				t._has_penetrate = true
		elif "リジェネ付与" in entry:
			for t in targets:
				t._regen_stacks += 1

func _get_support_targets(side: int, row: int, col: int, target_desc: String) -> Array:
	var positions: Array = []
	if "隣接" in target_desc:
		for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var r2: int = row + d[0]
			var c2: int = col + d[1]
			if r2 >= 0 and r2 < 3 and c2 >= 0 and c2 < 3:
				positions.append([r2, c2])
	elif "同行前列" in target_desc:
		var front: int = 2 if side == 0 else 0
		positions.append([row, front])
	elif "前列" in target_desc:
		var front: int = 2 if side == 0 else 0
		for r2 in range(3):
			positions.append([r2, front])
	elif "同行" in target_desc:
		for c2 in range(3):
			if c2 != col:
				positions.append([row, c2])
	elif "同列" in target_desc:
		for r2 in range(3):
			if r2 != row:
				positions.append([r2, col])
	elif "全体" in target_desc:
		for r2 in range(3):
			for c2 in range(3):
				if not (r2 == row and c2 == col):
					positions.append([r2, c2])
	# 種族フィルタ
	var race_filter: String = ""
	for race in ["獣", "スライム", "アンデッド"]:
		if race in target_desc:
			race_filter = race
			break
	var result: Array = []
	for pos in positions:
		var u = board[side][pos[0]][pos[1]]
		if u == null:
			continue
		if race_filter != "" and u.race != race_filter:
			continue
		result.append(u)
	return result

func on_board_changed() -> void:
	if event_queue != null:
		# PRIORITY_SUPPORT：盤面変化後にサポート効果を再計算
		event_queue.push(EventQueue.PRIORITY_SUPPORT, null, null, "support_apply", 0.0)
	else:
		_board_dirty = true  # フォールバック（event_queue 未設定時）

func _on_status_tick() -> void:
	if event_queue == null:
		return
	# HP回復（サポート効果の _regen を1秒ごとに適用）
	_apply_regen()
	# リジェネバフ（2秒ごとにHP5%×スタック数回復）
	_regen_tick += 1
	if _regen_tick >= 2:
		_regen_tick = 0
		_apply_regen_buff()
	# 時間経過スキル処理
	_process_timed_skills()
	# HP閾値スキルチェック
	_check_hp_thresholds()
	# 状態異常処理
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board[s][r][c]
				if u == null:
					continue
				# 毒ダメージ
				if u.poison_stacks > 0:
					event_queue.push(
						EventQueue.PRIORITY_STATUS, null, u, "poison_damage",
						float(u.poison_stacks),
						{"enemy_side": s, "row": r, "col": c, "unit_name": u.unit_name}
					)
				# 状態異常カウントダウン
				for status_pair in [["frozen_turns", "凍結"], ["burn_turns", "火傷"], ["paralysis_turns", "麻痺"]]:
					var val: int = u.get(status_pair[0])
					if val > 0:
						u.set(status_pair[0], val - 1)
						if val - 1 == 0:
							event_queue.push(
								EventQueue.PRIORITY_STATUS, null, u, "status_clear", 0.0,
								{"unit_name": u.unit_name, "status": status_pair[1]}
							)
	# Timer ティックで flush（regen + 毒 + 時間経過スキルをまとめて処理）
	event_queue.flush(self, base_hp_ref)

func _apply_regen() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board[s][r][c]
				if u != null and u._regen > 0.0:
					event_queue.push(
						EventQueue.PRIORITY_IMMEDIATE,
						null, u, "heal", float(roundi(u._regen)),
						{"src_side": s, "src_row": r, "src_col": c}
					)

func _apply_regen_buff() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board[s][r][c]
				if u != null and u._regen_stacks > 0:
					var heal: int = max(1, u.max_hp * 5 * u._regen_stacks / 100)
					event_queue.push(
						EventQueue.PRIORITY_IMMEDIATE,
						null, u, "heal", float(heal),
						{"src_side": s, "src_row": r, "src_col": c}
					)

# ---- 時間経過スキルシステム ----

func _init_skill_timers(unit: Object) -> void:
	unit._skill_timers.clear()
	for entry in unit.active_skill.split(" / "):
		if "時間経過" not in entry:
			continue
		var interval: float = _parse_skill_interval(entry)
		if interval > 0.0:
			unit._skill_timers[entry] = interval

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

func _process_timed_skills() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board[s][r][c]
				if u == null:
					continue
				# 一時バフ減衰
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
				# 時間経過スキルタイマー
				if u._skill_timers.is_empty():
					continue
				var fired: Array = []
				for entry in u._skill_timers:
					u._skill_timers[entry] -= 1.0
					if u._skill_timers[entry] <= 0.0:
						fired.append(entry)
				for entry in fired:
					_fire_timed_skill(s, r, c, u, entry)
					u._skill_timers[entry] = _parse_skill_interval(entry)

func _fire_timed_skill(side: int, row: int, col: int, unit: Object, entry: String) -> void:
	var enemy_side: int = 1 - side
	# SPD低下（同行の敵全体に凍結付与）
	if "SPD低下" in entry:
		for c2 in range(3):
			var target = board[enemy_side][row][c2]
			if target != null and target.is_alive():
				event_queue.push(EventQueue.PRIORITY_ACTIVE, unit, target, "status_apply", 0.0,
					{"status": "凍結", "stacks": 2, "side": enemy_side, "row": row, "col": c2,
					 "src_side": side, "src_row": row, "src_col": col, "skill_name": "SPD低下"})
		active_skill_used.emit(side, row, col, "SPD低下")
	# 全体回復（自HP20%消費→全味方HP+10）
	elif "全体回復" in entry:
		var hp_cost: int = max(1, unit.max_hp / 5)
		if unit.current_hp > hp_cost:
			event_queue.push(EventQueue.PRIORITY_ACTIVE, unit, unit, "damage", float(hp_cost),
				{"enemy_side": side, "row": row, "col": col})
			for r2 in range(3):
				for c2 in range(3):
					var ally = board[side][r2][c2]
					if ally != null and ally.is_alive():
						event_queue.push(EventQueue.PRIORITY_ACTIVE, unit, ally, "heal", 10.0,
							{"src_side": side, "src_row": row, "src_col": col, "skill_name": "全体回復"})
	# 全体ATK低下（敵全行に火傷付与）
	elif "全体ATK低下" in entry:
		for r2 in range(3):
			for c2 in range(3):
				var target = board[enemy_side][r2][c2]
				if target != null and target.is_alive():
					event_queue.push(EventQueue.PRIORITY_ACTIVE, unit, target, "status_apply", 0.0,
						{"status": "火傷", "stacks": 2, "side": enemy_side, "row": r2, "col": c2,
						 "src_side": side, "src_row": row, "src_col": col, "skill_name": "全体ATK低下"})
		active_skill_used.emit(side, row, col, "全体ATK低下")
	# ATKバフ（同行の獣全員ATK+3・5秒間）
	elif "ATKバフ" in entry:
		for c2 in range(3):
			var ally = board[side][row][c2]
			if ally != null and ally.is_alive() and ally.race == "獣":
				ally._temp_atk_bonus = 3
				ally._temp_atk_timer = 5.0
		active_skill_used.emit(side, row, col, "ATKバフ")
	# 単体大ダメージ（最大HP敵1体にATK×3）
	elif "単体大ダメージ" in entry:
		var best_target: Object = null
		var best_info: Dictionary = {}
		for r2 in range(3):
			for c2 in range(3):
				var target = board[enemy_side][r2][c2]
				if target != null and target.is_alive():
					if best_target == null or target.current_hp > best_target.current_hp:
						best_target = target
						best_info = {"enemy_side": enemy_side, "row": r2, "col": c2}
		if best_target != null:
			var big_dmg: int = unit.attack * 3
			event_queue.push(EventQueue.PRIORITY_ACTIVE, unit, best_target, "damage", float(big_dmg),
				best_info)
			active_skill_used.emit(side, row, col, "単体大ダメージ")

# ---- 撃破時スキルシステム ----

func _process_on_kill(killer: Object) -> void:
	# killerの盤面位置を探す
	var k_side: int = -1
	var k_row: int = -1
	var k_col: int = -1
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if board[s][r][c] == killer:
					k_side = s; k_row = r; k_col = c
	if k_side == -1:
		return
	var enemy_side: int = 1 - k_side
	for entry in killer.active_skill.split(" / "):
		if "撃破時" not in entry:
			continue
		# ATK累積（撃破時ATK+2・上限+10）
		if "ATK累積" in entry:
			if killer._kill_atk_bonus < 10:
				var prev_bonus: int = killer._kill_atk_bonus
				killer._kill_atk_bonus = min(killer._kill_atk_bonus + 2, 10)
				killer.attack += killer._kill_atk_bonus - prev_bonus
				active_skill_used.emit(k_side, k_row, k_col, "ATK累積")
		# 敵SPD低下（撃破時・全体に凍結付与）
		if "SPD低下" in entry:
			for r2 in range(3):
				for c2 in range(3):
					var target = board[enemy_side][r2][c2]
					if target != null and target.is_alive():
						event_queue.push(EventQueue.PRIORITY_ACTIVE, killer, target, "status_apply", 0.0,
							{"status": "凍結", "stacks": 4, "side": enemy_side, "row": r2, "col": c2,
							 "src_side": k_side, "src_row": k_row, "src_col": k_col, "skill_name": "敵SPD低下"})
			active_skill_used.emit(k_side, k_row, k_col, "敵SPD低下")

# ---- HP閾値スキルシステム ----

func _check_hp_thresholds() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board[s][r][c]
				if u == null or not u.is_alive():
					continue
				for entry in u.active_skill.split(" / "):
					if "HP閾値時" not in entry:
						continue
					if u._hp_threshold_triggered.get(entry, false):
						continue  # 既に発動済み
					var threshold: float = _parse_hp_threshold(entry)
					if threshold <= 0.0:
						continue
					var hp_ratio: float = float(u.current_hp) / float(u.max_hp)
					if hp_ratio <= threshold:
						u._hp_threshold_triggered[entry] = true
						_fire_hp_threshold_skill(s, r, c, u, entry)

func _parse_hp_threshold(entry: String) -> float:
	# "HP30%以下" → 0.3, "HP50%以下" → 0.5
	var idx: int = entry.find("HP")
	if idx == -1:
		return 0.0
	var after: int = idx + 2  # "HP" = 2 chars
	var pct_idx: int = entry.find("%", after)
	if pct_idx == -1:
		return 0.0
	return float(entry.substr(after, pct_idx - after)) / 100.0

func _fire_hp_threshold_skill(side: int, row: int, col: int, unit: Object, entry: String) -> void:
	# 後退（後列に自動退避）
	if "後退" in entry:
		var back_col: int = 0 if side == 0 else 2
		if col != back_col and board[side][row][back_col] == null:
			board[side][row][back_col] = unit
			attack_timers[side][row][back_col] = unit.attack_interval
			board[side][row][col] = null
			attack_timers[side][row][col] = 0.0
			on_board_changed()
			active_skill_used.emit(side, row, back_col, "後退")
	# 結晶化（完全無敵3s）
	elif "結晶化" in entry:
		unit._invincible_timer = 3.0
		active_skill_used.emit(side, row, col, "結晶化")
	# 前列強制突撃
	elif "前列強制突撃" in entry:
		var front_col: int = 2 if side == 0 else 0
		if col != front_col and board[side][row][front_col] == null:
			board[side][row][front_col] = unit
			attack_timers[side][row][front_col] = unit.attack_interval
			board[side][row][col] = null
			attack_timers[side][row][col] = 0.0
			on_board_changed()
			active_skill_used.emit(side, row, front_col, "前列強制突撃")
	# ATK/SPD2倍（10秒間）
	elif "2倍" in entry:
		unit._temp_atk_bonus = unit.attack  # ATK2倍 = 現ATK分を加算
		unit._temp_atk_timer = 10.0
		unit._temp_spd_bonus = unit.attack_interval * 0.5  # 攻撃間隔半減
		unit._temp_spd_timer = 10.0
		active_skill_used.emit(side, row, col, "ATK/SPD2倍")
