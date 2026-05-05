class_name EconGrid
extends Node2D

const HEX_SIZE := 24.0
const COLS := 26
const ROWS := 13
const MAX_STACK: int = 3
const BASE_INITIAL_POS := Vector2i(1, 6)
const LAND_RESOURCE_TYPES := ["wood", "resin", "stone", "iron", "wheat", "cotton"]
const LAND_TERRAIN_TYPES := ["grassland", "forest", "rocky", "desert", "wetland", "wasteland"]

enum ResourceType { NONE, WOOD, STONE, RESIN, WHEAT, IRON, COTTON }
enum TileType { PLAIN, MOUNTAIN, DESERT }

var origin: Vector2 = Vector2.ZERO
var resource_cells: Dictionary = {}
var land_panels: Dictionary = {}
var base_panel_data: Dictionary = {}
var seed_value: int = 42
var tile_cells: Dictionary = {}
var mountain_ratio: int = 0
var desert_ratio: int = 25
var _land_rng := RandomNumberGenerator.new()


var highlight_cells: Dictionary = {}  # Vector2i -> true
var enemy_territory_cells: Dictionary = {}
var fill_cells: Dictionary = {}
var resource_highlight_type: int = 0
var land_highlight_cells: Dictionary = {}  # Vector2i -> true (土地参照型建物選択時のパネル強調)
var construction_sites: Dictionary = {}


var base_longpress_cell: Vector2i = Vector2i(-1, -1)
var base_longpress_progress: float = 0.0  # 0.0縲・.0

func _ready() -> void:
	_init_resource_cells()
	generate_initial_land_panels()

func _init_resource_cells() -> void:
	resource_cells.clear()
	tile_cells.clear()


	for row in range(ROWS):
		for col in range(get_col_count(row)):
			tile_cells[Vector2i(col, row)] = TileType.PLAIN


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

	for i in range(4):
		resource_cells[player_cells[i]] = ResourceType.WOOD
	for i in range(4, 8):
		resource_cells[player_cells[i]] = ResourceType.STONE
	for i in range(8, 12):
		resource_cells[player_cells[i]] = ResourceType.RESIN
	for i in range(12, 14):
		resource_cells[player_cells[i]] = ResourceType.WHEAT

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

	for i in range(4):
		resource_cells[enemy_cells[i]] = ResourceType.WOOD
	for i in range(4, 8):
		resource_cells[enemy_cells[i]] = ResourceType.STONE
	for i in range(8, 12):
		resource_cells[enemy_cells[i]] = ResourceType.RESIN
	for i in range(12, 14):
		resource_cells[enemy_cells[i]] = ResourceType.WHEAT

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


	generate_terrain(mountain_ratio, desert_ratio)

func calculate_distance_band(pos: Vector2i, base_pos: Vector2i = BASE_INITIAL_POS) -> String:
	var distance: int = absi(pos.x - base_pos.x) + absi(pos.y - base_pos.y)
	if distance <= 4:
		return "near"
	if distance <= 10:
		return "mid"
	return "far"

func generate_resource_value(distance_band: String) -> int:
	match distance_band:
		"near":
			return _land_rng.randi_range(1, 3)
		"mid":
			return _land_rng.randi_range(1, 4)
		"far":
			return _land_rng.randi_range(2, 5)
		_:
			return 1

func generate_single_resource_panel(pos: Vector2i, resource_key: String = "") -> Dictionary:
	var distance_band: String = calculate_distance_band(pos)
	var selected_resource: String = resource_key
	if selected_resource == "":
		selected_resource = LAND_RESOURCE_TYPES[_land_rng.randi_range(0, LAND_RESOURCE_TYPES.size() - 1)]
	return _build_land_panel(pos, {selected_resource: generate_resource_value(distance_band)}, "single", distance_band)

