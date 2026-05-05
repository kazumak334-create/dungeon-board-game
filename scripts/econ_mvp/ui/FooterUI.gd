class_name FooterUI
extends Control

# FooterUI -- EconMain.gd footer UI split (Sprint 9 refactor)
# Moved from EconMain.gd: _setup_footer_ui / _setup_deck_discard_block /
# _setup_hand_center_block / _setup_event_block / _update_draw_gauge_ui /
# _update_reload_gauge_ui

signal hand_scroll_left_pressed
signal hand_scroll_right_pressed

var _footer: PanelContainer = null
var _hand_container: HBoxContainer = null
var _hand_left_arrow: Button = null
var _hand_right_arrow: Button = null
var _draw_gauge_bar: ColorRect = null
var _draw_gauge_bg: ColorRect = null
var _draw_gauge_label: Label = null
var _reload_gauge_bar: ColorRect = null
var _reload_gauge_bg: ColorRect = null
var _reload_gauge_label: Label = null
var _deck_count_label: Label = null
var _discard_count_label: Label = null

var _draw_gauge_blink_timer: float = 0.0
var _draw_flash_timer: float = 0.0

const FOOTER_H := 180.0
const COLOR_PANEL           := Color("#231F1B")
const COLOR_BORDER          := Color("#3C3628")
const COLOR_TEXT            := Color("#DCD2B9")
const COLOR_TEXT_DIM        := Color("#8A8070")
const COLOR_ACCENT_GOLD     := Color("#B49448")
const COLOR_ACCENT_GOLD_BRIGHT := Color("#D4B468")
const COLOR_RED             := Color("#9C3A2A")

func setup(vp: Vector2) -> void:
	_build_footer(vp)
	print("[FooterUI] setup complete")

func get_footer() -> PanelContainer:
	return _footer

func set_hand_cards(card_nodes: Array) -> void:
	if _hand_container == null:
		return
	for child in _hand_container.get_children():
		child.queue_free()
	for node in card_nodes:
		_hand_container.add_child(node)

func update_hand_arrows(scroll_offset: int, hand_size: int) -> void:
	if _hand_left_arrow != null:
		_hand_left_arrow.modulate.a = 1.0 if scroll_offset > 0 else 0.3
	if _hand_right_arrow != null:
		_hand_right_arrow.modulate.a = 1.0 if (scroll_offset + 5 < hand_size) else 0.3

func update_deck_discard_counts(deck_count: int, discard_count: int) -> void:
	if _deck_count_label != null:
		_deck_count_label.text = "R%d" % deck_count
	if _discard_count_label != null:
		_discard_count_label.text = "%d" % discard_count

func refresh_draw_gauge(delta: float, deck_manager) -> void:
	if _draw_gauge_bar == null or deck_manager == null:
		return
	var gauge_val: float = float(deck_manager.draw_gauge_value)
	var gauge_max: float = 30.0
	var pending: int = int(deck_manager.pending_draws)
	var progress: float = clampf(gauge_val / gauge_max, 0.0, 1.0)
	_draw_gauge_blink_timer += delta
	var bar_color: Color = COLOR_ACCENT_GOLD
	var sub_text: String = "%.0fs" % (gauge_max - gauge_val)
	if pending > 0:
		bar_color = COLOR_TEXT_DIM
		sub_text = "MAX (8/8)"
		_draw_gauge_label.add_theme_color_override("font_color", COLOR_RED)
	elif _draw_flash_timer > 0.0:
		_draw_flash_timer -= delta
		bar_color = Color.WHITE
		sub_text = ""
	elif progress >= 0.8:
		var blink_period: float = 0.5 if progress >= 0.9 else 1.0
		var blink_alpha: float = 0.7 + 0.3 * sin(_draw_gauge_blink_timer * PI * 2.0 / blink_period)
		bar_color = COLOR_ACCENT_GOLD_BRIGHT
		bar_color.a = blink_alpha
		sub_text = "Soon..."
		_draw_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	else:
		_draw_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	var bg_w: float = _draw_gauge_bg.size.x if _draw_gauge_bg.size.x > 0.0 else 160.0
	_draw_gauge_bar.size = Vector2(bg_w * progress, _draw_gauge_bg.size.y)
	_draw_gauge_bar.color = bar_color
	_draw_gauge_label.text = sub_text

