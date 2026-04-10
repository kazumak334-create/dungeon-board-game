# DeckPrepBoard.gd
# 配置タブの盤面UI・ドラッグ&ドロップ・ハイライト管理
extends RefCounted

const UIF = preload("res://scripts/UIFactory.gd")

# レイアウト定数
const BOARD_X = 20
const BOARD_Y = 5
const CELL_W = 118
const CELL_H = 105
const CELL_GAP = 3
const CENTER_GAP = 24
const ROW_LABEL_W = 35
const BOARD_H = BOARD_Y + 52 + 3 * (CELL_H + CELL_GAP) + 30
const INFO_W = 280

# 呪文スロット定数 (タイル最大4枚→80×100px, 5枚以上→バー形式)
const SPELL_TILE_W = 80
const SPELL_TILE_H = 100
const SPELL_TILE_GAP = 6
const SPELL_BAR_H = 28
const SPELL_BAR_GAP = 4
const SPELL_SLOTS_COLS = 5   # バー時の列数（後方互換）
const SPELL_SLOTS_ROWS = 2   # バー時の行数（後方互換）
const SPELL_SLOT_W = 78      # バー時の幅（後方互換）
const SPELL_SLOT_H = 38      # バー時の高さ（後方互換）
const SPELL_SLOT_GAP = 6     # バー時のギャップ（後方互換）
const SPELL_TILE_SWITCH = 4  # タイル→バー切り替え枚数（4以下タイル, 5以上バー）
const SPELL_SLOTS_Y = BOARD_H + 4

# v2設計: 手持ちカード（ユニット・呪文両対応）
const SPELL_HAND_TILE_W = 80
const SPELL_HAND_TILE_H = 100
const SPELL_HAND_TILE_GAP = 6
const SPELL_HAND_BAR_H = 28
const SPELL_HAND_BAR_GAP = 4
const SPELL_HAND_TILE_SWITCH = 4  # タイル→バー切り替え枚数（呪文デッキと同じ）
const SPELL_HAND_SLOTS_COUNT = 6

# 手持ちカードY（呪文デッキエリア下のオフセット）
const SPELL_HAND_Y_OFFSET = 12

# カード詳細エリア定数（盤面左下）
const CARD_DETAIL_W = 130   # 盤面1列分幅（约130px）
const CARD_DETAIL_H = 200   # カード詳細高さ

const RACE_COLORS = {
	"スライム": Color(0.3, 0.6, 0.3),
	"獣": Color(0.6, 0.4, 0.2),
	"アンデッド": Color(0.5, 0.3, 0.6),
}
const SPELL_COLOR = Color(0.3, 0.4, 0.6)
const DEFAULT_COLOR = Color(0.3, 0.3, 0.4)

# 外部参照（DeckPrep.gdからセット）
var main_node: Control = null
var tab_container: Control = null
var _PL = null
var on_card_selected: Callable = Callable()
var on_card_pinned: Callable = Callable()  # クリックピン留め通知（DeckPrep.gdが設定）

# 配置タブ状態
var _cell_rects: Array = []
var _cell_card_containers: Array = []
var _selected_card_idx: int = -1
var _dragging: bool = false
var _drag_node: Control = null
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_source_idx: int = -1
var _drag_group_indices: Array = []

func build_placement_tab(_tab_container_arg: Control, PL) -> void:
	tab_container = _tab_container_arg
	_PL = PL

	var enemy_x = BOARD_X + ROW_LABEL_W + 3 * (CELL_W + CELL_GAP) + CENTER_GAP
	# 自陣・敵陣ラベル完全削除 → 列ラベルのみ
	_build_board_col_labels(enemy_x)
	_build_board_cells(enemy_x)
	populate_cards()
	# ⑧⑨ 呪文デッキ（左半分）+ 手持ちカード（右半分）: 盤面直下
	var sub_area_y = _build_spell_artifact_split()
	# ⑥ 合成可能エリア（中央下部）
	_build_synthesis_area(sub_area_y)

# 自陣・敵陣ラベル完全削除 → 列ラベルのみ残す
func _build_board_col_labels(enemy_x: float) -> void:
	var ally_cols = ["後列", "中列", "前列"]
	var enemy_cols = ["前列", "中列", "後列"]
	# チェックボックスは左下に移動したため、列ラベルは盤面上部に直接配置
	var col_label_y = BOARD_Y + 5
	for ci in range(3):
		var al = Button.new()
		al.text = ally_cols[ci]
		al.flat = true
		al.position = Vector2(BOARD_X + ROW_LABEL_W + ci * (CELL_W + CELL_GAP), col_label_y)
		al.size = Vector2(CELL_W, 16)
		al.add_theme_font_size_override("font_size", 10)
		al.add_theme_color_override("font_color", Color(0.5, 0.65, 0.55))
		var ally_ci = ci
		al.pressed.connect(func(): select_col(0, ally_ci))
		tab_container.add_child(al)

		var el = Button.new()
		el.text = enemy_cols[ci]
		el.flat = true
		el.position = Vector2(enemy_x + ci * (CELL_W + CELL_GAP), col_label_y)
		el.size = Vector2(CELL_W, 16)
		el.add_theme_font_size_override("font_size", 10)
		el.add_theme_color_override("font_color", Color(0.65, 0.5, 0.5))
		var enemy_ci = ci
		el.pressed.connect(func(): select_col(1, enemy_ci))
		tab_container.add_child(el)

# セル行の開始Y（列ラベル5px + 16px + 4px余白 = 25px）
const CELLS_START_Y = BOARD_Y + 25

