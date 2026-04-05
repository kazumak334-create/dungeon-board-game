# DevUI.gd
# 開発者モードのUI・ロジック
# クリック = 通常発動（ゲームシステム経由）
# ドラッグ = 手動配置（対象セル指定）
class_name DevUI
extends RefCounted

var main: Node
var board_manager: Node
var deck_manager: Node
var enemy_ai: Node

var selected_card: Object = null
var _dragging: bool = false
var _drag_label: Label = null
var _drag_start_pos: Vector2 = Vector2.ZERO
var card_list_container: VBoxContainer
var selected_label: Label
var _all_cards: Array = []
var _tooltip_panel: PanelContainer = null
var _tooltip_label: Label = null
# デッキエディタ
var _deck_container: VBoxContainer = null
var _deck_scroll: ScrollContainer = null
var _deck_title_label: Label = null
var _last_deck_size: int = -1
var _pending_tile_effect: String = ""  # 設置予約中の盤面効果ID

func setup(p_main: Node, p_board: Node, p_deck: Node, p_enemy: Node) -> void:
	main = p_main
	board_manager = p_board
	deck_manager = p_deck
	enemy_ai = p_enemy
	_build_all_cards()
	_build_dev_panel()

func _build_all_cards() -> void:
	var _CardDB = load("res://scripts/CardDB.gd").new()
	for name in _CardDB.UNITS:
		var d = _CardDB.UNITS[name]
		_all_cards.append({"name": name, "data": d, "type": "unit"})
	for name in _CardDB.SPELLS:
		var d = _CardDB.SPELLS[name]
		_all_cards.append({"name": name, "data": d, "type": "spell"})
	for name in _CardDB.STATUS_SPELLS:
		var d = _CardDB.STATUS_SPELLS[name]
		_all_cards.append({"name": name, "data": d, "type": "status_spell"})
	for name in _CardDB.SYSTEM_SPELLS:
		var d = _CardDB.SYSTEM_SPELLS[name]
		_all_cards.append({"name": name, "data": d, "type": "spell"})
	# アーティファクト（盤面出現型 + 永久効果型）
	for aname in _CardDB.ARTIFACTS:
		var d = _CardDB.ARTIFACTS[aname]
		_all_cards.append({"name": aname, "data": d, "type": d.get("card_type", "artifact")})

