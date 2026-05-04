class_name MilestoneWindow
extends PanelContainer

var session = null
var colors: Dictionary = {}
var _title_bar: PanelContainer = null
var _rows_box: VBoxContainer = null
var _special_badge: Label = null
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _show_all: bool = false

func setup(session_ref, color_values: Dictionary) -> void:
	session = session_ref
	colors = color_values
	position = session.milestone_window_position if session != null else Vector2(1050.0, 100.0)
	custom_minimum_size = Vector2(160.0, 180.0)
	size = Vector2(160.0, 180.0)
	_build_ui()
	update_milestones()

func update_milestones() -> void:
	if _rows_box == null or session == null:
		return
	for child in _rows_box.get_children():
		child.queue_free()
	var rows := _get_sorted_rows()
	var limit := rows.size() if _show_all else mini(3, rows.size())
	for i in range(limit):
		_rows_box.add_child(_make_row(rows[i]))
	_special_badge.visible = session.special_milestones.size() > 0
	_special_badge.text = "+%d SPECIAL ◇" % session.special_milestones.size()

func notify_special_added() -> void:
	update_milestones()
	if _special_badge == null:
		return
	var tween := create_tween()
	tween.tween_property(_special_badge, "modulate:a", 0.2, 0.25)
	tween.tween_property(_special_badge, "modulate:a", 1.0, 0.25)
	tween.set_loops(3)

func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = (colors.get("panel", Color("#231F1B")) as Color)
	sb.bg_color.a = 0.9
	sb.border_color = colors.get("border", Color("#3C3628"))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", sb)
	var root := VBoxContainer.new()
	add_child(root)
	_title_bar = PanelContainer.new()
	_title_bar.custom_minimum_size = Vector2(160, 20)
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.gui_input.connect(_on_drag_handle_input)
	root.add_child(_title_bar)
	var title := Label.new()
	title.text = "MILESTONE"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", colors.get("accent", Color("#B49448")))
	_title_bar.add_child(title)
	_rows_box = VBoxContainer.new()
	_rows_box.custom_minimum_size = Vector2(144, 120)
	root.add_child(_rows_box)
	_special_badge = Label.new()
	_special_badge.add_theme_font_size_override("font_size", 10)
	_special_badge.add_theme_color_override("font_color", colors.get("accent", Color("#B49448")))
	_special_badge.visible = false
	root.add_child(_special_badge)
	mouse_entered.connect(func():
		_show_all = true
		update_milestones()
	)
	mouse_exited.connect(func():
		_show_all = false
		update_milestones()
	)

func _gui_input(event: InputEvent) -> void:
	_on_drag_handle_input(event)

func _on_drag_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = event.position
			move_to_front()
		else:
			_dragging = false
			if session != null:
				session.milestone_window_position = position
	elif event is InputEventMouseMotion and _dragging:
		var viewport_size := get_viewport_rect().size
		position = (global_position + event.relative).clamp(Vector2.ZERO, viewport_size - size)
		if session != null:
			session.milestone_window_position = position

func _get_sorted_rows() -> Array:
	var rows: Array = []
	for system_key in session.milestones.keys():
		var data: Dictionary = session.milestones[system_key]
		var best_ratio := 0.0
		var best_current := 0
		var best_threshold := 1
		for difficulty_key in data.keys():
			var item: Dictionary = data[difficulty_key]
			var threshold: int = max(1, int(item.get("threshold", 1)))
			var current: int = int(item.get("current", 0))
			var ratio: float = float(current) / float(threshold)
			if ratio > best_ratio:
				best_ratio = ratio
				best_current = current
				best_threshold = threshold
		rows.append({"system": system_key, "current": best_current, "threshold": best_threshold, "ratio": best_ratio})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("ratio", 0.0)) > float(b.get("ratio", 0.0))
	)
	return rows

func _make_row(row: Dictionary) -> Control:
	var label := Label.new()
	var system_key := str(row.get("system", ""))
	label.text = "%s %d/%d" % [
		_get_system_label(system_key),
		int(row.get("current", 0)),
		int(row.get("threshold", 1)),
	]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", colors.get("text", Color("#DCD2B9")))
	return label

func _get_system_label(system_key: String) -> String:
	var labels := {
		"population": "POP",
		"food": "FOOD",
		"satisfaction": "SAT",
		"building": "BUILD",
		"resource": "RES",
		"troop": "TROOP",
		"land": "LAND",
		"risk": "RISK",
	}
	return labels.get(system_key, system_key.substr(0, 4).to_upper())
