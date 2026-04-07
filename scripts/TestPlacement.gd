# TestPlacement.gd
# 配置ロジックテスト（PlacementLogic, placement_operations, persistence）
extends RefCounted

func run(runner: RefCounted) -> void:
	_test_placement_logic(runner)
	_test_placement_operations(runner)
	_test_persistence(runner)
	_test_spell_card_constraints(runner)
	_test_highlight_cells(runner)
	_test_spell_placement_enemy_side(runner)

func _test_placement_logic(r: RefCounted) -> void:
	var PL = load("res://scripts/PlacementLogic.gd")

	# ユニットは自陣OK、敵陣NG
	var unit_entry = {"name": "スライム", "col": 1}
	r._assert_eq(PL.can_place_ally(unit_entry), true, "ユニット: 自陣OK")
	r._assert_eq(PL.can_place_enemy(unit_entry), false, "ユニット: 敵陣NG")

	# 呪文の陣営判定
	var spell_entry = {"name": "召喚加速", "col": -1}
	r._assert_eq(PL.can_place_ally(spell_entry), true, "味方呪文: 自陣OK")

	# 効果範囲
	r._assert_eq(PL.get_effect_scope(unit_entry), "normal", "ユニット: normal")

	# デフォルトconfig生成（3×3対応）
	var test_deck = [
		{"name": "スライム", "col": 1},
		{"name": "ゴブリン", "col": 0},
		{"name": "召喚加速", "col": -1}
	]
	var config = PL.generate_default_config(test_deck)
	r._assert_eq(config.size(), 3, "config数=デッキ枚数")
	r._assert_eq(config[0]["side"], 0, "スライム: 自陣")
	r._assert_eq(config[0]["col"], 1, "スライムcol1→中列")
	r._assert_eq(config[0]["row"], 0, "ユニットデフォルト→上段(ラウンドロビン)")
	r._assert_eq(config[0]["fallback_same_col"], true, "デフォルトfallback=true")
	r._assert_eq(config[1]["col"], 0, "ゴブリンcol0→後列")
	r._assert_eq(config[2]["col"], -1, "呪文→列おまかせ")
	r._assert_eq(config[2]["side"], 0, "味方呪文→自陣")

