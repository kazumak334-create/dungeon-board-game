class_name EconAI
extends Node

var economy: EconEconomy
var _grid: EconGrid
var _battle: EconBattle

var _construction_queue: Array = []  # EconBuilding（未建設）
var _build_plan: Array = []  # 建設予定リスト {type, pos}
var _diag_timer: float = 0.0

func setup(grid: EconGrid, battle: EconBattle) -> void:
	_grid = grid
	_battle = battle
	# 敵専用Economy
	economy = EconEconomy.new()
	economy.alloc_wood = 35
	economy.alloc_stone = 25
	economy.alloc_sulfur = 20
	economy.alloc_wheat = 20
	economy.priority_wood = 1
	economy.priority_stone = 1
	economy.priority_sulfur = 2
	economy.priority_wheat = 3
	economy.harvester_starved.connect(_on_economy_starved)
	add_child(economy)
	# ビルドオーダー（固定）
	_build_plan = [
		{"type": EconBuilding.BuildingType.BARRACKS, "pos": Vector2i(3, 10)},
		{"type": EconBuilding.BuildingType.VILLAGE,  "pos": Vector2i(7, 10)},
		{"type": EconBuilding.BuildingType.BARRACKS, "pos": Vector2i(3, 9)},
		{"type": EconBuilding.BuildingType.FORTRESS, "pos": Vector2i(7, 9)},
		{"type": EconBuilding.BuildingType.WORKSHOP, "pos": Vector2i(5, 10)},
	]
	# blueprint状態でenemy_buildingsに追加（is_built=false）
	for plan in _build_plan:
		var b := EconBuilding.new()
		b.setup(plan["type"], plan["pos"], false)  # is_player_side=false
		b.position = _grid.hex_to_pixel(plan["pos"].x, plan["pos"].y)
		b.unit_produced.connect(on_unit_produced)
		_construction_queue.append(b)

func update(delta: float) -> void:
	# 建設キュー処理
	while _construction_queue.size() > 0:
		var next: EconBuilding = _construction_queue[0]
		if not next.is_alive or next.is_built:
			_construction_queue.pop_front()
			continue
		var btype_int: int = int(next.building_type)
		var cost: Dictionary = EconBuilding.BUILD_COSTS.get(btype_int, {})
		# VILLAGE 建設前：小麦隣接チェック＆動的位置補正
		if next.building_type == EconBuilding.BuildingType.VILLAGE:
			var neighbors := _grid.get_neighbors(next.grid_pos.x, next.grid_pos.y)
			var has_wheat := false
			for nb in neighbors:
				if _grid.get_resource_type(nb) == EconGrid.ResourceType.WHEAT:
					has_wheat = true
					break
			if not has_wheat:
				# 敵陣 (row 8-11) で小麦隣接セルを探す
				var valid_pos := Vector2i(-1, -1)
				var occupied: Dictionary = {}
				for b2 in _battle.enemy_buildings:
					if b2.is_alive:
						occupied[b2.grid_pos] = true
				for row in range(8, 12):
					for col in range(_grid.get_col_count(row)):
						var cell := Vector2i(col, row)
						if occupied.has(cell):
							continue
						for nb2 in _grid.get_neighbors(col, row):
							if _grid.get_resource_type(nb2) == EconGrid.ResourceType.WHEAT:
								valid_pos = cell
								break
						if valid_pos != Vector2i(-1, -1):
							break
					if valid_pos != Vector2i(-1, -1):
						break
				if valid_pos == Vector2i(-1, -1):
					# 小麦隣接セルが見つからない場合はスキップ
					_construction_queue.pop_front()
					continue
				next.grid_pos = valid_pos
				next.position = _grid.hex_to_pixel(valid_pos.x, valid_pos.y)
		if economy.can_afford(cost):
			economy.spend(cost)
			next.is_built = true
			next.position = _grid.hex_to_pixel(next.grid_pos.x, next.grid_pos.y)
			_battle.enemy_buildings.append(next)
			_grid.add_child(next)
			_construction_queue.pop_front()
			var names := ["Barracks", "Fortress", "Workshop", "Village", "Base"]
			_battle.log_message.emit("AI Built: %s at (%d,%d)" % [names[btype_int], next.grid_pos.x, next.grid_pos.y])
		else:
			break  # 資源不足 → 次フレームに再試行
	# 敵経済更新（小麦消費）
	var total: int = _battle.enemy_units.size()
	economy.update(delta, total)
	# 診断ログ（20秒ごと）
	_diag_timer += delta
	if _diag_timer >= 20.0:
		_diag_timer = 0.0
		var alive_h: int = _battle.enemy_harvesters.filter(func(h): return h.is_alive).size()
		var q_names := ["Barracks","Fortress","Workshop","Village","Base"]
		var q_info: String = "empty"
		if _construction_queue.size() > 0:
			var nb: EconBuilding = _construction_queue[0]
			var cost: Dictionary = EconBuilding.BUILD_COSTS.get(int(nb.building_type), {})
			q_info = "%s(cost:%s)" % [q_names[int(nb.building_type)], str(cost)]
		_battle.log_message.emit("AI diag: W%d St%d Su%d | harv:%d | next:%s" % [
			economy.wood, economy.stone, economy.sulfur, alive_h, q_info])
	# 敵ハーベスター更新
	var all_movable: Array = _battle.player_units + _battle.player_harvesters + _battle.enemy_units + _battle.enemy_harvesters
	for h in _battle.enemy_harvesters:
		if h.is_alive:
			h.update(delta, _grid, all_movable)
	# 敵建物更新
	for b in _battle.enemy_buildings:
		if b.is_alive:
			b.update(delta, economy)

func _on_economy_starved(kill_count: int) -> void:
	var alive_u: Array = _battle.enemy_units.filter(func(u): return u.is_alive)
	if alive_u.is_empty():
		return
	alive_u.shuffle()
	var killed: int = 0
	for i in range(mini(kill_count, alive_u.size())):
		alive_u[i].is_alive = false
		alive_u[i].visible = false
		killed += 1
	_battle.log_message.emit("AI Wheat shortage! %d unit(s) lost" % killed)

func on_unit_produced(pos: Vector2i, utype: int) -> void:
	if utype == -1:
		# ハーベスター生産
		var h := EconHarvester.new()
		h.grid_pos = pos
		h.economy = economy
		h.position = _grid.hex_to_pixel(pos.x, pos.y)
		h.harvested.connect(func(rtype): economy.add_resource(rtype))
		h.harvester_index = _battle.enemy_harvesters.size()
		_battle.enemy_harvesters.append(h)
		_grid.add_child(h)
	else:
		# 戦闘ユニット生産
		var unit := EconUnit.create(utype, EconUnit.Side.ENEMY, pos.x, pos.y)
		unit.position = _grid.hex_to_pixel(pos.x, pos.y)
		_battle.enemy_units.append(unit)
		_grid.add_child(unit)
