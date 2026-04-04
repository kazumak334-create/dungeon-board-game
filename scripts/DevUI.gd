# DevUI.gd
# 開発者モードのUI・ロジック
class_name DevUI
extends RefCounted

var main: Node
var board_manager: Node
var deck_manager: Node
var enemy_ai: Node

var selected_card: Object = null  # 選択中のカード
var selected_side: int = 0        # 配置先サイド（0=自陣, 1=敵陣）
var card_list_container: VBoxContainer
var selected_label: Label
var side_label: Label
var card_buttons: Array = []
var _all_cards: Array = []  # {name, data, type} の配列

func setup(p_main: Node, p_board: Node, p_deck: Node, p_enemy: Node) -> void:
	main = p_main
	board_manager = p_board
	deck_manager = p_deck
	enemy_ai = p_enemy
	_build_all_cards()
	_build_dev_panel()

func _build_all_cards() -> void:
	# ユニットカード
	var unit_defs: Array = [
		{"name": "アメーバ",       "hp": 5,  "atk": 1, "interval": 0.5, "cost": 1, "race": "スライム",   "range": "1行",       "col": 0, "support": "HPバフ〈常時発動・前列の味方のみ・微回復〉", "active": "追加召喚〈召喚時・隣接マスに同種を1体〉"},
		{"name": "マッドスライム", "hp": 10, "atk": 2, "interval": 1.0, "cost": 1, "race": "スライム",   "range": "1行",       "col": 1, "support": "障壁付与〈常時発動・同行前列の味方・物理軽減〉", "active": "火傷付与〈命中時・敵ATK低下〉 / SPD低下〈時間経過10s・同行の敵全体〉"},
		{"name": "ブラッドスライム","hp": 12, "atk": 4, "interval": 1.5, "cost": 2, "race": "スライム",   "range": "1行",       "col": 2, "support": "吸血付与〈常時発動・隣接の味方〉", "active": "吸血〈命中時・ダメージ30%回復〉 / 全体回復〈時間経過20s・HP20%消費→全味方+10〉"},
		{"name": "スケルトン",     "hp": 20, "atk": 4, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "1行",       "col": 0, "support": "再起付与〈常時発動・隣接の味方・HP1で1度復活〉", "active": "自己再起〈撃破時・HP5で復活〉"},
		{"name": "グール",         "hp": 25, "atk": 5, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "1行",       "col": 1, "support": "デバフ波及〈常時発動・前列の敵・撃破時に周囲の敵にデバフ波及〉", "active": "吸血〈命中時・ダメージ25%回復〉 / ATK累積〈撃破時・+2（上限10）〉"},
		{"name": "バンシー",       "hp": 10, "atk": 1, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "上下含む3行","col": 2, "support": "後列攻撃〈常時発動・全行・極低ATK・命中時効果あり〉 / SPDバフ〈常時発動・同列の味方〉", "active": "火傷付与〈命中時・敵ATK低下〉 / 全体ATK低下〈時間経過15s・敵全行〉 / 敵SPD低下〈撃破時・全体30%・30s〉"},
		{"name": "ゴブリン",       "hp": 15, "atk": 3, "interval": 1.0, "cost": 1, "race": "獣",        "range": "1行",       "col": 0, "support": "ATKバフ〈常時発動・隣接の獣のみ〉", "active": "2枚ドロー〈召喚時・次の2枚をキューに同時積み〉"},
		{"name": "ウルフ",         "hp": 20, "atk": 5, "interval": 1.5, "cost": 2, "race": "獣",        "range": "1行",       "col": 1, "support": "SPDバフ〈常時発動・同行の獣・同行獣数に比例〉", "active": "ATKバフ〈時間経過10s・同行の獣全員+3（5s）〉"},
		{"name": "タイガー",       "hp": 25, "atk": 8, "interval": 2.0, "cost": 3, "race": "獣",        "range": "下含む2行", "col": 2, "support": "ATKバフ〈常時発動・隣接の獣のみ〉", "active": "クリティカル〈命中時・初撃ATK×2〉 / 最前列突撃〈召喚時〉 / 単体大ダメージ〈時間経過20s〉"},
	]
	for d in unit_defs:
		_all_cards.append({"name": d["name"], "data": d, "type": "unit"})

	# 呪文カード（SpellExecutorの全呪文）
	var spell_defs: Array = [
		# 自己強化系
		{"name": "召喚加速",     "cost": 1, "target": "self",        "effect": "マナ即時+3回復"},
		{"name": "血の契約",     "cost": 2, "target": "single_ally", "effect": "対象1体に吸血付与"},
		{"name": "戦場の鼓動",   "cost": 2, "target": "all_allies",  "effect": "全味方SPD+50%（5s）"},
		{"name": "急召",         "cost": 1, "target": "self",        "effect": "低コストユニット1体即時召喚"},
		{"name": "連鎖の触媒",   "cost": 2, "target": "self",        "effect": "次の3枚コスト-1"},
		{"name": "強化の儀式",   "cost": 3, "target": "single_ally", "effect": "対象1体ATK+5・HP+10"},
		{"name": "盤面強化",     "cost": 3, "target": "all_allies",  "effect": "全味方HP+10・ATK+2"},
		{"name": "圧縮の書",     "cost": 2, "target": "self",        "effect": "山札から異常状態カード除去"},
		{"name": "再召喚",       "cost": -1,"target": "self",        "effect": "捨て札からコストXのユニット召喚"},
		{"name": "先読みの書",   "cost": 3, "target": "self",        "effect": "次の2枚を即時発動"},
		{"name": "召喚の呼び声", "cost": 2, "target": "self",        "effect": "最低コストユニットをデッキ先頭に"},
		{"name": "怒涛の展開",   "cost": 4, "target": "self",        "effect": "次の3枚を即時発動"},
		{"name": "生命の雫",     "cost": 2, "target": "single_ally", "effect": "対象1体HP15%回復"},
		# 相手弱体・環境操作系
		{"name": "泥の鎧",       "cost": 1, "target": "single_ally", "effect": "対象1体に鎧付与"},
		{"name": "結晶化",       "cost": 3, "target": "single_ally", "effect": "対象1体に呪文無効（1回）"},
		{"name": "毒霧",         "cost": 2, "target": "column",      "effect": "敵ランダム列に毒5＋自デッキに毒カード"},
		{"name": "寒波",         "cost": 2, "target": "front_all",   "effect": "前列全体に凍結＋両デッキに凍結カード"},
		{"name": "山火事",       "cost": 2, "target": "front_all",   "effect": "前列全体に火傷＋両デッキに火傷カード"},
		{"name": "落雷",         "cost": 3, "target": "front_all",   "effect": "前列全体に10dmg＋麻痺＋両デッキに麻痺カード"},
		{"name": "烈風斬",       "cost": 3, "target": "all_enemies", "effect": "敵全体に中ダメージ"},
		{"name": "弱体の呪詛",   "cost": 3, "target": "all_enemies", "effect": "敵全体ATK-30%（20s）"},
		{"name": "盤面凍結",     "cost": 4, "target": "all_enemies", "effect": "敵全体を8s間凍結"},
		# 位置変化系
		{"name": "混沌の手",     "cost": 2, "target": "single_enemy","effect": "敵1体をランダム行に移動"},
		{"name": "反転の波",     "cost": 3, "target": "all_enemies", "effect": "敵前列と後列を入れ替え"},
		{"name": "押し込み",     "cost": 2, "target": "single_enemy","effect": "敵前列1体を後列に移動"},
		# キュー干渉系
		{"name": "召喚妨害",     "cost": 1, "target": "enemy_queue", "effect": "敵の次の召喚を3s遅延"},
		{"name": "配置崩し",     "cost": 2, "target": "enemy_queue", "effect": "敵の次の召喚列をランダム化"},
		{"name": "魔力断絶",     "cost": 3, "target": "enemy_queue", "effect": "敵マナ回復-30%（10s）"},
	]
	for d in spell_defs:
		_all_cards.append({"name": d["name"], "data": d, "type": "spell"})

