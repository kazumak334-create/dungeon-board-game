class_name EconBattle
extends Node

const EconChestScript := preload("res://scripts/econ_mvp/EconChest.gd")

signal battle_ended(player_won: bool)
signal log_message(text: String)
signal chest_acquired(result: Dictionary)

var player_units: Array = []
var enemy_units: Array = []
var player_harvesters: Array = []
var enemy_harvesters: Array = []
var player_buildings: Array = []
var enemy_buildings: Array = []

var grid: EconGrid
var economy: EconEconomy
var _construction_queue: Array = []
var ai: EconAI = null

var is_running: bool = false
var player_flags: Array = []   # EconRallyFlag 縺ｮ驟榊・
var _game_over: bool = false
var _enemy_base_breakthrough_ids: Dictionary = {}

# 隕∽ｻｶ螳夂ｾｩ譖ｸ req_econ_draw_hand_circulation.md ﾂｧ8.2
var deck_manager = null
var reward_manager = null
var chests: Array = []

func setup(g: EconGrid, eco: EconEconomy) -> void:
	grid = g
	economy = eco

func set_reward_manager(manager) -> void:
	reward_manager = manager

func start() -> void:
	is_running = true
	_game_over = false
	_enemy_base_breakthrough_ids.clear()
	_spawn_chests()
	log_message.emit("Battle started!")

func setup_deck(initial_deck: Array, on_draw: Callable) -> void:
	# ﾂｧ8.2 EconBattle 縺ｸ縺ｮ霑ｽ蜉
	var dm_script = load("res://scripts/econ_mvp/EconDeckManager.gd")
	deck_manager = dm_script.new()
	add_child(deck_manager)
	deck_manager.setup(initial_deck, self, on_draw)
	print("[EconBattle] setup_deck: deck_manager initialized")

func play_card_and_build(card_idx: int, target_cell: Vector2i) -> bool:
	if deck_manager == null:
		return false
	if deck_manager.force_charge_triggered:
		return false
	if card_idx < 0 or card_idx >= deck_manager.hand.size():
		return false
	var card: Dictionary = deck_manager.hand[card_idx]
	if not _check_placement_valid(card, target_cell):
		return false
	var btype: int = _get_building_type_from_card(card)
	if btype < 0:
		return false
	if economy != null:
		economy.consume_resources(card)
	var used_card: Dictionary = deck_manager.remove_card_at(card_idx)
	if used_card.is_empty():
		return false
	if grid == null or not grid.start_construction(target_cell, btype, used_card, Time.get_ticks_msec()):
		return false
	_log_event({
		"type": "BUILDING_PLACED",
		"panel_id": [target_cell.x, target_cell.y],
		"building_type": btype,
		"card_id": str(used_card.get("id", "")),
	})
	log_message.emit("Card played: %s at (%d,%d)" % [card.get("name", "?"), target_cell.x, target_cell.y])
	return true

func _check_placement_valid(card: Dictionary, target_cell: Vector2i) -> bool:
	# ﾂｧ4.4.2 驟咲ｽｮ譎・譚｡莉ｶ繝√ぉ繝・け
	# 譚｡莉ｶ1: 雉・ｺ仙・雜ｳ
	if economy != null and not economy.can_afford_card(card):
		log_message.emit("Resource insufficient for %s" % card.get("name", "?"))
		return false
	# 譚｡莉ｶ2: 莠ｺ蜿｣蜈・ｶｳ
	if economy != null:
		var pop_req: int = card.get("population_required", 0)
		if economy.population_used + pop_req > economy.population_cap:
			log_message.emit("Population cap exceeded")
			return false
	# 譚｡莉ｶ3: 驟咲ｽｮ蜈域怏蜉ｹ繝√ぉ繝・け・医げ繝ｪ繝・ラ蜀・°縺､蜊譛峨↑縺暦ｼ・
	if grid != null and not grid.is_valid_cell(target_cell.x, target_cell.y):
		return false
	for b in player_buildings:
		if b.grid_pos == target_cell and b.is_alive:
			log_message.emit("Cell occupied at (%d,%d)" % [target_cell.x, target_cell.y])
			return false
	var occupied: Dictionary = {}
	for b in player_buildings:
		if b.is_alive:
			occupied[b.grid_pos] = true
	for h in player_harvesters:
		if h.is_alive:
			occupied[h.grid_pos] = true
	var own_positions: Array = []
	for b in player_buildings:
		if b.is_alive and b.is_built:
			own_positions.append(b.grid_pos)
	if grid != null and not grid.can_place_construction_site(target_cell, own_positions, occupied):
		log_message.emit("Cannot place construction site at (%d,%d)" % [target_cell.x, target_cell.y])
		return false
	# 譚｡莉ｶ4: 蠑ｷ蛻ｶ遯∵茶蜑搾ｼ亥他蜃ｺ蜈・〒繝√ぉ繝・け貂医∩・・
	return true

