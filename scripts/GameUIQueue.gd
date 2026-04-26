# GameUIQueue.gd
# キュー+デッキ情報UI（GameUI.gdから分離）
extends Control

var main: Node = null
var _EDB = null

var _queue_self_deck_label: Label = null  # 自デッキ山ラベル（互換用・非表示）
var _queue_mana_bar: ColorRect = null     # キューエリア内マナゲージ
var _queue_mana_label: Label = null       # キューエリア内マナ数値
var _overlay = null  # GameUIOverlayへの参照（デッキカウント更新用）

var _mana_gauge_fill: ColorRect = null
var _mana_value_lbl: Label = null

var _cast_gauge_fill: ColorRect = null
var _cast_value_lbl: Label = null

# 呪文スロットUI（Q1/Q2/Q3に配置）
var _spell_slot_panels: Array = []  # 3スロット分のUIノード辞書配列

# D&D状態管理
var _drag_slot: int = -1
var _is_dragging: bool = false

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

	# ---- スロット下部横並びゲージ（CAST / MANA） ----
	var gauge_row_y: float = queue_y + card_h + 4.0
	var slots_total_w: float = cell_w * 3.0
	var gauge_origin_x: float = self_q3_x  # Q3（後列）が最左端
	var half_w: float = slots_total_w / 2.0
	var bar_h: float = 8.0
	var lbl_w: float = 40.0
	var bar_margin: float = 4.0

	# CAST ゲージ（左半分）
	var cast_lbl := Label.new()
	cast_lbl.text = "CAST"
	cast_lbl.position = Vector2(gauge_origin_x, gauge_row_y + 4)
	cast_lbl.size = Vector2(lbl_w, 16)
	cast_lbl.add_theme_font_size_override("font_size", 10)
	cast_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	main.add_child(cast_lbl)

	var cast_bar_x: float = gauge_origin_x + lbl_w + bar_margin
	var cast_bar_w: float = half_w - lbl_w - bar_margin * 2.0

	var cast_gauge_bg := ColorRect.new()
	cast_gauge_bg.position = Vector2(cast_bar_x, gauge_row_y + 8)
	cast_gauge_bg.size = Vector2(cast_bar_w, bar_h)
	cast_gauge_bg.color = Color(0.12, 0.12, 0.16)
	main.add_child(cast_gauge_bg)

	_cast_gauge_fill = ColorRect.new()
	_cast_gauge_fill.position = Vector2(cast_bar_x, gauge_row_y + 8)
	_cast_gauge_fill.size = Vector2(0, bar_h)
	_cast_gauge_fill.color = Color(0.35, 0.65, 0.35)
	main.add_child(_cast_gauge_fill)

	main.cast_gauge_fill = _cast_gauge_fill
	main.cast_gauge_fill_max_w = cast_bar_w

	# MANA ゲージ（右半分）
	var mana_half_x: float = gauge_origin_x + half_w
	var mana_bar_x: float = mana_half_x + lbl_w + bar_margin
	var mana_bar_w: float = half_w - lbl_w - bar_margin * 2.0 - 50.0  # 数値ラベル分を引く

	var mana_lbl := Label.new()
	mana_lbl.text = "MANA"
	mana_lbl.position = Vector2(mana_half_x, gauge_row_y + 4)
	mana_lbl.size = Vector2(lbl_w, 16)
	mana_lbl.add_theme_font_size_override("font_size", 10)
	mana_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
	main.add_child(mana_lbl)

	var mana_gauge_bg := ColorRect.new()
	mana_gauge_bg.position = Vector2(mana_bar_x, gauge_row_y + 8)
	mana_gauge_bg.size = Vector2(mana_bar_w, bar_h)
	mana_gauge_bg.color = Color(0.12, 0.12, 0.16)
	main.add_child(mana_gauge_bg)

	_mana_gauge_fill = ColorRect.new()
	_mana_gauge_fill.position = Vector2(mana_bar_x, gauge_row_y + 8)
	_mana_gauge_fill.size = Vector2(0, bar_h)
	_mana_gauge_fill.color = Color(0.35, 0.35, 0.55)
	main.add_child(_mana_gauge_fill)

	_mana_value_lbl = Label.new()
	_mana_value_lbl.text = "0 / 0"
	_mana_value_lbl.position = Vector2(mana_bar_x + mana_bar_w + 4, gauge_row_y + 2)
	_mana_value_lbl.size = Vector2(46, 20)
	_mana_value_lbl.add_theme_font_size_override("font_size", 11)
	_mana_value_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70))
	main.add_child(_mana_value_lbl)

	main.mana_value_label = _mana_value_lbl
	main.mana_gauge_fill = _mana_gauge_fill
	main.mana_gauge_fill_max_w = mana_bar_w

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
	cond_lbl.clip_text = true
	main.add_child(cond_lbl)

	# マナコストラベル
	var cost_lbl := Label.new()
	cost_lbl.position = Vector2(sx + 5, sy + 82)
	cost_lbl.size = Vector2(sw - 10, 14)
	cost_lbl.add_theme_font_size_override("font_size", 9)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
	main.add_child(cost_lbl)

	# 効果テキストラベル
	var effect_lbl := Label.new()
	effect_lbl.position = Vector2(sx + 5, sy + 100)
	effect_lbl.size = Vector2(sw - 10, 54)
	effect_lbl.add_theme_font_size_override("font_size", 10)
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	main.add_child(effect_lbl)

	# 発動可否ラベル
	var status_lbl := Label.new()
	status_lbl.position = Vector2(sx + 5, sy + 158)
	status_lbl.size = Vector2(sw - 10, 14)
	status_lbl.add_theme_font_size_override("font_size", 9)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
	main.add_child(status_lbl)

	# 合成レベルバッジ（右上）
	var synth_badge := Label.new()
	synth_badge.position = Vector2(sx + sw - 36, sy + 4)
	synth_badge.size = Vector2(34, 16)
	synth_badge.add_theme_font_size_override("font_size", 11)
	synth_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	synth_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	synth_badge.visible = false
	main.add_child(synth_badge)

	# 範囲バリアントラベル（下部）
	var range_lbl := Label.new()
	range_lbl.position = Vector2(sx + 5, sy + sh - 18)
	range_lbl.size = Vector2(sw - 10, 16)
	range_lbl.add_theme_font_size_override("font_size", 9)
	range_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	range_lbl.visible = false
	main.add_child(range_lbl)

	_spell_slot_panels.append({
		"panel": panel,
		"glow_rect": glow_rect,
		"header_lbl": header_lbl,
		"name_lbl": name_lbl,
		"cond_lbl": cond_lbl,
		"cost_lbl": cost_lbl,
		"effect_lbl": effect_lbl,
		"status_lbl": status_lbl,
		"synth_badge": synth_badge,
		"range_lbl": range_lbl,
		"base_x": sx,
		"tween": null,
	})

