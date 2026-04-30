class_name EconEconomy
extends Node


var wood: int = 0
var stone: int = 0
var sulfur: int = 0
var wheat: int = 10

# ハーベスター割り当て人数（直接人数指定）
var target_count: Dictionary = {
	EconGrid.ResourceType.WOOD: 1,
	EconGrid.ResourceType.STONE: 1,
	EconGrid.ResourceType.SULFUR: 1,
	EconGrid.ResourceType.WHEAT: 0,
}

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

func add_resource(rtype: int, amount: int = 1) -> void:
	match rtype:
		EconGrid.ResourceType.WOOD: wood += amount
		EconGrid.ResourceType.STONE: stone += amount
		EconGrid.ResourceType.SULFUR: sulfur += amount
		EconGrid.ResourceType.WHEAT: wheat += amount

func can_afford(costs: Dictionary) -> bool:
	if costs.get("wood", 0) > wood:
		return false
	if costs.get("stone", 0) > stone:
		return false
	if costs.get("sulfur", 0) > sulfur:
		return false
	if costs.get("wheat", 0) > wheat:
		return false
	return true

func spend(costs: Dictionary) -> void:
	wood -= costs.get("wood", 0)
	stone -= costs.get("stone", 0)
	sulfur -= costs.get("sulfur", 0)
	wheat -= costs.get("wheat", 0)

func add_wheat(amount: int) -> void:
	wheat += amount

# 採掘先の資源タイプを決定（target_count から割り当てリストを生成してラウンドロビン）
func get_harvest_target_for(idx: int, total: int) -> int:
	print("[EconEconomy] get_harvest_target_for idx=%d total=%d" % [idx, total])
	# target_count から割り当てリストを生成
	var assignment: Array = []
	var resource_types: Array = [
		EconGrid.ResourceType.WOOD,
		EconGrid.ResourceType.STONE,
		EconGrid.ResourceType.SULFUR,
		EconGrid.ResourceType.WHEAT,
	]
	for rtype in resource_types:
		var count: int = target_count.get(rtype, 0)
		for _i in range(count):
			assignment.append(rtype)
	# 全target_countが0の場合はWOODにフォールバック
	if assignment.is_empty():
		return EconGrid.ResourceType.WOOD
	# total を使った安全なインデックス
	var safe_total: int = total if total > 0 else 1
	return assignment[idx % min(assignment.size(), safe_total)]

func get_display_text() -> String:
	return "Wood:%d Stone:%d Sulfur:%d Wheat:%d" % [wood, stone, sulfur, wheat]
