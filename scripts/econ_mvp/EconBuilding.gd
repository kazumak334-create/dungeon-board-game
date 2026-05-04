class_name EconBuilding
extends Node2D

enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE, EQUIPMENT_SHOP, TRADE_POST, WALL, PLAZA, HOUSE, EXCHANGE, LIBRARY, LIBRARY_ADV, MUSEUM, ART_GALLERY, SMITHY, WATCHTOWER, DINER, MILL }

var building_type: BuildingType
var grid_pos: Vector2i
var is_alive: bool = true
var is_built: bool = false
var is_operating: bool = true
var required_operation_labor: int = 0
var hp: float = 100.0
var max_hp: float = 100.0
var is_player_side: bool = true
var connected_flag_id: int = -1   # -1 = 接続なし

static var BUILD_COSTS: Dictionary = {
	0: {"wood": 8},     # BARRACKS
	1: {"stone": 10},    # FORTRESS
	2: {"resin": 8},   # WORKSHOP
	3: {"wood": 4, "stone": 3, "wheat": 2},     # VILLAGE
	4: {},              # BASE（建設不可）
	5: {"wood": 8, "stone": 3},   # SAWMILL
	6: {"stone": 10, "resin": 4}, # MINE
	7: {"wood": 5, "resin": 3},   # EQUIPMENT_SHOP
	8: {"wood": 5, "stone": 5},  # TRADE_POST
	9: {},                         # WALL
	10: {"wood": 4, "stone": 2},   # PLAZA（§2.7.2）
	11: {"wood": 3},               # HOUSE（§2.7.2）
	12: {"wood": 4, "stone": 2},   # EXCHANGE（交換所）
	13: {},                         # LIBRARY（書庫・スタブ）
	14: {},                         # LIBRARY_ADV（図書館・スタブ）
	15: {},                         # MUSEUM（博物館・スタブ）
	16: {},                         # ART_GALLERY（美術館・スタブ）
	17: {"wood": 4, "stone": 4, "resin": 2},  # SMITHY（鍛冶屋）
	18: {"wood": 6, "stone": 6, "resin": 2},  # WATCHTOWER（防衛拠点）
	19: {"wood": 4, "stone": 2},               # DINER（食堂）
	20: {"wood": 3, "stone": 2},               # MILL（製粉所）
}

static var BUILD_HP: Dictionary = {
	0: 100.0,   # BARRACKS
	1: 200.0,   # FORTRESS
	2: 100.0,   # WORKSHOP
	3: 80.0,    # VILLAGE
	4: 500.0,   # BASE
	5: 80.0,    # SAWMILL
	6: 100.0,   # MINE
	7: 80.0,    # EQUIPMENT_SHOP
	8: 80.0,   # TRADE_POST
	9: 100.0,  # WALL
	10: 60.0,  # PLAZA（§2.7.2）
	11: 60.0,  # HOUSE（§2.7.2）
	12: 80.0,  # EXCHANGE（交換所）
	13: 60.0,  # LIBRARY（書庫・スタブ）
	14: 60.0,  # LIBRARY_ADV（図書館・スタブ）
	15: 60.0,  # MUSEUM（博物館・スタブ）
	16: 60.0,  # ART_GALLERY（美術館・スタブ）
	17: 80.0,  # SMITHY（鍛冶屋）
	18: 100.0,  # WATCHTOWER
	19: 60.0,   # DINER（食堂）
	20: 60.0,   # MILL（製粉所）
}

# ベース生産間隔: 20秒（隣接ボーナスなしは実質機能しない重さ）
# 要件定義書 req_econ_building_variants.md § 1 より
const BARRACKS_PRODUCE_INTERVAL := 20.0
const BARRACKS_PRODUCE_COST := 3    # wood
const FORTRESS_PRODUCE_INTERVAL := 20.0
const FORTRESS_PRODUCE_COST := 3    # stone
const WORKSHOP_PRODUCE_INTERVAL := 20.0
const WORKSHOP_PRODUCE_COST := 3    # resin
const VILLAGE_INTERVAL := 2.5   # 2.5秒ごとにパネルリソース獲得（REQUIREMENTS_CARD_EFFECTS §1.1）
const VILLAGE_HARVESTER_INTERVAL := 30.0  # 廃止済み（参照のみ残存）

