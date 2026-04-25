# GameUIQueue.gd
# キュー+デッキ情報UI（GameUI.gdから分離）
extends Control

var main: Node = null
var _EDB = null

var _queue_self_deck_label: Label = null  # 自デッキ山ラベル（互換用・非表示）
var _queue_mana_bar: ColorRect = null     # キューエリア内マナゲージ
var _queue_mana_label: Label = null       # キューエリア内マナ数値
var _overlay = null  # GameUIOverlayへの参照（デッキカウント更新用）

# 呪文スロットUI（Q1/Q2/Q3に配置）
var _spell_slot_panels: Array = []  # 3スロット分のUIノード辞書配列

# Phase A: 呪文スロット色定義
const COLOR_SLOT_EMPTY       = Color(0.08, 0.10, 0.14, 0.8)
const COLOR_SLOT_LOADED_OFF  = Color(0.12, 0.15, 0.22)
const COLOR_SLOT_READY_BG    = Color(0.18, 0.32, 0.22)
const COLOR_SLOT_GLOW        = Color(0.6, 1.0, 0.7, 0.85)
const COLOR_LABEL_READY      = Color(1.0, 1.0, 1.0)
const COLOR_LABEL_DISABLED   = Color(0.5, 0.5, 0.5)
const COLOR_LABEL_EMPTY      = Color(0.5, 0.5, 0.5)
const COLOR_READY_ACCENT     = Color(0.4, 1.0, 0.5)
const COLOR_FAIL_ACCENT      = Color(1.0, 0.35, 0.35)

func build() -> void:
	_build_next_card_panel()
	# _build_card_queue_ui() は _build_next_card_panel 末尾から呼び出し済み

func _build_next_card_panel() -> void:
	var panel_w: int = 360
	var panel_h: int = 110
	var panel_x: int = main.CENTER_X - panel_w / 2
	var panel_y: int = main.BOARD_TOP + 3 * main.CELL_H + 36

	# ---- 既存パネル（互換のため維持・非表示） ----
	main.next_card_panel = ColorRect.new()
	main.next_card_panel.position = Vector2(panel_x, panel_y)
	main.next_card_panel.size     = Vector2(panel_w, panel_h)
	main.next_card_panel.color    = Color(0.08, 0.10, 0.17)
	main.next_card_panel.visible  = false
	main.add_child(main.next_card_panel)

	var border := ColorRect.new()
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.size     = Vector2(panel_w + 4, panel_h + 4)
	border.color    = Color(0.3, 0.5, 0.8, 0.6)
	border.z_index  = -1
	border.visible  = false
	main.add_child(border)

	var title_lbl := Label.new()
	title_lbl.text     = "─── NEXT CARD ───"
	title_lbl.position = Vector2(panel_x + 85, panel_y + 4)
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.modulate = Color(0.5, 0.7, 1.0)
	title_lbl.visible  = false
	main.add_child(title_lbl)

	main.next_card_name_label = Label.new()
	main.next_card_name_label.position = Vector2(panel_x + 10, panel_y + 22)
	main.next_card_name_label.add_theme_font_size_override("font_size", 28)
	main.next_card_name_label.modulate = Color(1.0, 1.0, 0.85)
	main.next_card_name_label.visible  = false
	main.add_child(main.next_card_name_label)

	main.next_card_cost_label = Label.new()
	main.next_card_cost_label.position = Vector2(panel_x + panel_w - 70, panel_y + 16)
	main.next_card_cost_label.add_theme_font_size_override("font_size", 32)
	main.next_card_cost_label.modulate = Color(1.0, 0.85, 0.1)
	main.next_card_cost_label.visible  = false
	main.add_child(main.next_card_cost_label)

	main.next_card_detail_label = Label.new()
	main.next_card_detail_label.position = Vector2(panel_x + 10, panel_y + 60)
	main.next_card_detail_label.add_theme_font_size_override("font_size", 13)
	main.next_card_detail_label.modulate = Color(0.75, 0.85, 0.75)
	main.next_card_detail_label.visible  = false
	main.add_child(main.next_card_detail_label)

	main.next_card_timer_label = Label.new()
	main.next_card_timer_label.position = Vector2(panel_x + 10, panel_y + 88)
	main.next_card_timer_label.add_theme_font_size_override("font_size", 11)
	main.next_card_timer_label.modulate = Color(0.55, 0.55, 0.7)
	main.next_card_timer_label.visible  = false
	main.add_child(main.next_card_timer_label)

	var deck_y: int = panel_y + panel_h + 6
	main.deck_count_label = Label.new()
	main.deck_count_label.position = Vector2(panel_x, deck_y)
	main.deck_count_label.add_theme_font_size_override("font_size", 12)
	main.deck_count_label.modulate = Color(0.6, 0.8, 1.0)
	main.deck_count_label.visible  = false
	main.add_child(main.deck_count_label)

	main.discard_count_label = Label.new()
	main.discard_count_label.position = Vector2(panel_x + 130, deck_y)
	main.discard_count_label.add_theme_font_size_override("font_size", 12)
	main.discard_count_label.modulate = Color(0.5, 0.5, 0.7)
	main.discard_count_label.visible  = false
	main.add_child(main.discard_count_label)

	# ---- 新カードキューUI ----
	_build_card_queue_ui()

