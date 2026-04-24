extends SceneTree

func _init():
	print("=== 構文チェック開始 ===")
	var syntax_pass = _check_syntax()
	print("=== 構文チェック完了 ===\n")

	if not syntax_pass:
		print("❌ 構文エラーあり。テストをスキップします")
		quit(1)

	print("=== テスト実行開始 ===")
	var TestRunner = load("res://scripts/debug/TestRunner.gd")
	var runner = TestRunner.new()
	var result = runner.run_all()
	print(result)
	print("=== テスト実行完了 ===")
	quit()

func _check_syntax() -> bool:
	var critical_scripts = [
		"CardDB.gd",
		"GameSession.gd",
		"DeckPrepBoard.gd",
		"DeckPrep.gd",
		"Main.gd",
		"CombatSystem.gd",
		"BoardManager.gd",
		"DeckManager.gd",
		"EnemyAI.gd",
		"EffectActions.gd",
		"SpellSlotSystem.gd"
	]

	var all_pass = true
	for script_name in critical_scripts:
		var result = load("res://scripts/" + script_name)
		if result == null:
			print("❌ SYNTAX ERROR: " + script_name)
			all_pass = false
		else:
			print("✓ " + script_name)

	return all_pass
