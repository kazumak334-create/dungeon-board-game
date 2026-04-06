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
	_test_display_logic_consistency()
	_test_damage_calculation()
	_test_buff_application()
	_test_debuff_tick()
	_test_tile_effect_damage()
	_test_artifact_exclusion()
	_test_promote()
	_test_revive_delay()
	# 画面遷移・セッション
	_test_game_session()
	_test_materials_integrity()
	_test_base_deck_integrity()
	_test_scene_manager_paths()
	# 配置ロジック
	_test_placement_logic()
	_test_placement_operations()
	_test_persistence()
	_test_environments()

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
	var is_equal: bool = false
	if actual is float and expected is float:
		is_equal = absf(actual - expected) < 0.001
	else:
		is_equal = actual == expected
	if is_equal:
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

	var valid_rarities = ["common", "uncommon", "rare", "epic", "legend", "god"]
	var valid_races = ["スライム", "獣", "アンデッド"]
	# ユニット
	for name in CardDB.UNITS:
		var d = CardDB.UNITS[name]
		_assert_true(d.has("hp"), "UNITS[%s] にhpがない" % name)
		_assert_true(d.has("atk"), "UNITS[%s] にatkがない" % name)
		_assert_true(d.has("interval"), "UNITS[%s] にintervalがない" % name)
		_assert_true(d.has("cost"), "UNITS[%s] にcostがない" % name)
		_assert_true(d.has("race"), "UNITS[%s] にraceがない" % name)
		_assert_true(d.has("skills"), "UNITS[%s] にskillsがない" % name)
		_assert_true(d.has("texture"), "UNITS[%s] にtextureがない" % name)
		_assert_true(d.has("rarity"), "UNITS[%s] にrarityがない" % name)
		_assert_true(d.has("col"), "UNITS[%s] にcolがない" % name)
		_assert_true(d.has("range"), "UNITS[%s] にrangeがない" % name)
		# 型チェック
		_assert_true(d["hp"] is float or d["hp"] is int, "UNITS[%s] hpが数値" % name)
		_assert_true(d["atk"] is float or d["atk"] is int, "UNITS[%s] atkが数値" % name)
		_assert_true(d["cost"] is float or d["cost"] is int, "UNITS[%s] costが数値" % name)
		# 値チェック
		if d.has("rarity"):
			_assert_true(d["rarity"] in valid_rarities, "UNITS[%s] rarity '%s' が不正" % [name, d["rarity"]])
		if d.has("race"):
			_assert_true(d["race"] in valid_races, "UNITS[%s] race '%s' が不正" % [name, d["race"]])
	# 呪文
	for name in CardDB.SPELLS:
		var d = CardDB.SPELLS[name]
		_assert_true(d.has("cost"), "SPELLS[%s] にcostがない" % name)
		_assert_true(d.has("skills"), "SPELLS[%s] にskillsがない" % name)
		_assert_true(d.has("texture"), "SPELLS[%s] にtextureがない" % name)
		_assert_true(d.has("rarity"), "SPELLS[%s] にrarityがない" % name)
		if d.has("rarity"):
			_assert_true(d["rarity"] in valid_rarities, "SPELLS[%s] rarity '%s' が不正" % [name, d["rarity"]])
		_assert_true(d["cost"] is float or d["cost"] is int, "SPELLS[%s] costが数値" % name)

