class_name EconEconomy
extends Node

# TRADE_POST: リソース消費時に通知するシグナル（REQUIREMENTS_CARD_EFFECTS §3.5）
signal resource_consumed(resource_type: String, amount: int)

const ROLE_BUILD := 10
const ROLE_TRADE := 11


const BASE_POPULATION_CAP: int = 100  # Sprint 3: initial population cap
const POPULATION_INITIAL: float = 50.0
const POPULATION_MIN_INITIAL: float = 10.0
const POPULATION_GROWTH_CONFIRM_UNIT: int = 10
const MOBILIZATION_BASE_RATE: float = 0.08
const HOUSE_POP_CAP_LV1: int = 10
const BARRACKS_POWER_PER_SEC: float = 0.2  # 莉ｮ蛟､・按ｧ4.7.2・・
const INITIAL_FOOD: int = 30
const INITIAL_CURRENCY: int = 100

var wood: int = 0
var stone: int = 0
var resin: int = 0
var wheat: int = 10
var iron: int = 0
var cotton: int = 0

# v0.2 resource fields
var resources: Dictionary = {"wood": 5, "stone": 5, "resin": 5, "food": 30, "wheat": 30, "iron": 5, "cotton": 5}
var special_resources: Dictionary = {"sulfur": false}
var food: int = INITIAL_FOOD
var satisfaction: int = 60
var military_power: float = 0.0


var currency: int = INITIAL_CURRENCY
var population_used: int = 0
var population_cap: float = float(BASE_POPULATION_CAP)


var population_float: float = POPULATION_INITIAL
var population_min: float = POPULATION_MIN_INITIAL
var food_value: int = INITIAL_FOOD
var satisfaction_value: float = 60.0
var satisfaction_slope: float = 0.0
var satisfaction_stage: String = "satisfied"
var building_satisfaction_modifier: float = 0.0
var building_efficiency_modifier: float = 0.0  # building interval efficiency modifier
var food_shortage_count: int = 0
var growth_blocked: bool = false
var unit_count: int = 0



var alloc_work_ratio: float = 0.30


var target_count: Dictionary = {
	EconGrid.ResourceType.WOOD: 1,
	EconGrid.ResourceType.STONE: 1,
	EconGrid.ResourceType.RESIN: 1,
	EconGrid.ResourceType.WHEAT: 0,
	EconGrid.ResourceType.IRON: 0,
	EconGrid.ResourceType.COTTON: 0,
	EconEconomy.ROLE_BUILD: 0,
	EconEconomy.ROLE_TRADE: 0,
}

const WHEAT_CONSUME_INTERVAL := 5.0
const WHEAT_PER_UNIT := 0.5

var _wheat_timer: float = 0.0





var _tick_timer: float = 0.0
const TICK_INTERVAL: float = 5.0
var _tick_index: int = 0


var buildings: Array = []

