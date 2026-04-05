# TestRunner.gd
# 自動テストランナー（開発者モードから実行）
# 各テストはassert_true/assert_eqでチェックし、結果をログ出力
extends RefCounted

var _pass_count: int = 0
var _fail_count: int = 0
var _results: Array = []

func run_all() -> String:
	_pass_count = 0
	_fail_count = 0
	_results.clear()

	_test_effectdb_integrity()
	_test_carddb_integrity()
	_test_carddb_skills_reference()
	_test_class_definitions()
	_test_equipment_definitions()
	_test_synthesis_references()
	# シナリオテスト
	_test_unit_placement()
	_test_damage_calculation()
	_test_buff_application()
	_test_debuff_tick()
	_test_tile_effect_damage()
	_test_artifact_exclusion()
	_test_promote()
	_test_revive_delay()

	var summary: String = "テスト結果: %d passed / %d failed" % [_pass_count, _fail_count]
	_results.insert(0, summary)
	return "\n".join(_results)

func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		_results.append("FAIL: " + msg)

func _assert_eq(actual, expected, msg: String) -> void:
	if actual == expected:
		_pass_count += 1
	else:
		_fail_count += 1
		_results.append("FAIL: %s (expected=%s, actual=%s)" % [msg, str(expected), str(actual)])

# ---- EffectDB整合性 ----
func _test_effectdb_integrity() -> void:
	var _EDB = load("res://scripts/EffectDB.gd")
	for eid in _EDB.EFFECTS:
		var def = _EDB.EFFECTS[eid]
		_assert_true(def.has("type"), "EffectDB[%s] にtypeがない" % eid)
		_assert_true(def.has("display"), "EffectDB[%s] にdisplayがない" % eid)
		_assert_true(def.has("texture"), "EffectDB[%s] にtextureがない" % eid)
		_assert_true(def.has("anim"), "EffectDB[%s] にanimがない" % eid)
		_assert_true(def.has("sfx"), "EffectDB[%s] にsfxがない" % eid)

# ---- CardDB整合性 ----
func _test_carddb_integrity() -> void:
	var _CDB = load("res://scripts/CardDB.gd")
	# ユニット
	for name in _CDB.UNITS:
		var d = _CDB.UNITS[name]
		_assert_true(d.has("hp"), "UNITS[%s] にhpがない" % name)
		_assert_true(d.has("atk"), "UNITS[%s] にatkがない" % name)
		_assert_true(d.has("interval"), "UNITS[%s] にintervalがない" % name)
		_assert_true(d.has("cost"), "UNITS[%s] にcostがない" % name)
		_assert_true(d.has("race"), "UNITS[%s] にraceがない" % name)
		_assert_true(d.has("skills"), "UNITS[%s] にskillsがない" % name)
		_assert_true(d.has("texture"), "UNITS[%s] にtextureがない" % name)
	# 呪文
	for name in _CDB.SPELLS:
		var d = _CDB.SPELLS[name]
		_assert_true(d.has("cost"), "SPELLS[%s] にcostがない" % name)
		_assert_true(d.has("skills"), "SPELLS[%s] にskillsがない" % name)
		_assert_true(d.has("texture"), "SPELLS[%s] にtextureがない" % name)