func trigger_draw_flash() -> void:
	_draw_flash_timer = 0.1

func refresh_reload_gauge(deck_manager) -> void:
	if _reload_gauge_bar == null or deck_manager == null:
		return
	var reload_timer_val: float = float(deck_manager.reload_timer)
	var reload_max: float = float(deck_manager.RELOAD_COOLDOWN_SEC)
	var progress: float = clampf(1.0 - (reload_timer_val / reload_max), 0.0, 1.0)
	var bg_w: float = _reload_gauge_bg.size.x if _reload_gauge_bg.size.x > 0.0 else 140.0
	_reload_gauge_bar.size = Vector2(bg_w * progress, _reload_gauge_bg.size.y)
	if reload_timer_val > 0.0:
		_reload_gauge_bar.color = Color(0.75, 0.58, 0.28)
		_reload_gauge_label.text = "%.1fs" % reload_timer_val
	else:
		_reload_gauge_bar.color = COLOR_ACCENT_GOLD
		_reload_gauge_label.text = "Ready"

func _build_footer(vp: Vector2) -> void:
	var footer := PanelContainer.new()
	footer.position = Vector2(0, max(56.0, vp.y - FOOTER_H))
	footer.custom_minimum_size = Vector2(vp.x, FOOTER_H)
	_footer = footer
	add_child(footer)
	var ftr_hbox := HBoxContainer.new()
	ftr_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ftr_hbox.add_theme_constant_override("separation", 4)
	footer.add_child(ftr_hbox)
	_setup_deck_discard_block(ftr_hbox)
	var ftr_sep1 := VSeparator.new()
	ftr_sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ftr_hbox.add_child(ftr_sep1)
	_setup_hand_center_block(ftr_hbox)
	var ftr_sep2 := VSeparator.new()
	ftr_sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ftr_hbox.add_child(ftr_sep2)
	_setup_event_block(ftr_hbox)

func _setup_deck_discard_block(parent: Control) -> void:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(90, 0)
	vb.add_theme_constant_override("separation", 4)
	parent.add_child(vb)
	var deck_panel := PanelContainer.new()
	deck_panel.custom_minimum_size = Vector2(90, 80)
	deck_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dp_sb := StyleBoxFlat.new()
	dp_sb.bg_color = COLOR_PANEL
	dp_sb.border_color = COLOR_BORDER
	dp_sb.set_border_width_all(1)
	deck_panel.add_theme_stylebox_override("panel", dp_sb)
	vb.add_child(deck_panel)
	var dp_vb := VBoxContainer.new()
	dp_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dp_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_panel.add_child(dp_vb)
	var dp_title := Label.new()
	dp_title.text = "DECK"
	dp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dp_title.add_theme_font_size_override("font_size", 10)
	dp_title.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dp_vb.add_child(dp_title)
	var dp_back := ColorRect.new()
	dp_back.custom_minimum_size = Vector2(48, 36)
	dp_back.color = COLOR_PANEL
	dp_vb.add_child(dp_back)
	var dp_back_border := Label.new()
	dp_back_border.text = "[DECK]"
	dp_back_border.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dp_back_border.add_theme_font_size_override("font_size", 9)
	dp_back_border.add_theme_color_override("font_color", COLOR_ACCENT_GOLD)
	dp_vb.add_child(dp_back_border)
	_deck_count_label = Label.new()
	_deck_count_label.text = "R13"
	_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_count_label.add_theme_font_size_override("font_size", 14)
	_deck_count_label.add_theme_color_override("font_color", COLOR_TEXT)
	dp_vb.add_child(_deck_count_label)
	var disc_panel := PanelContainer.new()
	disc_panel.custom_minimum_size = Vector2(90, 80)
	disc_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dsc_sb := StyleBoxFlat.new()
	dsc_sb.bg_color = COLOR_PANEL
	dsc_sb.border_color = COLOR_BORDER
	dsc_sb.set_border_width_all(1)
	disc_panel.add_theme_stylebox_override("panel", dsc_sb)
	vb.add_child(disc_panel)
	var dsc_vb := VBoxContainer.new()
	dsc_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dsc_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	disc_panel.add_child(dsc_vb)
	var dsc_title := Label.new()
	dsc_title.text = "DISCARD"
	dsc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dsc_title.add_theme_font_size_override("font_size", 10)
	dsc_title.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dsc_vb.add_child(dsc_title)
	var dsc_icon := Label.new()
	dsc_icon.text = "Disc"
	dsc_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dsc_icon.add_theme_font_size_override("font_size", 18)
	dsc_icon.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dsc_vb.add_child(dsc_icon)
	_discard_count_label = Label.new()
	_discard_count_label.text = "0"
	_discard_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_count_label.add_theme_font_size_override("font_size", 10)
	_discard_count_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dsc_vb.add_child(_discard_count_label)

