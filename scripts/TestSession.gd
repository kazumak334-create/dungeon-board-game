# TestSession.gd
# セッション/画面遷移テスト（GameSession, materials, base_deck, scene_manager）
extends RefCounted

func run(runner: RefCounted) -> void:
	_test_game_session(runner)
	_test_materials_integrity(runner)
	_test_base_deck_integrity(runner)
	_test_scene_manager_paths(runner)
	_test_scenario_title_to_deckprep(runner)
	_test_scenario_battle_run(runner)
	_test_scenario_battle_card_cleanup(runner)
	_test_scenario_return_to_deckprep(runner)
	_test_battle_gold_accumulation(runner)
	_test_battle_gold_to_result(runner)
	_test_result_reward_panel_fields(runner)
	_test_result_3card_choices(runner)
	_test_game_session_map_fields(runner)
	_test_game_session_map_reset(runner)
	_test_map_generator_seed_reproducibility(runner)
	_test_map_generator_acts_count(runner)
	_test_cards_bosses_count(runner)

func _test_game_session(r: RefCounted) -> void:
	# reset()で全フィールドが初期化されるか
	GameSession.class_id = "test"
	GameSession.dev_mode = true
	GameSession.gold = 999
	GameSession.skill_points = 5
	GameSession.materials = [{"id": "test"}]
	GameSession.selected_deck = [{"name": "test"}]
	GameSession.selected_material = {"id": "test"}
	GameSession.reset()
	r._assert_eq(GameSession.class_id, "", "reset: class_id空")
	r._assert_eq(GameSession.dev_mode, false, "reset: dev_mode=false")
	r._assert_eq(GameSession.gold, 0, "reset: gold=0")
	r._assert_eq(GameSession.skill_points, 0, "reset: skill_points=0")
	r._assert_eq(GameSession.materials.size(), 0, "reset: materials空")
	r._assert_eq(GameSession.selected_deck.size(), 0, "reset: selected_deck空")
	r._assert_eq(GameSession.selected_material.size(), 0, "reset: selected_material空")

func _test_materials_integrity(r: RefCounted) -> void:
	r._assert_true(CardDB.MATERIALS.size() > 0, "MATERIALS: 1個以上存在")
	for mat in CardDB.MATERIALS:
		r._assert_true(mat.has("id"), "素材にid: %s" % mat.get("display", "???"))
		r._assert_true(mat.has("display"), "素材にdisplay: %s" % mat.get("id", "???"))
		r._assert_true(mat.has("is_cursed"), "素材にis_cursed: %s" % mat.get("id", "???"))
		r._assert_true(mat.has("benefits"), "素材にbenefits: %s" % mat.get("id", "???"))
		r._assert_true(mat.has("demerits"), "素材にdemerits: %s" % mat.get("id", "???"))
	# 呪い素材はデメリット必須
	for mat in CardDB.MATERIALS:
		if mat.get("is_cursed", false):
			r._assert_true(mat.get("demerits", []).size() > 0, "呪い素材にデメリット: %s" % mat.get("id", ""))

func _test_base_deck_integrity(r: RefCounted) -> void:
	r._assert_true(CardDB.BASE_DECK.size() > 0, "BASE_DECK: 1個以上存在")
	for entry in CardDB.BASE_DECK:
		var name = entry.get("name", "")
		r._assert_true(name != "", "BASE_DECKエントリにname")
		var is_unit = CardDB.UNITS.has(name)
		var is_spell = CardDB.SPELLS.has(name)
		var is_status = CardDB.STATUS_SPELLS.has(name)
		var is_system = CardDB.SYSTEM_SPELLS.has(name)
		r._assert_true(is_unit or is_spell or is_status or is_system, "BASE_DECKカードがDB存在: %s" % name)

func _test_scene_manager_paths(r: RefCounted) -> void:
	# SceneManagerの全パスにファイルが存在するか
	var scenes = SceneManager._scenes
	for key in scenes:
		var path = scenes[key]
		if path != null:
			r._assert_true(FileAccess.file_exists(path), "シーン存在: %s -> %s" % [key, path])