func _get_building_type_from_card(card: Dictionary) -> int:
	var building := _create_building_from_card(card, Vector2i(0, 0))
	if building == null:
		return -1
	var btype: int = int(building.building_type)
	building.queue_free()
	return btype

func _create_building_from_card(card: Dictionary, target_cell: Vector2i) -> EconBuilding:
	# 繧ｫ繝ｼ繝峨°繧牙ｻｺ迚ｩ繧堤函謌舌☆繧・
	var btype_str: String = card.get("building_type", "")
	var btype_map: Dictionary = {
		"BARRACKS": EconBuilding.BuildingType.BARRACKS,
		"FORTRESS": EconBuilding.BuildingType.FORTRESS,
		"WORKSHOP": EconBuilding.BuildingType.WORKSHOP,
		"VILLAGE": EconBuilding.BuildingType.VILLAGE,
		"SAWMILL": EconBuilding.BuildingType.SAWMILL,
		"MINE": EconBuilding.BuildingType.MINE,
		"EQUIPMENT_SHOP": EconBuilding.BuildingType.EQUIPMENT_SHOP,
		"TRADE_POST": EconBuilding.BuildingType.TRADE_POST,
		"LIBRARY": EconBuilding.BuildingType.TRADE_POST,  # v0.1 莉ｮ繝槭ャ繝斐Φ繧ｰ
		"MARKET": EconBuilding.BuildingType.TRADE_POST,   # v0.1 莉ｮ繝槭ャ繝斐Φ繧ｰ
		"HOUSE": EconBuilding.BuildingType.HOUSE,
		"PLAZA": EconBuilding.BuildingType.PLAZA,
		"WOOD_EXTRACTOR": EconBuilding.BuildingType.SAWMILL,
		"STONE_EXTRACTOR": EconBuilding.BuildingType.MINE,
		"RESIN_EXTRACTOR": EconBuilding.BuildingType.MINE,
		"WHEAT_EXTRACTOR": EconBuilding.BuildingType.VILLAGE,
		"IRON_EXTRACTOR": EconBuilding.BuildingType.MINE,
		"COTTON_EXTRACTOR": EconBuilding.BuildingType.VILLAGE,
		"DINER": EconBuilding.BuildingType.DINER,
		"MILL": EconBuilding.BuildingType.MILL,
	}
	if not btype_map.has(btype_str):
		print("[EconBattle] _create_building_from_card: unknown building_type '%s'" % btype_str)
		return null
	var btype: int = btype_map[btype_str]
	var b := EconBuilding.new()
	b.setup(btype, target_cell, true)
	b.required_operation_labor = int(card.get("required_operation_labor", card.get("population_required", 0)))
	b.position = grid.hex_to_pixel(target_cell.x, target_cell.y)
	# HP 繧偵き繝ｼ繝峨°繧芽ｨｭ螳・
	var hp_val: float = float(card.get("hp", 100))
	b.hp = hp_val
	b.max_hp = hp_val
	b.building_destroyed.connect(func(building: Node):
		_on_building_destroyed(building)
		# 蟒ｺ迚ｩ遐ｴ螢頑凾縺ｮ莠ｺ蜿｣譖ｴ譁ｰ・按ｧ8.5・・
		if economy != null:
			var pop_req: int = card.get("population_required", 0)
			economy.population_used -= pop_req
			var pop_supply: int = card.get("population_supply", 0)
			if pop_supply > 0:
				# HOUSE遐ｴ螢頑凾縺ｯ calculate_population_cap() 縺ｧ蜀崎ｨ育ｮ励☆繧具ｼ按ｧ2.7.1 Lv蛻･蜉ｹ譫懷ｯｾ蠢懶ｼ・
				economy.population_cap = economy.calculate_population_cap()
				print("[EconBattle] HOUSE destroyed: population_cap recalculated -> ", economy.population_cap)
				_resolve_population_overflow()
	)
	return b

func _resolve_population_overflow() -> void:
	# ﾂｧ8.5.1 菴丞ｱ・ｴ螢頑凾縺ｮ蟒ｺ迚ｩ蛛懈ｭ｢繧｢繝ｫ繧ｴ繝ｪ繧ｺ繝
	if economy == null:
		return
	while economy.population_used > economy.population_cap:
		var active_buildings: Array = player_buildings.filter(func(b): return b.is_alive and b.is_built and not b.has_meta("stopped"))
		if active_buildings.is_empty():
			break
		# 蠢・ｦ∽ｺｺ蜿｣縺ｮ螟ｧ縺阪＞鬆・・蟒ｺ險ｭ鬆・ｼ・IFO・峨〒繧ｽ繝ｼ繝・
		active_buildings.sort_custom(func(a, b_node):
			var a_pop: int = a.get_meta("population_required") if a.has_meta("population_required") else 0
			var b_pop: int = b_node.get_meta("population_required") if b_node.has_meta("population_required") else 0
			if a_pop != b_pop:
				return a_pop > b_pop
			var a_ord: int = a.get_meta("construction_order") if a.has_meta("construction_order") else 0
			var b_ord: int = b_node.get_meta("construction_order") if b_node.has_meta("construction_order") else 0
			return a_ord > b_ord
		)
		var target: EconBuilding = active_buildings[0]
		target.set_meta("stopped", true)
		var pop_req: int = target.get_meta("population_required") if target.has_meta("population_required") else 0
		economy.population_used -= pop_req
		print("[EconBattle] _resolve_population_overflow: stopped building at (%d,%d)" % [target.grid_pos.x, target.grid_pos.y])

