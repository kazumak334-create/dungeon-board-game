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
		for row in range(3):
			var unit = board[side][row][0]
			if unit == null:
				continue
			attack_timers[side][row][0] -= delta
			if attack_timers[side][row][0] <= 0.0:
				attack_timers[side][row][0] = unit.attack_interval
				_do_attack(side, row, unit, enemy_side, base_hp)

func _do_attack(side: int, row: int, attacker: Object, enemy_side: int, base_hp: Array) -> void:
	var target = board[enemy_side][row][0]
	if target != null:
		target.take_damage(attacker.attack)
		if not target.is_alive():
			remove_unit(enemy_side, row, 0)
	else:
		base_hp[enemy_side] = max(0, base_hp[enemy_side] - attacker.attack)
		emit_signal("base_damaged", enemy_side, attacker.attack)
