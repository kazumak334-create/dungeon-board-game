# GameUI.gd
# UI描画・更新処理（Main.gdから分離）
extends RefCounted

var main: Node = null
var _EDB = null  # EffectDBキャッシュ
var _char_hp_bars: Array = [null, null]    # [side] -> ColorRect (HPバー)
var _char_hp_labels: Array = [null, null]  # [side] -> Label (HP数値)
var _char_panels: Array = [null, null]     # [side] -> Panel
var _damage_floats: Array = []             # [{label, timer, velocity}]

func setup(p_main: Node) -> void:
	main = p_main
	_EDB = load("res://scripts/EffectDB.gd")

# ---- UI構築 ----
func build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.11)
	bg.size  = Vector2(1280, 720)
	main.add_child(bg)

	# タイトル
	var title := Label.new()
	title.text = "Dungeon Board Game  Phase 1 Prototype"
	title.position = Vector2(20, 8)
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color(0.9, 0.85, 0.55)
	main.add_child(title)

	# 中央ライン
	var line := ColorRect.new()
	line.color    = Color(0.4, 0.4, 0.5, 0.5)
	line.size     = Vector2(2, 3 * main.CELL_H + 10)
	line.position = Vector2(main.CENTER_X - 1, main.BOARD_TOP - 5)
	main.add_child(line)

	# 行ラベル（左端）
	var row_names := ["上", "中", "下"]
	for r in range(3):
		var lbl := Label.new()
		lbl.text     = row_names[r]
		lbl.position = Vector2(_cell_x(0, 0) - 22, main.BOARD_TOP + r * main.CELL_H + 35)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.modulate = Color(0.6, 0.6, 0.6)
		main.add_child(lbl)

	# 列ラベル
	var player_col_labels := ["後列", "中列", "前列"]
	for c in range(3):
		var x: int = _cell_x(0, c)
		var lbl := Label.new()
		lbl.text     = player_col_labels[c]
		lbl.position = Vector2(x + 28, main.BOARD_TOP - 20)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.5, 0.75, 1.0)
		main.add_child(lbl)

	var enemy_col_labels := ["前列", "中列", "後列"]
	for c in range(3):
		var x: int = _cell_x(1, c)
		var lbl := Label.new()
		lbl.text     = enemy_col_labels[c]
		lbl.position = Vector2(x + 28, main.BOARD_TOP - 20)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(1.0, 0.5, 0.5)
		main.add_child(lbl)

	# 自陣・敵陣ラベル
	var pl := Label.new()
	pl.text     = "自  陣"
	pl.position = Vector2(_cell_x(0, 0) + 60, main.BOARD_TOP - 40)
	pl.add_theme_font_size_override("font_size", 15)
	pl.modulate = Color(0.4, 0.8, 1.0)
	main.add_child(pl)

	var el := Label.new()
	el.text     = "敵  陣"
	el.position = Vector2(_cell_x(1, 0) + 60, main.BOARD_TOP - 40)
	el.add_theme_font_size_override("font_size", 15)
	el.modulate = Color(1.0, 0.45, 0.45)
	main.add_child(el)

	# セル生成
	main.cell_rects  = [[], []]
	main.cell_labels = [[], []]
	for side in range(2):
		for r in range(3):
			main.cell_rects[side].append([])
			main.cell_labels[side].append([])
			for c in range(3):
				var x: int = _cell_x(side, c)
				var rect := ColorRect.new()
				rect.size     = Vector2(main.CELL_W - 4, main.CELL_H - 4)
				rect.position = Vector2(x + 2, main.BOARD_TOP + r * main.CELL_H + 2)
				rect.color    = Color(0.13, 0.13, 0.2)
				rect.mouse_entered.connect(on_cell_hover.bind(side, r, c))
				rect.mouse_exited.connect(on_cell_hover_end)
				main.add_child(rect)
				main.cell_rects[side][r].append(rect)

				var lbl := Label.new()
				lbl.position  = rect.position + Vector2(5, 4)
				lbl.size      = rect.size - Vector2(6, 6)
				lbl.add_theme_font_size_override("font_size", 12)
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				main.add_child(lbl)
				main.cell_labels[side][r].append(lbl)

	# ---- プレイヤー/敵キャラ立絵+HPバー ----
	_build_character_panel(0)  # プレイヤー側
	_build_character_panel(1)  # 敵側

	# 旧HP表示（互換）
	var base_y: int = main.BOARD_TOP + 3 * main.CELL_H + 12
	main.player_base_label = Label.new()
	main.player_base_label.position = Vector2(_cell_x(0, 0), base_y)
	main.player_base_label.add_theme_font_size_override("font_size", 14)
	main.player_base_label.modulate = Color(0.4, 0.9, 0.4)
	main.player_base_label.visible = false  # 立絵+HPバーに移行
	main.add_child(main.player_base_label)

	main.enemy_base_label = Label.new()
	main.enemy_base_label.position = Vector2(_cell_x(1, 0), base_y)
	main.enemy_base_label.add_theme_font_size_override("font_size", 14)
	main.enemy_base_label.modulate = Color(1.0, 0.45, 0.45)
	main.enemy_base_label.visible = false
	main.add_child(main.enemy_base_label)

	# 盤面セルホバー用ツールチップ
	main._cell_tooltip_panel = PanelContainer.new()
	main._cell_tooltip_panel.position = Vector2(10, 10)
	main._cell_tooltip_panel.visible = false
	main._cell_tooltip_panel.z_index = 90
	var tt_style := StyleBoxFlat.new()
	tt_style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	tt_style.border_color = Color(0.4, 0.5, 0.7)
	tt_style.set_border_width_all(1)
	tt_style.set_content_margin_all(8)
	main._cell_tooltip_panel.add_theme_stylebox_override("panel", tt_style)
	main._cell_tooltip_label = Label.new()
	main._cell_tooltip_label.add_theme_font_size_override("font_size", 11)
	main._cell_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main._cell_tooltip_label.custom_minimum_size = Vector2(250, 0)
	main._cell_tooltip_panel.add_child(main._cell_tooltip_label)
	main.add_child(main._cell_tooltip_panel)

	# ---- マナバー ----
	_build_mana_bar()

	# ---- 装備表示UI ----
	_build_equipment_ui()

	# ---- 次カードパネル ----
	_build_next_card_panel()

	# ---- ログ ----
	var log_bg := ColorRect.new()
	log_bg.position = Vector2(1020, main.BOARD_TOP - 10)
	log_bg.size     = Vector2(245, 3 * main.CELL_H + 30)
	log_bg.color    = Color(0.04, 0.04, 0.07)
	main.add_child(log_bg)

	var log_title := Label.new()
	log_title.text     = "ログ"
	log_title.position = Vector2(1028, main.BOARD_TOP - 6)
	log_title.modulate = Color(0.7, 0.7, 0.5)
	main.add_child(log_title)

	main.log_label = Label.new()
	main.log_label.position       = Vector2(1025, main.BOARD_TOP + 14)
	main.log_label.size           = Vector2(235, 3 * main.CELL_H)
	main.log_label.add_theme_font_size_override("font_size", 11)
	main.log_label.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	main.log_label.modulate       = Color(0.78, 0.78, 0.78)
	main.add_child(main.log_label)

	# ---- ゲームオーバー ----
	main.game_over_label = Label.new()
	main.game_over_label.position = Vector2(340, 270)
	main.game_over_label.add_theme_font_size_override("font_size", 72)
	main.game_over_label.visible  = false
	main.add_child(main.game_over_label)

	main.restart_button = Button.new()
	main.restart_button.text     = "もう一度"
	main.restart_button.position = Vector2(540, 380)
	main.restart_button.size     = Vector2(200, 56)
	main.restart_button.add_theme_font_size_override("font_size", 26)
	main.restart_button.visible  = false
	main.restart_button.pressed.connect(main._on_restart_pressed)
	main.add_child(main.restart_button)

	# ゲームスピード調整
	_build_speed_buttons()