func _build_board_cells(enemy_x: float) -> void:
	var row_names = ["上段", "中段", "下段"]
	_cell_rects = [
		[[null,null,null],[null,null,null],[null,null,null]]
	]
	_cell_card_containers = [
		[[null,null,null],[null,null,null],[null,null,null]]
	]

	for ri in range(3):
		# 自陣行ラベル
		var rl_ally = Button.new()
		rl_ally.text = row_names[ri]
		rl_ally.flat = true
		rl_ally.position = Vector2(BOARD_X, CELLS_START_Y + ri * (CELL_H + CELL_GAP) + (CELL_H / 2) - 10)
		rl_ally.size = Vector2(ROW_LABEL_W, 20)
		rl_ally.add_theme_font_size_override("font_size", 10)
		rl_ally.add_theme_color_override("font_color", Color(0.5, 0.65, 0.55))
		var ally_ri = ri
		rl_ally.pressed.connect(func(): select_row(0, ally_ri))
		tab_container.add_child(rl_ally)

		for ci in range(3):
			var bx: float = BOARD_X + ROW_LABEL_W + ci * (CELL_W + CELL_GAP)
			var by = CELLS_START_Y + ri * (CELL_H + CELL_GAP)
			var cell = Panel.new()
			cell.position = Vector2(bx, by)
			cell.size = Vector2(CELL_W, CELL_H)
			var cell_style = StyleBoxFlat.new()
			cell_style.bg_color = Color(0.1, 0.12, 0.16)
			cell_style.border_color = Color(0.2, 0.3, 0.25)
			cell_style.set_border_width_all(1)
			cell.add_theme_stylebox_override("panel", cell_style)
			tab_container.add_child(cell)
			var vbox = VBoxContainer.new()
			vbox.position = Vector2(2, 2)
			vbox.size = Vector2(CELL_W - 4, CELL_H - 4)
			vbox.add_theme_constant_override("separation", 2)
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(vbox)
			_cell_rects[0][ri][ci] = cell
			_cell_card_containers[0][ri][ci] = vbox

			# 項目1: 役割アイコン追加（列ごと）
			_add_role_icon(cell, ci)

# 項目1: セル内に役割アイコンを描画（前列=攻撃、中列=両用、後列=盾）
func _add_role_icon(cell: Panel, col: int) -> void:
	const ICON_SIZE = 16.0
	const ICON_Y = 4.0  # セル上部
	const ICON_X = (CELL_W - ICON_SIZE) / 2.0  # 中央揃え

	var icon_container = Control.new()
	icon_container.position = Vector2(ICON_X, ICON_Y)
	icon_container.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon_container)

	if col == 2:
		# 前列: 攻撃アイコン（三角形）
		var attack_icon = ColorRect.new()
		attack_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		attack_icon.color = Color(0.9, 0.35, 0.35, 0.6)
		attack_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(attack_icon)
		# 三角形描画用のカスタムノード（簡易的に矩形で代用）
		# TODO: Polygon2Dで三角形実装予定
	elif col == 1:
		# 中列: 攻撃+盾アイコン（上下2段）
		var attack_top = ColorRect.new()
		attack_top.position = Vector2(0, 0)
		attack_top.size = Vector2(ICON_SIZE, ICON_SIZE / 2.0)
		attack_top.color = Color(0.9, 0.35, 0.35, 0.6)
		attack_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(attack_top)

		var shield_bottom = ColorRect.new()
		shield_bottom.position = Vector2(0, ICON_SIZE / 2.0)
		shield_bottom.size = Vector2(ICON_SIZE, ICON_SIZE / 2.0)
		shield_bottom.color = Color(0.5, 0.7, 0.9, 0.6)
		shield_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(shield_bottom)
	elif col == 0:
		# 後列: 盾アイコン（円形風矩形）
		var shield_icon = ColorRect.new()
		shield_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		shield_icon.color = Color(0.5, 0.7, 0.9, 0.6)
		shield_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(shield_icon)

func set_global_fallback(on: bool) -> void:
	for cfg in GameSession.placement_config:
		cfg["fallback_same_col"] = on

# ---- ハイブリッドセル内コンテンツ生成 ----

# タイル分割定義: 種類数→{cols, rows}
const TILE_LAYOUTS = {
	1: {"cols": 1, "rows": 1},
	2: {"cols": 1, "rows": 2},
	3: {"cols": 1, "rows": 3},
	4: {"cols": 2, "rows": 2},
}
const BAR_H = 18  # バー形式の1バー高さ

func _create_cell_content(cards: Array) -> Control:
	if cards.size() == 0:
		var empty = Control.new()
		empty.custom_minimum_size = Vector2(CELL_W - 4, CELL_H - 4)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return empty
	elif cards.size() <= 4:
		return _create_tile_layout(cards)
	else:
		return _create_bar_scroll_layout(cards)

func _create_tile_layout(cards: Array) -> Control:
	var kind = cards.size()
	var layout = TILE_LAYOUTS.get(kind, {"cols": 2, "rows": 2})
	var cols: int = layout["cols"]
	var rows: int = layout["rows"]

	var container = Control.new()
	container.custom_minimum_size = Vector2(CELL_W - 4, CELL_H - 4)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# v2設計: 初期配置保存用にカード名をメタに設定
	if cards.size() > 0:
		container.set_meta("card_name", cards[0]["name"])

	var available_w = float(CELL_W - 4)
	var available_h = float(CELL_H - 4)
	var tile_w = floorf((available_w - float(cols - 1)) / float(cols))
	var tile_h = floorf((available_h - float(rows - 1)) / float(rows))

	for i in range(cards.size()):
		var card = cards[i]
		var c_idx = i % cols
		var r_idx = i / cols
		var tx = float(c_idx) * (tile_w + 1.0)
		var ty = float(r_idx) * (tile_h + 1.0)
		var tile = _create_tile_chip(card["name"], card["count"], tile_w, tile_h,
			card["idx_first"], card["indices"])
		tile.position = Vector2(tx, ty)
		container.add_child(tile)

	return container

func _create_tile_chip(card_name: String, count: int, w: float, h: float,
		idx: int, all_indices: Array) -> Control:
	var card_color = get_card_color(card_name)
	var cost = get_card_cost(card_name)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(w, h)
	var style = StyleBoxFlat.new()
	style.bg_color = card_color.darkened(0.4)
	style.border_color = card_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", style)

	# ヘッダー帯（高さ14px or h*0.4の小さい方）
	var header_h = minf(14.0, h * 0.45)
	var header = ColorRect.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(w, header_h)
	header.color = card_color
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header)

	var font_size = 9 if h >= 47.0 else 8
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(2, 0)
	name_lbl.size = Vector2(w - 16, header_h)
	name_lbl.add_theme_font_size_override("font_size", font_size)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = str(cost)
	cost_lbl.position = Vector2(w - 14, 0)
	cost_lbl.size = Vector2(13, header_h)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.add_theme_font_size_override("font_size", font_size)
	cost_lbl.add_theme_color_override("font_color", Color(1, 1, 0.7))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cost_lbl)

	# HP/ATK（47px以上かつユニットのみ）
	if h >= 47.0 and CardDB.UNITS.has(card_name):
		var d = CardDB.UNITS[card_name]
		var stat_lbl = Label.new()
		stat_lbl.text = "HP%d AT%d" % [d.get("hp", 0), d.get("atk", 0)]
		stat_lbl.position = Vector2(2, header_h + 1)
		stat_lbl.size = Vector2(w - 4, h - header_h - 1)
		stat_lbl.add_theme_font_size_override("font_size", 8)
		stat_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(stat_lbl)

	# スタック数（右下、count>=2のみ）
	if count >= 2:
		var stack_lbl = Label.new()
		stack_lbl.text = "×%d" % count
		stack_lbl.position = Vector2(0, h - 13)
		stack_lbl.size = Vector2(w - 2, 13)
		stack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack_lbl.add_theme_font_size_override("font_size", 9)
		stack_lbl.add_theme_color_override("font_color", Color(1, 1, 0.5))
		stack_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(stack_lbl)

	panel.gui_input.connect(func(event): _on_chip_input(event, idx, all_indices, panel))
	return panel

