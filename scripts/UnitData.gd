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
var race: String = ""
var attack_range: String = "1行"
var support_effect: String = ""   # サポート効果（常時発動/召喚時/条件達成時）
var active_skill: String = ""     # アクティブスキル（命中時/撃破時/HP閾値時/時間経過/その他）

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
	d.race = race
	d.attack_range = attack_range
	d.support_effect = support_effect
	d.active_skill = active_skill
	return d
