# DeckPrep.gd
# デッキ準備画面: タブ構成（配置/アイテム/スキル）+ 上部ステータスバー + 右側解説レーン
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
var _PL = null

var _tab_buttons: Array = []
var _tab_container: Control = null
var _info_container: Control = null  # 右側解説レーン
var _current_tab: String = "placement"

# 配置タブ用
var _cell_rects: Array = []
var _cell_card_containers: Array = []
var _selected_card_idx: int = -1
var _expanded_cell: Array = [-1, -1, -1]
var _dragging: bool = false
var _drag_node: Control = null
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_source_idx: int = -1

# レイアウト定数（全座標はここから自動計算）
const TAB_BAR_H = 30       # タブバー高さ
const TAB_BAR_Y = 4        # タブバーY位置
const CONTENT_Y = TAB_BAR_Y + TAB_BAR_H + 4  # タブコンテンツ開始Y
const INFO_W = 280          # 解説レーン幅
const BOARD_X = 20
const BOARD_Y = 5
const CELL_W = 118
const CELL_H = 105
const CELL_GAP = 3
const CENTER_GAP = 24
const ROW_LABEL_W = 35
const BOARD_H = BOARD_Y + 40 + 3 * (CELL_H + CELL_GAP) + 30  # 盤面+トグルの高さ
const STATUS_H = 180        # ステータスパネル高さ

const RACE_COLORS = {
	"スライム": Color(0.3, 0.6, 0.3),
	"獣": Color(0.6, 0.4, 0.2),
	"アンデッド": Color(0.5, 0.3, 0.6),
}
const SPELL_COLOR = Color(0.3, 0.4, 0.6)
const DEFAULT_COLOR = Color(0.3, 0.3, 0.4)

func _ready() -> void:
	_PL = load("res://scripts/PlacementLogic.gd")
	if GameSession.placement_config.size() == 0 and GameSession.selected_deck.size() > 0:
		GameSession.placement_config = _PL.generate_default_config(GameSession.selected_deck)
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	# ステータスパネル（左上・常時表示）
	_build_status_panel()

	# タブバー（ステータスの右に配置）
	_build_tab_bar()

	# タブコンテナ（ステータス下+タブバー下）
	var content_top = STATUS_H + TAB_BAR_H + 12
	var content_h = 720 - content_top - 8
	_tab_container = Control.new()
	_tab_container.position = Vector2(0, content_top)
	_tab_container.size = Vector2(1280 - INFO_W - 10, content_h)
	add_child(_tab_container)

	# 右側解説レーン
	_build_info_lane()

	_show_tab("placement")

	UIF.add_button(self, "マップへ", Vector2(700, 5), Vector2(120, 28), 13,
		func(): SceneManager.go_to(SceneManager.MAP_SELECT))
	UIF.add_back_button(self, "← タイトルへ", func():
		GameSession.reset()
		SceneManager.go_to(SceneManager.TITLE)
	, 692)

# ===== ステータスパネル（左上・常時表示） =====

