class_name PoCMain
extends Node2D

const MAX_LOG_LINES := 100
const LOG_PANEL_WIDTH := 250
const PATTERN_BUTTON_X := 20
const PATTERN_BUTTON_START_Y := 80
const PATTERN_BUTTON_H := 40
const PATTERN_BUTTON_W := 160

var _hex_grid: HexGrid
var _units_layer: Node2D
var _ui_layer: CanvasLayer
var _start_button: Button
var _reset_button: Button
var _result_label: Label
var _battle: PoCBattle
var _log_label: RichTextLabel
var _log_lines: Array = []
var _pattern_buttons: Array = []
var _selected_pattern: int = PoCBattle.Pattern.BALANCED

func _ready() -> void:
	print("[PoCMain] _ready called")
	_setup_hex_grid()
	_setup_ui()
	_setup_battle()

func _setup_hex_grid() -> void:
	_hex_grid = HexGrid.new()
	_hex_grid.name = "HexGrid"
	var hex_width := HexGrid.HEX_SIZE * sqrt(3.0)
	var total_width := hex_width * 6.0
	var total_height := HexGrid.HEX_SIZE * 2.0 * 0.75 * 9.0 + HexGrid.HEX_SIZE * 2.0
	_hex_grid.origin = Vector2(
		get_viewport_rect().size.x * 0.5 - total_width * 0.5 + hex_width * 0.5,
		get_viewport_rect().size.y * 0.5 - total_height * 0.5
	)
	add_child(_hex_grid)
	_units_layer = Node2D.new()
	_units_layer.name = "UnitsLayer"
	add_child(_units_layer)

func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	add_child(_ui_layer)
	_setup_start_reset_buttons()
	_setup_pattern_buttons()
	_setup_log_panel()
	_setup_result_label()

func _setup_start_reset_buttons() -> void:
	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "バトル開始"
	_start_button.size = Vector2(150, 50)
	_start_button.position = Vector2(20, 20)
	_ui_layer.add_child(_start_button)
	_start_button.pressed.connect(_on_start_button_pressed)
	_reset_button = Button.new()
	_reset_button.name = "ResetButton"
	_reset_button.text = "リセット"
	_reset_button.size = Vector2(150, 40)
	_reset_button.position = Vector2(180, 20)
	_ui_layer.add_child(_reset_button)
	_reset_button.pressed.connect(_on_reset_button_pressed)

func _setup_pattern_buttons() -> void:
	var patterns := [
		["均等 vs 均等", PoCBattle.Pattern.BALANCED],
		["突 vs 守", PoCBattle.Pattern.ATTACKER_VS_TANK],
		["守 vs 崩", PoCBattle.Pattern.TANK_VS_BREAKER],
		["崩 vs 突", PoCBattle.Pattern.BREAKER_VS_ATTACKER],
		["集中 vs 分散", PoCBattle.Pattern.FOCUS_VS_SPREAD],
	]
	for i in range(patterns.size()):
		var info: Array = patterns[i]
		var btn := Button.new()
		btn.text = info[0]
		btn.size = Vector2(PATTERN_BUTTON_W, PATTERN_BUTTON_H)
		btn.position = Vector2(PATTERN_BUTTON_X, PATTERN_BUTTON_START_Y + i * (PATTERN_BUTTON_H + 4))
		var pattern_id: int = info[1]
		btn.pressed.connect(func(): _on_pattern_button_pressed(pattern_id))
		_ui_layer.add_child(btn)
		_pattern_buttons.append(btn)
	_update_pattern_button_visuals()

func _setup_log_panel() -> void:
	var viewport_w: float = get_viewport_rect().size.x
	var viewport_h: float = get_viewport_rect().size.y
	var desc_h := 120
	# ユニット説明パネル（上部）
	var desc_panel := Panel.new()
	desc_panel.name = "DescPanel"
	desc_panel.size = Vector2(LOG_PANEL_WIDTH, desc_h)
	desc_panel.position = Vector2(viewport_w - LOG_PANEL_WIDTH - 10, 10)
	_ui_layer.add_child(desc_panel)
	var desc_label := RichTextLabel.new()
	desc_label.name = "DescLabel"
	desc_label.size = Vector2(LOG_PANEL_WIDTH - 8, desc_h - 8)
	desc_label.position = Vector2(4, 4)
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.text = "[b]ユニット説明[/b]\n[color=red]突（赤）[/color] HP60 ATK30 速2.0\n  崩にx2、守にx1\n[color=cyan]守（青）[/color] HP200 ATK10 速0.5\n  突にx0.5\n[color=green]崩（緑）[/color] HP40 ATK20 速0.8\n  守にx2・範囲攻撃"
	desc_panel.add_child(desc_label)
	# ログパネル（下部）
	var log_y := desc_h + 20
	var panel := Panel.new()
	panel.name = "LogPanel"
	panel.size = Vector2(LOG_PANEL_WIDTH, viewport_h - log_y - 10)
	panel.position = Vector2(viewport_w - LOG_PANEL_WIDTH - 10, log_y)
	_ui_layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "LogScroll"
	scroll.size = Vector2(LOG_PANEL_WIDTH - 4, panel.size.y - 4)
	scroll.position = Vector2(2, 2)
	scroll.follow_focus = false
	panel.add_child(scroll)
	_log_label = RichTextLabel.new()
	_log_label.name = "LogLabel"
	_log_label.size = Vector2(LOG_PANEL_WIDTH - 8, panel.size.y - 8)
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	scroll.add_child(_log_label)

