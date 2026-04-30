class_name EconHarvester
extends Node2D

var grid_pos: Vector2i
var harvester_index: int = 0
var is_alive: bool = true

const MOVE_INTERVAL := 2.0
const HARVEST_INTERVAL := 5.0  # 1資源/5秒
const MOVE_ANIM_DURATION := 0.4
const FLEE_RADIUS := 3

var _move_timer: float = 0.0
var _harvest_timer: float = 0.0
var _at_resource: bool = false
var _anim_from: Vector2 = Vector2.ZERO
var _anim_to: Vector2 = Vector2.ZERO
var _anim_t: float = 1.0
var _is_fleeing: bool = false

signal harvested(rtype: int)

var economy: EconEconomy = null

func update(delta: float, grid: EconGrid, all_units: Array, enemy_units: Array, player_buildings: Array = [], total_harvesters: int = 1) -> void:
	if not is_alive:
		return
	if _anim_t < 1.0:
		_anim_t = minf(1.0, _anim_t + delta / MOVE_ANIM_DURATION)
		position = _anim_from.lerp(_anim_to, _anim_t)
		queue_redraw()
	_check_flee(enemy_units, grid)
	if _is_fleeing:
		_flee_move(delta, grid, all_units, enemy_units)
		return
	var target_type: int = EconGrid.ResourceType.WOOD
	if economy != null:
		target_type = economy.get_harvest_target_for(harvester_index, total_harvesters)
	# 農村グリッド座標を収穫対象として追加（天然小麦タイルと同等扱い）
	var village_positions: Array = _get_village_positions(player_buildings)
	var rtype: int = grid.get_resource_type(grid_pos)
	if rtype == target_type:
		_at_resource = true
		_try_harvest(delta, rtype)
	elif target_type == EconGrid.ResourceType.WHEAT and grid_pos in village_positions:
		# 農村上にいる場合は小麦として収穫
		_at_resource = true
		_try_harvest(delta, EconGrid.ResourceType.WHEAT)
	else:
		_at_resource = false
		_try_move_with_villages(delta, grid, all_units, target_type, village_positions)

func _check_flee(enemy_units: Array, grid: EconGrid) -> void:
	_is_fleeing = false
	for u in enemy_units:
		if u.get("is_alive") != null and u.is_alive and u.get("grid_pos") != null:
			if grid.hex_distance(grid_pos, u.grid_pos) <= FLEE_RADIUS:
				_is_fleeing = true
				return

func _flee_move(delta: float, grid: EconGrid, all_units: Array, enemy_units: Array) -> void:
	_move_timer += delta
	if _move_timer < MOVE_INTERVAL:
		return
	_move_timer = 0.0
	# 最近傍敵を特定
	var nearest_enemy: Node = null
	var nearest_dist: int = FLEE_RADIUS + 1
	for u in enemy_units:
		if u.get("is_alive") != null and u.is_alive and u.get("grid_pos") != null:
			var d: int = grid.hex_distance(grid_pos, u.grid_pos)
			if d < nearest_dist:
				nearest_dist = d
				nearest_enemy = u
	if nearest_enemy == null:
		return
	var blocked: Dictionary = {}
	for u in all_units:
		if u != self and u.get("is_alive") != null and u.is_alive and u.get("grid_pos") != null:
			var cnt: int = blocked.get(u.grid_pos, 0)
			blocked[u.grid_pos] = cnt + 1
	var neighbors: Array = grid.get_neighbors(grid_pos.x, grid_pos.y)
	var best_cell := grid_pos
	var best_dist: int = grid.hex_distance(grid_pos, nearest_enemy.grid_pos)
	for nb in neighbors:
		if grid.is_mountain(nb):
			continue
		if blocked.get(nb, 0) >= EconGrid.MAX_STACK:
			continue
		var d: int = grid.hex_distance(nb, nearest_enemy.grid_pos)
		if d > best_dist:
			best_dist = d
			best_cell = nb
	if best_cell != grid_pos:
		_anim_from = position
		grid_pos = best_cell
		_anim_to = grid.hex_to_pixel(grid_pos.x, grid_pos.y)
		_anim_t = 0.0

