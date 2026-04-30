class_name EconBuilding
extends Node2D

enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE }

var building_type: BuildingType
var grid_pos: Vector2i
var is_alive: bool = true
var is_built: bool = false
var hp: float = 100.0
var max_hp: float = 100.0
var is_player_side: bool = true

static var BUILD_COSTS: Dictionary = {
	0: {"wood": 8},     # BARRACKS
	1: {"stone": 6},    # FORTRESS
	2: {"sulfur": 6},   # WORKSHOP
	3: {"wood": 4, "stone": 3, "wheat": 2},     # VILLAGE
	4: {},              # BASE（建設不可）
}

static var BUILD_HP: Dictionary = {
	0: 100.0,   # BARRACKS
	1: 200.0,   # FORTRESS
	2: 100.0,   # WORKSHOP
	3: 80.0,    # VILLAGE
	4: 500.0,   # BASE
}

const BARRACKS_PRODUCE_INTERVAL := 8.0
const BARRACKS_PRODUCE_COST := 3    # wood
const FORTRESS_PRODUCE_INTERVAL := 10.0
const FORTRESS_PRODUCE_COST := 3    # stone
const WORKSHOP_PRODUCE_INTERVAL := 12.0
const WORKSHOP_PRODUCE_COST := 3    # sulfur
const VILLAGE_WHEAT_INTERVAL := 5.0
const VILLAGE_WHEAT_AMOUNT := 2
const VILLAGE_HARVESTER_INTERVAL := 20.0
const BASE_BUILDER_INTERVAL := 20.0
const BASE_BUILDER_COST := 3    # stone

# ビルダーシステム
static var REQUIRED_CONSTRUCTION: Dictionary = {
	0: 5.0,   # BARRACKS
	1: 8.0,   # FORTRESS
	2: 8.0,   # WORKSHOP
	3: 5.0,   # VILLAGE
	4: 0.0,   # BASE（建設不可）
}

var build_progress: float = 0.0
var build_priority: int = 0  # 集中建設モードでの優先度（大きいほど優先）

var _produce_timer: float = 0.0
var _harvester_timer: float = 0.0
var _resource_ready: bool = true  # 生産コストが払えるか（!表示用）
var _construction_ready: bool = true  # 建設コストが払えるか（建設中!表示用）

signal unit_produced(pos: Vector2i, unit_type: int)  # unit_type: 0=突,1=守,2=崩,-1=harvester,-2=builder
signal base_destroyed(is_player: bool)

func setup(btype: BuildingType, pos: Vector2i, player_side: bool) -> void:
	building_type = btype
	grid_pos = pos
	is_player_side = player_side
	max_hp = BUILD_HP.get(int(btype), 100.0)
	hp = max_hp
	# BASEは建設不可の初期配置なので建設済み扱い
	is_built = (btype == BuildingType.BASE)

func update(delta: float, economy: EconEconomy) -> void:
	if not is_alive:
		return
	if not is_built:
		return
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
			_update_base(delta, economy)

func _update_barracks(delta: float, economy: EconEconomy) -> void:
	_resource_ready = economy.can_afford({"wood": BARRACKS_PRODUCE_COST})
	_produce_timer += delta
	if _produce_timer >= BARRACKS_PRODUCE_INTERVAL:
		if _resource_ready:
			economy.spend({"wood": BARRACKS_PRODUCE_COST})
			_produce_timer = 0.0
			unit_produced.emit(grid_pos, 0)

func _update_fortress(delta: float, economy: EconEconomy) -> void:
	_resource_ready = economy.can_afford({"stone": FORTRESS_PRODUCE_COST})
	_produce_timer += delta
	if _produce_timer >= FORTRESS_PRODUCE_INTERVAL:
		if _resource_ready:
			economy.spend({"stone": FORTRESS_PRODUCE_COST})
			_produce_timer = 0.0
			unit_produced.emit(grid_pos, 1)

func _update_workshop(delta: float, economy: EconEconomy) -> void:
	_resource_ready = economy.can_afford({"sulfur": WORKSHOP_PRODUCE_COST})
	_produce_timer += delta
	if _produce_timer >= WORKSHOP_PRODUCE_INTERVAL:
		if _resource_ready:
			economy.spend({"sulfur": WORKSHOP_PRODUCE_COST})
			_produce_timer = 0.0
			unit_produced.emit(grid_pos, 2)

func _update_base(delta: float, economy: EconEconomy) -> void:
	_resource_ready = economy.can_afford({"stone": BASE_BUILDER_COST})
	_harvester_timer += delta
	if _harvester_timer >= BASE_BUILDER_INTERVAL:
		if _resource_ready:
			economy.spend({"stone": BASE_BUILDER_COST})
			_harvester_timer = 0.0
			unit_produced.emit(grid_pos, -2)  # -2 = builder

func _update_village(delta: float, economy: EconEconomy) -> void:
	_produce_timer += delta
	if _produce_timer >= VILLAGE_WHEAT_INTERVAL:
		_produce_timer = 0.0
		economy.add_wheat(VILLAGE_WHEAT_AMOUNT)
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
