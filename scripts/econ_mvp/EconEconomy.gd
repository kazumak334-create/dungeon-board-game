class_name EconEconomy
extends Node

# TRADE_POST: リソース消費時に通知するシグナル（REQUIREMENTS_CARD_EFFECTS §3.5）
signal resource_consumed(resource_type: String, amount: int)


const BASE_POPULATION_CAP: int = 100  # Sprint 3: initial population cap
const POPULATION_INITIAL: float = 50.0
const POPULATION_MIN_INITIAL: float = 10.0
const POPULATION_GROWTH_CONFIRM_UNIT: int = 10
const MOBILIZATION_BASE_RATE: float = 0.08
const HOUSE_POP_CAP_LV1: int = 20
const BARRACKS_POWER_PER_SEC: float = 0.2  # 莉ｮ蛟､・按ｧ4.7.2・・

# === 人口増加ドライバー係数（REQUIREMENTS_POPULATION_DRIVER.md §3.1） ===
# 5分後人口200〜300を目標として逆算した初期値
const POP_GROWTH_BUILDING_COEF: float = 0.00015     # 稼働建設物1件あたりの増加率
const POP_GROWTH_BUILDING_CAP: int = 20             # 稼働建設物カウント上限（暴走防止）

const POP_GROWTH_HOUSING_COEF: float = 0.00002      # 余剰人口1人あたりの増加率
const POP_GROWTH_HOUSING_CAP: float = 100.0         # 余剰人口の評価上限

const POP_GROWTH_FOOD_COEF: float = 0.00005         # 余剰食料1ポイントあたりの増加率
const POP_GROWTH_FOOD_CAP: int = 30                 # 余剰食料の評価上限

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
var population_cap: float = float(BASE_POPULATION_CAP)


var population_float: float = POPULATION_INITIAL
var population_min: float = POPULATION_MIN_INITIAL
var food_value: int = INITIAL_FOOD
var satisfaction_value: float = 60.0
var satisfaction_target: float = 60.0
var satisfaction_stage: String = "satisfied"
var building_satisfaction_modifier: float = 0.0
var building_efficiency_modifier: float = 0.0  # building interval efficiency modifier
var food_shortage_count: int = 0
var growth_blocked: bool = false
var unit_count: int = 0
var _pop_history: Array[int] = []  # 5秒ごとの population_float スナップショット（直近30秒=最大6件）



var alloc_work_ratio: float = 0.30



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
	var _breakdown: Dictionary = _get_satisfaction_thought_breakdown(buildings)
	var _pop_breakdown: Dictionary = _get_population_change_breakdown()
	_pop_history.append(int(population_float))
	if _pop_history.size() > 6:
		_pop_history.pop_front()
	print("[EconEconomy] type=tick tick=%d pop=%.1f food=%d sat=%d mil=%.1f" % [_tick_index, population_float, food, satisfaction, military_power])
	print("[EconEconomy] type=satisfaction sat=%.1f target=%.1f stage=%s breakdown=%s" % [satisfaction_value, satisfaction_target, satisfaction_stage, str(_breakdown)])
	_log_population_change_event(_pop_breakdown)
	_log_satisfaction_thought_event(_breakdown)


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
			EconBuilding.BuildingType.VILLAGE:


				pass


	var mil_mod: float = get_happiness_military_modifier()
	for b in buildings:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.BARRACKS:
			continue

		var lv: int = b.fusion_rank
		var base_gain: int = lv + 1  # Lv1=+2, Lv2=+3, Lv3=+4
		var actual_gain: float = float(base_gain) * mil_mod
		military_power += actual_gain


	_consume_food_maintenance()

	# §10.1 旧 plaza_supply/pop_load 直接操作はThoughtモデルで代替済みのため削除









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
	print("[EconEconomy] type=labor_allocation_set alloc_work_ratio=%.2f" % alloc_work_ratio)



func get_happiness_state() -> String:
	var s: String = get_satisfaction_stage()
	match s:
		"thriving", "satisfied": return "high"
		"uneasy": return "normal"
		"dissatisfied": return "dissatisfied"
		"declining": return "danger"
	return "normal"


