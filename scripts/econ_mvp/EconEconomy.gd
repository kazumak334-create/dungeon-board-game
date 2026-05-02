class_name EconEconomy
extends Node

const ROLE_BUILD := 10
const ROLE_TRADE := 11

# v0.2 定数（§13.6 パラメータ化）
const BASE_POPULATION_CAP: int = 50  # 拠点効果（§7.4）
const HOUSE_POPULATION_SUPPLY: int = 3
const BARRACKS_POWER_PER_SEC: float = 0.2  # 仮値（§4.7.2）
const INITIAL_FOOD: int = 30              # §7.3
const INITIAL_CURRENCY: int = 100        # §7.3

var wood: int = 0
var stone: int = 0
var sulfur: int = 0
var wheat: int = 10
var iron: int = 0
var cotton: int = 0

# v0.2 追加フィールド（§7.3）
var resources: Dictionary = {"wood": 5, "stone": 5, "sulfur": 5, "wheat": 5, "iron": 5, "cotton": 5}
var food: int = INITIAL_FOOD
var satisfaction: int = 0     # v0.3で具体化、初期値0（§7.3）
var military_power: float = 0.0  # 兵力（§4.7.2）

# 要件定義書 req_econ_draw_hand_circulation.md §7.4
var currency: int = INITIAL_CURRENCY
var population_used: int = 0
var population_cap: int = BASE_POPULATION_CAP  # 拠点効果+50

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

# v0.2 新規：カード配置時の資源消費（§8.3）
func consume_resources(card: Dictionary) -> void:
	var cost: Dictionary = card.get("cost", {})
	for resource_key in cost.keys():
		if resources.has(resource_key):
			resources[resource_key] -= cost[resource_key]
			# 後方互換：既存フィールドとresourcesを同期
			_sync_resource_field(resource_key)
	print("[EconEconomy] consume_resources: %s" % str(cost))

# v0.2 新規：資源充足チェック（§8.3）
func can_afford_card(card: Dictionary) -> bool:
	var cost: Dictionary = card.get("cost", {})
	for resource_key in cost.keys():
		if not resources.has(resource_key):
			return false
		if resources[resource_key] < cost[resource_key]:
			return false
	return true

# v0.2 新規：兵力蓄積（§4.7.2）
func accumulate_military_power(delta: float, active_barracks_count: int) -> void:
	military_power += BARRACKS_POWER_PER_SEC * float(active_barracks_count) * delta

# v0.2 新規：resources辞書とフィールドを同期する内部メソッド
func _sync_resource_field(resource_key: String) -> void:
	match resource_key:
		"wood": wood = resources.get("wood", 0)
		"stone": stone = resources.get("stone", 0)
		"sulfur": sulfur = resources.get("sulfur", 0)
		"wheat": wheat = resources.get("wheat", 0)
		"iron": iron = resources.get("iron", 0)
		"cotton": cotton = resources.get("cotton", 0)

# v0.2 新規：初期化（§9.1）
func initialize_v0_2() -> void:
	population_cap = BASE_POPULATION_CAP
	population_used = 0
	satisfaction = 0
	military_power = 0.0
	currency = INITIAL_CURRENCY
	food = INITIAL_FOOD
	resources = {"wood": 5, "stone": 5, "sulfur": 5, "wheat": 5, "iron": 5, "cotton": 5}
	wood = 5
	stone = 5
	sulfur = 5
	wheat = 5
	iron = 5
	cotton = 5
	print("[EconEconomy] initialize_v0_2: resources=%s, currency=%d, food=%d, pop_cap=%d" % [str(resources), currency, food, population_cap])