func _test_placement_operations(r: RefCounted) -> void:
	var PL = load("res://scripts/PlacementLogic.gd")

	# テスト用デッキ
	var deck = [
		{"name": "スライム", "col": 1},
		{"name": "スライム", "col": 1},
		{"name": "ゴブリン", "col": 0},
		{"name": "召喚加速", "col": -1},
	]
	var config = PL.generate_default_config(deck)

	# --- move_card ---
	# ユニットを自陣内で移動 → OK
	r._assert_eq(PL.move_card(0, 0, 2, 2, deck, config), true, "move_card: ユニット自陣移動OK")
	r._assert_eq(config[0]["row"], 2, "move_card: row更新")
	r._assert_eq(config[0]["col"], 2, "move_card: col更新")

	# ユニットを敵陣に移動 → NG
	r._assert_eq(PL.move_card(0, 1, 0, 0, deck, config), false, "move_card: ユニット敵陣NG")
	r._assert_eq(config[0]["side"], 0, "move_card: side変わらず")

	# 範囲外インデックス → NG
	r._assert_eq(PL.move_card(-1, 0, 0, 0, deck, config), false, "move_card: 負インデックスNG")
	r._assert_eq(PL.move_card(99, 0, 0, 0, deck, config), false, "move_card: 超過インデックスNG")

	# --- move_group ---
	# スライム2枚をまとめて前列へ
	r._assert_eq(PL.move_group([0, 1], 0, 1, 2, deck, config), true, "move_group: 2枚移動OK")
	r._assert_eq(config[0]["col"], 2, "move_group: 0番col=2")
	r._assert_eq(config[1]["col"], 2, "move_group: 1番col=2")
	r._assert_eq(config[0]["row"], 1, "move_group: 0番row=1")
	r._assert_eq(config[1]["row"], 1, "move_group: 1番row=1")

	# ユニット含むグループを敵陣に → 全体NG（1枚も動かない）
	var prev_side_0 = config[0]["side"]
	var prev_side_2 = config[2]["side"]
	r._assert_eq(PL.move_group([0, 2], 1, 0, 0, deck, config), false, "move_group: ユニット含む敵陣NG")
	r._assert_eq(config[0]["side"], prev_side_0, "move_group: 0番side変わらず")
	r._assert_eq(config[2]["side"], prev_side_2, "move_group: 2番side変わらず")

	# --- get_same_name_group_in_cell ---
	# スライム2枚を同じセルに置いた状態
	config[0]["side"] = 0; config[0]["row"] = 0; config[0]["col"] = 1
	config[1]["side"] = 0; config[1]["row"] = 0; config[1]["col"] = 1
	var grp = PL.get_same_name_group_in_cell(0, deck, config)
	r._assert_eq(grp.size(), 2, "same_name_group: スライム2枚")
	r._assert_true(0 in grp, "same_name_group: idx0含む")
	r._assert_true(1 in grp, "same_name_group: idx1含む")

	# ゴブリンは別セルなので含まれない
	var grp2 = PL.get_same_name_group_in_cell(2, deck, config)
	r._assert_eq(grp2.size(), 1, "same_name_group: ゴブリン1枚")

	# --- get_cell_group ---
	var cell_grp = PL.get_cell_group(0, 0, 1, config)
	r._assert_eq(cell_grp.size(), 2, "cell_group: (0,0,1)に2枚")

	# 空セル
	var empty_grp = PL.get_cell_group(1, 2, 2, config)
	r._assert_eq(empty_grp.size(), 0, "cell_group: 空セル0枚")

	# --- get_row_group ---
	config[2]["side"] = 0; config[2]["row"] = 0; config[2]["col"] = 0
	# idx3(呪文)はrow=-1→正規化で0になるため上段に4枚
	var row_grp = PL.get_row_group(0, 0, config)
	r._assert_eq(row_grp.size(), 4, "row_group: 上段に4枚(スライム2+ゴブリン1+呪文1)")

	# 敵陣の行→呪文しかいない
	config[3]["side"] = 1; config[3]["row"] = 1; config[3]["col"] = 2
	var enemy_row = PL.get_row_group(1, 1, config)
	r._assert_eq(enemy_row.size(), 1, "row_group: 敵陣中段に1枚")

	# --- get_col_group ---
	var col_grp = PL.get_col_group(0, 1, config)
	r._assert_eq(col_grp.size(), 2, "col_group: 自陣中列に2枚(スライム2)")

	# --- Ctrl+クリック相当：1枚移動 ---
	# スライム2枚が(0,0,1)にいる状態で1枚だけ移動
	config[0]["side"] = 0; config[0]["row"] = 0; config[0]["col"] = 1
	config[1]["side"] = 0; config[1]["row"] = 0; config[1]["col"] = 1
	r._assert_eq(PL.move_card(0, 0, 2, 2, deck, config), true, "Ctrl移動: 1枚だけ前列へ")
	r._assert_eq(config[0]["col"], 2, "Ctrl移動: idx0がcol2")
	r._assert_eq(config[1]["col"], 1, "Ctrl移動: idx1はcol1のまま")

	# --- グループ維持移動：セル全選択後の移動 ---
	# idx0(前列)とidx1(中列)をグループとして後列へ
	r._assert_eq(PL.move_group([0, 1], 0, 1, 0, deck, config), true, "グループ維持移動OK")
	r._assert_eq(config[0]["col"], 0, "グループ移動: idx0がcol0")
	r._assert_eq(config[1]["col"], 0, "グループ移動: idx1がcol0")

	# --- resolve_placement テスト ---
	# 中列(col1)指定で空きマス優先(row=-1)
	var resolve_cfg = {"side": 0, "row": -1, "col": 1, "fallback_same_col": true}
	var empty_board = [
		[[null,null,null],[null,null,null],[null,null,null]],
		[[null,null,null],[null,null,null],[null,null,null]]
	]
	var pos = PL.resolve_placement(resolve_cfg, empty_board, empty_board)
	r._assert_true(pos[0] >= 0 and pos[0] <= 2, "resolve: 有効なrow")
	r._assert_eq(pos[1], 1, "resolve: col=1(中列)")

	# 前列(col2)指定
	var resolve_cfg2 = {"side": 0, "row": 0, "col": 2, "fallback_same_col": true}
	var pos2 = PL.resolve_placement(resolve_cfg2, empty_board, empty_board)
	r._assert_eq(pos2[0], 0, "resolve: row=0(上段)")
	r._assert_eq(pos2[1], 2, "resolve: col=2(前列)")

	# フォールバック: 指定セルが埋まっている→同列他行
	var partial_board = [
		[[null,null,null],[null,null,null],[null,null,null]],
		[[null,null,null],[null,null,null],[null,null,null]]
	]
	partial_board[0][0][1] = "occupied"  # (0,1)を埋める
	var resolve_cfg3 = {"side": 0, "row": 0, "col": 1, "fallback_same_col": true}
	var pos3 = PL.resolve_placement(resolve_cfg3, partial_board, partial_board)
	r._assert_true(pos3[0] > 0, "resolve fallback: row0が埋まり→他行")
	r._assert_eq(pos3[1], 1, "resolve fallback: col=1維持")