func update(delta: float, total_unit_count: int) -> void:
	unit_count = total_unit_count

	update_satisfaction(delta)
	update_population(delta)

	# ---- 5遘稚ick蜃ｦ逅・----
	_tick_timer += delta
	if _tick_timer < TICK_INTERVAL:
		return
	_tick_timer -= TICK_INTERVAL
	_tick_index += 1
	var _breakdown: Dictionary = _get_satisfaction_slope_breakdown(buildings)
	var _pop_breakdown: Dictionary = _get_population_change_breakdown()
	print("[EconEconomy] tick: ", _tick_index, " pop=", population_used, " food=", food, " sat=", satisfaction, " mil=", military_power)
	print("[EconEconomy] satisfaction=%.1f slope=%+.3f stage=%s breakdown=%s" % [satisfaction_value, satisfaction_slope, satisfaction_stage, str(_breakdown)])
	_log_population_change_event(_pop_breakdown)
	_log_satisfaction_slope_event(_breakdown)


	for b in buildings:
		if not b.is_alive or not b.is_built:
			continue
		var lv: int = b.fusion_rank
		var lv_bonus: float = 1.0 + (lv - 1) * 0.25  # Lv1=1.0, Lv2=1.25, Lv3=1.5
		match b.building_type:
			# SAWMILL/MINE は EconBuilding._update_sawmill/_update_mine() でタイマー駆動（§5.7）
			EconBuilding.BuildingType.WORKSHOP:
				var gain: int = roundi(1.0 * lv_bonus)
				resin += gain
				resources["resin"] = resin
				print("[EconEconomy] WORKSHOP Lv%d resin +%d" % [lv, gain])
			EconBuilding.BuildingType.VILLAGE:


				pass


	var mil_mod: float = get_happiness_military_modifier()
	for b in buildings:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.BARRACKS:
			continue

		if population_used < 1:
			print("[EconEconomy] BARRACKS skipped: insufficient operation labor pop_used=%d" % population_used)
			continue
		var lv: int = b.fusion_rank
		var base_gain: int = lv + 1  # Lv1=+2, Lv2=+3, Lv3=+4
		var actual_gain: float = float(base_gain) * mil_mod
		military_power += actual_gain
		print("[EconEconomy] BARRACKS Lv%d military +%.1f (mil_mod=%.2f)" % [lv, actual_gain, mil_mod])


	_consume_food_maintenance()



	var plaza_supply: int = 0
	for b in buildings:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.PLAZA:
			continue
		var lv: int = b.fusion_rank  # Lv1=+1, Lv2=+2, Lv3=+3
		var base_supply: int = lv

		var adj_houses: int = _count_adjacent_houses(b, buildings)
		plaza_supply += base_supply + adj_houses
		print("[EconEconomy] PLAZA Lv%d happiness_supply+%d adjacent_houses=%d" % [lv, base_supply + adj_houses, adj_houses])


	var pop_load: int = population_used / 10


	satisfaction += plaza_supply - pop_load
	satisfaction = clampi(satisfaction, 0, 100)
	print("[EconEconomy] happiness update plaza_supply=+%d pop_load=-%d sat=%d state=%s" % [plaza_supply, pop_load, satisfaction, get_happiness_state()])

	# ---- Step 5: 髦ｲ陦帶侠轤ｹ蝗槫ｾｩ・按ｧ6.2-5・・---





	population_used = get_working_population()
	print("[EconEconomy] labor allocation updated alloc_work_ratio=%.2f working=%d building=%d cap=%d" % [alloc_work_ratio, get_working_population(), get_building_population(), population_cap])


func get_working_population() -> int:
	return int(population_cap * (1.0 - alloc_work_ratio))


func get_building_population() -> int:
	return int(population_cap * alloc_work_ratio)

func get_total_labor() -> int:
	return int(floor(get_display_population() * 0.20))

func get_operation_labor() -> int:
	return int(floor(float(get_total_labor()) * (1.0 - alloc_work_ratio)))

func get_work_labor() -> int:
	return get_total_labor() - get_operation_labor()


func snap_alloc_ratio(target_ratio: float) -> float:
	var snap_values: Array = []
	for i in range(0, 11):
		snap_values.append(float(i) * 0.1)
	var closest: float = snap_values[0]
	var min_diff: float = abs(target_ratio - closest)
	for snap_val in snap_values:
		var diff: float = abs(target_ratio - snap_val)
		if diff < min_diff:
			min_diff = diff
			closest = snap_val
	return closest



func set_alloc_work_ratio(ratio: float) -> void:
	alloc_work_ratio = snap_alloc_ratio(ratio)
	print("[EconEconomy] alloc_ratio: %.2f working: %d building: %d" % [alloc_work_ratio, get_working_population(), get_building_population()])



func get_happiness_state() -> String:
	var s: String = get_satisfaction_stage()
	match s:
		"thriving", "satisfied": return "high"
		"uneasy": return "normal"
		"dissatisfied": return "dissatisfied"
		"declining": return "danger"
	return "normal"


func get_satisfaction_stage() -> String:
	"""Return the satisfaction stage from the current satisfaction value."""
	if satisfaction_value < 20.0:
		return "declining"
	elif satisfaction_value < 40.0:
		return "dissatisfied"
	elif satisfaction_value < 60.0:
		return "uneasy"
	elif satisfaction_value < 80.0:
		return "satisfied"
	else:
		return "thriving"

