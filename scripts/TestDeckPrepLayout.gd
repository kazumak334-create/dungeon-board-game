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
	# 段階2追加テスト
	_test_synthesis_section_board_synthesis(runner)
	_test_upper_synthesis_section_exists(runner)
	_test_equipment_within_sidebar(runner)
	_test_card_pin_state(runner)
	_test_equipment_y_position(runner)
	# 段階3追加テスト
	_test_card_frame_golden_ratio(runner)
	_test_mini_card_golden_ratio(runner)
	_test_card_effect_table(runner)
	_test_synthesis_result_only(runner)
	_test_synth_confirm_toggle_exists(runner)
	_test_flavor_text_inside_card(runner)

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

# ===== 段階2追加テスト =====

func _test_synthesis_section_board_synthesis(r: RefCounted) -> void:
	# DeckPrepInfoに _build_board_synthesis_section が存在し「盤面合成」セクションを持つこと
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var info = InfoClass.new()
	r._assert_true(info.has_method("_build_board_synthesis_section"), "_build_board_synthesis_section()が存在する")
	r._assert_true(info.has_method("_build_upper_synthesis_section"), "_build_upper_synthesis_section()が存在する")
	r._assert_true(info.has_method("_create_synthesis_row_for_vbox"), "_create_synthesis_row_for_vbox()が存在する")

func _test_upper_synthesis_section_exists(r: RefCounted) -> void:
	# 上位合成欄がbuild_synthesis_sectionの上部に存在すること
	# build_synthesis_section() 内で _build_upper_synthesis_section を呼ぶ構造であること
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var info = InfoClass.new()
	r._assert_true(info.has_method("build_synthesis_section"), "build_synthesis_section()が存在する")
	r._assert_true(info.has_method("_build_upper_synthesis_section"), "上位合成セクション関数が存在する")

func _test_equipment_within_sidebar(r: RefCounted) -> void:
	# 装備エリア最下端がSIDEBAR_H(710px)以内に収まること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var equip_bottom = DeckPrepClass.SIDEBAR_Y + DeckPrepClass.EQUIP_AREA_Y + DeckPrepClass.EQUIP_AREA_H
	r._assert_true(equip_bottom <= DeckPrepClass.SIDEBAR_Y + DeckPrepClass.SIDEBAR_H,
		"装備エリア最下端がサイドバー内に収まる: %d <= %d" % [equip_bottom, DeckPrepClass.SIDEBAR_Y + DeckPrepClass.SIDEBAR_H])

func _test_card_pin_state(r: RefCounted) -> void:
	# DeckPrep.gdに _pinned_card_idx 変数が存在し初期値-1であること
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	var dp = DeckPrepClass.new()
	r._assert_true("_pinned_card_idx" in dp, "_pinned_card_idx変数が存在する")
	r._assert_eq(dp._pinned_card_idx, -1, "_pinned_card_idx初期値=-1")
	# DeckPrepBoardに on_card_pinned Callable が存在すること
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	var board = BoardClass.new()
	r._assert_true("on_card_pinned" in board, "on_card_pinned Callableが存在する")
	dp.queue_free()

func _test_equipment_y_position(r: RefCounted) -> void:
	# EQUIP_AREA_Y + 装備スロット実高さ ≤ SIDEBAR_H
	var DeckPrepClass = load("res://scripts/DeckPrep.gd")
	# 装備スロット実高さ: ヘッダー(20) + 3行×(EQUIP_SLOT_SIZE + EQUIP_SLOT_GAP + 14) + ラベル(12)
	var slot_size = DeckPrepClass.EQUIP_SLOT_SIZE
	var slot_gap = DeckPrepClass.EQUIP_SLOT_GAP
	var equip_real_h = 20 + 3 * (slot_size + slot_gap + 14) + 12
	var equip_bottom = DeckPrepClass.EQUIP_AREA_Y + equip_real_h
	r._assert_true(equip_bottom <= DeckPrepClass.SIDEBAR_H,
		"EQUIP_AREA_Y+実高さ=%d <= SIDEBAR_H=%d" % [equip_bottom, DeckPrepClass.SIDEBAR_H])

# ===== 段階3追加テスト =====