func _build_speed_buttons() -> void:
	var speeds = [1.0, 2.0, 4.0]
	var labels = ["x1", "x2", "x4"]
	var base_x = 1100
	var base_y = 8

	var speed_title = Label.new()
	speed_title.text = "速度:"
	speed_title.position = Vector2(base_x - 40, base_y + 5)
	speed_title.add_theme_font_size_override("font_size", 13)
	speed_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main.add_child(speed_title)

	for i in range(speeds.size()):
		var btn = Button.new()
		btn.text = labels[i]
		btn.position = Vector2(base_x + i * 55, base_y)
		btn.size = Vector2(50, 28)
		btn.add_theme_font_size_override("font_size", 13)
		var spd = speeds[i]
		btn.pressed.connect(func(): main.game_speed = spd)
		main.add_child(btn)

func _build_mana_bar() -> void:
	var bar_y: int = main.BOARD_TOP + 3 * main.CELL_H + 42
	var bar_x: int = _cell_x(0, 0)

	var bar_title := Label.new()
	bar_title.text     = "Mana"
	bar_title.position = Vector2(bar_x, bar_y - 18)
	bar_title.add_theme_font_size_override("font_size", 12)
	bar_title.modulate = Color(1.0, 0.85, 0.2)
	main.add_child(bar_title)

	main.mana_bar_cells = []
	for i in range(10):
		var cell := ColorRect.new()
		cell.size     = Vector2(22, 18)
		cell.position = Vector2(bar_x + i * 25, bar_y)
		cell.color    = Color(0.2, 0.2, 0.1)
		main.add_child(cell)
		main.mana_bar_cells.append(cell)

	main.mana_value_label = Label.new()
	main.mana_value_label.position = Vector2(bar_x + 10 * 25 + 6, bar_y)
	main.mana_value_label.add_theme_font_size_override("font_size", 13)
	main.mana_value_label.modulate = Color(1.0, 0.9, 0.3)
	main.add_child(main.mana_value_label)

