class_name EconBattle
extends Node

signal battle_ended(player_won: bool)
signal log_message(text: String)

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
var player_flags: Array = []   # EconRallyFlag の配列
var _game_over: bool = false

# 要件定義書 req_econ_draw_hand_circulation.md §8.2
var deck_manager = null  # EconDeckManager（型推論省略）

func setup(g: EconGrid, eco: EconEconomy) -> void:
	grid = g
	economy = eco

func start() -> void:
	is_running = true
	_game_over = false
	log_message.emit("Battle started!")

func setup_deck(initial_deck: Array, on_draw: Callable) -> void:
	# §8.2 EconBattle への追加
	var dm_script = load("res://scripts/econ_mvp/EconDeckManager.gd")
	deck_manager = dm_script.new()
	add_child(deck_manager)
	deck_manager.setup(initial_deck, self, on_draw)
	print("[EconBattle] setup_deck: deck_manager initialized")

func play_card_and_build(card_idx: int, target_cell: Vector2i) -> bool:
	# §4.4.3 / §8.2 カード使用→建物配置エントリポイント（v0.2 改訂・資源即時消費）
	if deck_manager == null:
		return false
	# 強制突撃後は建設停止（§9.6）
	if deck_manager.force_charge_triggered:
		return false
	if card_idx < 0 or card_idx >= deck_manager.hand.size():
		return false
	var card: Dictionary = deck_manager.hand[card_idx]
	# 配置チェック（§4.4.2）
	if not _check_placement_valid(card, target_cell):
		return false
	# ① 資源即時消費（§4.4.3 ステップ1）
	if economy != null:
		economy.consume_resources(card)
	# ② 手札から除外（§4.4.3 ステップ2）
	deck_manager.exclude_card_at(card_idx)
	# ③ 盤面に建物生成・登録（§4.4.3 ステップ3）
	var building := _create_building_from_card(card, target_cell)
	if building == null:
		return false
	register_player_building(building)
	# 人口更新（§8.6）
	if economy != null:
		economy.population_used += card.get("population_required", 0)
		var pop_supply: int = card.get("population_supply", 0)
		if pop_supply > 0:
			economy.population_cap += pop_supply
	log_message.emit("Card played: %s at (%d,%d)" % [card.get("name", "?"), target_cell.x, target_cell.y])
	return true

func _check_placement_valid(card: Dictionary, target_cell: Vector2i) -> bool:
	# §4.4.2 配置時4条件チェック
	# 条件1: 資源充足
	if economy != null and not economy.can_afford_card(card):
		log_message.emit("Resource insufficient for %s" % card.get("name", "?"))
		return false
	# 条件2: 人口充足
	if economy != null:
		var pop_req: int = card.get("population_required", 0)
		if economy.population_used + pop_req > economy.population_cap:
			log_message.emit("Population cap exceeded")
			return false
	# 条件3: 配置先有効チェック（グリッド内かつ占有なし）
	if grid != null and not grid.is_valid_cell(target_cell.x, target_cell.y):
		return false
	for b in player_buildings:
		if b.grid_pos == target_cell and b.is_alive:
			log_message.emit("Cell occupied at (%d,%d)" % [target_cell.x, target_cell.y])
			return false
	# 条件4: 強制突撃前（呼出元でチェック済み）
	return true

func _create_building_from_card(card: Dictionary, target_cell: Vector2i) -> EconBuilding:
	# カードから建物を生成する
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
		"LIBRARY": EconBuilding.BuildingType.TRADE_POST,  # v0.1 仮マッピング
		"MARKET": EconBuilding.BuildingType.TRADE_POST,   # v0.1 仮マッピング
		"HOUSE": EconBuilding.BuildingType.HOUSE,
		"PLAZA": EconBuilding.BuildingType.PLAZA,
		"WOOD_EXTRACTOR": EconBuilding.BuildingType.SAWMILL,
		"STONE_EXTRACTOR": EconBuilding.BuildingType.MINE,
		"SULFUR_EXTRACTOR": EconBuilding.BuildingType.MINE,
		"WHEAT_EXTRACTOR": EconBuilding.BuildingType.VILLAGE,
		"IRON_EXTRACTOR": EconBuilding.BuildingType.MINE,
		"COTTON_EXTRACTOR": EconBuilding.BuildingType.VILLAGE,
	}
	if not btype_map.has(btype_str):
		print("[EconBattle] _create_building_from_card: unknown building_type '%s'" % btype_str)
		return null
	var btype: int = btype_map[btype_str]
	var b := EconBuilding.new()
	b.setup(btype, target_cell, true)
	b.position = grid.hex_to_pixel(target_cell.x, target_cell.y)
	# HP をカードから設定
	var hp_val: float = float(card.get("hp", 100))
	b.hp = hp_val
	b.max_hp = hp_val
	b.building_destroyed.connect(func(building: Node):
		_on_building_destroyed(building)
		# 建物破壊時の人口更新（§8.5）
		if economy != null:
			var pop_req: int = card.get("population_required", 0)
			economy.population_used -= pop_req
			var pop_supply: int = card.get("population_supply", 0)
			if pop_supply > 0:
				# HOUSE破壊時は calculate_population_cap() で再計算する（§2.7.1 Lv別効果対応）
				economy.population_cap = economy.calculate_population_cap()
				print("[EconBattle] HOUSE destroyed: population_cap recalculated -> ", economy.population_cap)
				_resolve_population_overflow()
	)
	return b

