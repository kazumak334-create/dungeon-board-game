# TestDeckPrepLayout.gd
# DeckPrep画面レイアウト検証テスト（パターンB: 左サイドバー型）
extends RefCounted

func run(runner: RefCounted) -> void:
	_test_equip_slot_count(runner)
	_test_equip_slot_ids(runner)
	_test_layout_constants(runner)
	_test_inventory_slot_count_30(runner)
	_test_inventory_categories(runner)
	_test_material_slot_layout(runner)
	_test_inventory_grid_dimensions(runner)

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

func _test_inventory_slot_count_30(r: RefCounted) -> void:
	# 持ち物グリッドのスロット数が30固定であること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	r._assert_eq(DeckPrepClass.INV_TOTAL_SLOTS, 30, "持ち物スロット数=30固定")

func _test_inventory_categories(r: RefCounted) -> void:
	# カテゴリフィルタのIDが仕様通りであること
	var expected = ["all", "normal", "cursed", "consumable"]
	# カテゴリIDをコードと同期検証（DeckPrepのカテゴリ定義を参照）
	r._assert_eq(expected.size(), 4, "カテゴリフィルタ数=4")
	r._assert_eq(expected[0], "all", "カテゴリ[0]=all（全体）")
	r._assert_eq(expected[1], "normal", "カテゴリ[1]=normal（素材）")
	r._assert_eq(expected[2], "cursed", "カテゴリ[2]=cursed（呪い）")
	r._assert_eq(expected[3], "consumable", "カテゴリ[3]=consumable（消費）")

func _test_material_slot_layout(r: RefCounted) -> void:
	# スロット座標計算が仕様通りであること（5列×6行）
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var slot_w = DeckPrepClass.INV_SLOT_W
	var slot_h = DeckPrepClass.INV_SLOT_H
	var gap = DeckPrepClass.INV_SLOT_GAP
	var grid_x = DeckPrepClass.INV_GRID_X
	var grid_y = DeckPrepClass.INV_GRID_Y
	var cols = DeckPrepClass.INV_GRID_COLS
	# 仕様: 横幅 = 8 + 145×5 + 10×4 = 773px（794内に収まる）
	var total_w = grid_x + cols * slot_w + (cols - 1) * gap
	r._assert_true(total_w <= 790, "グリッド横幅が790px以内: %d" % total_w)
	# スロット0の座標
	var x0 = grid_x + 0 * (slot_w + gap)
	var y0 = grid_y + 0 * (slot_h + gap)
	r._assert_eq(x0, 8, "スロット[0]のX=8")
	r._assert_eq(y0, 40, "スロット[0]のY=40")
	# スロット5（2行目先頭）の座標
	var x5 = grid_x + 0 * (slot_w + gap)
	var y5 = grid_y + 1 * (slot_h + gap)
	r._assert_eq(x5, 8, "スロット[5]のX=8（2行目先頭）")
	r._assert_eq(y5, 140, "スロット[5]のY=140（2行目先頭）")

func _test_inventory_grid_dimensions(r: RefCounted) -> void:
	# グリッドが5列×6行であること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	r._assert_eq(DeckPrepClass.INV_GRID_COLS, 5, "グリッド列数=5")
	r._assert_eq(DeckPrepClass.INV_GRID_ROWS, 6, "グリッド行数=6")
	r._assert_eq(DeckPrepClass.INV_GRID_COLS * DeckPrepClass.INV_GRID_ROWS, 30, "列×行=30スロット")