func _build_equipment_ui() -> void:
	var eq_y: int = main.BOARD_TOP + 3 * main.CELL_H + 68
	var bar_x: int = _cell_x(0, 0)

	var eq_title := Label.new()
	eq_title.text     = "装備"
	eq_title.position = Vector2(bar_x, eq_y - 16)
	eq_title.add_theme_font_size_override("font_size", 11)
	eq_title.modulate = Color(0.85, 0.7, 1.0)
	main.add_child(eq_title)

	main._equip_slots = []
	for i in range(3):
		var slot_bg := ColorRect.new()
		slot_bg.size     = Vector2(90, 20)
		slot_bg.position = Vector2(bar_x + i * 94, eq_y)
		slot_bg.color    = Color(0.1, 0.08, 0.15)
		main.add_child(slot_bg)
		var slot_lbl := Label.new()
		slot_lbl.text     = "─ 空 ─"
		slot_lbl.position = Vector2(bar_x + i * 94 + 4, eq_y + 2)
		slot_lbl.size     = Vector2(84, 18)
		slot_lbl.add_theme_font_size_override("font_size", 10)
		slot_lbl.modulate = Color(0.5, 0.5, 0.5)
		main.add_child(slot_lbl)
		main._equip_slots.append(slot_lbl)
		slot_bg.mouse_entered.connect(_on_equip_hover.bind(i))
		slot_bg.mouse_exited.connect(_on_equip_hover_end)

	# 装備ホバーツールチップ
	main._equip_tooltip_panel = PanelContainer.new()
	main._equip_tooltip_panel.position = Vector2(bar_x, eq_y - 50)
	main._equip_tooltip_panel.visible = false
	main._equip_tooltip_panel.z_index = 90
	var eq_style := StyleBoxFlat.new()
	eq_style.bg_color = Color(0.08, 0.06, 0.14, 0.95)
	eq_style.border_color = Color(0.6, 0.4, 0.9)
	eq_style.set_border_width_all(1)
	eq_style.set_content_margin_all(7)
	main._equip_tooltip_panel.add_theme_stylebox_override("panel", eq_style)
	main._equip_tooltip_label = Label.new()
	main._equip_tooltip_label.add_theme_font_size_override("font_size", 11)
	main._equip_tooltip_label.custom_minimum_size = Vector2(200, 0)
	main._equip_tooltip_panel.add_child(main._equip_tooltip_label)
	main.add_child(main._equip_tooltip_panel)

func _on_equip_hover(slot: int) -> void:
	if main.board_manager.player_data == null:
		return
	var equip: Array = main.board_manager.player_data.equipment
	if slot >= equip.size():
		main._equip_tooltip_panel.visible = false
		return
	var eq: Dictionary = equip[slot]
	main._equip_tooltip_label.text = "%s\n%s" % [eq.get("display", ""), eq.get("effect", "")]
	main._equip_tooltip_panel.visible = true

func _on_equip_hover_end() -> void:
	if main._equip_tooltip_panel != null:
		main._equip_tooltip_panel.visible = false

func _refresh_equipment_ui() -> void:
	if main.board_manager.player_data == null:
		return
	var equip: Array = main.board_manager.player_data.equipment
	for i in range(main._equip_slots.size()):
		if i < equip.size():
			main._equip_slots[i].text    = equip[i].get("display", "?")
			main._equip_slots[i].modulate = Color(0.9, 0.75, 1.0)
		else:
			main._equip_slots[i].text    = "─ 空 ─"
			main._equip_slots[i].modulate = Color(0.5, 0.5, 0.5)

