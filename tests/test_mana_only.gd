extends SceneTree

func _init():
	print("\n=== TestManaGeneration 単体実行 ===")

	# CardDB手動ロード
	var CardDBScript = load("res://scripts/CardDB.gd")
	if CardDBScript == null:
		print("ERROR: CardDB.gd ロード失敗")
		quit(1)
		return

	# TestRunner作成
	var TestRunnerScript = load("res://scripts/TestRunner.gd")
	var runner = TestRunnerScript.new()

	# TestManaGeneration実行
	var TestMana = load("res://scripts/TestManaGeneration.gd")
	if TestMana == null:
		print("ERROR: TestManaGeneration.gd ロード失敗")
		quit(1)
		return

	var test = TestMana.new()
	test.run(runner)

	print("\nテスト結果: %d passed / %d failed" % [runner._pass_count, runner._fail_count])
	if runner._fail_count > 0:
		print("\n失敗:")
		for msg in runner._results:
			print("  " + msg)

	print("=== 完了 ===\n")
	quit(0 if runner._fail_count == 0 else 1)
