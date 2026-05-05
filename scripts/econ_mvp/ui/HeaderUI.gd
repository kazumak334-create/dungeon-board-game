class_name HeaderUI
extends Control

# HeaderUI -- EconMain.gd header UI split (Sprint 9 refactor)
# Moved from EconMain.gd: _setup_header_ui / _update_status_ui / _update_population_ui
# _update_alloc_bar_ui / _on_alloc_bar_input and related helpers

signal early_charge_requested

var _economy: EconEconomy = null

var _pop_gauge_bar: ColorRect = null
var _pop_label: Label = null
var _pop_preview_label: Label = null
var _status_sat_label: Label = null
var _troop_gauge_bar: ColorRect = null
var _troop_label: Label = null
var _gold_label: Label = null
var _status_food_label: Label = null
var _soldiers_header_label: Label = null
var _units_header_label: Label = null
var _header_detail_popup: PanelContainer = null
var _header_detail_label: Label = null
var _res_labels: Dictionary = {}
var _alloc_bar_bg: ColorRect = null
var _alloc_bar_work: ColorRect = null
var _alloc_handle: ColorRect = null
var _alloc_label: Label = null
var _alloc_dragging: bool = false
var _force_charge_segs: Array = []
var _force_charge_turn_label: Label = null
var _force_charge_warn_label: Label = null
var _early_charge_btn: Button = null
var _ai_resource_label: Label = null
var _panel: PanelContainer = null
var _elapsed_time: float = 0.0

const COLOR_PANEL      := Color("#231F1B")
const COLOR_BORDER     := Color("#3C3628")
const COLOR_TEXT       := Color("#DCD2B9")
const COLOR_TEXT_DIM   := Color("#8A8070")
const COLOR_ACCENT_GOLD := Color("#B49448")
const COLOR_WOOD       := Color("#3F6932")
const COLOR_STONE      := Color("#5D5650")
const COLOR_RESIN      := Color("#8FD17A")
const COLOR_WHEAT      := Color("#A9924F")
const COLOR_POP        := Color("#5D8FB8")
const COLOR_SAT        := Color("#B89AC7")
const COLOR_TROOP      := Color("#B85A3C")
const COLOR_GOLD_COIN  := Color("#E0C060")
const COLOR_ORANGE     := Color("#C77A2C")
const COLOR_RED        := Color("#9C3A2A")

func setup(economy: EconEconomy, vp: Vector2) -> void:
	_economy = economy
	_build_header(vp)
	print("[HeaderUI] setup complete")

func get_panel() -> PanelContainer:
	return _panel

func refresh(delta: float, ai_economy = null) -> void:
	_elapsed_time += delta
	_update_res_labels()
	if ai_economy != null and _ai_resource_label != null:
		_ai_resource_label.text = "W:%d St:%d Re:%d Wh:%d" % [
			ai_economy.wood, ai_economy.stone, ai_economy.resin, ai_economy.wheat]
	_update_status_ui()
	_update_population_ui()
	_update_alloc_bar_ui()

