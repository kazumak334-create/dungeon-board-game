# AutoTest.gd
# 実機テスト自動化スクリプト
extends Node

var test_results: Dictionary = {}
var test_passed: int = 0
var test_failed: int = 0

func _ready() -> void:
	print("=== AutoTest 開始 ===")
	await get_tree().create_timer(0.5).timeout

	# Phase 1: バトル画面テスト
	var current = get_tree().current_scene
	if current != null and current.name == "Main":
		_test_battle_scene()
	elif current != null and current.name == "DeckPrep":
		_test_deckprep_scene()
	else:
		print("[AutoTest] 未対応のシーン: %s" % (current.name if current != null else "null"))

	await get_tree().create_timer(1.0).timeout
	_output_results()
	get_tree().quit()

# ===== バトル画面テスト =====

func _test_battle_scene() -> void:
	print("\n=== Phase 1: バトル画面テスト ===")

	var main = get_tree().current_scene
	if main == null:
		_record_fail("Main", "シーンがnull")
		return

	# A. HP表示の可視性
	_test_hp_visibility(main)

	# B. 本体HPシステム
	_test_base_hp_system(main)

	# D. マナ生成
	_test_mana_generation(main)

	# 30秒待機して行突破をテスト
	print("[AutoTest] 30秒待機してバトル観戦...")
	await get_tree().create_timer(30.0).timeout
	_test_row_breach(main)

func _test_hp_visibility(main: Node) -> void:
	print("\n[A. HP表示の可視性]")

	# HPバーが存在するか
	if main.get("cell_rects") == null:
		_record_fail("A-1", "cell_rectsが存在しない")
		return

	# GameUIインスタンスを取得
	var game_ui = main.get("game_ui")
	if game_ui == null:
		_record_fail("A-1", "game_uiが存在しない")
		return

	# HPバーが表示されているか（_cell_hp_barsをチェック）
	var hp_bars = game_ui.get("_cell_hp_bars")
	if hp_bars == null or hp_bars.size() == 0:
		_record_fail("A-1", "HPバーが初期化されていない")
		return

	var hp_bar_visible = false
	for side in range(2):
		for r in range(3):
			for c in range(3):
				if hp_bars[side][r][c] != null:
					var bar = hp_bars[side][r][c].get("bar")
					if bar != null and bar.visible:
						hp_bar_visible = true
						break

	if hp_bar_visible:
		_record_pass("A-1", "HPバーが表示されている")
	else:
		_record_fail("A-1", "HPバーが非表示")

	# 本体HPラベルが表示されているか
	var player_base_label = main.get("player_base_label")
	var enemy_base_label = main.get("enemy_base_label")

	if player_base_label != null and player_base_label.visible:
		_record_pass("A-3", "自陣本体HPラベルが表示されている")
	else:
		_record_fail("A-3", "自陣本体HPラベルが非表示")

	if enemy_base_label != null and enemy_base_label.visible:
		_record_pass("A-4", "敵陣本体HPラベルが表示されている")
	else:
		_record_fail("A-4", "敵陣本体HPラベルが非表示")

func _test_base_hp_system(main: Node) -> void:
	print("\n[B. 本体HPシステム]")

	var base_hp = main.get("base_hp")
	if base_hp == null or base_hp.size() != 2:
		_record_fail("B-1", "base_hpが初期化されていない")
		return

	if base_hp[0] == 30 and base_hp[1] == 30:
		_record_pass("B-1", "本体HPが初期値30/30")
	else:
		_record_fail("B-1", "本体HPが初期値ではない: [%d, %d]" % [base_hp[0], base_hp[1]])

	# row_breachedフラグが初期化されているか
	var row_breached = main.get("row_breached")
	if row_breached != null and row_breached.size() == 2:
		_record_pass("B-2", "row_breachedフラグが初期化されている")
	else:
		_record_fail("B-2", "row_breachedフラグが存在しない")