func trigger_early_charge() -> void:
	# ﾂｧ4.6.1 / ﾂｧ8.2 譌ｩ譛溽ｪ∵茶縺ｮ繧ｨ繝ｳ繝医Μ繝昴う繝ｳ繝茨ｼ・nitize_military_power縺ｯDeckManager邨檎罰縺ｧ螳溯｡鯉ｼ・
	if deck_manager != null:
		deck_manager.trigger_force_charge()
	log_message.emit("Early charge triggered!")

func unitize_military_power() -> int:
	# ﾂｧ4.7.3 / ﾂｧ8.2 蜈ｵ蜉帚・繝ｦ繝九ャ繝亥､画鋤・育ｪ∵茶譎ゅ・縺ｿ蜻ｼ蜃ｺ繝ｻ譌怜偵＠蜊倡峡縺ｧ縺ｯ蜻ｼ縺ｰ縺ｪ縺・ｼ・
	if economy == null:
		return 0
	var raw_unit_count: int = int(floor(economy.military_power))
	var unit_count: int = mini(raw_unit_count, economy.get_max_chargeable_units())
	economy.military_power -= float(unit_count)  # 蟆乗焚驛ｨ繧呈ｮ九☆
	if unit_count <= 0:
		print("[EconBattle] unitize_military_power skipped: power=%d max_chargeable=%d" % [raw_unit_count, economy.get_max_chargeable_units()])
		return 0
	_spawn_units_from_barracks(unit_count)
	log_message.emit("Unitized military power: %d units spawned" % unit_count)
	print("[EconBattle] unitize_military_power: %d/%d units from %.2f power" % [unit_count, raw_unit_count, economy.military_power + float(unit_count)])
	return unit_count

func register_enemy_reach_base(enemy_count: int) -> void:
	if economy == null:
		return
	economy.apply_defense_breakthrough_loss(enemy_count)

func _check_enemy_base_breakthroughs() -> void:
	var player_base: EconBuilding = _get_player_base()
	if player_base == null:
		return
	var breakthrough_count: int = 0
	for u in enemy_units:
		if not u.is_alive:
			continue
		var unit_id: int = u.get_instance_id()
		if _enemy_base_breakthrough_ids.has(unit_id):
			continue
		if grid.hex_distance(u.grid_pos, player_base.grid_pos) <= u.attack_range:
			_enemy_base_breakthrough_ids[unit_id] = true
			breakthrough_count += 1
	if breakthrough_count > 0:
		register_enemy_reach_base(breakthrough_count)
		log_message.emit("Defense breakthrough: %d enemy units reached base" % breakthrough_count)

func _get_player_base() -> EconBuilding:
	for b in player_buildings:
		if b.building_type == EconBuilding.BuildingType.BASE and b.is_alive:
			return b
	return null

func _spawn_units_from_barracks(unit_count: int) -> void:
	# ﾂｧ4.7.3 蜈ｵ闊弱そ繝ｫ縺九ｉ蝮・ｭ牙・謨｣蜃ｺ迴ｾ
	var barracks_cells: Array = []
	for b in player_buildings:
		if b.building_type == EconBuilding.BuildingType.BARRACKS and b.is_alive and b.is_built:
			barracks_cells.append(b.grid_pos)
	if barracks_cells.size() == 0:
		# 蜈ｵ闊弱↑縺・竊・BASE菴咲ｽｮ縺九ｉ繧ｹ繝昴・繝ｳ
		for b in player_buildings:
			if b.building_type == EconBuilding.BuildingType.BASE and b.is_alive:
				barracks_cells.append(b.grid_pos)
				break
	if barracks_cells.size() == 0:
		return
	var per_cell: int = int(unit_count / barracks_cells.size())
	var remainder: int = unit_count % barracks_cells.size()
	for i in range(barracks_cells.size()):
		var cell: Vector2i = barracks_cells[i]
		var n: int = per_cell + (1 if i < remainder else 0)
		for _j in range(n):
			spawn_player_unit(cell.x, cell.y, 0, true)  # 遯∵茶繝｢繝ｼ繝峨〒蜃ｺ迴ｾ
	print("[EconBattle] _spawn_units_from_barracks: %d units from %d barracks" % [unit_count, barracks_cells.size()])