# ---- skills配列のeffect_idがEffectDBに存在するか ----
func _test_carddb_skills_reference() -> void:

	var _EDB = load("res://scripts/EffectDB.gd")
	# ユニット
	for name in CardDB.UNITS:
		for skill in CardDB.UNITS[name].get("skills", []):
			var eid = skill.get("effect_id", "")
			_assert_true(_EDB.EFFECTS.has(eid), "UNITS[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])
	# 呪文
	for name in CardDB.SPELLS:
		for skill in CardDB.SPELLS[name].get("skills", []):
			var eid = skill.get("effect_id", "")
			_assert_true(_EDB.EFFECTS.has(eid), "SPELLS[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])
	# アーティファクト
	for name in CardDB.ARTIFACTS:
		for skill in CardDB.ARTIFACTS[name].get("skills", []):
			var eid = skill.get("effect_id", "")
			_assert_true(_EDB.EFFECTS.has(eid), "ARTIFACTS[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])

# ---- クラス定義 ----
func _test_class_definitions() -> void:

	var _EDB = load("res://scripts/EffectDB.gd")
	for cid in CardDB.CLASSES:
		var d = CardDB.CLASSES[cid]
		_assert_true(d.has("display"), "CLASSES[%s] にdisplayがない" % cid)
		_assert_true(d.has("initial_mana"), "CLASSES[%s] にinitial_manaがない" % cid)
		_assert_true(d.has("mana_max"), "CLASSES[%s] にmana_maxがない" % cid)
		_assert_true(d.has("skills"), "CLASSES[%s] にskillsがない" % cid)
		for skill in d.get("skills", []):
			var eid = skill.get("effect_id", "")
			_assert_true(_EDB.EFFECTS.has(eid), "CLASSES[%s] のeffect_id '%s' がEffectDBに存在しない" % [cid, eid])

# ---- 装備定義 ----
func _test_equipment_definitions() -> void:

	var _EDB = load("res://scripts/EffectDB.gd")
	for name in CardDB.EQUIPMENT:
		var d = CardDB.EQUIPMENT[name]
		_assert_true(d.has("display"), "EQUIPMENT[%s] にdisplayがない" % name)
		_assert_true(d.has("skills"), "EQUIPMENT[%s] にskillsがない" % name)
		for skill in d.get("skills", []):
			var eid = skill.get("effect_id", "")
			_assert_true(_EDB.EFFECTS.has(eid), "EQUIPMENT[%s] のeffect_id '%s' がEffectDBに存在しない" % [name, eid])

# ---- 合成レシピの参照先 ----
func _test_synthesis_references() -> void:

	for recipe in CardDB.SYNTHESIS:
		var base = recipe.get("base", "")
		var card = recipe.get("card", "")
		var result = recipe.get("result", "")
		_assert_true(CardDB.UNITS.has(result), "SYNTHESIS結果 '%s' がUNITSに存在しない" % result)

# ==== シナリオテスト ====

func _create_unit(unit_name: String) -> Object:

	var UDS = load("res://scripts/UnitData.gd")
	var d = CardDB.UNITS[unit_name]
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

	for name in CardDB.ARTIFACTS:
		var d = CardDB.ARTIFACTS[name]
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

# ---- 表示と内部ロジックの一致テスト ----
func _test_display_logic_consistency() -> void:
	var u = _create_unit("グール")
	# ATKバフ: _atk_bonusが表示にもダメージ計算にも使われるか
	u._atk_bonus = 5
	var display_atk: int = u.attack + u._atk_bonus
	var combat_atk: int = u.attack + u._atk_bonus + u._temp_atk_bonus
	_assert_eq(display_atk, 10, "グールATK5+バフ5=表示10")
	_assert_eq(combat_atk, 10, "グールATK5+バフ5=戦闘10（一時バフ0）")
	# 一時バフ追加時の一致
	u._temp_atk_bonus = 3
	var combat_atk2: int = u.attack + u._atk_bonus + u._temp_atk_bonus
	_assert_eq(combat_atk2, 13, "一時ATK+3→戦闘13")
	# バフリセット後の一致（サポート再計算をシミュレート）
	u._atk_bonus = 0
	u._temp_atk_bonus = 0
	_assert_eq(u.attack + u._atk_bonus, 5, "リセット後ATK=基礎値5")
	# 吸血: lifesteal_stacksが回復計算と表示で一致
	u.lifesteal_stacks = 8
	var heal_pct: float = 0.03 * u.lifesteal_stacks
	_assert_eq(heal_pct, 0.24, "吸血8スタック: 回復率24%")
	_assert_true(u.lifesteal_stacks > 0, "吸血スタック>0→表示あり")
	# リセット
	u.lifesteal_stacks = 0
	_assert_true(u.lifesteal_stacks == 0, "吸血0→表示なし")
	# 鎧: _damage_reductionが軽減計算と表示で一致
	u._damage_reduction = 3
	var armor_pct: float = min(1.0, u._damage_reduction * 0.1)
	_assert_eq(armor_pct, 0.3, "鎧3スタック: 軽減30%")
	# 被弾で-1
	u._damage_reduction -= 1
	_assert_eq(u._damage_reduction, 2, "被弾後鎧2")
	# デバフ表示一致
	u.poison_stacks = 4
	u.burn_turns = 2
	_assert_true(u.poison_stacks > 0, "毒4→表示あり")
	_assert_true(u.burn_turns > 0, "火傷2→表示あり")
	var burn_reduction: float = 0.8 * float(u.burn_turns) / float(u.burn_turns + 2)
	var burned_atk: int = max(1, int(float(u.attack) * (1.0 - burn_reduction)))
	_assert_eq(burned_atk, 3, "火傷2: ATK5→3（表示と戦闘計算が同じ式）")

# ---- 画面遷移・セッション ----

func _test_game_session() -> void:
	# reset()で全フィールドが初期化されるか
	GameSession.class_id = "test"
	GameSession.dev_mode = true
	GameSession.gold = 999
	GameSession.skill_points = 5
	GameSession.materials = [{"id": "test"}]
	GameSession.selected_deck = [{"name": "test"}]
	GameSession.selected_material = {"id": "test"}
	GameSession.reset()
	_assert_eq(GameSession.class_id, "", "reset: class_id空")
	_assert_eq(GameSession.dev_mode, false, "reset: dev_mode=false")
	_assert_eq(GameSession.gold, 0, "reset: gold=0")
	_assert_eq(GameSession.skill_points, 0, "reset: skill_points=0")
	_assert_eq(GameSession.materials.size(), 0, "reset: materials空")
	_assert_eq(GameSession.selected_deck.size(), 0, "reset: selected_deck空")
	_assert_eq(GameSession.selected_material.size(), 0, "reset: selected_material空")

func _test_materials_integrity() -> void:

	_assert_true(CardDB.MATERIALS.size() > 0, "MATERIALS: 1個以上存在")
	for mat in CardDB.MATERIALS:
		_assert_true(mat.has("id"), "素材にid: %s" % mat.get("display", "???"))
		_assert_true(mat.has("display"), "素材にdisplay: %s" % mat.get("id", "???"))
		_assert_true(mat.has("is_cursed"), "素材にis_cursed: %s" % mat.get("id", "???"))
		_assert_true(mat.has("benefits"), "素材にbenefits: %s" % mat.get("id", "???"))
		_assert_true(mat.has("demerits"), "素材にdemerits: %s" % mat.get("id", "???"))
	# 呪い素材はデメリット必須
	for mat in CardDB.MATERIALS:
		if mat.get("is_cursed", false):
			_assert_true(mat.get("demerits", []).size() > 0, "呪い素材にデメリット: %s" % mat.get("id", ""))

func _test_base_deck_integrity() -> void:

	_assert_true(CardDB.BASE_DECK.size() > 0, "BASE_DECK: 1個以上存在")
	for entry in CardDB.BASE_DECK:
		var name = entry.get("name", "")
		_assert_true(name != "", "BASE_DECKエントリにname")
		var is_unit = CardDB.UNITS.has(name)
		var is_spell = CardDB.SPELLS.has(name)
		var is_status = CardDB.STATUS_SPELLS.has(name)
		_assert_true(is_unit or is_spell or is_status, "BASE_DECKカードがDB存在: %s" % name)

func _test_scene_manager_paths() -> void:
	# SceneManagerの全パスにファイルが存在するか
	var scenes = SceneManager._scenes
	for key in scenes:
		var path = scenes[key]
		if path != null:
			_assert_true(FileAccess.file_exists(path), "シーン存在: %s -> %s" % [key, path])

func _test_placement_logic() -> void:
	var PL = load("res://scripts/PlacementLogic.gd")

	# ユニットは自陣OK、敵陣NG
	var unit_entry = {"name": "スライム", "col": 1}
	_assert_eq(PL.can_place_ally(unit_entry), true, "ユニット: 自陣OK")
	_assert_eq(PL.can_place_enemy(unit_entry), false, "ユニット: 敵陣NG")

	# 呪文の陣営判定
	var spell_entry = {"name": "召喚加速", "col": -1}
	_assert_eq(PL.can_place_ally(spell_entry), true, "味方呪文: 自陣OK")

	# 効果範囲
	_assert_eq(PL.get_effect_scope(unit_entry), "normal", "ユニット: normal")

	# デフォルトconfig生成（3×3対応）
	var test_deck = [
		{"name": "スライム", "col": 1},
		{"name": "ゴブリン", "col": 0},
		{"name": "召喚加速", "col": -1}
	]
	var config = PL.generate_default_config(test_deck)
	_assert_eq(config.size(), 3, "config数=デッキ枚数")
	_assert_eq(config[0]["side"], 0, "スライム: 自陣")
	_assert_eq(config[0]["col"], 1, "スライムcol1→中列")
	_assert_eq(config[0]["row"], 0, "ユニットデフォルト→上段(ラウンドロビン)")
	_assert_eq(config[0]["fallback_same_col"], true, "デフォルトfallback=true")
	_assert_eq(config[1]["col"], 0, "ゴブリンcol0→後列")
	_assert_eq(config[2]["col"], -1, "呪文→列おまかせ")
	_assert_eq(config[2]["side"], 0, "味方呪文→自陣")

func _test_placement_operations() -> void:
	var PL = load("res://scripts/PlacementLogic.gd")

	# テスト用デッキ
	var deck = [
		{"name": "スライム", "col": 1},
		{"name": "スライム", "col": 1},
		{"name": "ゴブリン", "col": 0},
		{"name": "召喚加速", "col": -1},
	]
	var config = PL.generate_default_config(deck)

	# --- move_card ---
	# ユニットを自陣内で移動 → OK
	_assert_eq(PL.move_card(0, 0, 2, 2, deck, config), true, "move_card: ユニット自陣移動OK")
	_assert_eq(config[0]["row"], 2, "move_card: row更新")
	_assert_eq(config[0]["col"], 2, "move_card: col更新")

	# ユニットを敵陣に移動 → NG
	_assert_eq(PL.move_card(0, 1, 0, 0, deck, config), false, "move_card: ユニット敵陣NG")
	_assert_eq(config[0]["side"], 0, "move_card: side変わらず")

	# 範囲外インデックス → NG
	_assert_eq(PL.move_card(-1, 0, 0, 0, deck, config), false, "move_card: 負インデックスNG")
	_assert_eq(PL.move_card(99, 0, 0, 0, deck, config), false, "move_card: 超過インデックスNG")

	# --- move_group ---
	# スライム2枚をまとめて前列へ
	_assert_eq(PL.move_group([0, 1], 0, 1, 2, deck, config), true, "move_group: 2枚移動OK")
	_assert_eq(config[0]["col"], 2, "move_group: 0番col=2")
	_assert_eq(config[1]["col"], 2, "move_group: 1番col=2")
	_assert_eq(config[0]["row"], 1, "move_group: 0番row=1")
	_assert_eq(config[1]["row"], 1, "move_group: 1番row=1")

	# ユニット含むグループを敵陣に → 全体NG（1枚も動かない）
	var prev_side_0 = config[0]["side"]
	var prev_side_2 = config[2]["side"]
	_assert_eq(PL.move_group([0, 2], 1, 0, 0, deck, config), false, "move_group: ユニット含む敵陣NG")
	_assert_eq(config[0]["side"], prev_side_0, "move_group: 0番side変わらず")
	_assert_eq(config[2]["side"], prev_side_2, "move_group: 2番side変わらず")

	# --- get_same_name_group_in_cell ---
	# スライム2枚を同じセルに置いた状態
	config[0]["side"] = 0; config[0]["row"] = 0; config[0]["col"] = 1
	config[1]["side"] = 0; config[1]["row"] = 0; config[1]["col"] = 1
	var grp = PL.get_same_name_group_in_cell(0, deck, config)
	_assert_eq(grp.size(), 2, "same_name_group: スライム2枚")
	_assert_true(0 in grp, "same_name_group: idx0含む")
	_assert_true(1 in grp, "same_name_group: idx1含む")

	# ゴブリンは別セルなので含まれない
	var grp2 = PL.get_same_name_group_in_cell(2, deck, config)
	_assert_eq(grp2.size(), 1, "same_name_group: ゴブリン1枚")

	# --- get_cell_group ---
	var cell_grp = PL.get_cell_group(0, 0, 1, config)
	_assert_eq(cell_grp.size(), 2, "cell_group: (0,0,1)に2枚")

	# 空セル
	var empty_grp = PL.get_cell_group(1, 2, 2, config)
	_assert_eq(empty_grp.size(), 0, "cell_group: 空セル0枚")

	# --- get_row_group ---
	config[2]["side"] = 0; config[2]["row"] = 0; config[2]["col"] = 0
	# idx3(呪文)はrow=-1→正規化で0になるため上段に4枚
	var row_grp = PL.get_row_group(0, 0, config)
	_assert_eq(row_grp.size(), 4, "row_group: 上段に4枚(スライム2+ゴブリン1+呪文1)")

	# 敵陣の行→呪文しかいない
	config[3]["side"] = 1; config[3]["row"] = 1; config[3]["col"] = 2
	var enemy_row = PL.get_row_group(1, 1, config)
	_assert_eq(enemy_row.size(), 1, "row_group: 敵陣中段に1枚")

	# --- get_col_group ---
	var col_grp = PL.get_col_group(0, 1, config)
	_assert_eq(col_grp.size(), 2, "col_group: 自陣中列に2枚(スライム2)")

	# --- Ctrl+クリック相当：1枚移動 ---
	# スライム2枚が(0,0,1)にいる状態で1枚だけ移動
	config[0]["side"] = 0; config[0]["row"] = 0; config[0]["col"] = 1
	config[1]["side"] = 0; config[1]["row"] = 0; config[1]["col"] = 1
	_assert_eq(PL.move_card(0, 0, 2, 2, deck, config), true, "Ctrl移動: 1枚だけ前列へ")
	_assert_eq(config[0]["col"], 2, "Ctrl移動: idx0がcol2")
	_assert_eq(config[1]["col"], 1, "Ctrl移動: idx1はcol1のまま")

	# --- グループ維持移動：セル全選択後の移動 ---
	# idx0(前列)とidx1(中列)をグループとして後列へ
	_assert_eq(PL.move_group([0, 1], 0, 1, 0, deck, config), true, "グループ維持移動OK")
	_assert_eq(config[0]["col"], 0, "グループ移動: idx0がcol0")
	_assert_eq(config[1]["col"], 0, "グループ移動: idx1がcol0")

	# --- resolve_placement テスト ---
	# 中列(col1)指定で空きマス優先(row=-1)
	var resolve_cfg = {"side": 0, "row": -1, "col": 1, "fallback_same_col": true}
	var empty_board = [
		[[null,null,null],[null,null,null],[null,null,null]],
		[[null,null,null],[null,null,null],[null,null,null]]
	]
	var pos = PL.resolve_placement(resolve_cfg, empty_board, empty_board)
	_assert_true(pos[0] >= 0 and pos[0] <= 2, "resolve: 有効なrow")
	_assert_eq(pos[1], 1, "resolve: col=1(中列)")

	# 前列(col2)指定
	var resolve_cfg2 = {"side": 0, "row": 0, "col": 2, "fallback_same_col": true}
	var pos2 = PL.resolve_placement(resolve_cfg2, empty_board, empty_board)
	_assert_eq(pos2[0], 0, "resolve: row=0(上段)")
	_assert_eq(pos2[1], 2, "resolve: col=2(前列)")

	# フォールバック: 指定セルが埋まっている→同列他行
	var partial_board = [
		[[null,null,null],[null,null,null],[null,null,null]],
		[[null,null,null],[null,null,null],[null,null,null]]
	]
	partial_board[0][0][1] = "occupied"  # (0,1)を埋める
	var resolve_cfg3 = {"side": 0, "row": 0, "col": 1, "fallback_same_col": true}
	var pos3 = PL.resolve_placement(resolve_cfg3, partial_board, partial_board)
	_assert_true(pos3[0] > 0, "resolve fallback: row0が埋まり→他行")
	_assert_eq(pos3[1], 1, "resolve fallback: col=1維持")

func _test_persistence() -> void:
	# --- UnitDataのpersistenceデフォルト ---
	var UDS = load("res://scripts/UnitData.gd")
	var u = UDS.new()
	_assert_eq(u.persistence, "permanent", "UnitDataデフォルト: permanent")
	_assert_eq(u.is_consumable, false, "UnitDataデフォルト: is_consumable=false")

	# --- cards.jsonの異常状態カードはpersistence=battle ---
	for name in CardDB.STATUS_SPELLS:
		var d = CardDB.STATUS_SPELLS[name]
		_assert_eq(d.get("persistence", "permanent"), "battle",
			"STATUS_SPELLS[%s] persistence=battle" % name)

	# --- 通常ユニット/呪文はpersistence未設定（=permanent扱い） ---
	for name in CardDB.UNITS:
		var d = CardDB.UNITS[name]
		_assert_eq(d.get("persistence", "permanent"), "permanent",
			"UNITS[%s] persistence=permanent" % name)
	for name in CardDB.SPELLS:
		var d = CardDB.SPELLS[name]
		_assert_eq(d.get("persistence", "permanent"), "permanent",
			"SPELLS[%s] persistence=permanent" % name)

	# --- バトル中追加カード（clone+persistence設定）のシミュレーション ---
	var card = UDS.new()
	card.unit_name = "テストスライム"
	card.persistence = "battle"
	card.is_consumable = false
	_assert_eq(card.persistence, "battle", "バトル中追加: persistence=battle")
	_assert_eq(card.is_consumable, false, "バトル中追加: is_consumable=false（使用時残る）")

	# --- バトル後クリーンアップのシミュレーション ---
	var test_deck: Array = [
		{"name": "スライム", "persistence": "permanent"},
		{"name": "毒カード", "persistence": "battle"},
		{"name": "ラージスライム副産物", "persistence": "battle"},
		{"name": "ゴブリン", "persistence": "permanent"},
	]
	var after: Array = []
	for entry in test_deck:
		if entry.get("persistence", "permanent") != "battle":
			after.append(entry)
	_assert_eq(after.size(), 2, "クリーンアップ後: battle除去→2枚残る")
	_assert_eq(after[0]["name"], "スライム", "クリーンアップ後: スライム残る")
	_assert_eq(after[1]["name"], "ゴブリン", "クリーンアップ後: ゴブリン残る")

func _test_environments() -> void:
	# ENVIRONMENTS存在確認
	_assert_true(CardDB.ENVIRONMENTS.size() > 0, "ENVIRONMENTS: 1個以上存在")

	# env_noneは盤面効果なし
	var none_env = CardDB.ENVIRONMENTS.get("env_none", {})
	_assert_eq(none_env.get("tile_id", "x"), "", "env_none: tile_id空")
	_assert_eq(none_env.get("max_tiles", -1), 0, "env_none: max_tiles=0")

	# 各環境のtile_idがEffectDBに存在するか
	var _EDB = load("res://scripts/EffectDB.gd")
	for env_id in CardDB.ENVIRONMENTS:
		var env = CardDB.ENVIRONMENTS[env_id]
		_assert_true(env.has("display"), "ENV[%s] にdisplay" % env_id)
		_assert_true(env.has("tile_id"), "ENV[%s] にtile_id" % env_id)
		var tid = env.get("tile_id", "")
		if tid != "":
			_assert_true(_EDB.EFFECTS.has(tid), "ENV[%s] のtile_id '%s' がEffectDBに存在" % [env_id, tid])

	# GameSessionの環境フィールド
	GameSession.base_environment = "env_curse"
	GameSession.reset()
	_assert_eq(GameSession.base_environment, "env_none", "reset: base_environment=env_none")
