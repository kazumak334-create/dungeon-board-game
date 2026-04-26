# GameUIOverlay.gd
# オーバーレイ・フロート・ホバー・装備UI（GameUI.gdから分離）
extends Control

var main: Node = null
var _EDB = null

var _damage_floats: Array = []             # [{label, timer, velocity}]
var _event_bubble: Label = null            # 重要イベントフキダシ
var _bubble_timer: float = 0.0             # フキダシ残り表示時間
var _deck_count_labels: Array = [null, null]    # [side] -> Label（山札枚数）
var _discard_count_labels: Array = [null, null] # [side] -> Label（捨て札枚数）
var _exile_count_labels: Array = [null, null]   # [side] -> Label（除外枚数）
var _battle_timer_label: Label = null            # バトル残り時間ラベル
var _timer_blink_acc: float = 0.0               # 点滅用アキュムレータ
var _battle_gold_label: Label = null             # バトル中獲得通貨ラベル（プレイヤー側パネル下）

func _cell_x(side: int, col: int) -> int:
	if side == 0:
		return main.CENTER_X - main.GAP / 2 - (3 - col) * main.CELL_W
	else:
		return main.CENTER_X + main.GAP / 2 + col * main.CELL_W

func build() -> void:
	# バトルタイマーラベル（画面上部中央）
	_battle_timer_label = Label.new()
	_battle_timer_label.position = Vector2(540, 42)
	_battle_timer_label.size = Vector2(200, 28)
	_battle_timer_label.visible = false  # 制限時間廃止
	main.add_child(_battle_timer_label)

	# 重要イベントフキダシ（画面下部・3秒で消える）
	_event_bubble = Label.new()
	_event_bubble.position = Vector2(200, 680)
	_event_bubble.size = Vector2(880, 25)
	_event_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_bubble.add_theme_font_size_override("font_size", 14)
	_event_bubble.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_event_bubble.visible = false
	main.add_child(_event_bubble)

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

func spawn_damage_float(side: int, row: int, col: int, amount: int, is_heal: bool = false) -> void:
	if amount == 0:
		return
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
	# 本体HPパネル削除により表示不要
	pass

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
	lines.append("Cost: %d / HP: %d/%d / ATK: %d / SPD: %.1fs" % [unit.mana, unit.current_hp, unit.max_hp, unit.attack, unit.get_attack_interval()])
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
	if unit.regen_stacks > 0:      buffs_h.append("再生%d" % unit.regen_stacks)
	if unit.burn_turns > 0:         buffs_h.append("火傷%d" % unit.burn_turns)
	if unit.frozen_turns > 0:       buffs_h.append("凍結%d" % unit.frozen_turns)
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


func _is_important_event(text: String) -> bool:
	# 重要イベント判定：死亡、本体ダメージ、スキル発動、合成
	if "倒 " in text: return true
	if "本体" in text: return true
	if "[スキル]" in text: return true
	if "合成" in text: return true
	if "呪文回収" in text: return true
	if "GAME OVER" in text or "YOU WIN" in text: return true
	return false

func _show_bubble(text: String) -> void:
	if _event_bubble == null:
		return
	# タイムスタンプを除去して表示
	var display = text
	if display.begins_with("["):
		var bracket_end = display.find("]")
		if bracket_end >= 0:
			display = display.substr(bracket_end + 2)
	_event_bubble.text = display
	_event_bubble.visible = true
	_bubble_timer = 3.0

func update_bubble(delta: float) -> void:
	if _bubble_timer > 0:
		_bubble_timer -= delta
		if _event_bubble != null:
			_event_bubble.modulate.a = min(1.0, _bubble_timer)
		if _bubble_timer <= 0 and _event_bubble != null:
			_event_bubble.visible = false

func update_battle_gold_label(total_gold: int) -> void:
	if _battle_gold_label != null:
		_battle_gold_label.text = "G: %d" % total_gold

func update_battle_timer(remaining: float, delta: float = 0.016) -> void:
	if _battle_timer_label == null:
		return
	var secs: int = ceili(remaining)
	_battle_timer_label.text = "%d" % max(0, secs)
	if remaining <= 10.0:
		# 10秒以下: 赤色 + 点滅（1Hz）
		_battle_timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		_timer_blink_acc += delta
		var blink_on: bool = fmod(_timer_blink_acc, 1.0) < 0.5
		_battle_timer_label.modulate.a = 1.0 if blink_on else 0.3
	else:
		_battle_timer_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		_battle_timer_label.modulate.a = 1.0
		_timer_blink_acc = 0.0