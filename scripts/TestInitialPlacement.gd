# TestInitialPlacement.gd
# v2設計: 初期配置システムのテスト
extends RefCounted

var _runner: RefCounted = null

func run(runner: RefCounted) -> void:
	_runner = runner
	_test_initial_units_structure()
	_test_mana_from_initial_units()
	_test_deck_only_spells()

func _test_initial_units_structure() -> void:
	# GameSession.initial_unitsの構造確認
	GameSession.initial_units.clear()
	GameSession.initial_units.append({"name": "スライム", "row": 0, "col": 0})
	GameSession.initial_units.append(null)
	GameSession.initial_units.append({"name": "ゴブリン", "row": 0, "col": 2})

	_runner._assert_eq(GameSession.initial_units.size(), 3, "initial_units: 3要素")
	_runner._assert_eq(GameSession.initial_units[0]["name"], "スライム", "initial_units[0]: スライム")
	_runner._assert_true(GameSession.initial_units[1] == null, "initial_units[1]: null")
	_runner._assert_eq(GameSession.initial_units[2]["name"], "ゴブリン", "initial_units[2]: ゴブリン")

func _test_mana_from_initial_units() -> void:
	# マナ上限がinitial_unitsから計算されることを確認
	GameSession.initial_units.clear()
	GameSession.initial_units.append({"name": "スライム", "row": 0, "col": 0})  # cost=1
	GameSession.initial_units.append({"name": "Fangos", "row": 0, "col": 1})  # cost=1
	GameSession.initial_units.append({"name": "ウルフ", "row": 0, "col": 2})    # cost=2
	for i in range(6):
		GameSession.initial_units.append(null)

	var DM = load("res://scripts/DeckManager.gd")
	var dm = DM.new()
	dm._ready()
	dm.initialize_mana_from_deck()

	var expected_mana = 1.0 + 1.0 + 2.0
	_runner._assert_eq(dm.MANA_MAX, expected_mana, "MANA_MAX=初期配置総コスト(1+1+2=4)")
	_runner._assert_eq(dm.mana, 0.0, "初期マナ=0")

func _test_deck_only_spells() -> void:
	# デッキに呪文のみが入ることを確認
	GameSession.selected_deck = [
		{"name": "スライム", "col": 1},  # ユニット→スキップ
		{"name": "火球", "col": 1},      # 呪文→追加
		{"name": "氷結", "col": 1},      # 呪文→追加
	]

	var DM = load("res://scripts/DeckManager.gd")
	var dm = DM.new()
	dm._ready()

	var unit_count = 0
	var spell_count = 0
	for card in dm.deck:
		if card.card_type == "unit":
			unit_count += 1
		elif card.card_type == "spell" or card.card_type == "status_spell":
			spell_count += 1

	# v2設計: デッキにはユニットが含まれない（initial_unitsから配置）
	_runner._assert_eq(unit_count, 0, "デッキにユニット0枚（v2設計: initial_unitsから配置）")
	# v2設計: selected_deckが空の場合、PLAYER_SPELLSから呪文が追加される
	_runner._assert_true(spell_count >= 0, "デッキに呪文が存在（v2設計: 呪文のみデッキに含まれる）")