# SAWMILL/MINE タイマー駆動定数（要件定義書 REQUIREMENTS_CARD_EFFECTS.md §1.1）
const SAWMILL_PRODUCE_INTERVAL := 2.5   # 2.5秒ごとにパネル木材数を獲得
const MINE_PRODUCE_INTERVAL := 2.5      # 2.5秒ごとにパネル石材数を獲得

# 徴兵兵舎用定数（バリアントシステム実装時に接続）
# 要件定義書 req_econ_building_variants.md § 6 より
const BARRACKS_CONSCRIPT_INTERVAL := 5.0   # 農村隣接時の徴兵兵舎間隔（ボーナス適用後）
const BARRACKS_CONSCRIPT_WHEAT_COST := 2   # 徴兵兵舎のWheat消費

# 鍛冶屋：隣接兵舎DPS補正（要件定義書 req_econ_smithy_building.md §3）
const SMITHY_DPS_MULT_LV1 := 1.10  # +10%
const SMITHY_DPS_MULT_LV2 := 1.15  # +15%（次期MVP）
const SMITHY_DPS_MULT_LV3 := 1.20  # +20%（次期MVP）

# 防衛拠点：防衛兵力統括・防壁回復（要件定義書 req_econ_watchtower_building.md §4.5）
const WATCHTOWER_RANGE_LV1 := 2  # 防衛範囲（hex距離）Lv1
const WATCHTOWER_REPAIR_INTERVAL := 5.0  # 防壁回復tick（秒）
const WATCHTOWER_REPAIR_AMOUNT_LV2 := 10 # Lv2 防壁回復量
const WATCHTOWER_REPAIR_AMOUNT_LV3 := 15 # Lv3 防壁回復量

# 食堂（DINER）定数（要件定義書 req_econ_food_system_sprint2.md §1）
const DINER_INTERVAL := 5.0
const DINER_WHEAT_COST := 5    # 小麦5消費（REQUIREMENTS_CARD_EFFECTS §1.1）
const DINER_FOOD_GAIN := 10    # 食料値+10（REQUIREMENTS_CARD_EFFECTS §1.1）

# 製粉所（MILL）定数（要件定義書 req_econ_food_system_sprint2.md §2）
const MILL_INTERVAL := 5.0
const MILL_WHEAT_COST := 1
const MILL_WHEAT_GAIN := 2
const MILL_WHEAT_GAIN_BOOST := 3  # 小麦値3以上パネル上（TODO: パネルリソース実装時に有効化）
const EFFECTIVE_INTERVAL_MIN := 2.0
const EFFECTIVE_INTERVAL_MAX := 15.0

# ビルダーシステム
static var REQUIRED_CONSTRUCTION: Dictionary = {
	0: 5.0,   # BARRACKS
	1: 8.0,   # FORTRESS
	2: 8.0,   # WORKSHOP
	3: 5.0,   # VILLAGE
	4: 0.0,   # BASE（建設不可）
	5: 5.0,   # SAWMILL
	6: 8.0,   # MINE
	7: 6.0,   # EQUIPMENT_SHOP
	8: 5.0,   # TRADE_POST
	9: 0.0,   # WALL
	10: 5.0,  # PLAZA（§2.7.2）
	11: 3.0,  # HOUSE（§2.7.2）
	12: 5.0,   # EXCHANGE（交換所）
	13: 5.0,   # LIBRARY（書庫・スタブ）
	14: 5.0,   # LIBRARY_ADV（図書館・スタブ）
	15: 5.0,   # MUSEUM（博物館・スタブ）
	16: 5.0,   # ART_GALLERY（美術館・スタブ）
	17: 6.0,   # SMITHY（鍛冶屋）
	18: 8.0,    # WATCHTOWER（防衛拠点）
	19: 5.0,    # DINER（食堂）
	20: 5.0,    # MILL（製粉所）
}

var build_progress: float = 0.0
var build_priority: int = 0  # 集中建設モードでの優先度（大きいほど優先）

