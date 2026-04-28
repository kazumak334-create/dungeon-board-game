extends Node2D

const LOG_PREFIX := "[BattleScreen]"
const LOG_PANEL_WIDTH := 250
const MAX_LOG_LINES := 100
const HEADER_H := 50

var _hex_grid: HexGrid
var _units_layer: Node2D
var _ui_layer: CanvasLayer
var _battle: PoCBattle
var _log_label: RichTextLabel
var _log_lines: Array = []
var _wave_label: Label

var _rng: RandomNumberGenerator

func _ready() -> void:
	print(LOG_PREFIX, " _ready wave=", GameState.current_wave)
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_setup_hex_grid()
	_setup_ui()
	_setup_battle()
	# 0.5秒後にバトル開始（敵配置を見せる演出）
	await get_tree().create_timer(0.5).timeout
	_battle.start_battle()
	_append_log("=== Wave%d バトル開始 ===" % GameState.current_wave)

func _setup_hex_grid() -> void:
	_hex_grid = HexGrid.new()
	_hex_grid.name = "HexGrid"
	var hex_width := HexGrid.HEX_SIZE * sqrt(3.0)
	var total_width := hex_width * 6.0
	var grid_area_w := 1280.0 - LOG_PANEL_WIDTH - 20.0
	var grid_area_h := 720.0 - HEADER_H
	var total_height := HexGrid.HEX_SIZE * 2.0 * 0.75 * 9.0 + HexGrid.HEX_SIZE * 2.0
	_hex_grid.origin = Vector2(
		grid_area_w * 0.5 - total_width * 0.5 + hex_width * 0.5,
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
	_setup_log_panel()

func _setup_header() -> void:
	var header := Panel.new()
	header.size = Vector2(1280 - LOG_PANEL_WIDTH - 20, HEADER_H)
	header.position = Vector2(0, 0)
	_ui_layer.add_child(header)

	_wave_label = Label.new()
	_wave_label.text = "Wave %d / %d  （観戦中）" % [GameState.current_wave, GameState.WAVE_COUNT]
	_wave_label.size = Vector2(600, HEADER_H)
	_wave_label.position = Vector2(10, 0)
	_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_wave_label)

func _setup_log_panel() -> void:
	var viewport_w := 1280.0
	var viewport_h := 720.0
	var panel_x := viewport_w - LOG_PANEL_WIDTH - 10.0

	# ユニット説明
	var desc_h := 120.0
	var desc_panel := Panel.new()
	desc_panel.size = Vector2(LOG_PANEL_WIDTH, desc_h)
	desc_panel.position = Vector2(panel_x, 10)
	_ui_layer.add_child(desc_panel)

	var desc_label := RichTextLabel.new()
	desc_label.size = Vector2(LOG_PANEL_WIDTH - 8, desc_h - 8)
	desc_label.position = Vector2(4, 4)
	desc_label.bbcode_enabled = true
	var s_at: Dictionary = PoCUnit.UNIT_STATS["ATTACKER"]
	var s_tk: Dictionary = PoCUnit.UNIT_STATS["TANK"]
	var s_br: Dictionary = PoCUnit.UNIT_STATS["BREAKER"]
	desc_label.text = "[b]ユニット説明[/b]\n" + \
		"[color=red]突（赤）[/color] HP%.0f ATK%.0f\n  崩にx2\n" % [s_at["hp"], s_at["atk"]] + \
		"[color=cyan]守（青）[/color] HP%.0f ATK%.0f\n  突にx2\n" % [s_tk["hp"], s_tk["atk"]] + \
		"[color=green]崩（緑）[/color] HP%.0f ATK%.0f\n  守にx2・範囲2" % [s_br["hp"], s_br["atk"]]
	desc_panel.add_child(desc_label)

	# ログパネル
	var log_y := desc_h + 20.0
	var log_panel := Panel.new()
	log_panel.size = Vector2(LOG_PANEL_WIDTH, viewport_h - log_y - 10)
	log_panel.position = Vector2(panel_x, log_y)
	_ui_layer.add_child(log_panel)

	var scroll := ScrollContainer.new()
	scroll.size = Vector2(LOG_PANEL_WIDTH - 4, log_panel.size.y - 4)
	scroll.position = Vector2(2, 2)
	log_panel.add_child(scroll)

	_log_label = RichTextLabel.new()
	_log_label.size = Vector2(LOG_PANEL_WIDTH - 8, log_panel.size.y - 8)
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	scroll.add_child(_log_label)

