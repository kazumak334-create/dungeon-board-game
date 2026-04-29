class_name EconHarvester
extends Node2D

var grid_pos: Vector2i
var harvester_index: int = 0
var is_alive: bool = true

const MOVE_INTERVAL := 1.5
const HARVEST_INTERVAL := 2.0  # 1資源/2秒（要件定義書）

var _move_timer: float = 0.0
var _harvest_timer: float = 0.0
var _at_resource: bool = false

signal harvested(rtype: int)

var economy: EconEconomy = null

func update(delta: float, grid: EconGrid, all_units: Array) -> void:
	if not is_alive:
		return
	var target_type: int = EconGrid.ResourceType.WOOD
	if economy != null:
		target_type = economy.get_harvest_target_for(harvester_index)
	var rtype: int = grid.get_resource_type(grid_pos)
	if rtype == target_type:
		_at_resource = true
		_try_harvest(delta, rtype)
	else:
		_at_resource = false
		_try_move(delta, grid, all_units, target_type)

func _try_harvest(delta: float, rtype: int) -> void:
	_harvest_timer += delta
	if _harvest_timer >= HARVEST_INTERVAL:
		_harvest_timer = 0.0
		harvested.emit(rtype)
		queue_redraw()

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
		grid_pos = path[1]
		position = grid.hex_to_pixel(grid_pos.x, grid_pos.y)
		queue_redraw()

func take_damage(amount: float) -> void:
	# ハーベスターは非戦闘員。攻撃を受けたら即脱落
	is_alive = false
	visible = false

func _draw() -> void:
	if not is_alive:
		return
	draw_circle(Vector2.ZERO, 12.0, Color.YELLOW)
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 16, Color.DARK_GOLDENROD, 2.0)
	if _at_resource:
		var progress: float = _harvest_timer / HARVEST_INTERVAL
		draw_rect(Rect2(Vector2(-10, -20), Vector2(20.0 * progress, 3)), Color.CYAN)