func _create_bar_scroll_layout(cards: Array) -> Control:
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(CELL_W - 4, CELL_H - 4)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# v2設計: 初期配置保存用にカード名をメタに設定
	if cards.size() > 0:
		scroll.set_meta("card_name", cards[0]["name"])

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for card in cards:
		var bar = _create_bar_chip(card["name"], card["count"], CELL_W - 4, BAR_H,
			card["idx_first"], card["indices"])
		vbox.add_child(bar)

	return scroll

func _create_bar_chip(card_name: String, count: int, w: float, h: float,
		idx: int, all_indices: Array) -> Control:
	var card_color = get_card_color(card_name)
	var cost = get_card_cost(card_name)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(w, h)
	var style = StyleBoxFlat.new()
	style.bg_color = card_color.darkened(0.35)
	style.border_color = card_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var cost_lbl = Label.new()
	cost_lbl.text = "[%d]" % cost
	cost_lbl.position = Vector2(1, 0)
	cost_lbl.size = Vector2(22, h)
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(1, 1, 0.7))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cost_lbl)

	var stack_w = 20.0 if count >= 2 else 0.0
	var name_w = w - 22.0 - stack_w - 2.0
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(23, 0)
	name_lbl.size = Vector2(name_w, h)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)

	if count >= 2:
		var stack_lbl = Label.new()
		stack_lbl.text = "×%d" % count
		stack_lbl.position = Vector2(w - 22, 0)
		stack_lbl.size = Vector2(21, h)
		stack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack_lbl.add_theme_font_size_override("font_size", 10)
		stack_lbl.add_theme_color_override("font_color", Color(1, 1, 0.5))
		stack_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(stack_lbl)

	panel.gui_input.connect(func(event): _on_chip_input(event, idx, all_indices, panel))
	return panel


# ---- ⑧⑨ 呪文デッキ（敵盤面位置）+ 手持ちカード（盤面直下全幅）----

func _build_spell_artifact_split() -> float:
	var board_start_x = float(BOARD_X)
	var ally_board_w = float(ROW_LABEL_W) + 3.0 * float(CELL_W + CELL_GAP)

	# 項目3: 呪文デッキを盤面右側に縦長表示
	const SPELL_DECK_W = 200.0
	var spell_deck_x = board_start_x + ally_board_w + float(CENTER_GAP)
	var spell_deck_y = float(CELLS_START_Y) - 20.0  # ラベル込みで上端揃え

	# 呪文デッキ背景パネル（項目3: 存在感強化）
	var spell_bg = Panel.new()
	spell_bg.position = Vector2(spell_deck_x, spell_deck_y)
	spell_bg.size = Vector2(SPELL_DECK_W, 3.0 * float(CELL_H + CELL_GAP) + 20.0)
	spell_bg.set_meta("hand_spell_area", true)
	var spell_bg_style = StyleBoxFlat.new()
	spell_bg_style.bg_color = Color(0.13, 0.13, 0.2)  # MaterialSelect COLOR_PANEL準拠
	spell_bg_style.border_color = Color(0.4, 0.45, 0.6)  # 強調色
	spell_bg_style.set_border_width_all(2)
	spell_bg.add_theme_stylebox_override("panel", spell_bg_style)
	tab_container.add_child(spell_bg)

	# 呪文デッキラベル（項目3: 大きく表示）
	var spell_lbl = Label.new()
	spell_lbl.text = "呪文デッキ"
	spell_lbl.position = Vector2(spell_deck_x + 10.0, spell_deck_y + 4.0)
	spell_lbl.add_theme_font_size_override("font_size", 14)  # 11→14に拡大
	spell_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.85))
	spell_lbl.set_meta("hand_spell_area", true)
	tab_container.add_child(spell_lbl)

	# 呪文カード描画（縦長配置）
	var spell_cards = _build_spell_cards_list()
	var spell_count = spell_cards.size()
	var card_start_y = spell_deck_y + 28.0  # ラベル下から

	# 縦並びバー形式（横幅はパネルに合わせる）
	var bar_w = SPELL_DECK_W - 20.0  # 左右余白10pxずつ
	for i in range(spell_count):
		var sy = card_start_y + float(i) * float(SPELL_BAR_H + SPELL_BAR_GAP)
		var bar = _create_bar_chip(spell_cards[i][1], spell_cards[i][2], bar_w, float(SPELL_BAR_H), spell_cards[i][0], spell_cards[i][3])
		bar.position = Vector2(spell_deck_x + 10.0, sy)
		bar.set_meta("hand_spell_area", true)
		tab_container.add_child(bar)

	# 項目2: 手持ちカードを2エリアに分離（ユニット・呪文）
	var hand_area_y = float(CELLS_START_Y) + 3.0 * float(CELL_H + CELL_GAP) + 4.0
	var hand_cards = _build_hand_cards_list()

	# ユニット・呪文に分離
	var unit_cards: Array = []
	var spell_hand_cards: Array = []
	for hc in hand_cards:
		var card_name = hc[1]
		if CardDB.UNITS.has(card_name):
			unit_cards.append(hc)
		elif CardDB.SPELLS.has(card_name) or CardDB.STATUS_SPELLS.has(card_name):
			spell_hand_cards.append(hc)
		else:
			# 種別不明は一旦ユニット扱い
			unit_cards.append(hc)

	# ユニットエリア（左側）
	var unit_lbl = Label.new()
	unit_lbl.text = "ユニット"
	unit_lbl.position = Vector2(board_start_x, hand_area_y - 14.0)
	unit_lbl.add_theme_font_size_override("font_size", 11)
	unit_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))  # 緑系
	unit_lbl.set_meta("hand_spell_area", true)
	tab_container.add_child(unit_lbl)

	var unit_container = _build_hand_card_container(unit_cards, board_start_x, hand_area_y)
	unit_container.set_meta("hand_spell_area", true)
	tab_container.add_child(unit_container)

	# 呪文エリア（右側）
	var spell_hand_x = board_start_x + ally_board_w / 2.0 + 10.0
	var spell_hand_lbl = Label.new()
	spell_hand_lbl.text = "呪文"
	spell_hand_lbl.position = Vector2(spell_hand_x, hand_area_y - 14.0)
	spell_hand_lbl.add_theme_font_size_override("font_size", 11)
	spell_hand_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.85))  # 青系
	spell_hand_lbl.set_meta("hand_spell_area", true)
	tab_container.add_child(spell_hand_lbl)

	var spell_hand_container = _build_hand_card_container(spell_hand_cards, spell_hand_x, hand_area_y)
	spell_hand_container.set_meta("hand_spell_area", true)
	tab_container.add_child(spell_hand_container)

	# 固定高さ（カード高さ130px + ホバー余白40px + ラベル余白）
	var hand_area_h = 130.0 + 40.0 + float(SPELL_HAND_Y_OFFSET)

	# 手持ちカード下境界線
	var hand_border = ColorRect.new()
	hand_border.position = Vector2(board_start_x, hand_area_y + hand_area_h - float(SPELL_HAND_Y_OFFSET))
	hand_border.size = Vector2(ally_board_w - float(BOARD_X), 1.0)
	hand_border.color = Color(0.3, 0.35, 0.45, 0.7)
	hand_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_container.add_child(hand_border)

	return hand_area_y + hand_area_h