func _try_harvest(delta: float, rtype: int) -> void:
	_harvest_timer += delta
	if _harvest_timer >= HARVEST_INTERVAL:
		_harvest_timer = 0.0
		harvested.emit(rtype)
		queue_redraw()

func _get_village_positions(buildings: Array) -> Array:
	var positions: Array = []
	for b in buildings:
		if b.get("is_alive") == null or not b.is_alive:
			continue
		if b.get("is_built") == null or not b.is_built:
			continue
		if b.get("building_type") == null:
			continue
		if b.building_type == EconBuilding.BuildingType.VILLAGE:
			positions.append(b.grid_pos)
	return positions

func _try_move_with_villages(delta: float, grid: EconGrid, all_units: Array, target_type: int, village_positions: Array) -> void:
	_move_timer += delta
	if _move_timer < MOVE_INTERVAL:
		return
	_move_timer = 0.0
	# 天然小麦タイル＋農村座標を合算してターゲット候補を作る
	var targets: Array = grid.get_resource_cells_of_type(target_type)
	if target_type == EconGrid.ResourceType.WHEAT:
		for vp in village_positions:
			if not targets.has(vp):
				targets.append(vp)
	if targets.is_empty():
		return
	var best_target: Vector2i = targets[0]
	var best_dist: int = grid.hex_distance(grid_pos, best_target)
	for t in targets:
		var d: int = grid.hex_distance(grid_pos, t)
		if d < best_dist:
			best_dist = d
			best_target = t
	var blocked: Dictionary = {}
	for u in all_units:
		if u != self and u.get("is_alive") != null and u.is_alive:
			if u.get("grid_pos") != null:
				var cnt: int = blocked.get(u.grid_pos, 0)
				blocked[u.grid_pos] = cnt + 1
	var path: Array = grid.bfs_path(grid_pos, best_target, blocked)
	if path.size() >= 2:
		_anim_from = position
		grid_pos = path[1]
		_anim_to = grid.hex_to_pixel(grid_pos.x, grid_pos.y)
		_anim_t = 0.0

func _try_move(delta: float, grid: EconGrid, all_units: Array, target_type: int) -> void:
	_move_timer += delta
	if _move_timer < MOVE_INTERVAL:
		return
	_move_timer = 0.0
	var targets: Array = grid.get_resource_cells_of_type(target_type)
	if targets.is_empty():
		return
	var best_target: Vector2i = targets[0]
	var best_dist: int = grid.hex_distance(grid_pos, best_target)
	for t in targets:
		var d: int = grid.hex_distance(grid_pos, t)
		if d < best_dist:
			best_dist = d
			best_target = t
	var blocked: Dictionary = {}
	for u in all_units:
		if u != self and u.get("is_alive") != null and u.is_alive:
			if u.get("grid_pos") != null:
				var cnt: int = blocked.get(u.grid_pos, 0)
				blocked[u.grid_pos] = cnt + 1
	var path: Array = grid.bfs_path(grid_pos, best_target, blocked)
	if path.size() >= 2:
		_anim_from = position
		grid_pos = path[1]
		_anim_to = grid.hex_to_pixel(grid_pos.x, grid_pos.y)
		_anim_t = 0.0

func take_damage(amount: float) -> void:
	# ハーベスターは非戦闘員。攻撃を受けたら即脱落
	is_alive = false
	visible = false

func _draw() -> void:
	if not is_alive:
		return
	draw_circle(Vector2.ZERO, 8.0, Color.YELLOW)
	draw_arc(Vector2.ZERO, 8.0, 0, TAU, 16, Color.DARK_GOLDENROD, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-4, 5), "H", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.BLACK)
	if _at_resource and not _is_fleeing:
		var progress: float = _harvest_timer / HARVEST_INTERVAL
		draw_rect(Rect2(Vector2(-10, -16), Vector2(20.0 * progress, 3)), Color.CYAN)