func get_military_gain_modifier() -> float:
	match get_satisfaction_stage():
		"declining", "decline":
			return 0.7
		"dissatisfied":
			return 0.8
		"uneasy", "stable":
			return 1.0
		"satisfied":
			return 1.1
		"thriving", "prosperity":
			return 1.2
		_:
			return 1.0

func get_military_effect_modifier() -> float:
	match get_satisfaction_stage():
		"declining", "decline":
			return 0.8
		"dissatisfied":
			return 0.9
		"uneasy", "stable", "satisfied":
			return 1.0
		"thriving", "prosperity":
			return 1.1
		_:
			return 1.0

func get_building_efficiency_modifier(stage: String = "") -> float:
	var target_stage: String = stage if stage != "" else get_satisfaction_stage()
	match target_stage:
		"declining", "decline":
			return -0.10
		"dissatisfied":
			return -0.05
		"uneasy", "stable":
			return 0.0
		"satisfied":
			return 0.05
		"thriving", "prosperity":
			return 0.30
		_:
			return 0.0


func get_display_population() -> int:
	return max(1, int(floor(population_float)))

func get_food_value() -> int:
	return food_value

func get_military_units() -> int:
	return int(floor(military_power))

func get_soldiers_count() -> int:
	return int(floor(military_power / 5.0))

func get_soldier_count() -> int:
	return get_soldiers_count()

func get_unit_count() -> int:
	return unit_count

func get_satisfaction_slope_breakdown() -> Dictionary:
	return _get_satisfaction_slope_breakdown(buildings)

func get_population_growth_rate() -> float:
	return _calculate_population_growth_rate()

func get_next_population_milestone() -> int:
	return _get_next_confirmed_population(population_float)

func get_population_milestone_food_cost(confirmed_population: int) -> int:
	return _get_population_growth_food_cost(confirmed_population)

func get_maintenance_food_cost() -> int:
	return _get_maintenance_food_cost()

func log_population_milestone(old_pop: int, new_pop: int) -> void:
	_log_event({
		"type": "POP_MILESTONE",
		"time": _get_elapsed_time(),
		"old_population": old_pop,
		"new_population": new_pop,
		"population": population_float,
	})

func log_satisfaction_stage_change(old_stage: String, new_stage: String) -> void:
	_log_event({
		"type": "SAT_STAGE_CHANGE",
		"time": _get_elapsed_time(),
		"old_stage": old_stage,
		"new_stage": new_stage,
		"satisfaction": satisfaction_value,
	})



func _count_adjacent_houses(plaza: EconBuilding, all_buildings: Array) -> int:
	var count: int = 0
	for b in all_buildings:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.HOUSE:
			continue

		var pos_plaza: Vector2i = plaza.grid_pos
		var pos_house: Vector2i = b.grid_pos
		var dist: int = _hex_distance(pos_plaza, pos_house)
		if dist == 1:
			count += 1
	return count


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ax := a.x - (a.y - (a.y & 1)) / 2
	var az := a.y
	var ay := -ax - az
	var bx := b.x - (b.y - (b.y & 1)) / 2
	var bz := b.y
	var by_ := -bx - bz
	return maxi(maxi(absi(ax - bx), absi(ay - by_)), absi(az - bz))


# "high"/"normal": 1.0 / "dissatisfied": 0.9 / "danger": 0.75
func get_happiness_production_modifier() -> float:
	push_warning("[EconEconomy] get_happiness_production_modifier is deprecated. Use building interval efficiency instead.")
	return 1.0 + get_building_efficiency_modifier()


# "high": 1.1 / "normal"/"dissatisfied": 1.0 / "danger": 0.8
func get_happiness_military_modifier() -> float:
	return get_military_gain_modifier()

func add_resource(rtype: int, amount: int = 1) -> void:
	match rtype:
		EconGrid.ResourceType.WOOD: wood += amount
		EconGrid.ResourceType.STONE: stone += amount
		EconGrid.ResourceType.RESIN:
			resin += amount
			resources["resin"] = resin
		EconGrid.ResourceType.WHEAT: wheat += amount
		EconGrid.ResourceType.IRON: iron += amount
		EconGrid.ResourceType.COTTON: cotton += amount

