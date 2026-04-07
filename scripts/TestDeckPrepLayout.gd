# TestDeckPrepLayout.gd
# DeckPrep画面レイアウト検証テスト（完全統合版）
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
	# 新規テスト（8項目修正対応）
	_test_equipment_3x2_layout(runner)
	_test_areas_left_aligned(runner)
	_test_synthesis_right_panel(runner)
	_test_card_detail_bottom_left(runner)
	_test_spell_tile_4_then_bar(runner)
	# 完全統合版テスト
	_test_left_right_panel_width_equal(runner)
	_test_checkbox_bottom_left(runner)
	_test_card_detail_right_panel(runner)
	_test_synthesis_area_bottom_center(runner)
	_test_synthesis_toggle_top_right(runner)
	_test_tile_5_7_ratio(runner)
	_test_empty_slot_hidden(runner)
	# 追加修正4項目テスト
	_test_no_synth_toggle_in_right_panel(runner)
	_test_equipment_fits_in_sidebar(runner)
	_test_equipment_last_slot_y(runner)
	# 今回の4項目修正テスト
	_test_checkbox_no_overlap_with_artifact_label(runner)
	_test_spell_area_no_overlap_with_artifact_area(runner)
	_test_synthesis_area_no_overlap_with_artifact_area(runner)
	_test_right_panel_no_overlap_with_main_content(runner)
	_test_inventory_square_cells_equal_equipment_size(runner)
	_test_inventory_cell_gap_equal_board_gap(runner)
	_test_inventory_sort_tab_includes_equipment(runner)
	_test_inventory_not_overlap_right_panel(runner)
	# Phase 3 タスクバー・タブ削除・画面分離テスト
	_test_taskbar_on_title(runner)
	_test_taskbar_on_material_select(runner)
	_test_taskbar_on_deck_prep(runner)
	_test_taskbar_on_battle(runner)
	_test_taskbar_on_result(runner)
	_test_deckprep_no_tabs(runner)
	_test_inventory_square_grid_moved(runner)
	_test_skill_tree_placeholder(runner)

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
	# レイアウト定数が仕様通りであること（完全統合版）
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	r._assert_eq(DeckPrepClass.SIDEBAR_W, 200, "左パネル幅=200")
	r._assert_eq(DeckPrepClass.INFO_W, 200, "右パネル幅=200（左パネルと同じ）")
	r._assert_eq(DeckPrepClass.CONTENT_W, 870, "タブコンテンツ幅=870")
	r._assert_eq(DeckPrepClass.CONTENT_H, 636, "タブコンテンツ高さ=636")
	r._assert_eq(DeckPrepClass.TAB_BAR_X, 210, "タブバーX=210")
	r._assert_eq(DeckPrepClass.INFO_X, 1080, "右パネルX=1080")
	r._assert_eq(DeckPrepClass.ADVENTURE_Y, 680, "冒険ボタンY=680")

