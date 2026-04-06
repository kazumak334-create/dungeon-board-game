# GameUIOverlay.gd
# オーバーレイ・フロート・ホバー・装備UI（GameUI.gdから分離）
extends RefCounted

var main: Node = null
var _EDB = null

var _char_hp_bars: Array = [null, null]    # [side] -> ColorRect (HPバー)
var _char_hp_labels: Array = [null, null]  # [side] -> Label (HP数値)
var _char_panels: Array = [null, null]     # [side] -> Panel
var _char_mana_bars: Array = [null, null]  # [side] -> ColorRect (マナバー)
var _char_mana_labels: Array = [null, null] # [side] -> Label (マナ数値)
var _char_cast_bars: Array = [null, null]  # [side] -> ColorRect (キャストゲージ)
var _damage_floats: Array = []             # [{label, timer, velocity}]
var _event_bubble: Label = null            # 重要イベントフキダシ
var _bubble_timer: float = 0.0             # フキダシ残り表示時間

func _cell_x(side: int, col: int) -> int:
	if side == 0:
		return main.CENTER_X - main.GAP / 2 - (3 - col) * main.CELL_W
	else:
		return main.CENTER_X + main.GAP / 2 + col * main.CELL_W

func build() -> void:
	_build_character_panel(0)
	_build_character_panel(1)
	# _build_equipment_ui()  # 将来実装（現在は非表示）
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

