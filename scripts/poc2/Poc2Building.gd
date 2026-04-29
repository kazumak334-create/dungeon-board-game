class_name Poc2Building
extends Node2D

enum BuildingType { BARRACKS, FORTRESS }

var building_type: BuildingType
var grid_pos: Vector2i
var is_alive: bool = true

const BARRACKS_WOOD_COST := 5
const BARRACKS_PRODUCE_INTERVAL := 8.0  # 生産間隔（木材コスト到達後リセット）

var _produce_timer: float = 0.0

signal unit_produced(pos: Vector2i)  # 兵舎が新ユニットを要求

func update(delta: float, economy: Node) -> void:
	if not is_alive:
		return
	match building_type:
		BuildingType.BARRACKS:
			_update_barracks(delta, economy)

func _update_barracks(delta: float, economy: Node) -> void:
	_produce_timer += delta
	if _produce_timer >= BARRACKS_PRODUCE_INTERVAL:
		if economy.can_afford_wood(BARRACKS_WOOD_COST):
			economy.spend_wood(BARRACKS_WOOD_COST)
			_produce_timer = 0.0
			unit_produced.emit(grid_pos)

func get_damage_reduction() -> float:
	if building_type == BuildingType.FORTRESS:
		return 0.5
	return 0.0

func _draw() -> void:
	var color: Color = Color.PERU if building_type == BuildingType.BARRACKS else Color.GRAY
	# 四角形で建造物を表現
	draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), color)
	draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), Color.WHITE, false, 2.0)