# ユニット生産ハーベスター化（要件定義書 req_econ_unit_production_harvester.md）
var stockpile: Dictionary = {"wood": 0, "stone": 0, "resin": 0}
const STOCKPILE_CAP := 6

# 装備屋融合ランク（要件定義書 req_econ_equipment_shop_mvp.md）
var fusion_rank: int = 1            # 1=Lv1, 2=Lv2, 3=Lv3
var fusion_cluster_id: int = -1     # 同種クラスタの ID（-1=未計算）

var _produce_timer: float = 0.0
var _harvester_timer: float = 0.0
var _diner_timer: float = 0.0
var _mill_timer: float = 0.0
var _produce_last_interval: float = 0.0
var _harvester_last_interval: float = 0.0
var _diner_last_interval: float = 0.0
var _mill_last_interval: float = 0.0
var _resource_counter: int = 0  # TRADE_POST: 累計消費カウンター（10到達で1ドロー）
var _resource_ready: bool = true  # 生産コストが払えるか（!表示用）
var _construction_ready: bool = true  # 建設コストが払えるか（建設中!表示用）
var _placement_bonus_active: bool = false  # 配置ボーナス有効フラグ
var smithy_level: int = 1   # Lv1〜Lv3（強化システム連動・MVPでは 1 固定）
var _smithy_active: bool = false   # 必要稼働人口1割当時のみ true
var _watchtower_repair_timer: float = 0.0  # 防壁回復tick用タイマー
var watchtower_level: int = 1              # Lv1〜Lv3（強化システム連動・MVPでは 1 固定）

signal unit_produced(pos: Vector2i, unit_type: int)  # unit_type: 0=突,1=守,2=崩,-1=harvester
signal base_destroyed(is_player: bool)
signal building_destroyed(building: Node)  # 装備屋破壊時の融合ランク再計算用

func setup(btype: BuildingType, pos: Vector2i, player_side: bool) -> void:
	building_type = btype
	grid_pos = pos
	is_player_side = player_side
	max_hp = BUILD_HP.get(int(btype), 100.0)
	hp = max_hp
	# BASEは建設不可の初期配置なので建設済み扱い
	is_built = (btype == BuildingType.BASE)
	is_operating = true

func set_operating(value: bool) -> void:
	if is_operating == value:
		return
	is_operating = value
	queue_redraw()

# stockpile への供給（疎結合・メソッド経由）
# 要件定義書 req_econ_unit_production_harvester.md § 6.1 より
func add_stock(key: String, amount: int) -> bool:
	var current: int = stockpile.get(key, 0)
	if current >= STOCKPILE_CAP:
		return false
	stockpile[key] = mini(current + amount, STOCKPILE_CAP)
	return true

# 配置ボーナス条件チェック
# 条件: BARRACKS/WORKSHOP → 農村隣接、FORTRESS → 農村または鉱山隣接
# 要件定義書 req_econ_building_variants.md § 2 より
func check_placement_bonus(buildings: Array, grid: EconGrid) -> void:
	_placement_bonus_active = false
	for b in buildings:
		if not b.is_alive or not b.is_built:
			continue
		var dist: int = grid.hex_distance(grid_pos, b.grid_pos)
		if dist != 1:
			continue
		match building_type:
			BuildingType.BARRACKS, BuildingType.WORKSHOP:
				if b.building_type == BuildingType.VILLAGE:
					_placement_bonus_active = true
					return
			BuildingType.FORTRESS:
				if b.building_type == BuildingType.VILLAGE or b.building_type == BuildingType.MINE:
					_placement_bonus_active = true
					return

