class_name EconEconomy
extends Node

signal harvester_starved()

var wood: int = 0
var stone: int = 0
var sulfur: int = 0
var wheat: int = 10

# 配分比率（合計100%を目安）
var alloc_wood: int = 50
var alloc_stone: int = 30
var alloc_sulfur: int = 20

# 優先度（1が最優先）
var priority_wood: int = 2
var priority_stone: int = 1
var priority_sulfur: int = 3

const WHEAT_CONSUME_INTERVAL := 5.0
const WHEAT_PER_UNIT := 0.5

var _wheat_timer: float = 0.0

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
		EconGrid.ResourceType.WOOD: wood += amount
		EconGrid.ResourceType.STONE: stone += amount
		EconGrid.ResourceType.SULFUR: sulfur += amount

func can_afford(costs: Dictionary) -> bool:
	if costs.get("wood", 0) > wood:
		return false
	if costs.get("stone", 0) > stone:
		return false
	if costs.get("sulfur", 0) > sulfur:
		return false
	return true

func spend(costs: Dictionary) -> void:
	wood -= costs.get("wood", 0)
	stone -= costs.get("stone", 0)
	sulfur -= costs.get("sulfur", 0)

func add_wheat(amount: int) -> void:
	wheat += amount

# 採掘先の資源タイプを決定（優先度+配分比率・ラウンドロビン対応）
func get_harvest_target_for(idx: int) -> int:
	# alloc > 0 の資源だけ対象
	var candidates := []
	var types := [
		{"type": EconGrid.ResourceType.WOOD,   "alloc": alloc_wood,   "priority": priority_wood},
		{"type": EconGrid.ResourceType.STONE,  "alloc": alloc_stone,  "priority": priority_stone},
		{"type": EconGrid.ResourceType.SULFUR, "alloc": alloc_sulfur, "priority": priority_sulfur},
	]
	for t in types:
		if t["alloc"] > 0:
			candidates.append(t)
	if candidates.is_empty():
		return EconGrid.ResourceType.WOOD
	# 最小優先度番号を特定
	var min_prio: int = candidates[0]["priority"]
	for t in candidates:
		if t["priority"] < min_prio:
			min_prio = t["priority"]
	# 最小優先度グループを収集
	var top_group := []
	for t in candidates:
		if t["priority"] == min_prio:
			top_group.append(t)
	# ラウンドロビン
	return top_group[idx % top_group.size()]["type"]

func get_display_text() -> String:
	return "Wood:%d Stone:%d Sulfur:%d Wheat:%d" % [wood, stone, sulfur, wheat]