func _on_spell_slot_input(event: InputEvent, slot_index: int) -> void:
	"""呪文スロット入力処理（左クリック発動・右クリック破棄・D&D合成）"""
	if main.spell_slot_system == null:
		return

	# PHASE_ACTIONモード: 左クリックのみ有効（右クリック・D&Dは無効）
	if main.spell_slot_system.mode == main.spell_slot_system.SlotMode.PHASE_ACTION:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if main.spell_slot_system.cast_action(slot_index):
				update_spell_slots()
			else:
				print("[SpellSlotUI] フェーズアクション%d: 押下不可" % slot_index)
		return  # D&D・右クリックを無効化

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_slot = slot_index
				_is_dragging = false
			else:
				if _is_dragging and _drag_slot >= 0:
					# D&D終了: ドロップ先スロットを検出して合成試行
					var drop = _get_slot_at_global(main.get_global_mouse_position())
					if drop >= 0 and drop != _drag_slot:
						_try_synthesize(_drag_slot, drop)
					_reset_all_highlights()
				elif _drag_slot == slot_index and not _is_dragging:
					# 通常クリック → キャスト
					if main.spell_slot_system.cast_spell(slot_index):
						print("[SpellSlotUI] スロット%d発動成功" % slot_index)
						update_spell_slots()
					else:
						var reason = main.spell_slot_system.get_cast_block_reason(slot_index)
						print("[SpellSlotUI] スロット%d発動失敗: %s" % [slot_index, reason])
				_drag_slot = -1
				_is_dragging = false

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if main.spell_slot_system.discard_slot(slot_index):
				print("[SpellSlotUI] スロット%d破棄" % slot_index)
				update_spell_slots()

	elif event is InputEventMouseMotion and _drag_slot == slot_index:
		if not _is_dragging:
			_is_dragging = true
		# ホバー中のスロットをハイライト
		var hover = _get_slot_at_global(main.get_global_mouse_position())
		_update_synth_highlights(_drag_slot, hover)

func _get_slot_at_global(gpos: Vector2) -> int:
	for i in range(_spell_slot_panels.size()):
		var panel: ColorRect = _spell_slot_panels[i]["panel"]
		if Rect2(panel.global_position, panel.size).has_point(gpos):
			return i
	return -1

func _try_synthesize(from: int, to: int) -> void:
	var sys = main.spell_slot_system
	if sys.can_synthesize(from, to):
		if sys.synthesize(from, to):
			print("[SpellSlotUI] 合成成功: %d → %d" % [from, to])
			update_spell_slots()
	else:
		var reason = sys.get_synth_reason(from, to)
		print("[SpellSlotUI] 合成不可: %s" % reason)