func can_afford(costs: Dictionary) -> bool:
	if costs.has("sulfur"):
		push_warning("[EconEconomy] stackable sulfur cost is deprecated. Use resin or special_resources.")
		return false
	if costs.get("wood", 0) > wood:
		return false
	if costs.get("stone", 0) > stone:
		return false
	if costs.get("resin", 0) > resin:
		return false
	if costs.get("wheat", 0) > wheat:
		return false
	return true

func spend(costs: Dictionary) -> void:
	wood -= costs.get("wood", 0)
	stone -= costs.get("stone", 0)
	resin -= costs.get("resin", 0)
	wheat -= costs.get("wheat", 0)

func has_special_resource(key: String) -> bool:
	return bool(special_resources.get(key, false))

func set_special_resource(key: String, owned: bool) -> void:
	special_resources[key] = owned

func add_wheat(amount: int) -> void:
	wheat += amount

func add_food(amount: int) -> void:
	food_value += amount
	food = food_value
	resources["food"] = food_value
	print("[EconEconomy] food_value +%d (current: %d)" % [amount, food_value])

func _get_maintenance_food_cost() -> int:
	return max(1, int(ceil(population_float / 50.0)))

func _sync_food_value() -> void:
	food = food_value
	resources["food"] = food_value

func consume_food_for_maintenance() -> void:
	_consume_food_maintenance()

func _consume_food_maintenance() -> void:
	var maintenance_cost: int = _get_maintenance_food_cost()

	if food_value >= maintenance_cost:
		food_value -= maintenance_cost
		food_shortage_count = max(0, food_shortage_count - 1)
		_sync_food_value()
		print("[EconEconomy] food maintenance: -%d (food_value=%d, shortage=%d)" % [maintenance_cost, food_value, food_shortage_count])
	else:
		var consumed: int = food_value
		food_value = 0
		_sync_food_value()
		food_shortage_count += 1
		print("[EconEconomy] food shortage: consumed=%d shortage_count=%d" % [consumed, food_shortage_count])



