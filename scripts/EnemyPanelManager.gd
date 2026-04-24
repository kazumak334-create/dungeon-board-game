# EnemyPanelManager.gd
# 敵盤面パネルの3フェーズ管理（NEXT_EI / SCRATCH / SHOP）
class_name EnemyPanelManager
extends Control

enum EnemyPanelPhase { NEXT_EI, SCRATCH, SHOP }

signal phase_changed(phase: EnemyPanelPhase)
signal scratch_completed(card_data: Dictionary)
signal shop_completed()

var _phase: EnemyPanelPhase = EnemyPanelPhase.NEXT_EI
var _current_container: Control = null
var _scratch_rewards: Array = []  # 9件の報酬カードデータ

# 外部参照（RestScreenManagerからセット）
var wave_manager: Node = null
var game_session: Node = null
var card_db: Node = null

# 盤面セルと同じ座標・サイズを使用
const BOARD_X: float = 430.0
const BOARD_Y: float = 52.0
const CELL_W: float = 130.0
const CELL_H: float = 95.0
const COLS: int = 3
const ROWS: int = 3

func set_phase(phase: EnemyPanelPhase, _context: Dictionary = {}) -> void:
	# 前フェーズUIを破棄
	if _current_container != null:
		_current_container.queue_free()
		_current_container = null

	# 新しいコンテナを作成
	_current_container = Control.new()
	_current_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_current_container)

	# フェーズに応じてUI構築
	match phase:
		EnemyPanelPhase.NEXT_EI:
			_build_next_ei_ui()
		EnemyPanelPhase.SCRATCH:
			_build_scratch_ui()
		EnemyPanelPhase.SHOP:
			_build_shop_ui()

	_phase = phase
	phase_changed.emit(phase)
	print("[EnemyPanelManager] フェーズ変更: %s" % EnemyPanelPhase.keys()[phase])

# ---- NEXT_EIフェーズ ----

func _build_next_ei_ui() -> void:
	var layout = _get_next_enemy_layout()
	for row in range(ROWS):
		for col in range(COLS):
			var cell = _create_ei_cell(layout[row][col], row, col)
			_current_container.add_child(cell)

func _create_ei_cell(has_enemy: bool, row: int, col: int) -> Control:
	var cell = Panel.new()
	cell.set_position(Vector2(BOARD_X + col * CELL_W, BOARD_Y + row * CELL_H))
	cell.set_size(Vector2(CELL_W, CELL_H))

	var style = StyleBoxFlat.new()
	if has_enemy:
		style.bg_color = Color(0.12, 0.12, 0.18)
		style.border_color = Color(0.3, 0.3, 0.4)
	else:
		style.bg_color = Color(0.08, 0.08, 0.1)
		style.border_color = Color(0.2, 0.2, 0.25)
	style.set_border_width_all(1)
	cell.add_theme_stylebox_override("panel", style)

	return cell

func _get_next_enemy_layout() -> Array:
	# wave_manager が null または情報取得不可の場合: 全false配列を返す
	if wave_manager == null:
		return _make_empty_layout()
	# フォールバック: 全シルエット非表示
	return _make_empty_layout()

func _make_empty_layout() -> Array:
	var layout: Array = []
	for _r in range(ROWS):
		var row_arr: Array = []
		for _c in range(COLS):
			row_arr.append(false)
		layout.append(row_arr)
	return layout

# ---- SCRATCHフェーズ ----

func _build_scratch_ui() -> void:
	_scratch_rewards = _generate_rewards(9)
	var active_index: int = randi() % 9

	for i in range(9):
		var row: int = i / COLS
		var col: int = i % COLS
		var card_data: Dictionary = _scratch_rewards[i]
		var cell = _create_scratch_cell(card_data, i == active_index)
		cell.set_position(Vector2(BOARD_X + col * CELL_W, BOARD_Y + row * CELL_H))
		_current_container.add_child(cell)