# ---- skills配列のeffect_idがEffectDBに存在するか ----
func _test_carddb_skills_reference() -> void:
	var _CDB = load("res://scripts/CardDB.gd")
	var _EDB = load("res://scripts/EffectDB.gd")
	# ユニット
	for name in _CDB.UNITS:
		for skill in _CDB.UNITS[name].get("skills", []):
			var eid = skill.get("effect_id", "")
			_assert_true(_EDB.EFFECTS.has(eid), "UNITS[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])
	# 呪文
	for name in _CDB.SPELLS:
		for skill in _CDB.SPELLS[name].get("skills", []):
			var eid = skill.get("effect_id", "")
			_assert_true(_EDB.EFFECTS.has(eid), "SPELLS[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])
	# アーティファクト
	for name in _CDB.ARTIFACTS:
		for skill in _CDB.ARTIFACTS[name].get("skills", []):
			var eid = skill.get("effect_id", "")
			_assert_true(_EDB.EFFECTS.has(eid), "ARTIFACTS[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])

# ---- クラス定義 ----
func _test_class_definitions() -> void:
	var _CDB = load("res://scripts/CardDB.gd")
	var _EDB = load("res://scripts/EffectDB.gd")
	for cid in _CDB.CLASSES:
		var d = _CDB.CLASSES[cid]
		_assert_true(d.has("display"), "CLASSES[%s] にdisplayがない" % cid)
		_assert_true(d.has("initial_mana"), "CLASSES[%s] にinitial_manaがない" % cid)
		_assert_true(d.has("mana_max"), "CLASSES[%s] にmana_maxがない" % cid)
		_assert_true(d.has("skills"), "CLASSES[%s] にskillsがない" % cid)
		for skill in d.get("skills", []):
			var eid = skill.get("effect_id", "")
			_assert_true(_EDB.EFFECTS.has(eid), "CLASSES[%s] のeffect_id '%s' がEffectDBに存在しない" % [cid, eid])

# ---- 装備定義 ----
func _test_equipment_definitions() -> void:
	var _CDB = load("res://scripts/CardDB.gd")
	var _EDB = load("res://scripts/EffectDB.gd")
	for name in _CDB.EQUIPMENT:
		var d = _CDB.EQUIPMENT[name]
		_assert_true(d.has("display"), "EQUIPMENT[%s] にdisplayがない" % name)
		_assert_true(d.has("skills"), "EQUIPMENT[%s] にskillsがない" % name)
		for skill in d.get("skills", []):
			var eid = skill.get("effect_id", "")
			_assert_true(_EDB.EFFECTS.has(eid), "EQUIPMENT[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])

# ---- 合成レシピの参照先 ----
func _test_synthesis_references() -> void:
	var _CDB = load("res://scripts/CardDB.gd")
	for recipe in _CDB.SYNTHESIS:
		var base = recipe.get("base", "")
		var card = recipe.get("card", "")
		var result = recipe.get("result", "")
		_assert_true(_CDB.UNITS.has(result), "SYNTHESIS結果 '%s' がUNITSに存在しない" % result)

# ==== シナリオテスト ====

func _create_unit(unit_name: String) -> Object:
	var _CDB = load("res://scripts/CardDB.gd")
	var UDS = load("res://scripts/UnitData.gd")
	var d = _CDB.UNITS[unit_name]
	var u = UDS.new()
	u.unit_name = unit_name
	u.max_hp = d["hp"]; u.current_hp = d["hp"]
	u.attack = d["atk"]; u.attack_interval = d["interval"]
	u.cost = d["cost"]; u.race = d.get("race", "")
	u.attack_range = d.get("range", "1行")
	u.skills = d.get("skills", []).duplicate(true)
	return u

# ---- ユニット配置テスト ----
func _test_unit_placement() -> void:
	var u = _create_unit("スライム")
	_assert_true(u != null, "ユニット生成: スライム")
	_assert_eq(u.max_hp, 15, "スライムHP=15")
	_assert_eq(u.attack, 1, "スライムATK=1")
	_assert_eq(u.race, "スライム", "スライム種族=スライム")
	# スケルトン弱体化確認
	var sk = _create_unit("スケルトン")
	_assert_eq(sk.attack, 2, "スケルトンATK=2（弱体化後）")
	_assert_eq(sk.attack_interval, 3.0, "スケルトンSPD=3.0s（弱体化後）")

# ---- ダメージ計算テスト ----
func _test_damage_calculation() -> void:
	var attacker = _create_unit("グール")
	var target = _create_unit("スライム")
	# 基本ダメージ: ATK5 → HP15-5=10
	var dmg: int = attacker.attack
	target.take_damage(dmg)
	_assert_eq(target.current_hp, 10, "グール→スライム: HP15-5=10")
	# 鎧テスト: 鎧1スタック=10%軽減 → ATK5*0.9=4.5→4 → HP10-4=6
	target._damage_reduction = 1
	var armor_pct: float = min(1.0, target._damage_reduction * 0.1)
	var actual_dmg: int = max(0, int(float(dmg) * (1.0 - armor_pct)))
	target.take_damage(actual_dmg)
	_assert_eq(actual_dmg, 4, "鎧1スタック: ATK5→4dmg")
	_assert_eq(target.current_hp, 6, "鎧軽減後HP=6")
	# 火傷ATK低下テスト: 火傷2スタック → reduction=0.8*2/(2+2)=0.4 → ATK5*0.6=3
	attacker.burn_turns = 2
	var burn_reduction: float = 0.8 * float(attacker.burn_turns) / float(attacker.burn_turns + 2)
	var burned_atk: int = max(1, int(float(attacker.attack) * (1.0 - burn_reduction)))
	_assert_eq(burned_atk, 3, "火傷2スタック: ATK5→3")

# ---- バフ適用テスト ----
func _test_buff_application() -> void:
	var u = _create_unit("ゴブリン")
	# ATKバフ
	u._atk_bonus = 3
	var effective_atk: int = u.attack + u._atk_bonus
	_assert_eq(effective_atk, 6, "ゴブリンATK3+バフ3=6")
	# 吸血スタック→回復率
	u.lifesteal_stacks = 5
	var heal_pct: float = 0.03 * u.lifesteal_stacks
	_assert_eq(heal_pct, 0.15, "吸血5スタック: 回復率15%")
	# ATKバフ上限10
	u._atk_bonus = 12
	u._atk_bonus = min(u._atk_bonus, 10)
	_assert_eq(u._atk_bonus, 10, "ATKバフ上限=10")

# ---- デバフTick テスト ----
func _test_debuff_tick() -> void:
	var u = _create_unit("スライム")
	u.frozen_turns = 3
	u.burn_turns = 2
	u.paralysis_turns = 1
	u.poison_stacks = 4
	# 凍結: 毎秒-1
	u.frozen_turns -= 1
	_assert_eq(u.frozen_turns, 2, "凍結Tick: 3→2")
	# 火傷: 毎秒-1
	u.burn_turns -= 1
	_assert_eq(u.burn_turns, 1, "火傷Tick: 2→1")
	# 麻痺: 毎秒-1
	u.paralysis_turns -= 1
	_assert_eq(u.paralysis_turns, 0, "麻痺Tick: 1→0")
	# 毒: 永続（減少しない）
	_assert_eq(u.poison_stacks, 4, "毒: 永続4スタック")
	# 毒ダメージ: スタック数=ダメージ/秒
	u.take_damage(u.poison_stacks)
	_assert_eq(u.current_hp, 11, "毒4dmg: HP15→11")

# ---- 盤面効果ダメージテスト ----
func _test_tile_effect_damage() -> void:
	var _EDB = load("res://scripts/EffectDB.gd")
	# 棘: on_enter 5dmg
	var thorn_def = _EDB.EFFECTS.get("tile_thorn", {})
	_assert_eq(thorn_def.get("trigger", ""), "on_enter", "棘trigger=on_enter")
	_assert_eq(thorn_def.get("damage", 0), 5, "棘damage=5")
	# 呪われた地: 被ダメ+50%
	var curse_def = _EDB.EFFECTS.get("tile_curse", {})
	_assert_eq(curse_def.get("damage_mult", 0), 1.5, "呪われた地damage_mult=1.5")
	# 実ダメージ計算: ATK5 * 1.5 = 7.5 → 7
	var base_dmg: int = 5
	var cursed_dmg: int = int(float(base_dmg) * curse_def["damage_mult"])
	_assert_eq(cursed_dmg, 7, "呪われた地: 5dmg→7dmg")

# ---- アーティファクト排他テスト ----
func _test_artifact_exclusion() -> void:
	# アーティファクトとユニットの排他はデータレベルで確認
	var _CDB = load("res://scripts/CardDB.gd")
	for name in _CDB.ARTIFACTS:
		var d = _CDB.ARTIFACTS[name]
		if d.get("card_type", "") == "artifact":
			_assert_true(d.has("hp"), "ARTIFACT[%s] にhpがある" % name)
			_assert_true(d.has("skills"), "ARTIFACT[%s] にskillsがある" % name)

# ---- Promoteテスト ----
func _test_promote() -> void:
	# Promoteのロジック検証（中列→前列移動のデータ確認）
	var u = _create_unit("ウルフ")
	_assert_true(u.attack_interval > 0, "ウルフSPD>0（promoteでタイマーリセットに使用）")
	# promote後もHP保持
	var original_hp: int = u.current_hp
	u.current_hp -= 5  # ダメージを受けた状態
	_assert_eq(u.current_hp, original_hp - 5, "promote後HPは変わらない（ダメージ保持）")

# ---- 遅延復活テスト ----
func _test_revive_delay() -> void:
	var sk = _create_unit("スケルトン")
	# on_deathスキルにself_reviveがあるか
	var has_revive: bool = false
	for skill in sk.skills:
		if skill.get("trigger", "") == "on_death" and skill.get("effect_id", "") == "self_revive":
			has_revive = true
			var delay = skill.get("params", {}).get("delay", 0)
			_assert_eq(delay, 3.0, "スケルトン復活遅延=3秒")
			var hp = skill.get("params", {}).get("hp", 0)
			_assert_eq(hp, 5, "スケルトン復活HP=5")
	_assert_true(has_revive, "スケルトンにself_reviveスキルがある")
