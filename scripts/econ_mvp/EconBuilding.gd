class_name EconBuilding
extends Node2D

enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE, EQUIPMENT_SHOP, TRADE_POST, WALL, PLAZA, HOUSE }

var building_type: BuildingType
var grid_pos: Vector2i
var is_alive: bool = true
var is_built: bool = false
var hp: float = 100.0
var max_hp: float = 100.0
var is_player_side: bool = true
var connected_flag_id: int = -1   # -1 = 接続なし

static var BUILD_COSTS: Dictionary = {
	0: {"wood": 8},     # BARRACKS
	1: {"stone": 10},    # FORTRESS
	2: {"sulfur": 8},   # WORKSHOP
	3: {"wood": 4, "stone": 3, "wheat": 2},     # VILLAGE
	4: {},              # BASE（建設不可）
	5: {"wood": 8, "stone": 3},   # SAWMILL
	6: {"stone": 10, "sulfur": 4}, # MINE
	7: {"wood": 5, "sulfur": 3},   # EQUIPMENT_SHOP
	8: {"wood": 5, "stone": 5},  # TRADE_POST
	9: {},                         # WALL
	10: {"wood": 4, "stone": 2},   # PLAZA（§2.7.2）
	11: {"wood": 3},               # HOUSE（§2.7.2）
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
}

# ベース生産間隔: 20秒（隣接ボーナスなしは実質機能しない重さ）
# 要件定義書 req_econ_building_variants.md § 1 より
const BARRACKS_PRODUCE_INTERVAL := 20.0
const BARRACKS_PRODUCE_COST := 3    # wood
const FORTRESS_PRODUCE_INTERVAL := 20.0
const FORTRESS_PRODUCE_COST := 3    # stone
const WORKSHOP_PRODUCE_INTERVAL := 20.0
const WORKSHOP_PRODUCE_COST := 3    # sulfur
const VILLAGE_WHEAT_INTERVAL := 5.0
const VILLAGE_WHEAT_AMOUNT := 2
const VILLAGE_COTTON_INTERVAL := 5.0
const VILLAGE_COTTON_AMOUNT := 1
const VILLAGE_HARVESTER_INTERVAL := 30.0

# 徴兵兵舎用定数（バリアントシステム実装時に接続）
# 要件定義書 req_econ_building_variants.md § 6 より
const BARRACKS_CONSCRIPT_INTERVAL := 5.0   # 農村隣接時の徴兵兵舎間隔（ボーナス適用後）
const BARRACKS_CONSCRIPT_WHEAT_COST := 2   # 徴兵兵舎のWheat消費

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
}

var build_progress: float = 0.0
var build_priority: int = 0  # 集中建設モードでの優先度（大きいほど優先）

# ユニット生産ハーベスター化（要件定義書 req_econ_unit_production_harvester.md）
var stockpile: Dictionary = {"wood": 0, "stone": 0, "sulfur": 0}
const STOCKPILE_CAP := 6

# 装備屋融合ランク（要件定義書 req_econ_equipment_shop_mvp.md）
var fusion_rank: int = 1            # 1=Lv1, 2=Lv2, 3=Lv3
var fusion_cluster_id: int = -1     # 同種クラスタの ID（-1=未計算）

var _produce_timer: float = 0.0
var _harvester_timer: float = 0.0
var _cotton_timer: float = 0.0
var _resource_ready: bool = true  # 生産コストが払えるか（!表示用）
var _construction_ready: bool = true  # 建設コストが払えるか（建設中!表示用）
var _placement_bonus_active: bool = false  # 配置ボーナス有効フラグ

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
			_update_village(delta, economy)
		BuildingType.BASE:
			pass  # BASEは何も生産しない（ビルダー廃止）
		BuildingType.SAWMILL:
			pass  # パッシブ効果のみ（EconHarvester側で処理）
		BuildingType.MINE:
			pass  # パッシブ効果のみ
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

func _update_barracks(delta: float, economy: EconEconomy) -> void:
	# 配置ボーナス適用時: 間隔・コスト半減
	# 要件定義書 req_econ_building_variants.md § 3 より
	var interval := 5.0 if _placement_bonus_active else BARRACKS_PRODUCE_INTERVAL
	var cost := ceili(BARRACKS_PRODUCE_COST / 2.0) if _placement_bonus_active else BARRACKS_PRODUCE_COST
	# ハーベスター化：自分のstockpileを参照（要件定義書 req_econ_unit_production_harvester.md）
	_resource_ready = (stockpile.get("wood", 0) >= cost)
	_produce_timer += delta
	if _produce_timer >= interval:
		if _resource_ready:
			stockpile["wood"] -= cost
			_produce_timer = 0.0
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
	var interval := 5.0 if _placement_bonus_active else WORKSHOP_PRODUCE_INTERVAL
	var cost := ceili(WORKSHOP_PRODUCE_COST / 2.0) if _placement_bonus_active else WORKSHOP_PRODUCE_COST
	# ハーベスター化：自分のstockpileを参照（要件定義書 req_econ_unit_production_harvester.md）
	_resource_ready = (stockpile.get("sulfur", 0) >= cost)
	_produce_timer += delta
	if _produce_timer >= interval:
		if _resource_ready:
			stockpile["sulfur"] -= cost
			_produce_timer = 0.0
			unit_produced.emit(grid_pos, 2)

func _update_village(delta: float, economy: EconEconomy) -> void:
	_produce_timer += delta
	if _produce_timer >= VILLAGE_WHEAT_INTERVAL:
		_produce_timer = 0.0
		economy.add_wheat(VILLAGE_WHEAT_AMOUNT)
	_cotton_timer += delta
	if _cotton_timer >= VILLAGE_COTTON_INTERVAL:
		_cotton_timer = 0.0
		economy.add_resource(EconGrid.ResourceType.COTTON, VILLAGE_COTTON_AMOUNT)
	_harvester_timer += delta
	if _harvester_timer >= VILLAGE_HARVESTER_INTERVAL:
		_harvester_timer = 0.0
		unit_produced.emit(grid_pos, -1)

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
	color.a = alpha
	draw_rect(Rect2(Vector2(-18, -18), Vector2(36, 36)), color)
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
	# 建設中かつ建設コスト不足 → 右上に「!」
	if not is_built and not _construction_ready:
		draw_circle(Vector2(15, -22), 7.0, Color(0.9, 0.1, 0.1, 0.9))
		draw_string(ThemeDB.fallback_font, Vector2(11, -16), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)
