# RestScreenShop.gd
# RestScreen ショップ機能: 敵陣盤面を商品表示に転用し9個の商品をグリッド表示・購入処理
extends Node

signal purchase_completed(card_id: String, new_gold: int)

const CELL_W: int = 130
const CELL_H: int = 95
const SHOP_BOARD_X: int = 430
const SHOP_BOARD_Y: int = 52
const GRID_COLS: int = 3
const GRID_ROWS: int = 3
const SHOP_ITEM_COUNT: int = 9

const COLOR_AFFORDABLE := Color(0.3, 0.5, 0.3)
const COLOR_UNAFFORDABLE := Color(0.3, 0.2, 0.2)
const COLOR_DIM := Color(0.5, 0.5, 0.5)
const COLOR_TEXT := Color(0.9, 0.9, 0.9)
const COLOR_PRICE := Color(0.9, 0.8, 0.3)

var ui_root: Control
var game_session: Node
var shop_data: Array = []
var shop_panels: Array = []
var shop_board_container: Control

func initialize(session: Node, parent: Control) -> void:
	game_session = session
	ui_root = parent
	generate_shop_items()
	build_shop_board()

func generate_shop_items() -> void:
	shop_data.clear()
	var candidates: Array = []
	
	# ユニット候補追加
	for uid in CardDB.UNITS.keys():
		var u = CardDB.UNITS[uid]
		candidates.append({
			"card_type": "unit",
			"card_id": uid,
			"card_data": u,
			"price": _get_price(u),
			"sold_out": false
		})
	
	# 呪文候補追加
	for sid in CardDB.SPELLS.keys():
		var s = CardDB.SPELLS[sid]
		candidates.append({
			"card_type": "spell",
			"card_id": sid,
			"card_data": s,
			"price": _get_price(s),
			"sold_out": false
		})
	
	candidates.shuffle()
	var count = min(SHOP_ITEM_COUNT, candidates.size())
	for i in range(count):
		var item = candidates[i]
		item["slot_index"] = i
		shop_data.append(item)

func build_shop_board() -> void:
	shop_board_container = Control.new()
	shop_board_container.position = Vector2(SHOP_BOARD_X, SHOP_BOARD_Y)
	shop_board_container.size = Vector2(GRID_COLS * CELL_W, GRID_ROWS * CELL_H)
	ui_root.add_child(shop_board_container)
	
	shop_panels.clear()
	for item in shop_data:
		var panel = create_item_panel(item, item.slot_index)
		shop_board_container.add_child(panel)
		shop_panels.append(panel)

func create_item_panel(item: Dictionary, slot_index: int) -> Panel:
	var panel = Panel.new()
	var pos = _get_cell_position(slot_index)
	panel.position = pos - Vector2(SHOP_BOARD_X, SHOP_BOARD_Y)
	panel.size = Vector2(CELL_W, CELL_H)
	
	# 枠線スタイル設定
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.border_color = _get_border_color(item)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	
	# 売却済みは半透明化
	if item.sold_out:
		panel.modulate.a = 0.4
	
	# カード名
	var name_label = Label.new()
	name_label.text = item.card_data.get("display", "???")
	name_label.position = Vector2(5, 4)
	name_label.size = Vector2(120, 16)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	panel.add_child(name_label)
	
	# ステータス
	var stats_label = Label.new()
	if item.card_type == "unit":
		var hp = item.card_data.get("hp", 0)
		var atk = item.card_data.get("atk", 0)
		stats_label.text = "HP:%d ATK:%d" % [hp, atk]
	else:
		var effect = item.card_data.get("effect", "")
		stats_label.text = effect.substr(0, 20) + ("..." if effect.length() > 20 else "")
	stats_label.position = Vector2(5, 24)
	stats_label.size = Vector2(120, 30)
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", COLOR_TEXT)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(stats_label)
	
	# タイプ
	var type_label = Label.new()
	type_label.text = "ユニット" if item.card_type == "unit" else "呪文"
	type_label.position = Vector2(5, 58)
	type_label.size = Vector2(60, 14)
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", COLOR_TEXT)
	panel.add_child(type_label)
	
	# 価格
	var price_label = Label.new()
	price_label.text = "%dG" % item.price
	price_label.position = Vector2(70, 75)
	price_label.size = Vector2(55, 16)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.add_theme_color_override("font_color", COLOR_PRICE)
	panel.add_child(price_label)
	
	# クリックイベント接続
	panel.gui_input.connect(_on_panel_gui_input.bind(slot_index))
	
	return panel

func _on_panel_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		on_item_clicked(slot_index)

func on_item_clicked(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= shop_data.size():
		return
	
	var item = shop_data[slot_index]
	if item.sold_out:
		return
	
	if purchase_item(item):
		refresh_item_panel(slot_index)

func purchase_item(item: Dictionary) -> bool:
	if game_session.gold < item.price:
		return false
	
	game_session.gold -= item.price
	game_session.selected_deck.append(item.card_id)
	item.sold_out = true
	
	purchase_completed.emit(item.card_id, game_session.gold)
	return true

func refresh_item_panel(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= shop_panels.size():
		return
	
	var panel = shop_panels[slot_index]
	var item = shop_data[slot_index]
	
	# 枠線色更新
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = _get_border_color(item)
	
	# 売却済みは半透明化
	if item.sold_out:
		panel.modulate.a = 0.4

func cleanup() -> void:
	if shop_board_container:
		shop_board_container.queue_free()
		shop_board_container = null
	shop_data.clear()
	shop_panels.clear()

func _get_price(card_data: Dictionary) -> int:
	var rarity = card_data.get("rarity", "common")
	var rarity_price = ConfigLoader.get_value("shop", "rarity_price", {
		"common": 50,
		"uncommon": 100,
		"rare": 200,
		"epic": 400,
		"legend": 800
	})
	return rarity_price.get(rarity, 50)

func _get_cell_position(slot_index: int) -> Vector2:
	var col = slot_index % GRID_COLS
	var row = slot_index / GRID_COLS
	var x = SHOP_BOARD_X + col * CELL_W
	var y = SHOP_BOARD_Y + row * CELL_H
	return Vector2(x, y)

func _get_border_color(item: Dictionary) -> Color:
	if item.sold_out:
		return COLOR_DIM
	if game_session.gold >= item.price:
		return COLOR_AFFORDABLE
	return COLOR_UNAFFORDABLE
