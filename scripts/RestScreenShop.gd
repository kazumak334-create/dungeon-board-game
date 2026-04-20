# RestScreenShop.gd
# RestScreen ショップ機能: 敵陣盤面を商品表示に転用し9個の商品をグリッド表示・購入処理
extends Control

signal purchase_completed(card_id: String, new_gold: int)

const CELL_W: int = 130
const CELL_H: int = 95
const SHOP_BOARD_X: int = 430
const SHOP_BOARD_Y: int = 52
const TIER_UNIT: int = 0
const TIER_SPELL: int = 1
const TIER_MATERIAL: int = 2
const TIER_ROWS: int = 3

const COLOR_AFFORDABLE := Color(0.3, 0.5, 0.3)
const COLOR_UNAFFORDABLE := Color(0.3, 0.2, 0.2)
const COLOR_DIM := Color(0.5, 0.5, 0.5)
const COLOR_TEXT := Color(0.9, 0.9, 0.9)
const COLOR_PRICE := Color(0.9, 0.8, 0.3)

const DUMMY_MATERIALS: Array[String] = ["素材A", "素材B", "素材C"]

var ui_root: Control
var game_session: Node
var shop_data: Array = []
var shop_panels: Array = []
var shop_board_container: Control
var _config: Dictionary = {}

func initialize(session: Node, parent: Control, config: Dictionary = {}) -> void:
	game_session = session
	ui_root = parent
	_config = config
	generate_shop_items()
	build_shop_board()

func generate_shop_items() -> void:
	shop_data.clear()

	var unit_count: int = _config.get("unit_count", 6)
	var spell_count: int = _config.get("spell_count", 3)
	var material_count: int = _config.get("material_count", 3)
	var rarity_weights: Dictionary = _config.get("rarity_weights", {})
	var allow_duplicates: bool = _config.get("allow_duplicates", true)

	# Tier 0: ユニット抽選
	var unit_candidates: Array = []
	for uid in CardDB.UNITS.keys():
		var u = CardDB.UNITS[uid]
		unit_candidates.append({
			"card_type": "unit",
			"card_id": uid,
			"card_data": u,
			"rarity": u.get("rarity", "common").to_lower(),
			"sold_out": false
		})
	var units: Array = _weighted_sample(unit_candidates, unit_count, rarity_weights, allow_duplicates)
	for i in range(units.size()):
		var item = units[i]
		item["tier"] = TIER_UNIT
		item["slot_in_tier"] = i
		item["price"] = _get_price(item.card_data)
		shop_data.append(item)

	# Tier 1: 呪文抽選
	var spell_candidates: Array = []
	for sid in CardDB.SPELLS.keys():
		var s = CardDB.SPELLS[sid]
		spell_candidates.append({
			"card_type": "spell",
			"card_id": sid,
			"card_data": s,
			"rarity": s.get("rarity", "common").to_lower(),
			"sold_out": false
		})
	var spells: Array = _weighted_sample(spell_candidates, spell_count, rarity_weights, allow_duplicates)
	for i in range(spells.size()):
		var item = spells[i]
		item["tier"] = TIER_SPELL
		item["slot_in_tier"] = i
		item["price"] = _get_price(item.card_data)
		shop_data.append(item)

	# Tier 2: 素材（ダミー）
	for i in range(material_count):
		var mat_name: String = DUMMY_MATERIALS[i % DUMMY_MATERIALS.size()]
		shop_data.append({
			"card_type": "material",
			"card_id": "mat_%d" % i,
			"card_data": {"display": mat_name},
			"tier": TIER_MATERIAL,
			"slot_in_tier": i,
			"price": 50,
			"sold_out": false,
			"is_dummy": true
		})

func _weighted_sample(pool: Array, count: int, weights: Dictionary, allow_duplicates: bool) -> Array:
	var result: Array = []
	var available: Array = pool.duplicate()

	for _i in range(count):
		if available.is_empty():
			break

		var total: float = 0.0
		var weighted: Array = []
		for candidate in available:
			var rarity: String = candidate.get("rarity", "common")
			var weight: float = weights.get(rarity, 1.0)
			total += weight
			weighted.append({"item": candidate, "weight": weight})

		var rand: float = randf() * total
		var acc: float = 0.0
		var selected = null
		for entry in weighted:
			acc += entry.weight
			if rand <= acc:
				selected = entry.item
				break

		if selected == null and not weighted.is_empty():
			selected = weighted[-1].item

		if selected != null:
			result.append(selected.duplicate())
			if not allow_duplicates:
				available.erase(selected)

	return result

func build_shop_board() -> void:
	shop_board_container = Control.new()
	shop_board_container.position = Vector2(SHOP_BOARD_X, SHOP_BOARD_Y)
	shop_board_container.size = Vector2(CELL_W * 3, CELL_H * TIER_ROWS)
	ui_root.add_child(shop_board_container)

	shop_panels.clear()
	for i in range(shop_data.size()):
		var item = shop_data[i]
		var panel = create_item_panel(item, i)
		shop_board_container.add_child(panel)
		shop_panels.append(panel)

func create_item_panel(item: Dictionary, shop_index: int) -> Panel:
	var panel = Panel.new()
	var pos = _get_cell_position(item)
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

	# ダミー素材の場合
	if item.get("is_dummy", false):
		var name_label = Label.new()
		name_label.text = item.card_data.get("display", "???")
		name_label.position = Vector2(5, 4)
		name_label.size = Vector2(120, 16)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", COLOR_DIM)
		panel.add_child(name_label)

		var dummy_label = Label.new()
		dummy_label.text = "(未実装)"
		dummy_label.position = Vector2(5, 40)
		dummy_label.size = Vector2(120, 14)
		dummy_label.add_theme_font_size_override("font_size", 11)
		dummy_label.add_theme_color_override("font_color", COLOR_DIM)
		panel.add_child(dummy_label)

		panel.gui_input.connect(_on_panel_gui_input.bind(shop_index))
		return panel

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
	panel.gui_input.connect(_on_panel_gui_input.bind(shop_index))

	return panel

func _on_panel_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		on_item_clicked(slot_index)

func on_item_clicked(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= shop_data.size():
		return

	var item = shop_data[slot_index]
	if item.get("is_dummy", false):
		print("[Shop] ダミー素材クリック: %s（未実装）" % item.card_data.get("display", ""))
		return

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

func _get_cell_position(item: Dictionary) -> Vector2:
	var tier: int = item.get("tier", 0)
	var slot: int = item.get("slot_in_tier", 0)
	var x = SHOP_BOARD_X + slot * CELL_W
	var y = SHOP_BOARD_Y + tier * CELL_H
	return Vector2(x, y)

func _get_border_color(item: Dictionary) -> Color:
	if item.sold_out:
		return COLOR_DIM
	if game_session.gold >= item.price:
		return COLOR_AFFORDABLE
	return COLOR_UNAFFORDABLE
