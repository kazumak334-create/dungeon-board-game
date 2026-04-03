# UnitData.gd
class_name UnitData
extends RefCounted

var unit_name: String = "Unknown"
var max_hp: int = 10
var current_hp: int = 10
var attack: int = 2
var attack_interval: float = 1.5
var cost: int = 2
var assigned_col: int = 0

func is_alive() -> bool:
	return current_hp > 0

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)

func clone() -> RefCounted:
	# class_name による自己参照を避けるため get_script() で生成
	var d = get_script().new()
	d.unit_name = unit_name
	d.max_hp = max_hp
	d.current_hp = max_hp
	d.attack = attack
	d.attack_interval = attack_interval
	d.cost = cost
	d.assigned_col = assigned_col
	return d