func _test_persistence(r: RefCounted) -> void:
	# --- UnitDataのpersistenceデフォルト ---
	var UDS = load("res://scripts/UnitData.gd")
	var u = UDS.new()
	r._assert_eq(u.persistence, "permanent", "UnitDataデフォルト: permanent")
	r._assert_eq(u.is_consumable, false, "UnitDataデフォルト: is_consumable=false")

	# --- cards.jsonの異常状態カードはpersistence=battle ---
	for name in CardDB.STATUS_SPELLS:
		var d = CardDB.STATUS_SPELLS[name]
		r._assert_eq(d.get("persistence", "permanent"), "battle",
			"STATUS_SPELLS[%s] persistence=battle" % name)

	# --- 通常ユニット/呪文はpersistence未設定（=permanent扱い） ---
	for name in CardDB.UNITS:
		var d = CardDB.UNITS[name]
		r._assert_eq(d.get("persistence", "permanent"), "permanent",
			"UNITS[%s] persistence=permanent" % name)
	for name in CardDB.SPELLS:
		var d = CardDB.SPELLS[name]
		r._assert_eq(d.get("persistence", "permanent"), "permanent",
			"SPELLS[%s] persistence=permanent" % name)

	# --- バトル中追加カード（clone+persistence設定）のシミュレーション ---
	var card = UDS.new()
	card.unit_name = "テストスライム"
	card.persistence = "battle"
	card.is_consumable = false
	r._assert_eq(card.persistence, "battle", "バトル中追加: persistence=battle")
	r._assert_eq(card.is_consumable, false, "バトル中追加: is_consumable=false（使用時残る）")

	# --- バトル後クリーンアップのシミュレーション ---
	var test_deck: Array = [
		{"name": "スライム", "persistence": "permanent"},
		{"name": "毒カード", "persistence": "battle"},
		{"name": "ラージスライム副産物", "persistence": "battle"},
		{"name": "ゴブリン", "persistence": "permanent"},
	]
	var after: Array = []
	for entry in test_deck:
		if entry.get("persistence", "permanent") != "battle":
			after.append(entry)
	r._assert_eq(after.size(), 2, "クリーンアップ後: battle除去→2枚残る")
	r._assert_eq(after[0]["name"], "スライム", "クリーンアップ後: スライム残る")
	r._assert_eq(after[1]["name"], "ゴブリン", "クリーンアップ後: ゴブリン残る")