func _build_dev_panel() -> void:
	var panel := ColorRect.new()
	panel.position = Vector2(1020, 0)
	panel.size = Vector2(260, 720)
	panel.color = Color(0.06, 0.06, 0.1)
	main.add_child(panel)

	var title := Label.new()
	title.text = "開発者モード"
	title.position = Vector2(1030, 4)
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(1.0, 0.4, 0.4)
	main.add_child(title)

	selected_label = Label.new()
	selected_label.text = "クリック=通常発動 / ドラッグ=対象指定"
	selected_label.position = Vector2(1030, 24)
	selected_label.add_theme_font_size_override("font_size", 10)
	selected_label.modulate = Color(0.7, 0.7, 0.5)
	main.add_child(selected_label)

	var btn_y: int = 42
	var col_w: int = 82
	var tools: Array = [
		[{"text": "一時停止",  "cb": _on_toggle_pause},
		 {"text": "マナMAX",   "cb": _on_max_mana},
		 {"text": "戻る",      "cb": _on_back_to_menu}],
		[{"text": "味方全滅",  "cb": _on_kill_allies},
		 {"text": "敵全滅",    "cb": _on_kill_enemies},
		 {"text": "全回復",    "cb": _on_heal_all}],
		[{"text": "味方10dmg", "cb": _on_damage_allies},
		 {"text": "敵10dmg",   "cb": _on_damage_enemies},
		 {"text": "デバフ解除","cb": _on_clear_debuffs}],
		[{"text": "自HP回復",  "cb": _on_heal_player_base},
		 {"text": "敵HP回復",  "cb": _on_heal_enemy_base},
		 {"text": "HP全回復",  "cb": _on_heal_both_base}],
	]
	for row in tools:
		for i in range(row.size()):
			var btn := Button.new()
			btn.text = row[i]["text"]
			btn.position = Vector2(1022 + i * (col_w + 2), btn_y)
			btn.size = Vector2(col_w, 24)
			btn.add_theme_font_size_override("font_size", 10)
			btn.pressed.connect(row[i]["cb"])
			main.add_child(btn)
		btn_y += 26
	# 速度ボタン
	var speed_btns := [
		{"text": "x0.5", "speed": 0.5},
		{"text": "x1",   "speed": 1.0},
		{"text": "x2",   "speed": 2.0},
		{"text": "x4",   "speed": 4.0},
	]
	var spd_col_w: int = 60
	for i in range(speed_btns.size()):
		var sbtn := Button.new()
		sbtn.text = speed_btns[i]["text"]
		sbtn.position = Vector2(1022 + i * (spd_col_w + 2), btn_y)
		sbtn.size = Vector2(spd_col_w, 24)
		sbtn.add_theme_font_size_override("font_size", 10)
		sbtn.modulate = Color(0.8, 0.9, 0.6)
		var spd: float = speed_btns[i]["speed"]
		sbtn.pressed.connect(_on_set_speed.bind(spd))
		main.add_child(sbtn)
	btn_y += 26
	btn_y += 4

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(1020, btn_y)
	scroll.size = Vector2(260, 720 - btn_y - 6)
	main.add_child(scroll)

	card_list_container = VBoxContainer.new()
	card_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_list_container)

	_add_section_header("── ユニット ──")
	for i in range(_all_cards.size()):
		if _all_cards[i]["type"] == "unit":
			_add_card_button(i, _all_cards[i]["name"], Color(0.7, 0.85, 1.0))

	_add_section_header("── 呪文（強化） ──")
	for i in range(_all_cards.size()):
		var c = _all_cards[i]
		if c["type"] == "spell" and c["data"]["target"] in ["self", "single_ally", "all_allies"]:
			var cost = c["data"]["cost"]
			_add_card_button(i, "%s (%s)" % [c["name"], "X" if cost == -1 else str(cost)], Color(0.5, 0.8, 0.5))

	_add_section_header("── 呪文（弱体・環境） ──")
	for i in range(_all_cards.size()):
		var c = _all_cards[i]
		if c["type"] == "spell" and c["data"]["target"] in ["column", "front_all", "all_enemies", "single_enemy"]:
			_add_card_button(i, "%s (%d)" % [c["name"], c["data"]["cost"]], Color(1.0, 0.5, 0.5))

	_add_section_header("── 呪文（干渉） ──")
	for i in range(_all_cards.size()):
		var c = _all_cards[i]
		if c["type"] == "spell" and c["data"]["target"] == "enemy_queue":
			_add_card_button(i, "%s (%d)" % [c["name"], c["data"]["cost"]], Color(1.0, 0.8, 0.4))

	_add_section_header("── 異常状態カード ──")
	for i in range(_all_cards.size()):
		if _all_cards[i]["type"] == "status_spell":
			_add_card_button(i, _all_cards[i]["name"], Color(0.8, 0.3, 0.8))

	_add_section_header("── アーティファクト（盤面） ──")
	for i in range(_all_cards.size()):
		var c = _all_cards[i]
		if c["type"] == "artifact":
			var hp_str: String = "HP%d" % c["data"].get("hp", 0)
			_add_card_button(i, "%s [%s]" % [c["name"], hp_str], Color(1.0, 0.85, 0.3))

	_add_section_header("── アーティファクト（永久） ──")
	for i in range(_all_cards.size()):
		var c = _all_cards[i]
		if c["type"] == "permanent_artifact":
			_add_card_button(i, c["name"], Color(1.0, 0.7, 0.1))

	# 盤面効果ボタン（EffectDBからtile_effect typeを動的取得）
	_add_section_header("── 盤面効果 ──")
	var _EDB_tile = load("res://scripts/EffectDB.gd")
	for eid in _EDB_tile.EFFECTS:
		var def = _EDB_tile.EFFECTS[eid]
		if def.get("type", "") == "tile_effect":
			var display = def.get("display", eid)
			var tile_btn := Button.new()
			tile_btn.text = display
			tile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tile_btn.custom_minimum_size = Vector2(240, 24)
			tile_btn.add_theme_font_size_override("font_size", 11)
			tile_btn.modulate = Color(0.9, 0.7, 0.3)
			tile_btn.pressed.connect(_on_tile_effect_select.bind(eid))
			card_list_container.add_child(tile_btn)
	var clear_tile_btn := Button.new()
	clear_tile_btn.text = "効果解除"
	clear_tile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_tile_btn.custom_minimum_size = Vector2(240, 24)
	clear_tile_btn.add_theme_font_size_override("font_size", 11)
	clear_tile_btn.modulate = Color(0.5, 0.5, 0.5)
	clear_tile_btn.pressed.connect(_on_tile_effect_clear)
	card_list_container.add_child(clear_tile_btn)

	# 装備選択（CardDB.EQUIPMENTから動的生成）
	_add_section_header("── 装備 ──")
	var _CardDB_eq = load("res://scripts/CardDB.gd")
	for eq_name in _CardDB_eq.EQUIPMENT:
		var eq_def = _CardDB_eq.EQUIPMENT[eq_name]
		var eq_btn := Button.new()
		eq_btn.text = "%s" % eq_def.get("display", eq_name)
		eq_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eq_btn.custom_minimum_size = Vector2(110, 24)
		eq_btn.add_theme_font_size_override("font_size", 10)
		eq_btn.modulate = Color(0.8, 0.6, 1.0)
		eq_btn.pressed.connect(_on_equip_toggle.bind(eq_name))
		card_list_container.add_child(eq_btn)
	var equip_remove_btn := Button.new()
	equip_remove_btn.text = "装備全解除"
	equip_remove_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_remove_btn.custom_minimum_size = Vector2(240, 24)
	equip_remove_btn.add_theme_font_size_override("font_size", 10)
	equip_remove_btn.modulate = Color(0.5, 0.4, 0.6)
	equip_remove_btn.pressed.connect(_on_equip_clear_all)
	card_list_container.add_child(equip_remove_btn)

	# クラス選択
	_add_section_header("── クラス選択 ──")
	var _CardDB_cls = load("res://scripts/CardDB.gd").new()
	for class_id in _CardDB_cls.CLASSES:
		var cdef = _CardDB_cls.CLASSES[class_id]
		var cls_btn := Button.new()
		cls_btn.text = cdef["display"]
		cls_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cls_btn.custom_minimum_size = Vector2(240, 24)
		cls_btn.add_theme_font_size_override("font_size", 11)
		cls_btn.modulate = Color(0.3, 0.9, 0.9)
		cls_btn.pressed.connect(_on_class_select.bind(class_id))
		card_list_container.add_child(cls_btn)


	# カード詳細ツールチップ（カード一覧の上に表示）
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.position = Vector2(750, 10)
	_tooltip_panel.size = Vector2(265, 0)
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 90
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 11)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(249, 0)
	_tooltip_panel.add_child(_tooltip_label)
	main.add_child(_tooltip_panel)

	_drag_label = Label.new()
	_drag_label.add_theme_font_size_override("font_size", 14)
	_drag_label.modulate = Color(1.0, 1.0, 0.3)
	_drag_label.visible = false
	_drag_label.z_index = 100
	main.add_child(_drag_label)

	# ---- 左側デッキエディタパネル ----
	var deck_bg := ColorRect.new()
	deck_bg.position = Vector2(0, 0)
	deck_bg.size = Vector2(155, 720)
	deck_bg.color = Color(0.06, 0.1, 0.06)
	main.add_child(deck_bg)

	_deck_title_label = Label.new()
	_deck_title_label.text = "プレイヤーデッキ (0枚)"
	_deck_title_label.position = Vector2(6, 4)
	_deck_title_label.add_theme_font_size_override("font_size", 11)
	_deck_title_label.modulate = Color(0.5, 1.0, 0.5)
	main.add_child(_deck_title_label)

	var deck_tools_y: int = 22
	var deck_btns: Array = [
		{"text": "シャッフル", "cb": _on_deck_shuffle},
		{"text": "全削除",     "cb": _on_deck_clear},
	]
	for i in range(deck_btns.size()):
		var db := Button.new()
		db.text = deck_btns[i]["text"]
		db.position = Vector2(4 + i * 76, deck_tools_y)
		db.size = Vector2(73, 22)
		db.add_theme_font_size_override("font_size", 10)
		db.pressed.connect(deck_btns[i]["cb"])
		main.add_child(db)
	deck_tools_y += 26

	_deck_scroll = ScrollContainer.new()
	_deck_scroll.position = Vector2(0, deck_tools_y)
	_deck_scroll.size = Vector2(155, 720 - deck_tools_y - 6)
	main.add_child(_deck_scroll)

	_deck_container = VBoxContainer.new()
	_deck_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_scroll.add_child(_deck_container)

	_refresh_deck_list()

