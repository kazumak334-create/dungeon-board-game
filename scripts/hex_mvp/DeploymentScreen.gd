extends Node2D

const LOG_PREFIX := "[DeploymentScreen]"
const TRAY_H := 100
const BOTTOM_BAR_H := 60
const HEADER_H := 50

var _hex_grid: HexGrid
var _units_layer: Node2D
var _ui_layer: CanvasLayer

# 配置管理
# key: Vector2i(col, row), value: Array
var _placed: Dictionary = {}
var _selected_unit_type: int = -1

# UI要素
var _wave_label: Label
var _enemy_info_label: Label
var _deploy_count_label: Label
var _complete_button: Button
var _tray_buttons: Array = []
var _tray_bg: Panel

# Waveデータ
var _wave_composition: Array = []
var _rng: RandomNumberGenerator

func _ready() -> void:
	print(LOG_PREFIX, " _ready wave=", GameState.current_wave)
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_wave_composition = WaveConfig.get_wave_composition(GameState.current_wave - 1, _rng)
	_setup_hex_grid()
	_setup_ui()

func _setup_hex_grid() -> void:
	_hex_grid = HexGrid.new()
	_hex_grid.name = "HexGrid"
	var hex_width := HexGrid.HEX_SIZE * sqrt(3.0)
	var total_width := hex_width * 6.0
	var grid_area_h := 720.0 - HEADER_H - TRAY_H - BOTTOM_BAR_H
	var total_height := HexGrid.HEX_SIZE * 2.0 * 0.75 * 9.0 + HexGrid.HEX_SIZE * 2.0
	_hex_grid.origin = Vector2(
		640.0 - total_width * 0.5 + hex_width * 0.5,
		HEADER_H + grid_area_h * 0.5 - total_height * 0.5
	)
	add_child(_hex_grid)
	_units_layer = Node2D.new()
	_units_layer.name = "UnitsLayer"
	add_child(_units_layer)

func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	add_child(_ui_layer)
	_setup_header()
	_setup_tray()
	_setup_complete_button()

func _setup_header() -> void:
	var header := Panel.new()
	header.size = Vector2(1280, HEADER_H)
	header.position = Vector2(0, 0)
	_ui_layer.add_child(header)

	_wave_label = Label.new()
	_wave_label.text = "Wave %d / %d" % [GameState.current_wave, GameState.WAVE_COUNT]
	_wave_label.size = Vector2(200, HEADER_H)
	_wave_label.position = Vector2(10, 0)
	_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_wave_label)

	_enemy_info_label = Label.new()
	_enemy_info_label.text = _build_enemy_info_text()
	_enemy_info_label.size = Vector2(700, HEADER_H)
	_enemy_info_label.position = Vector2(220, 0)
	_enemy_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enemy_info_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_enemy_info_label)

func _build_enemy_info_text() -> String:
	var type_names := ["突", "守", "崩"]
	var counts := [0, 0, 0]
	for entry in _wave_composition:
		var t: int = entry["unit_type"]
		if t >= 0 and t < 3:
			counts[t] += entry["count"]
	var parts: Array = []
	for i in range(3):
		if counts[i] > 0:
			parts.append(type_names[i] + str(counts[i]))
	return "敵構成: " + " ".join(parts)

func _setup_tray() -> void:
	var tray_y := 720.0 - TRAY_H - BOTTOM_BAR_H
	_tray_bg = Panel.new()
	_tray_bg.size = Vector2(1280, TRAY_H)
	_tray_bg.position = Vector2(0, tray_y)
	_ui_layer.add_child(_tray_bg)

	var tray_label := Label.new()
	tray_label.text = "ユニットトレイ（クリックで選択）"
	tray_label.position = Vector2(10, 5)
	tray_label.add_theme_font_size_override("font_size", 14)
	_tray_bg.add_child(tray_label)

	_deploy_count_label = Label.new()
	_deploy_count_label.name = "DeployCountLabel"
	_deploy_count_label.text = "配置数: 0 / %d" % GameState.DEPLOY_MAX
	_deploy_count_label.position = Vector2(1050, 5)
	_deploy_count_label.add_theme_font_size_override("font_size", 14)
	_tray_bg.add_child(_deploy_count_label)

	_rebuild_tray_buttons()

func _rebuild_tray_buttons() -> void:
	for btn in _tray_buttons:
		if is_instance_valid(btn):
			btn.free()
	_tray_buttons.clear()

	var type_names := ["突（赤）", "守（青）", "崩（緑）"]
	var counts := _get_remaining_counts()
	var x := 10.0
	for i in range(3):
		var btn := Button.new()
		btn.text = "%s x%d" % [type_names[i], counts[i]]
		btn.size = Vector2(140, 55)
		btn.position = Vector2(x, 30)
		btn.add_theme_font_size_override("font_size", 16)
		var captured_i := i
		btn.pressed.connect(func(): _on_tray_button_pressed(captured_i))
		if _selected_unit_type == i:
			btn.modulate = Color.YELLOW
		if counts[i] <= 0:
			btn.disabled = true
		_tray_bg.add_child(btn)
		_tray_buttons.append(btn)
		x += 150.0

func _get_remaining_counts() -> Array:
	var total := [0, 0, 0]
	for t in GameState.deck:
		if t >= 0 and t < 3:
			total[t] += 1
	for cell_units in _placed.values():
		for u in cell_units:
			var ut: int = int(u.unit_type)
			if ut >= 0 and ut < 3:
				total[ut] -= 1
	return total

func _get_total_deployed() -> int:
	var count := 0
	for cell_units in _placed.values():
		count += cell_units.size()
	return count