func _build_dev_panel() -> void:
	# 開発者パネル（画面右側）
	var panel := ColorRect.new()
	panel.position = Vector2(1020, 0)
	panel.size = Vector2(260, 720)
	panel.color = Color(0.06, 0.06, 0.1)
	main.add_child(panel)

	var title := Label.new()
	title.text = "開発者モード"
	title.position = Vector2(1030, 4)
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = Color(1.0, 0.4, 0.4)
	main.add_child(title)

	# 選択中カード表示
	selected_label = Label.new()
	selected_label.text = "選択: なし"
	selected_label.position = Vector2(1030, 28)
	selected_label.add_theme_font_size_override("font_size", 12)
	selected_label.modulate = Color(1.0, 1.0, 0.5)
	main.add_child(selected_label)

	# サイド切替
	side_label = Label.new()
	side_label.text = "配置先: 自陣"
	side_label.position = Vector2(1030, 48)
	side_label.add_theme_font_size_override("font_size", 12)
	side_label.modulate = Color(0.4, 0.9, 1.0)
	main.add_child(side_label)

	var side_btn := Button.new()
	side_btn.text = "自陣/敵陣 切替"
	side_btn.position = Vector2(1140, 44)
	side_btn.size = Vector2(130, 24)
	side_btn.add_theme_font_size_override("font_size", 11)
	side_btn.pressed.connect(_toggle_side)
	main.add_child(side_btn)

	# ツールボタン（2列配置）
	var btn_y: int = 72
	var tools_left: Array = [
		["マナ+10", _on_add_mana],
		["全味方回復", _on_heal_all],
		["呪文発動", _on_cast_spell],
	]
	var tools_right: Array = [
		["敵全滅", _on_kill_enemies],
		["選択解除", _on_deselect],
		["モード選択に戻る", _on_back_to_menu],
	]
	for i in range(tools_left.size()):
		var btn_l := Button.new()
		btn_l.text = tools_left[i][0]
		btn_l.position = Vector2(1025, btn_y + i * 28)
		btn_l.size = Vector2(120, 24)
		btn_l.add_theme_font_size_override("font_size", 10)
		btn_l.pressed.connect(tools_left[i][1])
		main.add_child(btn_l)
	for i in range(tools_right.size()):
		var btn_r := Button.new()
		btn_r.text = tools_right[i][0]
		btn_r.position = Vector2(1150, btn_y + i * 28)
		btn_r.size = Vector2(120, 24)
		btn_r.add_theme_font_size_override("font_size", 10)
		btn_r.pressed.connect(tools_right[i][1])
		main.add_child(btn_r)
	btn_y += tools_left.size() * 28 + 8

	# カードリスト（スクロール）
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(1020, btn_y)
	scroll.size = Vector2(260, 720 - btn_y - 10)
	main.add_child(scroll)

	card_list_container = VBoxContainer.new()
	card_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_list_container)

	# ユニットヘッダー
	_add_section_header("── ユニット ──")
	for i in range(_all_cards.size()):
		var card = _all_cards[i]
		if card["type"] != "unit":
			continue
		_add_card_button(i, card["name"], Color(0.7, 0.85, 1.0))

	# 呪文ヘッダー
	_add_section_header("── 呪文（自己強化） ──")
	for i in range(_all_cards.size()):
		var card = _all_cards[i]
		if card["type"] != "spell":
			continue
		var d = card["data"]
		if d["target"] == "self" or d["target"] == "single_ally" or d["target"] == "all_allies":
			_add_card_button(i, "%s (%d)" % [card["name"], d["cost"]], Color(0.5, 0.8, 0.5))

	_add_section_header("── 呪文（弱体・環境） ──")
	for i in range(_all_cards.size()):
		var card = _all_cards[i]
		if card["type"] != "spell":
			continue
		var d = card["data"]
		if d["target"] in ["column", "front_all", "all_enemies", "single_enemy"]:
			_add_card_button(i, "%s (%d)" % [card["name"], d["cost"]], Color(1.0, 0.5, 0.5))

	_add_section_header("── 呪文（キュー干渉） ──")
	for i in range(_all_cards.size()):
		var card = _all_cards[i]
		if card["type"] != "spell":
			continue
		var d = card["data"]
		if d["target"] == "enemy_queue":
			_add_card_button(i, "%s (%d)" % [card["name"], d["cost"]], Color(1.0, 0.8, 0.4))

