class_name EconEconomy
extends Node

const ROLE_BUILD := 10
const ROLE_TRADE := 11

var wood: int = 0
var stone: int = 0
var sulfur: int = 0
var wheat: int = 10
var iron: int = 0
var cotton: int = 0

# 要件定義書 req_econ_draw_hand_circulation.md §7.4
var currency: int = 0
var population_used: int = 0
var population_cap: int = 3  # BASE_POPULATION_CAP=3

# ハーベスター割り当て人数（直接人数指定）
var target_count: Dictionary = {
	EconGrid.ResourceType.WOOD: 1,
	EconGrid.ResourceType.STONE: 1,
	EconGrid.ResourceType.SULFUR: 1,
	EconGrid.ResourceType.WHEAT: 0,
	EconGrid.ResourceType.IRON: 0,
	EconGrid.ResourceType.COTTON: 0,
	EconEconomy.ROLE_BUILD: 0,
	EconEconomy.ROLE_TRADE: 0,
}

const WHEAT_CONSUME_INTERVAL := 5.0
const WHEAT_PER_UNIT := 0.5

var _wheat_timer: float = 0.0

func update(_delta: float, _total_unit_count: int) -> void:
	pass

func add_resource(rtype: int, amount: int = 1) -> void:
	match rtype:
		EconGrid.ResourceType.WOOD: wood += amount
		EconGrid.ResourceType.STONE: stone += amount
		EconGrid.ResourceType.SULFUR: sulfur += amount
		EconGrid.ResourceType.WHEAT: wheat += amount
		EconGrid.ResourceType.IRON: iron += amount
		EconGrid.ResourceType.COTTON: cotton += amount

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
# ROLE_BUILD / ROLE_TRADE も含めたリストから返す
func get_harvest_target_for(idx: int, total: int) -> int:
	# target_count から割り当てリストを生成（資源 + 役割）
	var assignment: Array = []
	var all_keys: Array = [
		EconGrid.ResourceType.WOOD,
		EconGrid.ResourceType.STONE,
		EconGrid.ResourceType.SULFUR,
		EconGrid.ResourceType.WHEAT,
		EconGrid.ResourceType.IRON,
		EconGrid.ResourceType.COTTON,
		EconEconomy.ROLE_BUILD,
		EconEconomy.ROLE_TRADE,
	]
	for key in all_keys:
		var count: int = target_count.get(key, 0)
		for _i in range(count):
			assignment.append(key)
	# 全target_countが0の場合はWOODにフォールバック
	if assignment.is_empty():
		return EconGrid.ResourceType.WOOD
	# total を使った安全なインデックス
	var safe_total: int = total if total > 0 else 1
	return assignment[idx % min(assignment.size(), safe_total)]

func get_display_text() -> String:
	return "Wood:%d Stone:%d Sulfur:%d Wheat:%d Iron:%d Cotton:%d" % [wood, stone, sulfur, wheat, iron, cotton]