func _build_status_panel() -> void:
	var y_offset: float = 0.0
	var cls = CardDB.CLASSES.get(GameSession.class_id, {})

	var total_cost: float = 0.0
	var unit_count: int = 0
	var spell_count: int = 0
	for entry in GameSession.selected_deck:
		var n = entry.get("name", "") if entry is Dictionary else str(entry)
		if CardDB.UNITS.has(n):
			total_cost += CardDB.UNITS[n].get("cost", 0)
			unit_count += 1
		elif CardDB.SPELLS.has(n):
			total_cost += CardDB.SPELLS[n].get("cost", 0)
			spell_count += 1
		elif CardDB.STATUS_SPELLS.has(n):
			total_cost += CardDB.STATUS_SPELLS[n].get("cost", 0)
			spell_count += 1
	var deck_size = GameSession.selected_deck.size()
	var avg_cost = total_cost / max(1, deck_size)
	var mana_regen = cls.get("mana_regen", 1.0)
	var cycle_time = total_cost / max(0.1, mana_regen)

	# パネル背景
	var panel_w = 1280 - INFO_W - 30
	var panel = UIF.create_panel(Vector2(10, 5), Vector2(panel_w, STATUS_H))
	add_child(panel)

	var header = Label.new()
	header.text = "ステータス"
	header.position = Vector2(25, 12)
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(header)

	# 3列レイアウト
	var col_w = (panel_w - 40) / 3
	var items_col1 = [
		["%s" % cls.get("display", ""), UIF.TITLE_COLOR],
		["HP: 30", UIF.TEXT_COLOR],
		["マナ: %.0f / %d" % [cls.get("initial_mana", 3), int(cls.get("mana_max", 10))], Color(0.5, 0.7, 0.9)],
		["リジェネ: %.1f/s" % mana_regen, Color(0.5, 0.7, 0.9)],
	]
	var items_col2 = [
		["デッキ: %d枚" % deck_size, UIF.TEXT_COLOR],
		["  ユニット: %d枚" % unit_count, Color(0.6, 0.7, 0.6)],
		["  呪文: %d枚" % spell_count, Color(0.6, 0.6, 0.8)],
		["平均コスト: %.1f" % avg_cost, UIF.TITLE_COLOR],
		["循環速度: 約%.0f秒/周" % cycle_time, UIF.TITLE_COLOR],
	]
	var items_col3 = [
		["所持金: %dG" % GameSession.gold, UIF.GOLD_COLOR],
		["スキルポイント: %d" % GameSession.skill_points, Color(0.5, 0.8, 0.9)],
		["素材: %d個" % GameSession.materials.size(), UIF.BENEFIT_COLOR],
	]

	var cols = [items_col1, items_col2, items_col3]
	for ci in range(3):
		var cx = 25 + ci * col_w
		var cy: float = 35
		for item in cols[ci]:
			var lbl = Label.new()
			lbl.text = item[0]
			lbl.position = Vector2(cx, cy)
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", item[1])
			add_child(lbl)
			cy += 22

func _build_tab_bar() -> void:
	var tabs = [
		{"id": "placement", "label": "配置"},
		{"id": "items", "label": "アイテム"},
		{"id": "skill_tree", "label": "スキル"},
	]
	var x = 15
	for tab in tabs:
		var btn = Button.new()
		btn.text = tab["label"]
		btn.position = Vector2(x, STATUS_H + 8)
		btn.size = Vector2(100, TAB_BAR_H)
		btn.add_theme_font_size_override("font_size", 13)
		var tab_id = tab["id"]
		btn.pressed.connect(func(): _show_tab(tab_id))
		add_child(btn)
		_tab_buttons.append({"id": tab_id, "button": btn})
		x += 110

func _show_tab(tab_id: String) -> void:
	_current_tab = tab_id
	for tb in _tab_buttons:
		(tb["button"] as Button).modulate = Color(1, 1, 0.6) if tb["id"] == tab_id else Color(1, 1, 1)
	for child in _tab_container.get_children():
		child.queue_free()
	_cell_rects = []
	_cell_card_containers = []
	# _selected_card_idx は保持（タブ切替で解説レーンを消さない）
	_expanded_cell = [-1, -1, -1]

	match tab_id:
		"placement": _build_placement_tab()
		"items": _build_items_tab()
		_: _build_placeholder_tab(tab_id)

	_update_info_lane()

# ===== 右側解説レーン =====

func _build_info_lane() -> void:
	_info_container = Control.new()
	var info_y = STATUS_H + TAB_BAR_H + 12
	var info_h = 720 - info_y - 8
	_info_container.position = Vector2(1280 - INFO_W, info_y)
	_info_container.size = Vector2(INFO_W, info_h)
	add_child(_info_container)

	var info_h2 = 720 - (STATUS_H + TAB_BAR_H + 12) - 8
	var bg = ColorRect.new()
	bg.size = Vector2(INFO_W, info_h2)
	bg.color = Color(0.07, 0.07, 0.11)
	_info_container.add_child(bg)

	var border = ColorRect.new()
	border.position = Vector2(0, 0)
	border.size = Vector2(1, info_h2)
	border.color = Color(0.2, 0.2, 0.3)
	_info_container.add_child(border)