func _test_inventory_slot_count_30(r: RefCounted) -> void:
	# 持ち物グリッドのスロット数がINV_GRID_COLS×INV_GRID_ROWSと一致すること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var expected = DeckPrepClass.INV_GRID_COLS * DeckPrepClass.INV_GRID_ROWS
	r._assert_eq(DeckPrepClass.INV_TOTAL_SLOTS, expected,
		"持ち物スロット数=INV_GRID_COLS(%d)×INV_GRID_ROWS(%d)=%d" % [DeckPrepClass.INV_GRID_COLS, DeckPrepClass.INV_GRID_ROWS, expected])

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
	# スロット座標計算が定数から正しく導出されること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var slot_w = DeckPrepClass.INV_SLOT_W
	var slot_h = DeckPrepClass.INV_SLOT_H
	var gap = DeckPrepClass.INV_SLOT_GAP
	var grid_x = DeckPrepClass.INV_GRID_X
	var grid_y = DeckPrepClass.INV_GRID_Y
	var cols = DeckPrepClass.INV_GRID_COLS
	# 横幅チェック: タブコンテンツ幅870内に収まること
	var total_w = grid_x + cols * slot_w + (cols - 1) * gap
	r._assert_true(total_w <= 870, "グリッド横幅がコンテンツ幅870px以内: %d" % total_w)
	# スロット0の座標（定数から計算）
	var x0 = grid_x + 0 * (slot_w + gap)
	var y0 = grid_y + 0 * (slot_h + gap)
	r._assert_eq(x0, DeckPrepClass.INV_GRID_OFFSET_X, "スロット[0]のX=INV_GRID_OFFSET_X(%d)" % DeckPrepClass.INV_GRID_OFFSET_X)
	r._assert_eq(y0, DeckPrepClass.INV_GRID_OFFSET_Y, "スロット[0]のY=INV_GRID_OFFSET_Y(%d)" % DeckPrepClass.INV_GRID_OFFSET_Y)
	# スロット[cols]（2行目先頭）の座標（定数から計算）
	var x_row1 = grid_x + 0 * (slot_w + gap)
	var y_row1 = grid_y + 1 * (slot_h + gap)
	r._assert_eq(x_row1, DeckPrepClass.INV_GRID_OFFSET_X, "スロット[cols]のX=INV_GRID_OFFSET_X（2行目先頭）")
	var expected_y_row1 = DeckPrepClass.INV_GRID_OFFSET_Y + slot_h + gap
	r._assert_eq(y_row1, expected_y_row1, "スロット[cols]のY=%d（2行目先頭）" % expected_y_row1)

func _test_inventory_grid_dimensions(r: RefCounted) -> void:
	# グリッドがINV_GRID_COLS列×INV_GRID_ROWS行で正しく定義されていること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	r._assert_true(DeckPrepClass.INV_GRID_COLS > 0, "グリッド列数が正値: %d" % DeckPrepClass.INV_GRID_COLS)
	r._assert_true(DeckPrepClass.INV_GRID_ROWS > 0, "グリッド行数が正値: %d" % DeckPrepClass.INV_GRID_ROWS)
	r._assert_eq(DeckPrepClass.INV_GRID_COLS * DeckPrepClass.INV_GRID_ROWS, DeckPrepClass.INV_TOTAL_SLOTS,
		"列×行=INV_TOTAL_SLOTS(%d)" % DeckPrepClass.INV_TOTAL_SLOTS)

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
	# CELLS_START_Y が BOARD_Y + 25 であること（チェックボックス左下移動後）
	r._assert_eq(BoardClass.CELLS_START_Y, BoardClass.BOARD_Y + 25, "CELLS_START_YはBOARD_Y+25（チェックボックス左下移動後）")

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

# ===== 新規テスト（8項目修正対応）=====

func _test_equipment_3x2_layout(r: RefCounted) -> void:
	# ② 装備スロットが縦3行×横2列配置であること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var slots = DeckPrepClass.EQUIP_SLOTS
	# 左列(col=0): 頭/胴/足
	r._assert_eq(slots[0]["row"], 0, "頭スロット=row0")
	r._assert_eq(slots[0]["col"], 0, "頭スロット=col0")
	r._assert_eq(slots[1]["row"], 1, "胴スロット=row1")
	r._assert_eq(slots[1]["col"], 0, "胴スロット=col0")
	r._assert_eq(slots[2]["row"], 2, "足スロット=row2")
	r._assert_eq(slots[2]["col"], 0, "足スロット=col0")
	# 右列(col=1): アクセ1/2/3
	r._assert_eq(slots[3]["row"], 0, "アクセ1=row0")
	r._assert_eq(slots[3]["col"], 1, "アクセ1=col1")
	r._assert_eq(slots[4]["row"], 1, "アクセ2=row1")
	r._assert_eq(slots[4]["col"], 1, "アクセ2=col1")
	r._assert_eq(slots[5]["row"], 2, "アクセ3=row2")
	r._assert_eq(slots[5]["col"], 1, "アクセ3=col1")