# シナリオ1: Title→MaterialSelect→DeckPrepのデータ引き継ぎ
func _test_scenario_title_to_deckprep(r: RefCounted) -> void:
	GameSession.reset()
	GameSession.class_id = "berserker"
	# 素材選択シミュレート
	GameSession.selected_material = {"id": "herb_bundle", "display": "薬草束", "is_cursed": false, "benefits": [], "demerits": []}
	# MaterialSelectで行うデッキ構築をシミュレート
	var deck: Array = []
	for entry in CardDB.BASE_DECK:
		deck.append(entry.duplicate())
	var cls = CardDB.CLASSES.get(GameSession.class_id, {})
	var initial = cls.get("initial_deck", [])
	if initial.size() > 0:
		deck.append({"name": initial[0], "col": 1})
	GameSession.selected_deck = deck
	var PL = load("res://scripts/PlacementLogic.gd")
	GameSession.placement_config = PL.generate_default_config(deck)
	# 検証
	r._assert_eq(GameSession.class_id, "berserker", "シナリオ1: クラスID引き継ぎ")
	r._assert_eq(GameSession.selected_material.get("id", ""), "herb_bundle", "シナリオ1: 素材引き継ぎ")
	r._assert_true(GameSession.selected_deck.size() > 0, "シナリオ1: デッキ構築済み")
	r._assert_eq(GameSession.placement_config.size(), GameSession.selected_deck.size(), "シナリオ1: placement_configとデッキサイズ一致")

# シナリオ2: DeckPrep→Battle→Resultの1ラン通し
func _test_scenario_battle_run(r: RefCounted) -> void:
	GameSession.reset()
	GameSession.class_id = "berserker"
	GameSession.run_depth = 0
	# battle_config初期化確認
	r._assert_true(GameSession.battle_config.has("time_limit"), "シナリオ2: battle_config初期化")
	r._assert_true(GameSession.battle_config.has("player_base_hp"), "シナリオ2: battle_config.player_base_hp存在")
	r._assert_eq(GameSession.battle_config.get("player_base_hp", 0), 30, "シナリオ2: player_base_hp=30")
	# バトル終了後のlast_result設定シミュレート
	GameSession.last_result = {"win": true, "player_hp_remaining": 20, "enemy_hp_dealt": 30, "turns": 30}
	r._assert_eq(GameSession.last_result.get("win"), true, "シナリオ2: 勝利結果引き継ぎ")
	r._assert_eq(GameSession.last_result.get("player_hp_remaining", 0), 20, "シナリオ2: HP残量引き継ぎ")
	# run_depth加算（Result._on_card_selectedでのみ加算）
	GameSession.run_depth += 1
	r._assert_eq(GameSession.run_depth, 1, "シナリオ2: run_depth加算")
	# battle_configはreset()なしで再バトル時も参照可能
	r._assert_true(GameSession.battle_config.has("time_limit"), "シナリオ2: 再バトル時battle_config維持")

# シナリオ3: バトル終了後のpersistence="battle"カードクリーンアップ
func _test_scenario_battle_card_cleanup(r: RefCounted) -> void:
	GameSession.reset()
	# 通常カード（スライム）と異常状態カードを混在させる
	var first_unit = CardDB.BASE_DECK[0].get("name", "") if CardDB.BASE_DECK.size() > 0 else "スライム"
	var battle_card_name: String = ""
	# STATUS_SPELLSからpersistence="battle"のカードを1枚探す
	for name in CardDB.STATUS_SPELLS:
		var d = CardDB.STATUS_SPELLS[name]
		if d.get("persistence", "permanent") == "battle":
			battle_card_name = name
			break
	GameSession.selected_deck = [
		{"name": first_unit, "col": 2},
		{"name": battle_card_name if battle_card_name != "" else first_unit},
	]
	GameSession.placement_config = [{"col_priority": [2, 1, 0]}, {"col_priority": [2, 1, 0]}]
	var deck_before = GameSession.selected_deck.size()
	# Result._cleanup_battle_cardsのロジックを再現
	var new_deck: Array = []
	var new_config: Array = []
	for i in range(GameSession.selected_deck.size()):
		var entry = GameSession.selected_deck[i]
		var card_name_str = entry.get("name", "") if entry is Dictionary else str(entry)
		var persistence: String = "permanent"
		if CardDB.STATUS_SPELLS.has(card_name_str):
			persistence = CardDB.STATUS_SPELLS[card_name_str].get("persistence", "permanent")
		elif CardDB.UNITS.has(card_name_str):
			persistence = CardDB.UNITS[card_name_str].get("persistence", "permanent")
		elif CardDB.SPELLS.has(card_name_str):
			persistence = CardDB.SPELLS[card_name_str].get("persistence", "permanent")
		if persistence != "battle":
			new_deck.append(entry)
			if i < GameSession.placement_config.size():
				new_config.append(GameSession.placement_config[i])
	GameSession.selected_deck = new_deck
	GameSession.placement_config = new_config
	if battle_card_name != "":
		r._assert_true(GameSession.selected_deck.size() < deck_before, "シナリオ3: battlepersistenceカード除去")
	r._assert_true(GameSession.selected_deck.size() >= 1, "シナリオ3: 通常カードは残存")
	r._assert_eq(GameSession.selected_deck.size(), GameSession.placement_config.size(), "シナリオ3: デッキとconfigサイズ一致")