func _test_mana_generation(main: Node) -> void:
	print("\n[D. マナ生成]")

	var deck_manager = main.get("deck_manager")
	if deck_manager == null:
		_record_fail("D-1", "deck_managerが存在しない")
		return

	var mana = deck_manager.get("mana")
	var mana_max = deck_manager.get("MANA_MAX")

	if mana != null:
		if mana == 0.0:
			_record_pass("D-1", "バトル開始時マナが0.0")
		else:
			_record_fail("D-1", "バトル開始時マナが0ではない: %.2f" % mana)
	else:
		_record_fail("D-1", "manaプロパティが存在しない")

	if mana_max != null:
		_record_pass("D-2", "MANA_MAXが設定されている: %.2f" % mana_max)
	else:
		_record_fail("D-2", "MANA_MAXが設定されていない")

func _test_row_breach(main: Node) -> void:
	print("\n[B. 行突破テスト（30秒後）]")

	var base_hp = main.get("base_hp")
	var row_breached = main.get("row_breached")

	if base_hp == null or row_breached == null:
		_record_fail("B-3", "base_hpまたはrow_breachedが存在しない")
		return

	# 行突破が発生したかチェック
	var breach_occurred = false
	for side in range(2):
		for row in range(3):
			if row_breached[side][row]:
				breach_occurred = true
				print("[AutoTest] 行突破検出: side=%d row=%d" % [side, row])

	if breach_occurred:
		_record_pass("B-3", "行突破が発生した")
		if base_hp[0] < 30 or base_hp[1] < 30:
			_record_pass("B-4", "行突破時に本体HPが減少した: [%d, %d]" % [base_hp[0], base_hp[1]])
		else:
			_record_fail("B-4", "行突破したが本体HPが減少していない")
	else:
		print("[AutoTest] 30秒では行突破が発生しなかった（正常範囲内）")

# ===== DeckPrep画面テスト =====

func _test_deckprep_scene() -> void:
	print("\n=== Phase 2: DeckPrep画面テスト ===")

	var deckprep = get_tree().current_scene
	if deckprep == null:
		_record_fail("DeckPrep", "シーンがnull")
		return

	# E. 初期配置UI
	_test_initial_placement_ui(deckprep)

	# F. 呪文発動条件UI
	_test_spell_condition_ui(deckprep)

func _test_initial_placement_ui(deckprep: Node) -> void:
	print("\n[E. 初期配置UI]")

	# 盤面が存在するか
	var board = deckprep.get("_board")
	if board == null:
		_record_fail("E-1", "_boardインスタンスが存在しない")
		return
	else:
		_record_pass("E-1", "_boardインスタンスが存在する")

	# タブコンテナが存在するか
	var tab_container = deckprep.get("_tab_container")
	if tab_container != null:
		_record_pass("E-2", "タブコンテナが存在する")
	else:
		_record_fail("E-2", "タブコンテナが存在しない")

func _test_spell_condition_ui(deckprep: Node) -> void:
	print("\n[F. 呪文発動条件UI]")

	# 呪文スロットUIが存在するか（未実装想定）
	# DeckPrep内に呪文スロット関連のノードを検索
	var spell_slot_ui_found = false
	for child in deckprep.get_children():
		if "spell" in child.name.to_lower() and "slot" in child.name.to_lower():
			spell_slot_ui_found = true
			break

	if spell_slot_ui_found:
		_record_pass("F-1", "呪文スロットUIが存在する")
	else:
		_record_fail("F-1", "呪文スロットUIが未実装（想定通り）")

# ===== 結果記録 =====

func _record_pass(id: String, message: String) -> void:
	test_results[id] = {"status": "PASS", "message": message}
	test_passed += 1
	print("  ✅ [%s] %s" % [id, message])

func _record_fail(id: String, message: String) -> void:
	test_results[id] = {"status": "FAIL", "message": message}
	test_failed += 1
	print("  ❌ [%s] %s" % [id, message])

func _output_results() -> void:
	print("\n=== テスト結果サマリー ===")
	print("合格: %d項目" % test_passed)
	print("不合格: %d項目" % test_failed)
	print("合計: %d項目" % (test_passed + test_failed))

	print("\n=== 詳細 ===")
	for id in test_results.keys():
		var result = test_results[id]
		var icon = "✅" if result["status"] == "PASS" else "❌"
		print("%s [%s] %s" % [icon, id, result["message"]])

	# JSONファイルに出力
	var output_path = "user://autotest_results.json"
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(test_results, "\t"))
		file.close()
		print("\n結果をファイルに出力: %s" % output_path)
