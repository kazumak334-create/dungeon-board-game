class_name EconGrid
extends Node2D

const HEX_SIZE := 24.0
const ROWS := 13
const MAX_STACK: int = 3

enum ResourceType { NONE, WOOD, STONE, SULFUR, WHEAT, IRON, COTTON }
enum TileType { PLAIN, MOUNTAIN, DESERT }

var origin: Vector2 = Vector2.ZERO
var resource_cells: Dictionary = {}
var seed_value: int = 42
var tile_cells: Dictionary = {}   # Vector2i → TileType
var mountain_ratio: int = 35
var desert_ratio: int = 25

# 建設可能エリアハイライト（EconMainがセットする）
var highlight_cells: Dictionary = {}  # Vector2i -> true
var enemy_territory_cells: Dictionary = {}  # Vector2i -> true（敵領土セット）
var fill_cells: Dictionary = {}  # Vector2i -> true（建設モード時のみ塗りつぶし対象セル）
var resource_highlight_type: int = 0  # ResourceType値（0=NONE）。建設モード時に対応資源タイルを枠線強調

# Phase 3: BASE長押しリング進捗（EconMainがセットする）
var base_longpress_cell: Vector2i = Vector2i(-1, -1)  # -1,-1なら無効
var base_longpress_progress: float = 0.0  # 0.0〜1.0

func _ready() -> void:
	_init_resource_cells()

