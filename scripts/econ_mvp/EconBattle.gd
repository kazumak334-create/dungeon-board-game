class_name EconBattle
extends Node

signal battle_ended(player_won: bool)
signal log_message(text: String)

var player_units: Array = []
var enemy_units: Array = []
var player_harvesters: Array = []
var enemy_harvesters: Array = []
var player_builders: Array = []
var enemy_builders: Array = []
var player_buildings: Array = []
var enemy_buildings: Array = []
var player_focus_mode: bool = true  # true=集中建設, false=並列建設

var grid: EconGrid
var economy: EconEconomy
var _construction_queue: Array = []
var ai: EconAI = null

var is_running: bool = false
var _game_over: bool = false

func setup(g: EconGrid, eco: EconEconomy) -> void:
	grid = g
	economy = eco

func start() -> void:
	is_running = true
	_game_over = false
	log_message.emit("Battle started!")

func update(delta: float) -> void:
	if not is_running or _game_over:
		return
	# 建設キューは廃止。ビルダーが現地に移動してbuild_progressを加算する
	# 経済更新（小麦消費）
	var total_units: int = player_units.size()
	economy.update(delta, total_units)
	# ハーベスター更新
	var all_movable: Array = player_units + player_harvesters + player_builders + enemy_units
	var alive_harvester_count: int = player_harvesters.filter(func(h): return h.is_alive).size()
	for h in player_harvesters:
		if h.is_alive:
			h.update(delta, grid, all_movable, enemy_units, player_buildings, alive_harvester_count)
	# ビルダー更新
	for b in player_builders:
		if b.is_alive:
			b.update(delta, grid, all_movable, player_buildings, player_focus_mode, economy, enemy_units)
	# 建物更新（プレイヤー側のみ）
	for b in player_buildings:
		if b.is_alive:
			b.update(delta, economy)
	# AI更新
	if ai != null:
		ai.update(delta)
	# 戦闘ユニット更新
	var all_units: Array = player_units + enemy_units
	for u in player_units:
		if u.is_alive:
			u.update(delta, enemy_units, enemy_buildings, enemy_harvesters, grid, all_units, economy)
	for u in enemy_units:
		if u.is_alive:
			u.update(delta, player_units, player_buildings, player_harvesters, grid, all_units, ai.economy if ai != null else null)
	# 重なりカウント更新
	_update_stack_counts()
	# 死亡処理
	_remove_dead()
	# 勝敗判定
	_check_victory()

func _remove_dead() -> void:
	player_units = player_units.filter(func(u): return u.is_alive)
	player_harvesters = player_harvesters.filter(func(h): return h.is_alive)
	player_builders = player_builders.filter(func(b): return b.is_alive)
	enemy_units = enemy_units.filter(func(u): return u.is_alive)
	enemy_harvesters = enemy_harvesters.filter(func(h): return h.is_alive)
	enemy_builders = enemy_builders.filter(func(b): return b.is_alive)
	# 死亡後にharvester_indexを再採番
	for i in range(player_harvesters.size()):
		player_harvesters[i].harvester_index = i
	for i in range(enemy_harvesters.size()):
		enemy_harvesters[i].harvester_index = i

func _check_victory() -> void:
	if _game_over:
		return
	for b in player_buildings:
		if b.building_type == EconBuilding.BuildingType.BASE and not b.is_alive:
			_game_over = true
			is_running = false
			battle_ended.emit(false)
			log_message.emit("Defeat... Player base destroyed!")
			return
	for b in enemy_buildings:
		if b.building_type == EconBuilding.BuildingType.BASE and not b.is_alive:
			_game_over = true
			is_running = false
			battle_ended.emit(true)
			log_message.emit("Victory! Enemy base destroyed!")
			return

func spawn_player_unit(col: int, row: int, unit_type: int) -> void:
	var unit := EconUnit.create(unit_type, EconUnit.Side.PLAYER, col, row)
	unit.position = grid.hex_to_pixel(col, row)
	player_units.append(unit)
	get_parent().add_child(unit)
	var names := ["Attacker", "Tank", "Breaker"]
	log_message.emit("%s produced at (%d,%d)" % [names[unit_type], col, row])

func spawn_player_harvester(pos: Vector2i, economy: EconEconomy) -> void:
	var h := EconHarvester.new()
	h.grid_pos = pos
	h.economy = economy
	h.position = grid.hex_to_pixel(pos.x, pos.y)
	h.harvested.connect(func(rtype): economy.add_resource(rtype))
	h.harvester_index = player_harvesters.size()
	player_harvesters.append(h)
	grid.add_child(h)
	log_message.emit("Harvester spawned at (%d,%d)" % [pos.x, pos.y])

func spawn_player_builder(pos: Vector2i) -> void:
	var b := EconBuilder.new()
	b.grid_pos = pos
	b.is_player_side = true
	b.position = grid.hex_to_pixel(pos.x, pos.y)
	player_builders.append(b)
	grid.add_child(b)
	log_message.emit("Builder spawned at (%d,%d)" % [pos.x, pos.y])

func spawn_enemy_builder(pos: Vector2i) -> void:
	var b := EconBuilder.new()
	b.grid_pos = pos
	b.is_player_side = false
	b.position = grid.hex_to_pixel(pos.x, pos.y)
	enemy_builders.append(b)
	grid.add_child(b)

func add_building_to_queue(_b: EconBuilding) -> void:
	pass  # ビルダー方式に移行済み。ビルダーが自動的に未建設建物を担当する
func spawn_enemy_unit(utype: int, pos: Vector2i) -> void:
	var unit := EconUnit.create(utype, EconUnit.Side.ENEMY, pos.x, pos.y)
	unit.position = grid.hex_to_pixel(pos.x, pos.y)
	enemy_units.append(unit)
	grid.add_child(unit)

func spawn_enemy_harvester(pos: Vector2i, economy: EconEconomy) -> void:
	var h := EconHarvester.new()
	h.grid_pos = pos
	h.economy = economy
	h.position = grid.hex_to_pixel(pos.x, pos.y)
	h.harvested.connect(func(rtype): economy.add_resource(rtype))
	h.harvester_index = enemy_harvesters.size()
	enemy_harvesters.append(h)
	grid.add_child(h)

func register_enemy_building(b: EconBuilding) -> void:
	enemy_buildings.append(b)
	grid.add_child(b)

func register_player_building(b: EconBuilding) -> void:
	player_buildings.append(b)
	grid.add_child(b)

func _update_stack_counts() -> void:
	var counts: Dictionary = {}
	for u in player_units + enemy_units:
		if u.is_alive:
			counts[u.grid_pos] = counts.get(u.grid_pos, 0) + 1
	for u in player_units + enemy_units:
		u.stack_count = counts.get(u.grid_pos, 1) if u.is_alive else 1