func get_satisfaction_stage() -> String:
	# §10.3: 4段階境界値（REQUIREMENTS_SPRINT_8.md §10.3）
	if satisfaction_value < 25.0:
		return "declining"
	elif satisfaction_value < 50.0:
		return "dissatisfied"
	elif satisfaction_value < 80.0:
		return "satisfied"
	else:
		return "thriving"

func get_military_gain_modifier() -> float:
	# §10.3: 4段階倍率（REQUIREMENTS_SPRINT_8.md §10.3）
	match get_satisfaction_stage():
		"declining":
			return 0.4
		"dissatisfied":
			return 0.7
		"satisfied":
			return 1.0
		"thriving":
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
	# 建物効率補正（req_econ_satisfaction_effects_sprint5 §1・§2）
	# decline=-0.30 / dissatisfied=-0.10 / stable/uneasy=0.0 / satisfied=+0.05 / prosperity/thriving=+0.10
	var target_stage: String = stage if stage != "" else get_satisfaction_stage()
	match target_stage:
		"declining", "decline":
			return -0.30
		"dissatisfied":
			return -0.10
		"uneasy", "stable":
			return 0.0
		"satisfied":
			return 0.05
		"thriving", "prosperity":
			return 0.10
		_:
			return 0.0


func get_display_population() -> int:
	return max(1, int(floor(population_float)))

func get_food_value() -> int:
	return food_value

func get_unit_count() -> int:
	return unit_count

func get_satisfaction_thought_breakdown() -> Dictionary:
	return _get_satisfaction_thought_breakdown(buildings)

func get_satisfaction_slope_breakdown() -> Dictionary:  # 後方互換エイリアス
	return get_satisfaction_thought_breakdown()

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


func _count_adjacent_buildings(plaza: EconBuilding, all_buildings: Array) -> int:
	# §10.2.1: 全完成建物を対象（HOUSE限定でない）
	var count: int = 0
	for b in all_buildings:
		if not b.is_alive or not b.is_built:
			continue
		var dist: int = _hex_distance(plaza.grid_pos, b.grid_pos)
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
	var key: String = ""
	match rtype:
		EconGrid.ResourceType.WOOD: key = "wood"
		EconGrid.ResourceType.STONE: key = "stone"
		EconGrid.ResourceType.RESIN: key = "resin"
		EconGrid.ResourceType.WHEAT: key = "wheat"
		EconGrid.ResourceType.IRON: key = "iron"
		EconGrid.ResourceType.COTTON: key = "cotton"
	if key != "" and resources.has(key):
		resources[key] += amount
		_sync_resource_field(key)

func has_special_resource(key: String) -> bool:
	return bool(special_resources.get(key, false))

func set_special_resource(key: String, owned: bool) -> void:
	special_resources[key] = owned

func add_wheat(amount: int) -> void:
	wheat += amount
	resources["wheat"] += amount

func add_food(amount: int) -> void:
	food_value += amount
	food = food_value
	resources["food"] = food_value

func _get_maintenance_food_cost() -> int:
	return max(1, int(ceil(population_float / 3.0)))

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
	else:
		var consumed: int = food_value
		food_value = 0
		_sync_food_value()
		food_shortage_count += 1
		print("[EconEconomy] type=food_shortage consumed=%d shortage_count=%d" % [consumed, food_shortage_count])



func get_display_text() -> String:
	return "Wood:%d Stone:%d Resin:%d Wheat:%d Iron:%d Cotton:%d" % [wood, stone, resin, wheat, iron, cotton]


func consume_resources(card: Dictionary) -> void:
	var cost: Dictionary = card.get("cost", {})
	for resource_key in cost.keys():
		if resources.has(resource_key):
			resources[resource_key] -= cost[resource_key]

			_sync_resource_field(resource_key)
	print("[EconEconomy] type=consume_resources cost=%s" % str(cost))

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
	print("[EconEconomy] type=consume_resource resource=%s amount=-%d remaining=%d" % [resource_type, amount, resources[resource_type]])
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
		var lv_bonus: Array = [HOUSE_POP_CAP_LV1, HOUSE_POP_CAP_LV1 + 5, HOUSE_POP_CAP_LV1 + 10]  # Lv1=20, Lv2=25, Lv3=30
		var rank: int = clampi(b.fusion_rank - 1, 0, 2)
		cap += lv_bonus[rank]
	return cap