# ---- 呪文カード配置制約テスト ----
func _test_spell_card_constraints(r: RefCounted) -> void:
	var PL = load("res://scripts/PlacementLogic.gd")

	# ユニットは常に盤面配置必須
	r._assert_eq(PL.requires_board_placement({"name": "スライム"}), true,
		"test_unit_card_no_slot_drop: ユニットは盤面配置必須")

	# AoE呪文（target: self）→呪文スロットのみ（盤面NG）
	r._assert_eq(PL.requires_board_placement({"name": "召喚加速"}), false,
		"test_spell_card_no_board_drop: 召喚加速(self)は盤面配置不要")

	# 単体狙い呪文（target: single_ally）→盤面配置必須
	r._assert_eq(PL.requires_board_placement({"name": "生命の雫"}), true,
		"test_unit_card_no_slot_drop: 生命の雫(single_ally)は盤面配置必須")

	# デフォルトconfig生成でAoE呪文→col=-1（呪文スロット）
	var deck_aoe = [{"name": "召喚加速"}]
	var config_aoe = PL.generate_default_config(deck_aoe)
	r._assert_eq(config_aoe[0]["col"], -1,
		"test_default_config_spell_assignment: AoE呪文→col=-1(呪文スロット)")

	# デフォルトconfig生成でユニット→col>=0（盤面）
	var deck_unit = [{"name": "スライム", "col": 1}]
	var config_unit = PL.generate_default_config(deck_unit)
	r._assert_true(config_unit[0]["col"] >= 0,
		"test_default_config_unit_assignment: ユニット→col>=0(盤面)")

	# デフォルトconfig生成で単体狙い呪文→col>=0（盤面）
	var deck_single = [{"name": "生命の雫"}]
	var config_single = PL.generate_default_config(deck_single)
	r._assert_true(config_single[0]["col"] >= 0,
		"test_default_config_spell_assignment: 単体狙い呪文→col>=0(盤面)")

# ---- ハイライトセルテスト ----
func _test_highlight_cells(r: RefCounted) -> void:
	var PL = load("res://scripts/PlacementLogic.gd")
	var heat_entry = {"name": "ヒートスライム"}

	# ヒートスライムを後列(side=0, col=0)に置いた時→敵前列全体(3マス)が赤ハイライト
	var highlights_back = PL.get_highlight_cells(heat_entry, 0, 1, 0)
	var red_cells = []
	for h in highlights_back:
		if h.get("color", "") == "red":
			red_cells.append(h)
	r._assert_true(red_cells.size() >= 3,
		"test_heatslime_support_range: 後列配置→敵前列3マス赤ハイライト")
	# 赤ハイライトが敵陣(side=1)前列(col=0)を指しているか確認
	var all_enemy_front = true
	for h in red_cells:
		if h.get("side", -1) != 1 or h.get("col", -1) != 0:
			all_enemy_front = false
	r._assert_true(all_enemy_front,
		"test_heatslime_support_range: 赤ハイライトがside=1,col=0(敵前列)のみ")

	# ヒートスライムを前列(side=0, col=2)に置いた時→ハイライトなし（サポート効果停止）
	var highlights_front = PL.get_highlight_cells(heat_entry, 0, 1, 2)
	r._assert_eq(highlights_front.size(), 0,
		"test_heatslime_no_range_in_front: 前列配置→ハイライトなし")

# ---- 呪文/アーティファクトの全エリア配置テスト ----
func _test_spell_placement_enemy_side(r: RefCounted) -> void:
	var PL = load("res://scripts/PlacementLogic.gd")

	# 単体狙い呪文（盤面配置必須）は敵陣にも配置可能
	var spell_single = {"name": "生命の雫"}
	r._assert_eq(PL.can_place_ally(spell_single), true,
		"test_spell_placement_enemy_side: 生命の雫は自陣OK")
	r._assert_eq(PL.can_place_enemy(spell_single), true,
		"test_spell_placement_enemy_side: 生命の雫は敵陣もOK（全エリア配置可）")

	# AoE呪文（盤面配置不要）は敵陣NG（呪文スロットのみ）
	var spell_aoe = {"name": "召喚加速"}
	r._assert_eq(PL.can_place_enemy(spell_aoe), false,
		"test_spell_placement_enemy_side: 召喚加速(AoE)は敵陣NG（スロットのみ）")

	# ユニットは敵陣NG
	var unit_entry = {"name": "スライム", "col": 1}
	r._assert_eq(PL.can_place_enemy(unit_entry), false,
		"test_spell_placement_enemy_side: ユニットは敵陣NG")
