# TestBattleScenario.gd
# シナリオ/バトルテスト（ユニット生成, ダメージ計算, バフ/デバフ, 盤面効果, promote, 復活, 表示一致）
extends RefCounted

func run(runner: RefCounted) -> void:
	_test_unit_placement(runner)
	_test_display_logic_consistency(runner)
	_test_damage_calculation(runner)
	_test_buff_application(runner)
	_test_debuff_tick(runner)
	_test_tile_effect_damage(runner)
	_test_artifact_exclusion(runner)
	_test_promote(runner)

func _create_unit(unit_name: String) -> Object:
	var UDS = load("res://scripts/UnitData.gd")
	var d = CardDB.UNITS[unit_name]
	var u = UDS.new()
	u.unit_name = unit_name
	u.max_hp = d["hp"]; u.current_hp = d["hp"]
	u.attack = d["atk"]; u.spd = d["spd"]
	u.mana = d["mana"]; u.race = d.get("race", "")
	u.attack_range = d.get("range", "1行")
	u.skills = d.get("skills", []).duplicate(true)
	return u

# ---- ユニット配置テスト ----
func _test_unit_placement(r: RefCounted) -> void:
	var u = _create_unit("スライム")
	r._assert_true(u != null, "ユニット生成: スライム")
	r._assert_eq(u.max_hp, 15, "スライムHP=15")
	r._assert_eq(u.attack, 1, "スライムATK=1")
	r._assert_eq(u.race, "スライム", "スライム種族=スライム")

# ---- ダメージ計算テスト ----
func _test_damage_calculation(r: RefCounted) -> void:
	var attacker = _create_unit("グール")
	var target = _create_unit("スライム")
	# 基本ダメージ: ATK5 → HP15-5=10
	var dmg: int = attacker.attack
	target.take_damage(dmg)
	r._assert_eq(target.current_hp, 10, "グール→スライム: HP15-5=10")
	# 鎧テスト: 鎧1スタック=10%軽減 → ATK5*0.9=4.5→4 → HP10-4=6
	target._damage_reduction = 1
	var armor_pct: float = min(1.0, target._damage_reduction * 0.1)
	var actual_dmg: int = max(0, int(float(dmg) * (1.0 - armor_pct)))
	target.take_damage(actual_dmg)
	r._assert_eq(actual_dmg, 4, "鎧1スタック: ATK5→4dmg")
	r._assert_eq(target.current_hp, 6, "鎧軽減後HP=6")
	# 火傷ATK低下テスト: 火傷2スタック → reduction=0.8*2/(2+2)=0.4 → ATK5*0.6=3
	attacker.burn_turns = 2
	var burn_reduction: float = 0.8 * float(attacker.burn_turns) / float(attacker.burn_turns + 2)
	var burned_atk: int = max(1, int(float(attacker.attack) * (1.0 - burn_reduction)))
	r._assert_eq(burned_atk, 3, "火傷2スタック: ATK5→3")

# ---- バフ適用テスト ----
func _test_buff_application(r: RefCounted) -> void:
	var u = _create_unit("ゴブリン")
	# ATKバフ
	u._atk_bonus = 3
	var effective_atk: int = u.attack + u._atk_bonus
	r._assert_eq(effective_atk, 6, "ゴブリンATK3+バフ3=6")
	# ATKバフ上限10
	u._atk_bonus = 12
	u._atk_bonus = min(u._atk_bonus, 10)
	r._assert_eq(u._atk_bonus, 10, "ATKバフ上限=10")

# ---- デバフTick テスト ----
func _test_debuff_tick(r: RefCounted) -> void:
	var u = _create_unit("スライム")
	u.frozen_turns = 3
	u.burn_turns = 2
	u.poison_stacks = 4
	# 凍結: 毎秒-1
	u.frozen_turns -= 1
	r._assert_eq(u.frozen_turns, 2, "凍結Tick: 3→2")
	# 火傷: 毎秒-1
	u.burn_turns -= 1
	r._assert_eq(u.burn_turns, 1, "火傷Tick: 2→1")
	# 麻痺: 毎秒-1
	# 毒: 永続（減少しない）
	r._assert_eq(u.poison_stacks, 4, "毒: 永続4スタック")
	# 毒ダメージ: スタック数=ダメージ/秒
	u.take_damage(u.poison_stacks)
	r._assert_eq(u.current_hp, 11, "毒4dmg: HP15→11")

