# DeckManager.gd
class_name DeckManager
extends Node

var energy: float = 3.0
const ENERGY_MAX: float = 10.0
const ENERGY_REGEN: float = 1.0

var deck: Array = []

# 発動チェック間隔（初期値1秒。将来ユニット効果で変更可能）
var check_interval: float = 1.0
var _check_timer: float = 0.0

signal card_played(unit: Object)
signal energy_changed(current: float)

func _ready() -> void:
	_build_default_deck()

func _build_default_deck() -> void:
	var definitions: Array = [
		{"name": "スカウト",   "hp": 8,  "atk": 2, "interval": 1.2, "cost": 1, "col": 0},
		{"name": "ソードマン", "hp": 15, "atk": 3, "interval": 1.5, "cost": 2, "col": 0},
		{"name": "アーチャー", "hp": 10, "atk": 2, "interval": 1.0, "cost": 2, "col": 0},
		{"name": "ナイト",     "hp": 20, "atk": 4, "interval": 2.0, "cost": 3, "col": 0},
		{"name": "ヒーラー",   "hp": 12, "atk": 1, "interval": 2.0, "cost": 2, "col": 1},
		{"name": "ウィザード", "hp": 8,  "atk": 5, "interval": 2.5, "cost": 3, "col": 1},
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
		deck.append(u)
	deck.shuffle()

func process_deck(delta: float, board: Node) -> void:
	# エネルギー毎フレーム回復
	energy = min(ENERGY_MAX, energy + ENERGY_REGEN * delta)
	emit_signal("energy_changed", energy)

	# 発動チェックは check_interval ごと
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = check_interval

	if deck.is_empty():
		return
	var top = deck[0]
	if energy >= top.cost:
		energy -= top.cost
		deck.remove_at(0)
		board.place_unit(0, top)
		emit_signal("card_played", top)
		deck.append(top)

func get_next_card() -> Object:
	if deck.is_empty():
		return null
	return deck[0]