# ---- ⑥ 合成可能エリア（盤面直下・中央）+ ⑦ Yes/No確認省略トグル ----

func _build_synthesis_area(start_y: float) -> void:
	var board_area_w = float(ROW_LABEL_W) + 3.0 * float(CELL_W + CELL_GAP) + float(CENTER_GAP) + 3.0 * float(CELL_W + CELL_GAP)
	var board_start_x = float(BOARD_X)

	# ⑦ Yes/No省略トグル（合成エリア右上角）
	var toggle = CheckBox.new()
	toggle.text = "確認省略"
	toggle.button_pressed = false
	toggle.position = Vector2(board_start_x + board_area_w - 90.0, start_y)
	toggle.size = Vector2(90.0, 20.0)
	toggle.add_theme_font_size_override("font_size", 10)
	toggle.toggled.connect(func(on: bool): _skip_synth_confirm = on)
	tab_container.add_child(toggle)

	# 合成ヘッダーラベル
	var header = Label.new()
	header.text = "合成可能"
	header.position = Vector2(board_start_x, start_y)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.5))
	tab_container.add_child(header)

	# 合成可能なカードのみタイル形式で横並び（素材不足は非表示）
	var card_counts: Dictionary = {}
	for entry in GameSession.selected_deck:
		var n = entry.get("name", "") if entry is Dictionary else str(entry)
		card_counts[n] = card_counts.get(n, 0) + 1

	var craftable: Array = []
	for recipe in CardDB.SYNTHESIS:
		var base = recipe.get("base", "")
		var card = recipe.get("card", "")
		var result_name = recipe.get("result", "")
		var needed: Dictionary = {}
		needed[base] = needed.get(base, 0) + 1
		needed[card] = needed.get(card, 0) + 1
		var can_craft = true
		for n in needed:
			if card_counts.get(n, 0) < needed[n]:
				can_craft = false
				break
		if can_craft:
			craftable.append({"base": base, "card": card, "result": result_name})

	var tile_area_y = start_y + 20.0
	var tile_w = 56.0  # 縦横比5:7維持
	var tile_h = tile_w * 7.0 / 5.0
	var tile_gap = 6.0
	var x_cur = board_start_x

	for craft in craftable:
		if x_cur + tile_w > board_start_x + board_area_w:
			break
		var tile = _create_synthesis_tile(craft["result"], craft["base"], craft["card"], tile_w, tile_h)
		tile.position = Vector2(x_cur, tile_area_y)
		tab_container.add_child(tile)
		x_cur += tile_w + tile_gap

# 合成タイル生成（⑥用）
var _skip_synth_confirm: bool = false

func _create_synthesis_tile(result_name: String, base_name: String, mat_name: String, w: float, h: float) -> Control:
	var card_color = get_card_color(result_name)
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(w, h)
	var style = StyleBoxFlat.new()
	style.bg_color = card_color.darkened(0.4)
	style.border_color = card_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)

	var header_h = minf(14.0, h * 0.35)
	var header = ColorRect.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(w, header_h)
	header.color = card_color
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header)

	var cost_lbl = Label.new()
	cost_lbl.text = str(get_card_cost(result_name))
	cost_lbl.position = Vector2(2, 0)
	cost_lbl.size = Vector2(w - 4, header_h)
	cost_lbl.add_theme_font_size_override("font_size", 8)
	cost_lbl.add_theme_color_override("font_color", Color(1, 1, 0.7))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cost_lbl)

	var name_lbl = Label.new()
	name_lbl.text = result_name
	name_lbl.position = Vector2(2, header_h + 1)
	name_lbl.size = Vector2(w - 4, h - header_h - 1)
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)

	# ホバー: 素材情報ポップアップ
	panel.mouse_entered.connect(func():
		if main_node != null:
			_show_synth_hover_popup(result_name, base_name, mat_name, panel.global_position + Vector2(w / 2.0, -90.0))
	)
	panel.mouse_exited.connect(func(): _hide_synth_hover_popup())

	# クリック: 合成確認 or 即合成
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _skip_synth_confirm:
				print("[DeckPrepBoard] 合成: [%s] + [%s] → [%s]" % [base_name, mat_name, result_name])
			else:
				_show_synth_confirm(result_name, base_name, mat_name)
	)
	return panel

var _synth_hover_popup: Control = null

