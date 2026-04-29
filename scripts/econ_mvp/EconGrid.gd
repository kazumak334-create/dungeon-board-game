class_name EconGrid
extends Node2D

const HEX_SIZE := 34.0
const ROWS := 12
const MAX_STACK: int = 3

enum ResourceType { NONE, WOOD, STONE, SULFUR, WHEAT }
enum TileType { PLAIN, MOUNTAIN, DESERT }

var origin: Vector2 = Vector2.ZERO
var resource_cells: Dictionary = {}
var seed_value: int = 42
var tile_cells: Dictionary = {}   # Vector2i → TileType
var mountain_ratio: int = 35
var desert_ratio: int = 25

func _ready() -> void:
	_init_resource_cells()

func _init_resource_cells() -> void:
	resource_cells.clear()
	tile_cells.clear()

	# --- 全セルを PLAIN で初期化 ---
	for row in range(ROWS):
		for col in range(get_col_count(row)):
			tile_cells[Vector2i(col, row)] = TileType.PLAIN

	# --- 自陣セル（row 0-3）を収集してシャッフル ---
	var player_cells: Array = []
	for row in range(0, 4):          # 旧: range(0, 5)
		for col in range(get_col_count(row)):
			player_cells.append(Vector2i(col, row))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	seed_value = rng.seed
	for i in range(player_cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = player_cells[i]
		player_cells[i] = player_cells[j]
		player_cells[j] = tmp
	# 自陣先頭4マスにWOOD、次4にSTONE、次4にSULFUR、次2にWHEAT
	for i in range(4):
		resource_cells[player_cells[i]] = ResourceType.WOOD
	for i in range(4, 8):
		resource_cells[player_cells[i]] = ResourceType.STONE
	for i in range(8, 12):
		resource_cells[player_cells[i]] = ResourceType.SULFUR
	for i in range(12, 14):
		resource_cells[player_cells[i]] = ResourceType.WHEAT

	# --- 敵陣セル（row 8-11）を収集してシャッフル ---
	var enemy_cells: Array = []
	for row in range(8, 12):          # 旧: range(6, 11)
		for col in range(get_col_count(row)):
			enemy_cells.append(Vector2i(col, row))
	rng.seed = seed_value + 1
	for i in range(enemy_cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = enemy_cells[i]
		enemy_cells[i] = enemy_cells[j]
		enemy_cells[j] = tmp
	# 敵陣先頭4マスにWOOD、次4にSTONE、次4にSULFUR、次2にWHEAT
	for i in range(4):
		resource_cells[enemy_cells[i]] = ResourceType.WOOD
	for i in range(4, 8):
		resource_cells[enemy_cells[i]] = ResourceType.STONE
	for i in range(8, 12):
		resource_cells[enemy_cells[i]] = ResourceType.SULFUR
	for i in range(12, 14):
		resource_cells[enemy_cells[i]] = ResourceType.WHEAT

	# --- 地形を生成 ---
	generate_terrain(mountain_ratio, desert_ratio)

func get_resource_type(pos: Vector2i) -> ResourceType:
	return resource_cells.get(pos, ResourceType.NONE)

func generate_terrain(p_mountain_ratio: int, p_desert_ratio: int) -> void:
	mountain_ratio = p_mountain_ratio
	desert_ratio = p_desert_ratio

	# 地形リセット（resource_cells は維持）
	for row in range(ROWS):
		for col in range(get_col_count(row)):
			tile_cells[Vector2i(col, row)] = TileType.PLAIN

	# 中央ゾーン（row 4-7）に山岳・砂漠を配置
	var center_cells: Array = []
	for row in range(4, 8):
		for col in range(get_col_count(row)):
			center_cells.append(Vector2i(col, row))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 2
	# Fisher-Yates シャッフル
	for i in range(center_cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = center_cells[i]
		center_cells[i] = center_cells[j]
		center_cells[j] = tmp

	var total := center_cells.size()
	var m_count := int(total * p_mountain_ratio / 100.0)
	var d_count := int(total * p_desert_ratio / 100.0)

	for i in range(m_count):
		tile_cells[center_cells[i]] = TileType.MOUNTAIN
	for i in range(m_count, m_count + d_count):
		tile_cells[center_cells[i]] = TileType.DESERT

	# 経路保証: row3→row8 の BFS が通るまで山岳を除去
	_ensure_passable_path()
	queue_redraw()

func _ensure_passable_path() -> void:
	while true:
		# row 3 の中央列から row 8 まで到達できるか確認
		var mid_col := get_col_count(3) / 2
		if _bfs_can_reach_row(Vector2i(mid_col, 3), 8):
			return
		# 到達できない → 中央ゾーンの山岳を1つ除去
		var removed := false
		for row in range(4, 8):
			var mid := get_col_count(row) / 2
			for dc in [0, -1, 1, -2, 2]:
				var pos := Vector2i(mid + dc, row)
				if tile_cells.get(pos, TileType.PLAIN) == TileType.MOUNTAIN:
					tile_cells[pos] = TileType.PLAIN
					removed = true
					break
			if removed:
				break
		if not removed:
			return  # 除去できる山岳がない

func _bfs_can_reach_row(start: Vector2i, target_row: int) -> bool:
	var queue: Array = [start]
	var visited: Dictionary = {start: true}
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		if cur.y == target_row:
			return true
		for nb in get_neighbors(cur.x, cur.y):
			if not visited.has(nb) and tile_cells.get(nb, TileType.PLAIN) != TileType.MOUNTAIN:
				visited[nb] = true
				queue.append(nb)
	return false

func get_tile_type(pos: Vector2i) -> TileType:
	return tile_cells.get(pos, TileType.PLAIN)

func is_mountain(pos: Vector2i) -> bool:
	return tile_cells.get(pos, TileType.PLAIN) == TileType.MOUNTAIN

func get_resource_cells_of_type(rtype: ResourceType) -> Array:
	var result: Array = []
	for pos in resource_cells:
		if resource_cells[pos] == rtype:
			result.append(pos)
	return result

func get_col_count(row: int) -> int:
	if row % 2 == 0:
		return 13   # 旧: 11
	return 12       # 旧: 10

func hex_to_pixel(col: int, row: int) -> Vector2:
	var hex_width := HEX_SIZE * sqrt(3.0)
	var hex_height := HEX_SIZE * 2.0
	var px := hex_width * col
	if row % 2 == 1:
		px += hex_width * 0.5
	var py := hex_height * 0.75 * row
	return origin + Vector2(px, py)

func is_valid_cell(col: int, row: int) -> bool:
	if row < 0 or row >= ROWS:
		return false
	var max_col := get_col_count(row)
	return col >= 0 and col < max_col

func get_neighbors(col: int, row: int) -> Array:
	var dirs_even := [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(0, -1),
		Vector2i(-1, 1), Vector2i(0, 1)
	]
	var dirs_odd := [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(0, 1), Vector2i(1, 1)
	]
	var dirs := dirs_even if row % 2 == 0 else dirs_odd
	var result: Array = []
	for d in dirs:
		var nc: int = col + d.x
		var nr: int = row + d.y
		if is_valid_cell(nc, nr):
			result.append(Vector2i(nc, nr))
	return result

func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ax := a.x - (a.y - (a.y & 1)) / 2
	var az := a.y
	var ay := -ax - az
	var bx := b.x - (b.y - (b.y & 1)) / 2
	var bz := b.y
	var by_ := -bx - bz
	return maxi(maxi(absi(ax - bx), absi(ay - by_)), absi(az - bz))

func bfs_path(start: Vector2i, goal: Vector2i, blocked: Dictionary = {}) -> Array:
	if start == goal:
		return []
	var queue: Array = [[start]]
	var visited: Dictionary = {start: true}
	while queue.size() > 0:
		var path: Array = queue.pop_front()
		var current: Vector2i = path[path.size() - 1]
		for nb in get_neighbors(current.x, current.y):
			if nb == goal:
				var full_path: Array = path.duplicate()
				full_path.append(nb)
				return full_path
			if blocked.get(nb, 0) >= MAX_STACK:
				continue
			if tile_cells.get(nb, TileType.PLAIN) == TileType.MOUNTAIN:
				continue
			if not visited.has(nb):
				visited[nb] = true
				var new_path: Array = path.duplicate()
				new_path.append(nb)
				queue.append(new_path)
	return []

func _get_hex_corners(center: Vector2) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for i in range(6):
		var angle_deg := 60.0 * i - 30.0
		var angle_rad := deg_to_rad(angle_deg)
		corners.append(center + Vector2(HEX_SIZE * cos(angle_rad), HEX_SIZE * sin(angle_rad)))
	return corners

func _draw() -> void:
	for row in range(ROWS):
		var col_count := get_col_count(row)
		for col in range(col_count):
			var pos := Vector2i(col, row)
			var center := hex_to_pixel(col, row)
			var corners := _get_hex_corners(center)
			var rtype: ResourceType = get_resource_type(pos)
			match rtype:
				ResourceType.WOOD:
					draw_colored_polygon(corners, Color(0.2, 0.6, 0.1, 0.5))
				ResourceType.STONE:
					draw_colored_polygon(corners, Color(0.5, 0.5, 0.5, 0.5))
				ResourceType.SULFUR:
					draw_colored_polygon(corners, Color(0.8, 0.7, 0.1, 0.5))
				ResourceType.WHEAT:
					draw_colored_polygon(corners, Color(0.9, 0.9, 0.3, 0.5))
			# TileType 描画（resource なしセルのみ）
			var ttype: TileType = get_tile_type(pos)
			if rtype == ResourceType.NONE:
				match ttype:
					TileType.MOUNTAIN:
						draw_colored_polygon(corners, Color(0.3, 0.25, 0.2, 0.7))
					TileType.DESERT:
						draw_colored_polygon(corners, Color(0.85, 0.75, 0.4, 0.5))
					TileType.PLAIN:
						pass  # 何も塗らない（デフォルト背景）
			if row <= 3:   # 旧: row <= 4
				draw_colored_polygon(corners, Color(0.2, 0.4, 0.8, 0.1))
			elif row >= 8:  # 旧: row >= 6
				draw_colored_polygon(corners, Color(0.8, 0.2, 0.2, 0.1))
			var closed := corners.duplicate()
			closed.append(corners[0])
			draw_polyline(closed, Color(1, 1, 1, 0.4), 1.0)
