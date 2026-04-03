# EnemyAI.gd
class_name EnemyAI
extends Node

var spawn_timer: float = 3.0
const SPAWN_INTERVAL: float = 3.5

var enemy_deck: Array = []

func _ready() -> void:
	_build_enemy_deck()

func _build_enemy_deck() -> void:
	var definitions: Array = [
		{"name": "ゴブリン",   "hp": 6,  "atk": 2, "interval": 1.0, "cost": 1, "col": 0},
		{"name": "オーク",     "hp": 18, "atk": 4, "interval": 2.0, "cost": 3, "col": 0},
		{"name": "スケルトン", "hp": 8,  "atk": 2, "interval": 1.2, "cost": 2, "col": 0},
		{"name": "ウルフ",     "hp": 10, "atk": 3, "interval": 1.0, "cost": 2, "col": 0},
		{"name": "シャーマン", "hp": 10, "atk": 2, "interval": 2.0, "cost": 2, "col": 1},
	]
	var UnitDataScript = load("res://scripts/UnitData.gd")
	for d in definitions:
		var u = UnitDataScript.new()
		u.unit_name = d["name"]
		u.max_hp = d["hp"]
		u.current_hp = d["hp"]
		u.attack = d["atk"]
		u.attack_interval = d["interval"]
		u.cost = d["cost"]
		u.assigned_col = d["col"]
		enemy_deck.append(u)
	enemy_deck.shuffle()

func process_ai(delta: float, board: Node) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = SPAWN_INTERVAL
		if not enemy_deck.is_empty():
			var idx: int = randi() % enemy_deck.size()
			var unit = enemy_deck[idx]
			board.place_unit(1, unit)