func _accumulate_barracks_power(delta: float) -> void:
	# ﾂｧ4.7.2 / ﾂｧ8.2 蜈ｵ闊弱・蜈ｵ蜉幄塘遨搾ｼ・conBattle.update蜀・〒蜻ｼ蜃ｺ・・
	if economy == null:
		return
	var active_count: int = 0
	for b in player_buildings:
		if b.building_type == EconBuilding.BuildingType.BARRACKS and b.is_alive and b.is_built and b.is_operating:
			active_count += 1
	if active_count > 0:
		economy.accumulate_military_power(delta, active_count)

func _allocate_operation_labor() -> void:
	if economy == null:
		return
	var sorted_buildings: Array = player_buildings.filter(func(b): return b.is_alive and b.is_built)
	sorted_buildings.sort_custom(func(a: EconBuilding, b: EconBuilding) -> bool:
		var ap: int = _get_operation_priority(a)
		var bp: int = _get_operation_priority(b)
		if ap == bp:
			return a.grid_pos.x < b.grid_pos.x if a.grid_pos.y == b.grid_pos.y else a.grid_pos.y < b.grid_pos.y
		return ap < bp
	)
	var pool: int = economy.get_operation_labor()
	for building in sorted_buildings:
		var need: int = max(0, int(building.required_operation_labor))
		if need <= 0:
			building.set_operating(true)
		elif pool >= need:
			pool -= need
			building.set_operating(true)
		else:
			building.set_operating(false)

func _get_operation_priority(building: EconBuilding) -> int:
	match building.building_type:
		EconBuilding.BuildingType.VILLAGE, EconBuilding.BuildingType.DINER, EconBuilding.BuildingType.MILL:
			return 0
		EconBuilding.BuildingType.SAWMILL, EconBuilding.BuildingType.MINE, EconBuilding.BuildingType.TRADE_POST, EconBuilding.BuildingType.EXCHANGE:
			return 1
		EconBuilding.BuildingType.BARRACKS, EconBuilding.BuildingType.FORTRESS, EconBuilding.BuildingType.WORKSHOP, EconBuilding.BuildingType.SMITHY, EconBuilding.BuildingType.WATCHTOWER:
			return 2
		EconBuilding.BuildingType.PLAZA:
			return 3
		_:
			return 4

func update(delta: float) -> void:
	if not is_running or _game_over:
		return
	if deck_manager != null:
		deck_manager.update(delta)
		deck_manager.try_resolve_pending_draws()
	# 蜈ｵ闊弱・蜈ｵ蜉幄塘遨搾ｼ・0.2 ﾂｧ4.7.2・・
	_allocate_operation_labor()
	_accumulate_barracks_power(delta)
	# 蠑ｷ蛻ｶ遯∵茶繧ｲ繝ｼ繧ｸ貅繧ｿ繝ｳ譎ゅ・閾ｪ蜍輔Θ繝九ャ繝亥喧・按ｧ9.1 繧ｿ繝ｼ繝ｳ10・・
	if deck_manager != null and deck_manager.force_charge_triggered and economy != null:
		if floor(economy.military_power) > 0.0:
			pass  # unitize_military_power 縺ｯ trigger_force_charge 邨檎罰縺ｧ蜻ｼ縺ｰ繧後ｋ
	var total_units: int = player_units.size()
	economy.update(delta, total_units)
	_update_milestone_progress()
	_update_construction_progress(delta)
	# 繝上・繝吶せ繧ｿ繝ｼ譖ｴ譁ｰ
	var all_movable: Array = player_units + player_harvesters + enemy_units
	var alive_harvester_count: int = player_harvesters.filter(func(h): return h.is_alive).size()
	for h in player_harvesters:
		if h.is_alive:
			h.update(delta, grid, all_movable, enemy_units, player_buildings, alive_harvester_count)
	# 蟒ｺ迚ｩ譖ｴ譁ｰ・医・繝ｬ繧､繝､繝ｼ蛛ｴ縺ｮ縺ｿ・・
	for b in player_buildings:
		if b.is_alive:
			b.update(delta, economy, player_buildings, grid)
	# AI譖ｴ譁ｰ
	if ai != null:
		ai.update(delta)
	# 謌ｦ髣倥Θ繝九ャ繝域峩譁ｰ
	var all_units: Array = player_units + enemy_units
	for u in player_units:
		if u.is_alive:
			var unit_rally := _get_unit_rally_pos(u)
			u.update(delta, enemy_units, enemy_buildings, enemy_harvesters, grid, all_units, economy, unit_rally)
	for u in enemy_units:
		if u.is_alive:
			u.update(delta, player_units, player_buildings, player_harvesters, grid, all_units, ai.economy if ai != null else null)
	# 驥阪↑繧翫き繧ｦ繝ｳ繝域峩譁ｰ
	_check_enemy_base_breakthroughs()
	_update_stack_counts()
	# 豁ｻ莠｡蜃ｦ逅・
	_remove_dead()
	_check_victory()