func _setup_hand_center_block(parent: Control) -> void:
	var center_block := VBoxContainer.new()
	center_block.custom_minimum_size = Vector2(1016, 160)
	center_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_block.add_theme_constant_override("separation", 2)
	parent.add_child(center_block)
	var dg_row := HBoxContainer.new()
	dg_row.custom_minimum_size = Vector2(0, 24)
	dg_row.add_theme_constant_override("separation", 4)
	center_block.add_child(dg_row)
	var dg_spacer := Control.new()
	dg_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dg_row.add_child(dg_spacer)
	var dg_lbl := Label.new()
	dg_lbl.text = "Draw"
	dg_lbl.add_theme_font_size_override("font_size", 9)
	dg_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dg_row.add_child(dg_lbl)
	var dg_bar_bg := ColorRect.new()
	dg_bar_bg.custom_minimum_size = Vector2(140, 12)
	dg_bar_bg.color = COLOR_PANEL
	dg_row.add_child(dg_bar_bg)
	_draw_gauge_bg = dg_bar_bg
	_draw_gauge_bar = ColorRect.new()
	_draw_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_draw_gauge_bar.size = Vector2(0, 12)
	_draw_gauge_bar.color = COLOR_ACCENT_GOLD
	dg_bar_bg.add_child(_draw_gauge_bar)
	_draw_gauge_label = Label.new()
	_draw_gauge_label.text = "30s"
	_draw_gauge_label.add_theme_font_size_override("font_size", 9)
	_draw_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	dg_row.add_child(_draw_gauge_label)
	var rg_row := HBoxContainer.new()
	rg_row.custom_minimum_size = Vector2(0, 20)
	rg_row.add_theme_constant_override("separation", 4)
	center_block.add_child(rg_row)
	var rg_spacer := Control.new()
	rg_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rg_row.add_child(rg_spacer)
	var rg_lbl_static := Label.new()
	rg_lbl_static.text = "Reload"
	rg_lbl_static.add_theme_font_size_override("font_size", 9)
	rg_lbl_static.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	rg_row.add_child(rg_lbl_static)
	var rg_bar_bg := ColorRect.new()
	rg_bar_bg.custom_minimum_size = Vector2(140, 10)
	rg_bar_bg.color = COLOR_PANEL
	rg_row.add_child(rg_bar_bg)
	_reload_gauge_bg = rg_bar_bg
	_reload_gauge_bar = ColorRect.new()
	_reload_gauge_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_reload_gauge_bar.size = Vector2(0, 10)
	_reload_gauge_bar.color = COLOR_ACCENT_GOLD
	rg_bar_bg.add_child(_reload_gauge_bar)
	_reload_gauge_label = Label.new()
	_reload_gauge_label.text = ""
	_reload_gauge_label.add_theme_font_size_override("font_size", 9)
	_reload_gauge_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	rg_row.add_child(_reload_gauge_label)
	var hand_row := HBoxContainer.new()
	hand_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_row.add_theme_constant_override("separation", 4)
	center_block.add_child(hand_row)
	_hand_left_arrow = Button.new()
	_hand_left_arrow.text = "<"
	_hand_left_arrow.custom_minimum_size = Vector2(40, 64)
	_hand_left_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hand_left_arrow.modulate.a = 0.3
	_hand_left_arrow.pressed.connect(func(): hand_scroll_left_pressed.emit())
	hand_row.add_child(_hand_left_arrow)
	_hand_container = HBoxContainer.new()
	_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hand_container.add_theme_constant_override("separation", 8)
	hand_row.add_child(_hand_container)
	_hand_right_arrow = Button.new()
	_hand_right_arrow.text = ">"
	_hand_right_arrow.custom_minimum_size = Vector2(40, 64)
	_hand_right_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hand_right_arrow.modulate.a = 0.3
	_hand_right_arrow.pressed.connect(func(): hand_scroll_right_pressed.emit())
	hand_row.add_child(_hand_right_arrow)