func _show_synth_hover_popup(result_name: String, base_name: String, mat_name: String, pos: Vector2) -> void:
	_hide_synth_hover_popup()
	if main_node == null:
		return
	var popup = PanelContainer.new()
	popup.z_index = 200
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	style.border_color = Color(0.4, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	popup.add_theme_stylebox_override("panel", style)
	popup.custom_minimum_size = Vector2(160, 60)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	popup.add_child(vbox)
	var res_lbl = Label.new()
	res_lbl.text = "▶ %s" % result_name
	res_lbl.add_theme_font_size_override("font_size", 11)
	res_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	vbox.add_child(res_lbl)
	var mat_lbl = Label.new()
	mat_lbl.text = "[%s] + [%s]" % [base_name, mat_name]
	mat_lbl.add_theme_font_size_override("font_size", 9)
	mat_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(mat_lbl)
	var synth_hint = Label.new()
	synth_hint.text = "クリックで合成"
	synth_hint.add_theme_font_size_override("font_size", 9)
	synth_hint.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))
	vbox.add_child(synth_hint)
	popup.position = pos
	main_node.add_child(popup)
	_synth_hover_popup = popup

func _hide_synth_hover_popup() -> void:
	if _synth_hover_popup != null:
		_synth_hover_popup.queue_free()
		_synth_hover_popup = null

func _show_synth_confirm(result_name: String, base_name: String, mat_name: String) -> void:
	if main_node == null:
		return
	var existing = main_node.find_child("SynthConfirmBoardDialog", false, false)
	if existing:
		existing.queue_free()
	var dialog = Panel.new()
	dialog.name = "SynthConfirmBoardDialog"
	dialog.z_index = 300
	dialog.size = Vector2(240, 110)
	dialog.position = Vector2((main_node.size.x - 240) / 2.0, (main_node.size.y - 110) / 2.0)
	var dstyle = StyleBoxFlat.new()
	dstyle.bg_color = Color(0.1, 0.1, 0.18, 0.97)
	dstyle.border_color = Color(0.5, 0.5, 0.7)
	dstyle.set_border_width_all(2)
	dstyle.set_corner_radius_all(6)
	dialog.add_theme_stylebox_override("panel", dstyle)
	main_node.add_child(dialog)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(220, 90)
	dialog.add_child(vbox)
	var msg = Label.new()
	msg.text = "%s を合成しますか？" % result_name
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.add_theme_font_size_override("font_size", 13)
	msg.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	vbox.add_child(msg)
	var sub = Label.new()
	sub.text = "[%s] + [%s]" % [base_name, mat_name]
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	sub.clip_text = true
	vbox.add_child(sub)
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_hbox)
	var yes_btn = Button.new()
	yes_btn.text = "合成する"
	yes_btn.add_theme_font_size_override("font_size", 12)
	yes_btn.pressed.connect(func():
		print("[DeckPrepBoard] 合成実行: [%s] + [%s] → [%s]" % [base_name, mat_name, result_name])
		dialog.queue_free()
	)
	btn_hbox.add_child(yes_btn)
	var no_btn = Button.new()
	no_btn.text = "キャンセル"
	no_btn.add_theme_font_size_override("font_size", 12)
	no_btn.pressed.connect(func(): dialog.queue_free())
	btn_hbox.add_child(no_btn)

func _create_empty_slot_panel(w: float, h: float, border_color: Color) -> Control:
	var p = Panel.new()
	p.custom_minimum_size = Vector2(w, h)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12)
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", style)
	return p

# ---- カード詳細コンテナ（盤面左下）----