func _allocate_work_labor() -> Array:
	# ADR-003: EconBattle が作業人手割当を所有する
	var sorted_sites: Array = grid.construction_sites.values()
	sorted_sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("started_at", 0)) < int(b.get("started_at", 0))
	)
	var pool: int = economy.get_work_labor()
	var active_sites: Array = []
	for site in sorted_sites:
		var need: int = int(site.get("required_work_labor", 1))
		if pool >= need:
			pool -= need
			active_sites.append(site)
	return active_sites

func _update_construction_progress(delta: float) -> void:
	# ADR-003: construction 管理は EconBattle が単一責務所有者
	if grid == null or economy == null:
		return
	var active_sites: Array = _allocate_work_labor()
	var active_lookup: Dictionary = {}
	for site in active_sites:
		active_lookup[site.get("panel_id", Vector2i(-1, -1))] = true

	var completed_panel_ids: Array = []
	for pos in grid.construction_sites.keys():
		var site: Dictionary = grid.construction_sites[pos]
		var is_active: bool = active_lookup.has(pos)
		site["is_active"] = is_active
		if is_active:
			var build_time: float = max(0.001, float(site.get("construction_time", 1.0)))
			site["construction_progress"] = min(1.0, float(site.get("construction_progress", 0.0)) + delta / build_time)
		grid.construction_sites[pos] = site
		_log_event({
			"type": "BUILDING_PROGRESS_UPDATED",
			"panel_id": [pos.x, pos.y],
			"progress": float(site.get("construction_progress", 0.0)),
			"required_work_labor": int(site.get("required_work_labor", 1)),
		})
		if float(site.get("construction_progress", 0.0)) >= 1.0:
			completed_panel_ids.append(pos)

	for pos in completed_panel_ids:
		var site: Dictionary = grid.construction_sites[pos].duplicate(true)
		grid.construction_sites.erase(pos)
		var building: EconBuilding = grid.spawn_building(site)
		if building == null:
			continue
		var card: Dictionary = site.get("card", {})
		building.unit_produced.connect(func(bpos: Vector2i, utype: int):
			spawn_player_unit(bpos.x, bpos.y, utype, false)
			_on_unit_produced(bpos, utype)
		)
		building.building_destroyed.connect(func(destroyed: Node):
			_on_building_destroyed(destroyed)
		)
		register_player_building(building)
		if building.building_type == EconBuilding.BuildingType.HOUSE:
			economy.population_cap = economy.calculate_population_cap()
		grid.reveal_panels_around(building.grid_pos)
		if deck_manager != null:
			if bool(site.get("is_special", false)):
				deck_manager.exclude_card(card)
			else:
				deck_manager.discard_card(card)
		_log_event({
			"type": "BUILDING_COMPLETED",
			"panel_id": [building.grid_pos.x, building.grid_pos.y],
			"building_type": int(building.building_type),
			"card_id": str(site.get("card_id", "")),
		})
		_on_building_constructed(building)
		building.queue_redraw()
	if not completed_panel_ids.is_empty() or not grid.construction_sites.is_empty():
		grid.queue_redraw()

func _remove_dead() -> void:
	player_units = player_units.filter(func(u): return u.is_alive)
	player_harvesters = player_harvesters.filter(func(h): return h.is_alive)
	enemy_units = enemy_units.filter(func(u): return u.is_alive)
	enemy_harvesters = enemy_harvesters.filter(func(h): return h.is_alive)
	# 豁ｻ莠｡蠕後↓harvester_index繧貞・謗｡逡ｪ
	for i in range(player_harvesters.size()):
		player_harvesters[i].harvester_index = i
	for i in range(enemy_harvesters.size()):
		enemy_harvesters[i].harvester_index = i

func _check_victory() -> void:
	if _game_over:
		return
	for b in player_buildings:
		if b.building_type == EconBuilding.BuildingType.BASE and not b.is_alive:
			_game_over = true
			is_running = false
			battle_ended.emit(false)
			log_message.emit("Defeat... Player base destroyed!")
			return
	for b in enemy_buildings:
		if b.building_type == EconBuilding.BuildingType.BASE and not b.is_alive:
			_game_over = true
			is_running = false
			battle_ended.emit(true)
			log_message.emit("Victory! Enemy base destroyed!")
			return

func spawn_player_unit(col: int, row: int, unit_type: int, charge_mode: bool = false) -> void:
	var unit := EconUnit.create(unit_type, EconUnit.Side.PLAYER, col, row)
	unit.position = grid.hex_to_pixel(col, row)
	unit.is_idle = not charge_mode
	unit._spawn_building_pos = Vector2i(col, row)
	player_units.append(unit)
	get_parent().add_child(unit)
	var names := ["Attacker", "Tank", "Breaker"]
	log_message.emit("%s produced at (%d,%d)" % [names[unit_type], col, row])

