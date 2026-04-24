# RunTests.gd
# headlessテスト実行用スクリプト（--script引数で直接実行）
extends SceneTree

func _init() -> void:
	# CardDBのAutoload初期化を待つ
	var timer = create_timer(0.5)
	timer.timeout.connect(_run)

func _run() -> void:
	var TestRunnerScript = load("res://scripts/debug/TestRunner.gd")
	if TestRunnerScript == null:
		print("ERROR: TestRunner.gd not found")
		quit(1)
		return
	var runner = TestRunnerScript.new()
	var result: String = runner.run_all()
	for line in result.split("\n"):
		if line != "":
			print(line)
	# fail件数をexit codeに
	if "0 failed" in result:
		quit(0)
	else:
		quit(1)