func generate_composite_resource_panel(pos: Vector2i) -> Dictionary:
	var distance_band: String = calculate_distance_band(pos)
	var first_idx: int = _land_rng.randi_range(0, LAND_RESOURCE_TYPES.size() - 1)
	var second_idx: int = _land_rng.randi_range(0, LAND_RESOURCE_TYPES.size() - 1)
	while second_idx == first_idx:
		second_idx = _land_rng.randi_range(0, LAND_RESOURCE_TYPES.size() - 1)
	var resources := {
		LAND_RESOURCE_TYPES[first_idx]: generate_resource_value(distance_band),
		LAND_RESOURCE_TYPES[second_idx]: generate_resource_value(distance_band),
	}
	return _build_land_panel(pos, resources, "composite", distance_band)

func apply_initial_guarantee(panels: Array) -> void:
	var guarantee_specs := [
		{"resource": "wood", "category": "single"},
		{"resource": "stone", "category": "single"},
		{"resource": "wheat", "category": "single"},
	]
	var used_positions: Dictionary = {}
	for spec in guarantee_specs:
		var target_index: int = _find_near_panel_index_for_guarantee(panels, used_positions)
		if target_index < 0:
			push_warning("[EconGrid] initial guarantee skipped: no near panel available")
			continue
		var pos: Vector2i = panels[target_index].get("pos", Vector2i(-1, -1))
		var panel: Dictionary = generate_single_resource_panel(pos, str(spec["resource"]))
		panel["resources"][str(spec["resource"])] = maxi(2, int(panel["resources"].get(str(spec["resource"]), 0)))
		panels[target_index] = panel
		land_panels[pos] = panel
		used_positions[pos] = true

func generate_initial_land_panels() -> Array:
	land_panels.clear()
	_land_rng.seed = seed_value + 100
	var panels: Array = []
	base_panel_data = {
		"pos": BASE_INITIAL_POS,
		"resources": {},
		"special_tag": "none",
		"terrain_type": "grassland",
		"category": "base",
		"distance_band": "near",
	}
	for row in range(ROWS):
		for col in range(COLS):
			var pos := Vector2i(col, row)
			if is_mountain(pos):
				continue
			var panel: Dictionary
			panel = generate_single_resource_panel(pos)
			panels.append(panel)
			land_panels[pos] = panel
			_log_land_panel_gen(pos, panel)
	apply_initial_guarantee(panels)

	apply_initial_reveal(panels, BASE_INITIAL_POS)
	print("[EconGrid] land panels generated: panels=%d" % panels.size())
	return panels

func _build_land_panel(pos: Vector2i, resources: Dictionary, category: String, distance_band: String) -> Dictionary:
	return {
		"pos": pos,
		"resources": resources,
		"special_tag": _generate_special_tag(),
		"terrain_type": _generate_land_terrain_type(),
		"category": category,
		"distance_band": distance_band,
		"revealed": false,
	}

func _generate_special_tag() -> String:
	return "spice" if _land_rng.randf() < 0.04 else "none"

func _generate_land_terrain_type() -> String:
	return LAND_TERRAIN_TYPES[_land_rng.randi_range(0, LAND_TERRAIN_TYPES.size() - 1)]

func _find_near_panel_index_for_guarantee(panels: Array, used_positions: Dictionary) -> int:
	for i in range(panels.size()):
		var panel: Dictionary = panels[i]
		var pos: Vector2i = panel.get("pos", Vector2i(-1, -1))
		if used_positions.has(pos):
			continue
		if panel.get("distance_band", "") == "near":
			return i
	return -1



