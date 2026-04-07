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

# 呪文スロット定数 (横5×縦2=10スロット)
const SPELL_SLOT_W = 78
const SPELL_SLOT_H = 38
const SPELL_SLOT_GAP = 6
const SPELL_SLOTS_COLS = 5
const SPELL_SLOTS_ROWS = 2
const SPELL_SLOTS_Y = BOARD_H + 4

# アーティファクトスロット定数 (横6×縦1=6スロット)
const ARTIFACT_SLOT_W = 78
const ARTIFACT_SLOT_H = 38
const ARTIFACT_SLOT_GAP = 6
const ARTIFACT_SLOTS_COUNT = 6
const ARTIFACT_SLOTS_Y = SPELL_SLOTS_Y + SPELL_SLOT_H * SPELL_SLOTS_ROWS + SPELL_SLOT_GAP * (SPELL_SLOTS_ROWS - 1) + 12

# 合成リスト開始Y
const SYNTHESIS_Y = ARTIFACT_SLOTS_Y + ARTIFACT_SLOT_H + 8

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
var _drag_full_group: Array = []  # Ctrl切替用：元のグループを保持

func build_placement_tab(_tab_container_arg: Control, PL) -> void:
	tab_container = _tab_container_arg
	_PL = PL

	# 項目3: チェックボックスを盤面上部中央、盤面との間に12px以上マージン
	var board_total_w = ROW_LABEL_W + 3 * (CELL_W + CELL_GAP) + CENTER_GAP + 3 * (CELL_W + CELL_GAP)
	var toggle = CheckBox.new()
	toggle.text = "指定セルが埋まっている場合、同じ列の他の空セルに召喚する"
	toggle.button_pressed = true
	toggle.position = Vector2(BOARD_X + board_total_w / 2 - 200, BOARD_Y)
	toggle.size = Vector2(400, 20)
	toggle.add_theme_font_size_override("font_size", 11)
	toggle.toggled.connect(func(on: bool): set_global_fallback(on))
	tab_container.add_child(toggle)

	var enemy_x = BOARD_X + ROW_LABEL_W + 3 * (CELL_W + CELL_GAP) + CENTER_GAP
	# 項目2: 自陣・敵陣ラベル完全削除 → _build_board_headers のみ列ラベルを建てる
	_build_board_col_labels(enemy_x)
	_build_board_cells(enemy_x)
	populate_cards()
	_build_spell_slots()
	_build_artifact_slots()
	build_synthesis_list(SYNTHESIS_Y, tab_container)

# 項目2: 自陣・敵陣ラベル完全削除 → 列ラベルのみ残す
func _build_board_col_labels(enemy_x: float) -> void:
	var ally_cols = ["後列", "中列", "前列"]
	var enemy_cols = ["前列", "中列", "後列"]
	# 項目3: チェックボックス下に12px余白 → BOARD_Y + 20 + 12 = BOARD_Y + 32 からラベル開始
	var col_label_y = BOARD_Y + 32
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

# セル行の開始Y（チェックボックス20px + 12px余白 + 列ラベル16px + 4px余白 = 52px）
const CELLS_START_Y = BOARD_Y + 52