func build_card_detail_container(_tc: Control) -> Control:
	# 盤面グリッドの左端・下端座標を計算
	var detail_x = float(BOARD_X)
	var board_bottom = float(CELLS_START_Y) + 3.0 * float(CELL_H + CELL_GAP) + 4.0
	var detail = Panel.new()
	detail.position = Vector2(detail_x, board_bottom)
	detail.size = Vector2(float(CARD_DETAIL_W), float(CARD_DETAIL_H))
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.11)
	style.border_color = Color(0.2, 0.2, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	detail.add_theme_stylebox_override("panel", style)
	_tc.add_child(detail)
	return detail

func populate_cards() -> void:
	# 盤面セルのクリア
	for ri in range(3):
		for ci in range(3):
			var vbox = _cell_card_containers[0][ri][ci]
			if vbox != null:
				for child in vbox.get_children():
					child.queue_free()

	# 手持ちカードエリア・呪文デッキエリアのクリア（メタデータを持つノードを削除）
	for child in tab_container.get_children():
		if child.has_meta("hand_spell_area"):
			child.queue_free()

	var cell_cards = _build_cell_cards_map()

	for key in cell_cards:
		var parts = key.split("_")
		var si = int(parts[0]); var ri = int(parts[1]); var ci = int(parts[2])
		if si != 0:
			continue
		var vbox = _cell_card_containers[0][ri][ci]
		if vbox == null:
			continue
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# v2設計: 1セルに1枚まで（グループ化なし）
		var cards = cell_cards[key]
		if cards.size() > 0:
			var card = cards[0]
			var card_defs: Array = [{"name": card["name"], "count": 1, "idx_first": card["idx"], "indices": [card["idx"]]}]
			var content = _create_cell_content(card_defs)
			vbox.add_child(content)

		# セル操作（Panelのgui_input）
		var cell_panel = _cell_rects[0][ri][ci]
		if cell_panel != null and not cell_panel.has_meta("click_connected"):
			var r = ri; var c = ci
			cell_panel.gui_input.connect(func(event):
				if _dragging:
					return
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if event.double_click:
						# ダブルクリック → セル内全カード選択
						select_cell(0, r, c)
					else:
						# シングルクリック → 選択リセット
						_selected_card_idx = -1
						_drag_group_indices = []
						if on_card_selected.is_valid():
							on_card_selected.call(-1)
			)
			cell_panel.set_meta("click_connected", true)

	# 手持ちカードエリア・呪文デッキエリアの再描画
	_build_spell_artifact_split()

func _build_cell_cards_map() -> Dictionary:
	var result: Dictionary = {}
	for i in range(GameSession.selected_deck.size()):
		var entry = GameSession.selected_deck[i]
		var config = GameSession.placement_config[i] if i < GameSession.placement_config.size() else {}
		var col = config.get("col", -1)
		# col=-1 は呪文スロット扱い → 盤面セルには含めない
		if col < 0:
			continue
		var side = config.get("side", 0)
		var row = max(0, config.get("row", 0))
		var key = "%d_%d_%d" % [side, row, col]
		# v2設計: 1セルに1枚まで（既に存在する場合はスキップ）
		if result.has(key):
			continue
		result[key] = []
		var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
		result[key].append({"idx": i, "name": card_name})
	return result

# 呪文スロット用カードリスト（col=-1 かつ row=0 のカードを集約して返す）
func _build_spell_cards_list() -> Array:
	var raw: Array = []
	for i in range(GameSession.selected_deck.size()):
		var entry = GameSession.selected_deck[i]
		var config = GameSession.placement_config[i] if i < GameSession.placement_config.size() else {}
		var col = config.get("col", -1)
		var row = config.get("row", 0)
		# v2設計: col=-1 かつ row=0 が呪文デッキ
		if col >= 0 or row != 0:
			continue
		var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
		# カード種別フィルター: 呪文のみ許可
		if not (CardDB.SPELLS.has(card_name) or CardDB.STATUS_SPELLS.has(card_name)):
			continue
		raw.append({"idx": i, "name": card_name})
	return _group_cards_by_name(raw)

# 手持ちカード用カードリスト（col=-1 かつ row=1 のカードを集約して返す）
func _build_hand_cards_list() -> Array:
	var raw: Array = []
	for i in range(GameSession.selected_deck.size()):
		var entry = GameSession.selected_deck[i]
		var config = GameSession.placement_config[i] if i < GameSession.placement_config.size() else {}
		var col = config.get("col", -1)
		var row = config.get("row", 0)
		# v2設計: col=-1 かつ row=1 が手持ちカード（ユニット・呪文両対応）
		if col >= 0 or row != 1:
			continue
		var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
		raw.append({"idx": i, "name": card_name})
	return _group_cards_by_name(raw)

func _group_cards_by_name(cards: Array) -> Array:
	var groups: Dictionary = {}
	var order: Array = []
	for card in cards:
		if not groups.has(card["name"]):
			groups[card["name"]] = {"count": 0, "idx_first": card["idx"], "indices": []}
			order.append(card["name"])
		groups[card["name"]]["count"] += 1
		groups[card["name"]]["indices"].append(card["idx"])
	var out: Array = []
	for gname in order:
		var g = groups[gname]
		out.append([g["idx_first"], gname, g["count"], g["indices"]])
	return out

# 手持ちカード新UI: 縦長カード形式（重なり配置）
func _build_hand_card_container(hand_cards: Array, start_x: float, start_y: float) -> Control:
	const CARD_W = 90.0
	const CARD_H = 130.0
	const OVERLAP_W = 22.0  # 左側1/4重なり

	var container = Control.new()
	container.position = Vector2(start_x, start_y)

	var CardSlotScript = load("res://scripts/CardSlot.gd")

	for i in range(hand_cards.size()):
		var hc = hand_cards[i]
		var idx = hc[0]
		var card_name = hc[1]
		var count = hc[2]
		var indices = hc[3]

		var slot = Control.new()
		slot.set_script(CardSlotScript)
		slot.position = Vector2(float(i) * (CARD_W - OVERLAP_W), 0.0)
		slot.z_index = i  # 左端が背面、右端が前面

		var card_color = get_card_color(card_name)
		var card_cost = get_card_cost(card_name)

		container.add_child(slot)
		slot.setup(card_name, card_cost, count, indices, card_color)

		# クリック時のコールバック設定
		slot.on_card_clicked = func(clicked_idx: int, event: InputEvent):
			_on_chip_input_from_slot(event, clicked_idx, indices, slot)

		# ホバー時のz_index保持用
		var original_z = i
		slot.card_hovered.connect(func(_s): slot.z_index = 100)
		slot.card_unhovered.connect(func(_s): slot.z_index = original_z)

	# 空配列対応: 最小サイズは0
	var container_w = CARD_W + float(max(0, hand_cards.size() - 1)) * (CARD_W - OVERLAP_W) if hand_cards.size() > 0 else 0.0
	container.custom_minimum_size = Vector2(container_w, CARD_H)
	return container

func _on_chip_input_from_slot(event: InputEvent, idx: int, all_indices: Array, slot: Control) -> void:
	# 既存のドラッグロジックに接続
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	_selected_card_idx = idx
	_drag_group_indices = [idx]
	if on_card_selected.is_valid(): on_card_selected.call(idx)
	if on_card_pinned.is_valid(): on_card_pinned.call(idx)
	start_drag_group(idx, [idx], slot, event.global_position)

func _on_chip_input(event: InputEvent, idx: int, all_indices: Array, chip: Control) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	chip.accept_event()
	# グループドラッグ廃止: 常に1枚のみドラッグ
	_selected_card_idx = idx
	_drag_group_indices = [idx]
	if on_card_selected.is_valid(): on_card_selected.call(idx)
	# ピン留め通知（ドラッグ開始前に通知してDeckPrep.gdがピン留め状態を管理）
	if on_card_pinned.is_valid(): on_card_pinned.call(idx)
	start_drag_group(idx, [idx], chip, event.global_position)

func get_card_color(card_name: String) -> Color:
	if CardDB.UNITS.has(card_name):
		return RACE_COLORS.get(CardDB.UNITS[card_name].get("race", ""), DEFAULT_COLOR)
	return SPELL_COLOR

func get_card_cost(card_name: String) -> int:
	if CardDB.UNITS.has(card_name):
		return CardDB.UNITS[card_name].get("cost", 0)
	if CardDB.SPELLS.has(card_name):
		return CardDB.SPELLS[card_name].get("cost", 0)
	if CardDB.STATUS_SPELLS.has(card_name):
		return CardDB.STATUS_SPELLS[card_name].get("cost", 0)
	return 0

# ---- ドラッグ&ドロップ ----

func start_cell_drag(si: int, ri: int, ci: int, source_node: Control, mouse_pos: Vector2) -> void:
	var group = _PL.get_cell_group(si, ri, ci, GameSession.placement_config)
	if group.size() == 0:
		return
	# グループドラッグ廃止: 先頭1枚のみドラッグ
	start_drag_group(group[0], [group[0]], source_node, mouse_pos)

func start_drag(idx: int, source_node: Control, mouse_pos: Vector2) -> void:
	start_drag_group(idx, [idx], source_node, mouse_pos)

func start_drag_group(idx: int, group: Array, source_node: Control, mouse_pos: Vector2) -> void:
	_dragging = true; _drag_source_idx = idx; _drag_group_indices = group
	_drag_offset = source_node.global_position - mouse_pos
	var entry = GameSession.selected_deck[idx] if idx < GameSession.selected_deck.size() else {}
	var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
	var count = group.size()
	var card_cost = get_card_cost(card_name)
	var card_color = get_card_color(card_name)

	# CardSlotと同じ縦長カード形式でドラッグノード作成（90×130px）
	const DRAG_CARD_W = 90.0
	const DRAG_CARD_H = 130.0
	const DRAG_ILLUST_RATIO = 0.6

	_drag_node = Control.new()
	_drag_node.custom_minimum_size = Vector2(DRAG_CARD_W, DRAG_CARD_H)
	_drag_node.z_index = 100
	_drag_node.modulate = Color(1, 1, 1, 0.7)  # 半透明化

	# カード枠（丸角矩形）
	var bg = PanelContainer.new()
	bg.size = Vector2(DRAG_CARD_W, DRAG_CARD_H)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_node.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(vbox)

	# イラストエリア（60%）
	var illust_h = DRAG_CARD_H * DRAG_ILLUST_RATIO
	var illust_area = ColorRect.new()
	illust_area.custom_minimum_size = Vector2(DRAG_CARD_W - 2, illust_h)
	illust_area.color = card_color
	illust_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(illust_area)

	# 左上コストバッジ
	const COST_BADGE_SIZE = 20.0
	var cost_badge = PanelContainer.new()
	cost_badge.position = Vector2(4, 4)
	cost_badge.custom_minimum_size = Vector2(COST_BADGE_SIZE, COST_BADGE_SIZE)
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.2, 0.3, 0.5)
	badge_style.set_corner_radius_all(int(COST_BADGE_SIZE / 2))
	cost_badge.add_theme_stylebox_override("panel", badge_style)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost_lbl = Label.new()
	cost_lbl.text = str(card_cost)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.add_child(cost_lbl)
	illust_area.add_child(cost_badge)

	# 右上×Nバッジ（count > 1の場合のみ）
	if count > 1:
		var count_lbl = Label.new()
		count_lbl.text = "×%d" % count
		count_lbl.position = Vector2(DRAG_CARD_W - 30, 4)
		count_lbl.size = Vector2(26, 16)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		illust_area.add_child(count_lbl)

	# テキストエリア（40%）
	var text_area = VBoxContainer.new()
	text_area.custom_minimum_size = Vector2(DRAG_CARD_W - 6, DRAG_CARD_H - illust_h - 6)
	text_area.add_theme_constant_override("separation", 2)
	text_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_area.add_child(name_lbl)
	vbox.add_child(text_area)

	main_node.add_child(_drag_node)
	_drag_node.global_position = mouse_pos + _drag_offset