func _update_synth_highlights(drag_src: int, hover_tgt: int) -> void:
	var sys = main.spell_slot_system
	for i in range(_spell_slot_panels.size()):
		if i == drag_src:
			continue
		var panel: ColorRect = _spell_slot_panels[i]["panel"]
		if i == hover_tgt and hover_tgt >= 0:
			if sys.can_synthesize(drag_src, i):
				panel.color = Color(0.1, 0.35, 0.15)  # 緑: 合成可
			else:
				panel.color = Color(0.35, 0.1, 0.1)   # 赤: 合成不可
		else:
			# 通常色に戻す（spell有無で判定）
			var slot = sys.slots[i]
			panel.color = COLOR_SLOT_LOADED_OFF if slot["spell"] != null else COLOR_SLOT_EMPTY

func _reset_all_highlights() -> void:
	if main.spell_slot_system == null:
		return
	for i in range(_spell_slot_panels.size()):
		var panel: ColorRect = _spell_slot_panels[i]["panel"]
		var slot = main.spell_slot_system.slots[i]
		if slot["spell"] != null:
			panel.color = COLOR_SLOT_READY_BG if main.spell_slot_system.can_cast(i) else COLOR_SLOT_LOADED_OFF
		else:
			panel.color = COLOR_SLOT_EMPTY

func update_spell_slots() -> void:
	"""呪文スロット表示更新（毎フレームまたはシグナルで呼ぶ）"""
	if main.spell_slot_system == null:
		return

	# フェーズアクションモードの場合は専用更新
	if main.spell_slot_system.mode == main.spell_slot_system.SlotMode.PHASE_ACTION:
		_update_phase_action_slots()
		return

	var slots = main.spell_slot_system.slots
	for i in range(3):
		if i >= _spell_slot_panels.size():
			break
		var sd = _spell_slot_panels[i]
		var panel: ColorRect = sd["panel"]
		var glow_rect: ColorRect = sd["glow_rect"]
		var header_lbl: Label = sd["header_lbl"]
		var name_lbl: Label = sd["name_lbl"]
		var cond_lbl: Label = sd["cond_lbl"]
		var cost_lbl: Label = sd["cost_lbl"]
		var status_lbl: Label = sd["status_lbl"]

		var synth_badge: Label = sd["synth_badge"]
		var range_lbl:   Label = sd["range_lbl"]
		var effect_lbl:  Label = sd["effect_lbl"]

		# BATTLEモードのヘッダー: 緑系
		header_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		var slot_labels: Array = ["Q1 (前列)", "Q2 (中列)", "Q3 (後列)"]
		header_lbl.text = slot_labels[i]

		if slots[i]["spell"] == null:
			# 空スロット
			panel.color = COLOR_SLOT_EMPTY
			glow_rect.visible = false
			name_lbl.text = "─"
			name_lbl.add_theme_color_override("font_color", COLOR_LABEL_EMPTY)
			cond_lbl.text = ""
			cost_lbl.text = ""
			effect_lbl.text = ""
			status_lbl.text = ""
			synth_badge.visible = false
			range_lbl.visible = false
			_stop_pulse(i)
		else:
			var slot = slots[i]
			var spell = slot["spell"]
			var cond_display = main.spell_slot_system.get_condition_display_name(slot["condition"])
			var can_cast: bool = main.spell_slot_system.can_cast(i)
			var reason: String = main.spell_slot_system.get_cast_block_reason(i)
			var synth_lv: int  = slot.get("synth_level", 1)

			name_lbl.text = spell.unit_name
			cond_lbl.text = "[%s]" % cond_display
			cost_lbl.text = "コスト: %d" % slot["mana_cost"]
			effect_lbl.text = spell.spell_effect if spell is UnitData else spell.get("effect", "")

			# 合成バッジ
			if synth_lv > 1:
				synth_badge.text = "Lv%d" % synth_lv
				synth_badge.visible = true
				var rv: String = slot.get("range_variant", "default")
				if rv != "default":
					range_lbl.text = main.spell_slot_system.RANGE_DISPLAY.get(rv, "")
					range_lbl.visible = true
				else:
					range_lbl.visible = false
			else:
				synth_badge.visible = false
				range_lbl.visible = false

			if can_cast:
				panel.color = COLOR_SLOT_READY_BG
				glow_rect.visible = true
				name_lbl.add_theme_color_override("font_color", COLOR_LABEL_READY)
				cond_lbl.add_theme_color_override("font_color", COLOR_LABEL_READY)
				cost_lbl.add_theme_color_override("font_color", COLOR_LABEL_READY)
				effect_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
				status_lbl.text = "▶ 発動可"
				status_lbl.add_theme_color_override("font_color", COLOR_READY_ACCENT)
				_start_pulse(i)
			else:
				panel.color = COLOR_SLOT_LOADED_OFF
				glow_rect.visible = false
				name_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
				cond_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
				cost_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
				effect_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
				if reason == "mana":
					status_lbl.text = "× マナ不足"
				elif reason == "condition":
					status_lbl.text = "× 条件未達"
				elif reason == "cooldown":
					status_lbl.text = "⏳ CD中"
				else:
					status_lbl.text = ""
				status_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
				_stop_pulse(i)

	# キャストゲージ更新
	if main.cast_gauge_fill != null:
		var sys = main.spell_slot_system
		if sys != null:
			var ratio: float = clamp(sys.cast_timer / max(0.01, sys.cast_interval), 0.0, 1.0)
			main.cast_gauge_fill.size.x = main.cast_gauge_fill_max_w * ratio
			if _cast_value_lbl != null:
				_cast_value_lbl.text = "%d / %d" % [int(sys.cast_timer * 10), int(sys.cast_interval * 10)]