func spawn_player_harvester(pos: Vector2i, economy: EconEconomy) -> void:
	var h := EconHarvester.new()
	h.grid_pos = pos
	h.economy = economy
	h.battle = self
	h.position = grid.hex_to_pixel(pos.x, pos.y)
	h.harvested.connect(_on_harvested)
	h.harvester_index = player_harvesters.size()
	player_harvesters.append(h)
	grid.add_child(h)
	# Harvester spawn log removed (v0.2: left-side harvester UI deleted)

func add_building_to_queue(_b: EconBuilding) -> void:
	pass  # 繝薙Ν繝繝ｼ譁ｹ蠑上↓遘ｻ陦梧ｸ医∩縲ゅン繝ｫ繝繝ｼ縺瑚・蜍慕噪縺ｫ譛ｪ蟒ｺ險ｭ蟒ｺ迚ｩ繧呈球蠖薙☆繧・
func spawn_enemy_unit(utype: int, pos: Vector2i) -> void:
	var unit := EconUnit.create(utype, EconUnit.Side.ENEMY, pos.x, pos.y)
	unit.position = grid.hex_to_pixel(pos.x, pos.y)
	unit.is_idle = true  # 謨ｵ繝ｦ繝九ャ繝医ｂ蛻晄悄縺ｯ繧｢繧､繝峨Μ繝ｳ繧ｰ
	unit._spawn_building_pos = pos
	enemy_units.append(unit)
	grid.add_child(unit)

func spawn_enemy_harvester(pos: Vector2i, economy: EconEconomy) -> void:
	var h := EconHarvester.new()
	h.grid_pos = pos
	h.economy = economy
	h.position = grid.hex_to_pixel(pos.x, pos.y)
	h.harvested.connect(func(rtype): economy.add_resource(rtype))
	h.harvester_index = enemy_harvesters.size()
	enemy_harvesters.append(h)
	grid.add_child(h)

func register_enemy_building(b: EconBuilding) -> void:
	enemy_buildings.append(b)
	grid.add_child(b)

func register_player_building(b: EconBuilding) -> void:
	player_buildings.append(b)
	grid.add_child(b)
	if economy != null:
		economy.buildings = player_buildings

func _log_event(data: Dictionary) -> void:
	var log_manager: Object = get_node_or_null("/root/LogManager")
	if log_manager == null:
		var scene := get_tree().current_scene
		if scene != null:
			log_manager = scene.get("_log_manager")
	if log_manager != null and log_manager.has_method("log_event"):
		log_manager.log_event(data)

func _update_stack_counts() -> void:
	var counts: Dictionary = {}
	for u in player_units + enemy_units:
		if u.is_alive:
			counts[u.grid_pos] = counts.get(u.grid_pos, 0) + 1
	for u in player_units + enemy_units:
		u.stack_count = counts.get(u.grid_pos, 1) if u.is_alive else 1

func set_player_flags(flags: Array) -> void:
	player_flags = flags

func _get_unit_rally_pos(u: EconUnit) -> Vector2i:
	for b in player_buildings:
		if b.grid_pos == u._spawn_building_pos and b.connected_flag_id >= 0:
			for f in player_flags:
				if f.flag_id == b.connected_flag_id:
					return f.grid_pos
	return Vector2i(-1, -1)

# 陞榊粋繝ｩ繝ｳ繧ｯ蜀崎ｨ育ｮ暦ｼ亥ｻｺ險ｭ螳御ｺ・・豁ｻ莠｡譎ゅ↓蜻ｼ縺ｳ蜃ｺ縺暦ｼ・
# 隕∽ｻｶ螳夂ｾｩ譖ｸ req_econ_equipment_shop_mvp.md ﾂｧ 4.2 繧医ｊ
func _recalc_fusion_clusters() -> void:
	var equip_types: Array = [
		EconBuilding.BuildingType.EQUIPMENT_SHOP,
	]
	var visited: Dictionary = {}
	var next_cluster_id: int = 0
	for b0 in player_buildings:
		if visited.has(b0): continue
		if not b0.is_alive or not b0.is_built: continue
		if not (b0.building_type in equip_types): continue
		# BFS: 蜷檎ｨｮ縺九▽ hex_distance==1 縺ｧ騾｣邨・
		var cluster: Array = []
		var queue: Array = [b0]
		visited[b0] = true
		while queue.size() > 0:
			var cur: EconBuilding = queue.pop_front()
			cluster.append(cur)
			for b1 in player_buildings:
				if visited.has(b1): continue
				if not b1.is_alive or not b1.is_built: continue
				if b1.building_type != b0.building_type: continue
				if grid.hex_distance(cur.grid_pos, b1.grid_pos) != 1: continue
				visited[b1] = true
				queue.append(b1)
		var rank: int = clampi(cluster.size(), 1, 3)
		for b in cluster:
			b.fusion_rank = rank
			b.fusion_cluster_id = next_cluster_id
			b.queue_redraw()
		next_cluster_id += 1

