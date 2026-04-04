# BoardManager.gd
class_name BoardManager
extends Node

var board: Array = []
var attack_timers: Array = []
var _regen_timer: float = 1.0
var event_queue: Node = null  # EventQueue（Main.gd が設定）

signal unit_placed(side: int, row: int, col: int, unit: Object)
signal unit_died(side: int, row: int, col: int)
signal unit_revived(side: int, row: int, col: int)
signal base_damaged(side: int, amount: int)
signal active_skill_used(side: int, row: int, col: int, skill_name: String)

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
	_try_promote(side, row, col)

func process_combat(delta: float, base_hp: Array) -> void:
	# サポート効果ボーナスを毎フレーム再計算
	_apply_support_effects()

	# HP回復ティック（1秒ごと）
	_regen_timer -= delta
	if _regen_timer <= 0.0:
		_regen_timer += 1.0
		_apply_regen()

	# 前列が空なら中列を繰り上げ（毎フレーム確認）
	for side in range(2):
		var front_col: int = 2 if side == 0 else 0
		for row in range(3):
			_try_promote(side, row, front_col)

	# 前列ユニットの攻撃
	for side in range(2):
		var enemy_side: int = 1 - side
		var front_col: int = 2 if side == 0 else 0
		for row in range(3):
			var unit = board[side][row][front_col]
			if unit == null:
				continue
			attack_timers[side][row][front_col] -= delta
			if attack_timers[side][row][front_col] <= 0.0:
				var eff_interval: float = max(0.3, unit.attack_interval - unit._interval_bonus)
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
			attack_timers[side][row][back_col] -= delta
			if attack_timers[side][row][back_col] <= 0.0:
				var eff_interval: float = max(0.3, unit.attack_interval - unit._interval_bonus)
				attack_timers[side][row][back_col] = eff_interval
				var back_atk: int = max(1, int(unit.attack * unit._back_atk_factor) + unit._atk_bonus)
				_do_attack(side, row, back_col, unit, enemy_side, base_hp, back_atk)

	# 全イベントを優先度順に一括処理
	if event_queue != null:
		event_queue.flush(self, base_hp)

func _do_attack(side: int, row: int, col: int, attacker: Object, enemy_side: int, base_hp: Array, atk_override: int = -1) -> void:
	var effective_atk: int = atk_override if atk_override >= 0 else attacker.attack + attacker._atk_bonus
	var target_rows: Array = _get_target_rows(row, attacker.attack_range)
	var hit_any: bool = false
	for target_row in target_rows:
		# 前列→中列→後列の順で最初にいるユニットを攻撃（案A）
		var target_col: int = _get_frontmost_col(enemy_side, target_row)
		if target_col != -1:
			hit_any = true
			var target = board[enemy_side][target_row][target_col]
			# 障壁による軽減
			var actual_damage: int = max(0, effective_atk - target._damage_reduction)
			if actual_damage > 0:
				# ダメージイベントをキューに積む
				event_queue.push(
					EventQueue.PRIORITY_IMMEDIATE,
					attacker, target, "damage", float(actual_damage),
					{"enemy_side": enemy_side, "row": target_row, "col": target_col}
				)
				# 吸血（命中時）：回復イベントをキューに積む
				var lifesteal_pct: float = _get_lifesteal_pct(attacker.active_skill)
				if lifesteal_pct > 0.0:
					var heal: int = max(1, int(actual_damage * lifesteal_pct))
					event_queue.push(
						EventQueue.PRIORITY_IMMEDIATE,
						target, attacker, "heal", float(heal),
						{"src_side": side, "src_row": row, "src_col": col, "skill_name": "吸血"}
					)
	if not hit_any:
		# 本体ダメージイベントをキューに積む
		event_queue.push(
			EventQueue.PRIORITY_IMMEDIATE,
			attacker, null, "base_damage", float(effective_atk),
			{"side": enemy_side}
		)

func _get_lifesteal_pct(active_skill: String) -> float:
	for entry in active_skill.split(" / "):
		if "吸血" in entry and "命中時" in entry:
			if "30%" in entry: return 0.30
			if "25%" in entry: return 0.25
	return 0.0

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

func _get_frontmost_col(side: int, row: int) -> int:
	# 前列→中列→後列の順で最初にユニットがいる列を返す（-1=なし）
	var col_order: Array = [2, 1, 0] if side == 0 else [0, 1, 2]
	for c in col_order:
		if board[side][row][c] != null:
			return c
	return -1

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
	# 各ユニットのサポート効果を適用
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board[s][r][c]
				if u != null:
					_process_unit_support(s, r, c, u)

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

func _apply_regen() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board[s][r][c]
				if u != null and u._regen > 0.0:
					event_queue.push(
						EventQueue.PRIORITY_IMMEDIATE,
						null, u, "heal", float(roundi(u._regen))
					)
