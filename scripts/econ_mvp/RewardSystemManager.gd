class_name RewardSystemManager
extends Node

signal immediate_reward_awarded(system: String, reward: Dictionary)
signal milestone_recorded(record: Dictionary)
signal special_milestone_added(record: Dictionary)

const SYSTEM_KEYS := ["population", "food", "satisfaction", "building", "resource", "troop", "land", "risk"]
const DIFFICULTY_RANGES := {
	"low": ["very_low", "low", "normal"],
	"normal": ["low", "normal", "high"],
	"high": ["normal", "high", "very_high"],
}
const THRESHOLDS := {
	"population": {"very_low": 10, "low": 20, "normal": 30, "high": 45, "very_high": 60},
	"food": {"very_low": 5, "low": 10, "normal": 20, "high": 35, "very_high": 50},
	"satisfaction": {"very_low": 45, "low": 60, "normal": 70, "high": 80, "very_high": 90},
	"building": {"very_low": 1, "low": 2, "normal": 4, "high": 6, "very_high": 8},
	"resource": {"very_low": 10, "low": 20, "normal": 35, "high": 55, "very_high": 80},
	"troop": {"very_low": 5, "low": 15, "normal": 30, "high": 50, "very_high": 75},
	"land": {"very_low": 1, "low": 2, "normal": 3, "high": 4, "very_high": 5},
	"risk": {"very_low": 1, "low": 2, "normal": 3, "high": 4, "very_high": 5},
}
const SYSTEM_LABELS := {
	"population": "POP",
	"food": "FOOD",
	"satisfaction": "SAT",
	"building": "BUILD",
	"resource": "RES",
	"troop": "TROOP",
	"land": "LAND",
	"risk": "RISK",
}

var milestone_tracker: Dictionary = {}
var special_milestones: Array = []
var reward_selection_history: Array = []

var session = null
var economy: EconEconomy = null
var battle: EconBattle = null
var reward_pools: Dictionary = {}

func setup(session_ref, economy_ref: EconEconomy, battle_ref: EconBattle) -> void:
	session = session_ref
	economy = economy_ref
	battle = battle_ref
	_load_reward_pools()

func generate_milestones(difficulty: String) -> void:
	var range_keys: Array = DIFFICULTY_RANGES.get(difficulty, DIFFICULTY_RANGES["normal"])
	milestone_tracker.clear()
	for system_key in SYSTEM_KEYS:
		var system_data: Dictionary = {}
		for difficulty_key in range_keys:
			system_data[difficulty_key] = {
				"threshold": int(THRESHOLDS.get(system_key, {}).get(difficulty_key, 1)),
				"current": 0,
				"achieved": false,
				"is_immediate": difficulty_key == "normal",
			}
		milestone_tracker[system_key] = system_data
	if session != null:
		session.set_milestones(milestone_tracker)

func update_progress(system: String, current_value: int) -> void:
	check_milestone_achievement(system, current_value, -1)

func check_milestone_achievement(system: String, current_value: int, threshold: int) -> void:
	if not milestone_tracker.has(system):
		return
	var system_data: Dictionary = milestone_tracker[system]
	for difficulty_key in system_data.keys():
		var milestone: Dictionary = system_data[difficulty_key]
		if threshold > 0 and int(milestone.get("threshold", 0)) != threshold:
			continue
		milestone["current"] = current_value
		if bool(milestone.get("achieved", false)):
			continue
		if current_value < int(milestone.get("threshold", 0)):
			continue
		milestone["achieved"] = true
		system_data[difficulty_key] = milestone
		var record := {
			"system": system,
			"difficulty": difficulty_key,
			"threshold": int(milestone.get("threshold", 0)),
			"value": current_value,
			"is_special": false,
		}
		if session != null:
			session.record_achieved_milestone(record)
			session.set_milestones(milestone_tracker)
		if difficulty_key == "normal":
			var reward := get_immediate_reward(system)
			_apply_immediate_reward(reward)
			immediate_reward_awarded.emit(system, reward)
		else:
			milestone_recorded.emit(record)
	_check_special_milestones(system, current_value)

func get_immediate_reward(system: String) -> Dictionary:
	match system:
		"population":
			return {"reward_type": "population", "value": 10, "label": "人口 +10"}
		"food":
			return {"reward_type": "food_value", "value": 10, "label": "食料値 +10"}
		"satisfaction":
			return {"reward_type": "satisfaction_pct", "value": 10, "label": "満足値 +10%"}
		"building":
			return {"reward_type": "construction_boost", "value": 20, "label": "建設 +20%"}
		"resource":
			return {"reward_type": "random_resource", "value": 5, "label": "資源 +5"}
		"troop":
			return {"reward_type": "troop_buff", "value": 10, "label": "兵力 +10%"}
		"land":
			return {"reward_type": "land_resource", "value": 1, "label": "土地資源発生"}
		"risk":
			return {"reward_type": "currency", "value": 100, "label": "通貨 +100G"}
		_:
			return {"reward_type": "currency", "value": 0, "label": "報酬なし"}