func _resolve_population_overflow() -> void:
	# §8.5.1 住居破壊時の建物停止アルゴリズム
	if economy == null:
		return
	while economy.population_used > economy.population_cap:
		var active_buildings: Array = player_buildings.filter(func(b): return b.is_alive and b.is_built and not b.has_meta("stopped"))
		if active_buildings.is_empty():
			break
		# 必要人口の大きい順→建設順（LIFO）でソート
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
	# §4.6.1 / §8.2 早期突撃のエントリポイント（unitize_military_powerはDeckManager経由で実行）
	if deck_manager != null:
		deck_manager.trigger_force_charge()
	log_message.emit("Early charge triggered!")

func unitize_military_power() -> int:
	# §4.7.3 / §8.2 兵力→ユニット変換（突撃時のみ呼出・旗倒し単独では呼ばない）
	if economy == null:
		return 0
	var unit_count: int = int(floor(economy.military_power))
	economy.military_power -= float(unit_count)  # 小数部を残す
	if unit_count <= 0:
		return 0
	_spawn_units_from_barracks(unit_count)
	log_message.emit("Unitized military power: %d units spawned" % unit_count)
	print("[EconBattle] unitize_military_power: %d units from %.2f power" % [unit_count, economy.military_power + float(unit_count)])
	return unit_count

func _spawn_units_from_barracks(unit_count: int) -> void:
	# §4.7.3 兵舎セルから均等分散出現
	var barracks_cells: Array = []
	for b in player_buildings:
		if b.building_type == EconBuilding.BuildingType.BARRACKS and b.is_alive and b.is_built:
			barracks_cells.append(b.grid_pos)
	if barracks_cells.size() == 0:
		# 兵舎なし → BASE位置からスポーン
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
			spawn_player_unit(cell.x, cell.y, 0, true)  # 突撃モードで出現
	print("[EconBattle] _spawn_units_from_barracks: %d units from %d barracks" % [unit_count, barracks_cells.size()])

func _accumulate_barracks_power(delta: float) -> void:
	# §4.7.2 / §8.2 兵舎の兵力蓄積（EconBattle.update内で呼出）
	if economy == null:
		return
	var active_count: int = 0
	for b in player_buildings:
		if b.building_type == EconBuilding.BuildingType.BARRACKS and b.is_alive and b.is_built:
			active_count += 1
	if active_count > 0:
		economy.accumulate_military_power(delta, active_count)

func update(delta: float) -> void:
	if not is_running or _game_over:
		return
	# 建設キューは廃止。ビルダーが現地に移動してbuild_progressを加算する
	# ドローマネージャー更新（§8.2）
	if deck_manager != null:
		deck_manager.update(delta)
		deck_manager.try_resolve_pending_draws()
	# 兵舎の兵力蓄積（v0.2 §4.7.2）
	_accumulate_barracks_power(delta)
	# 強制突撃ゲージ満タン時の自動ユニット化（§9.1 ターン10）
	if deck_manager != null and deck_manager.force_charge_triggered and economy != null:
		if floor(economy.military_power) > 0.0:
			pass  # unitize_military_power は trigger_force_charge 経由で呼ばれる
	# 経済更新（小麦消費）
	var total_units: int = player_units.size()
	economy.update(delta, total_units)
	# ハーベスター更新
	var all_movable: Array = player_units + player_harvesters + enemy_units
	var alive_harvester_count: int = player_harvesters.filter(func(h): return h.is_alive).size()
	for h in player_harvesters:
		if h.is_alive:
			h.update(delta, grid, all_movable, enemy_units, player_buildings, alive_harvester_count)
	# 建物更新（プレイヤー側のみ）
	for b in player_buildings:
		if b.is_alive:
			b.update(delta, economy, player_buildings, grid)
	# AI更新
	if ai != null:
		ai.update(delta)
	# 戦闘ユニット更新
	var all_units: Array = player_units + enemy_units
	for u in player_units:
		if u.is_alive:
			var unit_rally := _get_unit_rally_pos(u)
			u.update(delta, enemy_units, enemy_buildings, enemy_harvesters, grid, all_units, economy, unit_rally)
	for u in enemy_units:
		if u.is_alive:
			u.update(delta, player_units, player_buildings, player_harvesters, grid, all_units, ai.economy if ai != null else null)
	# 重なりカウント更新
	_update_stack_counts()
	# 死亡処理
	_remove_dead()
	# 勝敗判定
	_check_victory()

