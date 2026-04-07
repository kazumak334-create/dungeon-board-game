# TestDeckPrepLayout.gd
# DeckPrep画面レイアウト検証テスト（パターンB: 左サイドバー型）
extends RefCounted

func run(runner: RefCounted) -> void:
	_test_equip_slot_count(runner)
	_test_equip_slot_ids(runner)
	_test_layout_constants(runner)

func _test_equip_slot_count(r: RefCounted) -> void:
	# 装備スロットが6個固定であること（絶対変更禁止）
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var slots = DeckPrepClass.EQUIP_SLOTS
	r._assert_eq(slots.size(), 6, "装備スロット数=6個固定")

func _test_equip_slot_ids(r: RefCounted) -> void:
	# スロットIDが仕様通りであること（絶対変更禁止）
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var slots = DeckPrepClass.EQUIP_SLOTS
	var expected_ids = ["head", "body", "feet", "accessory1", "accessory2", "accessory3"]
	for i in range(expected_ids.size()):
		if i < slots.size():
			r._assert_eq(slots[i]["id"], expected_ids[i], "装備スロットID[%d]=%s" % [i, expected_ids[i]])
		else:
			r._assert_true(false, "装備スロットID[%d]が存在しない" % i)

func _test_layout_constants(r: RefCounted) -> void:
	# レイアウト定数が仕様通りであること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	r._assert_eq(DeckPrepClass.SIDEBAR_W, 200, "サイドバー幅=200")
	r._assert_eq(DeckPrepClass.INFO_W, 275, "解説レーン幅=275")
	r._assert_eq(DeckPrepClass.CONTENT_W, 790, "タブコンテンツ幅=790")
	r._assert_eq(DeckPrepClass.CONTENT_H, 636, "タブコンテンツ高さ=636")
	r._assert_eq(DeckPrepClass.TAB_BAR_X, 210, "タブバーX=210")
	r._assert_eq(DeckPrepClass.INFO_X, 1005, "解説レーンX=1005")
	r._assert_eq(DeckPrepClass.ADVENTURE_Y, 680, "冒険ボタンY=680")