func apply_initial_reveal(panels: Array, base_pos: Vector2i) -> void:
	var reveal_count: int = 0
	for panel in panels:
		var pos: Vector2i = panel.get("pos", Vector2i(-1, -1))
		var dist: int = hex_distance(pos, base_pos)
		if dist <= 3:
			panel["revealed"] = true
			land_panels[pos]["revealed"] = true
			reveal_count += 1
	print("[EconGrid] apply_initial_reveal: revealed=%d panels (dist<=3 from %s)" % [reveal_count, str(base_pos)])
	var composite_count: int = 0
	var unrevealed_composite_count: int = 0
	for pos in land_panels.keys():
		var p: Dictionary = land_panels[pos]
		if p.get("category", "") == "composite":
			composite_count += 1
			if not p.get("revealed", false):
				unrevealed_composite_count += 1
	print("[EconGrid] apply_initial_reveal: composite panels total=%d, unrevealed=%d" % [composite_count, unrevealed_composite_count])



func reveal_panels_around(building_pos: Vector2i, radius: int = 3) -> void:
	var reveal_count: int = 0
	for pos in land_panels.keys():
		var panel: Dictionary = land_panels[pos]
		if panel.get("revealed", false):
			continue
		var dist: int = hex_distance(pos, building_pos)
		if dist <= radius:
			land_panels[pos]["revealed"] = true
			reveal_count += 1
	if reveal_count > 0:
		print("[EconGrid] reveal_panels_around: revealed=%d new panels (dist<=%d from %s)" % [reveal_count, radius, str(building_pos)])




func can_place_building(target_pos: Vector2i, own_building_positions: Array) -> bool:
	var panel: Dictionary = get_panel_at(target_pos)
	if not panel.get("revealed", false):
		print("[EconGrid] can_place_building: unrevealed panel pos=%s" % str(target_pos))
		return false
	if not is_adjacent_to_own_building(target_pos, own_building_positions):
		print("[EconGrid] can_place_building: not adjacent to own building pos=%s" % str(target_pos))
		return false
	if construction_sites.has(target_pos):
		return false
	return true

func get_buildable_cells_for_card(_card: Dictionary, own_building_positions: Array, occupied_positions: Array = []) -> Array:
	var result: Array = []
	var occupied: Dictionary = {}
	for pos in occupied_positions:
		occupied[pos] = true
	for row in range(ROWS):
		for col in range(get_col_count(row)):
			var pos := Vector2i(col, row)
			if not can_place_construction_site(pos, own_building_positions, occupied):
				continue
			result.append(pos)
	return result

func can_place_construction_site(target_pos: Vector2i, own_building_positions: Array, occupied_positions: Dictionary = {}) -> bool:
	if not is_within_bounds(target_pos):
		return false
	if target_pos == BASE_INITIAL_POS:
		return false
	if not land_panels.has(target_pos):
		return false
	var panel: Dictionary = land_panels.get(target_pos, {})
	if not bool(panel.get("revealed", false)):
		return false
	if occupied_positions.has(target_pos):
		return false
	if construction_sites.has(target_pos):
		return false
	if not is_adjacent_to_own_building(target_pos, own_building_positions):
		return false
	return true

func start_construction(panel_id: Vector2i, building_type: int, card: Dictionary, started_at: int) -> bool:
	if construction_sites.has(panel_id):
		return false
	construction_sites[panel_id] = {
		"panel_id": panel_id,
		"building_type": building_type,
		"card": card.duplicate(true),
		"card_id": str(card.get("id", "")),
		"is_special": str(card.get("category", card.get("type", ""))) == "special",
		"construction_time": 3.0 if str(card.get("category", card.get("type", ""))) == "special" else 1.0,
		"construction_progress": 0.0,
		"required_work_labor": 1,
		"is_under_construction": true,
		"is_active": false,
		"started_at": started_at,
	}
	queue_redraw()
	return true


func spawn_building(site: Dictionary) -> EconBuilding:
	var panel_id: Vector2i = site.get("panel_id", Vector2i(-1, -1))
	var building := EconBuilding.new()
	building.setup(int(site.get("building_type", EconBuilding.BuildingType.HOUSE)), panel_id, true)
	building.is_built = true
	# 完成直前の build_progress で微フェード表現（不要ならコメント化）
	building.build_progress = 0.99
	building.position = hex_to_pixel(panel_id.x, panel_id.y)
	return building


