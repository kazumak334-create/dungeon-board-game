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

func process_combat(delta: float, base_hp: Array) -> void:
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
	var enemy_front_col: int = 2 if enemy_side == 0 else 0
	var target_rows: Array = _get_target_rows(row, attacker.attack_range)
	var hit_any: bool = false
	for target_row in target_rows:
		var target = board[enemy_side][target_row][enemy_front_col]
		if target != null:
			hit_any = true
			target.take_damage(attacker.attack)
			if not target.is_alive():
				remove_unit(enemy_side, target_row, enemy_front_col)
	if not hit_any:
		base_hp[enemy_side] = max(0, base_hp[enemy_side] - attacker.attack)
		emit_signal("base_damaged", enemy_side, attacker.attack)

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