func _build_next_card_panel() -> void:
	var panel_w: int = 360
	var panel_h: int = 110
	var panel_x: int = main.CENTER_X - panel_w / 2
	var panel_y: int = main.BOARD_TOP + 3 * main.CELL_H + 36

	main.next_card_panel = ColorRect.new()
	main.next_card_panel.position = Vector2(panel_x, panel_y)
	main.next_card_panel.size     = Vector2(panel_w, panel_h)
	main.next_card_panel.color    = Color(0.08, 0.10, 0.17)
	main.add_child(main.next_card_panel)

	var border := ColorRect.new()
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.size     = Vector2(panel_w + 4, panel_h + 4)
	border.color    = Color(0.3, 0.5, 0.8, 0.6)
	border.z_index  = -1
	main.add_child(border)

	var title_lbl := Label.new()
	title_lbl.text     = "─── NEXT CARD ───"
	title_lbl.position = Vector2(panel_x + 85, panel_y + 4)
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.modulate = Color(0.5, 0.7, 1.0)
	main.add_child(title_lbl)

	main.next_card_name_label = Label.new()
	main.next_card_name_label.position = Vector2(panel_x + 10, panel_y + 22)
	main.next_card_name_label.add_theme_font_size_override("font_size", 28)
	main.next_card_name_label.modulate = Color(1.0, 1.0, 0.85)
	main.add_child(main.next_card_name_label)

	main.next_card_cost_label = Label.new()
	main.next_card_cost_label.position = Vector2(panel_x + panel_w - 70, panel_y + 16)
	main.next_card_cost_label.add_theme_font_size_override("font_size", 32)
	main.next_card_cost_label.modulate = Color(1.0, 0.85, 0.1)
	main.add_child(main.next_card_cost_label)

	main.next_card_detail_label = Label.new()
	main.next_card_detail_label.position = Vector2(panel_x + 10, panel_y + 60)
	main.next_card_detail_label.add_theme_font_size_override("font_size", 13)
	main.next_card_detail_label.modulate = Color(0.75, 0.85, 0.75)
	main.add_child(main.next_card_detail_label)

	main.next_card_timer_label = Label.new()
	main.next_card_timer_label.position = Vector2(panel_x + 10, panel_y + 88)
	main.next_card_timer_label.add_theme_font_size_override("font_size", 11)
	main.next_card_timer_label.modulate = Color(0.55, 0.55, 0.7)
	main.add_child(main.next_card_timer_label)

	main.enemy_next_label = Label.new()
	main.enemy_next_label.position = Vector2(panel_x + panel_w + 8, panel_y + 20)
	main.enemy_next_label.add_theme_font_size_override("font_size", 13)
	main.enemy_next_label.modulate = Color(1.0, 0.5, 0.5)
	main.add_child(main.enemy_next_label)

	var deck_y: int = panel_y + panel_h + 6
	main.deck_count_label = Label.new()
	main.deck_count_label.position = Vector2(panel_x, deck_y)
	main.deck_count_label.add_theme_font_size_override("font_size", 12)
	main.deck_count_label.modulate = Color(0.6, 0.8, 1.0)
	main.add_child(main.deck_count_label)

	main.discard_count_label = Label.new()
	main.discard_count_label.position = Vector2(panel_x + 130, deck_y)
	main.discard_count_label.add_theme_font_size_override("font_size", 12)
	main.discard_count_label.modulate = Color(0.5, 0.5, 0.7)
	main.add_child(main.discard_count_label)

	main.enemy_deck_count_label = Label.new()
	main.enemy_deck_count_label.position = Vector2(panel_x + panel_w + 8, panel_y + 60)
	main.enemy_deck_count_label.add_theme_font_size_override("font_size", 12)
	main.enemy_deck_count_label.modulate = Color(1.0, 0.5, 0.5)
	main.add_child(main.enemy_deck_count_label)

# ---- キャラクターパネル ----

func _build_character_panel(side: int) -> void:
	var panel_w = 80
	var panel_h = 120
	var panel_x: int
	if side == 0:
		panel_x = _cell_x(0, 0) - panel_w - 15  # プレイヤー側：盤面左端のさらに左
	else:
		panel_x = _cell_x(1, 2) + main.CELL_W + 15  # 敵側：盤面右端のさらに右
	var panel_y = main.BOARD_TOP + 1 * main.CELL_H - 15  # 中段の高さ

	# パネル背景
	var panel = Panel.new()
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_w, panel_h)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.5, 0.3) if side == 0 else Color(0.5, 0.3, 0.3)
	panel.add_theme_stylebox_override("panel", style)
	main.add_child(panel)
	_char_panels[side] = panel

	# キャラ名
	var name_label = Label.new()
	name_label.text = "プレイヤー" if side == 0 else "敵"
	name_label.position = Vector2(panel_x + 5, panel_y + 5)
	name_label.size = Vector2(panel_w - 10, 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7) if side == 0 else Color(0.85, 0.7, 0.7))
	main.add_child(name_label)

	# 立絵プレースホルダ（将来テクスチャに差し替え）
	var portrait = ColorRect.new()
	portrait.position = Vector2(panel_x + 15, panel_y + 25)
	portrait.size = Vector2(50, 50)
	portrait.color = Color(0.25, 0.3, 0.2) if side == 0 else Color(0.3, 0.2, 0.2)
	main.add_child(portrait)

	var portrait_label = Label.new()
	portrait_label.text = "P" if side == 0 else "E"
	portrait_label.position = Vector2(panel_x + 30, panel_y + 38)
	portrait_label.add_theme_font_size_override("font_size", 20)
	portrait_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5) if side == 0 else Color(0.8, 0.5, 0.5))
	main.add_child(portrait_label)

	# HPバー背景
	var hp_bg = ColorRect.new()
	hp_bg.position = Vector2(panel_x + 5, panel_y + 82)
	hp_bg.size = Vector2(70, 10)
	hp_bg.color = Color(0.2, 0.2, 0.2)
	main.add_child(hp_bg)

	# HPバー
	var hp_bar = ColorRect.new()
	hp_bar.position = Vector2(panel_x + 5, panel_y + 82)
	hp_bar.size = Vector2(70, 10)
	hp_bar.color = Color(0.3, 0.9, 0.4) if side == 0 else Color(0.9, 0.3, 0.3)
	main.add_child(hp_bar)
	_char_hp_bars[side] = hp_bar

	# HP数値
	var hp_label = Label.new()
	hp_label.position = Vector2(panel_x + 5, panel_y + 95)
	hp_label.size = Vector2(70, 18)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hp_label.text = "%d" % main.base_hp[side]
	main.add_child(hp_label)
	_char_hp_labels[side] = hp_label

