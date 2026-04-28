class_name HexGrid
extends Node2D

const HEX_SIZE := 40.0
const ROWS := 11

var origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("[HexGrid] _ready called")

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
			# goalでないセルが満杯(3以上)の場合はスキップ
			if blocked.get(nb, 0) >= 3:
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
			var center := hex_to_pixel(col, row)
			var corners := _get_hex_corners(center)
			# ゾーン塗りつぶし
			if row <= 2:
				draw_colored_polygon(corners, Color(0.2, 0.4, 0.8, 0.2))
			elif row >= 8:
				draw_colored_polygon(corners, Color(0.8, 0.2, 0.2, 0.2))
			# グリッド線
			var line_color := Color(1, 1, 1, 0.5)
			var closed_corners := corners.duplicate()
			closed_corners.append(corners[0])
			draw_polyline(closed_corners, line_color, 1.0)
