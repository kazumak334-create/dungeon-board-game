class_name LandCardPlacementController
extends Node

signal land_card_placed(card: Dictionary, pos: Vector2i)
signal placement_failed(card: Dictionary)

var active: bool = false
var card: Dictionary = {}
var grid: EconGrid = null
var battle: EconBattle = null
var valid_cells: Array = []

func begin(card_data: Dictionary, grid_ref: EconGrid, battle_ref: EconBattle) -> bool:
	card = card_data.duplicate(true)
	grid = grid_ref
	battle = battle_ref
	valid_cells = get_valid_cells()
	if valid_cells.is_empty():
		placement_failed.emit(card)
		return false
	active = true
	if grid != null:
		grid.fill_cells = _cells_to_dict(valid_cells)
		grid.queue_redraw()
	return true

func handle_cell_click(cell: Vector2i) -> bool:
	if not active:
		return false
	if not valid_cells.has(cell):
		return true
	var own_positions := _get_own_positions(false)
	var occupied_positions := _get_own_positions(true)
	var land_card := _to_grid_land_card(card)
	if grid.place_land_card(land_card, cell, own_positions, occupied_positions):
		active = false
		grid.fill_cells = {}
		grid.queue_redraw()
		land_card_placed.emit(card, cell)
	return true

func get_valid_cells() -> Array:
	if grid == null or battle == null:
		return []
	return grid.get_adjacent_empty_land_cells_for_player(_get_own_positions(false), _get_own_positions(true))

func can_place_current_card() -> bool:
	return not get_valid_cells().is_empty()

func _get_own_positions(include_unbuilt: bool) -> Array:
	var positions: Array = []
	if battle == null:
		return positions
	for b in battle.player_buildings:
		if not b.is_alive:
			continue
		if not include_unbuilt and not b.is_built:
			continue
		positions.append(b.grid_pos)
	return positions

func _to_grid_land_card(source: Dictionary) -> Dictionary:
	if source.has("panel_data"):
		return source
	var resource_key := str(source.get("resource", "wood"))
	var value := int(source.get("value", 1))
	return {
		"card_type": "land",
		"land_subtype": "reward",
		"panel_data": {
			"resources": {resource_key: value},
			"terrain": "grassland",
			"special_tag": "none",
		},
	}

func _cells_to_dict(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell in cells:
		result[cell] = true
	return result