func is_adjacent_to_own_building(target_pos: Vector2i, own_building_positions: Array) -> bool:
	for own_pos in own_building_positions:
		var neighbors: Array = get_neighbors(own_pos.x, own_pos.y)
		if target_pos in neighbors:
			return true
	return false

func get_resource_type(pos: Vector2i) -> ResourceType:
	return resource_cells.get(pos, ResourceType.NONE)

func get_panel_at(pos: Vector2i) -> Dictionary:
	return land_panels.get(pos, {})

func get_panel_wheat_value(pos: Vector2i) -> int:
	var panel: Dictionary = get_panel_at(pos)
	var resources: Dictionary = panel.get("resources", {})
	return int(resources.get("wheat", 0))

func has_spice_tag(pos: Vector2i) -> bool:
	var panel: Dictionary = get_panel_at(pos)
	var tag: String = str(panel.get("special_tag", "none"))
	return tag == "spice"

func is_within_bounds(pos: Vector2i) -> bool:
	return is_valid_cell(pos.x, pos.y)


func get_adjacent_empty_cells(pos: Vector2i) -> Array:
	var adjacent: Array = []
	var directions := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for dir in directions:
		var check_pos: Vector2i = pos + dir
		if is_within_bounds(check_pos) and not land_panels.has(check_pos):
			adjacent.append(check_pos)
	return adjacent

func get_adjacent_empty_land_cells_for_player(own_building_positions: Array, occupied_positions: Array = []) -> Array:
	var result: Array = []
	var occupied: Dictionary = {}
	for pos in occupied_positions:
		occupied[pos] = true
	for pos in land_panels.keys():
		if not _is_empty_land_card_target(pos, occupied):
			continue
		if is_adjacent_to_own_building(pos, own_building_positions):
			result.append(pos)
	return result

func get_land_card_placement_options(own_building_positions: Array, occupied_positions: Array = []) -> Array:
	var options: Array = []
	var occupied: Dictionary = {}
	for pos in occupied_positions:
		occupied[pos] = true
	var positions: Array = land_panels.keys()
	positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = absi(a.x - BASE_INITIAL_POS.x) + absi(a.y - BASE_INITIAL_POS.y)
		var db: int = absi(b.x - BASE_INITIAL_POS.x) + absi(b.y - BASE_INITIAL_POS.y)
		if da == db:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
		return da < db
	)
	for pos in positions:
		var base_dist: int = absi(pos.x - BASE_INITIAL_POS.x) + absi(pos.y - BASE_INITIAL_POS.y)
		if base_dist < 1 or base_dist > 3:
			continue
		if not _is_empty_land_card_target(pos, occupied):
			continue
		var panel: Dictionary = land_panels.get(pos, {})
		if not bool(panel.get("revealed", false)):
			continue
		if not is_adjacent_to_own_building(pos, own_building_positions):
			continue
		options.append(pos)
		if options.size() >= 3:
			break
	return options

func _is_empty_land_card_target(pos: Vector2i, occupied_positions: Dictionary) -> bool:
	if not is_within_bounds(pos):
		return false
	if pos == BASE_INITIAL_POS:
		return false
	if not land_panels.has(pos):
		return false
	if occupied_positions.has(pos):
		return false
	var panel: Dictionary = land_panels.get(pos, {})
	return not bool(panel.get("land_card_placed", false))

