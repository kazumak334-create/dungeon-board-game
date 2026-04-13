# DeckPrepBoardSpells.gd
# DeckPrepBoard呪文デッキ・手持ちカード・合成エリア専用
extends RefCounted

var _board: Object = null  # DeckPrepBoardへの参照
var _spell_deck_label: Label = null
var _synth_hover_popup: Control = null
var _skip_synth_confirm: bool = false

func setup(board: Object) -> void:
	_board = board

func build_spell_artifact_split() -> float:
	var BOARD_X = _board.BOARD_X
	var CELLS_START_Y = _board.CELLS_START_Y
	var CELL_H = _board.CELL_H
	var CELL_GAP = _board.CELL_GAP
	var ROW_LABEL_W = _board.ROW_LABEL_W
	var CELL_W = _board.CELL_W
	var HAND_AREA_Y = _board.HAND_AREA_Y
	var HAND_AREA_UNIT_X = _board.HAND_AREA_UNIT_X
	var HAND_AREA_SPELL_X = _board.HAND_AREA_SPELL_X
	var HAND_AREA_H = _board.HAND_AREA_H
	var SPELL_BAR_H = _board.SPELL_BAR_H
	var SPELL_BAR_GAP = _board.SPELL_BAR_GAP
	var tab_container = _board.tab_container

	var board_start_x = float(BOARD_X)
	var ally_board_w = float(ROW_LABEL_W) + 3.0 * float(CELL_W + CELL_GAP)

	const SPELL_DECK_W = 427.0
	var container_w = tab_container.size.x if tab_container else 860.0
	var spell_deck_x = container_w - SPELL_DECK_W - 5.0
	var spell_deck_y = float(CELLS_START_Y) - 20.0

	var spell_bg = Panel.new()
	spell_bg.position = Vector2(spell_deck_x, spell_deck_y)
	spell_bg.size = Vector2(SPELL_DECK_W, 3.0 * float(CELL_H + CELL_GAP) + 20.0)
	spell_bg.set_meta("hand_spell_area", true)
	var spell_bg_style = StyleBoxFlat.new()
	spell_bg_style.bg_color = Color(0.13, 0.13, 0.2)
	spell_bg_style.border_color = Color(0.4, 0.45, 0.6)
	spell_bg_style.set_border_width_all(2)
	spell_bg.add_theme_stylebox_override("panel", spell_bg_style)
	tab_container.add_child(spell_bg)

	_spell_deck_label = Label.new()
	_spell_deck_label.text = "呪文デッキ  総マナ: 0"
	_spell_deck_label.position = Vector2(spell_deck_x + 10.0, spell_deck_y + 4.0)
	_spell_deck_label.add_theme_font_size_override("font_size", 11)
	_spell_deck_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.85))
	_spell_deck_label.set_meta("hand_spell_area", true)
	tab_container.add_child(_spell_deck_label)

	var spell_cards = _build_spell_cards_list()
	var spell_count = spell_cards.size()
	var card_start_y = spell_deck_y + 28.0

	var bar_w = SPELL_DECK_W - 20.0
	for i in range(spell_count):
		var sy = card_start_y + float(i) * float(SPELL_BAR_H + SPELL_BAR_GAP)
		var bar = _create_bar_chip(spell_cards[i][1], spell_cards[i][2], bar_w, float(SPELL_BAR_H), spell_cards[i][0], spell_cards[i][3])
		bar.position = Vector2(spell_deck_x + 10.0, sy)
		bar.set_meta("hand_spell_area", true)
		tab_container.add_child(bar)

	var hand_cards = _build_hand_cards_list()
	var unit_cards: Array = []
	var spell_hand_cards: Array = []
	for hc in hand_cards:
		var card_name = hc[1]
		if CardDB.UNITS.has(card_name):
			unit_cards.append(hc)
		elif CardDB.SPELLS.has(card_name) or CardDB.STATUS_SPELLS.has(card_name):
			spell_hand_cards.append(hc)
		else:
			unit_cards.append(hc)

	var unit_lbl = Label.new()
	unit_lbl.text = "ユニット"
	unit_lbl.position = Vector2(HAND_AREA_UNIT_X, HAND_AREA_Y - 14.0)
	unit_lbl.add_theme_font_size_override("font_size", 11)
	unit_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	unit_lbl.set_meta("hand_spell_area", true)
	tab_container.add_child(unit_lbl)

	var unit_container = _build_hand_card_container(unit_cards, HAND_AREA_UNIT_X, HAND_AREA_Y)
	unit_container.set_meta("hand_spell_area", true)
	tab_container.add_child(unit_container)

	var spell_hand_lbl = Label.new()
	spell_hand_lbl.text = "呪文"
	spell_hand_lbl.position = Vector2(HAND_AREA_SPELL_X, HAND_AREA_Y - 14.0)
	spell_hand_lbl.add_theme_font_size_override("font_size", 11)
	spell_hand_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.85))
	spell_hand_lbl.set_meta("hand_spell_area", true)
	tab_container.add_child(spell_hand_lbl)

	var spell_hand_container = _build_hand_card_container(spell_hand_cards, HAND_AREA_SPELL_X, HAND_AREA_Y)
	spell_hand_container.set_meta("hand_spell_area", true)
	tab_container.add_child(spell_hand_container)

	var hand_border = ColorRect.new()
	hand_border.position = Vector2(HAND_AREA_UNIT_X, HAND_AREA_Y + HAND_AREA_H)
	hand_border.size = Vector2(ally_board_w - float(BOARD_X), 1.0)
	hand_border.color = Color(0.3, 0.35, 0.45, 0.7)
	hand_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_container.add_child(hand_border)

	return HAND_AREA_Y + HAND_AREA_H

