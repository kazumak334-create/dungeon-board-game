class_name Poc2Harvester
extends Node2D

var grid_pos: Vector2i
var is_alive: bool = true
var target_resource_type: int = 1  # Poc2Grid.ResourceType (1=WOOD,2=STONE,3=WHEAT)

const MOVE_INTERVAL := 1.5  # 移動速度（秒/セル）
const HARVEST_INTERVAL := 3.0

var _move_timer: float = 0.0
var _harvest_timer: float = 0.0
var _at_resource: bool = false

signal harvested(rtype: int)

func update(delta: float, grid: Node, all_units: Array) -> void:
	if not is_alive:
		return
	var rtype: int = grid.get_resource_type(grid_pos)
	if rtype == target_resource_type:
		_at_resource = true
		_try_harvest(delta)
	else:
		_at_resource = false
		_try_move(delta, grid, all_units)

func _try_harvest(delta: float) -> void:
	_harvest_timer += delta
	if _harvest_timer >= HARVEST_INTERVAL:
		_harvest_timer = 0.0
		harvested.emit(target_resource_type)
		queue_redraw()

func _try_move(delta: float, grid: Node, all_units: Array) -> void:
	_move_timer += delta
	if _move_timer < MOVE_INTERVAL:
		return
	_move_timer = 0.0
	# 目標資源エリアを探す
	var targets: Array = grid.get_resource_cells_of_type(target_resource_type)
	if targets.is_empty():
		return
	# 最寄りのターゲットへBFS
	var best_target: Vector2i = targets[0]
	var best_dist: int = grid.hex_distance(grid_pos, best_target)
	for t in targets:
		var d: int = grid.hex_distance(grid_pos, t)
		if d < best_dist:
			best_dist = d
			best_target = t
	var blocked: Dictionary = {}
	for u in all_units:
		if u.is_alive and u != self:
			var cnt: int = blocked.get(u.grid_pos, 0)
			blocked[u.grid_pos] = cnt + 1
	var path: Array = grid.bfs_path(grid_pos, best_target, blocked)
	if path.size() >= 2:
		grid_pos = path[1]
		position = grid.hex_to_pixel(grid_pos.x, grid_pos.y)
		queue_redraw()

func _draw() -> void:
	# 黄色い六角形（小さめ）
	draw_circle(Vector2.ZERO, 12.0, Color.YELLOW)
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 16, Color.DARK_GOLDENROD, 2.0)
	# HPバー不要（非戦闘員）
	if _at_resource:
		# 採掘中インジケータ
		var progress: float = _harvest_timer / HARVEST_INTERVAL
		draw_rect(Rect2(Vector2(-10, -20), Vector2(20 * progress, 3)), Color.CYAN)