func _refresh_deck_list(force: bool = true) -> void:
	# デッキまたは捨て札のサイズが変化した場合のみリフレッシュ
	var current_size: int = deck_manager.deck.size() * 1000 + deck_manager.discard.size()
	if not force and current_size == _last_deck_size:
		return
	_last_deck_size = current_size
	# デッキ一覧を再構築
	for child in _deck_container.get_children():
		child.queue_free()
	var deck_arr: Array = deck_manager.deck
	_deck_title_label.text = "プレイヤーデッキ (%d枚)" % deck_arr.size()
	for i in range(deck_arr.size()):
		var card = deck_arr[i]
		var hbox := HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(150, 22)
		# カード名ラベル
		var lbl := Label.new()
		var display: String = "%d. %s (%d)" % [i + 1, card.unit_name, card.cost]
		lbl.text = display
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if card.card_type == "unit":
			lbl.modulate = Color(0.7, 0.85, 1.0)
		elif card.card_type == "status_spell":
			lbl.modulate = Color(0.8, 0.3, 0.8)
		else:
			lbl.modulate = Color(0.5, 0.8, 0.5)
		# 右クリックで削除
		lbl.gui_input.connect(_on_deck_card_input.bind(i))
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		hbox.add_child(lbl)
		# 上移動ボタン
		if i > 0:
			var up_btn := Button.new()
			up_btn.text = "↑"
			up_btn.custom_minimum_size = Vector2(22, 20)
			up_btn.add_theme_font_size_override("font_size", 10)
			up_btn.pressed.connect(_on_deck_move_up.bind(i))
			hbox.add_child(up_btn)
		_deck_container.add_child(hbox)
	# 捨て札表示
	var discard_lbl := Label.new()
	discard_lbl.text = "── 捨て札 (%d枚) ──" % deck_manager.discard.size()
	discard_lbl.add_theme_font_size_override("font_size", 10)
	discard_lbl.modulate = Color(0.5, 0.5, 0.4)
	_deck_container.add_child(discard_lbl)
	for card in deck_manager.discard:
		var lbl := Label.new()
		lbl.text = "  %s (%d)" % [card.unit_name, card.cost]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.modulate = Color(0.4, 0.4, 0.35)
		_deck_container.add_child(lbl)