func build_synthesis_area(start_y: float) -> void:
	var BOARD_X = _board.BOARD_X
	var CELL_W = _board.CELL_W
	var CELL_GAP = _board.CELL_GAP
	var CENTER_GAP = _board.CENTER_GAP
	var ROW_LABEL_W = _board.ROW_LABEL_W
	var tab_container = _board.tab_container

	var board_area_w = float(ROW_LABEL_W) + 3.0 * float(CELL_W + CELL_GAP) + float(CENTER_GAP) + 3.0 * float(CELL_W + CELL_GAP)
	var board_start_x = float(BOARD_X)

	var toggle = CheckBox.new()
	toggle.text = "確認省略"
	toggle.button_pressed = false
	toggle.position = Vector2(board_start_x + board_area_w - 90.0, start_y)
	toggle.size = Vector2(90.0, 20.0)
	toggle.add_theme_font_size_override("font_size", 10)
	toggle.toggled.connect(func(on: bool): _skip_synth_confirm = on)
	tab_container.add_child(toggle)

	var header = Label.new()
	header.text = "合成可能"
	header.position = Vector2(board_start_x, start_y)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.5))
	tab_container.add_child(header)

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
	var tile_w = 56.0
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

func _create_synthesis_tile(result_name: String, base_name: String, mat_name: String, w: float, h: float) -> Control:
	var card_color = _board.get_card_color(result_name)
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
	cost_lbl.text = str(_board.get_card_cost(result_name))
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

	panel.mouse_entered.connect(func():
		if _board.main_node != null:
			_show_synth_hover_popup(result_name, base_name, mat_name, panel.global_position + Vector2(w / 2.0, -90.0))
	)
	panel.mouse_exited.connect(func(): _hide_synth_hover_popup())

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _skip_synth_confirm:
				print("[DeckPrepBoard] 合成: [%s] + [%s] → [%s]" % [base_name, mat_name, result_name])
			else:
				_show_synth_confirm(result_name, base_name, mat_name)
	)
	return panel

func _show_synth_hover_popup(result_name: String, base_name: String, mat_name: String, pos: Vector2) -> void:
	_hide_synth_hover_popup()
	if _board.main_node == null:
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
	_board.main_node.add_child(popup)
	_synth_hover_popup = popup

func _hide_synth_hover_popup() -> void:
	if _synth_hover_popup != null:
		_synth_hover_popup.queue_free()
		_synth_hover_popup = null

func _show_synth_confirm(result_name: String, base_name: String, mat_name: String) -> void:
	if _board.main_node == null:
		return
	var existing = _board.main_node.find_child("SynthConfirmBoardDialog", false, false)
	if existing:
		existing.queue_free()
	var dialog = Panel.new()
	dialog.name = "SynthConfirmBoardDialog"
	dialog.z_index = 300
	dialog.size = Vector2(240, 110)
	dialog.position = Vector2((_board.main_node.size.x - 240) / 2.0, (_board.main_node.size.y - 110) / 2.0)
	var dstyle = StyleBoxFlat.new()
	dstyle.bg_color = Color(0.1, 0.1, 0.18, 0.97)
	dstyle.border_color = Color(0.5, 0.5, 0.7)
	dstyle.set_border_width_all(2)
	dstyle.set_corner_radius_all(6)
	dialog.add_theme_stylebox_override("panel", dstyle)
	_board.main_node.add_child(dialog)
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

func _build_spell_cards_list() -> Array:
	var raw: Array = []
	for i in range(GameSession.selected_deck.size()):
		var entry = GameSession.selected_deck[i]
		var config = GameSession.placement_config[i] if i < GameSession.placement_config.size() else {}
		var col = config.get("col", -1)
		var row = config.get("row", 0)
		if col >= 0 or row != 0:
			continue
		var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
		if not (CardDB.SPELLS.has(card_name) or CardDB.STATUS_SPELLS.has(card_name)):
			continue
		raw.append({"idx": i, "name": card_name})
	return _group_cards_by_name(raw)

