class_name EconChest
extends Node2D

var grid_pos: Vector2i = Vector2i(-1, -1)
var acquired: bool = false
var reward_manager = null

func setup(pos: Vector2i, manager) -> void:
	grid_pos = pos
	reward_manager = manager
	queue_redraw()

func acquire() -> Dictionary:
	if acquired:
		return {}
	acquired = true
	visible = false
	if reward_manager != null:
		return reward_manager.acquire_chest()
	return {}

func _draw() -> void:
	if acquired:
		return
	draw_circle(Vector2.ZERO, 10.0, Color("#B49448"))
	draw_rect(Rect2(Vector2(-8, -4), Vector2(16, 12)), Color("#231F1B"))
	draw_rect(Rect2(Vector2(-8, -4), Vector2(16, 12)), Color("#B49448"), false, 2.0)
