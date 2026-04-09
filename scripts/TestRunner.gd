# TestRunner.gd
# 自動テストランナー（開発者モードから実行）
# テストは各TestXxx.gdに責務分離済み
extends RefCounted

var _pass_count: int = 0
var _fail_count: int = 0
var _results: Array = []

func run_all() -> String:
	_pass_count = 0
	_fail_count = 0
	_results.clear()

	# DB整合性テスト
	var db_tests = load("res://scripts/TestDBIntegrity.gd").new()
	db_tests.run(self)

	# シナリオ/バトルテスト
	var battle_tests = load("res://scripts/TestBattleScenario.gd").new()
	battle_tests.run(self)

	# 画面遷移・セッション
	var session_tests = load("res://scripts/TestSession.gd").new()
	session_tests.run(self)

	# 配置ロジック
	var placement_tests = load("res://scripts/TestPlacement.gd").new()
	placement_tests.run(self)

	# 環境/システム
	var system_tests = load("res://scripts/TestGameSystem.gd").new()
	system_tests.run(self)

	# バトルコンフィグ
	var config_tests = load("res://scripts/TestBattleConfig.gd").new()
	config_tests.run(self)

	# DeckPrepレイアウト（パターンB）
	var layout_tests = load("res://scripts/TestDeckPrepLayout.gd").new()
	layout_tests.run(self)

	# v2設計: マナ生成システム
	var mana_tests = load("res://scripts/TestManaGeneration.gd").new()
	mana_tests.run(self)

	# v2設計: 初期配置システム
	var initial_placement_tests = load("res://scripts/TestInitialPlacement.gd").new()
	initial_placement_tests.run(self)

	# v2設計: 呪文3スロット
	var spell_slot_tests = load("res://scripts/TestSpellSlot.gd").new()
	spell_slot_tests.run(self)

	var summary: String = "テスト結果: %d passed / %d failed" % [_pass_count, _fail_count]
	_results.insert(0, summary)
	return "\n".join(_results)

func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		_results.append("FAIL: " + msg)

func _assert_eq(actual, expected, msg: String) -> void:
	var is_equal: bool = false
	if actual is float and expected is float:
		is_equal = absf(actual - expected) < 0.001
	else:
		is_equal = actual == expected
	if is_equal:
		_pass_count += 1
	else:
		_fail_count += 1
		_results.append("FAIL: %s (expected=%s, actual=%s)" % [msg, str(expected), str(actual)])