func place_land_card(card: Dictionary, target_pos: Vector2i, own_building_positions: Array = [], occupied_positions: Array = []) -> bool:
	if not is_within_bounds(target_pos):
		return false
	if target_pos == BASE_INITIAL_POS:
		return false
	if not land_panels.has(target_pos):
		return false
	var occupied: Dictionary = {}
	for pos in occupied_positions:
		occupied[pos] = true
	if not _is_empty_land_card_target(target_pos, occupied):
		print("[EconGrid] place_land_card rejected: target is not empty %s" % str(target_pos))
		return false
	if not own_building_positions.is_empty() and not is_adjacent_to_own_building(target_pos, own_building_positions):
		print("[EconGrid] place_land_card rejected: not adjacent to own building %s" % str(target_pos))
		return false

	var panel_data: Dictionary = card.get("panel_data", {})
	var existing: Dictionary = land_panels[target_pos].duplicate(true)
	var resources: Dictionary = panel_data.get("resources", {})
	var terrain_type: String = str(panel_data.get("terrain_type", panel_data.get("terrain", existing.get("terrain_type", "grassland"))))
	existing["land_card_placed"] = true
	existing["land_card"] = panel_data.duplicate(true)
	existing["land_card_subtype"] = str(card.get("land_subtype", ""))
	existing["land_card_resources"] = resources.duplicate(true)
	existing["land_card_special_tag"] = str(panel_data.get("special_tag", "none"))
	existing["land_card_terrain_type"] = terrain_type
	land_panels[target_pos] = existing
	print("[EconGrid] land card placed without panel overwrite %s -> resources=%s, special_tag=%s, terrain_type=%s" % [
		str(target_pos),
		str(resources),
		str(panel_data.get("special_tag", "none")),
		terrain_type,
	])
	_log_event({
		"type": "LAND_CARD_PLACED",
		"land_subtype": str(card.get("land_subtype", "")),
		"pos": [target_pos.x, target_pos.y],
		"resources": resources.duplicate(true),
		"special_tag": str(panel_data.get("special_tag", "none")),
		"terrain_type": terrain_type,
	})
	queue_redraw()
	return true
func _normalize_land_card_panel_data(panel_data: Dictionary, target_pos: Vector2i) -> Dictionary:
	var resources: Dictionary = panel_data.get("resources", {})
	var terrain_type: String = str(panel_data.get("terrain_type", panel_data.get("terrain", "grassland")))
	return {
		"pos": target_pos,
		"resources": resources.duplicate(true),
		"special_tag": str(panel_data.get("special_tag", "none")),
		"terrain_type": terrain_type,
		"category": "composite" if resources.size() > 1 else "single",
		"distance_band": calculate_distance_band(target_pos),
	}

func _log_land_panel_gen(pos: Vector2i, panel: Dictionary) -> void:
	var distance: int = absi(pos.x - BASE_INITIAL_POS.x) + absi(pos.y - BASE_INITIAL_POS.y)
	_log_event({
		"type": "LAND_PANEL_GEN",
		"pos": [pos.x, pos.y],
		"distance": distance,
		"distance_band": str(panel.get("distance_band", "unknown")),
		"category": str(panel.get("category", "unknown")),
		"resources": panel.get("resources", {}),
		"special_tag": str(panel.get("special_tag", "none")),
		"terrain_type": str(panel.get("terrain_type", "grassland")),
	})

func _log_event(data: Dictionary) -> void:
	var log_manager: Object = get_node_or_null("/root/LogManager")
	if log_manager == null:
		var scene := get_tree().current_scene
		if scene != null:
			log_manager = scene.get("_log_manager")
	if log_manager != null and log_manager.has_method("log_event"):
		log_manager.log_event(data)

func generate_terrain(p_mountain_ratio: int, p_desert_ratio: int) -> void:
	mountain_ratio = p_mountain_ratio
	desert_ratio = p_desert_ratio


	for row in range(ROWS):
		for col in range(get_col_count(row)):
			tile_cells[Vector2i(col, row)] = TileType.PLAIN


	var center_cells: Array = []
	for col in range(8, 18):
		for row in range(ROWS):
			center_cells.append(Vector2i(col, row))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 2

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


	_ensure_passable_path()
	queue_redraw()