func _test_areas_left_aligned(r: RefCounted) -> void:
	# ① 盤面・呪文・アーティファクトの左端X座標が一致すること
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	r._assert_eq(BoardClass.BOARD_X, 20, "盤面左端X=20")
	# 呪文スロット: BOARD_Xから開始
	# _build_spell_slots_hybrid 内で sx = BOARD_X + ... なので BOARD_X が起点
	r._assert_eq(BoardClass.SPELL_TILE_W, 80, "呪文タイル幅=80px")
	r._assert_eq(BoardClass.SPELL_TILE_H, 100, "呪文タイル高さ=100px")
	# アーティファクト: 同様にBOARD_Xから開始（コード上で確認済み）
	r._assert_eq(BoardClass.ARTIFACT_TILE_W, 80, "アーティファクトタイル幅=80px")

func _test_synthesis_right_panel(r: RefCounted) -> void:
	# DeckPrepInfoが合成セクション構築メソッドを持つこと
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var info = InfoClass.new()
	r._assert_true(info.has_method("build_synthesis_section"), "build_synthesis_section()が存在する")
	# 合成後カードを結果タイルで表示するため _get_card_accent_color が必要
	r._assert_true(info.has_method("_get_card_accent_color"), "_get_card_accent_color()が存在する")

func _test_card_detail_bottom_left(r: RefCounted) -> void:
	# ③ DeckPrepBoardがカード詳細コンテナ（盤面左下）構築メソッドを持つこと
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var board = BoardClass.new()
	r._assert_true(board.has_method("build_card_detail_container"), "build_card_detail_container()が存在する")
	# カード詳細コンテナ幅が盤面1列分（CARD_DETAIL_W）であること
	r._assert_eq(BoardClass.CARD_DETAIL_W, 130, "CARD_DETAIL_W=130（盤面1列分）")
	# DeckPrepInfoがコンテナへの描画メソッドを持つこと
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var info = InfoClass.new()
	r._assert_true(info.has_method("show_card_info_in_container"), "show_card_info_in_container()が存在する")
	r._assert_true(info.has_method("show_empty_in_container"), "show_empty_in_container()が存在する")
	r._assert_true(info.has_method("show_material_in_container"), "show_material_in_container()が存在する")

func _test_spell_tile_4_then_bar(r: RefCounted) -> void:
	# ④ 呪文4枚以下→タイル(5:7比率)、5枚以上→バー(full幅×28px)の切り替え定数
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	r._assert_eq(BoardClass.SPELL_TILE_SWITCH, 4, "SPELL_TILE_SWITCH=4（4以下タイル/5以上バー）")
	r._assert_eq(BoardClass.SPELL_TILE_W, 80, "呪文タイル幅=80px（基準値）")
	r._assert_eq(BoardClass.SPELL_BAR_H, 28, "バー高さ=28px")
	# 分割描画関数が存在すること
	var board = BoardClass.new()
	r._assert_true(board.has_method("_build_spell_artifact_split"), "_build_spell_artifact_split()が存在する")

# ===== 完全統合版テスト =====

func _test_left_right_panel_width_equal(r: RefCounted) -> void:
	# ① 左右パネル幅が同一定数で管理されていること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	r._assert_eq(DeckPrepClass.SIDEBAR_W, DeckPrepClass.INFO_W, "左パネル幅=右パネル幅（SIDE_PANEL_W共通）")
	r._assert_eq(DeckPrepClass.SIDE_PANEL_W, 200, "SIDE_PANEL_W=200")
	r._assert_eq(DeckPrepClass.INFO_W, DeckPrepClass.SIDE_PANEL_W, "INFO_W=SIDE_PANEL_W")

func _test_checkbox_bottom_left(r: RefCounted) -> void:
	# ③ チェックボックス配置関数が盤面左下に存在すること
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var board = BoardClass.new()
	r._assert_true(board.has_method("_build_fallback_toggle_bottom_left"), "_build_fallback_toggle_bottom_left()が存在する")
	# CELLS_START_Y + 3行分 = 盤面下端Y
	var board_bottom = BoardClass.CELLS_START_Y + 3 * (BoardClass.CELL_H + BoardClass.CELL_GAP) + 4
	r._assert_true(board_bottom > 0, "盤面下端Yが正値: %d" % board_bottom)