# 繝ｦ繝九ャ繝育函謌先凾縺ｮ陬・ｙ螻九ヰ繝暮←逕ｨ
# 隕∽ｻｶ螳夂ｾｩ譖ｸ req_econ_equipment_shop_mvp.md ﾂｧ 4.3 繧医ｊ
func _apply_equipment_buffs(unit: EconUnit, source_building_pos: Vector2i) -> void:
	var equip_types: Array = [
		EconBuilding.BuildingType.EQUIPMENT_SHOP,
	]
	# 髫｣謗･陬・ｙ螻九・縺・■譛螟ｧ fusion_rank 繧帝∈螳夲ｼ井ｺ碁㍾驕ｩ逕ｨ蝗樣∩・・
	var best: EconBuilding = null
	for b in player_buildings:
		if not b.is_alive or not b.is_built: continue
		if grid.hex_distance(source_building_pos, b.grid_pos) != 1: continue
		if not (b.building_type in equip_types): continue
		if best == null or b.fusion_rank > best.fusion_rank:
			best = b
	# 驕ｩ逕ｨ・育鮪邨仙粋: 繝｡繧ｽ繝・ラ邨檎罰・・
	if best != null:
		unit.apply_equipment_buff(int(unit.unit_type), best.fusion_rank)

# 繝ｦ繝九ャ繝育函謌先凾縺ｮ骰帛・螻九ヰ繝暮←逕ｨ
# 隕∽ｻｶ螳夂ｾｩ譖ｸ req_econ_smithy_building.md ﾂｧ 5.3 繧医ｊ
func _apply_smithy_buff(unit: EconUnit, source_building_pos: Vector2i) -> void:
	# 髫｣謗･骰帛・螻九・縺・■譛螟ｧ smithy_level 繧帝∈螳夲ｼ磯㍾隍・←逕ｨ蝗樣∩・・
	var best_rank: int = 0
	for b in player_buildings:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.SMITHY:
			continue
		if grid.hex_distance(source_building_pos, b.grid_pos) != 1:
			continue
		var rank: int = b.smithy_level
		if rank > best_rank:
			best_rank = rank
	# 驕ｩ逕ｨ・育鮪邨仙粋: 繝｡繧ｽ繝・ラ邨檎罰・・
	if best_rank > 0:
		unit.apply_smithy_buff(best_rank)

# 繝上・繝吶せ繧ｿ繝ｼ harvested 繧ｷ繧ｰ繝翫Ν蜿嶺ｿ｡譎ゅ・繝ｫ繝ｼ繝・ぅ繝ｳ繧ｰ
# 隕∽ｻｶ螳夂ｾｩ譖ｸ req_econ_unit_production_harvester.md ﾂｧ 2.3 繧医ｊ
func _on_harvested(rtype: int) -> void:
	_route_harvested_resource(rtype)

# 繝ｦ繝九ャ繝育函謌先凾縺ｮ陬・ｙ螻九・骰帛・螻九ヰ繝暮←逕ｨ
# 隕∽ｻｶ螳夂ｾｩ譖ｸ req_econ_equipment_shop_mvp.md ﾂｧ 3.1 / req_econ_smithy_building.md ﾂｧ 5.3 繧医ｊ
func _on_unit_produced(pos: Vector2i, unit_type: int) -> void:
	# unit_type: 0=遯・ 1=螳・ 2=蟠ｩ, -1=harvester・医ワ繝ｼ繝吶せ繧ｿ繝ｼ逕滓・譎ゅ・蜃ｦ逅・＠縺ｪ縺・ｼ・
	if unit_type < 0:
		return
	if not player_units.size() > 0:
		return
	var unit = player_units[-1]
	_apply_equipment_buffs(unit, pos)
	_apply_smithy_buff(unit, pos)

func _on_building_constructed(building: EconBuilding) -> void:
	if building.building_type == EconBuilding.BuildingType.EQUIPMENT_SHOP:
		_recalc_fusion_clusters()
	_try_acquire_adjacent_chests(building)

func boost_first_construction(progress_ratio: float) -> void:
	var targets: Array = player_buildings.filter(func(b): return b.is_alive and not b.is_built)
	if targets.is_empty():
		return
	targets.sort_custom(func(a, b):
		var a_order: int = a.get_meta("construction_order") if a.has_meta("construction_order") else 0
		var b_order: int = b.get_meta("construction_order") if b.has_meta("construction_order") else 0
		return a_order < b_order
	)
	var target: EconBuilding = targets[0]
	var required: float = EconBuilding.REQUIRED_CONSTRUCTION.get(int(target.building_type), 5.0)
	target.build_progress = min(required, target.build_progress + required * progress_ratio)
	target.queue_redraw()