func _build_hand_cards_list() -> Array:
	var raw: Array = []
	for i in range(GameSession.selected_deck.size()):
		var entry = GameSession.selected_deck[i]
		var config = GameSession.placement_config[i] if i < GameSession.placement_config.size() else {}
		var col = config.get("col", -1)
		var row = config.get("row", 0)
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

func _build_hand_card_container(hand_cards: Array, start_x: float, start_y: float) -> Control:
	const CARD_W = 90.0
	const CARD_H = 130.0
	const OVERLAP_W = 22.0

	var container = Control.new()
	container.position = Vector2(start_x, start_y)

	if hand_cards.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "カードなし"
		empty_label.position = Vector2(10.0, 10.0)
		empty_label.add_theme_font_size_override("font_size", 10)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 0.7))
		container.add_child(empty_label)
		container.custom_minimum_size = Vector2(100.0, CARD_H)
		return container

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
		slot.z_index = i

		var card_color = _board.get_card_color(card_name)
		var card_cost = _board.get_card_cost(card_name)

		container.add_child(slot)
		slot.setup(card_name, card_cost, count, indices, card_color)

		slot.on_card_clicked = func(clicked_idx: int, event: InputEvent):
			_on_chip_input_from_slot(event, clicked_idx, indices, slot)

		var original_z = i
		slot.card_hovered.connect(func(_s): slot.z_index = 100)
		slot.card_unhovered.connect(func(_s): slot.z_index = original_z)

	var container_w = CARD_W + float(max(0, hand_cards.size() - 1)) * (CARD_W - OVERLAP_W)
	container.custom_minimum_size = Vector2(container_w, CARD_H)
	return container

func _on_chip_input_from_slot(event: InputEvent, idx: int, all_indices: Array, slot: Control) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	_board._selected_card_idx = idx
	_board._drag_group_indices = [idx]
	if _board.on_card_selected.is_valid(): _board.on_card_selected.call(idx)
	if _board.on_card_pinned.is_valid(): _board.on_card_pinned.call(idx)
	_board.start_drag_group(idx, [idx], slot, event.global_position)

func update_spell_deck_mana() -> void:
	if _spell_deck_label == null:
		return
	var spell_mana: int = 0
	for i in range(GameSession.selected_deck.size()):
		if i >= GameSession.placement_config.size():
			continue
		var config = GameSession.placement_config[i]
		var row = config.get("row", 0)
		var col = config.get("col", -1)
		if row != 0 or col != -1:
			continue
		var entry = GameSession.selected_deck[i]
		var card_name = entry.get("name", "") if entry is Dictionary else str(entry)
		if CardDB.SPELLS.has(card_name):
			spell_mana += CardDB.SPELLS[card_name].get("mana", 0)
		elif CardDB.STATUS_SPELLS.has(card_name):
			spell_mana += CardDB.STATUS_SPELLS[card_name].get("mana", 0)
	_spell_deck_label.text = "呪文デッキ  総マナ: %d" % spell_mana

func _create_bar_chip(card_name: String, count: int, w: float, h: float, idx: int, indices: Array) -> Control:
	var card_color = _board.get_card_color(card_name)
	var card_cost = _board.get_card_cost(card_name)
	var bar = Panel.new()
	bar.custom_minimum_size = Vector2(w, h)
	var style = StyleBoxFlat.new()
	style.bg_color = card_color.darkened(0.5)
	style.border_color = card_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("panel", style)

	var cost_lbl = Label.new()
	cost_lbl.text = str(card_cost)
	cost_lbl.position = Vector2(4, (h - 12) / 2.0)
	cost_lbl.size = Vector2(24, 12)
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(1, 1, 0.7))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(cost_lbl)

	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(32, (h - 12) / 2.0)
	name_lbl.size = Vector2(w - 70, 12)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(name_lbl)

	if count > 1:
		var count_lbl = Label.new()
		count_lbl.text = "×%d" % count
		count_lbl.position = Vector2(w - 34, (h - 12) / 2.0)
		count_lbl.size = Vector2(30, 12)
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(count_lbl)

	bar.gui_input.connect(func(event: InputEvent):
		_on_chip_input(event, idx, indices, bar)
	)

	return bar

func _on_chip_input(event: InputEvent, idx: int, all_indices: Array, chip: Control) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	chip.accept_event()
	_board._selected_card_idx = idx
	_board._drag_group_indices = [idx]
	if _board.on_card_selected.is_valid(): _board.on_card_selected.call(idx)
	if _board.on_card_pinned.is_valid(): _board.on_card_pinned.call(idx)
	_board.start_drag_group(idx, [idx], chip, event.global_position)