func _setup_result_label() -> void:
	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_result_label.visible = false
	_result_label.size = Vector2(400, 80)
	_result_label.position = Vector2(
		get_viewport_rect().size.x * 0.5 - 200,
		get_viewport_rect().size.y * 0.5 - 40
	)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 48)
	_ui_layer.add_child(_result_label)

func _setup_battle() -> void:
	_battle = PoCBattle.new()
	_battle.name = "PoCBattle"
	add_child(_battle)
	_battle.setup(_hex_grid)
	_battle.setup_units_for_pattern(_selected_pattern)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.unit_died.connect(_on_unit_died)
	_battle.attack_logged.connect(_on_attack_logged)
	_battle.kill_logged.connect(_on_kill_logged)
	_add_units_to_layer()
	_append_log("=== 盤面セットアップ完了 ===")

func _add_units_to_layer() -> void:
	for u in _battle.get_player_units():
		_units_layer.add_child(u)
	for u in _battle.get_enemy_units():
		_units_layer.add_child(u)

func _process(delta: float) -> void:
	_battle.update(delta)
	_update_unit_visuals()

func _update_unit_visuals() -> void:
	var cell_map: Dictionary = {}
	var all_units: Array = _battle.get_player_units() + _battle.get_enemy_units()
	for u in all_units:
		var key: Vector2i = u.grid_pos
		if not cell_map.has(key):
			cell_map[key] = []
		cell_map[key].append(u)
	for key in cell_map:
		var units: Array = cell_map[key]
		var base_pos: Vector2 = _hex_grid.hex_to_pixel(key.x, key.y)
		var count: int = units.size()
		for i in range(count):
			var offset_x: float = (float(i) - float(count - 1) * 0.5) * 12.0
			units[i].position = base_pos + Vector2(offset_x, 0)

func _on_start_button_pressed() -> void:
	print("[PoCMain] start button pressed")
	_start_button.disabled = true
	_battle.start_battle()
	_append_log("=== バトル開始 ===")

func _on_reset_button_pressed() -> void:
	print("[PoCMain] reset button pressed")
	_rebuild_units()
	_log_lines.clear()
	_log_label.text = ""
	_append_log("=== リセット完了 ===")

func _on_pattern_button_pressed(pattern: int) -> void:
	print("[PoCMain] pattern selected: ", pattern)
	_selected_pattern = pattern
	_update_pattern_button_visuals()
	_rebuild_units()

func _rebuild_units() -> void:
	# UnitsLayerの子を即座に削除（queue_freeではなくfree）
	for child in _units_layer.get_children():
		_units_layer.remove_child(child)
		child.free()
	# バトルをリセット
	_battle.phase = PoCBattle.Phase.SETUP
	_battle.player_units.clear()
	_battle.enemy_units.clear()
	_battle.setup_units_for_pattern(_selected_pattern)
	_add_units_to_layer()
	# UIリセット
	_start_button.disabled = false
	_result_label.visible = false

func _update_pattern_button_visuals() -> void:
	for i in range(_pattern_buttons.size()):
		var btn: Button = _pattern_buttons[i]
		if i == _selected_pattern:
			btn.disabled = true
			btn.modulate = Color.YELLOW
		else:
			btn.disabled = false
			btn.modulate = Color.WHITE

func _on_battle_ended(player_won: bool) -> void:
	_result_label.visible = true
	if player_won:
		_result_label.text = "PLAYER WIN!"
		_result_label.modulate = Color.YELLOW
		_append_log("=== PLAYER WIN ===")
	else:
		_result_label.text = "PLAYER LOSE..."
		_result_label.modulate = Color.RED
		_append_log("=== PLAYER LOSE ===")
	print("[PoCMain] battle ended, player_won=", player_won)

func _on_unit_died(unit: Node2D) -> void:
	print("[PoCMain] unit died: type=", unit.unit_type, " side=", unit.side, " pos=", unit.grid_pos)
	if is_instance_valid(unit) and unit.get_parent() != null:
		unit.get_parent().remove_child(unit)
		unit.free()

func _on_attack_logged(attacker_type: int, defender_type: int, damage: float, multiplier: float) -> void:
	var type_names: Array = ["突", "守", "崩"]
	var at_name: String = type_names[attacker_type] if attacker_type < type_names.size() else "?"
	var dt_name: String = type_names[defender_type] if defender_type < type_names.size() else "?"
	var raw: float = damage / multiplier if multiplier != 0.0 else damage
	var line: String
	if multiplier != 1.0:
		line = "[BW1] %s→%s ダメ%.0f(x%.1f=%.0f)" % [at_name, dt_name, raw, multiplier, damage]
	else:
		line = "[BW1] %s→%s ダメ%.0f" % [at_name, dt_name, damage]
	_append_log(line)

func _on_kill_logged(unit_type: int, side: int, pos: Vector2i) -> void:
	var type_names: Array = ["突", "守", "崩"]
	var type_name: String = type_names[unit_type] if unit_type < type_names.size() else "?"
	var line := "[死] %s(row%d,col%d)撃破" % [type_name, pos.y, pos.x]
	_append_log(line)

func _append_log(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