func _create_scratch_cell(card_data: Dictionary, is_active: bool) -> Panel:
	var cell = Panel.new()
	cell.set_size(Vector2(CELL_W, CELL_H))

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(1)
	cell.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "???"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	cell.add_child(label)

	if is_active:
		var captured_data = card_data
		cell.gui_input.connect(func(event: InputEvent):
			_on_scratch_input(event, captured_data, cell)
		)
	else:
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return cell

func _on_scratch_input(event: InputEvent, card_data: Dictionary, cell: Panel) -> void:
	if event is InputEventMouseButton and event.double_click \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_scratch_selected(card_data, cell)

func _on_scratch_selected(card_data: Dictionary, cell: Panel) -> void:
	# セルにカード名・種別を表示
	for child in cell.get_children():
		child.queue_free()

	var rarity: String = card_data.get("rarity", "common")
	var style = StyleBoxFlat.new()
	style.bg_color = _get_rarity_color(rarity)
	style.border_color = Color(0.6, 0.6, 0.7)
	style.set_border_width_all(2)
	cell.add_theme_stylebox_override("panel", style)

	var name_label = Label.new()
	name_label.text = card_data.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	cell.add_child(name_label)

	var type_label = Label.new()
	type_label.text = card_data.get("type", "unit")
	type_label.set_position(Vector2(5, CELL_H - 18))
	type_label.set_size(Vector2(CELL_W - 10, 16))
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	cell.add_child(type_label)

	# 他セルを無効化（念のため）
	if _current_container:
		for other_cell in _current_container.get_children():
			other_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# カードをgame_sessionに追加
	if game_session:
		var card_type: String = card_data.get("type", "unit")
		var card_name: String = card_data.get("name", "")
		if card_type == "unit":
			game_session.selected_deck.append({"name": card_name})
			print("[EnemyPanelManager] ユニット獲得: %s" % card_name)
		elif card_type == "spell":
			game_session.spell_available.append({"name": card_name})
			print("[EnemyPanelManager] 呪文獲得: %s" % card_name)

	scratch_completed.emit(card_data)

	# 0.5秒後にSHOPフェーズへ
	get_tree().create_timer(0.5).timeout.connect(func():
		set_phase(EnemyPanelPhase.SHOP)
	)

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.10, 0.22, 0.10)
		"rare":
			return Color(0.10, 0.12, 0.28)
		"epic":
			return Color(0.22, 0.10, 0.28)
		_:
			return Color(0.18, 0.18, 0.22)

func _generate_rewards(count: int) -> Array:
	var result: Array = []
	var db = card_db if card_db != null else CardDB

	var unit_keys: Array = db.UNITS.keys()
	if unit_keys.is_empty():
		for _i in range(count):
			result.append({"name": "不明", "type": "unit", "rarity": "common"})
		return result

	var has_spells: bool = not db.SPELLS.is_empty()
	var spell_keys: Array = db.SPELLS.keys() if has_spells else []

	for _i in range(count):
		var is_spell: bool = has_spells and (randi() % 2 == 0)
		if is_spell:
			var spell_name: String = spell_keys[randi() % spell_keys.size()]
			var spell_data: Dictionary = db.SPELLS[spell_name]
			result.append({
				"name": spell_name,
				"type": "spell",
				"rarity": spell_data.get("rarity", "common")
			})
		else:
			var unit_name: String = unit_keys[randi() % unit_keys.size()]
			var unit_data: Dictionary = db.UNITS[unit_name]
			result.append({
				"name": unit_name,
				"type": "unit",
				"rarity": unit_data.get("rarity", "common")
			})

	return result

# ---- SHOPフェーズ ----

func _build_shop_ui() -> void:
	var shop = preload("res://scripts/RestScreenShop.gd").new()
	_current_container.add_child(shop)

	# RestScreenShopはui_root, sessionが必要
	var session = game_session if game_session != null else GameSession
	shop.initialize(session, _current_container, {})
	shop.purchase_completed.connect(_on_shop_purchase_completed)

func _on_shop_purchase_completed(_card_id: String, _new_gold: int) -> void:
	print("[EnemyPanelManager] ショップ購入完了: %s" % _card_id)
	# 購入完了後にNEXT_EIへ戻す
	shop_completed.emit()
	set_phase(EnemyPanelPhase.NEXT_EI)