# ---- フェーズアクションモード表示（REQ-QPA-08） ----

# フェーズ名→ヘッダー色マッピング
const PHASE_HEADER_COLORS: Dictionary = {
	"SCRATCH": Color(0.85, 0.75, 0.4),
	"SHOP":    Color(1.0, 0.85, 0.2),
	"NEXT_EI": Color(0.85, 0.4, 0.4),
}

func _update_phase_action_slots() -> void:
	"""PHASE_ACTIONモードのスロット表示更新"""
	var sys = main.spell_slot_system
	var slots = sys.slots
	var phase_name: String = sys.current_phase_name.to_upper()
	var header_color: Color = PHASE_HEADER_COLORS.get(phase_name, Color(0.7, 0.7, 0.7))

	for i in range(3):
		if i >= _spell_slot_panels.size():
			break
		var sd = _spell_slot_panels[i]
		var panel: ColorRect = sd["panel"]
		var glow_rect: ColorRect = sd["glow_rect"]
		var header_lbl: Label = sd["header_lbl"]
		var name_lbl: Label = sd["name_lbl"]
		var cond_lbl: Label = sd["cond_lbl"]
		var cost_lbl: Label = sd["cost_lbl"]
		var status_lbl: Label = sd["status_lbl"]
		var synth_badge: Label = sd["synth_badge"]
		var range_lbl:   Label = sd["range_lbl"]

		# ヘッダーをフェーズ名表示に変更
		var phase_display: String = phase_name if phase_name != "" else "PHASE"
		header_lbl.text = "Q%d / %s" % [i + 1, phase_display]
		header_lbl.add_theme_color_override("font_color", header_color)

		# synth_badge / range_lbl は非表示
		synth_badge.visible = false
		range_lbl.visible = false

		var slot = slots[i]
		if not slot.get("is_action", false):
			# 空スロット扱い
			panel.color = COLOR_SLOT_EMPTY
			glow_rect.visible = false
			name_lbl.text = "─"
			name_lbl.add_theme_color_override("font_color", COLOR_LABEL_EMPTY)
			cond_lbl.text = ""
			cost_lbl.text = ""
			status_lbl.text = ""
			_stop_pulse(i)
			continue

		var enabled: bool = slot.get("enabled", false)
		var label: String = slot.get("action_label", "")
		var desc: String = slot.get("action_desc", "")
		var cost_text: String = slot.get("action_cost_text", "")

		name_lbl.text = label
		cond_lbl.text = desc
		cond_lbl.add_theme_font_size_override("font_size", 9)
		cost_lbl.text = cost_text

		if enabled:
			panel.color = COLOR_SLOT_READY_BG
			glow_rect.visible = false  # フェーズアクションはglow不要
			name_lbl.add_theme_color_override("font_color", COLOR_LABEL_READY)
			cond_lbl.add_theme_color_override("font_color", COLOR_LABEL_READY)
			cost_lbl.add_theme_color_override("font_color", COLOR_LABEL_READY)
			status_lbl.text = "▶ タップ可"
			status_lbl.add_theme_color_override("font_color", COLOR_READY_ACCENT)
		else:
			# 押下不可: action_id が "" か "next_ei_dark" は完全暗転
			var aid: String = slot.get("action_id", "")
			if aid == "next_ei_dark" or label == "":
				panel.color = COLOR_SLOT_EMPTY
			else:
				panel.color = COLOR_SLOT_LOADED_OFF
			glow_rect.visible = false
			name_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
			cond_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
			cost_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
			status_lbl.text = "× 押下不可"
			status_lbl.add_theme_color_override("font_color", COLOR_LABEL_DISABLED)
		_stop_pulse(i)

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