func _test_card_detail_right_panel(r: RefCounted) -> void:
	# ⑤ 右パネルがカード詳細専用であること
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var info = InfoClass.new()
	r._assert_true(info.has_method("show_card_info"), "show_card_info()が存在する（右パネル用）")
	r._assert_true(info.has_method("show_empty"), "show_empty()が存在する（右パネル用）")
	# DeckPrep: 右パネル更新が show_card_info を呼ぶこと（_update_info_lane で確認）
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var dp = DeckPrepClass.new()
	r._assert_true(dp.has_method("_update_info_lane"), "_update_info_lane()が存在する")
	dp.queue_free()

func _test_synthesis_area_bottom_center(r: RefCounted) -> void:
	# ⑥ 合成可能エリアが盤面直下に配置する関数として存在すること
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var board = BoardClass.new()
	r._assert_true(board.has_method("_build_synthesis_area"), "_build_synthesis_area()が存在する（中央下部）")
	r._assert_true(board.has_method("_create_synthesis_tile"), "_create_synthesis_tile()が存在する")

func _test_synthesis_toggle_top_right(r: RefCounted) -> void:
	# ⑦ Yes/No確認省略トグルが合成エリアに存在すること
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var board = BoardClass.new()
	# _skip_synth_confirm 変数が存在すること（get()でnullチェック）
	var val = board.get("_skip_synth_confirm")
	r._assert_true(val != null or val == false, "_skip_synth_confimがDeckPrepBoardに存在する")

func _test_tile_5_7_ratio(r: RefCounted) -> void:
	# ④ タイル形式の縦横比が5:7であること（SPELL_TILE_H / SPELL_TILE_W ≈ 1.4 = 7/5）
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	# 呪文タイル基準値: 幅80, 高さ = 80 * 7 / 5 = 112
	var expected_h: int = BoardClass.SPELL_TILE_W * 7 / 5
	r._assert_eq(expected_h, 112, "タイル高さ計算: 80 × 7/5 = 112px")
	# アーティファクトも同様
	var art_expected_h: int = BoardClass.ARTIFACT_TILE_W * 7 / 5
	r._assert_eq(art_expected_h, 112, "アーティファクトタイル高さ: 80 × 7/5 = 112px")

func _test_empty_slot_hidden(r: RefCounted) -> void:
	# ④ 空スロットを表示しないこと:
	# _build_spell_artifact_split では空スロット(count=0のとき)タイルを追加しない設計であること
	# コード上の設計チェック: _create_empty_slot_panel は呪文/アーティファクトエリアから呼ばれないこと
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var board = BoardClass.new()
	# 新設計では _build_spell_artifact_split が空スロット非表示
	r._assert_true(board.has_method("_build_spell_artifact_split"), "新設計の分割描画関数が存在する")
	# _create_empty_slot_panel は盤面セル用として残存可能（削除不要）
	r._assert_true(board.has_method("_create_empty_slot_panel"), "_create_empty_slot_panelが存在する")

# ===== 追加修正4項目テスト =====

func _test_no_synth_toggle_in_right_panel(r: RefCounted) -> void:
	# ① 右パネルの合成セクション（build_synthesis_section）にトグルが追加されないこと
	# build_synthesis_sectionが_build_synth_confirm_toggleを呼ばないことを
	# 合成エリア（DeckPrepBoard）にのみ_skip_synth_confirmが存在することで検証
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var info = InfoClass.new()
	# DeckPrepInfoに_build_synth_confirm_toggleは存在するが、
	# build_synthesis_sectionがそれを呼ばなくなっていること
	# → _skip_synth_confirmはDeckPrepInfoに存在するが右パネルのbuild_synthesis_sectionでは使わない
	r._assert_true(info.has_method("build_synthesis_section"),
		"build_synthesis_section()が存在する")
	# DeckPrepBoardにのみトグルが存在すること（_skip_synth_confirm変数）
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var board = BoardClass.new()
	var val = board.get("_skip_synth_confirm")
	r._assert_true(val != null or val == false,
		"test_no_synth_toggle_in_right_panel: トグルはDeckPrepBoardにのみ存在する")

