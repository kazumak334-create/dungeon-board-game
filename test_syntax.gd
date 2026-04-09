extends SceneTree

# GameSessionをグローバルとしてロード
var GameSession = preload("res://scripts/GameSession.gd").new()

func _init():
	print("=== 構文チェック開始 ===")

	# 基本スクリプトのロード（パースエラーのみ検出）
	var scripts = [
		"CardDB.gd",
		"GameSession.gd",
		"DeckPrepBoard.gd",
		"DeckPrep.gd",
		"Main.gd",
		"CombatSystem.gd",
		"BoardManager.gd"
	]

	var pass_count = 0
	var fail_count = 0

	for script_name in scripts:
		var result = load("res://scripts/" + script_name)
		if result == null:
			print("FAIL: " + script_name + " のロードに失敗")
			fail_count += 1
		else:
			print("PASS: " + script_name)
			pass_count += 1

	print("=== 構文チェック完了: %d passed / %d failed ===" % [pass_count, fail_count])
	quit()