func update(delta: float, economy: EconEconomy, buildings: Array = [], grid: EconGrid = null) -> void:
	if not is_alive:
		return
	if not is_built:
		return
	if not is_operating:
		_resource_ready = true
		return
	# 配置ボーナスチェック（引数が揃っている場合のみ）
	if buildings.size() > 0 and grid != null:
		check_placement_bonus(buildings, grid)
	match building_type:
		BuildingType.BARRACKS:
			_update_barracks(delta, economy)
		BuildingType.FORTRESS:
			_update_fortress(delta, economy)
		BuildingType.WORKSHOP:
			_update_workshop(delta, economy)
		BuildingType.VILLAGE:
			_update_village(delta, economy, grid)
		BuildingType.BASE:
			pass  # BASEは何も生産しない（ビルダー廃止）
		BuildingType.SAWMILL:
			_update_sawmill(delta, economy, grid)  # 2.5秒周期・パネル参照（REQUIREMENTS_CARD_EFFECTS §1.1）
		BuildingType.MINE:
			_update_mine(delta, economy, grid)     # 2.5秒周期・パネル参照（REQUIREMENTS_CARD_EFFECTS §1.1）
		BuildingType.EQUIPMENT_SHOP:
			pass  # 装備屋はパッシブバフのみ（要件定義書 req_econ_equipment_shop_mvp.md）
		BuildingType.TRADE_POST:
			pass
		BuildingType.WALL:
			pass
		BuildingType.PLAZA:
			pass  # 幸福度供給はEconEconomy.update() Step 4で処理（§2.4.3）
		BuildingType.HOUSE:
			pass  # パッシブ：人口上限供給はEconEconomy側で処理（§2.4.2）
		BuildingType.EXCHANGE, BuildingType.LIBRARY, BuildingType.LIBRARY_ADV, BuildingType.MUSEUM, BuildingType.ART_GALLERY:
			pass  # 次期MVPで効果設計
		BuildingType.SMITHY:
			_update_smithy(delta, economy)
		BuildingType.WATCHTOWER:
			_update_watchtower(delta, economy)
		BuildingType.DINER:
			_update_diner(delta, economy, grid)
		BuildingType.MILL:
			_update_mill(delta, economy, grid)

func _get_effective_interval(base_interval: float, economy: EconEconomy) -> float:
	var efficiency: float = economy.get_building_efficiency_modifier() if economy != null else 0.0
	var denominator: float = max(0.01, 1.0 + efficiency)
	return clampf(base_interval / denominator, EFFECTIVE_INTERVAL_MIN, EFFECTIVE_INTERVAL_MAX)

func _remap_timer_to_interval(timer: float, last_interval: float, new_interval: float) -> float:
	if last_interval <= 0.0 or abs(last_interval - new_interval) <= 0.001:
		return timer
	var progress: float = clampf(timer / last_interval, 0.0, 1.0)
	return progress * new_interval

func _update_barracks(delta: float, economy: EconEconomy) -> void:
	# 配置ボーナス適用時: 間隔・コスト半減
	# 要件定義書 req_econ_building_variants.md § 3 より
	var base_interval := 5.0 if _placement_bonus_active else BARRACKS_PRODUCE_INTERVAL
	var interval := _get_effective_interval(base_interval, economy)
	_produce_timer = _remap_timer_to_interval(_produce_timer, _produce_last_interval, interval)
	_produce_last_interval = interval
	var cost := ceili(BARRACKS_PRODUCE_COST / 2.0) if _placement_bonus_active else BARRACKS_PRODUCE_COST
	# ハーベスター化：自分のstockpileを参照（要件定義書 req_econ_unit_production_harvester.md）
	_resource_ready = (stockpile.get("wood", 0) >= cost)
	if not _resource_ready:
		return
	_produce_timer += delta
	if _produce_timer >= interval:
		stockpile["wood"] -= cost
		_produce_timer -= interval
		unit_produced.emit(grid_pos, 0)

func _update_fortress(delta: float, economy: EconEconomy) -> void:
	var interval := 5.0 if _placement_bonus_active else FORTRESS_PRODUCE_INTERVAL
	var cost := ceili(FORTRESS_PRODUCE_COST / 2.0) if _placement_bonus_active else FORTRESS_PRODUCE_COST
	# ハーベスター化：自分のstockpileを参照（要件定義書 req_econ_unit_production_harvester.md）
	_resource_ready = (stockpile.get("stone", 0) >= cost)
	_produce_timer += delta
	if _produce_timer >= interval:
		if _resource_ready:
			stockpile["stone"] -= cost
			_produce_timer = 0.0
			unit_produced.emit(grid_pos, 1)

