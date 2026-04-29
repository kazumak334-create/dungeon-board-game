class_name EconBattle
extends Node

signal battle_ended(player_won: bool)
signal log_message(text: String)

var player_units: Array = []
var enemy_units: Array = []
var player_harvesters: Array = []
var enemy_harvesters: Array = []
var player_buildings: Array = []
var enemy_buildings: Array = []

var grid: EconGrid
var economy: EconEconomy
var _construction_queue: Array = []

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
	# 建設キュー処理
	if _construction_queue.size() > 0:
		var next: EconBuilding = _construction_queue[0]
		if not next.is_alive:
			_construction_queue.pop_front()
		else:
			var cost: Dictionary = EconBuilding.BUILD_COSTS.get(int(next.building_type), {})
			if economy.can_afford(cost):
				economy.spend(cost)
				next.is_built = true
				next.queue_redraw()
				_construction_queue.pop_front()
				var names := ["Barracks", "Fortress", "Workshop", "Village", "Base"]
				log_message.emit("Built: %s at (%d,%d)" % [names[int(next.building_type)], next.grid_pos.x, next.grid_pos.y])
	# 経済更新（小麦消費）
	var total_units: int = player_units.size() + player_harvesters.size()
	economy.update(delta, total_units)
	# ハーベスター更新
	var all_movable: Array = player_units + player_harvesters + enemy_units
	for h in player_harvesters:
		if h.is_alive:
			h.update(delta, grid, all_movable)
	# 建物更新（プレイヤー側のみ）
	for b in player_buildings:
		if b.is_alive:
			b.update(delta, economy)
	# 戦闘ユニット更新
	var all_units: Array = player_units + enemy_units
	for u in player_units:
		if u.is_alive:
			u.update(delta, enemy_units, enemy_buildings, enemy_harvesters, grid, all_units)
	for u in enemy_units:
		if u.is_alive:
			u.update(delta, player_units, player_buildings, player_harvesters, grid, all_units)
	# 死亡処理
	_remove_dead()
	# 勝敗判定
	_check_victory()

func _remove_dead() -> void:
	player_units = player_units.filter(func(u): return u.is_alive)
	player_harvesters = player_harvesters.filter(func(h): return h.is_alive)
	enemy_units = enemy_units.filter(func(u): return u.is_alive)

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

func spawn_player_harvester(col: int, row: int, eco: EconEconomy) -> void:
	var h := EconHarvester.new()
	h.grid_pos = Vector2i(col, row)
	h.economy = eco
	h.position = grid.hex_to_pixel(col, row)
	h.harvested.connect(func(rtype): eco.add_resource(rtype))
	h.harvester_index = player_harvesters.size()
	player_harvesters.append(h)
	get_parent().add_child(h)
	log_message.emit("Harvester spawned at (%d,%d)" % [col, row])

func add_building_to_queue(b: EconBuilding) -> void:
	_construction_queue.append(b)
