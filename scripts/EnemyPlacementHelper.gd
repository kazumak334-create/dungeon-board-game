# EnemyPlacementHelper.gd
# 警戒レベルに応じた敵配置強化・エリート混入
class_name EnemyPlacementHelper
extends RefCounted

const ELITE_CHANCE_LV4: float = 0.5

# 警戒レベルに応じた敵デッキ加工
func apply_alert_modifiers(enemy_deck: Array, alert: int, act: int) -> void:
	if alert < 1:
		return

	print("[EnemyPlacementHelper] 警戒レベル %d の配置強化を適用 (Act %d)" % [alert, act])

	# Lv1+: 前列確保（配置強化は盤面配置ロジックで実現するため、ここでは何もしない）
	# ※要件定義書3-5では「デッキ加工」となっているが、実際の配置はMain.gdで行われるため
	# ※ここでは追加ユニット生成のみ実装

	# Lv4+: エリート混入
	if alert >= 4:
		var guaranteed = (alert >= 5)
		var chance_roll = randf() < ELITE_CHANCE_LV4
		if guaranteed or chance_roll:
			_inject_elite_unit(enemy_deck, act, guaranteed)

func _inject_elite_unit(enemy_deck: Array, act: int, is_guaranteed: bool) -> void:
	var act_key = str(act)
	if not CardDB.ELITE_POOLS.has(act_key):
		print("[EnemyPlacementHelper] WARNING: Act%d のELITE_POOLS未定義" % act)
		return

	var pool: Array = CardDB.ELITE_POOLS[act_key]
	if pool.is_empty():
		print("[EnemyPlacementHelper] WARNING: Act%d のELITE_POOLSが空" % act)
		return

	pool.shuffle()
	var elite_entry = pool[0]
	var elite_unit = _create_unit_from_pool_entry(elite_entry)
	if elite_unit != null:
		enemy_deck.append(elite_unit)
		GameSession.elite_injected_in_battle = true
		print("[EnemyPlacementHelper] エリート混入: %s (alert=%d, guaranteed=%s)" % [elite_unit.unit_name, GameSession.alert_level, str(is_guaranteed)])

func _create_unit_from_pool_entry(entry: Dictionary) -> Object:
	var unit_name = entry.get("name", "")
	if unit_name == "" or not CardDB.UNITS.has(unit_name):
		print("[EnemyPlacementHelper] WARNING: ユニット '%s' 未定義" % unit_name)
		return null

	var d: Dictionary = CardDB.UNITS[unit_name]
	var UnitDataScript = load("res://scripts/UnitData.gd")
	var u = UnitDataScript.new()
	u.unit_name = unit_name
	u.max_hp = d["hp"]
	u.current_hp = d["hp"]
	u.attack = d["atk"]
	u.spd = d["spd"]
	u.mana = d["mana"]
	u.assigned_col = entry.get("col", randi() % 3)  # ランダム列
	u.race = d.get("race", "")
	u.attack_range = d.get("range", "1行")
	u.support_effect = ""
	u.skills = d.get("skills", []).duplicate(true)
	return u