func _on_deck_shuffle() -> void:
	deck_manager.deck.shuffle()
	_refresh_deck_list()
	main._add_log("[DEV] デッキシャッフル")

func _on_deck_clear() -> void:
	deck_manager.deck.clear()
	deck_manager.discard.clear()
	deck_manager.ensure_shuffle_card()  # シャッフルカードは除外不可
	_refresh_deck_list()
	main._add_log("[DEV] デッキ全削除")

func _on_deck_move_up(index: int) -> void:
	var arr: Array = deck_manager.deck
	if index > 0 and index < arr.size():
		# シャッフルカードは最下部固定（移動不可）
		if arr[index].unit_name == "シャッフル" or arr[index - 1].unit_name == "シャッフル":
			return
		var tmp = arr[index]
		arr[index] = arr[index - 1]
		arr[index - 1] = tmp
	_refresh_deck_list()

func _on_deck_remove(index: int) -> void:
	var arr: Array = deck_manager.deck
	if index >= 0 and index < arr.size():
		# シャッフル���ードは除外不可
		if arr[index].unit_name == "シャッフル":
			return
		arr.remove_at(index)
	_refresh_deck_list()
	main._add_log("[DEV] デッキからカード削除")

func _on_deck_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_on_deck_remove(index)

func on_drop_to_deck() -> void:
	if selected_card == null:
		return
	var card = selected_card.clone() if selected_card.card_type == "unit" else selected_card
	# シャッフルカードの上（最下部の1つ上）に挿入
	var arr: Array = deck_manager.deck
	var insert_pos: int = arr.size()
	if arr.size() > 0 and arr[arr.size() - 1].unit_name == "シャッフル":
		insert_pos = arr.size() - 1
	arr.insert(insert_pos, card)
	_refresh_deck_list()
	main._add_log("[DEV] %s をデッキに追加" % selected_card.unit_name)

func _add_section_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.6, 0.6, 0.5)
	card_list_container.add_child(lbl)

func _add_card_button(index: int, card_name: String, color: Color) -> void:
	var btn := Button.new()
	btn.text = card_name
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(240, 24)
	btn.add_theme_font_size_override("font_size", 11)
	btn.modulate = color
	btn.button_down.connect(_on_card_mouse_down.bind(index))
	btn.mouse_entered.connect(_on_card_hover.bind(index))
	btn.mouse_exited.connect(_on_card_hover_end)
	card_list_container.add_child(btn)

# ---- カード操作 ----