func _on_tray_button_pressed(unit_type: int) -> void:
	print(LOG_PREFIX, " tray pressed unit_type=", unit_type)
	_selected_unit_type = unit_type
	_update_tray_visuals()

func _update_tray_visuals() -> void:
	var type_names := ["突（赤）", "守（青）", "崩（緑）"]
	var counts := _get_remaining_counts()
	for i in range(_tray_buttons.size()):
		var btn: Button = _tray_buttons[i]
		if not is_instance_valid(btn):
			continue
		btn.text = "%s x%d" % [type_names[i], counts[i]]
		btn.disabled = counts[i] <= 0
		if _selected_unit_type == i:
			btn.modulate = Color.YELLOW
		else:
			btn.modulate = Color.WHITE

func _setup_complete_button() -> void:
	var bar_y := 720.0 - BOTTOM_BAR_H
	var bar_bg := Panel.new()
	bar_bg.size = Vector2(1280, BOTTOM_BAR_H)
	bar_bg.position = Vector2(0, bar_y)
	_ui_layer.add_child(bar_bg)

	_complete_button = Button.new()
	_complete_button.name = "CompleteButton"
	_complete_button.text = "配置完了"
	_complete_button.size = Vector2(160, 44)
	_complete_button.position = Vector2(1100, 8)
	_complete_button.add_theme_font_size_override("font_size", 20)
	_complete_button.disabled = true
	bar_bg.add_child(_complete_button)
	_complete_button.pressed.connect(_on_complete_button_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_grid_click(mb.position)

func _handle_grid_click(mouse_pos: Vector2) -> void:
	# ブルートフォースで最近傍ヘックスセルを検索（66セル以下）
	var local_pos: Vector2 = mouse_pos - _hex_grid.origin
	var best_cell := Vector2i(-1, -1)
	var best_dist := INF
	for row in range(HexGrid.ROWS):
		var col_count: int = _hex_grid.get_col_count(row)
		for col in range(col_count):
			var center: Vector2 = _hex_grid.hex_to_pixel(col, row) - _hex_grid.origin
			var d: float = local_pos.distance_to(center)
			if d < best_dist:
				best_dist = d
				best_cell = Vector2i(col, row)
	if best_dist > HexGrid.HEX_SIZE:
		return
	print(LOG_PREFIX, " clicked cell=", best_cell)
	_process_cell_click(best_cell)

func _process_cell_click(cell: Vector2i) -> void:
	var row: int = cell.y
	if row < 0 or row > 2:
		print(LOG_PREFIX, " not player zone row=", row)
		return
	var cell_units: Array = _placed.get(cell, [])
	if cell_units.size() > 0:
		_remove_unit_from_cell(cell)
	elif _selected_unit_type >= 0:
		var total := _get_total_deployed()
		if total >= GameState.DEPLOY_MAX:
			print(LOG_PREFIX, " deploy limit reached")
			return
		var remaining := _get_remaining_counts()
		if remaining[_selected_unit_type] <= 0:
			print(LOG_PREFIX, " no remaining of type=", _selected_unit_type)
			return
		if cell_units.size() >= HexGrid.MAX_STACK:
			print(LOG_PREFIX, " cell stack full")
			return
		_place_unit_on_cell(cell, _selected_unit_type)

func _place_unit_on_cell(cell: Vector2i, unit_type: int) -> void:
	print(LOG_PREFIX, " placing unit_type=", unit_type, " at=", cell)
	var unit := PoCUnit.create(unit_type, PoCUnit.Side.PLAYER, cell.x, cell.y)
	unit.position = _hex_grid.hex_to_pixel(cell.x, cell.y)
	_units_layer.add_child(unit)
	if not _placed.has(cell):
		_placed[cell] = []
	_placed[cell].append(unit)
	_update_unit_visuals_in_cell(cell)
	_refresh_ui()

func _remove_unit_from_cell(cell: Vector2i) -> void:
	var cell_units: Array = _placed.get(cell, [])
	if cell_units.size() == 0:
		return
	var unit: PoCUnit = cell_units.pop_back()
	print(LOG_PREFIX, " removing unit_type=", unit.unit_type, " from=", cell)
	if is_instance_valid(unit):
		_units_layer.remove_child(unit)
		unit.free()
	if cell_units.size() == 0:
		_placed.erase(cell)
	else:
		_placed[cell] = cell_units
	_refresh_ui()

func _update_unit_visuals_in_cell(cell: Vector2i) -> void:
	var cell_units: Array = _placed.get(cell, [])
	var base_pos: Vector2 = _hex_grid.hex_to_pixel(cell.x, cell.y)
	var count: int = cell_units.size()
	for i in range(count):
		var u: PoCUnit = cell_units[i]
		var offset_x: float = (float(i) - float(count - 1) * 0.5) * 12.0
		u.position = base_pos + Vector2(offset_x, 0)

func _refresh_ui() -> void:
	var total := _get_total_deployed()
	_deploy_count_label.text = "配置数: %d / %d" % [total, GameState.DEPLOY_MAX]
	_complete_button.disabled = total < 1
	_update_tray_visuals()

func _on_complete_button_pressed() -> void:
	print(LOG_PREFIX, " complete button pressed")
	GameState.deployed_units = []
	for cell in _placed:
		for u in _placed[cell]:
			GameState.deployed_units.append({
				"unit_type": int(u.unit_type),
				"col": cell.x,
				"row": cell.y
			})
	print(LOG_PREFIX, " saved deployed_units=", GameState.deployed_units.size())
	get_tree().change_scene_to_file("res://scenes/hex_mvp/BattleScreen.tscn")