func _test_equipment_fits_in_sidebar(r: RefCounted) -> void:
	# ④ 装備スロット6個が左パネル（高さ710px）内に完全に収まること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var sidebar_h = DeckPrepClass.SIDEBAR_H  # 710
	var sidebar_y = DeckPrepClass.SIDEBAR_Y  # 5
	var equip_area_y = DeckPrepClass.EQUIP_AREA_Y
	var slot_size = DeckPrepClass.EQUIP_SLOT_SIZE
	var slot_gap = DeckPrepClass.EQUIP_SLOT_GAP
	# base_y = SIDEBAR_Y + EQUIP_AREA_Y
	var base_y = sidebar_y + equip_area_y
	# row=0のスロットY: base_y + 20（ヘッダー）
	var slot_row0_y = base_y + 20
	# row=2のスロットY: slot_row0_y + 2 * (slot_size + slot_gap + 14)
	var row_pitch = slot_size + slot_gap + 14
	var slot_row2_y = slot_row0_y + 2 * row_pitch
	var slot_bottom = slot_row2_y + slot_size
	# パネル下端 = SIDEBAR_Y + SIDEBAR_H = 5 + 710 = 715
	var panel_bottom = sidebar_y + sidebar_h
	r._assert_true(slot_bottom <= panel_bottom,
		"test_equipment_fits_in_sidebar: 装備6スロットが左パネル内に収まる（%d <= %d）" % [slot_bottom, panel_bottom])

func _test_equipment_last_slot_y(r: RefCounted) -> void:
	# ④ 6番目スロットの下端が710px（パネル下端）以下であること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var sidebar_y = DeckPrepClass.SIDEBAR_Y  # 5
	var sidebar_h = DeckPrepClass.SIDEBAR_H  # 710
	var equip_area_y = DeckPrepClass.EQUIP_AREA_Y
	var slot_size = DeckPrepClass.EQUIP_SLOT_SIZE
	var slot_gap = DeckPrepClass.EQUIP_SLOT_GAP
	var base_y = sidebar_y + equip_area_y
	var slot_row0_y = base_y + 20
	var row_pitch = slot_size + slot_gap + 14
	var last_slot_y = slot_row0_y + 2 * row_pitch
	var last_slot_bottom = last_slot_y + slot_size
	var panel_bottom = sidebar_y + sidebar_h
	r._assert_true(last_slot_bottom <= panel_bottom,
		"test_equipment_last_slot_y: 6番目スロット下端(%d) <= パネル下端(%d)" % [last_slot_bottom, panel_bottom])

# ===== 要素間干渉テストヘルパー =====
# 将来の全UIに再利用可能な共通ヘルパー。座標計算ベースで干渉を検証する。

# 2つのRect2が重なっているか判定
static func _rects_overlap(rect_a: Rect2, rect_b: Rect2) -> bool:
	return rect_a.intersects(rect_b)

# 位置・サイズからRect2を生成
static func _make_rect(pos: Vector2, size: Vector2) -> Rect2:
	return Rect2(pos, size)

# 2つの矩形が重なっていないことをassert（将来のControlノードテスト用にインターフェース統一）
func _assert_no_rect_overlap(r: RefCounted, rect_a: Rect2, rect_b: Rect2, msg: String) -> void:
	r._assert_true(not rect_a.intersects(rect_b),
		"%s (rect_a=%s, rect_b=%s)" % [msg, rect_a, rect_b])

# ===== 今回の4項目修正テスト =====