func _add_section_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.6, 0.6, 0.5)
	card_list_container.add_child(lbl)

func _add_card_button(index: int, card_name: String, color: Color) -> void:
	var btn := Button.new()
	btn.text = card_name
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(240, 26)
	btn.add_theme_font_size_override("font_size", 11)
	btn.modulate = color
	btn.pressed.connect(_on_card_selected.bind(index))
	card_list_container.add_child(btn)
	card_buttons.append(btn)

func _on_card_selected(index: int) -> void:
	var card = _all_cards[index]
	var UnitDataScript = load("res://scripts/UnitData.gd")
	selected_card = UnitDataScript.new()

	if card["type"] == "unit":
		var d: Dictionary = card["data"]
		selected_card.unit_name = d["name"]
		selected_card.max_hp = d["hp"]
		selected_card.current_hp = d["hp"]
		selected_card.attack = d["atk"]
		selected_card.attack_interval = d["interval"]
		selected_card.cost = d["cost"]
		selected_card.assigned_col = d["col"]
		selected_card.race = d["race"]
		selected_card.attack_range = d["range"]
		selected_card.support_effect = d["support"]
		selected_card.active_skill = d["active"]
		selected_label.text = "選択: %s (ユニット)" % d["name"]
	elif card["type"] == "spell":
		var d: Dictionary = card["data"]
		selected_card.unit_name = d["name"]
		selected_card.card_type = "spell"
		selected_card.spell_id = d["name"]
		selected_card.cost = d["cost"]
		selected_card.spell_target = d["target"]
		selected_card.spell_effect = d["effect"]
		selected_label.text = "選択: %s (呪文)" % d["name"]