func _build_board_cells(enemy_x: float) -> void:
	var row_names = ["上段", "中段", "下段"]
	_cell_rects = [
		[[null,null,null],[null,null,null],[null,null,null]],
		[[null,null,null],[null,null,null],[null,null,null]]
	]
	_cell_card_containers = [
		[[null,null,null],[null,null,null],[null,null,null]],
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

		# 項目9: 敵陣の行ラベル非表示（代わりに何も追加しない）

		for si in range(2):
			for ci in range(3):
				var bx: float = (BOARD_X + ROW_LABEL_W + ci * (CELL_W + CELL_GAP)) if si == 0 else (enemy_x + ci * (CELL_W + CELL_GAP))
				var by = CELLS_START_Y + ri * (CELL_H + CELL_GAP)
				var cell = Panel.new()
				cell.position = Vector2(bx, by)
				cell.size = Vector2(CELL_W, CELL_H)
				var cell_style = StyleBoxFlat.new()
				cell_style.bg_color = Color(0.1, 0.12, 0.16) if si == 0 else Color(0.14, 0.1, 0.1)
				cell_style.border_color = Color(0.2, 0.3, 0.25) if si == 0 else Color(0.3, 0.2, 0.2)
				cell_style.set_border_width_all(1)
				cell.add_theme_stylebox_override("panel", cell_style)
				tab_container.add_child(cell)
				# 項目1: セル内をカード型（ヘッダー+イラスト枠+ステータス縦並び）に変更
				# vbox は populate_cards でカード型チップを入れる際に使用
				var vbox = VBoxContainer.new()
				vbox.position = Vector2(2, 2)
				vbox.size = Vector2(CELL_W - 4, CELL_H - 4)
				vbox.add_theme_constant_override("separation", 2)
				vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cell.add_child(vbox)
				_cell_rects[si][ri][ci] = cell
				_cell_card_containers[si][ri][ci] = vbox

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

# ---- 呪文スロット描画 ----

func _build_spell_slots() -> void:
	# セクションラベル
	var label = Label.new()
	label.text = "呪文スロット"
	label.position = Vector2(BOARD_X, SPELL_SLOTS_Y - 14)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.85))
	tab_container.add_child(label)

	# 呪文カード一覧を取得（集約済み）
	var spell_cards = _build_spell_cards_list()

	var slot_idx = 0
	for sc in spell_cards:
		if slot_idx >= SPELL_SLOTS_COLS * SPELL_SLOTS_ROWS:
			break
		var row = slot_idx / SPELL_SLOTS_COLS
		var col = slot_idx % SPELL_SLOTS_COLS
		var sx = float(BOARD_X) + float(col) * float(SPELL_SLOT_W + SPELL_SLOT_GAP)
		var sy = float(SPELL_SLOTS_Y) + float(row) * float(SPELL_SLOT_H + SPELL_SLOT_GAP)
		var bar = _create_bar_chip(sc[1], sc[2], float(SPELL_SLOT_W), float(SPELL_SLOT_H), sc[0], sc[3])
		bar.position = Vector2(sx, sy)
		tab_container.add_child(bar)
		slot_idx += 1

	# 残りの空スロット
	for i in range(slot_idx, SPELL_SLOTS_COLS * SPELL_SLOTS_ROWS):
		var row = i / SPELL_SLOTS_COLS
		var col = i % SPELL_SLOTS_COLS
		var sx = float(BOARD_X) + float(col) * float(SPELL_SLOT_W + SPELL_SLOT_GAP)
		var sy = float(SPELL_SLOTS_Y) + float(row) * float(SPELL_SLOT_H + SPELL_SLOT_GAP)
		var empty = _create_empty_slot_panel(float(SPELL_SLOT_W), float(SPELL_SLOT_H),
			Color(0.2, 0.22, 0.35))
		empty.position = Vector2(sx, sy)
		tab_container.add_child(empty)

# ---- アーティファクトスロット描画 ----

func _build_artifact_slots() -> void:
	# セクションラベル
	var label = Label.new()
	label.text = "アーティファクト"
	label.position = Vector2(BOARD_X, ARTIFACT_SLOTS_Y - 14)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.4))
	tab_container.add_child(label)

	for i in range(ARTIFACT_SLOTS_COUNT):
		var sx = float(BOARD_X) + float(i) * float(ARTIFACT_SLOT_W + ARTIFACT_SLOT_GAP)
		var sy = float(ARTIFACT_SLOTS_Y)
		var empty = _create_empty_slot_panel(float(ARTIFACT_SLOT_W), float(ARTIFACT_SLOT_H),
			Color(0.4, 0.35, 0.18))
		empty.position = Vector2(sx, sy)
		tab_container.add_child(empty)

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

func build_synthesis_list(y_start: float, _tc: Control) -> void:
	var panel_w = 1280 - INFO_W - 30
	var panel = UIF.create_panel(Vector2(BOARD_X, y_start), Vector2(panel_w, 160))
	_tc.add_child(panel)

	var header = Label.new()
	header.text = "合成可能"
	header.position = Vector2(BOARD_X + 10, y_start + 5)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	_tc.add_child(header)

	var card_counts: Dictionary = {}
	for entry in GameSession.selected_deck:
		var name = entry.get("name", "") if entry is Dictionary else str(entry)
		card_counts[name] = card_counts.get(name, 0) + 1

	var x = BOARD_X + 10
	var y = y_start + 25
	var found = false
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

		var lbl = Label.new()
		lbl.text = "%s + %s → %s" % [base, card, result_name]
		lbl.position = Vector2(x, y)
		lbl.add_theme_font_size_override("font_size", 11)
		if can_craft:
			lbl.add_theme_color_override("font_color", UIF.BENEFIT_COLOR)
		else:
			lbl.add_theme_color_override("font_color", UIF.DIM_COLOR)
		_tc.add_child(lbl)
		y += 18
		found = true

		if y > y_start + 150:
			break

	if not found:
		var empty = Label.new()
		empty.text = "合成レシピなし"
		empty.position = Vector2(x, y)
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", UIF.DIM_COLOR)
		_tc.add_child(empty)