func _update_info_lane() -> void:
	# 背景と枠線（先頭2個）以外を削除
	var children = _info_container.get_children()
	for i in range(children.size() - 1, 1, -1):
		children[i].queue_free()

	if _selected_card_idx < 0 or _selected_card_idx >= GameSession.selected_deck.size():
		_show_info_empty()
		return

	var entry = GameSession.selected_deck[_selected_card_idx]
	var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)

	if CardDB.UNITS.has(card_name):
		_show_unit_info(card_name)
	elif CardDB.SPELLS.has(card_name):
		_show_spell_info(card_name)
	elif CardDB.STATUS_SPELLS.has(card_name):
		_show_spell_info_status(card_name)
	else:
		_show_info_empty()

func _show_info_empty() -> void:
	var hint = Label.new()
	hint.text = "カードを選択すると\n詳細が表示されます"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(10, 250)
	hint.size = Vector2(INFO_W - 20, 60)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UIF.DIM_COLOR)
	_info_container.add_child(hint)

func _show_unit_info(card_name: String) -> void:
	var d = CardDB.UNITS[card_name]
	var y = 15

	# カード名
	y = _info_label(card_name, y, 18, UIF.TITLE_COLOR)
	y += 5

	# 基本ステータス
	y = _info_label("コスト: %d" % d.get("cost", 0), y, 13, Color(0.5, 0.7, 0.9))
	y = _info_label("HP: %d  ATK: %d  SPD: %.1fs" % [d.get("hp", 0), d.get("atk", 0), d.get("interval", 0)], y, 13, UIF.TEXT_COLOR)
	var race = d.get("race", "")
	var race_color = RACE_COLORS.get(race, DEFAULT_COLOR)
	y = _info_label("種族: %s" % race, y, 13, race_color)
	y += 10

	# 効果セクション（3分類）
	var skills = d.get("skills", [])
	var _edb = load("res://scripts/EffectDB.gd")

	# 攻撃時効果（前列で発動）
	var attack_skills: Array = []
	var support_skills: Array = []
	var passive_skills: Array = []
	for skill in skills:
		var trigger = skill.get("trigger", "")
		var target = skill.get("target", "self")
		match trigger:
			"on_hit", "on_kill":
				attack_skills.append(skill)
			"always":
				support_skills.append(skill)
			"timer":
				if target == "self":
					passive_skills.append(skill)
				else:
					support_skills.append(skill)
			_:
				passive_skills.append(skill)

	y = _info_section("── 攻撃時効果（前列で発動）──", y)
	if attack_skills.size() == 0:
		y = _info_label("なし", y, 11, UIF.DIM_COLOR)
	else:
		for skill in attack_skills:
			var edef = _edb.EFFECTS.get(skill.get("effect_id", ""), {})
			y = _info_label("[%s] %s" % [skill.get("trigger", ""), edef.get("display", skill.get("effect_id", ""))], y, 11, Color(0.9, 0.6, 0.5))

	y = _info_section("── サポート効果（中後列で発動）──", y)
	if support_skills.size() == 0:
		y = _info_label("なし", y, 11, UIF.DIM_COLOR)
	else:
		for skill in support_skills:
			var edef = _edb.EFFECTS.get(skill.get("effect_id", ""), {})
			y = _info_label("[%s] %s" % [skill.get("trigger", ""), edef.get("display", skill.get("effect_id", ""))], y, 11, Color(0.5, 0.8, 0.6))

	y = _info_section("── パッシブ効果（位置無関係）──", y)
	if passive_skills.size() == 0:
		y = _info_label("なし", y, 11, UIF.DIM_COLOR)
	else:
		for skill in passive_skills:
			var edef = _edb.EFFECTS.get(skill.get("effect_id", ""), {})
			y = _info_label("[%s] %s" % [skill.get("trigger", ""), edef.get("display", skill.get("effect_id", ""))], y, 11, Color(0.5, 0.6, 0.9))
	y += 8

	# 合成セクション
	y = _info_section("── 合成 ──", y)
	var has_synthesis = false
	for recipe in CardDB.SYNTHESIS:
		if recipe.get("base", "") == card_name or recipe.get("card", "") == card_name:
			y = _info_label("%s + %s → %s" % [recipe["base"], recipe["card"], recipe["result"]], y, 11, UIF.BENEFIT_COLOR)
			has_synthesis = true
	# 合成先（このカードが結果になるレシピ）
	for recipe in CardDB.SYNTHESIS:
		if recipe.get("result", "") == card_name:
			y = _info_label("← %s + %s" % [recipe["base"], recipe["card"]], y, 11, Color(0.7, 0.7, 0.5))
			has_synthesis = true
	if not has_synthesis:
		y = _info_label("なし", y, 12, UIF.DIM_COLOR)
	y += 10

	# フレーバーテキスト
	y = _info_section("── フレーバー ──", y)
	var flavor = _get_flavor_text(card_name)
	y = _info_label_wrap(flavor, y, 11, Color(0.6, 0.6, 0.5))