func _build_card_queue_ui() -> void:
	var cell_w: float = main.CELL_W
	var queue_y: int = main.BOARD_TOP + 3 * main.CELL_H + 15
	var card_h: float = 220.0

	# 座標ヘルパー（GameUI._cell_x相当）
	# 自陣: col X = CENTER_X - GAP/2 - (3-col)*CELL_W
	# 敵陣: col X = CENTER_X + GAP/2 + col*CELL_W
	var cx: float = main.CENTER_X
	var gap: float = main.GAP

	# 自キュー座標: Q1=前列(col2), Q2=中列(col1), Q3=後列(col0)
	var self_q1_x: float = cx - gap / 2.0 - (3 - 2) * cell_w  # col2: 前列
	var self_q2_x: float = cx - gap / 2.0 - (3 - 1) * cell_w  # col1: 中列
	var self_q3_x: float = cx - gap / 2.0 - (3 - 0) * cell_w  # col0: 後列

	# 敵キュー座標: Q1=前列(col0), Q2=中列(col1), Q3=後列(col2)
	var enemy_q1_x: float = cx + gap / 2.0 + 0 * cell_w  # col0: 前列
	var enemy_q2_x: float = cx + gap / 2.0 + 1 * cell_w  # col1: 中列
	var enemy_q3_x: float = cx + gap / 2.0 + 2 * cell_w  # col2: 後列

	# ---- 自陣Q1/Q2/Q3: 呪文スロットUI ----
	var slot_xs: Array = [self_q1_x, self_q2_x, self_q3_x]
	var slot_labels: Array = ["Q1 (前列)", "Q2 (中列)", "Q3 (後列)"]
	_spell_slot_panels.clear()
	for i in range(3):
		var sx: float = slot_xs[i]
		_build_one_spell_slot(i, sx, queue_y, cell_w, card_h, slot_labels[i])

	# 互換用（非表示）
	_queue_self_deck_label = Label.new()
	_queue_self_deck_label.visible = false
	main.add_child(_queue_self_deck_label)



func update() -> void:
	_update_deck_counts()
	update_spell_slots()

