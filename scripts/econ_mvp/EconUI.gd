class_name EconUI
extends Control

var economy: EconEconomy = null

var _update_timer: float = 0.0
var _buttons: Dictionary = {}
var _popup: PanelContainer = null
var _popup_label: Label = null

const UPDATE_INTERVAL := 0.5

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(240.0, 150.0)

	var panel := PanelContainer.new()
	panel.position = Vector2.ZERO
	panel.custom_minimum_size = custom_minimum_size
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	for key in ["population", "food", "stage", "military", "soldiers", "units"]:
		var button := Button.new()
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(220.0, 20.0)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_show_detail.bind(key))
		button.mouse_entered.connect(_show_detail.bind(key))
		box.add_child(button)
		_buttons[key] = button

	_popup = PanelContainer.new()
	_popup.visible = false
	_popup.position = Vector2(248.0, 0.0)
	_popup.custom_minimum_size = Vector2(320.0, 130.0)
	add_child(_popup)

	var popup_box := VBoxContainer.new()
	popup_box.add_theme_constant_override("separation", 4)
	_popup.add_child(popup_box)

	_popup_label = Label.new()
	_popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_popup_label.add_theme_font_size_override("font_size", 12)
	popup_box.add_child(_popup_label)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(func(): _popup.visible = false)
	popup_box.add_child(close_button)

	_refresh()

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0
	_refresh()

func _refresh() -> void:
	if economy == null:
		_set_button_text("population", "Population: -")
		_set_button_text("food", "Food: -")
		_set_button_text("stage", "Satisfaction: -")
		_set_button_text("military", "Power: -")
		_set_button_text("soldiers", "Soldiers: -")
		_set_button_text("units", "Units: -")
		return

	_set_button_text("population", "Population: %s" % economy.get_display_population())
	_set_button_text("food", "Food: %d" % economy.get_food_value())
	_set_button_text("stage", "Satisfaction: %s" % economy.get_satisfaction_stage())
	_set_button_text("military", "Power: %d" % economy.get_military_units())
	_set_button_text("soldiers", "Soldiers: %d" % economy.get_soldiers_count())
	_set_button_text("units", "Units: %d" % economy.get_unit_count())

func _set_button_text(key: String, value: String) -> void:
	if not _buttons.has(key):
		return
	var button: Button = _buttons[key]
	button.text = value

func _show_detail(key: String) -> void:
	if economy == null or _popup == null or _popup_label == null:
		return
	_popup_label.text = _build_detail_text(key)
	_popup.visible = true

func _build_detail_text(key: String) -> String:
	match key:
		"population":
			return _population_detail()
		"food":
			return _food_detail()
		"stage":
			return _satisfaction_detail()
		"military":
			return _military_detail()
		"soldiers":
			return _soldiers_detail()
		"units":
			return _units_detail()
		_:
			return ""

func _population_detail() -> String:
	var growth_rate: float = economy.get_population_growth_rate()
	var next_pop: int = economy.get_next_population_milestone()
	var required_food: int = 0
	if economy.has_method("get_population_milestone_food_cost"):
		required_food = economy.get_population_milestone_food_cost(next_pop)
	return "Population\nCurrent: %.2fk\nMin: %.0fk / Max: %dk\nGrowth rate: %+.2f%%/sec (%s)\nGrowth speed: %+.3f pop/sec\nNext milestone: %dk (food: %d)" % [
		economy.population_float,
		economy.population_min,
		economy.population_cap,
		growth_rate * 100.0,
		economy.get_satisfaction_stage(),
		economy.population_float * growth_rate,
		next_pop,
		required_food,
	]

func _food_detail() -> String:
	var cost: int = 0
	if economy.has_method("get_maintenance_food_cost"):
		cost = economy.get_maintenance_food_cost()
	return "Food\nCurrent: %d\n5-sec consumption: %d\nShortage: %s" % [
		economy.get_food_value(),
		cost,
		"yes" if economy.food_shortage_count > 0 else "none",
	]

func _satisfaction_detail() -> String:
	var b: Dictionary = economy.get_satisfaction_slope_breakdown()
	return "Satisfaction\nValue: %.1f%%\nStage: %s\nSlope: %+.5f%%/sec\n  Base: %+.5f\n  Population scale: %+.5f\n  Population change: %+.5f\n  Building: %+.5f\n  Food shortage: %+.5f" % [
		economy.satisfaction_value,
		economy.get_satisfaction_stage(),
		float(b.get("total", 0.0)),
		float(b.get("base", 0.0)),
		float(b.get("population_scale", 0.0)),
		float(b.get("population_growth", 0.0)),
		float(b.get("building", 0.0)),
		-float(b.get("food_shortage_penalty", 0.0)),
	]

func _military_detail() -> String:
	return "Power\nTotal: %d units (%d soldiers)\nGain modifier: %+.0f%% (%s)\nEffect modifier: %+.0f%% (%s)" % [
		economy.get_military_units(),
		economy.get_soldiers_count(),
		(economy.get_military_gain_modifier() - 1.0) * 100.0,
		economy.get_satisfaction_stage(),
		(economy.get_military_effect_modifier() - 1.0) * 100.0,
		economy.get_satisfaction_stage(),
	]

func _soldiers_detail() -> String:
	return "Soldiers\nCurrent: %d\nConversion: floor(power / 5)\nPower: %d" % [
		economy.get_soldiers_count(),
		economy.get_military_units(),
	]

func _units_detail() -> String:
	return "Units\nHand unit count: %d\nThis value is updated from the deck hand each frame." % economy.get_unit_count()