func _show_spell_info(card_name: String) -> void:
	var d = CardDB.SPELLS[card_name]
	var y = 15

	y = _info_label(card_name, y, 18, UIF.TITLE_COLOR)
	y = _info_label("[呪文]", y, 12, SPELL_COLOR)
	y += 5
	y = _info_label("コスト: %d" % d.get("cost", 0), y, 13, Color(0.5, 0.7, 0.9))
	y += 5

	y = _info_section("── 効果 ──", y)
	var effect_text = d.get("effect", "")
	if effect_text != "":
		y = _info_label_wrap(effect_text, y, 12, UIF.TEXT_COLOR)
	y += 5

	var skills = d.get("skills", [])
	var _edb = load("res://scripts/EffectDB.gd")
	for skill in skills:
		var eid = skill.get("effect_id", "")
		var edef = _edb.EFFECTS.get(eid, {})
		var target = skill.get("target", "")
		y = _info_label("%s → %s" % [edef.get("display", eid), target], y, 11, Color(0.6, 0.8, 0.7))

	# 効果範囲
	var entry = {"name": card_name}
	var scope = _PL.get_effect_scope(entry)
	var scope_names = {"cell": "単体", "row": "行全体", "col": "列全体", "all": "全体"}
	y += 5
	y = _info_label("効果範囲: %s" % scope_names.get(scope, "単体"), y, 12, Color(0.7, 0.6, 0.8))

func _show_spell_info_status(card_name: String) -> void:
	var d = CardDB.STATUS_SPELLS[card_name]
	var y = 15
	y = _info_label(card_name, y, 18, UIF.TITLE_COLOR)
	y = _info_label("[異常状態カード]", y, 12, UIF.DEMERIT_COLOR)
	y += 5
	y = _info_label("コスト: %d" % d.get("cost", 0), y, 13, Color(0.5, 0.7, 0.9))
	if d.get("is_consumable", false):
		y = _info_label("消費型（使用後デッキから消滅）", y, 11, UIF.DEMERIT_COLOR)

func _get_flavor_text(card_name: String) -> String:
	# 仮のフレーバーテキスト（将来CardDBに追加）
	var flavors = {
		"スライム": "最も弱く、最も可能性に満ちた存在",
		"ゴブリン": "素早さだけが取り柄の小さな戦士",
		"スケルトン": "死してなお戦場に立つ不屈の骨",
		"マッドスライム": "泥に混じった怒りが形になった",
		"ウルフ": "群れの先頭を走る誇り高き獣",
		"グール": "腐敗の中に宿る異常な生命力",
	}
	return flavors.get(card_name, "...")

# 解説レーンのヘルパー関数
func _info_label(text: String, y: float, size: int, color: Color) -> float:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = Vector2(15, y)
	lbl.size = Vector2(INFO_W - 30, 20)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	_info_container.add_child(lbl)
	return y + size + 6

func _info_label_wrap(text: String, y: float, size: int, color: Color) -> float:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = Vector2(15, y)
	lbl.size = Vector2(INFO_W - 30, 80)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	_info_container.add_child(lbl)
	return y + 50

func _info_section(text: String, y: float) -> float:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = Vector2(15, y)
	lbl.size = Vector2(INFO_W - 30, 18)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	_info_container.add_child(lbl)
	return y + 20