func _build_card(index: int) -> Object:
	var card = _all_cards[index]
	var UnitDataScript = load("res://scripts/UnitData.gd")
	var obj = UnitDataScript.new()
	if card["type"] == "unit":
		var d = card["data"]
		obj.unit_name = card["name"]; obj.max_hp = d["hp"]; obj.current_hp = d["hp"]
		obj.attack = d["atk"]; obj.attack_interval = d["interval"]; obj.cost = d["cost"]
		obj.assigned_col = d["col"]; obj.race = d["race"]; obj.attack_range = d["range"]
		obj.support_effect = ""; obj.active_skill = ""
		obj.skills = d.get("skills", []).duplicate(true)
	elif card["type"] in ["artifact", "permanent_artifact"]:
		# アーティファクト: UnitDataを軽量ラッパーとして使用
		var d = card["data"]
		obj.unit_name = card["name"]
		obj.card_type = card["type"]
		obj.cost = 0
		obj.skills = d.get("skills", []).duplicate(true)
	else:
		var d = card["data"]
		obj.unit_name = card["name"]; obj.card_type = card["type"]
		obj.spell_id = card["name"]; obj.cost = d["cost"]
		obj.spell_target = d["target"]; obj.spell_effect = d["effect"]
		obj.is_consumable = (card["type"] == "status_spell")
		obj.skills = d.get("skills", []).duplicate(true)
	return obj

func _on_card_mouse_down(index: int) -> void:
	selected_card = _build_card(index)
	_drag_start_pos = main.get_viewport().get_mouse_position()
	_dragging = true
	_drag_label.text = selected_card.unit_name
	_drag_label.visible = true
	selected_label.text = "ドラッグ中: " + selected_card.unit_name

func _stop_drag() -> void:
	_dragging = false
	if _drag_label != null:
		_drag_label.visible = false
	if _pending_tile_effect == "":
		selected_label.text = "クリック=通常発動 / ドラッグ=対象指定"

func on_drop(side: int, row: int, col: int) -> void:
	# 盤面効果設置モード
	if _pending_tile_effect != "":
		if _pending_tile_effect == "clear":
			board_manager.clear_tile_effect(side, row, col)
			main._add_log("[DEV] 盤面効果解除: %d行col%d" % [row, col])
		else:
			var _EDB_drop = load("res://scripts/EffectDB.gd")
			var def_drop = _EDB_drop.EFFECTS.get(_pending_tile_effect, {})
			var duration_drop: float = def_drop.get("duration", -1.0)
			board_manager.set_tile_effect(side, row, col, _pending_tile_effect, duration_drop)
			var display_drop: String = def_drop.get("display", _pending_tile_effect)
			main._add_log("[DEV] 盤面効果設置: %s → %d行col%d" % [display_drop, row, col])
		_pending_tile_effect = ""
		selected_label.text = "クリック=通常発動 / ドラッグ=対象指定"
		_stop_drag()
		main._mark_all_cells_dirty()
		return
	# ドラッグ距離が短い → クリック扱い（通常発動）
	var dist: float = main.get_viewport().get_mouse_position().distance_to(_drag_start_pos)
	if dist < 30.0:
		_normal_play(selected_card)
		return
	# ドラッグ → 手動配置
	_manual_place(selected_card, side, row, col)

func on_drop_outside() -> void:
	# セル外ドロップ → ドラッグ距離が短ければクリック扱い
	var dist: float = main.get_viewport().get_mouse_position().distance_to(_drag_start_pos)
	if dist < 30.0:
		_normal_play(selected_card)

func _normal_play(card: Object) -> void:
	if card == null:
		return
	if card.card_type == "artifact":
		# 盤面出現型アーティファクト: ランダム空きマスに配置
		var placed_art: bool = false
		var cells: Array = []
		for r2 in range(3):
			for c2 in range(3):
				if board_manager.board[0][r2][c2] == null and board_manager.board_artifacts[0][r2][c2] == null:
					cells.append([r2, c2])
		cells.shuffle()
		if not cells.is_empty():
			board_manager.place_artifact(0, cells[0][0], cells[0][1], {"name": card.unit_name})
			main._add_log("[DEV通常] アーティファクト %s を自陣に配置" % card.unit_name)
			placed_art = true
		if not placed_art:
			main._add_log("[DEV通常] 空きマスなし: %s" % card.unit_name)
		main._mark_all_cells_dirty()
		return
	elif card.card_type == "permanent_artifact":
		# 永久効果型: player_artifactsに追加
		var _CDB_np = load("res://scripts/CardDB.gd")
		var art_def_np = _CDB_np.ARTIFACTS.get(card.unit_name, {})
		var art_entry_np: Dictionary = {"name": card.unit_name, "skills": art_def_np.get("skills", []).duplicate(true)}
		board_manager.player_artifacts.append(art_entry_np)
		board_manager.on_board_changed()
		main._add_log("[DEV通常] 永久アーティファクト %s を追加" % card.unit_name)
		return
	if card.card_type == "unit":
		board_manager.place_unit(0, card)
		main._add_log("[DEV通常] %s を自陣に召喚" % card.unit_name)
	elif card.card_type in ["spell", "status_spell"]:
		if deck_manager._try_spell_synthesis(0, card, board_manager):
			main._add_log("[DEV通常] %s で盤面合成" % card.spell_id)
		else:
			deck_manager.spell_executor.execute(card, 0, board_manager, deck_manager, enemy_ai)
			main._add_log("[DEV通常] %s 発動" % card.spell_id)
	main._mark_all_cells_dirty()
	_refresh_deck_list()

