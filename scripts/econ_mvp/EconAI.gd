class_name EconAI
extends Node

# 敵戦闘ユニット無効化フラグ（true=通常動作 / false=経済検証モード）
const ENEMY_COMBAT_UNITS_ENABLED: bool = false

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
	economy.target_count = {
		EconGrid.ResourceType.WOOD: 1,
		EconGrid.ResourceType.STONE: 1,
		EconGrid.ResourceType.RESIN: 1,
		EconGrid.ResourceType.WHEAT: 1,
	}

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
		# VILLAGEのみ小麦隣接チェック＆動的位置補正（戦闘建物の資源隣接制限は削除済み）
		# 敵建物のいずれかから半径3以内チェック
		var in_range := false
		for eb in _battle.enemy_buildings:
			if eb.is_alive and _grid.hex_distance(next.grid_pos, eb.grid_pos) <= 3:
				in_range = true
				break
		var needs_relocation := false
		if next.building_type == EconBuilding.BuildingType.VILLAGE:
			var has_wheat := false
			for nb in _grid.get_neighbors(next.grid_pos.x, next.grid_pos.y):
				if _grid.get_resource_type(nb) == EconGrid.ResourceType.WHEAT:
					has_wheat = true
					break
			if not has_wheat or not in_range:
				needs_relocation = true
		elif not in_range:
			needs_relocation = true
		if needs_relocation:
			# 敵陣 (row 8-11) で敵建物から3hex以内のセルを探す
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
					var cell_in_range := false
					for eb2 in _battle.enemy_buildings:
						if eb2.is_alive and _grid.hex_distance(cell, eb2.grid_pos) <= 3:
							cell_in_range = true
							break
					if not cell_in_range:
						continue
					# VILLAGEは小麦隣接もチェック
					if next.building_type == EconBuilding.BuildingType.VILLAGE:
						var has_w := false
						for nb2 in _grid.get_neighbors(col, row):
							if _grid.get_resource_type(nb2) == EconGrid.ResourceType.WHEAT:
								has_w = true
								break
						if not has_w:
							continue
					valid_pos = cell
					break
				if valid_pos != Vector2i(-1, -1):
					break
			if valid_pos == Vector2i(-1, -1):
				# 有効位置が見つからない場合はスキップ
				_construction_queue.pop_front()
				continue
			next.grid_pos = valid_pos
			next.position = _grid.hex_to_pixel(valid_pos.x, valid_pos.y)
		# 配置は無料：ビルダーが現地到着後に資材チェックして建設進捗を蓄積する
		next.position = _grid.hex_to_pixel(next.grid_pos.x, next.grid_pos.y)
		_battle.register_enemy_building(next)
		_construction_queue.pop_front()
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
		_battle.log_message.emit("AI diag: W%d St%d Re%d | harv:%d | next:%s" % [
			economy.wood, economy.stone, economy.resin, alive_h, q_info])
	# 敵ハーベスター更新
	var all_movable: Array = _battle.player_units + _battle.player_harvesters + _battle.enemy_units + _battle.enemy_harvesters
	for h in _battle.enemy_harvesters:
		if h.is_alive:
			h.update(delta, _grid, all_movable, _battle.player_units)
	# 敵建物更新
	for b in _battle.enemy_buildings:
		if b.is_alive:
			b.update(delta, economy)


func on_unit_produced(pos: Vector2i, utype: int) -> void:
	if ENEMY_COMBAT_UNITS_ENABLED:
		_battle.spawn_enemy_unit(utype, pos)