func _ensure_passable_path() -> void:
	while true:

		var mid_row := ROWS / 2
		if _bfs_can_reach_col(Vector2i(7, mid_row), 18):
			return

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
			return

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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_pos: Vector2i = _pixel_to_grid_pos(get_local_mouse_position())
		if not land_panels.has(clicked_pos):
			return
		var panel: Dictionary = land_panels[clicked_pos]
		print("[LandPanelDetail] pos=%s" % str(clicked_pos))
		print("  distance=%d" % _calculate_manhattan_distance(clicked_pos))
		print("  band=%s" % panel.get("distance_band", "unknown"))
		print("  category=%s" % panel.get("category", "unknown"))
		print("  resources=%s" % str(panel.get("resources", {})))
		print("  special_tag=%s" % panel.get("special_tag", "none"))
		print("  terrain=%s" % panel.get("terrain_type", "grassland"))

func _pixel_to_grid_pos(mouse_pos: Vector2) -> Vector2i:
	var best_pos := Vector2i(-1, -1)
	var best_dist := INF
	for row in range(ROWS):
		for col in range(get_col_count(row)):
			var pos := Vector2i(col, row)
			var dist: float = mouse_pos.distance_squared_to(hex_to_pixel(col, row))
			if dist < best_dist:
				best_dist = dist
				best_pos = pos
	return best_pos

func _calculate_manhattan_distance(pos: Vector2i) -> int:
	return absi(pos.x - BASE_INITIAL_POS.x) + absi(pos.y - BASE_INITIAL_POS.y)

func _draw_resource_icons(center: Vector2, resource_types: Array, resource_values: Dictionary) -> void:
	if resource_types.size() == 1:
		var res_type: String = str(resource_types[0])
		var res_value: int = int(resource_values.get(res_type, 0))
		_draw_value_text(center + Vector2(0.0, 4.0), str(res_value), 11)
		return
	for i in range(resource_types.size()):
		var res_type: String = str(resource_types[i])
		var res_value: int = int(resource_values.get(res_type, 0))
		var offset_x: float = -7.0 + (float(i) * 14.0)
		_draw_value_text(center + Vector2(offset_x, 7.0), str(res_value), 8)

func _draw_value_text(pos: Vector2, text: String, font_size: int) -> void:
	draw_string(ThemeDB.fallback_font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.05, 0.05, 0.05, 0.8))
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func _get_primary_resource_type(resources: Dictionary) -> String:
	var best_type: String = ""
	var best_value: int = -1
	for key in resources.keys():
		var value: int = int(resources.get(key, 0))
		if value > best_value:
			best_type = str(key)
			best_value = value
	return best_type

func _get_max_resource_value(resources: Dictionary) -> int:
	var max_value: int = 0
	for key in resources.keys():
		max_value = maxi(max_value, int(resources.get(key, 0)))
	return max_value

func _get_land_panel_color(panel: Dictionary) -> Color:
	var resources: Dictionary = panel.get("resources", {})
	var primary_resource: String = _get_primary_resource_type(resources)
	if primary_resource != "":
		return _get_resource_color(primary_resource).darkened(0.06)
	return _get_terrain_color(str(panel.get("terrain_type", "grassland")))

func _draw_land_panel_fill(center: Vector2, corners: PackedVector2Array, panel: Dictionary) -> void:
	var resources: Dictionary = panel.get("resources", {})
	var resource_types: Array = resources.keys()
	if resource_types.size() <= 1:
		draw_colored_polygon(corners, _get_land_panel_color(panel))
		return
	resource_types.sort_custom(func(a, b):
		return int(resources.get(a, 0)) > int(resources.get(b, 0))
	)
	var primary_color: Color = _get_resource_color(str(resource_types[0])).darkened(0.06)
	var secondary_color: Color = _get_resource_color(str(resource_types[1])).darkened(0.06)
	var left_poly := PackedVector2Array([corners[2], corners[3], corners[4], corners[5], center])
	var right_poly := PackedVector2Array([corners[5], corners[0], corners[1], corners[2], center])
	draw_colored_polygon(left_poly, primary_color)
	draw_colored_polygon(right_poly, secondary_color)