func _manual_place(card: Object, side: int, row: int, col: int) -> void:
	if card == null:
		return
	var side_name: String = "自陣" if side == 0 else "敵陣"
	if card.card_type == "artifact":
		# 盤面出現型アーティファクトをドロップ先に配置
		board_manager.place_artifact(side, row, col, {"name": card.unit_name})
		main._add_log("[DEV] アーティファクト %s → %s %d行col%d" % [card.unit_name, side_name, row, col])
		main._mark_all_cells_dirty()
		return
	elif card.card_type == "permanent_artifact":
		# 永久効果型: player_artifacts / enemy_artifactsに追加
		var _CDB_pa = load("res://scripts/CardDB.gd")
		var art_def_pa = _CDB_pa.ARTIFACTS.get(card.unit_name, {})
		var art_entry: Dictionary = {"name": card.unit_name, "skills": art_def_pa.get("skills", []).duplicate(true)}
		if side == 0:
			board_manager.player_artifacts.append(art_entry)
		else:
			board_manager.enemy_artifacts.append(art_entry)
		board_manager.on_board_changed()
		main._add_log("[DEV] 永久アーティファクト %s → %s に追加" % [card.unit_name, side_name])
		return
	if card.card_type == "unit":
		var existing = board_manager.board[side][row][col]
		if existing != null:
			var result = board_manager._check_synthesis(existing.unit_name, card)
			if result != null:
				board_manager._execute_synthesis(side, row, col, existing, result)
				main._add_log("[DEV] 合成: %s + %s → %s" % [existing.unit_name, card.unit_name, result.unit_name])
			else:
				main._add_log("[DEV] 合成不可・セル埋まり")
		else:
			# アーティファクト排他チェック
			if board_manager.board_artifacts[side][row][col] != null:
				main._add_log("[DEV] アーティファクトがあるため配置不可")
				return
			var placed = card.clone()
			board_manager.board[side][row][col] = placed
			board_manager.attack_timers[side][row][col] = placed.attack_interval
			board_manager._init_skill_timers(placed)
			board_manager._push_summon_effects(side, row, col, placed)
			board_manager._check_tile_on_enter(side, row, col, placed)
			board_manager.emit_signal("unit_placed", side, row, col, placed)
			board_manager.on_board_changed()
			main._add_log("[DEV] %s → %s %d行col%d" % [placed.unit_name, side_name, row, col])
	elif card.card_type in ["spell", "status_spell"]:
		# 呪文の盤面合成はドロップ先sideで判定
		var existing = board_manager.board[side][row][col]
		if existing != null:
			var result = board_manager._check_synthesis(existing.unit_name, card)
			if result != null:
				board_manager._execute_synthesis(side, row, col, existing, result)
				main._add_log("[DEV] 合成: %s + %s → %s" % [existing.unit_name, card.spell_id, result.unit_name])
				main._mark_all_cells_dirty()
				return
		# 呪文効果はside=0（プレイヤー発動）固定（enemy_side逆転を防ぐ）
		deck_manager.spell_executor.execute(card, 0, board_manager, deck_manager, enemy_ai)
		main._add_log("[DEV] 呪文 %s 発動" % card.spell_id)
	main._mark_all_cells_dirty()
	_refresh_deck_list()

# ---- カードホバー詳細 ----