func _spawn_chests() -> void:
	for chest in chests:
		if is_instance_valid(chest):
			chest.queue_free()
	chests.clear()
	if grid == null:
		return
	var candidates := [Vector2i(9, 4), Vector2i(13, 6), Vector2i(16, 8)]
	for pos in candidates:
		if not grid.is_valid_cell(pos.x, pos.y):
			continue
		var chest = EconChestScript.new()
		chest.setup(pos, reward_manager)
		chest.position = grid.hex_to_pixel(pos.x, pos.y)
		chests.append(chest)
		grid.add_child(chest)

func _try_acquire_adjacent_chests(building: EconBuilding) -> void:
	if grid == null:
		return
	for chest in chests:
		if chest == null or bool(chest.acquired):
			continue
		if grid.hex_distance(building.grid_pos, chest.grid_pos) > 1:
			continue
		var result: Dictionary = chest.acquire()
		if result.is_empty():
			continue
		log_message.emit("Chest obtained: %s" % str(result.get("reward", {}).get("label", "reward")))
		chest_acquired.emit(result)

func _update_milestone_progress() -> void:
	if reward_manager == null or economy == null:
		return
	reward_manager.update_progress("population", int(economy.population_float))
	reward_manager.update_progress("food", int(economy.food_value))
	reward_manager.update_progress("satisfaction", int(economy.satisfaction_value))
	reward_manager.update_progress("building", _count_built_player_buildings())
	reward_manager.update_progress("resource", _count_total_resources())
	reward_manager.update_progress("troop", int(floor(economy.military_power)))
	reward_manager.update_progress("land", _count_placed_land_cards())
	reward_manager.update_progress("risk", int(deck_manager.current_turn) if deck_manager != null else 0)

func _count_built_player_buildings() -> int:
	var count := 0
	for b in player_buildings:
		if b.is_alive and b.is_built:
			count += 1
	return count

func _count_total_resources() -> int:
	return int(economy.wood + economy.stone + economy.resin + economy.wheat + economy.iron + economy.cotton)

func _count_placed_land_cards() -> int:
	if grid == null:
		return 0
	var count := 0
	for panel in grid.land_panels.values():
		if bool((panel as Dictionary).get("land_card_placed", false)):
			count += 1
	return count

func _on_building_destroyed(building: EconBuilding) -> void:
	# 陬・ｙ螻区ｭｻ莠｡譎ゅ↓陞榊粋繝ｩ繝ｳ繧ｯ蜀崎ｨ育ｮ暦ｼ郁ｦ∽ｻｶ螳夂ｾｩ譖ｸ req_econ_equipment_shop_mvp.md ﾂｧ 4.4・・
	if building.building_type == EconBuilding.BuildingType.EQUIPMENT_SHOP:
		_recalc_fusion_clusters()

func _route_harvested_resource(rtype: int) -> void:
	var btype: int = -1
	var key: String = ""
	match rtype:
		EconGrid.ResourceType.WOOD:
			btype = EconBuilding.BuildingType.BARRACKS
			key = "wood"
		EconGrid.ResourceType.STONE:
			btype = EconBuilding.BuildingType.FORTRESS
			key = "stone"
		EconGrid.ResourceType.RESIN:
			btype = EconBuilding.BuildingType.WORKSHOP
			key = "resin"
		_:
			# WHEAT / IRON / COTTON 遲峨・譌｢蟄倬壹ｊ economy 縺ｫ逶ｴ謗･霑ｽ蜉
			economy.add_resource(rtype, 1)
			return
	# 隧ｲ蠖薙ち繧､繝励・蟒ｺ迚ｩ縺ｮ縺・■縲∝惠蠎ｫ縺ｫ遨ｺ縺阪′縺ゅｋ譛蟇・ｊ繧帝∈螳・
	var best: EconBuilding = null
	var best_priority: int = 0
	for b in player_buildings:
		if not b.is_alive or not b.is_built: continue
		if b.building_type != btype: continue
		if b.stockpile.get(key, 0) >= EconBuilding.STOCKPILE_CAP: continue
		# 髮・ｸｭ蟒ｺ險ｭ繝｢繝ｼ繝峨・蜆ｪ蜈亥ｺｦ繧呈ｵ∫畑 + 蝨ｨ蠎ｫ縺悟ｰ代↑縺・・ｒ蜆ｪ蜈・
		var priority: int = b.build_priority * 100 + (EconBuilding.STOCKPILE_CAP - b.stockpile.get(key, 0))
		if best == null or priority > best_priority:
			best = b
			best_priority = priority
	if best != null:
		if not best.add_stock(key, 1):
			# 貅譚ｯ縺ｮ蝣ｴ蜷医・繝輔か繝ｼ繝ｫ繝舌ャ繧ｯ
			economy.add_resource(rtype, 1)
	else:
		# 蜈ｨ蟒ｺ迚ｩ貅譚ｯ or 隧ｲ蠖灘ｻｺ迚ｩ縺ｪ縺・竊・譌｢蟄倬壹ｊ economy 縺ｫ繝輔か繝ｼ繝ｫ繝舌ャ繧ｯ
		economy.add_resource(rtype, 1)