func end_drag() -> void:
	if _drag_node != null:
		_drag_node.queue_free()
		_drag_node = null
	_dragging = false
	_drag_source_idx = -1
	_drag_group_indices = []

func process_drag(_delta: float) -> void:
	if _dragging and _drag_node != null:
		_drag_node.global_position = main_node.get_viewport().get_mouse_position() + _drag_offset
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		try_drop_at_mouse(tab_container)

func try_drop_at_mouse(_tc: Control) -> void:
	if not _dragging or _drag_source_idx < 0:
		end_drag()
		return

	var mouse = main_node.get_viewport().get_mouse_position()
	var local = mouse - _tc.global_position

	# 自陣盤面のドロップ判定
	for ri in range(3):
		for ci in range(3):
			var bx: float = BOARD_X + ROW_LABEL_W + ci * (CELL_W + CELL_GAP)
			var by = CELLS_START_Y + ri * (CELL_H + CELL_GAP)
			if local.x >= bx and local.x < bx + CELL_W and local.y >= by and local.y < by + CELL_H:
				try_drop_card(_drag_source_idx, 0, ri, ci)
				return

	# 呪文デッキエリアのドロップ判定（row=0, col=-1）
	var ally_board_w = float(ROW_LABEL_W) + 3.0 * float(CELL_W + CELL_GAP)
	var spell_deck_x = float(BOARD_X) + ally_board_w + float(CENTER_GAP)
	var spell_deck_y = float(CELLS_START_Y)
	var spell_deck_w = 3.0 * float(CELL_W + CELL_GAP)
	var spell_deck_h = 3.0 * float(CELL_H + CELL_GAP)
	if local.x >= spell_deck_x and local.x < spell_deck_x + spell_deck_w and \
	   local.y >= spell_deck_y and local.y < spell_deck_y + spell_deck_h:
		try_drop_card(_drag_source_idx, 0, 0, -1)
		return

	# 手持ちカードエリアのドロップ判定（row=1, col=-1）
	var hand_area_y = float(CELLS_START_Y) + 3.0 * float(CELL_H + CELL_GAP) + 4.0
	var hand_area_w = ally_board_w - float(BOARD_X)
	var hand_area_h = 120.0  # 手持ちカードエリアの高さ（概算）
	if local.x >= float(BOARD_X) and local.x < float(BOARD_X) + hand_area_w and \
	   local.y >= hand_area_y and local.y < hand_area_y + hand_area_h:
		try_drop_card(_drag_source_idx, 0, 1, -1)
		return

	end_drag()