func _on_card_hover(index: int) -> void:
	var card = _all_cards[index]
	var d = card["data"]
	var lines: Array = []
	if card["type"] == "unit":
		lines.append("[%s] %s" % [d.get("race", ""), card["name"]])
		lines.append("Cost: %d" % d["cost"])
		lines.append("HP: %d / ATK: %d / SPD: %.1fs" % [d["hp"], d["atk"], d["interval"]])
		lines.append("攻撃範囲: %s" % d.get("range", "1行"))
		# skills配列からdisplay名で表示
		var _EDB = load("res://scripts/EffectDB.gd")
		var support_names: Array = []
		var active_names: Array = []
		for skill in d.get("skills", []):
			var eid: String = skill.get("effect_id", "")
			var display: String = eid
			if _EDB != null and _EDB.EFFECTS.has(eid):
				display = _EDB.EFFECTS[eid].get("display", eid)
			if skill.get("trigger", "") == "always":
				support_names.append(display)
			else:
				active_names.append(display)
		if support_names.size() > 0:
			lines.append("")
			lines.append("■ サポート: " + ", ".join(support_names))
		if active_names.size() > 0:
			lines.append("")
			lines.append("■ スキル: " + ", ".join(active_names))
	elif card["type"] == "artifact":
		lines.append("[アーティファクト] %s" % card["name"])
		lines.append("HP: %d" % d.get("hp", 0))
		var _EDB_art = load("res://scripts/EffectDB.gd")
		var art_active: Array = []
		for sk in d.get("skills", []):
			var eid_a: String = sk.get("effect_id", "")
			var disp_a: String = _EDB_art.EFFECTS.get(eid_a, {}).get("display", eid_a)
			var trig_a: String = sk.get("trigger", "")
			art_active.append("- %s（%s）" % [disp_a, trig_a])
		if art_active.size() > 0:
			lines.append("")
			lines.append("■ スキル:")
			lines.append_array(art_active)
	elif card["type"] == "permanent_artifact":
		lines.append("[永久アーティファクト] %s" % card["name"])
		var _EDB_part = load("res://scripts/EffectDB.gd")
		var perm_lines: Array = []
		for sk in d.get("skills", []):
			var eid_p: String = sk.get("effect_id", "")
			var disp_p: String = _EDB_part.EFFECTS.get(eid_p, {}).get("display", eid_p)
			perm_lines.append("- %s（常時）" % disp_p)
		if perm_lines.size() > 0:
			lines.append("")
			lines.append("■ 永久効果:")
			lines.append_array(perm_lines)
	elif card["type"] == "spell":
		lines.append("[呪文] %s" % card["name"])
		lines.append("Cost: %s" % ("X" if d["cost"] == -1 else str(d["cost"])))
		lines.append("")
		lines.append("■ 効果:")
		lines.append("  " + d["effect"])
	elif card["type"] == "status_spell":
		lines.append("[異常状態] %s" % card["name"])
		lines.append("Cost: 0 (消滅型)")
		lines.append("")
		lines.append("■ 効果:")
		lines.append("  " + d["effect"])
	_tooltip_label.text = "\n".join(lines)
	_tooltip_panel.visible = true
	_tooltip_panel.size = Vector2(265, 0)  # 高さ自動調整

func _on_card_hover_end() -> void:
	_tooltip_panel.visible = false

# ---- ツールボタン ----

func _on_toggle_pause() -> void:
	main.game_paused = not main.game_paused
	main._add_log("[DEV] %s" % ("一時停止" if main.game_paused else "再開"))

func _on_max_mana() -> void:
	deck_manager.mana = deck_manager.MANA_MAX
	main._add_log("[DEV] マナMAX")

func _on_kill_allies() -> void:
	for r in range(3):
		for c in range(3):
			if board_manager.board[0][r][c] != null:
				board_manager.remove_unit(0, r, c)
	main._add_log("[DEV] 味方全滅")

func _on_kill_enemies() -> void:
	for r in range(3):
		for c in range(3):
			if board_manager.board[1][r][c] != null:
				board_manager.remove_unit(1, r, c)
	main._add_log("[DEV] 敵全滅")

func _on_heal_all() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board_manager.board[s][r][c]
				if u != null:
					u.current_hp = u.max_hp
	main._add_log("[DEV] 全回復")
	main._mark_all_cells_dirty()

func _on_damage_allies() -> void:
	for r in range(3):
		for c in range(3):
			var u = board_manager.board[0][r][c]
			if u != null:
				u.take_damage(10)
				if not u.is_alive():
					board_manager.remove_unit(0, r, c)
	main._add_log("[DEV] 味方10dmg")
	main._mark_all_cells_dirty()

func _on_damage_enemies() -> void:
	for r in range(3):
		for c in range(3):
			var u = board_manager.board[1][r][c]
			if u != null:
				u.take_damage(10)
				if not u.is_alive():
					board_manager.remove_unit(1, r, c)
	main._add_log("[DEV] 敵10dmg")
	main._mark_all_cells_dirty()