func _get_terrain_color(terrain_type: String) -> Color:
	match terrain_type:
		"forest":
			return Color8(65, 86, 66)
		"rocky":
			return Color8(93, 89, 82)
		"desert":
			return Color8(154, 139, 94)
		"wetland":
			return Color8(63, 92, 86)
		"wasteland":
			return Color8(82, 76, 78)
		_:
			return Color8(86, 104, 82)

func _get_inset_corners(center: Vector2, corners: PackedVector2Array, inset_ratio: float) -> PackedVector2Array:
	var inset := PackedVector2Array()
	for corner in corners:
		inset.append(center.lerp(corner, inset_ratio))
	return inset

func _draw_land_value_edge(center: Vector2, corners: PackedVector2Array, panel: Dictionary) -> void:
	if not _should_draw_land_type_edge(panel):
		return
	var closed := _get_inset_corners(center, corners, 0.82)
	closed.append(closed[0])
	var edge_color: Color = _get_land_type_edge_color(panel)
	draw_polyline(closed, edge_color, 2.0)

func _should_draw_land_type_edge(panel: Dictionary) -> bool:
	if str(panel.get("special_tag", "none")) != "none":
		return true
	return false

func _get_land_type_edge_color(panel: Dictionary) -> Color:
	if str(panel.get("special_tag", "none")) != "none":
		return Color(1.0, 0.83, 0.18, 0.95)
	return Color(0.93, 0.93, 0.86, 0.72)

func _get_resource_color(resource_type: String) -> Color:
	match str(resource_type):
		"wood":
			return Color8(63, 82, 50)
		"resin":
			return Color8(154, 138, 60)
		"stone":
			return Color8(93, 86, 78)
		"iron":
			return Color8(80, 65, 55)
		"wheat":
			return Color8(169, 146, 80)
		"cotton":
			return Color8(240, 235, 220)
		_:
			return Color.WHITE