func offer_reward(system: String, difficulty: String) -> Array:
	if difficulty == "special":
		return offer_special_reward()
	return offer_normal_reward(system, difficulty)

func offer_normal_reward(system: String, difficulty: String) -> Array:
	var normal_pool: Dictionary = reward_pools.get("normal_milestone_rewards", {})
	var types := ["normal_building", "special_building", "policy_card"]
	return _pick_one_from_each_pool(normal_pool, types, system, difficulty, false)

func offer_special_reward() -> Array:
	var special_pool: Dictionary = reward_pools.get("special_milestone_rewards", {})
	var types := ["land_card", "great_person_card", "special_building"]
	return _pick_one_from_each_pool(special_pool, types, "special", "special", true)

func get_chest_reward() -> Dictionary:
	var rewards: Array = reward_pools.get("chest_rewards", [])
	if rewards.is_empty():
		rewards = [
			{"reward_type": "resource", "resource": "wood", "value": 5, "label": "木 +5"},
			{"reward_type": "currency", "value": 50, "label": "通貨 +50G"},
		]
	return (rewards.pick_random() as Dictionary).duplicate(true)

func acquire_chest() -> Dictionary:
	var reward := get_chest_reward()
	_apply_immediate_reward(reward)
	var special := add_special_milestone()
	return {"reward": reward, "special_milestone": special}

func add_special_milestone() -> Dictionary:
	var system_key: String = str(SYSTEM_KEYS.pick_random())
	var threshold := int(THRESHOLDS.get(system_key, {}).get("high", 3))
	var record := {
		"system": system_key,
		"difficulty": "special",
		"threshold": threshold,
		"current": 0,
		"achieved": false,
		"is_special": true,
	}
	special_milestones.append(record)
	if session != null:
		session.set_special_milestones(special_milestones)
	special_milestone_added.emit(record)
	return record

func record_reward_selection(record: Dictionary) -> void:
	reward_selection_history.append(record.duplicate(true))
	if session != null:
		session.record_reward_selection(record)

func _check_special_milestones(system: String, current_value: int) -> void:
	for i in range(special_milestones.size()):
		var milestone: Dictionary = special_milestones[i]
		if bool(milestone.get("achieved", false)):
			continue
		if str(milestone.get("system", "")) != system:
			continue
		milestone["current"] = current_value
		if current_value < int(milestone.get("threshold", 0)):
			special_milestones[i] = milestone
			continue
		milestone["achieved"] = true
		special_milestones[i] = milestone
		if session != null:
			session.record_achieved_milestone(milestone)
			session.set_special_milestones(special_milestones)
		milestone_recorded.emit(milestone)

func _apply_immediate_reward(reward: Dictionary) -> void:
	if economy == null:
		return
	var reward_type := str(reward.get("reward_type", ""))
	var value := int(reward.get("value", 0))
	match reward_type:
		"resource":
			_add_resource_by_key(str(reward.get("resource", "wood")), value)
		"random_resource":
			_add_resource_by_key(str(["wood", "stone", "wheat", "resin", "iron"].pick_random()), value)
		"food_value":
			economy.add_food(value)
		"satisfaction_pct":
			economy.satisfaction_value = clampf(economy.satisfaction_value + float(value), 0.0, 100.0)
			economy.satisfaction = int(economy.satisfaction_value)
		"construction_boost":
			if battle != null:
				battle.boost_first_construction(float(value) / 100.0)
		"troop_buff":
			economy.military_power += float(value)
		"currency":
			economy.currency += value
		"population":
			economy.population_cap += float(value)

func _add_resource_by_key(resource_key: String, amount: int) -> void:
	match resource_key:
		"wood":
			economy.wood += amount
		"stone":
			economy.stone += amount
		"wheat", "food":
			economy.wheat += amount
			economy.food += amount
			economy.food_value += amount
		"resin":
			economy.resin += amount
		"iron":
			economy.iron += amount
		"cotton":
			economy.cotton += amount
	economy.resources[resource_key] = int(economy.resources.get(resource_key, 0)) + amount

func _pick_one_from_each_pool(pool: Dictionary, types: Array, system: String, difficulty: String, is_special: bool) -> Array:
	var options: Array = []
	for card_type in types:
		var entries: Array = pool.get(card_type, [])
		if entries.is_empty():
			continue
		var entry: Dictionary = (entries.pick_random() as Dictionary).duplicate(true)
		entry["card_type"] = card_type
		entry["system"] = str(entry.get("system", system))
		entry["difficulty"] = difficulty
		entry["is_special_reward"] = is_special
		options.append(entry)
	return options

func _load_reward_pools() -> void:
	var f := FileAccess.open("res://data/cards_econ.json", FileAccess.READ)
	if f == null:
		reward_pools = {}
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		reward_pools = (parsed as Dictionary).get("reward_pools", {})