func _init_resource_cells() -> void:
	resource_cells.clear()
	tile_cells.clear()

	# --- 全セルを PLAIN で初期化 ---
	for row in range(ROWS):
		for col in range(get_col_count(row)):
			tile_cells[Vector2i(col, row)] = TileType.PLAIN

	# --- 自陣セル（col 0-7）を収集してシャッフル ---
	var player_cells: Array = []
	for col in range(0, 8):
		for row in range(ROWS):
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
	# IRON×2 を後列（col 5-7）から選ぶ
	var player_back: Array = []
	for c in range(5, 8):
		for r in range(ROWS):
			var bc := Vector2i(c, r)
			if not resource_cells.has(bc):
				player_back.append(bc)
	rng.seed = seed_value + 10
	for i in range(player_back.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = player_back[i]
		player_back[i] = player_back[j]
		player_back[j] = tmp
	if player_back.size() >= 2:
		resource_cells[player_back[0]] = ResourceType.IRON
		resource_cells[player_back[1]] = ResourceType.IRON
	# COTTON×2 を残りのセルからランダム選択
	var player_remain: Array = []
	for pc in player_cells:
		if not resource_cells.has(pc):
			player_remain.append(pc)
	rng.seed = seed_value + 11
	for i in range(player_remain.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = player_remain[i]
		player_remain[i] = player_remain[j]
		player_remain[j] = tmp
	if player_remain.size() >= 2:
		resource_cells[player_remain[0]] = ResourceType.COTTON
		resource_cells[player_remain[1]] = ResourceType.COTTON

	# --- 敵陣セル（col 18-25）を収集してシャッフル ---
	var enemy_cells: Array = []
	for col in range(18, 26):
		for row in range(ROWS):
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
	# 敵陣 IRON×2 を後列（col 20-22）から選ぶ
	var enemy_back: Array = []
	for c in range(20, 23):
		for r in range(ROWS):
			var bc := Vector2i(c, r)
			if not resource_cells.has(bc):
				enemy_back.append(bc)
	rng.seed = seed_value + 12
	for i in range(enemy_back.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = enemy_back[i]
		enemy_back[i] = enemy_back[j]
		enemy_back[j] = tmp
	if enemy_back.size() >= 2:
		resource_cells[enemy_back[0]] = ResourceType.IRON
		resource_cells[enemy_back[1]] = ResourceType.IRON
	# 敵陣 COTTON×2 を残りのセルからランダム選択
	var enemy_remain: Array = []
	for ec in enemy_cells:
		if not resource_cells.has(ec):
			enemy_remain.append(ec)
	rng.seed = seed_value + 13
	for i in range(enemy_remain.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = enemy_remain[i]
		enemy_remain[i] = enemy_remain[j]
		enemy_remain[j] = tmp
	if enemy_remain.size() >= 2:
		resource_cells[enemy_remain[0]] = ResourceType.COTTON
		resource_cells[enemy_remain[1]] = ResourceType.COTTON

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

	# 中央ゾーン（col 8-17）に山岳・砂漠を配置
	var center_cells: Array = []
	for col in range(8, 18):
		for row in range(ROWS):
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
		# col 7 の中央行から col 18 まで到達できるか確認
		var mid_row := ROWS / 2
		if _bfs_can_reach_col(Vector2i(7, mid_row), 18):
			return
		# 到達できない → 中央ゾーンの山岳を1つ除去
		var removed := false
		for col in range(8, 18):
			var mid := ROWS / 2
			for dr in [0, -1, 1, -2, 2]:
				var pos := Vector2i(col, mid + dr)
				if is_valid_cell(pos.x, pos.y) and tile_cells.get(pos, TileType.PLAIN) == TileType.MOUNTAIN:
					tile_cells[pos] = TileType.PLAIN
					removed = true
					break
			if removed:
				break
		if not removed:
			return  # 除去できる山岳がない

func _bfs_can_reach_col(start: Vector2i, target_col: int) -> bool:
	var queue: Array = [start]
	var visited: Dictionary = {start: true}
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		if cur.x == target_col:
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
	return 26

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

func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var n: int = hex_distance(from, to)
	if n <= 1:
		return true
	var fx: float = float(from.x - (from.y - (from.y & 1)) / 2)
	var fz: float = float(from.y)
	var fy: float = -fx - fz
	var tx: float = float(to.x - (to.y - (to.y & 1)) / 2)
	var tz: float = float(to.y)
	var ty: float = -tx - tz
	for i in range(1, n):
		var t: float = float(i) / float(n)
		var cx: float = fx + (tx - fx) * t
		var cy: float = fy + (ty - fy) * t
		var cz: float = fz + (tz - fz) * t
		var rx: int = roundi(cx)
		var ry: int = roundi(cy)
		var rz: int = roundi(cz)
		var dx: float = abs(float(rx) - cx)
		var dy: float = abs(float(ry) - cy)
		var dz: float = abs(float(rz) - cz)
		if dx > dy and dx > dz:
			rx = -ry - rz
		elif dy > dz:
			ry = -rx - rz
		else:
			rz = -rx - ry
		var col: int = rx + (rz - (rz & 1)) / 2
		var row: int = rz
		var cell: Vector2i = Vector2i(col, row)
		if tile_cells.get(cell, TileType.PLAIN) == TileType.MOUNTAIN:
			return false
	return true

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
					draw_colored_polygon(corners, Color8(63, 82, 50))
				ResourceType.STONE:
					draw_colored_polygon(corners, Color8(93, 86, 78))
				ResourceType.SULFUR:
					draw_colored_polygon(corners, Color8(154, 138, 60))
				ResourceType.WHEAT:
					draw_colored_polygon(corners, Color8(169, 146, 80))
				ResourceType.IRON:
					draw_colored_polygon(corners, Color8(80, 65, 55))
				ResourceType.COTTON:
					draw_colored_polygon(corners, Color8(240, 235, 220))
			# TileType 描画（resource なしセルのみ）
			var ttype: TileType = get_tile_type(pos)
			if rtype == ResourceType.NONE:
				match ttype:
					TileType.MOUNTAIN:
						draw_colored_polygon(corners, Color8(58, 50, 43))
					TileType.DESERT:
						draw_colored_polygon(corners, Color8(184, 168, 128))
					TileType.PLAIN:
						draw_colored_polygon(corners, Color8(94, 106, 77))
			if col <= 7:
				draw_colored_polygon(corners, Color(0.2, 0.4, 0.8, 0.1))
			elif col >= 18:
				draw_colored_polygon(corners, Color(0.8, 0.2, 0.2, 0.1))
			# 建設可能ハイライト（Civilizationスタイル、建設モード時のみ塗りつぶし）
			if fill_cells.has(pos):
				draw_colored_polygon(corners, Color(0.3, 0.6, 1.0, 0.20))
			# 資源タイル強調枠線（建設モード時のみ）
			if resource_highlight_type != ResourceType.NONE and rtype == resource_highlight_type:
				var res_color_map: Dictionary = {
					ResourceType.WOOD:   Color(1.0, 0.5, 0.0, 0.9),
					ResourceType.STONE:  Color(0.7, 0.7, 0.7, 0.9),
					ResourceType.SULFUR: Color(1.0, 0.9, 0.0, 0.9),
					ResourceType.WHEAT:  Color(0.2, 0.9, 0.2, 0.9),
					ResourceType.IRON:   Color(0.5, 0.4, 0.35, 0.9),
					ResourceType.COTTON: Color(0.9, 0.9, 0.85, 0.9),
				}
				var res_c: Color = res_color_map.get(resource_highlight_type, Color(1, 1, 1, 0.9))
				var res_closed: PackedVector2Array = corners.duplicate()
				res_closed.append(corners[0])
				draw_polyline(res_closed, res_c, 3.0)
			var closed := corners.duplicate()
			closed.append(corners[0])
			draw_polyline(closed, Color(1, 1, 1, 0.4), 1.0)
	# 領土境界線（重複ゾーンを除いた純粋な各領土のみ描画）
	var pure_player: Dictionary = {}
	for cell in highlight_cells:
		if not enemy_territory_cells.has(cell):
			pure_player[cell] = true
	var pure_enemy: Dictionary = {}
	for cell in enemy_territory_cells:
		if not highlight_cells.has(cell):
			pure_enemy[cell] = true
	_draw_territory_border(pure_player, Color(0.4, 0.8, 1.0))
	_draw_territory_border(pure_enemy, Color(1.0, 0.3, 0.3))
	# Phase 3: BASE長押しリング進捗（金色弧）
	if base_longpress_cell != Vector2i(-1, -1) and base_longpress_progress > 0.0:
		var ring_center := hex_to_pixel(base_longpress_cell.x, base_longpress_cell.y)
		var ring_radius := HEX_SIZE * 1.2
		var ring_color := Color("#E0C060")  # COLOR_GOLD
		var segments := 32
		var angle_end := base_longpress_progress * TAU
		var pts: PackedVector2Array = []
		for i in range(segments + 1):
			var frac := float(i) / float(segments)
			if frac * TAU > angle_end:
				break
			var a := -PI * 0.5 + frac * TAU  # 12時方向スタート
			pts.append(ring_center + Vector2(cos(a), sin(a)) * ring_radius)
		if pts.size() >= 2:
			draw_polyline(pts, ring_color, 4.0)


# 領土境界線を描画する（プレイヤー・敵共通汎用）
func _draw_territory_border(cells: Dictionary, color: Color) -> void:
	if cells.is_empty():
		return
	var edge_pairs := [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0]]
	# edge_pairs[i] に対応する隣接セル方向（corners angle_deg=60*i-30 基準）
	# i=0:[0,1]=RIGHT, i=1:[1,2]=下右, i=2:[2,3]=下左, i=3:[3,4]=LEFT, i=4:[4,5]=上左, i=5:[5,0]=上右
	var dirs_even := [
		Vector2i(1, 0),    # RIGHT
		Vector2i(0, 1),    # 下右（even）
		Vector2i(-1, 1),   # 下左（even）
		Vector2i(-1, 0),   # LEFT
		Vector2i(-1, -1),  # 上左（even）
		Vector2i(0, -1),   # 上右（even）
	]
	var dirs_odd := [
		Vector2i(1, 0),    # RIGHT
		Vector2i(1, 1),    # 下右（odd）
		Vector2i(0, 1),    # 下左（odd）
		Vector2i(-1, 0),   # LEFT
		Vector2i(0, -1),   # 上左（odd）
		Vector2i(1, -1),   # 上右（odd）
	]
	for pos in cells:
		var col: int = pos.x
		var row: int = pos.y
		var center := hex_to_pixel(col, row)
		var corners := _get_hex_corners(center)
		var dirs := dirs_even if row % 2 == 0 else dirs_odd
		for i in range(6):
			var nb_pos: Vector2i = pos + dirs[i]
			if not cells.has(nb_pos):
				var ep: Array = edge_pairs[i]
				var p0: Vector2 = corners[ep[0]]
				var p1: Vector2 = corners[ep[1]]
				draw_line(p0, p1, Color(color.r, color.g, color.b, 0.4), 6.0)
				draw_line(p0, p1, Color(color.r, color.g, color.b, 0.9), 2.0)