func refresh_force_charge_with_turn(turn: int, blink_timer: float) -> void:
	if _force_charge_segs.is_empty():
		return
	for i in range(10):
		var seg: ColorRect = _force_charge_segs[i]
		if i < turn:
			var seg_color: Color
			var seg_turn := i + 1
			if seg_turn <= 3:
				seg_color = COLOR_WOOD
			elif seg_turn <= 6:
				seg_color = COLOR_WHEAT
			elif seg_turn <= 9:
				var blink := 0.7 + 0.3 * sin(blink_timer * PI * 2.0 / 0.8)
				seg_color = COLOR_ORANGE
				seg_color.a = blink
			else:
				var blink := 0.5 + 0.5 * sin(blink_timer * PI * 2.0 / 0.4)
				seg_color = COLOR_RED
				seg_color.a = blink
			seg.color = seg_color
		else:
			seg.color = COLOR_PANEL
	if _force_charge_turn_label != null:
		_force_charge_turn_label.text = "Turn %d/10" % turn
	if _force_charge_warn_label != null:
		_force_charge_warn_label.visible = (turn >= 7)
	if _early_charge_btn != null:
		var ec_sb := StyleBoxFlat.new()
		ec_sb.bg_color = COLOR_PANEL
		ec_sb.set_corner_radius_all(3)
		if turn >= 10:
			ec_sb.border_color = COLOR_RED
			ec_sb.set_border_width_all(2)
			_early_charge_btn.add_theme_color_override("font_color", COLOR_RED)
		elif turn >= 7:
			ec_sb.border_color = COLOR_ORANGE
			ec_sb.set_border_width_all(2)
			_early_charge_btn.add_theme_color_override("font_color", COLOR_ORANGE)
		else:
			ec_sb.border_color = COLOR_BORDER
			ec_sb.set_border_width_all(1)
			_early_charge_btn.add_theme_color_override("font_color", COLOR_TEXT)
		_early_charge_btn.add_theme_stylebox_override("normal", ec_sb)

func _build_header(vp: Vector2) -> void:
	var header := PanelContainer.new()
	header.position = Vector2.ZERO
	header.custom_minimum_size = Vector2(vp.x, 56)
	_panel = header
	add_child(header)
	var hdr_vbox := VBoxContainer.new()
	hdr_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hdr_vbox.add_theme_constant_override("separation", 0)
	header.add_child(hdr_vbox)
	var row1 := HBoxContainer.new()
	row1.custom_minimum_size = Vector2(0, 28)
	row1.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row1.add_theme_constant_override("separation", 4)
	hdr_vbox.add_child(row1)
	_setup_pop_header(row1)
	_setup_troop_header(row1)
	_setup_gold_header(row1)
	var food_hbox := HBoxContainer.new()
	food_hbox.custom_minimum_size = Vector2(90, 28)
	food_hbox.add_theme_constant_override("separation", 2)
	row1.add_child(food_hbox)
	_register_detail_target(food_hbox, "food")
	var food_icon := Label.new()
	food_icon.text = "食料"
	food_icon.add_theme_font_size_override("font_size", 10)
	food_icon.add_theme_color_override("font_color", COLOR_WHEAT)
	food_hbox.add_child(food_icon)
	_status_food_label = Label.new()
	_status_food_label.text = "30"
	_status_food_label.add_theme_font_size_override("font_size", 11)
	_status_food_label.add_theme_color_override("font_color", COLOR_WHEAT)
	food_hbox.add_child(_status_food_label)
	_soldiers_header_label = _make_header_metric("兵0", COLOR_TROOP)
	row1.add_child(_soldiers_header_label)
	_register_detail_target(_soldiers_header_label, "soldiers")
	_units_header_label = _make_header_metric("隊0", COLOR_TEXT)
	row1.add_child(_units_header_label)
	_register_detail_target(_units_header_label, "units")
	var ctrl_spacer := Control.new()
	ctrl_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(ctrl_spacer)
	var row2 := HBoxContainer.new()
	row2.custom_minimum_size = Vector2(0, 28)
	row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row2.add_theme_constant_override("separation", 2)
	hdr_vbox.add_child(row2)
	var res_keys   := ["wood", "stone", "resin", "wheat", "iron", "cotton"]
	var res_icons  := ["木", "石", "樹脂", "麦", "鉄", "綿"]
	var res_colors := [COLOR_WOOD, COLOR_STONE, COLOR_RESIN, COLOR_WHEAT, COLOR_STONE, COLOR_TEXT]
	_res_labels = {}
	for ri in range(res_keys.size()):
		var rc := HBoxContainer.new()
		rc.custom_minimum_size = Vector2(72, 0)
		rc.add_theme_constant_override("separation", 2)
		row2.add_child(rc)
		_register_detail_target(rc, "resource:%s" % res_keys[ri])
		var ri_lbl := Label.new()
		ri_lbl.text = res_icons[ri]
		ri_lbl.add_theme_font_size_override("font_size", 10)
		ri_lbl.add_theme_color_override("font_color", res_colors[ri])
		rc.add_child(ri_lbl)
		var rv_lbl := Label.new()
		rv_lbl.text = "0"
		rv_lbl.add_theme_font_size_override("font_size", 11)
		rv_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		rc.add_child(rv_lbl)
		_res_labels[res_keys[ri]] = rv_lbl
	var res_sep := VSeparator.new()
	res_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(res_sep)
	_status_sat_label = Label.new()
	_status_sat_label.add_theme_font_size_override("font_size", 10)
	_status_sat_label.add_theme_color_override("font_color", COLOR_SAT)
	_status_sat_label.custom_minimum_size = Vector2(120, 0)
	row2.add_child(_status_sat_label)
	_register_detail_target(_status_sat_label, "satisfaction")
	_setup_alloc_bar(row2)
	var fc_sep := VSeparator.new()
	fc_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(fc_sep)
	var fc_hbox := HBoxContainer.new()
	fc_hbox.custom_minimum_size = Vector2(288, 0)
	fc_hbox.add_theme_constant_override("separation", 2)
	fc_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(fc_hbox)
	var fc_lbl := Label.new()
	fc_lbl.text = "Force:"
	fc_lbl.add_theme_font_size_override("font_size", 9)
	fc_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	fc_hbox.add_child(fc_lbl)
	_force_charge_segs = []
	for si in range(10):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(22, 18)
		seg.color = COLOR_PANEL
		fc_hbox.add_child(seg)
		_force_charge_segs.append(seg)
	_force_charge_turn_label = Label.new()
	_force_charge_turn_label.text = "0/10"
	_force_charge_turn_label.add_theme_font_size_override("font_size", 9)
	_force_charge_turn_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	fc_hbox.add_child(_force_charge_turn_label)
	_force_charge_warn_label = Label.new()
	_force_charge_warn_label.add_theme_font_size_override("font_size", 9)
	_force_charge_warn_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_force_charge_warn_label.visible = false
	fc_hbox.add_child(_force_charge_warn_label)
	_ai_resource_label = Label.new()
	_ai_resource_label.visible = false
	_setup_header_detail_popup()