func _update_workshop(delta: float, economy: EconEconomy) -> void:
	var base_interval := 5.0 if _placement_bonus_active else WORKSHOP_PRODUCE_INTERVAL
	var interval := _get_effective_interval(base_interval, economy)
	_produce_timer = _remap_timer_to_interval(_produce_timer, _produce_last_interval, interval)
	_produce_last_interval = interval
	var cost := ceili(WORKSHOP_PRODUCE_COST / 2.0) if _placement_bonus_active else WORKSHOP_PRODUCE_COST
	# ハーベスター化：自分のstockpileを参照（要件定義書 req_econ_unit_production_harvester.md）
	_resource_ready = (stockpile.get("resin", 0) >= cost)
	if not _resource_ready:
		return
	_produce_timer += delta
	if _produce_timer >= interval:
		stockpile["resin"] -= cost
		_produce_timer -= interval
		unit_produced.emit(grid_pos, 2)

func _update_village(delta: float, economy: EconEconomy, grid: EconGrid = null) -> void:
	# 農場: 2.5秒ごとにパネルの麦数+綿数を獲得（REQUIREMENTS_CARD_EFFECTS §1.1）
	var interval := _get_effective_interval(VILLAGE_INTERVAL, economy)
	_produce_timer = _remap_timer_to_interval(_produce_timer, _produce_last_interval, interval)
	_produce_last_interval = interval
	_produce_timer += delta
	if _produce_timer >= interval:
		_produce_timer -= interval
		if grid != null:
			var panel: Dictionary = grid.get_panel_at(grid_pos)
			var panel_resources: Dictionary = panel.get("resources", {})
			var wheat_gain: int = int(panel_resources.get("wheat", 0))
			var cotton_gain: int = int(panel_resources.get("cotton", 0))
			if wheat_gain > 0:
				economy.add_wheat(wheat_gain)
			if cotton_gain > 0:
				economy.add_resource(EconGrid.ResourceType.COTTON, cotton_gain)
			print("[EconBuilding] VILLAGE: 麦+%d 綿+%d (pos=%s)" % [wheat_gain, cotton_gain, str(grid_pos)])

func _update_sawmill(delta: float, economy: EconEconomy, grid: EconGrid = null) -> void:
	# 製材所: 2.5秒周期でパネルの木材数を獲得（REQUIREMENTS_CARD_EFFECTS §1.1）
	var interval := _get_effective_interval(SAWMILL_PRODUCE_INTERVAL, economy)
	_produce_timer = _remap_timer_to_interval(_produce_timer, _produce_last_interval, interval)
	_produce_last_interval = interval
	_produce_timer += delta
	if _produce_timer >= interval:
		_produce_timer -= interval
		if grid != null:
			var panel: Dictionary = grid.get_panel_at(grid_pos)
			var panel_resources: Dictionary = panel.get("resources", {})
			var gain: int = int(panel_resources.get("wood", 0))
			if gain > 0:
				economy.add_resource(EconGrid.ResourceType.WOOD, gain)
			print("[EconBuilding] SAWMILL 木材+%d (pos=%s)" % [gain, str(grid_pos)])

func _update_mine(delta: float, economy: EconEconomy, grid: EconGrid = null) -> void:
	# 採石場: 2.5秒周期でパネルの石材数を獲得（REQUIREMENTS_CARD_EFFECTS §1.1）
	var interval := _get_effective_interval(MINE_PRODUCE_INTERVAL, economy)
	_produce_timer = _remap_timer_to_interval(_produce_timer, _produce_last_interval, interval)
	_produce_last_interval = interval
	_produce_timer += delta
	if _produce_timer >= interval:
		_produce_timer -= interval
		if grid != null:
			var panel: Dictionary = grid.get_panel_at(grid_pos)
			var panel_resources: Dictionary = panel.get("resources", {})
			var gain: int = int(panel_resources.get("stone", 0))
			if gain > 0:
				economy.add_resource(EconGrid.ResourceType.STONE, gain)
			print("[EconBuilding] MINE 石材+%d (pos=%s)" % [gain, str(grid_pos)])

func _update_smithy(delta: float, economy: EconEconomy) -> void:
	# 鍛冶屋: 稼働人口1を満たせば有効（パッシブ的に出撃時DPS補正を提供）
	# 実際のDPS適用は EconBattle でユニット生成時に行う（疎結合）
	_smithy_active = true
	_resource_ready = true