func _build_one_spell_slot(slot_index: int, sx: float, sy: float, sw: float, sh: float, header_text: String) -> void:
	"""呪文スロット1つ分のUIノードを生成してmainに追加"""
	# ヘッダーラベル
	var header_lbl := Label.new()
	header_lbl.text = header_text
	header_lbl.position = Vector2(sx, sy - 16)
	header_lbl.size = Vector2(sw, 14)
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_size_override("font_size", 10)
	header_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	main.add_child(header_lbl)

	# キャストゲージ（呪文スロット上部の横棒）
	# 配置: ヘッダーラベルとパネル間（sy - 4 のY座標）
	var gauge_bg := ColorRect.new()
	gauge_bg.position = Vector2(sx, sy - 4)
	gauge_bg.size = Vector2(sw, 3)
	gauge_bg.color = Color(0.15, 0.15, 0.2)
	main.add_child(gauge_bg)

	var gauge_fill := ColorRect.new()
	gauge_fill.position = Vector2(sx, sy - 4)
	gauge_fill.size = Vector2(sw, 3)
	gauge_fill.color = Color(0.4, 0.7, 1.0)  # シアン系（マナと区別）
	main.add_child(gauge_fill)

	# 発光縁取り（発動可能時のみvisible=true）
	var glow_rect := ColorRect.new()
	glow_rect.position = Vector2(sx - 2, sy - 2)
	glow_rect.size = Vector2(sw + 4, sh + 4)
	glow_rect.color = COLOR_SLOT_GLOW
	glow_rect.z_index = -1
	glow_rect.visible = false
	main.add_child(glow_rect)

	# 背景パネル（クリック受付）
	var panel := ColorRect.new()
	panel.position = Vector2(sx, sy)
	panel.size = Vector2(sw, sh)
	panel.color = COLOR_SLOT_EMPTY
	panel.gui_input.connect(_on_spell_slot_input.bind(slot_index))
	main.add_child(panel)

	# 呪文名ラベル
	var name_lbl := Label.new()
	name_lbl.position = Vector2(sx + 5, sy + 10)
	name_lbl.size = Vector2(sw - 10, 48)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", COLOR_LABEL_EMPTY)
	name_lbl.text = "─"
	main.add_child(name_lbl)

	# 条件タグラベル
	var cond_lbl := Label.new()
	cond_lbl.position = Vector2(sx + 5, sy + 62)
	cond_lbl.size = Vector2(sw - 10, 16)
	cond_lbl.add_theme_font_size_override("font_size", 9)
	cond_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cond_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
	main.add_child(cond_lbl)

	# マナコストラベル
	var cost_lbl := Label.new()
	cost_lbl.position = Vector2(sx + 5, sy + 82)
	cost_lbl.size = Vector2(sw - 10, 14)
	cost_lbl.add_theme_font_size_override("font_size", 9)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
	main.add_child(cost_lbl)

	# 発動可否ラベル
	var status_lbl := Label.new()
	status_lbl.position = Vector2(sx + 5, sy + 100)
	status_lbl.size = Vector2(sw - 10, 14)
	status_lbl.add_theme_font_size_override("font_size", 9)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
	main.add_child(status_lbl)

	_spell_slot_panels.append({
		"panel": panel,
		"glow_rect": glow_rect,
		"name_lbl": name_lbl,
		"cond_lbl": cond_lbl,
		"cost_lbl": cost_lbl,
		"status_lbl": status_lbl,
		"base_x": sx,
		"tween": null,
		"gauge_bg": gauge_bg,
		"gauge_fill": gauge_fill,
	})

func _on_spell_slot_input(event: InputEvent, slot_index: int) -> void:
	"""呪文スロット入力処理（左クリック発動・右クリック破棄）"""
	if not (event is InputEventMouseButton and event.pressed):
		return
	if main.spell_slot_system == null:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if main.spell_slot_system.cast_spell(slot_index):
			print("[SpellSlotUI] スロット%d発動成功" % slot_index)
			update_spell_slots()
		else:
			var reason = main.spell_slot_system.get_cast_block_reason(slot_index)
			print("[SpellSlotUI] スロット%d発動失敗: %s" % [slot_index, reason])
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if main.spell_slot_system.discard_slot(slot_index):
			print("[SpellSlotUI] スロット%d破棄" % slot_index)
			update_spell_slots()