# ---- ダメージフロート ----

func spawn_damage_float(side: int, row: int, col: int, amount: int, is_heal: bool = false) -> void:
	var x = _cell_x(side, col) + main.CELL_W / 2 - 15
	var y = main.BOARD_TOP + row * main.CELL_H + 10
	var label = Label.new()
	label.text = "+%d" % amount if is_heal else "-%d" % amount
	label.position = Vector2(x, y)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3) if is_heal else Color(0.9, 0.3, 0.2))
	label.z_index = 50
	main.add_child(label)
	_damage_floats.append({"label": label, "timer": 1.0, "y_start": y})

func spawn_base_damage_float(side: int, amount: int) -> void:
	var panel = _char_panels[side]
	if panel == null:
		return
	var x = panel.position.x + 20
	var y = panel.position.y + 40
	var label = Label.new()
	label.text = "-%d" % amount
	label.position = Vector2(x, y)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	label.z_index = 50
	main.add_child(label)
	_damage_floats.append({"label": label, "timer": 1.2, "y_start": y})

func update_damage_floats(delta: float) -> void:
	var to_remove: Array = []
	for i in range(_damage_floats.size()):
		var d = _damage_floats[i]
		d["timer"] -= delta
		if d["timer"] <= 0:
			d["label"].queue_free()
			to_remove.append(i)
		else:
			# 上に浮かぶ + フェードアウト
			d["label"].position.y = d["y_start"] - (1.0 - d["timer"]) * 30.0
			d["label"].modulate.a = d["timer"]
	for i in range(to_remove.size() - 1, -1, -1):
		_damage_floats.remove_at(to_remove[i])

# ---- セルのX座標計算 ----
func _cell_x(side: int, col: int) -> int:
	if side == 0:
		return main.CENTER_X - main.GAP / 2 - (3 - col) * main.CELL_W
	else:
		return main.CENTER_X + main.GAP / 2 + col * main.CELL_W

# ---- UI更新 ----
func update_ui() -> void:
	_update_cells()
	update_base_hp()
	_update_mana()
	_update_next_card()
	_update_deck_counts()

func _update_cells() -> void:
	for side in range(2):
		for r in range(3):
			for c in range(3):
				var has_flash: bool = main.skill_flash_timers[side][r][c] > 0.0
				var has_tile_effect: bool = main.board_manager.board_effects[side][r][c] != null
				var has_artifact: bool = main.board_manager.board_artifacts[side][r][c] != null
				if not main._cell_dirty[side][r][c] and not has_flash and not has_tile_effect and not has_artifact:
					continue
				render_cell(side, r, c)
				if not has_flash:
					main._cell_dirty[side][r][c] = false

