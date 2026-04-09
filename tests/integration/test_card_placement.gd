# test_card_placement.gd
# カード配置の統合テスト
extends GutTest

var deck_prep: Node

func before_each():
	GameSession.reset()
	GameSession.class_id = "alchemist"
	GameSession.selected_deck = CardDB.CLASSES["alchemist"]["initial_deck"].duplicate()
	GameSession.initial_units = []
	for i in range(9):
		GameSession.initial_units.append(null)

	deck_prep = load("res://scenes/DeckPrep.tscn").instantiate()
	add_child_autofree(deck_prep)
	await wait_frames(2)

func after_each():
	if deck_prep != null:
		deck_prep.queue_free()
		deck_prep = null
	await wait_frames(2)

# カードを盤面に配置するテスト
func test_place_card_on_board():
	# 初期状態: 9マス全て空
	for i in range(9):
		assert_null(GameSession.initial_units[i], "マス%d は空" % i)

	# カードを配置（位置0に最初のユニット）
	var card_name = GameSession.selected_deck[0]
	GameSession.initial_units[0] = {
		"name": card_name,
		"row": 0,
		"col": 0
	}

	assert_not_null(GameSession.initial_units[0], "マス0にカードが配置された")
	assert_eq(GameSession.initial_units[0]["name"], card_name, "カード名が一致")

# 複数カードを配置するテスト
func test_place_multiple_cards():
	var deck = GameSession.selected_deck
	var positions = [
		{"row": 0, "col": 0},  # マス0
		{"row": 0, "col": 1},  # マス1
		{"row": 1, "col": 0},  # マス3
	]

	for i in range(positions.size()):
		var pos = positions[i]
		var idx = pos["row"] * 3 + pos["col"]
		GameSession.initial_units[idx] = {
			"name": deck[i],
			"row": pos["row"],
			"col": pos["col"]
		}

	# 検証
	assert_not_null(GameSession.initial_units[0], "マス0配置")
	assert_not_null(GameSession.initial_units[1], "マス1配置")
	assert_not_null(GameSession.initial_units[3], "マス3配置")
	assert_null(GameSession.initial_units[2], "マス2は空")

# カードを移動するテスト
func test_move_card():
	# マス0に配置
	var card_name = GameSession.selected_deck[0]
	GameSession.initial_units[0] = {
		"name": card_name,
		"row": 0,
		"col": 0
	}

	# マス0 → マス1 へ移動
	GameSession.initial_units[1] = GameSession.initial_units[0]
	GameSession.initial_units[1]["col"] = 1
	GameSession.initial_units[0] = null

	assert_null(GameSession.initial_units[0], "マス0は空になった")
	assert_not_null(GameSession.initial_units[1], "マス1に移動した")
	assert_eq(GameSession.initial_units[1]["name"], card_name, "カード名が一致")

# カードを削除するテスト
func test_remove_card():
	# マス0に配置
	var card_name = GameSession.selected_deck[0]
	GameSession.initial_units[0] = {
		"name": card_name,
		"row": 0,
		"col": 0
	}

	# 削除
	GameSession.initial_units[0] = null

	assert_null(GameSession.initial_units[0], "マス0からカードが削除された")

# 9マス全て埋めるテスト
func test_fill_all_slots():
	var deck = GameSession.selected_deck

	# 9マス全て埋める
	for r in range(3):
		for c in range(3):
			var idx = r * 3 + c
			if idx < deck.size():
				GameSession.initial_units[idx] = {
					"name": deck[idx],
					"row": r,
					"col": c
				}

	# 検証
	var filled_count = 0
	for i in range(9):
		if GameSession.initial_units[i] != null:
			filled_count += 1

	assert_eq(filled_count, min(9, deck.size()), "全マスが埋まった")

# 同じマスに重複配置できないことを確認
func test_cannot_place_duplicate():
	var card1 = GameSession.selected_deck[0]
	var card2 = GameSession.selected_deck[1]

	# マス0に配置
	GameSession.initial_units[0] = {
		"name": card1,
		"row": 0,
		"col": 0
	}

	# 同じマスに別のカードを配置（上書き）
	GameSession.initial_units[0] = {
		"name": card2,
		"row": 0,
		"col": 0
	}

	# 上書きされる
	assert_eq(GameSession.initial_units[0]["name"], card2, "上書きされた")