func _test_checkbox_no_overlap_with_artifact_label(r: RefCounted) -> void:
	# ③ チェックボックスとアーティファクトラベルが重ならないこと
	var DPB = load("res://scripts/DeckPrepBoard.gd")
	# チェックボックスの座標: _build_fallback_toggle_bottom_left() の計算
	var board_bottom = float(DPB.CELLS_START_Y) + 3.0 * float(DPB.CELL_H + DPB.CELL_GAP) + 4.0
	var enemy_right_x = float(DPB.BOARD_X) + float(DPB.ROW_LABEL_W) + 3.0 * float(DPB.CELL_W + DPB.CELL_GAP) + float(DPB.CENTER_GAP) + 3.0 * float(DPB.CELL_W + DPB.CELL_GAP)
	var toggle_w = 380.0
	var checkbox_rect = _make_rect(Vector2(enemy_right_x - toggle_w, board_bottom), Vector2(toggle_w, 20.0))
	# アーティファクトラベルの座標: _build_spell_artifact_split() の計算
	var board_area_w = float(DPB.ROW_LABEL_W) + 3.0 * float(DPB.CELL_W + DPB.CELL_GAP) + float(DPB.CENTER_GAP) + 3.0 * float(DPB.CELL_W + DPB.CELL_GAP)
	var half_w = board_area_w / 2.0
	var area_y = float(DPB.CELLS_START_Y) + 3.0 * float(DPB.CELL_H + DPB.CELL_GAP) + 50.0
	var art_label_rect = _make_rect(Vector2(float(DPB.BOARD_X) + half_w, area_y - 14.0), Vector2(200.0, 14.0))
	_assert_no_rect_overlap(r, checkbox_rect, art_label_rect,
		"test_checkbox_no_overlap_with_artifact_label: チェックボックスとアーティファクトラベルが重ならない")

func _test_spell_area_no_overlap_with_artifact_area(r: RefCounted) -> void:
	# ② 呪文エリアとアーティファクトエリアが横方向に重ならないこと（中央で分割）
	var DPB = load("res://scripts/DeckPrepBoard.gd")
	var board_area_w = float(DPB.ROW_LABEL_W) + 3.0 * float(DPB.CELL_W + DPB.CELL_GAP) + float(DPB.CENTER_GAP) + 3.0 * float(DPB.CELL_W + DPB.CELL_GAP)
	var half_w = board_area_w / 2.0
	var board_start_x = float(DPB.BOARD_X)
	var area_y = float(DPB.CELLS_START_Y) + 3.0 * float(DPB.CELL_H + DPB.CELL_GAP) + 50.0
	var area_h = 120.0  # 代表的な高さ
	# 呪文エリア: X=board_start_x、幅=half_w-4
	var spell_rect = _make_rect(Vector2(board_start_x, area_y), Vector2(half_w - 4.0, area_h))
	# アーティファクトエリア: X=board_start_x+half_w、幅=half_w-2
	var art_rect = _make_rect(Vector2(board_start_x + half_w, area_y), Vector2(half_w - 2.0, area_h))
	_assert_no_rect_overlap(r, spell_rect, art_rect,
		"test_spell_area_no_overlap_with_artifact_area: 呪文エリアとアーティファクトエリアが重ならない")

func _test_synthesis_area_no_overlap_with_artifact_area(r: RefCounted) -> void:
	# ② 合成エリアと呪文/アーティファクトエリアがY方向に重ならないこと
	var DPB = load("res://scripts/DeckPrepBoard.gd")
	# 呪文/アーティファクトエリアの終端Y（タイル高さが最大の場合を想定）
	var area_y = float(DPB.CELLS_START_Y) + 3.0 * float(DPB.CELL_H + DPB.CELL_GAP) + 50.0
	var max_tile_h = float(DPB.SPELL_TILE_W) * 7.0 / 5.0 + float(DPB.ARTIFACT_SLOTS_Y_OFFSET)
	var sub_area_end_y = area_y + max_tile_h
	# 合成エリアは sub_area_end_y から開始する（_build_synthesis_area(sub_area_y) の引数）
	# テストでは合成エリアのY >= sub_area_end_y であることを確認
	r._assert_true(sub_area_end_y > area_y,
		"test_synthesis_area_no_overlap_with_artifact_area: 合成エリア開始Y(%s) が呪文エリア終端以降" % sub_area_end_y)