func try_drop_card(idx: int, new_side: int, new_row: int, new_col: int) -> void:
	var indices_to_move = _drag_group_indices if _drag_group_indices.size() > 0 else [idx]

	# v2設計: 盤面（col>=0）にはユニットのみ配置可能、1マス1枚まで
	if new_col >= 0:
		# チェック1: ユニットのみ配置可能
		for move_idx in indices_to_move:
			if move_idx < 0 or move_idx >= GameSession.selected_deck.size():
				continue
			var entry = GameSession.selected_deck[move_idx]
			var card_name = entry.get("name", "") if entry is Dictionary else str(entry)

			if not CardDB.UNITS.has(card_name):
				push_warning("[DeckPrepBoard] 盤面にはユニットのみ配置できます: %s" % card_name)
				end_drag()
				return

		# チェック2: ドロップ先に既にカードがあるか → 入れ替え処理
		var target_container = _cell_card_containers[new_side][new_row][new_col]
		if target_container.get_child_count() > 0:
			# ドロップ先のカードインデックスを取得
			var target_indices = _PL.get_cell_group(new_side, new_row, new_col, GameSession.placement_config)
			if target_indices.is_empty():
				push_warning("[DeckPrepBoard] ドロップ先のカード情報が取得できません")
				end_drag()
				return

			# ドラッグ元の位置を取得（複数カードの場合は代表1枚の位置を使用）
			var source_idx = indices_to_move[0]
			var source_config = GameSession.placement_config[source_idx] if source_idx < GameSession.placement_config.size() else {}
			var source_side = source_config.get("side", 0)
			var source_row = source_config.get("row", 0)
			var source_col = source_config.get("col", -1)

			# 入れ替え処理
			if source_col >= 0:
				# 盤面 → 盤面: 単純に入れ替え
				for target_idx in target_indices:
					var cfg = GameSession.placement_config[target_idx]
					cfg["side"] = source_side
					cfg["row"] = source_row
					cfg["col"] = source_col
			elif source_row == 1 or source_row == 0:
				# 手持ちカード（row=1）or 呪文スロット（row=0） → 盤面: ドロップ先カードを元の位置へ
				for target_idx in target_indices:
					var cfg = GameSession.placement_config[target_idx]
					cfg["side"] = source_side
					cfg["row"] = source_row
					cfg["col"] = source_col

	# 呪文デッキ（row=0, col=-1）へのドロップ時バリデーション
	if new_row == 0 and new_col == -1:
		for move_idx in indices_to_move:
			if move_idx < 0 or move_idx >= GameSession.selected_deck.size():
				continue
			var entry = GameSession.selected_deck[move_idx]
			var card_name = entry.get("name", "") if entry is Dictionary else str(entry)

			if not (CardDB.SPELLS.has(card_name) or CardDB.STATUS_SPELLS.has(card_name)):
				push_warning("[DeckPrepBoard] 呪文デッキには呪文のみ配置できます: %s" % card_name)
				end_drag()
				return

	# ドラッグカードをドロップ先へ移動
	print("[DeckPrepBoard] try_drop_card: idx=%d, new_side=%d, new_row=%d, new_col=%d, indices_to_move=%s" % [idx, new_side, new_row, new_col, str(indices_to_move)])
	var success = _PL.move_group(indices_to_move, new_side, new_row, new_col,
		GameSession.selected_deck, GameSession.placement_config)
	print("[DeckPrepBoard] move_group result: success=%s" % str(success))

	if not success:
		print("[DeckPrepBoard] move_group failed, aborting")
		end_drag()
		return

	print("[DeckPrepBoard] move_group succeeded, calling populate_cards()")
	end_drag()
	populate_cards()
	select_card(idx)

func select_row(side: int, row_idx: int) -> void:
	var group = _PL.get_row_group(side, row_idx, GameSession.placement_config)
	apply_group_selection(group)
	for ci in range(3):
		var cell = _cell_rects[side][row_idx][ci]
		if cell != null:
			set_cell_color(cell, Color(0.18, 0.22, 0.28))

func select_cell(side: int, row_idx: int, col_idx: int) -> void:
	var group = _PL.get_cell_group(side, row_idx, col_idx, GameSession.placement_config)
	apply_group_selection(group)
	var cell = _cell_rects[side][row_idx][col_idx]
	if cell != null:
		set_cell_color(cell, Color(0.22, 0.25, 0.32))

func select_col(side: int, col_idx: int) -> void:
	var group = _PL.get_col_group(side, col_idx, GameSession.placement_config)
	apply_group_selection(group)
	for ri in range(3):
		var cell = _cell_rects[side][ri][col_idx]
		if cell != null:
			set_cell_color(cell, Color(0.18, 0.22, 0.28))

func apply_group_selection(group: Array) -> void:
	if group.size() > 0:
		_drag_group_indices = group
		_selected_card_idx = group[0]
		if on_card_selected.is_valid():
			on_card_selected.call(group[0])

func select_card(idx: int) -> void:
	_selected_card_idx = idx
	if on_card_selected.is_valid():
		on_card_selected.call(idx)

func set_cell_color(cell: Control, color: Color) -> void:
	if cell == null:
		return
	var style = cell.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = color

func update_highlight() -> void:
	if _cell_rects.size() < 2:
		return
	# 全セルの色をリセット
	for si in range(2):
		for ri in range(3):
			for ci in range(3):
				var default_color = Color(0.1, 0.12, 0.16) if si == 0 else Color(0.14, 0.1, 0.1)
				set_cell_color(_cell_rects[si][ri][ci], default_color)

	if _selected_card_idx < 0 or _selected_card_idx >= GameSession.selected_deck.size():
		return

	# 複数選択時またはドラッグ中は効果範囲ハイライトを出さない
	if _drag_group_indices.size() > 1 or _dragging:
		return

	var entry = GameSession.selected_deck[_selected_card_idx]
	var config = GameSession.placement_config[_selected_card_idx] if _selected_card_idx < GameSession.placement_config.size() else {}
	var p_side = config.get("side", 0)
	var p_row = config.get("row", 0)
	var p_col = config.get("col", -1)
	# 呪文スロットカード（col=-1）は盤面ハイライトを出さない
	if p_col < 0:
		return
	if p_row < 0: p_row = 0

	# 配置マスをハイライト
	var placed_color = Color(0.2, 0.22, 0.28) if p_side == 0 else Color(0.22, 0.18, 0.18)
	set_cell_color(_cell_rects[p_side][p_row][p_col], placed_color)

	# 効果範囲ハイライト
	var highlights = _PL.get_highlight_cells(entry, p_side, p_row, p_col)
	var highlight_colors = {
		"green": Color(0.15, 0.3, 0.15),
		"red": Color(0.3, 0.12, 0.12),
		"blue": Color(0.12, 0.18, 0.3),
	}
	for h in highlights:
		var hs = h.get("side", 0)
		var hr = h.get("row", 0)
		var hc = h.get("col", 0)
		var hcolor = h.get("color", "green")
		if hs >= 0 and hs < 2 and hr >= 0 and hr < 3 and hc >= 0 and hc < 3:
			set_cell_color(_cell_rects[hs][hr][hc], highlight_colors.get(hcolor, highlight_colors["green"]))