func get_smithy_dps_mult() -> float:
	# 鍛冶屋として、現在の Lv に応じた DPS 倍率を返す（非稼働時は 1.0）
	# 要件 req_econ_smithy_building.md §4.10
	if building_type != BuildingType.SMITHY:
		return 1.0
	if not _smithy_active:
		return 1.0
	match smithy_level:
		2: return SMITHY_DPS_MULT_LV2
		3: return SMITHY_DPS_MULT_LV3
		_: return SMITHY_DPS_MULT_LV1

func _update_watchtower(delta: float, economy: EconEconomy) -> void:
	# 防衛拠点: 本MVPではスタブ（Sprint 5で防衛出撃・防壁回復を実装）
	# TODO(Sprint 5): 範囲内兵舎から兵力を引き出して防衛出撃
	# TODO(Sprint 5): 範囲内防壁HP回復（+10HP/5秒）
	_resource_ready = true
	_watchtower_repair_timer += delta
	if _watchtower_repair_timer >= WATCHTOWER_REPAIR_INTERVAL:
		_watchtower_repair_timer = 0.0
		# TODO(Sprint 5): watchtower_level >= 2 のとき範囲内防壁を回復
		# TODO(Sprint 5): 範囲内に敵がいるとき範囲内兵舎から防衛兵力を引き抜き出撃
		pass

func _update_diner(delta: float, economy: EconEconomy, grid: EconGrid = null) -> void:
	# 食堂：5秒ごとに小麦5消費→食料値+10（REQUIREMENTS_CARD_EFFECTS §1.1・§3.4）
	var interval := _get_effective_interval(DINER_INTERVAL, economy)
	_diner_timer = _remap_timer_to_interval(_diner_timer, _diner_last_interval, interval)
	_diner_last_interval = interval
	if economy.wheat < DINER_WHEAT_COST:
		_resource_ready = false
		return
	_resource_ready = true
	_diner_timer += delta
	if _diner_timer < interval:
		return
	_diner_timer -= interval

	# consume_resource 経由で小麦5消費（REQUIREMENTS_CARD_EFFECTS §3.4）
	var consumed: bool = economy.consume_resource("wheat", DINER_WHEAT_COST)
	if not consumed:
		_resource_ready = false
		return
	economy.add_food(DINER_FOOD_GAIN)
	print("[EconBuilding] DINER: 小麦-%d 食料値+%d (food_value=%d)" % [
		DINER_WHEAT_COST,
		DINER_FOOD_GAIN,
		economy.food_value,
	])

func _update_mill(delta: float, economy: EconEconomy, grid: EconGrid = null) -> void:
	# 製粉所：5秒ごとに小麦1消費→小麦+2（要件定義書 req_econ_food_system_sprint2.md §2）
	var interval := _get_effective_interval(MILL_INTERVAL, economy)
	_mill_timer = _remap_timer_to_interval(_mill_timer, _mill_last_interval, interval)
	_mill_last_interval = interval
	if economy.wheat < MILL_WHEAT_COST:
		_resource_ready = false
		return
	_resource_ready = true
	_mill_timer += delta
	if _mill_timer < interval:
		return
	_mill_timer -= interval

	# 小麦消費
	economy.wheat -= MILL_WHEAT_COST

	var has_high_yield_wheat: bool = grid != null and grid.get_panel_wheat_value(grid_pos) >= 3
	var gain: int = MILL_WHEAT_GAIN_BOOST if has_high_yield_wheat else MILL_WHEAT_GAIN
	economy.wheat += gain
	economy.resources["wheat"] = economy.wheat
	print("[EconBuilding] MILL: 小麦-1 小麦+%d (wheat=%d)%s" % [
		gain,
		economy.wheat,
		" [high-yield panel bonus]" if has_high_yield_wheat else "",
	])

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		is_alive = false
		if building_type == BuildingType.BASE:
			base_destroyed.emit(is_player_side)
		# 装備屋破壊時に融合ランク再計算を通知（要件定義書 req_econ_equipment_shop_mvp.md § 3.2）
		building_destroyed.emit(self)
	queue_redraw()