func render_cell(side: int, r: int, c: int) -> void:
	var unit   = main.board_manager.get_unit(side, r, c)
	var artifact = main.board_manager.board_artifacts[side][r][c]
	var rect: ColorRect = main.cell_rects[side][r][c]
	var lbl:  Label     = main.cell_labels[side][r][c]
	if artifact != null and unit == null:
		if main.skill_flash_timers[side][r][c] > 0.0:
			var f: float = main.skill_flash_timers[side][r][c]
			rect.color = Color(0.9, 0.75 * f + 0.1, 0.0)
		else:
			rect.color = Color(0.11, 0.11, 0.17)
		var art_hp: int = artifact.get("hp", 0)
		var art_max_hp: int = artifact.get("max_hp", 1)
		var art_hp_ratio: float = float(art_hp) / float(max(1, art_max_hp))
		var art_bar_filled: int = int(art_hp_ratio * 6)
		var art_hp_bar: String = "█".repeat(art_bar_filled) + "░".repeat(6 - art_bar_filled)
		lbl.text = "【%s】\n%s HP%d/%d" % [artifact.get("name", "?"), art_hp_bar, art_hp, art_max_hp]
		return
	if unit != null:
		var hp_ratio: float = float(unit.current_hp) / float(unit.max_hp)
		if main.skill_flash_timers[side][r][c] > 0.0:
			var f: float = main.skill_flash_timers[side][r][c]
			rect.color = Color(0.9, 0.75 * f + 0.1, 0.0)
		else:
			rect.color = Color(0.11, 0.11, 0.17)
		var bar_filled: int = int(hp_ratio * 8)
		var hp_bar: String = "█".repeat(bar_filled) + "░".repeat(8 - bar_filled)
		var buffs: Array = []
		if unit._atk_bonus > 0:        buffs.append("ATK+%d" % unit._atk_bonus)
		if unit._interval_bonus > 0.0:  buffs.append("SPD+")
		if unit._damage_reduction > 0:  buffs.append("鎧%d" % unit._damage_reduction)
		if unit.lifesteal_stacks > 0:   buffs.append("吸血%d" % unit.lifesteal_stacks)
		if unit._regen_stacks > 0:      buffs.append("再生%d" % unit._regen_stacks)
		if unit._temp_atk_bonus > 0:    buffs.append("ATK↑%d" % unit._temp_atk_bonus)
		if unit._temp_spd_bonus > 0.0:  buffs.append("SPD↑")
		if unit.burn_turns > 0:         buffs.append("火傷%d" % unit.burn_turns)
		if unit.frozen_turns > 0:       buffs.append("凍結%d" % unit.frozen_turns)
		if unit.paralysis_turns > 0:    buffs.append("麻痺%d" % unit.paralysis_turns)
		if unit.poison_stacks > 0:      buffs.append("毒%d" % unit.poison_stacks)
		if unit._invincible_timer > 0.0: buffs.append("無敵")
		var buff_line: String = (" ".join(buffs)) if not buffs.is_empty() else ""
		var flash_line: String = ""
		if main.skill_flash_timers[side][r][c] > 0.0:
			flash_line = "★" + main.skill_flash_names[side][r][c] + "!"
		var lines: Array = [
			unit.unit_name,
			"%s HP%d/%d ATK%d" % [hp_bar, unit.current_hp, unit.max_hp, unit.attack],
		]
		if buff_line != "": lines.append(buff_line)
		if flash_line != "": lines.append(flash_line)
		lbl.text = "\n".join(lines)
	else:
		rect.color = Color(0.11, 0.11, 0.17)
		lbl.text   = ""
	# 盤面効果の可視化
	var te_vis = main.board_manager.board_effects[side][r][c]
	if te_vis != null:
		var tile_id: String = te_vis["effect_id"]
		var tile_def = _EDB.EFFECTS.get(tile_id, {})
		var tile_display: String = tile_def.get("display", tile_id)
		var tile_color: Array = tile_def.get("color", [])
		if tile_color.size() == 4:
			rect.color = rect.color.lerp(Color(tile_color[0], tile_color[1], tile_color[2]), tile_color[3])
		var unit_label: String = tile_def.get("unit_label", "")
		var race_filter: String = tile_def.get("race", "")
		if lbl.text == "":
			lbl.text = tile_display
		else:
			if unit != null and unit.get("_is_flying") == true:
				pass
			elif race_filter != "" and (unit == null or unit.race != race_filter):
				pass
			elif unit_label != "":
				lbl.text = lbl.text + "\n[%s]" % unit_label

func update_base_hp() -> void:
	main.player_base_label.text = "自陣 本体HP: %d / 30" % main.base_hp[0]
	main.enemy_base_label.text  = "敵陣 本体HP: %d / 30" % main.base_hp[1]
	# HPバー更新
	for side in range(2):
		if _char_hp_bars[side] != null:
			var ratio = float(main.base_hp[side]) / 30.0
			_char_hp_bars[side].size.x = int(70.0 * max(0.0, ratio))
			var color = Color(0.3, 0.9, 0.4) if side == 0 else Color(0.9, 0.3, 0.3)
			if ratio < 0.3:
				color = Color(0.9, 0.2, 0.2)
			_char_hp_bars[side].color = color
		if _char_hp_labels[side] != null:
			_char_hp_labels[side].text = "%d" % main.base_hp[side]

func _update_mana() -> void:
	var filled: int = int(main.deck_manager.mana)
	for i in range(10):
		var cell: ColorRect = main.mana_bar_cells[i]
		if i < filled:
			cell.color = Color(1.0, 0.85, 0.1)
		else:
			cell.color = Color(0.18, 0.17, 0.07)
	main.mana_value_label.text = "%.1f / 10" % main.deck_manager.mana

