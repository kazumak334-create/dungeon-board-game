extends RefCounted

var initial_difficulty: String = ""
var milestones: Dictionary = {}
var special_milestones: Array = []
var achieved_milestones: Array = []
var reward_selection_history: Array = []
var land_cards: Array = []
var current_battle_gold: int = 0
var milestone_window_position: Vector2 = Vector2(1050.0, 100.0)

func set_initial_difficulty(difficulty: String, economy: EconEconomy = null) -> void:
	initial_difficulty = difficulty
	var gold_delta := get_initial_gold_delta(difficulty)
	current_battle_gold = gold_delta
	if economy != null:
		economy.currency += gold_delta

func get_initial_gold_delta(difficulty: String) -> int:
	match difficulty:
		"low":
			return 100
		"high":
			return -100
		_:
			return 0

func set_milestones(value: Dictionary) -> void:
	milestones = value.duplicate(true)

func set_special_milestones(value: Array) -> void:
	special_milestones = value.duplicate(true)

func record_achieved_milestone(record: Dictionary) -> void:
	for existing in achieved_milestones:
		if str(existing.get("system", "")) == str(record.get("system", "")) \
				and str(existing.get("difficulty", "")) == str(record.get("difficulty", "")) \
				and bool(existing.get("is_special", false)) == bool(record.get("is_special", false)):
			return
	achieved_milestones.append(record.duplicate(true))

func record_reward_selection(record: Dictionary) -> void:
	reward_selection_history.append(record.duplicate(true))

func record_land_card(card: Dictionary, placed_at: Vector2i) -> void:
	var record := card.duplicate(true)
	record["placed_at"] = placed_at
	land_cards.append(record)