func populate_cards() -> void:
	for si in range(2):
		for ri in range(3):
			for ci in range(3):
				var vbox = _cell_card_containers[si][ri][ci]
				if vbox != null:
					for child in vbox.get_children():
						child.queue_free()

	var cell_cards = _build_cell_cards_map()

	for key in cell_cards:
		var parts = key.split("_")
		var si = int(parts[0]); var ri = int(parts[1]); var ci = int(parts[2])
		var vbox = _cell_card_containers[si][ri][ci]
		if vbox == null:
			continue
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# ハイブリッド表示: セル内カードを集約してタイル/バー形式で描画
		var grouped = _group_cards_by_name(cell_cards[key])
		# {name, count, idx_first, indices} 形式に変換
		var card_defs: Array = []
		for arr in grouped:
			card_defs.append({"name": arr[1], "count": arr[2], "idx_first": arr[0], "indices": arr[3]})
		var content = _create_cell_content(card_defs)
		vbox.add_child(content)

		# セル操作（Panelのgui_input）
		var cell_panel = _cell_rects[si][ri][ci]
		if cell_panel != null and not cell_panel.has_meta("click_connected"):
			var s = si; var r = ri; var c = ci
			cell_panel.gui_input.connect(func(event):
				if _dragging:
					return
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if event.double_click:
						# ダブルクリック → セル内全カード選択
						select_cell(s, r, c)
					else:
						# シングルクリック → 選択リセット
						_selected_card_idx = -1
						_drag_group_indices = []
						if on_card_selected.is_valid():
							on_card_selected.call(-1)
			)
			cell_panel.set_meta("click_connected", true)

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
		if not result.has(key): result[key] = []
		var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
		result[key].append({"idx": i, "name": card_name})
	return result

# 呪文スロット用カードリスト（col=-1のカードを集約して返す）
func _build_spell_cards_list() -> Array:
	var raw: Array = []
	for i in range(GameSession.selected_deck.size()):
		var entry = GameSession.selected_deck[i]
		var config = GameSession.placement_config[i] if i < GameSession.placement_config.size() else {}
		var col = config.get("col", -1)
		if col >= 0:
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


func _on_chip_input(event: InputEvent, idx: int, all_indices: Array, chip: Control) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	chip.accept_event()
	if event.ctrl_pressed:
		_selected_card_idx = idx
		_drag_group_indices = [idx]
		if on_card_selected.is_valid(): on_card_selected.call(idx)
		start_drag_group(idx, [idx], chip, event.global_position)
	elif idx in _drag_group_indices and _drag_group_indices.size() > 1:
		start_drag_group(_drag_group_indices[0], _drag_group_indices.duplicate(), chip, event.global_position)
	else:
		_selected_card_idx = idx
		_drag_group_indices = all_indices.duplicate()
		if on_card_selected.is_valid(): on_card_selected.call(idx)
		# ピン留め通知（ドラッグ開始前に通知してDeckPrep.gdがピン留め状態を管理）
		if on_card_pinned.is_valid(): on_card_pinned.call(idx)
		start_drag_group(idx, all_indices.duplicate(), chip, event.global_position)

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
	start_drag_group(group[0], group, source_node, mouse_pos)

func start_drag(idx: int, source_node: Control, mouse_pos: Vector2) -> void:
	start_drag_group(idx, [idx], source_node, mouse_pos)