func _update_next_card() -> void:
	var next = main.deck_manager.get_next_card()
	if next == null:
		main.next_card_name_label.text   = "（なし）"
		main.next_card_detail_label.text = ""
		main.next_card_cost_label.text   = ""
		main.next_card_timer_label.text  = ""
		return

	if next.card_type != "unit":
		var prefix: String = "【呪文】" if next.card_type == "spell" else "【異常】"
		main.next_card_name_label.text = prefix + next.unit_name
		main.next_card_name_label.modulate = Color(0.8, 0.6, 1.0)
		var cost_text: String = "Cost X" if next.cost == -1 else "Cost %d" % next.cost
		main.next_card_cost_label.text = cost_text
		main.next_card_cost_label.modulate = Color(0.3, 1.0, 0.4) if main.deck_manager.mana >= next.cost else Color(1.0, 0.85, 0.1)
		main.next_card_detail_label.text = next.spell_effect
	else:
		main.next_card_name_label.modulate = Color(1.0, 1.0, 0.85)
		var col_names: Array = ["前列", "中列", "後列"]
		var col_name: String = col_names[next.assigned_col]
		main.next_card_name_label.text = next.unit_name
		main.next_card_cost_label.text = "Cost %d" % next.cost
		if main.deck_manager.mana >= next.cost:
			main.next_card_cost_label.modulate = Color(0.3, 1.0, 0.4)
		else:
			main.next_card_cost_label.modulate = Color(1.0, 0.85, 0.1)
		main.next_card_detail_label.text = "HP %d  ATK %d  配置:%s  攻撃間隔:%.1fs" % [
			next.max_hp, next.attack, col_name, next.attack_interval
		]

	var remain: float = main.deck_manager._check_timer
	var interval: float = main.deck_manager.check_interval
	main.next_card_timer_label.text = "発動チェック: %.1fs 後（間隔 %.1fs）" % [remain, interval]

	var enemy_next = main.enemy_ai.get_next_card()
	if enemy_next != null:
		var cost_ok: bool = main.enemy_ai.mana >= enemy_next.cost
		main.enemy_next_label.modulate = Color(0.3, 1.0, 0.4) if cost_ok else Color(1.0, 0.5, 0.5)
		main.enemy_next_label.text = "次の敵：%s\nマナ %.1f/10  Cost %d" % [
			enemy_next.unit_name, main.enemy_ai.mana, enemy_next.cost
		]
	else:
		main.enemy_next_label.text = ""

func _update_deck_counts() -> void:
	main.deck_count_label.text    = "自デッキ: %d枚" % main.deck_manager.deck.size()
	main.discard_count_label.text = "捨て札: %d枚" % main.deck_manager.discard.size()
	main.enemy_deck_count_label.text = "敵デッキ: %d枚\n敵捨て札: %d枚" % [
		main.enemy_ai.enemy_deck.size(), main.enemy_ai.enemy_discard.size()
	]