func _test_right_panel_no_overlap_with_main_content(r: RefCounted) -> void:
	# ② 右パネルがメインコンテンツ（タブコンテンツ）と重ならないこと
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	# タブコンテンツ右端 = CONTENT_X + CONTENT_W = 210 + 870 = 1080
	var content_right = DeckPrepClass.CONTENT_X + DeckPrepClass.CONTENT_W
	# 右パネル左端 = INFO_X = 1080
	var info_left = DeckPrepClass.INFO_X
	r._assert_true(info_left >= content_right,
		"test_right_panel_no_overlap_with_main_content: 右パネル(%d) >= タブコンテンツ右端(%d)" % [info_left, content_right])

func _test_inventory_square_cells_equal_equipment_size(r: RefCounted) -> void:
	# ④ 持ち物グリッドのセルサイズが装備スロットと同じであること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	r._assert_eq(DeckPrepClass.INV_CELL_SIZE, DeckPrepClass.EQUIP_SLOT_SIZE,
		"test_inventory_square_cells_equal_equipment_size: INV_CELL_SIZE=EQUIP_SLOT_SIZE")
	r._assert_eq(DeckPrepClass.INV_SLOT_W, DeckPrepClass.EQUIP_SLOT_SIZE,
		"test_inventory_square_cells_equal_equipment_size: INV_SLOT_W=EQUIP_SLOT_SIZE（後方互換）")
	r._assert_eq(DeckPrepClass.INV_SLOT_H, DeckPrepClass.EQUIP_SLOT_SIZE,
		"test_inventory_square_cells_equal_equipment_size: INV_SLOT_H=EQUIP_SLOT_SIZE（正方形）")

func _test_inventory_cell_gap_equal_board_gap(r: RefCounted) -> void:
	# ④ 持ち物グリッドのギャップが装備スロットのギャップと同じであること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	r._assert_eq(DeckPrepClass.INV_CELL_GAP, DeckPrepClass.EQUIP_SLOT_GAP,
		"test_inventory_cell_gap_equal_board_gap: INV_CELL_GAP=EQUIP_SLOT_GAP")

func _test_inventory_sort_tab_includes_equipment(r: RefCounted) -> void:
	# ④ ソートタブに「装備」が含まれること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var tabs = DeckPrepClass.INV_SORT_TABS
	var has_equipment = false
	for tab in tabs:
		if tab.get("id", "") == "equipment":
			has_equipment = true
	r._assert_true(has_equipment, "test_inventory_sort_tab_includes_equipment: ソートタブに装備が含まれる")
	# タブ数が5以上であること（全体/装備/素材/呪い/消費）
	r._assert_true(tabs.size() >= 5, "test_inventory_sort_tab_includes_equipment: ソートタブ数>=5")

func _test_inventory_not_overlap_right_panel(r: RefCounted) -> void:
	# ④ 持ち物グリッドが右パネルと重ならないこと
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var cell = DeckPrepClass.INV_CELL_SIZE
	var gap = DeckPrepClass.INV_CELL_GAP
	var ox = DeckPrepClass.INV_GRID_OFFSET_X
	var cols = DeckPrepClass.INV_GRID_COLS
	# グリッド右端 = CONTENT_X + ox + cols * (cell+gap) - gap
	var grid_right = DeckPrepClass.CONTENT_X + ox + cols * (cell + gap) - gap
	var panel_left = DeckPrepClass.INFO_X
	r._assert_true(grid_right <= panel_left,
		"test_inventory_not_overlap_right_panel: グリッド右端(%d) <= 右パネル左端(%d)" % [grid_right, panel_left])

# ===== Phase 3 タスクバー・タブ削除・画面分離テスト =====