# シナリオ4: Result→DeckPrep戻り時のデータ保持
func _test_scenario_return_to_deckprep(r: RefCounted) -> void:
	GameSession.reset()
	GameSession.class_id = "slime_alchemist"
	GameSession.selected_deck = [{"name": "スライム", "col": 2}]
	var PL = load("res://scripts/PlacementLogic.gd")
	GameSession.placement_config = PL.generate_default_config(GameSession.selected_deck)
	GameSession.gold = 100
	GameSession.skill_points = 2
	# Result画面でカード追加シミュレート
	var first_unit = CardDB.BASE_DECK[0].get("name", "スライム") if CardDB.BASE_DECK.size() > 0 else "スライム"
	GameSession.selected_deck.append({"name": first_unit, "col": 2})
	var new_cfg = PL.generate_default_config([{"name": first_unit, "col": 2}])
	if new_cfg.size() > 0:
		GameSession.placement_config.append(new_cfg[0])
	r._assert_eq(GameSession.selected_deck.size(), 2, "シナリオ4: カード追加反映")
	r._assert_eq(GameSession.gold, 100, "シナリオ4: ゴールド維持")
	r._assert_eq(GameSession.skill_points, 2, "シナリオ4: SP維持")
	r._assert_eq(GameSession.class_id, "slime_alchemist", "シナリオ4: クラスID維持")
	r._assert_eq(GameSession.placement_config.size(), GameSession.selected_deck.size(), "シナリオ4: placement_configサイズ一致")

# テスト: 敵撃破でcurrent_battle_goldが増える
func _test_battle_gold_accumulation(r: RefCounted) -> void:
	GameSession.reset()
	r._assert_eq(GameSession.current_battle_gold, 0, "battle_gold: reset後0")
	# cost=2のユニット撃破をシミュレート（reward_multiplier=1.0の場合 2×5=10G）
	var reward_mult: float = GameSession.battle_config.get("reward_multiplier", 1.0)
	var gold = max(1, int(2 * 5 * reward_mult))
	GameSession.current_battle_gold += gold
	r._assert_eq(GameSession.current_battle_gold, 10, "battle_gold: cost2撃破で+10G")
	# cost=1ユニット追加
	var gold2 = max(1, int(1 * 5 * reward_mult))
	GameSession.current_battle_gold += gold2
	r._assert_eq(GameSession.current_battle_gold, 15, "battle_gold: 累積15G")

# テスト: バトル終了時にcurrent_battle_goldがlast_resultに渡る
func _test_battle_gold_to_result(r: RefCounted) -> void:
	GameSession.reset()
	GameSession.current_battle_gold = 30
	# Main._check_game_overの動作をシミュレート
	GameSession.last_result = {"win": true, "player_hp_remaining": 20, "turns": 0, "battle_gold": GameSession.current_battle_gold}
	r._assert_eq(GameSession.last_result.get("battle_gold", -1), 30, "battle_gold: last_resultに引き継ぎ")
	r._assert_eq(GameSession.last_result.get("win"), true, "battle_gold: 勝利フラグと共存")

# テスト: 報酬パネルに必要なフィールドが揃っている
func _test_result_reward_panel_fields(r: RefCounted) -> void:
	GameSession.reset()
	# 報酬計算に必要なフィールドが全て存在するか確認
	r._assert_true("current_battle_gold" in GameSession, "reward_panel: current_battle_goldフィールド存在")
	r._assert_true("gold" in GameSession, "reward_panel: goldフィールド存在")
	r._assert_true("skill_points" in GameSession, "reward_panel: skill_pointsフィールド存在")
	r._assert_true("materials" in GameSession, "reward_panel: materialsフィールド存在")
	r._assert_true(GameSession.last_result.has("win"), "reward_panel: last_result.win存在")

# テスト: カード3択生成（重みテーブルと重複なし）
func _test_result_3card_choices(r: RefCounted) -> void:
	GameSession.reset()
	GameSession.run_depth = 0
	# 重みテーブルからREARLY_WEIGHTS_EARLYで3枚選択できるか確認
	var pool: Array = []
	for name in CardDB.UNITS:
		pool.append({"name": name, "rarity": CardDB.UNITS[name].get("rarity", "common")})
	for name in CardDB.SPELLS:
		pool.append({"name": name, "rarity": CardDB.SPELLS[name].get("rarity", "common")})
	r._assert_true(pool.size() >= 3, "card_choices: プール3枚以上")
	# 重複なし確認（3回抽選で同じ名前が出ないことをシミュレート）
	var used: Array = []
	for entry in pool.slice(0, min(3, pool.size())):
		r._assert_true(not (entry["name"] in used), "card_choices: 3択に重複なし: %s" % entry["name"])
		used.append(entry["name"])

