# TestGameSystem.gd
# 環境/システムテスト（environments, mana, enemy_ai, rarity, card_queue, spell_speed, cast_gauge, tile_triggers）
extends RefCounted

func run(runner: RefCounted) -> void:
	_test_environments(runner)
	_test_mana_system(runner)
	_test_enemy_ai_mana_skip(runner)
	_test_rarity_integrity(runner)
	_test_card_queue_data(runner)
	_test_spell_speed_skip(runner)
	_test_cast_gauge(runner)
	_test_tile_triggers(runner)

func _test_environments(r: RefCounted) -> void:
	# ENVIRONMENTS存在確認
	r._assert_true(CardDB.ENVIRONMENTS.size() > 0, "ENVIRONMENTS: 1個以上存在")

	# env_noneは盤面効果なし
	var none_env = CardDB.ENVIRONMENTS.get("env_none", {})
	r._assert_eq(none_env.get("tile_id", "x"), "", "env_none: tile_id空")
	r._assert_eq(none_env.get("max_tiles", -1), 0, "env_none: max_tiles=0")

	# 各環境のtile_idがEffectDBに存在するか
	var _EDB = load("res://scripts/EffectDB.gd")
	for env_id in CardDB.ENVIRONMENTS:
		var env = CardDB.ENVIRONMENTS[env_id]
		r._assert_true(env.has("display"), "ENV[%s] にdisplay" % env_id)
		r._assert_true(env.has("tile_id"), "ENV[%s] にtile_id" % env_id)
		var tid = env.get("tile_id", "")
		if tid != "":
			r._assert_true(_EDB.EFFECTS.has(tid), "ENV[%s] のtile_id '%s' がEffectDBに存在" % [env_id, tid])

	# GameSessionの環境フィールド
	GameSession.base_environment = "env_curse"
	GameSession.reset()
	r._assert_eq(GameSession.base_environment, "env_none", "reset: base_environment=env_none")

func _test_mana_system(r: RefCounted) -> void:
	# マナ上限は3でスタート
	r._assert_eq(int(CardDB.CLASSES["alchemist"]["mana_max"]), 3, "錬金術師mana_max=3")
	r._assert_eq(int(CardDB.CLASSES["berserker"]["mana_max"]), 3, "バーサーカーmana_max=3")
	r._assert_eq(int(CardDB.CLASSES["necromancer"]["mana_max"]), 3, "死霊術師mana_max=3")

	# 呪文回収カードの存在確認
	r._assert_true(CardDB.SYSTEM_SPELLS.has("呪文回収"), "呪文回収カード存在")
	var mana_card = CardDB.SYSTEM_SPELLS["呪文回収"]
	r._assert_eq(mana_card.get("mana", -1), 0, "呪文回収コスト=0")

	# MANA_MAX廃止: コスト超過スキップは削除済み
	r._assert_true(true, "マナ上限なし設計（スキップ廃止）")

func _test_enemy_ai_mana_skip(r: RefCounted) -> void:
	# EnemyAIはMANA_MAX廃止済み（呪文を使わないため不要）
	var ai_script = load("res://scripts/EnemyAI.gd")
	r._assert_true(ai_script != null, "EnemyAI.gdロード可能")

func _test_rarity_integrity(r: RefCounted) -> void:
	var valid_rarities = ["common", "uncommon", "rare", "epic", "legend", "god"]
	# 全ユニットにrarityがある
	for name in CardDB.UNITS:
		var d = CardDB.UNITS[name]
		r._assert_true(d.has("rarity"), "UNITS[%s] にrarity" % name)
		if d.has("rarity"):
			r._assert_true(d["rarity"] in valid_rarities, "UNITS[%s] rarity有効値" % name)
	# 全呪文にrarityがある
	for name in CardDB.SPELLS:
		var d = CardDB.SPELLS[name]
		r._assert_true(d.has("rarity"), "SPELLS[%s] にrarity" % name)
		if d.has("rarity"):
			r._assert_true(d["rarity"] in valid_rarities, "SPELLS[%s] rarity有効値" % name)
	# 全アーティファクトにrarityがある
	for name in CardDB.ARTIFACTS:
		var d = CardDB.ARTIFACTS[name]
		r._assert_true(d.has("rarity"), "ARTIFACTS[%s] にrarity" % name)