func update_spell_slots() -> void:
	"""呪文スロット表示更新（毎フレームまたはシグナルで呼ぶ）"""
	if main.spell_slot_system == null:
		return
	var slots = main.spell_slot_system.slots
	for i in range(3):
		if i >= _spell_slot_panels.size():
			break
		var sd = _spell_slot_panels[i]
		var panel: ColorRect = sd["panel"]
		var glow_rect: ColorRect = sd["glow_rect"]
		var name_lbl: Label = sd["name_lbl"]
		var cond_lbl: Label = sd["cond_lbl"]
		var cost_lbl: Label = sd["cost_lbl"]
		var status_lbl: Label = sd["status_lbl"]

		if slots[i]["spell"] == null:
			# 空スロット
			panel.color = COLOR_SLOT_EMPTY
			glow_rect.visible = false
			name_lbl.text = "─"
			name_lbl.add_theme_color_override("font_color", COLOR_LABEL_EMPTY)
			cond_lbl.text = ""
			cost_lbl.text = ""
			status_lbl.text = ""
			_stop_pulse(i)
		else:
			var spell = slots[i]["spell"]
			var cond_display = main.spell_slot_system.get_condition_display_name(slots[i]["condition"])
			var can_cast: bool = main.spell_slot_system.can_cast(i)
			var reason: String = main.spell_slot_system.get_cast_block_reason(i)

			name_lbl.text = spell.unit_name
			cond_lbl.text = "[%s]" % cond_display
			cost_lbl.text = "コスト: %d" % slots[i]["mana_cost"]

			if can_cast:
				panel.color = COLOR_SLOT_READY_BG
				glow_rect.visible = true
				name_lbl.add_theme_color_override("font_color", COLOR_LABEL_READY)
				cond_lbl.add_theme_color_override("font_color", COLOR_LABEL_READY)
				cost_lbl.add_theme_color_override("font_color", COLOR_LABEL_READY)
				status_lbl.text = "▶ 発動可"
				status_lbl.add_theme_color_override("font_color", COLOR_READY_ACCENT)
				_start_pulse(i)
			else:
				panel.color = COLOR_SLOT_LOADED_OFF
				glow_rect.visible = false
				name_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
				cond_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
				cost_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
				if reason == "mana":
					status_lbl.text = "× マナ不足"
				elif reason == "condition":
					status_lbl.text = "× 条件未達"
				else:
					status_lbl.text = ""
				status_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
				_stop_pulse(i)

		# キャストゲージ更新（全スロット共通のratio）
		var sys = main.spell_slot_system
		var ratio: float = 1.0 - (sys.cast_timer / max(0.01, sys.cast_interval))
		ratio = clamp(ratio, 0.0, 1.0)
		var gauge_fill: ColorRect = sd["gauge_fill"]
		gauge_fill.size.x = sd["gauge_bg"].size.x * ratio
		# 満タンならシアン、進行中はやや暗め
		gauge_fill.color = Color(0.4, 0.7, 1.0) if ratio >= 1.0 else Color(0.3, 0.5, 0.8)

func _start_pulse(slot_index: int) -> void:
	if slot_index >= _spell_slot_panels.size():
		return
	var sd = _spell_slot_panels[slot_index]
	var glow_rect: ColorRect = sd["glow_rect"]
	if sd["tween"] != null:
		sd["tween"].kill()
	var tw = create_tween()
	tw.set_loops()
	tw.tween_property(glow_rect, "modulate:a", 0.95, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow_rect, "modulate:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sd["tween"] = tw

func _stop_pulse(slot_index: int) -> void:
	if slot_index >= _spell_slot_panels.size():
		return
	var sd = _spell_slot_panels[slot_index]
	if sd["tween"] != null:
		sd["tween"].kill()
		sd["tween"] = null


func _update_deck_counts() -> void:
	# 互換ラベル（非表示だが参照維持）
	main.deck_count_label.text    = "自デッキ: %d枚" % main.deck_manager.deck.size()
	main.discard_count_label.text = "捨て札: %d枚" % main.deck_manager.discard.size()
	# Overlayの縦3段VBoxラベルを更新
	if _overlay != null:
		# 自陣(side=0)
		if _overlay._deck_count_labels[0] != null:
			_overlay._deck_count_labels[0].text = "%d" % main.deck_manager.deck.size()
		if _overlay._discard_count_labels[0] != null:
			_overlay._discard_count_labels[0].text = "%d" % main.deck_manager.discard.size()
		if _overlay._exile_count_labels[0] != null:
			_overlay._exile_count_labels[0].text = "0"
