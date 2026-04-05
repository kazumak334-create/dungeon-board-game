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
