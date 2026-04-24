extends SceneTree

func _init():
	print("\n=== v2設計テスト一括実行 ===")

	var TestRunner = load("res://scripts/debug/TestRunner.gd")
	var runner = TestRunner.new()

	# TestManaGeneration
	print("\n[1/3] TestManaGeneration")
	var mana_test = load("res://scripts/debug/TestManaGeneration.gd").new()
	mana_test.run(runner)

	# TestInitialPlacement
	print("\n[2/3] TestInitialPlacement")
	var placement_test = load("res://scripts/debug/TestInitialPlacement.gd").new()
	placement_test.run(runner)

	# TestSpellSlot
	print("\n[3/3] TestSpellSlot")
	var spell_slot_test = load("res://scripts/debug/TestSpellSlot.gd").new()
	spell_slot_test.run(runner)

	print("\n=== テスト結果 ===")
	print("PASSED: %d" % runner._pass_count)
	print("FAILED: %d" % runner._fail_count)

	if runner._fail_count > 0:
		print("\n失敗:")
		for msg in runner._results:
			print("  " + msg)

	quit(0 if runner._fail_count == 0 else 1)
