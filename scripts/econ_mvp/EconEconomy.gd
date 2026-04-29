class_name EconEconomy
extends Node


var wood: int = 0
var stone: int = 0
var sulfur: int = 0
var wheat: int = 10

# 配分比率（合計100%を目安）
var alloc_wood: int = 50
var alloc_stone: int = 30
var alloc_sulfur: int = 20
var alloc_wheat: int = 0

# 優先度（1が最優先）
var priority_wood: int = 2
var priority_stone: int = 1
var priority_sulfur: int = 3
var priority_wheat: int = 3

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

# 採掘先の資源タイプを決定（tier cap + 優先度 + alloc加重ラウンドロビン）
func get_harvest_target_for(idx: int) -> int:
	# ステップ1: 総在庫量でtier capを決定
	var total_stock: int = wood + stone + sulfur
	var tier_cap: int
	if total_stock < 10:
		tier_cap = 10
	elif total_stock < 50:
		tier_cap = 50
	elif total_stock < 150:
		tier_cap = 150
	else:
		tier_cap = 300
	var total_alloc: int = alloc_wood + alloc_stone + alloc_sulfur
	if total_alloc == 0:
		return EconGrid.ResourceType.WOOD
	# ステップ2: 各資源の個別上限を計算し、上限未満のものをcandidatesに
	var all_types: Array = [
		{"type": EconGrid.ResourceType.WOOD,   "alloc": alloc_wood,   "stock": wood,   "priority": priority_wood},
		{"type": EconGrid.ResourceType.STONE,  "alloc": alloc_stone,  "stock": stone,  "priority": priority_stone},
		{"type": EconGrid.ResourceType.SULFUR, "alloc": alloc_sulfur, "stock": sulfur, "priority": priority_sulfur},
	]
	var candidates: Array = []
	for t in all_types:
		if t["alloc"] <= 0:
			continue
		var cap_for_this: int = tier_cap * t["alloc"] / total_alloc
		if t["stock"] < cap_for_this:
			candidates.append(t)
	# ステップ3: 全資源がtier capに達した場合はalloc>0の全てを候補に
	if candidates.is_empty():
		for t in all_types:
			if t["alloc"] > 0:
				candidates.append(t)
	if candidates.is_empty():
		return EconGrid.ResourceType.WOOD
	# ステップ4: 最小priorityグループに絞る
	var min_prio: int = 999
	for t in candidates:
		if t["priority"] < min_prio:
			min_prio = t["priority"]
	var top_group: Array = []
	for t in candidates:
		if t["priority"] == min_prio:
			top_group.append(t)
	# ステップ5: alloc加重ラウンドロビン
	var total_group_alloc: int = 0
	for t in top_group:
		total_group_alloc += t["alloc"]
	if total_group_alloc == 0:
		return top_group[0]["type"]
	var slot: int = idx % total_group_alloc
	var cumulative: int = 0
	for t in top_group:
		cumulative += t["alloc"]
		if slot < cumulative:
			return t["type"]
	return top_group[0]["type"]

func get_display_text() -> String:
	return "Wood:%d Stone:%d Sulfur:%d Wheat:%d" % [wood, stone, sulfur, wheat]