func _setup_event_block(parent: Control) -> void:
	var ev_panel := PanelContainer.new()
	ev_panel.custom_minimum_size = Vector2(144, 0)
	var ep_sb := StyleBoxFlat.new()
	ep_sb.bg_color = Color(COLOR_PANEL.r * 0.5, COLOR_PANEL.g * 0.5, COLOR_PANEL.b * 0.5, 0.9)
	ep_sb.border_color = COLOR_BORDER
	ep_sb.set_border_width_all(1)
	ev_panel.add_theme_stylebox_override("panel", ep_sb)
	ev_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ev_panel)
	var ev_vb := VBoxContainer.new()
	ev_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ev_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	ev_panel.add_child(ev_vb)
	var ev_title := Label.new()
	ev_title.text = "EVENT"
	ev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_title.add_theme_font_size_override("font_size", 10)
	ev_title.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	ev_vb.add_child(ev_title)
	var ev_grid := GridContainer.new()
	ev_grid.columns = 2
	ev_grid.add_theme_constant_override("h_separation", 4)
	ev_grid.add_theme_constant_override("v_separation", 4)
	ev_vb.add_child(ev_grid)
	for _ei in range(4):
		var cell_panel := PanelContainer.new()
		cell_panel.custom_minimum_size = Vector2(68, 68)
		var cp_sb := StyleBoxFlat.new()
		cp_sb.bg_color = Color(COLOR_PANEL.r, COLOR_PANEL.g, COLOR_PANEL.b, 0.5)
		cp_sb.border_color = COLOR_BORDER
		cp_sb.set_border_width_all(1)
		cell_panel.add_theme_stylebox_override("panel", cp_sb)
		cell_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ev_grid.add_child(cell_panel)
		var cell_vb := VBoxContainer.new()
		cell_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cell_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		cell_panel.add_child(cell_vb)
		var lock_lbl := Label.new()
		lock_lbl.text = "[L]"
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_size_override("font_size", 18)
		lock_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		cell_vb.add_child(lock_lbl)
		var locked_lbl := Label.new()
		locked_lbl.text = "LOCKED"
		locked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_lbl.add_theme_font_size_override("font_size", 9)
		locked_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		cell_vb.add_child(locked_lbl)
	var ev_sub := Label.new()
	ev_sub.text = "v0.3 future"
	ev_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_sub.add_theme_font_size_override("font_size", 8)
	ev_sub.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	ev_vb.add_child(ev_sub)