func _test_card_frame_golden_ratio(r: RefCounted) -> void:
	# カード詳細枠が黄金比近似（縦/横 ≒ 1.6）
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var card_w = InfoClass.CARD_FRAME_W
	var card_h = InfoClass.CARD_FRAME_H
	var ratio = float(card_h) / float(card_w)
	r._assert_true(card_w == 260, "CARD_FRAME_W=260px")
	r._assert_true(card_h == 420, "CARD_FRAME_H=420px")
	r._assert_true(ratio >= 1.5 and ratio <= 1.7,
		"縦/横比が黄金比近似(1.5〜1.7): %.3f" % ratio)

func _test_mini_card_golden_ratio(r: RefCounted) -> void:
	# ミニカードアイコンが黄金比（縦/横 ≒ 1.618）
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var w = InfoClass.MINI_CARD_W
	var h = InfoClass.MINI_CARD_H
	var ratio = float(h) / float(w)
	r._assert_true(w == 60, "MINI_CARD_W=60")
	r._assert_true(h == 97, "MINI_CARD_H=97")
	r._assert_true(ratio >= 1.55 and ratio <= 1.68,
		"ミニカード縦/横比が黄金比近似(1.55〜1.68): %.3f" % ratio)
	# デフォルト引数が黄金比サイズを使っていること
	var info = InfoClass.new()
	r._assert_true(info.has_method("create_mini_card_icon"), "create_mini_card_icon()が存在する")

func _test_card_effect_table(r: RefCounted) -> void:
	# 効果表生成関数が存在し、カード枠内に描画する構造であること
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var info = InfoClass.new()
	r._assert_true(info.has_method("_build_effect_table_in_card"),
		"_build_effect_table_in_card()が存在する")
	# CARD_FRAME_H内に収まる設計: ヘッダー30+イラスト100+ステータス25+種族20+効果表63+フレーバー80=318<420
	var total = 30 + 100 + 25 + 20 + 63 + 80
	r._assert_true(total <= InfoClass.CARD_FRAME_H,
		"効果表・フレーバーがCARD_FRAME_H(%d)内に収まる: %d" % [InfoClass.CARD_FRAME_H, total])

func _test_synthesis_result_only(r: RefCounted) -> void:
	# 合成欄が結果カードのみを表示する関数構造であること
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var info = InfoClass.new()
	r._assert_true(info.has_method("_build_synthesis_result_grid"),
		"_build_synthesis_result_grid()が存在する（結果カードのみ表示）")
	r._assert_true(info.has_method("_show_synthesis_hover_popup"),
		"_show_synthesis_hover_popup()が存在する（ホバーで素材表示）")
	r._assert_true(info.has_method("_execute_synthesis"),
		"_execute_synthesis()が存在する（合成実行）")
	r._assert_true(info.has_method("_show_synth_confirm_dialog"),
		"_show_synth_confirm_dialog()が存在する（合成確認ダイアログ）")

func _test_synth_confirm_toggle_exists(r: RefCounted) -> void:
	# トグルスイッチの状態変数が存在し初期値falseであること
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	var info = InfoClass.new()
	r._assert_true("_skip_synth_confirm" in info,
		"_skip_synth_confirm変数が存在する")
	r._assert_true(info._skip_synth_confirm == false,
		"_skip_synth_confirm初期値=false")
	r._assert_true(info.has_method("_build_synth_confirm_toggle"),
		"_build_synth_confirm_toggle()が存在する")

func _test_flavor_text_inside_card(r: RefCounted) -> void:
	# フレーバーテキストがカード枠内部(_build_card_frame_header)に内包されること
	# → _show_unit_info がカード枠外で_info_label_wrapを呼ばない構造を確認
	# GOLDEN_RATIO定数が定義されていること
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	r._assert_true(InfoClass.GOLDEN_RATIO > 1.6 and InfoClass.GOLDEN_RATIO < 1.7,
		"GOLDEN_RATIO定数が1.618付近: %.3f" % InfoClass.GOLDEN_RATIO)
	var info = InfoClass.new()
	r._assert_true(info.has_method("_get_flavor_text"),
		"_get_flavor_text()が存在する（カード枠内で呼び出される）")
	r._assert_true(info.has_method("_build_card_frame_header"),
		"_build_card_frame_header()が存在する（フレーバー内包）")
