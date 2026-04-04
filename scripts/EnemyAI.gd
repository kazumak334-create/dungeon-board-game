# EnemyAI.gd
class_name EnemyAI
extends Node

var spawn_timer: float = 3.0
const SPAWN_INTERVAL: float = 3.5

var enemy_deck: Array = []
var enemy_discard: Array = []
var next_card: Object = null  # 次に召喚するカード（表示用に事前決定）

func _ready() -> void:
	_build_enemy_deck()
	_pick_next_card()

func _build_enemy_deck() -> void:
	var definitions: Array = [
		{"name": "ゴブリン",   "hp": 6,  "atk": 2, "interval": 1.0, "cost": 1, "col": 0, "race": "獣",         "range": "1行"},
		{"name": "オーク",     "hp": 18, "atk": 4, "interval": 2.0, "cost": 3, "col": 0, "race": "獣",         "range": "1行"},
		{"name": "スケルトン", "hp": 8,  "atk": 2, "interval": 1.2, "cost": 2, "col": 0, "race": "アンデッド", "range": "1行"},
		{"name": "ウルフ",     "hp": 10, "atk": 3, "interval": 1.0, "cost": 2, "col": 0, "race": "獣",         "range": "1行"},
		{"name": "シャーマン", "hp": 10, "atk": 2, "interval": 2.0, "cost": 2, "col": 1, "race": "獣",         "range": "1行"},
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
		u.race = d["race"]
		u.attack_range = d["range"]
		enemy_deck.append(u)
	enemy_deck.shuffle()

func _pick_next_card() -> void:
	# 山札が空なら捨て札をシャッフルして山札に戻す
	if enemy_deck.is_empty():
		if enemy_discard.is_empty():
			next_card = null
			return
		enemy_deck = enemy_discard.duplicate()
		enemy_discard.clear()
		enemy_deck.shuffle()
	next_card = enemy_deck[0]  # 山札先頭を次の召喚カードとして確定

func get_next_card() -> Object:
	return next_card

func process_ai(delta: float, board: Node) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = SPAWN_INTERVAL
		if next_card != null:
			board.place_unit(1, next_card)
			enemy_deck.remove_at(0)     # 山札から消費
			enemy_discard.append(next_card)  # 捨て札へ
		_pick_next_card()  # 次の召喚カードを事前決定