func _on_clear_debuffs() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board_manager.board[s][r][c]
				if u != null:
					u.burn_turns = 0; u.frozen_turns = 0
					u.paralysis_turns = 0; u.poison_stacks = 0
	main._add_log("[DEV] デバフ解除")
	main._mark_all_cells_dirty()

func _on_heal_player_base() -> void:
	main.base_hp[0] = 30
	main._update_base_hp()
	main._add_log("[DEV] 自本体HP全回復")

func _on_heal_enemy_base() -> void:
	main.base_hp[1] = 30
	main._update_base_hp()
	main._add_log("[DEV] 敵本体HP全回復")

func _on_heal_both_base() -> void:
	main.base_hp[0] = 30
	main.base_hp[1] = 30
	main._update_base_hp()
	main._add_log("[DEV] 両本体HP全回復")

func _on_run_tests() -> void:
	main._add_log("=== テスト開始 ===")
	var TestRunnerScript = load("res://scripts/TestRunner.gd")
	if TestRunnerScript == null:
		main._add_log("ERROR: TestRunner.gd ロード失敗")
		return
	var runner = TestRunnerScript.new()
	var result: String = runner.run_all()
	for line in result.split("\n"):
		if line != "":
			main._add_log(line)
	main._add_log("=== テスト完了 ===")

func _on_back_to_menu() -> void:
	main.get_tree().reload_current_scene()

func _on_set_speed(speed: float) -> void:
	main.game_speed = speed
	main._add_log("[DEV] ゲームスピード x%s" % str(speed))

func _on_tile_effect_select(eid: String) -> void:
	_pending_tile_effect = eid
	var _EDB_sel = load("res://scripts/EffectDB.gd")
	var display = _EDB_sel.EFFECTS[eid].get("display", eid)
	selected_label.text = "盤面効果: " + display + " → セルをクリック"

func _on_tile_effect_clear() -> void:
	_pending_tile_effect = "clear"
	selected_label.text = "盤面効果解除 → セルをクリック"

func _on_equip_toggle(eq_name: String) -> void:
	if board_manager.player_data == null:
		return
	var _CardDB_eq = load("res://scripts/CardDB.gd")
	var eq_def = _CardDB_eq.EQUIPMENT.get(eq_name, {})
	if eq_def.is_empty():
		return
	var pdata = board_manager.player_data
	# 既に装備中なら外す
	for i in range(pdata.equipment.size()):
		if pdata.equipment[i].get("display", "") == eq_def.get("display", ""):
			pdata.equipment.remove_at(i)
			main._apply_equipment_effects(pdata)
			main._refresh_equipment_ui()
			main._add_log("[DEV] 装備解除: %s" % eq_name)
			return
	# 装備スロット上限（3枠）
	if pdata.equipment.size() >= 3:
		main._add_log("[DEV] 装備スロット満杯（最大3）")
		return
	pdata.equipment.append({"name": eq_name, "display": eq_def.get("display", eq_name), "effect": eq_def.get("effect", ""), "skills": eq_def.get("skills", []).duplicate(true)})
	main._apply_equipment_effects(pdata)
	main._refresh_equipment_ui()
	main._add_log("[DEV] 装備: %s" % eq_name)

func _on_equip_clear_all() -> void:
	if board_manager.player_data == null:
		return
	board_manager.player_data.equipment.clear()
	main._apply_equipment_effects(board_manager.player_data)
	main._refresh_equipment_ui()
	main._add_log("[DEV] 装備全解除")

func _on_class_select(class_id: String) -> void:
	var _CardDB = load("res://scripts/CardDB.gd").new()
	var cdef = _CardDB.CLASSES[class_id]
	var PlayerDataScript = load("res://scripts/PlayerData.gd")
	var pdata = PlayerDataScript.new()
	pdata.class_id = class_id
	pdata.class_name_jp = cdef["display"]
	pdata.initial_mana = cdef["initial_mana"]
	pdata.mana_max = cdef["mana_max"]
	pdata.mana_regen = cdef["mana_regen"]
	pdata.skills = cdef["skills"].duplicate(true)
	pdata.reset_runtime()
	board_manager.player_data = pdata
	deck_manager.mana = pdata.initial_mana
	deck_manager.MANA_MAX = pdata.mana_max
	deck_manager.MANA_REGEN = pdata.mana_regen
	main._add_log("[DEV] クラス変更: %s" % cdef["display"])
