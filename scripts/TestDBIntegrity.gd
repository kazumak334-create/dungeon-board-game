# TestDBIntegrity.gd
# DB整合性テスト（EffectDB/CardDB/CLASSES/EQUIPMENT/SYNTHESIS）
extends RefCounted

func run(runner: RefCounted) -> void:
	_test_effectdb_integrity(runner)
	_test_carddb_integrity(runner)
	_test_carddb_skills_reference(runner)
	_test_class_definitions(runner)
	# _test_equipment_definitions(runner)  # 装備システム廃止により無効化
	_test_synthesis_references(runner)

# ---- EffectDB整合性 ----
func _test_effectdb_integrity(r: RefCounted) -> void:
	var _EDB = load("res://scripts/EffectDB.gd")
	for eid in _EDB.EFFECTS:
		var def = _EDB.EFFECTS[eid]
		r._assert_true(def.has("type"), "EffectDB[%s] にtypeがない" % eid)
		r._assert_true(def.has("display"), "EffectDB[%s] にdisplayがない" % eid)
		r._assert_true(def.has("texture"), "EffectDB[%s] にtextureがない" % eid)
		r._assert_true(def.has("anim"), "EffectDB[%s] にanimがない" % eid)
		r._assert_true(def.has("sfx"), "EffectDB[%s] にsfxがない" % eid)

# ---- CardDB整合性 ----
func _test_carddb_integrity(r: RefCounted) -> void:
	var valid_rarities = ["common", "uncommon", "rare", "epic", "legend", "god"]
	var valid_races = ["スライム", "獣", "アンデッド"]
	# ユニット
	for name in CardDB.UNITS:
		var d = CardDB.UNITS[name]
		r._assert_true(d.has("hp"), "UNITS[%s] にhpがない" % name)
		r._assert_true(d.has("atk"), "UNITS[%s] にatkがない" % name)
		r._assert_true(d.has("spd"), "UNITS[%s] にspdがない" % name)
		r._assert_true(d.has("mana"), "UNITS[%s] にmanaがない" % name)
		r._assert_true(d.has("race"), "UNITS[%s] にraceがない" % name)
		r._assert_true(d.has("skills"), "UNITS[%s] にskillsがない" % name)
		r._assert_true(d.has("texture"), "UNITS[%s] にtextureがない" % name)
		r._assert_true(d.has("rarity"), "UNITS[%s] にrarityがない" % name)
		r._assert_true(d.has("col"), "UNITS[%s] にcolがない" % name)
		r._assert_true(d.has("range"), "UNITS[%s] にrangeがない" % name)
		# 型チェック
		r._assert_true(d["hp"] is float or d["hp"] is int, "UNITS[%s] hpが数値" % name)
		r._assert_true(d["atk"] is float or d["atk"] is int, "UNITS[%s] atkが数値" % name)
		r._assert_true(d["mana"] is float or d["mana"] is int, "UNITS[%s] costが数値" % name)
		# 値チェック
		if d.has("rarity"):
			r._assert_true(d["rarity"] in valid_rarities, "UNITS[%s] rarity '%s' が不正" % [name, d["rarity"]])
		if d.has("race"):
			r._assert_true(d["race"] in valid_races, "UNITS[%s] race '%s' が不正" % [name, d["race"]])
	# 呪文
	for name in CardDB.SPELLS:
		var d = CardDB.SPELLS[name]
		r._assert_true(d.has("mana"), "SPELLS[%s] にmanaがない" % name)
		r._assert_true(d.has("skills"), "SPELLS[%s] にskillsがない" % name)
		r._assert_true(d.has("texture"), "SPELLS[%s] にtextureがない" % name)
		r._assert_true(d.has("rarity"), "SPELLS[%s] にrarityがない" % name)
		if d.has("rarity"):
			r._assert_true(d["rarity"] in valid_rarities, "SPELLS[%s] rarity '%s' が不正" % [name, d["rarity"]])
		r._assert_true(d["mana"] is float or d["mana"] is int, "SPELLS[%s] costが数値" % name)

# ---- skills配列のeffect_idがEffectDBに存在するか ----
func _test_carddb_skills_reference(r: RefCounted) -> void:
	var _EDB = load("res://scripts/EffectDB.gd")
	# ユニット
	for name in CardDB.UNITS:
		for skill in CardDB.UNITS[name].get("skills", []):
			var eid = skill.get("effect_id", "")
			r._assert_true(_EDB.EFFECTS.has(eid), "UNITS[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])
	# 呪文
	for name in CardDB.SPELLS:
		for skill in CardDB.SPELLS[name].get("skills", []):
			var eid = skill.get("effect_id", "")
			r._assert_true(_EDB.EFFECTS.has(eid), "SPELLS[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])
	# アーティファクト
	for name in CardDB.ARTIFACTS:
		for skill in CardDB.ARTIFACTS[name].get("skills", []):
			var eid = skill.get("effect_id", "")
			r._assert_true(_EDB.EFFECTS.has(eid), "ARTIFACTS[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])

# ---- クラス定義 ----
func _test_class_definitions(r: RefCounted) -> void:
	var _EDB = load("res://scripts/EffectDB.gd")
	for cid in CardDB.CLASSES:
		var d = CardDB.CLASSES[cid]
		r._assert_true(d.has("display"), "CLASSES[%s] にdisplayがない" % cid)
		r._assert_true(d.has("initial_mana"), "CLASSES[%s] にinitial_manaがない" % cid)
		r._assert_true(d.has("mana_max"), "CLASSES[%s] にmana_maxがない" % cid)
		r._assert_true(d.has("skills"), "CLASSES[%s] にskillsがない" % cid)
		for skill in d.get("skills", []):
			var eid = skill.get("effect_id", "")
			r._assert_true(_EDB.EFFECTS.has(eid), "CLASSES[%s] のeffect_id '%s' がEffectDBに存在しない" % [cid, eid])

# ---- 装備定義 ----
func _test_equipment_definitions(r: RefCounted) -> void:
	var _EDB = load("res://scripts/EffectDB.gd")
	for name in CardDB.EQUIPMENT:
		var d = CardDB.EQUIPMENT[name]
		r._assert_true(d.has("display"), "EQUIPMENT[%s] にdisplayがない" % name)
		r._assert_true(d.has("skills"), "EQUIPMENT[%s] にskillsがない" % name)
		for skill in d.get("skills", []):
			var eid = skill.get("effect_id", "")
			r._assert_true(_EDB.EFFECTS.has(eid), "EQUIPMENT[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])

# ---- 合成レシピの参照先 ----
func _test_synthesis_references(r: RefCounted) -> void:
	for recipe in CardDB.SYNTHESIS:
		var result = recipe.get("result", "")
		r._assert_true(CardDB.UNITS.has(result), "SYNTHESIS結果 '%s' がUNITSに存在しない" % result)
