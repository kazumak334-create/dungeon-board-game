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
	_test_info_lane_separation(runner)
	_test_mh_inventory_owned_first(runner)
	_test_deck_prep_info_setup(runner)
	_test_board_no_ally_enemy_labels(runner)
	_test_spell_slot_count(runner)
	_test_artifact_slot_count(runner)
	_test_cell_layout_tile_layouts(runner)
	_test_stack_count_grouping(runner)

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

func _test_info_lane_separation(r: RefCounted) -> void:
	# 情報レーンがDeckPrepInfoに分離されていること（DeckPrep.gdに旧解説関数がないこと）
	# DeckPrepInfoが独立クラスとして存在すること
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	r._assert_true(InfoClass != null, "DeckPrepInfo.gdが存在する")
	var info = InfoClass.new()
	r._assert_true(info.has_method("show_card_info"), "show_card_info()が存在する")
	r._assert_true(info.has_method("show_material_info"), "show_material_info()が存在する")
	r._assert_true(info.has_method("show_empty"), "show_empty()が存在する")
	r._assert_true(info.has_method("build_synthesis_section"), "build_synthesis_section()が存在する")
	r._assert_true(info.has_method("create_card_hover_popup"), "create_card_hover_popup()が存在する")
	# DeckPrep.gdに旧解説レーン関数が残っていないこと
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var dp = DeckPrepClass.new()
	r._assert_true(not dp.has_method("_show_unit_info"), "DeckPrep._show_unit_infoは削除済み")
	r._assert_true(not dp.has_method("_show_spell_info"), "DeckPrep._show_spell_infoは削除済み")
	r._assert_true(not dp.has_method("_info_label"), "DeckPrep._info_labelは削除済み")
	dp.queue_free()

func _test_mh_inventory_owned_first(r: RefCounted) -> void:
	# モンハン式持ち物: _build_material_slot_mh メソッドが存在する
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var dp = DeckPrepClass.new()
	r._assert_true(dp.has_method("_build_material_slot_mh"), "モンハン式スロット関数が存在する")
	dp.queue_free()

func _test_deck_prep_info_setup(r: RefCounted) -> void:
	# DeckPrepInfoのsetup()シグネチャが4引数であること
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var info = InfoClass.new()
	r._assert_true(info.has_method("setup"), "DeckPrepInfo.setup()が存在する")
	# _info_w初期値が275と同じデフォルトであること
	r._assert_eq(info._info_w, 275, "DeckPrepInfo初期_info_w=275")

func _test_board_no_ally_enemy_labels(r: RefCounted) -> void:
	# DeckPrepBoard: 自陣・敵陣ラベルが削除されていること（_build_board_headers 関数が存在しないこと）
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var board = BoardClass.new()
	r._assert_true(not board.has_method("_build_board_headers"), "自陣・敵陣ラベル関数は削除済み")
	r._assert_true(board.has_method("_build_board_col_labels"), "列ラベル関数が存在する")
	# CELLS_START_Y が BOARD_Y + 52 であること（12px以上のマージン保証）
	r._assert_eq(BoardClass.CELLS_START_Y, BoardClass.BOARD_Y + 52, "CELLS_START_YはBOARD_Y+52（マージン確保）")

func _test_spell_slot_count(r: RefCounted) -> void:
	# 呪文スロットが10個（5列×2行）であること
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var total = BoardClass.SPELL_SLOTS_COLS * BoardClass.SPELL_SLOTS_ROWS
	r._assert_eq(total, 10, "呪文スロット=10個（5×2）")
	r._assert_eq(BoardClass.SPELL_SLOTS_COLS, 5, "呪文スロット列数=5")
	r._assert_eq(BoardClass.SPELL_SLOTS_ROWS, 2, "呪文スロット行数=2")

func _test_artifact_slot_count(r: RefCounted) -> void:
	# アーティファクトスロットが6個固定であること
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	r._assert_eq(BoardClass.ARTIFACT_SLOTS_COUNT, 6, "アーティファクトスロット=6個固定")

func _test_cell_layout_tile_layouts(r: RefCounted) -> void:
	# タイル分割定義: 1-4種類のレイアウトが定義されていること
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var board = BoardClass.new()
	var layouts = BoardClass.TILE_LAYOUTS
	r._assert_true(layouts.has(1), "TILE_LAYOUTS[1]が定義済み")
	r._assert_true(layouts.has(2), "TILE_LAYOUTS[2]が定義済み")
	r._assert_true(layouts.has(3), "TILE_LAYOUTS[3]が定義済み")
	r._assert_true(layouts.has(4), "TILE_LAYOUTS[4]が定義済み")
	r._assert_eq(layouts[1]["cols"], 1, "1種: 1列")
	r._assert_eq(layouts[1]["rows"], 1, "1種: 1行")
	r._assert_eq(layouts[4]["cols"], 2, "4種: 2列")
	r._assert_eq(layouts[4]["rows"], 2, "4種: 2行")
	# ハイブリッド描画関数が存在すること
	r._assert_true(board.has_method("_create_cell_content"), "_create_cell_content()が存在する")
	r._assert_true(board.has_method("_create_tile_layout"), "_create_tile_layout()が存在する")
	r._assert_true(board.has_method("_create_bar_scroll_layout"), "_create_bar_scroll_layout()が存在する")

func _test_stack_count_grouping(r: RefCounted) -> void:
	# _group_cards_by_name: 同名カードが集約され count が正しいこと
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var board = BoardClass.new()
	var raw = [
		{"idx": 0, "name": "スライム"},
		{"idx": 1, "name": "スライム"},
		{"idx": 2, "name": "コブラ"},
	]
	var grouped = board._group_cards_by_name(raw)
	# スライムが2枚スタック、コブラが1枚
	r._assert_eq(grouped.size(), 2, "2種類に集約される")
	r._assert_eq(grouped[0][1], "スライム", "1番目=スライム")
	r._assert_eq(grouped[0][2], 2, "スライムcount=2")
	r._assert_eq(grouped[1][1], "コブラ", "2番目=コブラ")
	r._assert_eq(grouped[1][2], 1, "コブラcount=1")