func initialize_v0_2() -> void:

	population_cap = calculate_population_cap()
	satisfaction = 60
	military_power = 0.0
	currency = INITIAL_CURRENCY
	food = INITIAL_FOOD
	resources = {"wood": 30, "stone": 30, "resin": 5, "food": INITIAL_FOOD, "wheat": INITIAL_FOOD, "iron": 5, "cotton": 5}
	special_resources = {"sulfur": false}
	wood = 30
	stone = 30
	resin = 5
	wheat = INITIAL_FOOD
	food = INITIAL_FOOD
	iron = 5
	cotton = 5
	print("[EconEconomy] type=initialize_v0_2 resources=%s currency=%d food=%d pop_cap=%d" % [str(resources), currency, food, population_cap])

	population_float = POPULATION_INITIAL
	food_value = INITIAL_FOOD
	satisfaction_value = 60.0
	satisfaction_target = 60.0
	satisfaction_stage = "satisfied"
	building_satisfaction_modifier = 0.0
	building_efficiency_modifier = 0.0
	food_shortage_count = 0
	growth_blocked = false
	unit_count = 0
	_pop_history.clear()

	print("[EconEconomy] type=city_status_init pop=%.2f food=%d sat=%.1f stage=%s" % [population_float, food_value, satisfaction_value, get_satisfaction_stage()])
	print("[EconEconomy] type=satisfaction_system_init status=complete")

# 稼働建設物数を算出（REQUIREMENTS_POPULATION_DRIVER.md §4.1）
# 完成済み・存在中・稼働中（資源/人手不足で停止していない）建物のみカウント
func _count_active_buildings() -> int:
	var count: int = 0
	for b in buildings:
		if b == null:
			continue
		if not b.is_alive:
			continue
		if not b.is_built:
			continue
		if not b.is_operating:
			continue
		count += 1
	return count

# === Sprint 3: Population system ===
# 人口増加ドライバー基盤（REQUIREMENTS_POPULATION_DRIVER.md §4.2）
func _calculate_population_growth_rate() -> float:
	if population_float >= float(population_cap):
		return 0.0
	if growth_blocked:
		return 0.0

	# 基礎人口増加（既存の満足度ステージ補正を継承）
	var food_bonus: float = 0.0005 if food_value >= 30 else 0.0
	var base_growth: float = 0.0
	match get_satisfaction_stage():
		"declining", "decline", "dissatisfied":
			return 0.0
		"uneasy", "stable":
			base_growth = 0.0006 + food_bonus
		"satisfied":
			base_growth = 0.0010 + food_bonus
		"thriving", "prosperity":
			base_growth = 0.0015 + food_bonus
		_:
			return 0.0

	# 稼働建設物数補正（上限あり）
	var active_count: int = mini(_count_active_buildings(), POP_GROWTH_BUILDING_CAP)
	var active_building_bonus: float = float(active_count) * POP_GROWTH_BUILDING_COEF

	# 余剰人口数補正（上限あり）
	var housing_margin: float = max(0.0, float(population_cap) - population_float)
	housing_margin = min(housing_margin, POP_GROWTH_HOUSING_CAP)
	var housing_margin_bonus: float = housing_margin * POP_GROWTH_HOUSING_COEF

	# 余剰食料値補正（上限あり）
	var food_surplus: int = max(0, food_value - _get_maintenance_food_cost())
	food_surplus = mini(food_surplus, POP_GROWTH_FOOD_CAP)
	var food_surplus_bonus: float = float(food_surplus) * POP_GROWTH_FOOD_COEF

	return base_growth + active_building_bonus + housing_margin_bonus + food_surplus_bonus

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
	return (int(floor(current_population / float(POPULATION_GROWTH_CONFIRM_UNIT))) + 1) * POPULATION_GROWTH_CONFIRM_UNIT

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
		print("[EconEconomy] type=population_growth_confirmed population=%d food_delta=-%d" % [confirmed_population, need])
	else:
		population_float = max(population_min, float(confirmed_population) - 0.01)
		growth_blocked = true
		print("[EconEconomy] type=population_growth_blocked need_food=%d current_food=%d" % [need, food_value])