func start_drag_group(idx: int, group: Array, source_node: Control, mouse_pos: Vector2) -> void:
	_dragging = true; _drag_source_idx = idx; _drag_group_indices = group
	_drag_full_group = group.duplicate()  # Ctrl切替用に元グループを保存
	_drag_offset = source_node.global_position - mouse_pos
	var entry = GameSession.selected_deck[idx] if idx < GameSession.selected_deck.size() else {}
	var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
	var count = group.size()
	_drag_node = PanelContainer.new()
	_drag_node.size = Vector2(CELL_W - 10, 15); _drag_node.z_index = 100
	var style = StyleBoxFlat.new()
	style.bg_color = get_card_color(card_name).lightened(0.2); style.set_corner_radius_all(3)
	_drag_node.add_theme_stylebox_override("panel", style)
	var lbl = Label.new()
	lbl.text = "%s x%d" % [card_name, count] if count > 1 else card_name
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_drag_node.add_child(lbl); main_node.add_child(_drag_node)
	_drag_node.global_position = mouse_pos + _drag_offset

func _update_drag_label() -> void:
	if _drag_node == null or _drag_source_idx < 0:
		return
	var entry = GameSession.selected_deck[_drag_source_idx] if _drag_source_idx < GameSession.selected_deck.size() else {}
	var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
	var count = _drag_group_indices.size()
	# ラベル更新（PanelContainerの最初の子がLabel）
	for child in _drag_node.get_children():
		if child is Label:
			child.text = "%s x%d" % [card_name, count] if count > 1 else card_name
			return

func end_drag() -> void:
	if _drag_node != null:
		_drag_node.queue_free()
		_drag_node = null
	_dragging = false
	_drag_source_idx = -1
	_drag_group_indices = []
	_drag_full_group = []

func process_drag(_delta: float) -> void:
	if _dragging and _drag_node != null:
		_drag_node.global_position = main_node.get_viewport().get_mouse_position() + _drag_offset
		# ドラッグ中のCtrl切り替え：1枚⇔グループ
		var ctrl_now = Input.is_key_pressed(KEY_CTRL)
		if ctrl_now and _drag_group_indices.size() > 1:
			# Ctrl押された → 1枚に絞る
			_drag_group_indices = [_drag_source_idx]
			_update_drag_label()
		elif not ctrl_now and _drag_group_indices.size() == 1 and _drag_full_group.size() > 1:
			# Ctrl離された → 元のグループに戻す
			_drag_group_indices = _drag_full_group.duplicate()
			_update_drag_label()
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		try_drop_at_mouse(tab_container)

func try_drop_at_mouse(_tc: Control) -> void:
	if not _dragging or _drag_source_idx < 0:
		end_drag()
		return

	var mouse = main_node.get_viewport().get_mouse_position()
	var local = mouse - _tc.global_position
	var enemy_x = BOARD_X + ROW_LABEL_W + 3 * (CELL_W + CELL_GAP) + CENTER_GAP

	for si in range(2):
		for ri in range(3):
			for ci in range(3):
				var bx: float = (BOARD_X + ROW_LABEL_W + ci * (CELL_W + CELL_GAP)) if si == 0 else (enemy_x + ci * (CELL_W + CELL_GAP))
				var by = CELLS_START_Y + ri * (CELL_H + CELL_GAP)
				if local.x >= bx and local.x < bx + CELL_W and local.y >= by and local.y < by + CELL_H:
					try_drop_card(_drag_source_idx, si, ri, ci)
					return
	end_drag()

func try_drop_card(idx: int, new_side: int, new_row: int, new_col: int) -> void:
	var indices_to_move = _drag_group_indices if _drag_group_indices.size() > 0 else [idx]

	# ドロップ先整合性チェック: 盤面セル（col>=0）へのドロップ制約
	# AoE/プレイヤー影響カードは盤面ドロップ不可（呪文スロットのみ）
	if new_col >= 0:
		for move_idx in indices_to_move:
			if move_idx < 0 or move_idx >= GameSession.selected_deck.size():
				continue
			var entry = GameSession.selected_deck[move_idx]
			if not _PL.requires_board_placement(entry):
				# AoE呪文→盤面ドロップ拒否
				push_warning("[DeckPrepBoard] AoE呪文は盤面に配置できません: %s" % entry.get("name", "?"))
				end_drag()
				return

	var success = _PL.move_group(indices_to_move, new_side, new_row, new_col,
		GameSession.selected_deck, GameSession.placement_config)

	if not success:
		end_drag()
		return

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