func _remove_dead() -> void:
	player_units = player_units.filter(func(u): return u.is_alive)
	player_harvesters = player_harvesters.filter(func(h): return h.is_alive)
	enemy_units = enemy_units.filter(func(u): return u.is_alive)
	enemy_harvesters = enemy_harvesters.filter(func(h): return h.is_alive)
	# 死亡後にharvester_indexを再採番
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
	pass  # ビルダー方式に移行済み。ビルダーが自動的に未建設建物を担当する
func spawn_enemy_unit(utype: int, pos: Vector2i) -> void:
	var unit := EconUnit.create(utype, EconUnit.Side.ENEMY, pos.x, pos.y)
	unit.position = grid.hex_to_pixel(pos.x, pos.y)
	unit.is_idle = true  # 敵ユニットも初期はアイドリング
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

# 融合ランク再計算（建設完了・死亡時に呼び出し）
# 要件定義書 req_econ_equipment_shop_mvp.md § 4.2 より
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
		# BFS: 同種かつ hex_distance==1 で連結
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

# ユニット生成時の装備屋バフ適用
# 要件定義書 req_econ_equipment_shop_mvp.md § 4.3 より
func _apply_equipment_buffs(unit: EconUnit, source_building_pos: Vector2i) -> void:
	var equip_types: Array = [
		EconBuilding.BuildingType.EQUIPMENT_SHOP,
	]
	# 隣接装備屋のうち最大 fusion_rank を選定（二重適用回避）
	var best: EconBuilding = null
	for b in player_buildings:
		if not b.is_alive or not b.is_built: continue
		if grid.hex_distance(source_building_pos, b.grid_pos) != 1: continue
		if not (b.building_type in equip_types): continue
		if best == null or b.fusion_rank > best.fusion_rank:
			best = b
	# 適用（疎結合: メソッド経由）
	if best != null:
		unit.apply_equipment_buff(int(unit.unit_type), best.fusion_rank)

# ハーベスター harvested シグナル受信時のルーティング
# 要件定義書 req_econ_unit_production_harvester.md § 2.3 より
func _on_harvested(rtype: int) -> void:
	_route_harvested_resource(rtype)

# ユニット生成時の装備屋バフ適用
# 要件定義書 req_econ_equipment_shop_mvp.md § 3.1 より
func _on_unit_produced(pos: Vector2i, unit_type: int) -> void:
	# unit_type: 0=突, 1=守, 2=崩, -1=harvester（ハーベスター生成時は処理しない）
	if unit_type < 0:
		return
	if not player_units.size() > 0:
		return
	var unit = player_units[-1]
	_apply_equipment_buffs(unit, pos)

func _on_building_constructed(building: EconBuilding) -> void:
	# 装備屋建設完了時に融合ランク再計算（要件定義書 req_econ_equipment_shop_mvp.md § 4.4）
	if building.building_type == EconBuilding.BuildingType.EQUIPMENT_SHOP:
		_recalc_fusion_clusters()

func _on_building_destroyed(building: EconBuilding) -> void:
	# 装備屋死亡時に融合ランク再計算（要件定義書 req_econ_equipment_shop_mvp.md § 4.4）
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
		EconGrid.ResourceType.SULFUR:
			btype = EconBuilding.BuildingType.WORKSHOP
			key = "sulfur"
		_:
			# WHEAT / IRON / COTTON 等は既存通り economy に直接追加
			economy.add_resource(rtype, 1)
			return
	# 該当タイプの建物のうち、在庫に空きがある最寄りを選定
	var best: EconBuilding = null
	var best_priority: int = 0
	for b in player_buildings:
		if not b.is_alive or not b.is_built: continue
		if b.building_type != btype: continue
		if b.stockpile.get(key, 0) >= EconBuilding.STOCKPILE_CAP: continue
		# 集中建設モードの優先度を流用 + 在庫が少ない順を優先
		var priority: int = b.build_priority * 100 + (EconBuilding.STOCKPILE_CAP - b.stockpile.get(key, 0))
		if best == null or priority > best_priority:
			best = b
			best_priority = priority
	if best != null:
		if not best.add_stock(key, 1):
			# 満杯の場合のフォールバック
			economy.add_resource(rtype, 1)
	else:
		# 全建物満杯 or 該当建物なし → 既存通り economy にフォールバック
		economy.add_resource(rtype, 1)
