class_name EconRallyFlag
extends Node2D

var flag_id: int = 0
var grid_pos: Vector2i = Vector2i(-1, -1)
var connected_buildings: Array = []   # Vector2i の配列
var is_connected: bool = false          # true=集結旗 / false=経由旗(将来用)
var is_assault_mode: bool = false

# 描画に使う参照（EconMainからセット）
var grid_ref = null        # EconGrid
var buildings_ref: Array = []  # EconBuilding の配列（接続線描画用）

func setup(fid: int, pos: Vector2i) -> void:
	flag_id = fid
	grid_pos = pos

func add_building(bpos: Vector2i) -> void:
	if not connected_buildings.has(bpos):
		connected_buildings.append(bpos)
		is_connected = true

func remove_building(bpos: Vector2i) -> void:
	connected_buildings.erase(bpos)
	if connected_buildings.is_empty():
		is_connected = false

func has_connected_buildings() -> bool:
	return connected_buildings.size() > 0

func _draw() -> void:
	# 旗の色（接続あり=黄色・接続なし=青）
	var flag_color: Color = Color("#FFD700") if has_connected_buildings() else Color("#7EC8E3")
	if is_assault_mode:
		flag_color = Color.RED
	# 旗ポール（縦線）
	draw_line(Vector2(0, 4), Vector2(0, -16), Color.WHITE, 2.0)
	# 旗布（三角形）
	var pts: PackedVector2Array
	if is_assault_mode:
		# 突撃モード: 旗を横に傾けた三角形
		pts = PackedVector2Array([Vector2(0, -8), Vector2(14, -2), Vector2(0, 4)])
	else:
		pts = PackedVector2Array([Vector2(0, -16), Vector2(12, -10), Vector2(0, -4)])
	draw_colored_polygon(pts, flag_color)
	# 接続線（建物グリッド中心 → 旗グリッド中心）
	if grid_ref != null and connected_buildings.size() > 0:
		_draw_connection_lines()
	# 接続数バッジ
	if connected_buildings.size() > 0:
		_draw_badge()

func _draw_connection_lines() -> void:
	# 建物種別ごとの色
	var type_colors: Dictionary = {
		0: Color("#FF8C00"),   # BARRACKS
		1: Color("#4169E1"),   # FORTRESS
		2: Color("#9932CC"),   # WORKSHOP
		3: Color("#888888"),   # VILLAGE
		4: Color("#888888"),   # BASE
		5: Color("#888888"),   # SAWMILL
		6: Color("#888888"),   # MINE
	}
	var my_px: Vector2 = grid_ref.hex_to_pixel(grid_pos.x, grid_pos.y)
	for bpos in connected_buildings:
		# buildings_ref から建物種別を取得
		var btype: int = 0
		for b in buildings_ref:
			if b.grid_pos == bpos and b.is_alive:
				btype = int(b.building_type)
				break
		var b_px: Vector2 = grid_ref.hex_to_pixel(bpos.x, bpos.y)
		# 旗の position（ピクセル）が my_px のため、ローカル座標に変換
		var from_local: Vector2 = b_px - my_px
		var to_local: Vector2 = Vector2.ZERO
		var line_color: Color = type_colors.get(btype, Color("#888888"))
		draw_dashed_line(from_local, to_local, line_color, 2.0, 8.0)

func _draw_badge() -> void:
	var count: int = connected_buildings.size()
	# バッジ背景（円）
	var badge_pos: Vector2 = Vector2(10, -22)
	draw_circle(badge_pos, 7.0, Color(0.1, 0.1, 0.1, 0.85))
	draw_arc(badge_pos, 7.0, 0, TAU, 16, Color.WHITE, 1.0)
	# バッジ文字
	draw_string(ThemeDB.fallback_font, badge_pos + Vector2(-4, 4), str(count),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