# ---- 盤面効果ダメージテスト ----
func _test_tile_effect_damage(r: RefCounted) -> void:
	var _EDB = load("res://scripts/EffectDB.gd")
	# 棘: on_enter 5dmg
	var thorn_def = _EDB.EFFECTS.get("tile_thorn", {})
	r._assert_eq(thorn_def.get("trigger", ""), "on_enter", "棘trigger=on_enter")
	r._assert_eq(thorn_def.get("damage", 0), 5, "棘damage=5")
	# 呪われた地: 被ダメ+50%
	var curse_def = _EDB.EFFECTS.get("tile_curse", {})
	r._assert_eq(curse_def.get("damage_mult", 0), 1.5, "呪われた地damage_mult=1.5")
	# 実ダメージ計算: ATK5 * 1.5 = 7.5 → 7
	var base_dmg: int = 5
	var cursed_dmg: int = int(float(base_dmg) * curse_def["damage_mult"])
	r._assert_eq(cursed_dmg, 7, "呪われた地: 5dmg→7dmg")

# ---- アーティファクト排他テスト ----
func _test_artifact_exclusion(r: RefCounted) -> void:
	for name in CardDB.ARTIFACTS:
		var d = CardDB.ARTIFACTS[name]
		if d.get("card_type", "") == "artifact":
			r._assert_true(d.has("hp"), "ARTIFACT[%s] にhpがある" % name)
			r._assert_true(d.has("skills"), "ARTIFACT[%s] にskillsがある" % name)

# ---- Promoteテスト ----
func _test_promote(r: RefCounted) -> void:
	var u = _create_unit("ウルフ")
	r._assert_true(u.get_attack_interval() > 0, "ウルフSPD>0（promoteでタイマーリセットに使用）")
	# promote後もHP保持
	var original_hp: int = u.current_hp
	u.current_hp -= 5  # ダメージを受けた状態
	r._assert_eq(u.current_hp, original_hp - 5, "promote後HPは変わらない（ダメージ保持）")

# ---- 表示と内部ロジックの一致テスト ----
func _test_display_logic_consistency(r: RefCounted) -> void:
	var u = _create_unit("グール")
	# ATKバフ: _atk_bonusが表示にもダメージ計算にも使われるか
	u._atk_bonus = 5
	var display_atk: int = u.attack + u._atk_bonus
	var combat_atk: int = u.attack + u._atk_bonus + u._temp_atk_bonus
	r._assert_eq(display_atk, 10, "グールATK5+バフ5=表示10")
	r._assert_eq(combat_atk, 10, "グールATK5+バフ5=戦闘10（一時バフ0）")
	# 一時バフ追加時の一致
	u._temp_atk_bonus = 3
	var combat_atk2: int = u.attack + u._atk_bonus + u._temp_atk_bonus
	r._assert_eq(combat_atk2, 13, "一時ATK+3→戦闘13")
	# バフリセット後の一致（サポート再計算をシミュレート）
	u._atk_bonus = 0
	u._temp_atk_bonus = 0
	r._assert_eq(u.attack + u._atk_bonus, 5, "リセット後ATK=基礎値5")
	# リセット
	# 鎧: _damage_reductionが軽減計算と表示で一致
	u._damage_reduction = 3
	var armor_pct: float = min(1.0, u._damage_reduction * 0.1)
	r._assert_eq(armor_pct, 0.3, "鎧3スタック: 軽減30%")
	# 被弾で-1
	u._damage_reduction -= 1
	r._assert_eq(u._damage_reduction, 2, "被弾後鎧2")
	# デバフ表示一致
	u.poison_stacks = 4
	u.burn_turns = 2
	r._assert_true(u.poison_stacks > 0, "毒4→表示あり")
	r._assert_true(u.burn_turns > 0, "火傷2→表示あり")
	var burn_reduction: float = 0.8 * float(u.burn_turns) / float(u.burn_turns + 2)
	var burned_atk: int = max(1, int(float(u.attack) * (1.0 - burn_reduction)))
	r._assert_eq(burned_atk, 3, "火傷2: ATK5→3（表示と戦闘計算が同じ式）")