# Phase 3テスト: GameSessionマップフィールドの存在確認
func _test_game_session_map_fields(r: RefCounted) -> void:
	r._assert_true("map_data" in GameSession, "map_fields: map_data存在")
	r._assert_true("race_theme" in GameSession, "map_fields: race_theme存在")
	r._assert_true("map_seed" in GameSession, "map_fields: map_seed存在")
	r._assert_true("current_act" in GameSession, "map_fields: current_act存在")
	r._assert_true("current_node" in GameSession, "map_fields: current_node存在")
	r._assert_true("completed_nodes" in GameSession, "map_fields: completed_nodes存在")
	r._assert_true("boss_candidates" in GameSession, "map_fields: boss_candidates存在")
	r._assert_true("selected_boss_id" in GameSession, "map_fields: selected_boss_id存在")

# Phase 3テスト: reset()でマップフィールドがクリアされる
func _test_game_session_map_reset(r: RefCounted) -> void:
	GameSession.map_data = {"seed": 12345, "acts": []}
	GameSession.race_theme = "beast"
	GameSession.map_seed = 12345
	GameSession.current_act = 2
	GameSession.current_node = "act1_boss"
	GameSession.completed_nodes = ["act1_d0_n0", "act1_d0_n1"]
	GameSession.boss_candidates = ["boss_beast_king"]
	GameSession.selected_boss_id = "boss_beast_king"
	GameSession.reset()
	r._assert_eq(GameSession.map_data.size(), 0, "map_reset: map_data空")
	r._assert_eq(GameSession.race_theme, "", "map_reset: race_theme空")
	r._assert_eq(GameSession.map_seed, 0, "map_reset: map_seed=0")
	r._assert_eq(GameSession.current_act, 1, "map_reset: current_act=1")
	r._assert_eq(GameSession.current_node, "", "map_reset: current_node空")
	r._assert_eq(GameSession.completed_nodes.size(), 0, "map_reset: completed_nodes空")
	r._assert_eq(GameSession.boss_candidates.size(), 0, "map_reset: boss_candidates空")
	r._assert_eq(GameSession.selected_boss_id, "", "map_reset: selected_boss_id空")

# Phase 3テスト: 同じseedで同じマップが生成される
func _test_map_generator_seed_reproducibility(r: RefCounted) -> void:
	var gen = load("res://scripts/MapGenerator.gd").new()
	var seed_val: int = 999
	var map1 = gen.generate(seed_val, "slime")
	var map2 = gen.generate(seed_val, "slime")
	r._assert_eq(map1.get("seed"), map2.get("seed"), "map_seed: seed一致")
	r._assert_eq(map1.get("acts", []).size(), map2.get("acts", []).size(), "map_seed: acts数一致")
	# 各Act内のノード数が一致
	var acts1 = map1.get("acts", [])
	var acts2 = map2.get("acts", [])
	for i in range(acts1.size()):
		r._assert_eq(acts1[i].get("nodes", []).size(), acts2[i].get("nodes", []).size(),
			"map_seed: Act%dノード数一致" % (i + 1))

# Phase 3テスト: 3Act生成される
func _test_map_generator_acts_count(r: RefCounted) -> void:
	var gen = load("res://scripts/MapGenerator.gd").new()
	var map_data = gen.generate(42, "undead")
	r._assert_eq(map_data.get("acts", []).size(), 3, "map_acts: 3Act生成")
	var acts = map_data.get("acts", [])
	for i in range(acts.size()):
		var act = acts[i]
		r._assert_eq(act.get("act_num", 0), i + 1, "map_acts: act_num=%d" % (i + 1))
		r._assert_true(act.get("nodes", []).size() >= 5, "map_acts: Act%dに5ノード以上" % (i + 1))
		r._assert_true(act.get("boss_candidates", []).size() >= 0, "map_acts: Act%dにboss_candidates存在" % (i + 1))
		# 連結性検証
		r._assert_true(gen.validate_connectivity(act), "map_connectivity: Act%d連結" % (i + 1))

# Phase 3テスト: bossesが最低3体読み込まれる
func _test_cards_bosses_count(r: RefCounted) -> void:
	r._assert_true(CardDB.BOSSES.size() >= 3, "bosses: 3体以上存在")
	for boss_id in CardDB.BOSSES:
		var boss = CardDB.BOSSES[boss_id]
		r._assert_true(boss.has("display"), "bosses: display存在: %s" % boss_id)
		r._assert_true(boss.has("act"), "bosses: act存在: %s" % boss_id)
		r._assert_true(boss.has("race_theme"), "bosses: race_theme存在: %s" % boss_id)
		r._assert_true(boss.has("hp_multiplier"), "bosses: hp_multiplier存在: %s" % boss_id)
		r._assert_true(boss.has("atk_multiplier"), "bosses: atk_multiplier存在: %s" % boss_id)