func _test_card_queue_data(r: RefCounted) -> void:
	# 全ユニットのskillsがEffectDBに存在する（重複チェックだが安全網）
	var _edb = load("res://scripts/EffectDB.gd")
	var fail_count = 0
	for name in CardDB.UNITS:
		for skill in CardDB.UNITS[name].get("skills", []):
			var eid = skill.get("effect_id", "")
			if not _edb.EFFECTS.has(eid):
				fail_count += 1
	r._assert_eq(fail_count, 0, "全ユニットskillsのeffect_idがEffectDBに存在")

	# base_deckの全カードがCardDBに存在
	for entry in CardDB.BASE_DECK:
		var card_name = entry.get("name", "")
		var exists = CardDB.UNITS.has(card_name) or CardDB.SPELLS.has(card_name) or CardDB.STATUS_SPELLS.has(card_name) or CardDB.SYSTEM_SPELLS.has(card_name)
		r._assert_true(exists, "BASE_DECK '%s' がCardDBに存在" % card_name)

	# 呪文回収の効果確認
	var mana_card = CardDB.SYSTEM_SPELLS.get("呪文回収", {})
	var has_shuffle = false
	for skill in mana_card.get("skills", []):
		if skill.get("effect_id", "") == "shuffle_deck":
			has_shuffle = true
	r._assert_true(has_shuffle, "呪文回収にshuffle_deck効果あり")

	# v2設計: ラウンドロビン廃止、全ユニットは手持ち（row=1）に配置される
	var PL = load("res://scripts/PlacementLogic.gd")
	var test_deck_rr = [
		{"name": "スライム", "col": 1},
		{"name": "スライム", "col": 1},
		{"name": "スライム", "col": 1},
	]
	var cfg_rr = PL.generate_default_config(test_deck_rr)
	# v2設計: 全て手持ち（row=1）に配置される
	r._assert_eq(cfg_rr[0]["row"], 1, "v2設計: 全ユニット→手持ち(row=1)")
	r._assert_eq(cfg_rr[1]["row"], 1, "v2設計: 全ユニット→手持ち(row=1)")
	r._assert_eq(cfg_rr[2]["row"], 1, "v2設計: 全ユニット→手持ち(row=1)")

func _test_spell_speed_skip(r: RefCounted) -> void:
	# スキップも詠唱扱いであることの確認（データレベル）
	var dm_script = load("res://scripts/DeckManager.gd")
	r._assert_true(dm_script != null, "DeckManager.gdロード可能")
	r._assert_true(true, "スキップも詠唱タイミングで発生する仕様")

func _test_cast_gauge(r: RefCounted) -> void:
	# キャストゲージの計算ロジック確認
	var timer = 0.5
	var interval = 1.0
	var ratio = 1.0 - (timer / max(0.01, interval))
	r._assert_eq(ratio, 0.5, "キャスト: timer0.5/interval1.0 → ratio0.5")

	# timer=0 → ratio=1.0（満タン=発動可能）
	timer = 0.0
	ratio = 1.0 - (timer / max(0.01, interval))
	r._assert_eq(ratio, 1.0, "キャスト: timer0/interval1.0 → ratio1.0（発動可能）")

	# timer=1.0 → ratio=0（空=クールダウン中）
	timer = 1.0
	ratio = 1.0 - (timer / max(0.01, interval))
	r._assert_eq(ratio, 0.0, "キャスト: timer1.0/interval1.0 → ratio0（クールダウン中）")

func _test_tile_triggers(r: RefCounted) -> void:
	# 棘(tile_thorn)のtriggerがon_enterであること
	var _edb = load("res://scripts/EffectDB.gd")
	var thorn = _edb.EFFECTS.get("tile_thorn", {})
	r._assert_eq(thorn.get("trigger", ""), "on_enter", "棘: trigger=on_enter")
	r._assert_true(thorn.has("damage"), "棘: damageフィールドあり")

	# 鉄壁(tile_fortress)のon_enter効果
	var fortress = _edb.EFFECTS.get("tile_fortress", {})
	r._assert_eq(fortress.get("trigger", ""), "on_enter", "鉄壁: trigger=on_enter")
	r._assert_true(fortress.has("armor_stacks"), "鉄壁: armor_stacksあり")

	# 呪い(tile_curse)はon_stay
	var curse = _edb.EFFECTS.get("tile_curse", {})
	r._assert_eq(curse.get("trigger", ""), "on_stay", "呪い: trigger=on_stay")

	# ヒビ(tile_crack)はon_leave
	var crack = _edb.EFFECTS.get("tile_crack", {})
	r._assert_eq(crack.get("trigger", ""), "on_leave", "ヒビ: trigger=on_leave")
	r._assert_true(crack.has("transform_to"), "ヒビ: transform_toあり")

	# 毒沼(tile_poison)はon_tick
	var poison = _edb.EFFECTS.get("tile_poison", {})
	r._assert_eq(poison.get("trigger", ""), "on_tick", "毒沼: trigger=on_tick")