func on_cell_clicked(side: int, row: int, col: int) -> void:
	if selected_card == null:
		return
	if selected_card.card_type == "unit":
		# ユニット配置（指定セルに直接配置）
		var target_side: int = selected_side
		if board_manager.board[target_side][row][col] != null:
			main._add_log("[DEV] セルが埋まっています")
			return
		var placed = selected_card.clone()
		board_manager.board[target_side][row][col] = placed
		board_manager.attack_timers[target_side][row][col] = placed.attack_interval
		board_manager._init_skill_timers(placed)
		board_manager.emit_signal("unit_placed", target_side, row, col, placed)
		board_manager.on_board_changed()
		main._add_log("[DEV] %s を %s %d行col%d に配置" % [placed.unit_name, "自陣" if target_side == 0 else "敵陣", row, col])
	elif selected_card.card_type == "spell":
		_cast_selected_spell()
	main._mark_all_cells_dirty()

func _cast_selected_spell() -> void:
	if selected_card == null or selected_card.card_type != "spell":
		main._add_log("[DEV] 呪文が選択されていません")
		return
	var spell = selected_card.clone()
	var executor = deck_manager.spell_executor
	if executor != null:
		executor.execute(spell, selected_side, board_manager, deck_manager, enemy_ai)
		main._add_log("[DEV] 呪文 %s を発動（%s）" % [spell.spell_id, "自陣" if selected_side == 0 else "敵陣"])
	main._mark_all_cells_dirty()

func _toggle_side() -> void:
	selected_side = 1 - selected_side
	side_label.text = "配置先: %s" % ("自陣" if selected_side == 0 else "敵陣")

func _on_add_mana() -> void:
	deck_manager.mana = min(deck_manager.MANA_MAX, deck_manager.mana + 10.0)
	main._add_log("[DEV] マナ+10")

func _on_heal_all() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = board_manager.board[s][r][c]
				if u != null:
					u.current_hp = u.max_hp
	main._add_log("[DEV] 全ユニット全回復")
	main._mark_all_cells_dirty()

func _on_kill_enemies() -> void:
	for r in range(3):
		for c in range(3):
			if board_manager.board[1][r][c] != null:
				board_manager.remove_unit(1, r, c)
	main._add_log("[DEV] 敵全滅")

func _on_cast_spell() -> void:
	_cast_selected_spell()

func _on_deselect() -> void:
	selected_card = null
	selected_label.text = "選択: なし"

func _on_back_to_menu() -> void:
	main.get_tree().reload_current_scene()