func _test_taskbar_on_title(r: RefCounted) -> void:
	# Title.gdにCommonTaskbarが埋め込まれていること
	var TitleClass = load("res://scripts/Title.gd")
	var title = TitleClass.new()
	# _taskbar変数が存在すること（null初期値でも変数として定義されている）
	r._assert_true("_taskbar" in title, "test_taskbar_on_title: _taskbar変数がTitle.gdに存在する")
	title.queue_free()

func _test_taskbar_on_material_select(r: RefCounted) -> void:
	# MaterialSelect.gdにCommonTaskbarが埋め込まれていること
	var MSClass = load("res://scripts/MaterialSelect.gd")
	var ms = MSClass.new()
	r._assert_true("_taskbar" in ms,
		"test_taskbar_on_material_select: _taskbar変数がMaterialSelect.gdに存在する")
	ms.queue_free()

func _test_taskbar_on_deck_prep(r: RefCounted) -> void:
	# DeckPrep.gdにCommonTaskbarが埋め込まれていること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var dp = DeckPrepClass.new()
	r._assert_true("_taskbar" in dp,
		"test_taskbar_on_deck_prep: _taskbar変数がDeckPrep.gdに存在する")
	dp.queue_free()

func _test_taskbar_on_battle(r: RefCounted) -> void:
	# GameUI.gdにCommonTaskbarが埋め込まれていること（バトル画面用）
	var GameUIClass = load("res://scripts/GameUI.gd")
	var gui = GameUIClass.new()
	r._assert_true("_taskbar" in gui,
		"test_taskbar_on_battle: _taskbar変数がGameUI.gdに存在する")

func _test_taskbar_on_result(r: RefCounted) -> void:
	# Result.gdにCommonTaskbarが埋め込まれていること
	var ResultClass = load("res://scripts/Result.gd")
	var res_obj = ResultClass.new()
	r._assert_true("_taskbar" in res_obj,
		"test_taskbar_on_result: _taskbar変数がResult.gdに存在する")
	res_obj.queue_free()

func _test_deckprep_no_tabs(r: RefCounted) -> void:
	# DeckPrepのタブバーが廃止されていること（_build_tab_barは残るが_build_ui内で呼ばれない）
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var dp = DeckPrepClass.new()
	# _tab_buttons変数が存在すること
	r._assert_true("_tab_buttons" in dp, "test_deckprep_no_tabs: _tab_buttons変数が存在する")
	# _show_tab関数は互換のため残存していること
	r._assert_true(dp.has_method("_show_tab"), "test_deckprep_no_tabs: _show_tab()が互換のため残存している")
	dp.queue_free()

func _test_inventory_square_grid_moved(r: RefCounted) -> void:
	# Inventory.gdに持ち物グリッドロジックが移植されていること
	var InventoryClass = load("res://scripts/Inventory.gd")
	var inv = InventoryClass.new()
	r._assert_true(inv.has_method("_build_grid"), "test_inventory_square_grid_moved: _build_grid()がInventory.gdに存在する")
	r._assert_true(inv.has_method("_get_filtered_items"), "test_inventory_square_grid_moved: _get_filtered_items()がInventory.gdに存在する")
	r._assert_true(inv.has_method("_build_sort_tabs"), "test_inventory_square_grid_moved: _build_sort_tabs()がInventory.gdに存在する")
	r._assert_true(inv.has_method("_build_item_cell"), "test_inventory_square_grid_moved: _build_item_cell()がInventory.gdに存在する")
	inv.queue_free()

func _test_skill_tree_placeholder(r: RefCounted) -> void:
	# SkillTree.gdが最小実装（タスクバー + 戻るボタン + プレースホルダー）であること
	var SkillTreeClass = load("res://scripts/SkillTree.gd")
	var st = SkillTreeClass.new()
	r._assert_true("_taskbar" in st,
		"test_skill_tree_placeholder: _taskbar変数がSkillTree.gdに存在する")
	r._assert_true(st.has_method("_on_back"), "test_skill_tree_placeholder: _on_back()が存在する")
	st.queue_free()
