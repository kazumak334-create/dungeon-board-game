class_name RewardSelectionUI
extends Control

signal reward_selected(card: Dictionary)
signal reward_skipped(context: Dictionary)

var colors: Dictionary = {}
var current_options: Array = []
var current_context: Dictionary = {}

func setup(color_values: Dictionary) -> void:
	colors = color_values
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func show_rewards(options: Array, context: Dictionary) -> void:
	current_options = options.duplicate(true)
	current_context = context.duplicate(true)
	visible = true
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = colors.get("bg", Color("#1A1814"))
	dim.color.a = 0.85
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := VBoxContainer.new()
	root.position = Vector2(300, 140)
	root.custom_minimum_size = Vector2(700, 420)
	add_child(root)
	var title := Label.new()
	title.text = "MILESTONE REWARD"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", colors.get("accent", Color("#B49448")))
	root.add_child(title)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 24)
	root.add_child(cards)
	for option in current_options:
		cards.add_child(_make_card(option))
	var skip := Button.new()
	skip.text = "SKIP"
	skip.custom_minimum_size = Vector2(80, 32)
	skip.pressed.connect(func():
		visible = false
		reward_skipped.emit(current_context)
	)
	root.add_child(skip)

func _make_card(card: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 280)
	btn.text = "%s\n\n%s\n\n%s" % [
		str(card.get("card_type", "")).to_upper(),
		str(card.get("name", card.get("card_id", card.get("id", "?")))),
		_format_description(card),
	]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD
	var sb := StyleBoxFlat.new()
	sb.bg_color = colors.get("panel", Color("#231F1B"))
	sb.border_color = _get_border_color(str(card.get("card_type", "")))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_color_override("font_color", colors.get("text", Color("#DCD2B9")))
	var selected := card.duplicate(true)
	btn.pressed.connect(func():
		visible = false
		reward_selected.emit(selected)
	)
	return btn

func _format_description(card: Dictionary) -> String:
	if str(card.get("card_type", "")) == "land_card":
		return "資源:%s 値:%d" % [str(card.get("resource", "wood")), int(card.get("value", 0))]
	return str(card.get("description", card.get("effect", "")))

func _get_border_color(card_type: String) -> Color:
	match card_type:
		"special_building":
			return colors.get("accent", Color("#B49448"))
		"policy_card":
			return colors.get("pop", Color("#5D8FB8"))
		"great_person_card":
			return colors.get("sat", Color("#B89AC7"))
		"land_card":
			return colors.get("wood", Color("#3F6932"))
		_:
			return colors.get("border", Color("#3C3628"))