func get_harvest_target_for(idx: int, total: int) -> int:

	var assignment: Array = []
	var all_keys: Array = [
		EconGrid.ResourceType.WOOD,
		EconGrid.ResourceType.STONE,
		EconGrid.ResourceType.RESIN,
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

	if assignment.is_empty():
		return EconGrid.ResourceType.WOOD

	var safe_total: int = total if total > 0 else 1
	return assignment[idx % min(assignment.size(), safe_total)]

func get_display_text() -> String:
	return "Wood:%d Stone:%d Resin:%d Wheat:%d Iron:%d Cotton:%d" % [wood, stone, resin, wheat, iron, cotton]


func consume_resources(card: Dictionary) -> void:
	var cost: Dictionary = card.get("cost", {})
	for resource_key in cost.keys():
		if resources.has(resource_key):
			resources[resource_key] -= cost[resource_key]

			_sync_resource_field(resource_key)
	print("[EconEconomy] consume_resources: %s" % str(cost))

# 単一リソース消費（REQUIREMENTS_CARD_EFFECTS §3.4 DINER用）
# String引数でリソース種別を指定、消費成功なら true を返す
# 消費成功時は resource_consumed シグナルを発行（TRADE_POST カウンター追跡用）
func consume_resource(resource_type: String, amount: int) -> bool:
	if not resources.has(resource_type):
		return false
	if resources[resource_type] < amount:
		return false
	resources[resource_type] -= amount
	_sync_resource_field(resource_type)
	print("[EconEconomy] consume_resource: %s -%d (残: %d)" % [resource_type, amount, resources[resource_type]])
	resource_consumed.emit(resource_type, amount)
	return true


func can_afford_card(card: Dictionary) -> bool:
	var cost: Dictionary = card.get("cost", {})
	for resource_key in cost.keys():
		if resource_key == "sulfur":
			push_warning("[EconEconomy] stackable sulfur card cost is deprecated: %s" % card.get("id", "?"))
			return false
		if not resources.has(resource_key):
			return false
		if resources[resource_key] < cost[resource_key]:
			return false
	return true


func accumulate_military_power(delta: float, active_barracks_count: int) -> void:
	military_power += BARRACKS_POWER_PER_SEC * float(active_barracks_count) * delta


func _sync_resource_field(resource_key: String) -> void:
	match resource_key:
		"wood": wood = resources.get("wood", 0)
		"stone": stone = resources.get("stone", 0)
		"resin": resin = resources.get("resin", 0)
		"food": food = resources.get("food", 0)
		"wheat": wheat = resources.get("wheat", 0)
		"iron": iron = resources.get("iron", 0)
		"cotton": cotton = resources.get("cotton", 0)



func calculate_population_cap() -> int:
	var cap: int = BASE_POPULATION_CAP
	for b in buildings:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.HOUSE:
			continue
		var lv_bonus: Array = [10, 15, 20]  # Lv1, Lv2, Lv3・按ｧ2.7.1・・
		var rank: int = clampi(b.fusion_rank - 1, 0, 2)
		cap += lv_bonus[rank]
	print("[EconEconomy] calculate_population_cap: ", cap)
	return cap


func initialize_v0_2() -> void:

	population_cap = calculate_population_cap()
	population_used = 0
	satisfaction = 60
	military_power = 0.0
	currency = INITIAL_CURRENCY
	food = INITIAL_FOOD
	resources = {"wood": 5, "stone": 5, "resin": 5, "food": INITIAL_FOOD, "wheat": INITIAL_FOOD, "iron": 5, "cotton": 5}
	special_resources = {"sulfur": false}
	wood = 5
	stone = 5
	resin = 5
	wheat = INITIAL_FOOD
	food = INITIAL_FOOD
	iron = 5
	cotton = 5
	print("[EconEconomy] initialize_v0_2: resources=%s, currency=%d, food=%d, pop_cap=%d" % [str(resources), currency, food, population_cap])

	population_float = POPULATION_INITIAL
	food_value = INITIAL_FOOD
	satisfaction_value = 60.0
	satisfaction_slope = 0.0
	satisfaction_stage = "satisfied"
	building_satisfaction_modifier = 0.0
	building_efficiency_modifier = 0.0
	food_shortage_count = 0
	growth_blocked = false
	unit_count = 0

	print("[EconEconomy] CityStatus init: pop=%.2f food=%d sat=%.1f stage=%s" % [population_float, food_value, satisfaction_value, get_satisfaction_stage()])
	print("[EconEconomy] 満足度システム初期化完了")

# === Sprint 3: Population system ===
func _calculate_population_growth_rate() -> float:
	if population_float >= float(population_cap):
		return 0.0
	if growth_blocked:
		return 0.0
	match get_satisfaction_stage():
		"declining", "decline", "dissatisfied":
			return 0.0
		"uneasy", "stable":
			return 0.0002
		"satisfied":
			return 0.0004
		"thriving", "prosperity":
			return 0.0006
		_:
			return 0.0

func _calculate_population_decline_rate() -> float:
	var rate: float = 0.0
	if food_shortage_count > 0:
		rate += 0.0008
	match get_satisfaction_stage():
		"declining", "decline":
			rate += 0.0012
		"dissatisfied":
			rate += 0.0004
	return rate

func _get_next_confirmed_population(current_population: float) -> int:
	return int(ceil(current_population / float(POPULATION_GROWTH_CONFIRM_UNIT))) * POPULATION_GROWTH_CONFIRM_UNIT

func _get_population_growth_food_cost(confirmed_population: int) -> int:
	var need: int = max(1, int(ceil(float(confirmed_population) / 50.0)))
	if get_satisfaction_stage() in ["thriving", "prosperity"]:
		need = max(1, need - 1)
	return need

func _try_unblock_population_growth() -> void:
	if not growth_blocked:
		return
	var confirmed_population: int = _get_next_confirmed_population(population_float)
	var need: int = _get_population_growth_food_cost(confirmed_population)
	if food_value >= need:
		growth_blocked = false

func _try_confirm_population_growth(confirmed_population: int) -> void:
	var need: int = _get_population_growth_food_cost(confirmed_population)
	if food_value >= need:
		food_value -= need
		_sync_food_value()
		var old_confirmed: int = int(floor(population_float / float(POPULATION_GROWTH_CONFIRM_UNIT))) * POPULATION_GROWTH_CONFIRM_UNIT
		population_float = min(float(confirmed_population), float(population_cap))
		growth_blocked = false
		if confirmed_population != old_confirmed:
			log_population_milestone(old_confirmed, confirmed_population)
		print("[EconEconomy] population growth confirmed: %d food-%d" % [confirmed_population, need])
	else:
		population_float = max(population_min, float(confirmed_population) - 0.01)
		growth_blocked = true
		print("[EconEconomy] population growth blocked: need_food=%d current_food=%d" % [need, food_value])

func _get_population_change_breakdown() -> Dictionary:
	var growth_rate: float = _calculate_population_growth_rate()
	var decline_rate: float = _calculate_population_decline_rate()
	return {
		"population": population_float,
		"growth_rate": growth_rate,
		"decline_rate": decline_rate,
		"growth_total": growth_rate,
		"decline_total": decline_rate,
		"growth_per_sec": population_float * growth_rate,
		"decline_per_sec": population_float * decline_rate,
		"decline_food_shortage": 0.0008 if food_shortage_count > 0 else 0.0,
		"decline_dissatisfied": 0.0004 if get_satisfaction_stage() == "dissatisfied" else 0.0,
		"decline_declining_stage": 0.0012 if get_satisfaction_stage() in ["declining", "decline"] else 0.0,
		"stage": get_satisfaction_stage(),
		"growth_blocked": growth_blocked,
		"blocked_by_food": growth_blocked,
		"food_required_for_maintain": _get_maintenance_food_cost(),
	}

func update_population(delta: float) -> void:
	_try_unblock_population_growth()

	var old_float: float = population_float
	var old_unit: int = int(floor(old_float / float(POPULATION_GROWTH_CONFIRM_UNIT)))
	var growth_rate: float = _calculate_population_growth_rate()
	var decline_rate: float = _calculate_population_decline_rate()
	var population_delta: float = old_float * (growth_rate - decline_rate) * delta
	population_float = clamp(old_float + population_delta, population_min, float(population_cap))

	var new_unit: int = int(floor(population_float / float(POPULATION_GROWTH_CONFIRM_UNIT)))
	if new_unit > old_unit:
		_try_confirm_population_growth(new_unit * POPULATION_GROWTH_CONFIRM_UNIT)

func apply_population_loss(amount: float, reason: String = "population_loss") -> void:
	if amount <= 0.0:
		return
	var before: float = population_float
	population_float = max(population_min, population_float - amount)
	var actual_loss: float = before - population_float
	print("[EconEconomy] POP_LOSS reason=%s loss=%.1f pop %.2f -> %.2f" % [reason, actual_loss, before, population_float])
	_log_pop_loss_event(reason, int(actual_loss), before, population_float)

func get_mobilization_modifier() -> float:
	match get_satisfaction_stage():
		"declining", "decline":
			return 0.50
		"dissatisfied":
			return 0.75
		"uneasy", "stable":
			return 1.00
		"satisfied":
			return 1.10
		"thriving", "prosperity":
			return 1.25
		_:
			return 1.00

func get_mobilization_rate() -> float:
	return MOBILIZATION_BASE_RATE * get_mobilization_modifier()

func get_max_chargeable_units() -> int:
	return max(0, int(floor(population_float * get_mobilization_rate())))

func apply_defense_breakthrough_loss(enemy_count: int) -> void:
	var current_population: int = int(floor(population_float))
	var loss: int = mini(maxi(enemy_count, 0), max(0, current_population - int(population_min)))
	if loss <= 0:
		print("[EconEconomy] DEFENSE_BREAKTHROUGH population loss skipped: request=%d pop=%.2f" % [enemy_count, population_float])
		return
	apply_population_loss(float(loss), "defense_breakthrough")

func _apply_population_loss(reason: String, loss: int) -> void:
	var before: float = population_float
	population_float = max(population_min, population_float - float(loss))
	print("[EconEconomy] POP_LOSS reason=%s loss=%d pop %.2f -> %.2f" % [reason, loss, before, population_float])
	_log_pop_loss_event(reason, loss, before, population_float)


func _get_population_scale_influence() -> float:
	var pop: int = int(floor(population_float))
	if pop <= 50: return 0.02
	if pop <= 100: return 0.0
	if pop <= 250: return -0.03
	if pop <= 500: return -0.06
	if pop <= 750: return -0.10
	if pop <= 1000: return -0.14
	return -0.18


func _get_population_growth_influence() -> float:
	var growth_rate: float = _calculate_population_growth_rate()
	var growth_per_sec: float = max(0.0, population_float * growth_rate)
	if growth_per_sec <= 0.0:
		return 0.0
	return growth_per_sec * -0.2


func set_building_satisfaction_modifier(modifier: float) -> void:
	building_satisfaction_modifier = modifier

func add_building_satisfaction_influence(modifier: float) -> void:
	building_satisfaction_modifier += modifier

func _get_building_satisfaction_influence(_blds: Array) -> float:
	return building_satisfaction_modifier


func _get_food_shortage_penalty() -> float:
	return float(food_shortage_count) * 0.50


func _calculate_satisfaction_slope(blds: Array) -> float:
	return (0.03
		+ _get_population_scale_influence()
		+ _get_population_growth_influence()
		+ _get_building_satisfaction_influence(blds)
		- _get_food_shortage_penalty())


func _get_satisfaction_slope_breakdown(blds: Array) -> Dictionary:
	return {
		"base": 0.03,
		"population_scale": _get_population_scale_influence(),
		"population_growth": _get_population_growth_influence(),
		"building": _get_building_satisfaction_influence(blds),
		"food_shortage_penalty": _get_food_shortage_penalty(),
		"total": _calculate_satisfaction_slope(blds),
	}

func _get_elapsed_time() -> float:
	return float(_tick_index) * TICK_INTERVAL

func _log_event(data: Dictionary) -> void:
	var log_manager: Object = get_node_or_null("/root/LogManager")
	if log_manager == null:
		var scene := get_tree().current_scene
		if scene != null:
			log_manager = scene.get("_log_manager")
	if log_manager != null and log_manager.has_method("log_event"):
		log_manager.log_event(data)

func _log_population_change_event(pop_breakdown: Dictionary) -> void:
	_log_event({
		"type": "POP_CHANGE",
		"time": _get_elapsed_time(),
		"population": population_float,
		"stage": str(pop_breakdown.get("stage", get_satisfaction_stage())),
		"growth": float(pop_breakdown.get("growth_total", 0.0)),
		"decline_total": float(pop_breakdown.get("decline_total", 0.0)),
		"decline_food_shortage": float(pop_breakdown.get("decline_food_shortage", 0.0)),
		"decline_dissatisfied": float(pop_breakdown.get("decline_dissatisfied", 0.0)),
		"decline_declining_stage": float(pop_breakdown.get("decline_declining_stage", 0.0)),
		"blocked_by_food": bool(pop_breakdown.get("blocked_by_food", false)),
	})

func _log_satisfaction_slope_event(breakdown: Dictionary) -> void:
	_log_event({
		"type": "SAT_SLOPE",
		"time": _get_elapsed_time(),
		"satisfaction": satisfaction_value,
		"stage": satisfaction_stage,
		"slope_total": float(breakdown.get("total", satisfaction_slope)),
		"base": float(breakdown.get("base", 0.0)),
		"population_scale": float(breakdown.get("population_scale", 0.0)),
		"population_growth": float(breakdown.get("population_growth", 0.0)),
		"building": float(breakdown.get("building", 0.0)),
		"food_shortage_penalty": float(breakdown.get("food_shortage_penalty", 0.0)),
	})

func _log_pop_loss_event(reason: String, loss: int, before: float, after: float) -> void:
	_log_event({
		"type": "POP_LOSS",
		"time": _get_elapsed_time(),
		"reason": reason,
		"loss": loss,
		"population_before": before,
		"population": after,
		"stage": get_satisfaction_stage(),
	})


func update_satisfaction(delta: float) -> void:
	var old_stage: String = satisfaction_stage
	satisfaction_slope = _calculate_satisfaction_slope(buildings)
	satisfaction_value = clamp(satisfaction_value + satisfaction_slope * delta, 0.0, 100.0)
	satisfaction_stage = get_satisfaction_stage()
	if old_stage != "" and old_stage != satisfaction_stage:
		log_satisfaction_stage_change(old_stage, satisfaction_stage)
	satisfaction = int(satisfaction_value)
	building_efficiency_modifier = get_building_efficiency_modifier()
