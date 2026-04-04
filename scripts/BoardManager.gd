# BoardManager.gd
class_name BoardManager
extends Node

var board: Array = []
var attack_timers: Array = []

signal unit_placed(side: int, row: int, col: int, unit: Object)
signal unit_died(side: int, row: int, col: int)
signal base_damaged(side: int, amount: int)

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
	board[side][row][col] = null
	attack_timers[side][row][col] = 0.0
	emit_signal("unit_died", side, row, col)
	_try_promote(side, row, col)

func process_combat(delta: float, base_hp: Array) -> void:
	# 前列が空なら中列を繰り上げ（毎フレーム確認）
	for side in range(2):
		var front_col: int = 2 if side == 0 else 0
		for row in range(3):
			_try_promote(side, row, front_col)

	for side in range(2):
		var enemy_side: int = 1 - side
		# 自陣の前列はcol2、敵陣の前列はcol0
		var front_col: int = 2 if side == 0 else 0
		for row in range(3):
			var unit = board[side][row][front_col]
			if unit == null:
				continue
			attack_timers[side][row][front_col] -= delta
			if attack_timers[side][row][front_col] <= 0.0:
				attack_timers[side][row][front_col] = unit.attack_interval
				_do_attack(side, row, front_col, unit, enemy_side, base_hp)

func _do_attack(side: int, row: int, col: int, attacker: Object, enemy_side: int, base_hp: Array) -> void:
	var target_rows: Array = _get_target_rows(row, attacker.attack_range)
	var hit_any: bool = false
	for target_row in target_rows:
		# 前列→中列→後列の順で最初にいるユニットを攻撃（案A）
		var target_col: int = _get_frontmost_col(enemy_side, target_row)
		if target_col != -1:
			hit_any = true
			var target = board[enemy_side][target_row][target_col]
			target.take_damage(attacker.attack)
			if not target.is_alive():
				remove_unit(enemy_side, target_row, target_col)
	if not hit_any:
		base_hp[enemy_side] = max(0, base_hp[enemy_side] - attacker.attack)
		emit_signal("base_damaged", enemy_side, attacker.attack)

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