# ===== 配置タブ =====

func _build_placement_tab() -> void:
	var guide = Label.new()
	guide.text = "カードをドラッグして配置先を設定  │  自陣=召喚先  敵陣=呪文対象"
	guide.position = Vector2(BOARD_X, BOARD_Y - 3)
	guide.add_theme_font_size_override("font_size", 11)
	guide.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	_tab_container.add_child(guide)

	# 陣営ラベル
	var ally_lbl = Label.new()
	ally_lbl.text = "── 自陣 ──"
	ally_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ally_lbl.position = Vector2(BOARD_X + ROW_LABEL_W, BOARD_Y + 8)
	ally_lbl.size = Vector2(3 * (CELL_W + CELL_GAP), 18)
	ally_lbl.add_theme_font_size_override("font_size", 11)
	ally_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 0.5))
	_tab_container.add_child(ally_lbl)

	var enemy_x = BOARD_X + ROW_LABEL_W + 3 * (CELL_W + CELL_GAP) + CENTER_GAP
	var enemy_lbl = Label.new()
	enemy_lbl.text = "── 敵陣 ──"
	enemy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_lbl.position = Vector2(enemy_x, BOARD_Y + 8)
	enemy_lbl.size = Vector2(3 * (CELL_W + CELL_GAP), 18)
	enemy_lbl.add_theme_font_size_override("font_size", 11)
	enemy_lbl.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
	_tab_container.add_child(enemy_lbl)

	# 列ヘッダー
	var ally_cols = ["後列", "中列", "前列"]
	var enemy_cols = ["前列", "中列", "後列"]
	for ci in range(3):
		var al = Label.new()
		al.text = ally_cols[ci]
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.position = Vector2(BOARD_X + ROW_LABEL_W + ci * (CELL_W + CELL_GAP), BOARD_Y + 22)
		al.size = Vector2(CELL_W, 16)
		al.add_theme_font_size_override("font_size", 10)
		al.add_theme_color_override("font_color", Color(0.5, 0.65, 0.55))
		_tab_container.add_child(al)

		var el = Label.new()
		el.text = enemy_cols[ci]
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.position = Vector2(enemy_x + ci * (CELL_W + CELL_GAP), BOARD_Y + 22)
		el.size = Vector2(CELL_W, 16)
		el.add_theme_font_size_override("font_size", 10)
		el.add_theme_color_override("font_color", Color(0.65, 0.5, 0.5))
		_tab_container.add_child(el)

	# セル生成
	var row_names = ["上段", "中段", "下段"]
	_cell_rects = [
		[[null,null,null],[null,null,null],[null,null,null]],
		[[null,null,null],[null,null,null],[null,null,null]]
	]
	_cell_card_containers = [
		[[null,null,null],[null,null,null],[null,null,null]],
		[[null,null,null],[null,null,null],[null,null,null]]
	]

	for ri in range(3):
		var rl = Label.new()
		rl.text = row_names[ri]
		rl.position = Vector2(BOARD_X, BOARD_Y + 40 + ri * (CELL_H + CELL_GAP) + 40)
		rl.add_theme_font_size_override("font_size", 10)
		rl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_tab_container.add_child(rl)

		for si in range(2):
			for ci in range(3):
				var bx: float
				if si == 0:
					bx = BOARD_X + ROW_LABEL_W + ci * (CELL_W + CELL_GAP)
				else:
					bx = enemy_x + ci * (CELL_W + CELL_GAP)
				var by = BOARD_Y + 40 + ri * (CELL_H + CELL_GAP)

				var cell = ColorRect.new()
				cell.position = Vector2(bx, by)
				cell.size = Vector2(CELL_W, CELL_H)
				cell.color = Color(0.1, 0.12, 0.16) if si == 0 else Color(0.14, 0.1, 0.1)
				_tab_container.add_child(cell)

				var border = ReferenceRect.new()
				border.position = Vector2(bx, by)
				border.size = Vector2(CELL_W, CELL_H)
				border.border_color = Color(0.2, 0.3, 0.25) if si == 0 else Color(0.3, 0.2, 0.2)
				border.border_width = 1.0
				border.editor_only = false
				_tab_container.add_child(border)

				var vbox = VBoxContainer.new()
				vbox.position = Vector2(bx + 3, by + 3)
				vbox.size = Vector2(CELL_W - 6, CELL_H - 6)
				vbox.add_theme_constant_override("separation", 1)
				_tab_container.add_child(vbox)

				_cell_rects[si][ri][ci] = cell
				_cell_card_containers[si][ri][ci] = vbox

	_populate_cards()

	# グローバルトグル
	var toggle_y = BOARD_H
	var toggle = CheckBox.new()
	toggle.text = "指定セルが埋まっている場合、同じ列の他の空セルに召喚する"
	toggle.button_pressed = true
	toggle.position = Vector2(BOARD_X + ROW_LABEL_W, toggle_y)
	toggle.add_theme_font_size_override("font_size", 11)
	toggle.toggled.connect(func(on: bool): _set_global_fallback(on))
	_tab_container.add_child(toggle)

	# ステータスパネル（盤面下部）
	# ステータスパネルは_build_uiで常時表示済み

