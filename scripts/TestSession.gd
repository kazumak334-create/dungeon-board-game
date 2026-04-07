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
		r._assert_true(is_unit or is_spell or is_status, "BASE_DECKカードがDB存在: %s" % name)

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