func _draw_spice_tag_mark(center: Vector2) -> void:
	var mark_pos: Vector2 = center + Vector2(0.0, -HEX_SIZE * 0.7)
	draw_circle(mark_pos, 4.0, Color("#FFD700"))
	draw_arc(mark_pos, 4.0, 0.0, TAU, 16, Color.WHITE, 1.0)

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
				ResourceType.RESIN:
					draw_colored_polygon(corners, Color8(154, 138, 60))
				ResourceType.WHEAT:
					draw_colored_polygon(corners, Color8(169, 146, 80))
				ResourceType.IRON:
					draw_colored_polygon(corners, Color8(80, 65, 55))
				ResourceType.COTTON:
					draw_colored_polygon(corners, Color8(240, 235, 220))

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
			if land_panels.has(pos):
				var panel: Dictionary = land_panels[pos]
				_draw_land_panel_fill(center, corners, panel)
				var resources: Dictionary = panel.get("resources", {})
				if resources.is_empty():
					resources = panel.get("land_card_resources", {})
				var special_tag: String = str(panel.get("special_tag", "none"))
				var resource_list: Array = resources.keys()
				if highlight_cells.has(pos) and resource_list.size() > 0:
					_draw_resource_icons(center, resource_list, resources)
				if highlight_cells.has(pos) and special_tag == "spice":
					_draw_spice_tag_mark(center)

			if fill_cells.has(pos):
				draw_colored_polygon(corners, Color(0.3, 0.6, 1.0, 0.20))

			if land_highlight_cells.has(pos):
				draw_colored_polygon(corners, Color(1.0, 0.8, 0.0, 0.18))
				var lhc := corners.duplicate()
				lhc.append(corners[0])
				draw_polyline(lhc, Color(1.0, 0.70, 0.0, 0.85), 2.5)

			if resource_highlight_type != ResourceType.NONE and rtype == resource_highlight_type:
				var res_color_map: Dictionary = {
					ResourceType.WOOD:   Color(1.0, 0.5, 0.0, 0.9),
					ResourceType.STONE:  Color(0.7, 0.7, 0.7, 0.9),
					ResourceType.RESIN: Color(1.0, 0.9, 0.0, 0.9),
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
			if land_panels.has(pos):
				_draw_land_value_edge(center, corners, land_panels[pos])
			if construction_sites.has(pos):
				var site: Dictionary = construction_sites[pos]
				draw_colored_polygon(corners, Color(0.09, 0.08, 0.07, 0.40))
				var ring_color := Color(0.70, 0.58, 0.28, 0.95) if bool(site.get("is_active", false)) else Color(0.54, 0.50, 0.44, 0.95)
				var ring_progress: float = clampf(float(site.get("construction_progress", 0.0)), 0.0, 1.0)
				# バックグラウンドring: 建設中サイトは進捗0でも全円表示（EXCHANGE等progress=0でも視認可能に）
				draw_arc(center + Vector2(0.0, -12.0), 14.0, -PI * 0.5, -PI * 0.5 + TAU, 24, Color(0.30, 0.28, 0.25, 0.50), 3.0)
				draw_arc(center + Vector2(0.0, -12.0), 14.0, -PI * 0.5, -PI * 0.5 + TAU * ring_progress, 24, ring_color, 3.0)
				# 建設順番号バッジ（左上）
				var queue_list: Array = _get_construction_queue_sorted()
				var queue_index := 0
				for qi in range(queue_list.size()):
					if queue_list[qi].get("panel_id", Vector2i(-1,-1)) == pos:
						queue_index = qi + 1
						break
				if queue_index > 0:
					var badge_pos := center + Vector2(-14.0, -26.0)
					var badge_label: String = str(queue_index) if queue_index <= 5 else "..."
					draw_circle(badge_pos, 9.0, Color(0.15, 0.14, 0.13, 0.8))
					draw_string(ThemeDB.fallback_font, badge_pos + Vector2(-4.5, 4.0), badge_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.86, 0.76, 0.50))

	# 建設予定地ゴースト表示
	for pos in construction_sites:
		var center: Vector2 = hex_to_pixel(pos.x, pos.y)
		draw_rect(Rect2(center + Vector2(-14, -14), Vector2(28, 28)), Color(0.7, 0.7, 0.7, 0.35))

	var pure_player: Dictionary = {}
	for cell in highlight_cells:
		if not enemy_territory_cells.has(cell):
			pure_player[cell] = true
	var pure_enemy: Dictionary = {}
	for cell in enemy_territory_cells:
		if not highlight_cells.has(cell):
			pure_enemy[cell] = true
	_draw_territory_border(pure_player, Color(0.247, 0.412, 0.196))  # COLOR_WOOD相当
	_draw_territory_border(pure_enemy, Color(1.0, 0.3, 0.3))

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
			var a := -PI * 0.5 + frac * TAU
			pts.append(ring_center + Vector2(cos(a), sin(a)) * ring_radius)
		if pts.size() >= 2:
			draw_polyline(pts, ring_color, 4.0)



func _draw_territory_border(cells: Dictionary, color: Color) -> void:
	if cells.is_empty():
		return
	var edge_pairs := [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0]]


	var dirs_even := [
		Vector2i(1, 0),    # RIGHT
		Vector2i(0, 1),
		Vector2i(-1, 1),
		Vector2i(-1, 0),   # LEFT
		Vector2i(-1, -1),
		Vector2i(0, -1),
	]
	var dirs_odd := [
		Vector2i(1, 0),    # RIGHT
		Vector2i(1, 1),
		Vector2i(0, 1),
		Vector2i(-1, 0),   # LEFT
		Vector2i(0, -1),
		Vector2i(1, -1),
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

func _get_construction_queue_sorted() -> Array:
	var sites: Array = []
	for pos in construction_sites:
		sites.append(construction_sites[pos])
	sites.sort_custom(func(a, b): return a["started_at"] < b["started_at"])
	return sites