func _set_global_fallback(on: bool) -> void:
	for cfg in GameSession.placement_config:
		cfg["fallback_same_col"] = on

func _populate_cards() -> void:
	for si in range(2):
		for ri in range(3):
			for ci in range(3):
				var vbox = _cell_card_containers[si][ri][ci]
				if vbox != null:
					for child in vbox.get_children():
						child.queue_free()

	var cell_cards: Dictionary = {}
	for i in range(GameSession.selected_deck.size()):
		var entry = GameSession.selected_deck[i]
		var config = GameSession.placement_config[i] if i < GameSession.placement_config.size() else {}
		var side = config.get("side", 0)
		var row = config.get("row", -1)
		var col = config.get("col", -1)
		if row < 0: row = 0
		if col < 0: col = 2
		var key = "%d_%d_%d" % [side, row, col]
		if not cell_cards.has(key):
			cell_cards[key] = []
		var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)
		cell_cards[key].append({"idx": i, "name": card_name})

	for key in cell_cards:
		var parts = key.split("_")
		var si = int(parts[0])
		var ri = int(parts[1])
		var ci = int(parts[2])
		var vbox = _cell_card_containers[si][ri][ci]
		if vbox == null:
			continue

		var cards = cell_cards[key]
		var is_expanded = (_expanded_cell[0] == si and _expanded_cell[1] == ri and _expanded_cell[2] == ci)

		if is_expanded:
			for card in cards:
				vbox.add_child(_create_card_tag(card["idx"], card["name"], true))
		else:
			var groups: Dictionary = {}
			var order: Array = []
			for card in cards:
				if not groups.has(card["name"]):
					groups[card["name"]] = {"count": 0, "idx_first": card["idx"]}
					order.append(card["name"])
				groups[card["name"]]["count"] += 1
			for gname in order:
				var g = groups[gname]
				vbox.add_child(_create_grouped_tag(g["idx_first"], gname, g["count"]))

		var cell_rect = _cell_rects[si][ri][ci]
		if not cell_rect.has_meta("click_connected"):
			var s = si; var r = ri; var c = ci
			cell_rect.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_toggle_cell_expand(s, r, c)
			)
			cell_rect.set_meta("click_connected", true)

func _create_grouped_tag(idx: int, card_name: String, count: int) -> Control:
	var chip = PanelContainer.new()
	chip.custom_minimum_size = Vector2(CELL_W - 10, 15)
	var style = StyleBoxFlat.new()
	style.bg_color = _get_card_color(card_name)
	style.set_corner_radius_all(3)
	chip.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	var cost = _get_card_cost(card_name)
	lbl.text = "%s ×%d [%d]" % [card_name, count, cost] if count > 1 else "%s [%d]" % [card_name, cost]
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	chip.add_child(lbl)

	chip.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			chip.accept_event()
			_start_drag(idx, chip, event.global_position)
			_select_card(idx)
	)
	return chip

