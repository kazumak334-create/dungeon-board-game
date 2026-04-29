class_name Poc2Grid
extends Node2D

const HEX_SIZE := 40.0
const ROWS := 11
const MAX_STACK: int = 3

var origin: Vector2 = Vector2.ZERO

# 資源エリア定義
enum ResourceType { NONE, WOOD, STONE, WHEAT }

# 各マスの資源タイプを格納
var resource_cells: Dictionary = {}  # Vector2i -> ResourceType

func _ready() -> void:
	print("[Poc2Grid] _ready called")
	_init_resource_cells()

func _init_resource_cells() -> void:
	# 木材: row4-5, col2-3
	for r in [4, 5]:
		for c in [2, 3]:
			resource_cells[Vector2i(c, r)] = ResourceType.WOOD
	# 石材: row4-5, col0-1 と col4-5
	for r in [4, 5]:
		for c in [0, 1, 4, 5]:
			if is_valid_cell(c, r):
				resource_cells[Vector2i(c, r)] = ResourceType.STONE
	# 小麦: row3, row6 の偶数列
	for c in [0, 2, 4]:
		if is_valid_cell(c, 3):
			resource_cells[Vector2i(c, 3)] = ResourceType.WHEAT
		if is_valid_cell(c, 6):
			resource_cells[Vector2i(c, 6)] = ResourceType.WHEAT

func get_resource_type(pos: Vector2i) -> ResourceType:
	return resource_cells.get(pos, ResourceType.NONE)

func get_resource_cells_of_type(rtype: ResourceType) -> Array:
	var result: Array = []
	for pos in resource_cells:
		if resource_cells[pos] == rtype:
			result.append(pos)
	return result

func get_col_count(row: int) -> int:
	if row % 2 == 0:
		return 6
	return 5

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
		var neighbors: Array = get_neighbors(current.x, current.y)
		for nb in neighbors:
			if nb == goal:
				var full_path: Array = path.duplicate()
				full_path.append(nb)
				return full_path
			if blocked.get(nb, 0) >= MAX_STACK:
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
			# 資源エリアの色
			var rtype: ResourceType = get_resource_type(pos)
			match rtype:
				ResourceType.WOOD:
					draw_colored_polygon(corners, Color(0.2, 0.6, 0.1, 0.4))
				ResourceType.STONE:
					draw_colored_polygon(corners, Color(0.5, 0.5, 0.5, 0.4))
				ResourceType.WHEAT:
					draw_colored_polygon(corners, Color(0.9, 0.8, 0.1, 0.4))
			# 配置可能ゾーン（row0-2: プレイヤー配置エリア）
			if row <= 2:
				draw_colored_polygon(corners, Color(0.2, 0.4, 0.8, 0.15))
			elif row >= 8:
				draw_colored_polygon(corners, Color(0.8, 0.2, 0.2, 0.15))
			# グリッド線
			var closed := corners.duplicate()
			closed.append(corners[0])
			draw_polyline(closed, Color(1, 1, 1, 0.4), 1.0)
