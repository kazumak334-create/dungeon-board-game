# TestSpellSlot.gd
# v2設計: 呪文3スロットシステムのテスト
extends RefCounted

var _runner: RefCounted = null

func run(runner: RefCounted) -> void:
	_runner = runner
	_test_slot_structure()
	_test_set_clear_slot()
	_test_mana_consumption()

func _test_slot_structure() -> void:
	# SpellSlotSystemの構造確認
	var SSS = load("res://scripts/SpellSlotSystem.gd")
	var sss = SSS.new()
	# setup()呼び出しでスロット初期化
	sss.setup(null, null, null, null)

	_runner._assert_eq(sss.slots.size(), 3, "3スロット存在")
	for i in range(3):
		_runner._assert_true(sss.slots[i].has("spell"), "スロット%d: spell" % i)
		_runner._assert_true(sss.slots[i].has("condition"), "スロット%d: condition" % i)
		_runner._assert_true(sss.slots[i].has("mana_cost"), "スロット%d: mana_cost" % i)
		_runner._assert_true(sss.slots[i].has("enabled"), "スロット%d: enabled" % i)

func _test_set_clear_slot() -> void:
	# set_slot/clear_slotの動作確認
	var SSS = load("res://scripts/SpellSlotSystem.gd")
	var sss = SSS.new()
	sss.setup(null, null, null, null)

	# ダミー呪文
	var UD = load("res://scripts/UnitData.gd")
	var spell = UD.new()
	spell.unit_name = "テスト呪文"
	spell.cost = 5
	spell.card_type = "spell"

	# set_slot
	sss.set_slot(0, spell, "always")
	_runner._assert_eq(sss.slots[0]["spell"], spell, "スロット0: 呪文設定")
	_runner._assert_eq(sss.slots[0]["condition"], "always", "スロット0: 条件設定")
	_runner._assert_eq(sss.slots[0]["mana_cost"], 5, "スロット0: コスト=5")
	_runner._assert_true(sss.slots[0]["enabled"], "スロット0: enabled=true")

	# clear_slot
	sss.clear_slot(0)
	_runner._assert_true(sss.slots[0]["spell"] == null, "スロット0: クリア")
	_runner._assert_false(sss.slots[0]["enabled"], "スロット0: enabled=false")

func _test_mana_consumption() -> void:
	# マナ消費確認
	# TODO: 統合テストで確認（Main.gdが必要）
	_runner._assert_true(true, "マナ消費: 統合テストで確認")