func _create_card_tag(idx: int, card_name: String, draggable: bool) -> Control:
	var chip = PanelContainer.new()
	chip.custom_minimum_size = Vector2(CELL_W - 10, 15)
	var style = StyleBoxFlat.new()
	style.bg_color = _get_card_color(card_name).lightened(0.1)
	style.set_corner_radius_all(3)
	style.set_border_width_all(1)
	style.border_color = Color(0.5, 0.5, 0.6)
	chip.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	lbl.text = "%s [%d]" % [card_name, _get_card_cost(card_name)]
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.9))
	chip.add_child(lbl)

	if draggable:
		chip.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				chip.accept_event()
				_start_drag(idx, chip, event.global_position)
				_select_card(idx)
		)
	return chip

func _get_card_color(card_name: String) -> Color:
	if CardDB.UNITS.has(card_name):
		return RACE_COLORS.get(CardDB.UNITS[card_name].get("race", ""), DEFAULT_COLOR)
	return SPELL_COLOR

func _get_card_cost(card_name: String) -> int:
	if CardDB.UNITS.has(card_name):
		return CardDB.UNITS[card_name].get("cost", 0)
	if CardDB.SPELLS.has(card_name):
		return CardDB.SPELLS[card_name].get("cost", 0)
	if CardDB.STATUS_SPELLS.has(card_name):
		return CardDB.STATUS_SPELLS[card_name].get("cost", 0)
	return 0

func _toggle_cell_expand(si: int, ri: int, ci: int) -> void:
	if _expanded_cell[0] == si and _expanded_cell[1] == ri and _expanded_cell[2] == ci:
		_expanded_cell = [-1, -1, -1]
	else:
		_expanded_cell = [si, ri, ci]
	_populate_cards()

# ---- ドラッグ&ドロップ ----

func _start_drag(idx: int, source_node: Control, mouse_pos: Vector2) -> void:
	_dragging = true
	_drag_source_idx = idx
	_drag_offset = source_node.global_position - mouse_pos

	var entry = GameSession.selected_deck[idx] if idx < GameSession.selected_deck.size() else {}
	var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)

	_drag_node = PanelContainer.new()
	_drag_node.size = Vector2(CELL_W - 10, 15)
	_drag_node.z_index = 100
	var style = StyleBoxFlat.new()
	style.bg_color = _get_card_color(card_name).lightened(0.2)
	style.set_corner_radius_all(3)
	_drag_node.add_theme_stylebox_override("panel", style)
	var lbl = Label.new()
	lbl.text = card_name
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_drag_node.add_child(lbl)
	add_child(_drag_node)
	_drag_node.global_position = mouse_pos + _drag_offset

func _end_drag() -> void:
	if _drag_node != null:
		_drag_node.queue_free()
		_drag_node = null
	_dragging = false
	_drag_source_idx = -1

func _process(_delta: float) -> void:
	if _dragging and _drag_node != null:
		_drag_node.global_position = get_viewport().get_mouse_position() + _drag_offset
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_drop_at_mouse()

func _try_drop_at_mouse() -> void:
	if not _dragging or _drag_source_idx < 0:
		_end_drag()
		return

	var mouse = get_viewport().get_mouse_position()
	var local = mouse - _tab_container.global_position
	var enemy_x = BOARD_X + ROW_LABEL_W + 3 * (CELL_W + CELL_GAP) + CENTER_GAP

	for si in range(2):
		for ri in range(3):
			for ci in range(3):
				var bx: float
				if si == 0:
					bx = BOARD_X + ROW_LABEL_W + ci * (CELL_W + CELL_GAP)
				else:
					bx = enemy_x + ci * (CELL_W + CELL_GAP)
				var by = BOARD_Y + 40 + ri * (CELL_H + CELL_GAP)

				if local.x >= bx and local.x < bx + CELL_W and local.y >= by and local.y < by + CELL_H:
					_try_drop_card(_drag_source_idx, si, ri, ci)
					return
	_end_drag()

func _try_drop_card(idx: int, new_side: int, new_row: int, new_col: int) -> void:
	var entry = GameSession.selected_deck[idx] if idx < GameSession.selected_deck.size() else {}
	if new_side == 0 and not _PL.can_place_ally(entry):
		_end_drag()
		return
	if new_side == 1 and not _PL.can_place_enemy(entry):
		_end_drag()
		return

	if idx < GameSession.placement_config.size():
		GameSession.placement_config[idx]["side"] = new_side
		GameSession.placement_config[idx]["row"] = new_row
		GameSession.placement_config[idx]["col"] = new_col

	_end_drag()
	_expanded_cell = [-1, -1, -1]
	_populate_cards()

