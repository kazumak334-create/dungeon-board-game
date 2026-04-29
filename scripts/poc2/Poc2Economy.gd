class_name Poc2Economy
extends Node

signal harvester_starved()  # 小麦不足でハーベスター脱落

var wood: int = 0
var stone: int = 0
var wheat: int = 10  # 初期在庫10

const WHEAT_CONSUME_INTERVAL := 5.0
const WHEAT_PER_UNIT := 0.5  # ユニット1体あたり消費
var _wheat_timer: float = 0.0

var priority: int = 0  # 0=木材優先, 1=石材優先, 2=小麦優先

func update(delta: float, total_unit_count: int) -> void:
	_wheat_timer += delta
	if _wheat_timer >= WHEAT_CONSUME_INTERVAL:
		_wheat_timer = 0.0
		var cost := int(total_unit_count * WHEAT_PER_UNIT)
		if wheat >= cost:
			wheat -= cost
		else:
			wheat = 0
			harvester_starved.emit()

func add_resource(rtype: int, amount: int = 1) -> void:
	match rtype:
		1: wood += amount   # WOOD
		2: stone += amount  # STONE
		3: wheat += amount  # WHEAT

func can_afford_wood(cost: int) -> bool:
	return wood >= cost

func spend_wood(cost: int) -> void:
	wood -= cost