func _get_population_change_breakdown() -> Dictionary:
	var growth_rate: float = _calculate_population_growth_rate()
	var decline_rate: float = _calculate_population_decline_rate()

	# 内訳算出（ログ・デバッグ用）
	var stage: String = get_satisfaction_stage()
	var food_bonus: float = 0.0005 if food_value >= 30 else 0.0
	var base_growth: float = 0.0
	match stage:
		"uneasy", "stable":
			base_growth = 0.0006 + food_bonus
		"satisfied":
			base_growth = 0.0010 + food_bonus
		"thriving", "prosperity":
			base_growth = 0.0015 + food_bonus

	var active_count_raw: int = _count_active_buildings()
	var active_count: int = mini(active_count_raw, POP_GROWTH_BUILDING_CAP)
	var active_building_bonus: float = float(active_count) * POP_GROWTH_BUILDING_COEF

	var housing_margin_raw: float = max(0.0, float(population_cap) - population_float)
	var housing_margin: float = min(housing_margin_raw, POP_GROWTH_HOUSING_CAP)
	var housing_margin_bonus: float = housing_margin * POP_GROWTH_HOUSING_COEF

	var maintenance: int = _get_maintenance_food_cost()
	var food_surplus_raw: int = max(0, food_value - maintenance)
	var food_surplus: int = mini(food_surplus_raw, POP_GROWTH_FOOD_CAP)
	var food_surplus_bonus: float = float(food_surplus) * POP_GROWTH_FOOD_COEF

	return {
		"population": population_float,
		"growth_rate": growth_rate,
		"decline_rate": decline_rate,
		"growth_total": growth_rate,
		"decline_total": decline_rate,
		"growth_per_sec": population_float * growth_rate,
		"decline_per_sec": population_float * decline_rate,
		# ---- 新規ドライバー内訳（§4.3） ----
		"base_growth": base_growth,
		"active_building_count": active_count_raw,
		"active_building_bonus": active_building_bonus,
		"housing_margin": housing_margin_raw,
		"housing_margin_bonus": housing_margin_bonus,
		"food_maintenance_required": maintenance,
		"food_surplus": food_surplus_raw,
		"food_surplus_bonus": food_surplus_bonus,
		# ---- 既存キー（後方互換） ----
		"decline_food_shortage": 0.0008 if food_shortage_count > 0 else 0.0,
		"decline_dissatisfied": 0.0004 if get_satisfaction_stage() == "dissatisfied" else 0.0,
		"decline_declining_stage": 0.0012 if get_satisfaction_stage() in ["declining", "decline"] else 0.0,
		"stage": stage,
		"growth_blocked": growth_blocked,
		"blocked_by_food": growth_blocked,
		"food_required_for_maintain": maintenance,
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
	print("[EconEconomy] type=population_loss reason=%s loss=%.1f pop_before=%.2f pop_after=%.2f" % [reason, actual_loss, before, population_float])
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
		print("[EconEconomy] type=defense_breakthrough_population_loss skipped=true request=%d pop=%.2f" % [enemy_count, population_float])
		return
	apply_population_loss(float(loss), "defense_breakthrough")

func _apply_population_loss(reason: String, loss: int) -> void:
	var before: float = population_float
	population_float = max(population_min, population_float - float(loss))
	print("[EconEconomy] type=population_loss reason=%s loss=%d pop_before=%.2f pop_after=%.2f" % [reason, loss, before, population_float])
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


func _calculate_satisfaction_target(blds: Array) -> float:
	return _get_satisfaction_thought_breakdown(blds)["target"]


func _get_satisfaction_thought_breakdown(blds: Array) -> Dictionary:
	# §10.2: Thought内訳辞書（ログ・UI用）
	var population_int: int = int(population_float)
	var food_thought: float = 10.0 if food >= population_int else -20.0

	var house_cap: int = int(calculate_population_cap())
	var overcrowd_thought: float = -10.0 if population_int > house_cap else 0.0

	var city_load_thought: float = 0.0
	if population_int <= 99:
		city_load_thought = 5.0
	elif population_int <= 299:
		city_load_thought = 3.0
	elif population_int <= 599:
		city_load_thought = 0.0
	elif population_int <= 999:
		city_load_thought = -10.0
	else:
		city_load_thought = -15.0

	var rapid_growth_thought: float = 0.0
	if _pop_history.size() >= 6 and population_int - _pop_history[0] >= 10:
		rapid_growth_thought = -10.0

	var conscript_thought: float = 0.0
	if military_power >= 300.0:
		conscript_thought = -20.0
	elif military_power >= 200.0:
		conscript_thought = -10.0
	elif military_power >= 100.0:
		conscript_thought = -5.0

	var plaza_thought: float = 0.0
	for b in blds:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.PLAZA:
			continue
		var adj_count: int = _count_adjacent_buildings(b, blds)
		if adj_count >= 6:
			plaza_thought += 5.0
		elif adj_count >= 3:
			plaza_thought += 3.0
		else:
			plaza_thought += 1.0

	return {
		"food": food_thought,
		"overcrowd": overcrowd_thought,
		"city_load": city_load_thought,
		"rapid_growth": rapid_growth_thought,
		"conscript": conscript_thought,
		"plaza": plaza_thought,
		"target": clamp(60.0 + food_thought + overcrowd_thought + city_load_thought + rapid_growth_thought + conscript_thought + plaza_thought, 0.0, 100.0),
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
		# ---- 新規ドライバー内訳 ----
		"base_growth": float(pop_breakdown.get("base_growth", 0.0)),
		"active_building_count": int(pop_breakdown.get("active_building_count", 0)),
		"active_building_bonus": float(pop_breakdown.get("active_building_bonus", 0.0)),
		"housing_margin": float(pop_breakdown.get("housing_margin", 0.0)),
		"housing_margin_bonus": float(pop_breakdown.get("housing_margin_bonus", 0.0)),
		"food_surplus": int(pop_breakdown.get("food_surplus", 0)),
		"food_surplus_bonus": float(pop_breakdown.get("food_surplus_bonus", 0.0)),
		# ---- 既存キー ----
		"decline_total": float(pop_breakdown.get("decline_total", 0.0)),
		"decline_food_shortage": float(pop_breakdown.get("decline_food_shortage", 0.0)),
		"decline_dissatisfied": float(pop_breakdown.get("decline_dissatisfied", 0.0)),
		"decline_declining_stage": float(pop_breakdown.get("decline_declining_stage", 0.0)),
		"blocked_by_food": bool(pop_breakdown.get("blocked_by_food", false)),
	})