func get_build_progress_ratio() -> float:
	var required: float = float(REQUIRED_CONSTRUCTION.get(int(building_type), 1.0))
	if required <= 0.0:
		return 1.0
	return clampf(build_progress / required, 0.0, 1.0)

func get_timer_progress() -> float:
	if not is_built:
		return get_build_progress_ratio()
	match building_type:
		BuildingType.DINER:
			return _timer_progress_ratio(_diner_timer, _diner_last_interval)
		BuildingType.MILL:
			return _timer_progress_ratio(_mill_timer, _mill_last_interval)
		BuildingType.VILLAGE:
			return _timer_progress_ratio(_produce_timer, _produce_last_interval)
		BuildingType.BARRACKS, BuildingType.FORTRESS, BuildingType.WORKSHOP:
			return _timer_progress_ratio(_produce_timer, _produce_last_interval)
		BuildingType.SAWMILL, BuildingType.MINE:
			return _timer_progress_ratio(_produce_timer, _produce_last_interval)
		_:
			return 0.0

func _timer_progress_ratio(timer: float, interval: float) -> float:
	if interval <= 0.0:
		return 0.0
	return clampf(timer / interval, 0.0, 1.0)

func _draw_bottom_progress_mask(progress: float, color: Color) -> void:
	if progress <= 0.0:
		return
	var clamped := clampf(progress, 0.0, 1.0)
	var height := 36.0 * clamped
	draw_rect(Rect2(Vector2(-18.0, 18.0 - height), Vector2(36.0, height)), color)

func _draw() -> void:
	if not is_alive:
		return
	var alpha := 0.4 if not is_built else 1.0
	var color: Color
	match building_type:
		BuildingType.BARRACKS: color = Color.PERU
		BuildingType.FORTRESS: color = Color.SLATE_GRAY
		BuildingType.WORKSHOP: color = Color.GOLDENROD
		BuildingType.VILLAGE:  color = Color.FOREST_GREEN
		BuildingType.BASE:     color = Color.ROYAL_BLUE if is_player_side else Color.FIREBRICK
		BuildingType.SAWMILL:  color = Color.SADDLE_BROWN
		BuildingType.MINE:     color = Color.DIM_GRAY
		BuildingType.EQUIPMENT_SHOP: color = Color.MEDIUM_PURPLE
		BuildingType.TRADE_POST: color = Color(0.478, 0.310, 0.549)  # #7A4F8C（紫）
		BuildingType.WALL: color = Color.LIGHT_GRAY
		BuildingType.PLAZA: color = Color.CORNFLOWER_BLUE
		BuildingType.HOUSE: color = Color.SANDY_BROWN
		BuildingType.EXCHANGE: color = Color.GOLD  # 通貨建物・市場との差別化のため金色系
		BuildingType.LIBRARY, BuildingType.LIBRARY_ADV, BuildingType.MUSEUM, BuildingType.ART_GALLERY: color = Color.LIGHT_GRAY  # スタブ
		BuildingType.SMITHY: color = Color.DARK_ORANGE  # 火・鉄を想起する暖色（兵舎=PERU と区別）
		BuildingType.WATCHTOWER: color = Color(0.3, 0.5, 0.8)  # スチールブルー（防衛）
		BuildingType.DINER: color = Color(0.9, 0.6, 0.2)    # オレンジ系（食堂）
		BuildingType.MILL: color = Color(0.7, 0.8, 0.4)     # 黄緑系（製粉所）
	color.a = alpha
	draw_rect(Rect2(Vector2(-18, -18), Vector2(36, 36)), color)
	if is_built:
		_draw_bottom_progress_mask(get_timer_progress(), Color(0.25, 0.9, 0.45, 0.25))
	else:
		# 建設中：底部プログレス + 建設リング描画
		_draw_bottom_progress_mask(get_build_progress_ratio(), Color(0.25, 0.9, 0.45, 0.45))
		_draw_construction_ring(build_progress, true)  # リング描画（進捗状態を反映）
	draw_rect(Rect2(Vector2(-18, -18), Vector2(36, 36)), Color(1.0, 1.0, 1.0, alpha), false, 2.0)
	if is_built:
		var bar_w := 36.0
		var bar_h := 5.0
		var bar_y := -26.0
		var hp_ratio := hp / max_hp if max_hp > 0 else 0.0
		draw_rect(Rect2(Vector2(-bar_w * 0.5, bar_y), Vector2(bar_w, bar_h)), Color.DARK_GRAY)
		draw_rect(Rect2(Vector2(-bar_w * 0.5, bar_y), Vector2(bar_w * hp_ratio, bar_h)), Color.GREEN)
		# リソース不足 → 右上に「!」
		if not _resource_ready:
			draw_circle(Vector2(15, -22), 7.0, Color(0.9, 0.1, 0.1, 0.9))
			draw_string(ThemeDB.fallback_font, Vector2(11, -16), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)
		var dot_color := Color(0.25, 0.9, 0.45, 0.95) if is_operating else Color(0.45, 0.43, 0.40, 0.95)
		draw_circle(Vector2(0, 23), 3.0, dot_color)
	# 建設中かつ建設コスト不足 → 右上に「!」
	if not is_built and not _construction_ready:
		draw_circle(Vector2(15, -22), 7.0, Color(0.9, 0.1, 0.1, 0.9))
		draw_string(ThemeDB.fallback_font, Vector2(11, -16), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)

