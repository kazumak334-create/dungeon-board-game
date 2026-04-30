class_name EconBuilder
extends Node2D

var grid_pos: Vector2i
var is_alive: bool = true
var is_player_side: bool = true

const MOVE_INTERVAL := 2.0
const CONSTRUCTION_RATE := 1.0  # pt/秒
const MOVE_ANIM_DURATION := 0.4
const FLEE_RADIUS := 3

var _move_timer: float = 0.0
var _anim_from: Vector2 = Vector2.ZERO
var _anim_to: Vector2 = Vector2.ZERO
var _anim_t: float = 1.0
var _is_fleeing: bool = false

var _target_building: EconBuilding = null

func update(delta: float, grid: EconGrid, all_units: Array, buildings: Array, focus_mode: bool, economy: EconEconomy, enemy_units: Array) -> void:
	if not is_alive:
		return
	# スムーズ移動アニメーション
	if _anim_t < 1.0:
		_anim_t = minf(1.0, _anim_t + delta / MOVE_ANIM_DURATION)
		position = _anim_from.lerp(_anim_to, _anim_t)
		queue_redraw()
	_check_flee(enemy_units, grid)
	if _is_fleeing:
		_flee_move(delta, grid, all_units, enemy_units)
		return
	# ターゲット選択
	if _target_building == null or not _target_building.is_alive or _target_building.is_built:
		_target_building = _pick_target(buildings, focus_mode)
	if _target_building == null:
		return
	# 目的地に到着していれば建設進捗を加算
	if grid_pos == _target_building.grid_pos:
		var btype_int: int = int(_target_building.building_type)
		var cost: Dictionary = EconBuilding.BUILD_COSTS.get(btype_int, {})
		var required: float = EconBuilding.REQUIRED_CONSTRUCTION.get(btype_int, 5.0)
		_target_building._construction_ready = economy.can_afford(cost)
		_target_building.queue_redraw()
		if economy.can_afford(cost):
			_target_building.build_progress += CONSTRUCTION_RATE * delta
			if _target_building.build_progress >= required:
				economy.spend(cost)
				_target_building.is_built = true
				_target_building.build_progress = required
				_target_building.queue_redraw()
				_target_building = null
			else:
				queue_redraw()
	else:
		_try_move(delta, grid, all_units)

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

func _pick_target(buildings: Array, focus_mode: bool) -> EconBuilding:
	var candidates: Array = []
	for b in buildings:
		if b.is_alive and not b.is_built:
			candidates.append(b)
	if candidates.is_empty():
		return null
	if focus_mode:
		# 集中建設: build_priority が最大のものを選ぶ（同値なら最初のもの）
		var best: EconBuilding = candidates[0]
		for c in candidates:
			if c.build_priority > best.build_priority:
				best = c
		return best
	else:
		# 並列建設: 他のビルダーが担当していない建物を探す
		# 自分がすでにターゲット済みならそれを返す
		# ここでは候補の中で最も build_priority が高いものを返す（簡易実装）
		var best: EconBuilding = candidates[0]
		for c in candidates:
			if c.build_priority > best.build_priority:
				best = c
		return best

func _try_move(delta: float, grid: EconGrid, all_units: Array) -> void:
	_move_timer += delta
	if _move_timer < MOVE_INTERVAL:
		return
	_move_timer = 0.0
	if _target_building == null:
		return
	var blocked: Dictionary = {}
	for u in all_units:
		if u != self and u.get("is_alive") != null and u.is_alive:
			if u.get("grid_pos") != null:
				var cnt: int = blocked.get(u.grid_pos, 0)
				blocked[u.grid_pos] = cnt + 1
	var path: Array = grid.bfs_path(grid_pos, _target_building.grid_pos, blocked)
	if path.size() >= 2:
		_anim_from = position
		grid_pos = path[1]
		_anim_to = grid.hex_to_pixel(grid_pos.x, grid_pos.y)
		_anim_t = 0.0

func take_damage(amount: float) -> void:
	is_alive = false
	visible = false

func _draw() -> void:
	if not is_alive:
		return
	draw_circle(Vector2.ZERO, 8.0, Color.ORANGE)
	draw_arc(Vector2.ZERO, 8.0, 0, TAU, 16, Color.DARK_ORANGE, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-4, 5), "B", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)
	# 建設中なら進捗バーを表示
	if _target_building != null and grid_pos == _target_building.grid_pos and not _is_fleeing:
		var req: float = EconBuilding.REQUIRED_CONSTRUCTION.get(int(_target_building.building_type), 5.0)
		var progress: float = _target_building.build_progress / req if req > 0 else 0.0
		draw_rect(Rect2(Vector2(-10, -16), Vector2(20.0 * progress, 3)), Color.CYAN)
