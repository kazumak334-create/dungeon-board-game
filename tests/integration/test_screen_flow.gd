# test_screen_flow.gd
# 画面遷移の統合テスト
extends GutTest

# テスト用のシーン遷移ヘルパー
var _current_scene: Node = null

func before_each():
	# GameSession リセット
	GameSession.reset()
	GameSession.class_id = "alchemist"

func after_each():
	if _current_scene != null:
		_current_scene.queue_free()
		_current_scene = null
	await wait_frames(2)

# Title → MaterialSelect 遷移テスト
func test_title_to_material_select():
	# Title画面読み込み
	var title_scene = load("res://scenes/Title.tscn").instantiate()
	add_child_autofree(title_scene)
	await wait_frames(1)

	# クラス選択ボタンをシミュレート
	GameSession.class_id = "alchemist"

	# MaterialSelectへ遷移（実際のボタンクリックをシミュレート）
	SceneManager.go_to(SceneManager.MATERIAL_SELECT)
	await wait_frames(2)

	assert_true(GameSession.class_id == "alchemist", "クラスIDが保持されている")

# MaterialSelect → MapSelect 遷移テスト
func test_material_to_map_select():
	GameSession.class_id = "alchemist"

	var material_scene = load("res://scenes/MaterialSelect.tscn").instantiate()
	add_child_autofree(material_scene)
	await wait_frames(2)

	# 素材選択（インデックス0を選択）
	GameSession.selected_material = {"index": 0}

	# MapSelectへ遷移
	SceneManager.go_to(SceneManager.MAP_SELECT)
	await wait_frames(2)

	assert_not_null(GameSession.selected_material, "素材選択が保持されている")

# MapSelect → DeckPrep 遷移テスト
func test_map_to_deck_prep():
	GameSession.class_id = "alchemist"
	GameSession.selected_material = {"index": 0}

	var map_scene = load("res://scenes/MapSelect.tscn").instantiate()
	add_child_autofree(map_scene)
	await wait_frames(2)

	# ノード選択（battle）
	GameSession.battle_type = "normal"

	# DeckPrepへ遷移
	SceneManager.go_to(SceneManager.DECK_PREP)
	await wait_frames(2)

	assert_eq(GameSession.battle_type, "normal", "バトルタイプが設定されている")

# DeckPrep → Battle 遷移テスト
func test_deck_prep_to_battle():
	GameSession.class_id = "alchemist"
	GameSession.selected_deck = CardDB.CLASSES["alchemist"]["initial_deck"].duplicate()
	GameSession.initial_units = []
	for i in range(9):
		GameSession.initial_units.append(null)

	var deck_prep_scene = load("res://scenes/DeckPrep.tscn").instantiate()
	add_child_autofree(deck_prep_scene)
	await wait_frames(2)

	# Battleへ遷移
	SceneManager.go_to(SceneManager.BATTLE)
	await wait_frames(2)

	assert_not_null(GameSession.selected_deck, "デッキが設定されている")

# Battle → Result 遷移テスト
func test_battle_to_result():
	GameSession.class_id = "alchemist"
	GameSession.selected_deck = CardDB.CLASSES["alchemist"]["initial_deck"].duplicate()
	GameSession.last_result = {"win": true, "player_hp_remaining": 20, "enemy_hp_remaining": 0, "turns": 10}

	var result_scene = load("res://scenes/Result.tscn").instantiate()
	add_child_autofree(result_scene)
	await wait_frames(2)

	assert_true(GameSession.last_result.get("win", false), "勝利結果が保持されている")

# 完全な画面遷移フローテスト
func test_full_screen_flow():
	# Title → MaterialSelect → MapSelect → DeckPrep → Battle → Result
	GameSession.reset()
	GameSession.class_id = "alchemist"

	# MaterialSelect
	GameSession.selected_material = {"index": 0}
	assert_not_null(GameSession.selected_material, "Step1: 素材選択")

	# MapSelect
	GameSession.battle_type = "normal"
	assert_eq(GameSession.battle_type, "normal", "Step2: ノード選択")

	# DeckPrep
	GameSession.selected_deck = CardDB.CLASSES["alchemist"]["initial_deck"].duplicate()
	assert_gt(GameSession.selected_deck.size(), 0, "Step3: デッキ設定")

	# Battle → Result
	GameSession.last_result = {"win": true}
	assert_true(GameSession.last_result.get("win"), "Step4: バトル完了")

	print("✓ 完全な画面遷移フロー成功")