func _setup_battle() -> void:
	_battle = PoCBattle.new()
	_battle.name = "PoCBattle"
	add_child(_battle)
	_battle.setup(_hex_grid)

	# プレイヤーユニット生成（GameState.deployed_units から）
	for entry in GameState.deployed_units:
		var unit_type: int = entry["unit_type"]
		var col: int = entry["col"]
		var row: int = entry["row"]
		var unit := PoCUnit.create(unit_type, PoCUnit.Side.PLAYER, col, row)
		unit.position = _hex_grid.hex_to_pixel(col, row)
		_connect_unit_signals(unit)
		_battle.player_units.append(unit)
		_units_layer.add_child(unit)
	print(LOG_PREFIX, " player_units=", _battle.player_units.size())

	# 敵ユニット生成（WaveConfigからランダム配置）
	var composition := WaveConfig.get_wave_composition(GameState.current_wave - 1, _rng)
	var enemy_placements := WaveConfig.generate_enemy_placement(composition, _hex_grid, _rng)
	for entry in enemy_placements:
		var unit_type: int = entry["unit_type"]
		var col: int = entry["col"]
		var row: int = entry["row"]
		var unit := PoCUnit.create(unit_type, PoCUnit.Side.ENEMY, col, row)
		unit.position = _hex_grid.hex_to_pixel(col, row)
		_connect_unit_signals(unit)
		_battle.enemy_units.append(unit)
		_units_layer.add_child(unit)
	print(LOG_PREFIX, " enemy_units=", _battle.enemy_units.size())

	# バトルシグナル接続（1回のみ）
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.unit_died.connect(_on_unit_died)
	_battle.attack_logged.connect(_on_attack_logged)
	_battle.kill_logged.connect(_on_kill_logged)
	_append_log("=== Wave%d 盤面セットアップ完了 ===" % GameState.current_wave)

func _connect_unit_signals(unit: PoCUnit) -> void:
	# PoCBattle._connect_unit_signals と同等の接続
	unit.attack_dealt.connect(func(at, dt, dmg, mult): _battle.attack_logged.emit(at, dt, dmg, mult))
	unit.unit_killed.connect(func(ut, s, pos): _battle.kill_logged.emit(ut, s, pos))

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

func _on_battle_ended(player_won: bool) -> void:
	print(LOG_PREFIX, " battle ended player_won=", player_won)
	GameState.last_battle_won = player_won
	if player_won:
		_append_log("=== PLAYER WIN ===")
	else:
		_append_log("=== PLAYER LOSE ===")
	# 1秒後に遷移
	await get_tree().create_timer(1.0).timeout
	if player_won and GameState.current_wave < GameState.WAVE_COUNT:
		get_tree().change_scene_to_file("res://scenes/hex_mvp/RewardScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/hex_mvp/ResultScreen.tscn")

func _on_unit_died(unit: Node2D) -> void:
	print(LOG_PREFIX, " unit died type=", unit.unit_type, " side=", unit.side)
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
		line = "%s→%s ダメ%.0f(x%.1f)" % [at_name, dt_name, raw, multiplier]
	else:
		line = "%s→%s ダメ%.0f" % [at_name, dt_name, damage]
	_append_log(line)

func _on_kill_logged(unit_type: int, side: int, pos: Vector2i) -> void:
	var type_names: Array = ["突", "守", "崩"]
	var type_name: String = type_names[unit_type] if unit_type < type_names.size() else "?"
	_append_log("[死] %s(r%d,c%d)撃破" % [type_name, pos.y, pos.x])

func _append_log(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	if is_instance_valid(_log_label):
		_log_label.text = "\n".join(_log_lines)