func _select_card(idx: int) -> void:
	_selected_card_idx = idx
	_update_info_lane()
	_update_highlight()

func _update_highlight() -> void:
	# 全セルの色をリセット
	if _cell_rects.size() < 2:
		return
	for si in range(2):
		for ri in range(3):
			for ci in range(3):
				var cell = _cell_rects[si][ri][ci]
				if cell != null:
					cell.color = Color(0.1, 0.12, 0.16) if si == 0 else Color(0.14, 0.1, 0.1)

	if _selected_card_idx < 0 or _selected_card_idx >= GameSession.selected_deck.size():
		return

	var entry = GameSession.selected_deck[_selected_card_idx]
	var config = GameSession.placement_config[_selected_card_idx] if _selected_card_idx < GameSession.placement_config.size() else {}
	var p_side = config.get("side", 0)
	var p_row = config.get("row", 0)
	var p_col = config.get("col", 0)
	if p_row < 0: p_row = 0
	if p_col < 0: p_col = 2

	# 配置マスを白枠でハイライト
	var placed_cell = _cell_rects[p_side][p_row][p_col]
	if placed_cell != null:
		placed_cell.color = Color(0.2, 0.22, 0.28) if p_side == 0 else Color(0.22, 0.18, 0.18)

	# 効果範囲ハイライト
	var highlights = _PL.get_highlight_cells(entry, p_side, p_row, p_col)
	var highlight_colors = {
		"green": Color(0.15, 0.3, 0.15),  # 味方バフ
		"red": Color(0.3, 0.12, 0.12),    # 敵攻撃/デバフ
		"blue": Color(0.12, 0.18, 0.3),   # 自己
	}
	for h in highlights:
		var hs = h.get("side", 0)
		var hr = h.get("row", 0)
		var hc = h.get("col", 0)
		var hcolor = h.get("color", "green")
		if hs >= 0 and hs < 2 and hr >= 0 and hr < 3 and hc >= 0 and hc < 3:
			var cell = _cell_rects[hs][hr][hc]
			if cell != null:
				cell.color = highlight_colors.get(hcolor, highlight_colors["green"])

# ===== アイテムタブ =====

func _build_items_tab() -> void:
	var sections = ["消費アイテム", "装備", "素材", "合成"]
	for i in range(sections.size()):
		var sp = UIF.create_panel(Vector2(15 + i * 235, 15), Vector2(220, 400))
		_tab_container.add_child(sp)
		var hl = Label.new()
		hl.text = sections[i]
		hl.position = Vector2(25 + i * 235, 23)
		hl.add_theme_font_size_override("font_size", 13)
		hl.add_theme_color_override("font_color", UIF.TITLE_COLOR)
		_tab_container.add_child(hl)
		var cl = Label.new()
		cl.text = "（準備中）"
		cl.position = Vector2(25 + i * 235, 45)
		cl.add_theme_font_size_override("font_size", 11)
		cl.add_theme_color_override("font_color", UIF.DIM_COLOR)
		_tab_container.add_child(cl)

	var mat_y = 65
	for mat in GameSession.materials:
		var ml = Label.new()
		ml.text = "  %s" % mat.get("display", "???")
		ml.position = Vector2(25 + 2 * 235, mat_y)
		ml.add_theme_font_size_override("font_size", 11)
		ml.add_theme_color_override("font_color", UIF.BENEFIT_COLOR)
		_tab_container.add_child(ml)
		mat_y += 18

func _build_placeholder_tab(tab_id: String) -> void:
	var names = {"skill_tree": "スキル"}
	var lbl = Label.new()
	lbl.text = "%s（準備中）" % names.get(tab_id, tab_id)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 200)
	lbl.size = Vector2(980, 30)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", UIF.DIM_COLOR)
	_tab_container.add_child(lbl)