func on_cell_hover(side: int, r: int, c: int) -> void:
	var unit = main.board_manager.board[side][r][c]
	var te_hover = main.board_manager.board_effects[side][r][c]
	var art_hover = main.board_manager.board_artifacts[side][r][c]
	if unit == null and te_hover == null and art_hover == null:
		main._cell_tooltip_panel.visible = false
		return
	# アーティファクト表示
	if art_hover != null and unit == null:
		var art_lines: Array = []
		art_lines.append("[アーティファクト] %s" % art_hover.get("name", "?"))
		art_lines.append("HP: %d / %d" % [art_hover.get("hp", 0), art_hover.get("max_hp", 0)])
		var art_skill_lines: Array = []
		for sk in art_hover.get("skills", []):
			var eid_ah: String = sk.get("effect_id", "")
			var disp_ah: String = _EDB.EFFECTS.get(eid_ah, {}).get("display", eid_ah)
			var trig_ah: String = sk.get("trigger", "")
			if trig_ah == "timer":
				var intv_ah: float = sk.get("params", {}).get("interval", 0)
				art_skill_lines.append("- %s（%ds毎）" % [disp_ah, int(intv_ah)])
			else:
				art_skill_lines.append("- %s（%s）" % [disp_ah, trig_ah])
		if art_skill_lines.size() > 0:
			art_lines.append("")
			art_lines.append("■ スキル:")
			art_lines.append_array(art_skill_lines)
		main._cell_tooltip_label.text = "\n".join(art_lines)
		main._cell_tooltip_panel.visible = true
		main._cell_tooltip_panel.size = Vector2(265, 0)
		return
	if unit == null:
		var tile_def_h = _EDB.EFFECTS.get(te_hover["effect_id"], {})
		var tile_display_h: String = tile_def_h.get("display", te_hover["effect_id"])
		var remaining_str_h: String = "永続" if te_hover["remaining"] < 0 else "%ds" % int(te_hover["remaining"])
		main._cell_tooltip_label.text = "■ 盤面効果: %s（%s）" % [tile_display_h, remaining_str_h]
		main._cell_tooltip_panel.visible = true
		main._cell_tooltip_panel.size = Vector2(265, 0)
		return
	var trigger_jp: Dictionary = {"always": "常時", "on_summon": "召喚時", "on_hit": "命中時", "on_kill": "撃破時", "on_death": "死亡時", "timer": "時間経過"}
	var target_jp: Dictionary = {"self": "自身", "front_one": "前方1体", "same_row": "同段", "same_row_beast": "同段の獣", "same_col_ally": "同深度の味方", "adjacent_beast": "隣接の獣", "all_allies": "味方全体", "all_enemies": "敵全体", "hit_target": "攻撃対象", "enemy_most_buffs": "バフ最多の敵", "ally_undead_lowest": "最低HPアンデッド", "enemy_max_hp": "最大HP敵", "self_deck": "自デッキ", "front_enemy": "前列の敵", "adjacent_enemy": "隣接の敵", "enemy": "敵"}
	var lines: Array = []
	lines.append("[%s] %s" % [unit.race, unit.unit_name])
	lines.append("Cost: %d / HP: %d/%d / ATK: %d / SPD: %.1fs" % [unit.cost, unit.current_hp, unit.max_hp, unit.attack, unit.attack_interval])
	var support_lines: Array = []
	var active_lines: Array = []
	for skill in unit.skills:
		var eid: String = skill.get("effect_id", "")
		var display: String = eid
		if _EDB != null and _EDB.EFFECTS.has(eid):
			display = _EDB.EFFECTS[eid].get("display", eid)
		var trigger: String = skill.get("trigger", "")
		var tgt: String = skill.get("target", "")
		var t_jp: String = trigger_jp.get(trigger, trigger)
		var tgt_jp: String = target_jp.get(tgt, tgt)
		if trigger == "timer":
			var interval = skill.get("params", {}).get("interval", 0)
			t_jp = "%ds毎" % int(interval)
		var entry: String = "- %s（%s, %s）" % [display, t_jp, tgt_jp]
		if trigger == "always":
			support_lines.append(entry)
		else:
			active_lines.append(entry)
	if support_lines.size() > 0:
		lines.append("")
		lines.append("■ サポート効果:")
		lines.append_array(support_lines)
	if active_lines.size() > 0:
		lines.append("")
		lines.append("■ パッシブスキル:")
		lines.append_array(active_lines)
	var buffs_h: Array = []
	if unit._atk_bonus > 0:        buffs_h.append("ATK+%d" % unit._atk_bonus)
	if unit._interval_bonus > 0.0:  buffs_h.append("SPD+")
	if unit._damage_reduction > 0:  buffs_h.append("鎧%d" % unit._damage_reduction)
	if unit.lifesteal_stacks > 0:   buffs_h.append("吸血%d" % unit.lifesteal_stacks)
	if unit._regen_stacks > 0:      buffs_h.append("再生%d" % unit._regen_stacks)
	if unit.burn_turns > 0:         buffs_h.append("火傷%d" % unit.burn_turns)
	if unit.frozen_turns > 0:       buffs_h.append("凍結%d" % unit.frozen_turns)
	if unit.paralysis_turns > 0:    buffs_h.append("麻痺%d" % unit.paralysis_turns)
	if unit.poison_stacks > 0:      buffs_h.append("毒%d" % unit.poison_stacks)
	if unit._invincible_timer > 0.0: buffs_h.append("無敵")
	if buffs_h.size() > 0:
		lines.append("")
		lines.append("■ バフ/デバフ: " + " ".join(buffs_h))
	if te_hover != null:
		var tile_def_hover = _EDB.EFFECTS.get(te_hover["effect_id"], {})
		var tile_display_hover: String = tile_def_hover.get("display", te_hover["effect_id"])
		var remaining_str: String = "永続" if te_hover["remaining"] < 0 else "%ds" % int(te_hover["remaining"])
		lines.append("")
		lines.append("■ 盤面効果: %s（%s）" % [tile_display_hover, remaining_str])
	main._cell_tooltip_label.text = "\n".join(lines)
	main._cell_tooltip_panel.visible = true
	main._cell_tooltip_panel.size = Vector2(265, 0)

func on_cell_hover_end() -> void:
	main._cell_tooltip_panel.visible = false

func mark_all_cells_dirty() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				main._cell_dirty[s][r][c] = true

func add_log(text: String) -> void:
	var ms: float = float(Time.get_ticks_msec()) * 0.001
	main.log_lines.append("[%.1fs] %s" % [ms, text])
	if main.log_lines.size() > 22:
		main.log_lines.pop_front()
	main.log_label.text = "\n".join(main.log_lines)