func set_construction_progress(progress: float) -> void:
	build_progress = clampf(progress, 0.0, 1.0)
	queue_redraw()

func _draw_construction_ring(progress: float, is_active: bool) -> void:
	# 建設進捗リング描画（要件書 § 6.3）
	# 位置: パネル中央上端（12px上）
	# 外径28px / 内径22px / 線幅3px
	# 進捗 0% → 0°、100% → 360°（時計回り）
	if progress < 0.001:
		return
	var center := Vector2(0.0, -12.0)
	var outer_radius := 14.0
	var inner_radius := 11.0
	var ring_color := Color(0.9, 0.7, 0.0, 1.0) if is_active else Color(0.6, 0.6, 0.6, 0.7)  # 金色 or 灰色
	var angle_end := TAU * progress

	# リング背景（薄い円）
	draw_circle(center, outer_radius + 1.5, Color(0.3, 0.3, 0.3, 0.2))

	# 進捗アークを複数の小三角形で描画（draw_arc は存在しないため手動実装）
	var segments: int = maxi(int(progress * 32), 2)
	for i in range(segments):
		var angle1: float = (TAU / 32.0) * float(i)
		var angle2: float = (TAU / 32.0) * float(i + 1)
		angle2 = minf(angle2, angle_end)
		if angle2 <= angle1:
			break

		var p1_outer := center + Vector2(cos(angle1), sin(angle1)) * outer_radius
		var p2_outer := center + Vector2(cos(angle2), sin(angle2)) * outer_radius
		var p1_inner := center + Vector2(cos(angle1), sin(angle1)) * inner_radius
		var p2_inner := center + Vector2(cos(angle2), sin(angle2)) * inner_radius

		draw_colored_polygon([p1_outer, p2_outer, p2_inner, p1_inner], ring_color)

func get_construction_progress_for_drawing() -> float:
	# 建設中の建物の進捗を取得（draw()時点で必要）
	# 注：このメソッドは _process() 内で build_progress が更新されている前提
	return build_progress if not is_built else 0.0

# TRADE_POST: パネル資源消費カウンター加算（REQUIREMENTS_CARD_EFFECTS §3.5）
# EconEconomy.consume_resource() / consume_resources() 呼び出し後に EconBattle が呼ぶ
# amount: 消費量、deck_manager: 10到達時のドロー発動用
func add_trade_post_resource_count(amount: int, deck_manager) -> void:
	if building_type != BuildingType.TRADE_POST:
		return
	if not is_operating:
		return
	_resource_counter += amount
	print("[EconBuilding] TRADE_POST カウンター +%d → %d (pos=%s)" % [amount, _resource_counter, str(grid_pos)])
	while _resource_counter >= 10:
		_resource_counter -= 10
		if deck_manager != null:
			deck_manager.draw_card()
			print("[EconBuilding] TRADE_POST: カウンター10到達 → 1ドロー (pos=%s)" % str(grid_pos))