func _build_character_panel(side: int) -> void:
	var panel_w = 80
	var panel_h = 175  # 装備行+マナ行を追加して拡張
	var panel_x: int
	if side == 0:
		panel_x = _cell_x(0, 0) - panel_w - 15  # プレイヤー側：盤面左端のさらに左
	else:
		panel_x = _cell_x(1, 2) + main.CELL_W + 15  # 敵側：盤面右端のさらに右
	var panel_y = main.BOARD_TOP + 1 * main.CELL_H - 40  # 中段の高さ（拡張分で上にずらす）

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
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func(): _on_char_hover(side))
	panel.mouse_exited.connect(func(): _on_char_hover_end())
	main.add_child(panel)
	_char_panels[side] = panel

	# キャラ名
	var name_label = Label.new()
	name_label.text = "プレイヤー" if side == 0 else "敵"
	name_label.position = Vector2(panel_x + 5, panel_y + 4)
	name_label.size = Vector2(panel_w - 10, 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7) if side == 0 else Color(0.85, 0.7, 0.7))
	main.add_child(name_label)

	# 装備効果アイコン行（将来プレースホルダ）
	var equip_label = Label.new()
	equip_label.text = "装備なし"
	equip_label.position = Vector2(panel_x + 4, panel_y + 22)
	equip_label.size = Vector2(panel_w - 8, 14)
	equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equip_label.add_theme_font_size_override("font_size", 9)
	equip_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	main.add_child(equip_label)

	# 立絵プレースホルダ（将来テクスチャに差し替え）
	var portrait = ColorRect.new()
	portrait.position = Vector2(panel_x + 15, panel_y + 38)
	portrait.size = Vector2(50, 50)
	portrait.color = Color(0.25, 0.3, 0.2) if side == 0 else Color(0.3, 0.2, 0.2)
	main.add_child(portrait)

	var portrait_label = Label.new()
	portrait_label.text = "P" if side == 0 else "E"
	portrait_label.position = Vector2(panel_x + 30, panel_y + 51)
	portrait_label.add_theme_font_size_override("font_size", 20)
	portrait_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5) if side == 0 else Color(0.8, 0.5, 0.5))
	main.add_child(portrait_label)

	# HPバー背景
	var hp_bg = ColorRect.new()
	hp_bg.position = Vector2(panel_x + 5, panel_y + 94)
	hp_bg.size = Vector2(70, 10)
	hp_bg.color = Color(0.2, 0.2, 0.2)
	main.add_child(hp_bg)

	# HPバー
	var hp_bar = ColorRect.new()
	hp_bar.position = Vector2(panel_x + 5, panel_y + 94)
	hp_bar.size = Vector2(70, 10)
	hp_bar.color = Color(0.3, 0.9, 0.4) if side == 0 else Color(0.9, 0.3, 0.3)
	main.add_child(hp_bar)
	_char_hp_bars[side] = hp_bar

	# HP数値
	var hp_label = Label.new()
	hp_label.position = Vector2(panel_x + 5, panel_y + 107)
	hp_label.size = Vector2(70, 16)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hp_label.text = "%d" % main.base_hp[side]
	main.add_child(hp_label)
	_char_hp_labels[side] = hp_label

	# マナゲージ背景
	var mana_bg = ColorRect.new()
	mana_bg.position = Vector2(panel_x + 5, panel_y + 127)
	mana_bg.size = Vector2(70, 10)
	mana_bg.color = Color(0.1, 0.1, 0.07)
	main.add_child(mana_bg)

	# マナゲージ
	var mana_bar = ColorRect.new()
	mana_bar.position = Vector2(panel_x + 5, panel_y + 127)
	mana_bar.size = Vector2(0, 10)
	mana_bar.color = Color(0.2, 0.5, 1.0) if side == 0 else Color(1.0, 0.3, 0.2)
	main.add_child(mana_bar)
	_char_mana_bars[side] = mana_bar

	# マナ数値
	var mana_label = Label.new()
	mana_label.position = Vector2(panel_x + 4, panel_y + 140)
	mana_label.size = Vector2(panel_w - 8, 14)
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label.add_theme_font_size_override("font_size", 10)
	mana_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if side == 0 else Color(1.0, 0.6, 0.3))
	mana_label.text = "0 / 10"
	main.add_child(mana_label)
	_char_mana_labels[side] = mana_label

	# マナラベル（タイトル）
	var mana_title = Label.new()
	mana_title.text = "マナ"
	mana_title.position = Vector2(panel_x + 4, panel_y + 155)
	mana_title.size = Vector2(panel_w - 8, 14)
	mana_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_title.add_theme_font_size_override("font_size", 9)
	mana_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if side == 0 else Color(1.0, 0.5, 0.2))
	main.add_child(mana_title)

	# キャストゲージ（クールダウン表示・バーのみ）
	var cast_title = Label.new()
	cast_title.text = "キャスト"
	cast_title.position = Vector2(panel_x + 4, panel_y + 168)
	cast_title.size = Vector2(panel_w - 8, 12)
	cast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cast_title.add_theme_font_size_override("font_size", 8)
	cast_title.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9) if side == 0 else Color(0.9, 0.5, 0.5))
	main.add_child(cast_title)

	var cast_bg = ColorRect.new()
	cast_bg.position = Vector2(panel_x + 5, panel_y + 180)
	cast_bg.size = Vector2(70, 6)
	cast_bg.color = Color(0.15, 0.1, 0.2)
	main.add_child(cast_bg)

	var cast_bar = ColorRect.new()
	cast_bar.position = Vector2(panel_x + 5, panel_y + 180)
	cast_bar.size = Vector2(0, 6)
	cast_bar.color = Color(0.6, 0.3, 0.9) if side == 0 else Color(0.9, 0.4, 0.4)
	main.add_child(cast_bar)
	_char_cast_bars[side] = cast_bar

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

func _on_char_hover(side: int) -> void:
	var text: String = ""
	if side == 0:
		var cls: Dictionary = CardDB.CLASSES.get(GameSession.class_id, {})
		text = "クラス: %s\n" % cls.get("display", "（未選択）")
		var _edb = load("res://scripts/EffectDB.gd")
		for skill in cls.get("skills", []):
			var eid: String = skill.get("effect_id", "")
			var edef: Dictionary = _edb.EFFECTS.get(eid, {})
			text += "  [%s] %s\n" % [skill.get("trigger", ""), edef.get("display", eid)]
		text += "\n装備: なし\n消費アイテム: なし"
	else:
		text = "敵"
	main._cell_tooltip_label.text = text
	var panel: Panel = _char_panels[side]
	if panel != null:
		main._cell_tooltip_panel.position = Vector2(panel.position.x + 90, panel.position.y)
	main._cell_tooltip_panel.visible = true

func _on_char_hover_end() -> void:
	main._cell_tooltip_panel.visible = false

func _is_important_event(text: String) -> bool:
	# 重要イベント判定：死亡、本体ダメージ、スキル発動、合成
	if "倒 " in text: return true
	if "本体" in text: return true
	if "[スキル]" in text: return true
	if "合成" in text: return true
	if "マナ吸収" in text: return true
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