func _log_satisfaction_thought_event(breakdown: Dictionary) -> void:
	_log_event({
		"type": "SAT_THOUGHT",
		"time": _get_elapsed_time(),
		"satisfaction": satisfaction_value,
		"target": satisfaction_target,
		"stage": satisfaction_stage,
		"food": float(breakdown.get("food", 0.0)),
		"overcrowd": float(breakdown.get("overcrowd", 0.0)),
		"city_load": float(breakdown.get("city_load", 0.0)),
		"rapid_growth": float(breakdown.get("rapid_growth", 0.0)),
		"conscript": float(breakdown.get("conscript", 0.0)),
		"plaza": float(breakdown.get("plaza", 0.0)),
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
	# §10.1: Thoughtモデル・慣性収束（REQUIREMENTS_SPRINT_8.md §10.1）
	var old_stage: String = satisfaction_stage
	satisfaction_target = _calculate_satisfaction_target(buildings)
	# satisfaction_value は 2.0/秒で target に近づく（慣性）
	var diff: float = satisfaction_target - satisfaction_value
	var max_step: float = 2.0 * delta
	if abs(diff) <= max_step:
		satisfaction_value = satisfaction_target
	else:
		satisfaction_value += sign(diff) * max_step
	satisfaction_value = clamp(satisfaction_value, 0.0, 100.0)
	satisfaction_stage = get_satisfaction_stage()
	if old_stage != "" and old_stage != satisfaction_stage:
		log_satisfaction_stage_change(old_stage, satisfaction_stage)
	satisfaction = int(satisfaction_value)
	building_efficiency_modifier = get_building_efficiency_modifier()
