# TestEntry.gd
# 実機テスト用エントリーポイント
# battle_configと初期配置を設定してバトルへ遷移
extends Node

func _ready() -> void:
	print("[TestEntry] テスト用データを設定中...")

	# 自動テストフラグを設定
	OS.set_environment("DUNGEON_AUTOTEST", "1")

	# GameSession初期化
	GameSession.class_id = "berserker"
	GameSession.gold = 100
	GameSession.current_battle_gold = 0

	# テスト用初期配置ユニット（9マス配置）
	GameSession.initial_units = [
		# 前列（col=2）
		{"name": "スライム", "row": 0, "col": 2},
		{"name": "グール", "row": 1, "col": 2},
		{"name": "ゴブリン", "row": 2, "col": 2},
		# 中列（col=1）
		{"name": "ウルフ", "row": 0, "col": 1},
		{"name": "スケルトン", "row": 1, "col": 1},
		# 後列（col=0）
		{"name": "スライム", "row": 0, "col": 0},
	]

	# テスト用呪文デッキ
	GameSession.selected_deck = [
		{"name": "生命の雫", "type": "spell"},
		{"name": "火球", "type": "spell"},
		{"name": "氷槍", "type": "spell"},
	]

	# battle_config設定
	GameSession.battle_config = {
		"player_base_hp": 30,
		"enemy_base_hp": 30,
		"card_play_interval": 1.0,
		"enemy_check_interval": 1.0,
		"time_limit": 60.0,
		"time_up_result": "lose",
		"reward_multiplier": 1.0,
	}

	# 環境設定
	GameSession.base_environment = "env_none"

	print("[TestEntry] 設定完了。バトルへ遷移...")

	# バトル画面へ遷移
	await get_tree().create_timer(0.5).timeout
	SceneManager.go_to(SceneManager.BATTLE)