func _make_header_metric(p_text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = p_text
	label.custom_minimum_size = Vector2(56, 28)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	return label

func _setup_pop_header(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(130, 28)
	hbox.add_theme_constant_override("separation", 2)
	parent.add_child(hbox)
	_register_detail_target(hbox, "population")
	var icon_lbl := Label.new()
	icon_lbl.text = "[P]"
	icon_lbl.add_theme_font_size_override("font_size", 11)
	icon_lbl.add_theme_color_override("font_color", COLOR_POP)
	hbox.add_child(icon_lbl)
	var vb := VBoxContainer.new()
	hbox.add_child(vb)
	var gauge_row := HBoxContainer.new()
	vb.add_child(gauge_row)
	var gauge_bg := ColorRect.new()
	gauge_bg.custom_minimum_size = Vector2(60, 6)
	gauge_bg.color = COLOR_PANEL
	gauge_row.add_child(gauge_bg)
	_pop_gauge_bar = ColorRect.new()
	_pop_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_pop_gauge_bar.size = Vector2(0, 6)
	_pop_gauge_bar.color = COLOR_POP
	gauge_bg.add_child(_pop_gauge_bar)
	_pop_label = Label.new()
	_pop_label.text = "0/50"
	_pop_label.add_theme_font_size_override("font_size", 10)
	_pop_label.add_theme_color_override("font_color", COLOR_TEXT)
	gauge_row.add_child(_pop_label)
	_pop_preview_label = Label.new()
	_pop_preview_label.add_theme_font_size_override("font_size", 9)
	_pop_preview_label.add_theme_color_override("font_color", COLOR_WOOD)
	_pop_preview_label.visible = false
	vb.add_child(_pop_preview_label)

func _setup_troop_header(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(130, 28)
	hbox.add_theme_constant_override("separation", 2)
	parent.add_child(hbox)
	_register_detail_target(hbox, "military")
	var icon_lbl := Label.new()
	icon_lbl.text = "[S]"
	icon_lbl.add_theme_font_size_override("font_size", 11)
	icon_lbl.add_theme_color_override("font_color", COLOR_TROOP)
	hbox.add_child(icon_lbl)
	var vb := VBoxContainer.new()
	hbox.add_child(vb)
	var gauge_row := HBoxContainer.new()
	vb.add_child(gauge_row)
	var gauge_bg := ColorRect.new()
	gauge_bg.custom_minimum_size = Vector2(60, 6)
	gauge_bg.color = COLOR_PANEL
	gauge_row.add_child(gauge_bg)
	_troop_gauge_bar = ColorRect.new()
	_troop_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_troop_gauge_bar.size = Vector2(0, 6)
	_troop_gauge_bar.color = COLOR_TROOP
	gauge_bg.add_child(_troop_gauge_bar)
	_troop_label = Label.new()
	_troop_label.text = "0"
	_troop_label.add_theme_font_size_override("font_size", 10)
	_troop_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	gauge_row.add_child(_troop_label)

func _setup_gold_header(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(110, 28)
	hbox.add_theme_constant_override("separation", 2)
	parent.add_child(hbox)
	_register_detail_target(hbox, "gold")
	var icon_lbl := Label.new()
	icon_lbl.text = "[G]"
	icon_lbl.add_theme_font_size_override("font_size", 11)
	icon_lbl.add_theme_color_override("font_color", COLOR_GOLD_COIN)
	hbox.add_child(icon_lbl)
	_gold_label = Label.new()
	_gold_label.text = "100G"
	_gold_label.add_theme_font_size_override("font_size", 12)
	_gold_label.add_theme_color_override("font_color", COLOR_GOLD_COIN)
	hbox.add_child(_gold_label)

func _setup_alloc_bar(parent: Control) -> void:
	var container := HBoxContainer.new()
	container.custom_minimum_size = Vector2(140, 28)
	container.add_theme_constant_override("separation", 2)
	parent.add_child(container)
	var icon_lbl := Label.new()
	icon_lbl.text = "配分"
	icon_lbl.add_theme_font_size_override("font_size", 10)
	icon_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	container.add_child(icon_lbl)
	_alloc_bar_bg = ColorRect.new()
	_alloc_bar_bg.custom_minimum_size = Vector2(80, 14)
	_alloc_bar_bg.color = COLOR_PANEL
	_alloc_bar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(_alloc_bar_bg)
	_alloc_bar_work = ColorRect.new()
	_alloc_bar_work.color = COLOR_WOOD
	_alloc_bar_work.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alloc_bar_bg.add_child(_alloc_bar_work)
	_alloc_handle = ColorRect.new()
	_alloc_handle.color = COLOR_TEXT
	_alloc_handle.custom_minimum_size = Vector2(2, 14)
	_alloc_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alloc_bar_bg.add_child(_alloc_handle)
	_alloc_label = Label.new()
	_alloc_label.add_theme_font_size_override("font_size", 9)
	_alloc_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	container.add_child(_alloc_label)
	_alloc_bar_bg.gui_input.connect(_on_alloc_bar_input)

func _setup_header_detail_popup() -> void:
	_header_detail_popup = PanelContainer.new()
	_header_detail_popup.visible = false
	_header_detail_popup.position = Vector2(8.0, 60.0)
	_header_detail_popup.custom_minimum_size = Vector2(330.0, 160.0)
	add_child(_header_detail_popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_header_detail_popup.add_child(box)
	_header_detail_label = Label.new()
	_header_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_header_detail_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_header_detail_label)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(func(): _header_detail_popup.visible = false)
	box.add_child(close_button)

func _register_detail_target(control: Control, key: String) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_header_detail(key)
	)

func _show_header_detail(key: String) -> void:
	if _header_detail_popup == null or _header_detail_label == null or _economy == null:
		return
	_header_detail_label.text = _build_header_detail_text(key)
	_header_detail_popup.visible = true

func _build_header_detail_text(key: String) -> String:
	if key.begins_with("resource:"):
		var res_key: String = key.get_slice(":", 1)
		return "Resource: %s\nCurrent: %d" % [res_key, int(_economy.resources.get(res_key, 0))]
	match key:
		"population":
			var next_pop: int = _economy.get_next_population_milestone()
			return "Population\nCap: %d\nCurrent: %d\nNext: %dk" % [
				_economy.population_cap, _economy.get_display_population(), next_pop]
		"food":
			return "Food\nCurrent: %d\nShortage: %d" % [
				_economy.get_food_value(), _economy.food_shortage_count]
		"satisfaction":
			return "Satisfaction\nStage: %s\nValue: %.1f%%" % [
				_economy.get_satisfaction_stage(), _economy.satisfaction_value]
		"military":
			return "Power\nCurrent: %d\nRaw: %.2f" % [
				_economy.get_military_units(), _economy.military_power]
		"gold":
			return "Gold\nCurrent: %dG" % _economy.currency
		"soldiers":
			return "Soldiers\nCurrent: %d" % _economy.get_soldiers_count()
		"units":
			return "Units\nCurrent: %d" % _economy.get_unit_count()
		_:
			return ""

func _update_res_labels() -> void:
	if _economy == null:
		return
	for res_key in _res_labels.keys():
		var lbl: Label = _res_labels[res_key]
		lbl.text = "%d" % _economy.resources.get(res_key, 0)

func _update_status_ui() -> void:
	if _economy == null:
		return
	if _status_sat_label != null:
		_status_sat_label.text = "満足%d" % _economy.satisfaction
	var mil_power: float = _economy.military_power
	if _troop_label != null:
		_troop_label.text = "%d" % int(floor(mil_power))
	var gauge_progress: float = clampf(mil_power / 60.0, 0.0, 1.0)
	if mil_power == 0.0:
		if _troop_gauge_bar != null:
			_troop_gauge_bar.modulate.a = 0.3
			_troop_gauge_bar.self_modulate = COLOR_TROOP
		if _troop_label != null:
			_troop_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
			_troop_label.remove_theme_font_size_override("font_size")
	elif mil_power <= 30.0:
		if _troop_gauge_bar != null:
			_troop_gauge_bar.modulate.a = 1.0
			_troop_gauge_bar.self_modulate = COLOR_TROOP
		if _troop_label != null:
			_troop_label.add_theme_color_override("font_color", COLOR_TEXT)
			_troop_label.remove_theme_font_size_override("font_size")
	elif mil_power <= 50.0:
		var cycle2: float = fmod(_elapsed_time, 1.0)
		var alpha2: float = lerp(0.7, 1.0, sin(cycle2 * PI) * 0.5 + 0.5)
		if _troop_gauge_bar != null:
			_troop_gauge_bar.modulate.a = alpha2
			_troop_gauge_bar.self_modulate = COLOR_TROOP
		if _troop_label != null:
			_troop_label.add_theme_color_override("font_color", COLOR_TEXT)
			_troop_label.add_theme_font_size_override("font_size", 14)
	else:
		var cycle3: float = fmod(_elapsed_time, 0.5)
		var alpha3: float = 0.5 if cycle3 < 0.25 else 1.0
		if _troop_gauge_bar != null:
			_troop_gauge_bar.modulate.a = alpha3
			_troop_gauge_bar.self_modulate = COLOR_RED
		if _troop_label != null:
			_troop_label.add_theme_color_override("font_color", COLOR_RED)
			_troop_label.add_theme_font_size_override("font_size", 14)
	if _troop_gauge_bar != null:
		var tbg_w: float = _troop_gauge_bar.get_parent().size.x if _troop_gauge_bar.get_parent() != null and _troop_gauge_bar.get_parent().size.x > 0.0 else 80.0
		_troop_gauge_bar.size = Vector2(tbg_w * gauge_progress, _troop_gauge_bar.size.y)
	if _gold_label != null:
		_gold_label.text = "%dG" % _economy.currency
		var cur_color := COLOR_TEXT_DIM if _economy.currency <= 0 else COLOR_GOLD_COIN
		_gold_label.add_theme_color_override("font_color", cur_color)
	if _status_food_label != null:
		_status_food_label.text = "食%d" % _economy.food
		var food_color := COLOR_RED if _economy.food < 5 else COLOR_WHEAT
		_status_food_label.add_theme_color_override("font_color", food_color)
	if _soldiers_header_label != null:
		_soldiers_header_label.text = "兵%d" % _economy.get_soldiers_count()
	if _units_header_label != null:
		_units_header_label.text = "隊%d" % _economy.get_unit_count()

func _update_population_ui() -> void:
	if _pop_gauge_bar == null or _pop_label == null or _economy == null:
		return
	var pop_current: int = _economy.get_display_population()
	var pop_cap: int = _economy.population_cap
	if pop_cap <= 0:
		return
	var ratio: float = float(pop_current) / float(pop_cap)
	var pbg_w: float = _pop_gauge_bar.get_parent().size.x if _pop_gauge_bar.get_parent() != null and _pop_gauge_bar.get_parent().size.x > 0.0 else 80.0
	_pop_gauge_bar.size = Vector2(pbg_w * clampf(ratio, 0.0, 1.0), _pop_gauge_bar.size.y)
	if ratio >= 1.0:
		_pop_gauge_bar.color = COLOR_RED
		_pop_label.add_theme_color_override("font_color", COLOR_RED)
	elif ratio >= 0.7:
		_pop_gauge_bar.color = COLOR_WHEAT
		_pop_label.add_theme_color_override("font_color", COLOR_TEXT)
	else:
		_pop_gauge_bar.color = COLOR_WOOD
		_pop_label.add_theme_color_override("font_color", COLOR_TEXT)
	_pop_label.text = "%d/%d" % [pop_current, pop_cap]

func _update_alloc_bar_ui() -> void:
	if _alloc_bar_bg == null or _alloc_bar_work == null or _alloc_handle == null or _economy == null:
		return
	var ratio: float = _economy.alloc_work_ratio
	var bar_w: float = _alloc_bar_bg.size.x
	if bar_w <= 0.0:
		return
	var work_x: float = bar_w * (1.0 - ratio)
	_alloc_bar_work.position = Vector2(work_x, 0.0)
	_alloc_bar_work.size = Vector2(bar_w - work_x, _alloc_bar_bg.size.y)
	_alloc_handle.position = Vector2(work_x - 1.0, 0.0)
	_alloc_handle.size = Vector2(2.0, _alloc_bar_bg.size.y)
	if _alloc_label != null:
		_alloc_label.text = ""

func _on_alloc_bar_input(event: InputEvent) -> void:
	if _alloc_bar_bg == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_alloc_dragging = mb.pressed
			if mb.pressed:
				_apply_alloc_from_mouse(mb.position.x)
	elif event is InputEventMouseMotion and _alloc_dragging:
		_apply_alloc_from_mouse(event.position.x)

func _apply_alloc_from_mouse(local_x: float) -> void:
	if _economy == null:
		return
	var bar_w: float = _alloc_bar_bg.size.x
	if bar_w <= 0.0:
		return
	var raw_ratio: float = clampf(local_x / bar_w, 0.0, 1.0)
	_economy.set_alloc_work_ratio(raw_ratio)
	_update_alloc_bar_ui()
