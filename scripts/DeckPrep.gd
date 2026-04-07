# DeckPrep.gd
# デッキ準備画面: パターンB（左サイドバー型）
# 左サイドバー(w=200): ステータス上部 + 装備スロット下部
# 中央エリア(w=790): タブバー + タブコンテンツ + 冒険ボタン行
# 右解説レーン(w=275): カード/アイテム詳細
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
var _PL = null
var _board = null  # DeckPrepBoard インスタンス

var _tab_buttons: Array = []
var _tab_container: Control = null
var _info_container: Control = null  # 右側解説レーン
var _current_tab: String = "placement"

# 選択状態（_boardと同期）
var _selected_card_idx: int = -1

# 持ち物タブ選択状態
var _selected_material: Dictionary = {}
var _inventory_filter: String = "all"  # "all" / "normal" / "cursed" / "consumable"

# レイアウト定数（パターンB）
const SIDEBAR_X = 5         # 左サイドバー開始X
const SIDEBAR_Y = 5         # 左サイドバー開始Y
const SIDEBAR_W = 200       # 左サイドバー幅
const SIDEBAR_H = 710       # 左サイドバー高さ
const STATUS_AREA_Y = 15    # ステータス領域Y（サイドバー内）
const STATUS_AREA_H = 460   # ステータス領域高さ
const EQUIP_AREA_Y = 480    # 装備スロット領域Y（サイドバー内）
const EQUIP_AREA_H = 220    # 装備スロット領域高さ
const TAB_BAR_X = 210       # タブバー開始X
const TAB_BAR_Y = 5         # タブバー開始Y
const TAB_BAR_W = 790       # タブバー幅
const TAB_BAR_H = 30        # タブバー高さ
const CONTENT_X = 210       # タブコンテンツ開始X
const CONTENT_Y = 40        # タブコンテンツ開始Y
const CONTENT_W = 790       # タブコンテンツ幅
const CONTENT_H = 636       # タブコンテンツ高さ
const ADVENTURE_Y = 680     # 冒険ボタン行Y
const INFO_X = 1005         # 解説レーン開始X
const INFO_Y = 5            # 解説レーン開始Y
const INFO_W = 275          # 解説レーン幅
const INFO_H = 710          # 解説レーン高さ

# 装備スロット定義（絶対変更禁止: 頭/胴/足/アクセ×3の6個固定）
const EQUIP_SLOTS = [
	{"id": "head",       "label": "頭",    "row": 0, "col": 0},
	{"id": "body",       "label": "胴",    "row": 0, "col": 1},
	{"id": "feet",       "label": "足",    "row": 0, "col": 2},
	{"id": "accessory1", "label": "アクセ1", "row": 1, "col": 0},
	{"id": "accessory2", "label": "アクセ2", "row": 1, "col": 1},
	{"id": "accessory3", "label": "アクセ3", "row": 1, "col": 2},
]
const EQUIP_SLOT_SIZE = 55   # スロットサイズ
const EQUIP_SLOT_GAP = 8     # スロット間隔

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
	var BoardClass = load("res://scripts/DeckPrepBoard.gd")
	_board = BoardClass.new()
	_board.main_node = self
	_board._PL = _PL
	_board.on_card_selected = func(idx: int):
		_selected_card_idx = idx
		_update_info_lane()
		_board.update_highlight()
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	# 左サイドバー（ステータス上部 + 装備スロット下部）
	_build_sidebar()

	# タブバー（中央上部）
	_build_tab_bar()

	# タブコンテナ（中央メイン）
	_tab_container = Control.new()
	_tab_container.position = Vector2(CONTENT_X, CONTENT_Y)
	_tab_container.size = Vector2(CONTENT_W, CONTENT_H)
	add_child(_tab_container)

	# 右側解説レーン
	_build_info_lane()

	# 冒険ボタン行（下部）
	_build_adventure_buttons()

	_show_tab("placement")

# ===== 左サイドバー =====

func _build_sidebar() -> void:
	# サイドバー背景
	var sidebar_panel = UIF.create_panel(
		Vector2(SIDEBAR_X, SIDEBAR_Y),
		Vector2(SIDEBAR_W, SIDEBAR_H)
	)
	add_child(sidebar_panel)

	# ステータス領域（上部）
	_build_status_area()

	# 区切りライン
	var sep = ColorRect.new()
	sep.position = Vector2(SIDEBAR_X + 10, SIDEBAR_Y + EQUIP_AREA_Y - 10)
	sep.size = Vector2(SIDEBAR_W - 20, 1)
	sep.color = Color(0.3, 0.3, 0.4, 0.6)
	add_child(sep)

	# 装備スロット領域（下部）
	_build_equipment_area()

func _build_status_area() -> void:
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

	var base_x = SIDEBAR_X + 15
	var base_y = SIDEBAR_Y + STATUS_AREA_Y
	var cy: float = base_y
	var lbl_w = SIDEBAR_W - 30

	var header = Label.new()
	header.text = "ステータス"
	header.position = Vector2(base_x, cy)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(header)
	cy += 24

	var items = [
		["%s" % cls.get("display", "---"), UIF.TITLE_COLOR],
		["HP: 30", UIF.TEXT_COLOR],
		["マナ: %.0f / %d" % [cls.get("initial_mana", 3), int(cls.get("mana_max", 10))], Color(0.5, 0.7, 0.9)],
		["リジェネ: %.1f/s" % mana_regen, Color(0.5, 0.7, 0.9)],
		["─────────────", Color(0.3, 0.3, 0.4)],
		["デッキ: %d枚" % deck_size, UIF.TEXT_COLOR],
		["  ユニット: %d枚" % unit_count, Color(0.6, 0.7, 0.6)],
		["  呪文: %d枚" % spell_count, Color(0.6, 0.6, 0.8)],
		["平均コスト: %.1f" % avg_cost, UIF.TITLE_COLOR],
		["循環: 約%.0f秒/周" % cycle_time, UIF.TITLE_COLOR],
		["─────────────", Color(0.3, 0.3, 0.4)],
		["所持金: %dG" % GameSession.gold, UIF.GOLD_COLOR],
		["スキルPt: %d" % GameSession.skill_points, Color(0.5, 0.8, 0.9)],
		["素材: %d個" % GameSession.materials.size(), UIF.BENEFIT_COLOR],
	]
	for item in items:
		var lbl = Label.new()
		lbl.text = item[0]
		lbl.position = Vector2(base_x, cy)
		lbl.size = Vector2(lbl_w, 20)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", item[1])
		add_child(lbl)
		cy += 20

func _build_equipment_area() -> void:
	var base_x = SIDEBAR_X + 15
	var base_y = SIDEBAR_Y + EQUIP_AREA_Y

	var header = Label.new()
	header.text = "装備"
	header.position = Vector2(base_x, base_y)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(header)

	# 装備スロット2×3配置
	for slot in EQUIP_SLOTS:
		var sx = base_x + 3 + slot["col"] * (EQUIP_SLOT_SIZE + EQUIP_SLOT_GAP)
		var sy = base_y + 20 + slot["row"] * (EQUIP_SLOT_SIZE + EQUIP_SLOT_GAP + 14)
		_build_equipment_slot(slot["id"], slot["label"], sx, sy)

func _build_equipment_slot(slot_id: String, label: String, x: float, y: float) -> void:
	# スロット枠
	var cell = Panel.new()
	cell.position = Vector2(x, y)
	cell.size = Vector2(EQUIP_SLOT_SIZE, EQUIP_SLOT_SIZE)
	cell.name = "equip_slot_" + slot_id
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.18)
	style.border_color = Color(0.35, 0.28, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", style)
	add_child(cell)

	# スロットラベル（スロット内中央）
	var slot_lbl = Label.new()
	slot_lbl.text = label
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lbl.position = Vector2(x, y + EQUIP_SLOT_SIZE + 2)
	slot_lbl.size = Vector2(EQUIP_SLOT_SIZE, 12)
	slot_lbl.add_theme_font_size_override("font_size", 9)
	slot_lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6))
	add_child(slot_lbl)

func _build_tab_bar() -> void:
	var tabs = [
		{"id": "placement", "label": "配置"},
		{"id": "inventory", "label": "持ち物"},
		{"id": "skill_tree", "label": "スキル"},
	]
	var tab_w = int(TAB_BAR_W / tabs.size()) - 4
	var x = TAB_BAR_X + 2
	for tab in tabs:
		var btn = Button.new()
		btn.text = tab["label"]
		btn.position = Vector2(x, TAB_BAR_Y)
		btn.size = Vector2(tab_w, TAB_BAR_H)
		btn.add_theme_font_size_override("font_size", 13)
		var tab_id = tab["id"]
		btn.pressed.connect(func(): _show_tab(tab_id))
		add_child(btn)
		_tab_buttons.append({"id": tab_id, "button": btn})
		x += tab_w + 4

func _build_adventure_buttons() -> void:
	UIF.add_button(self, "← タイトルへ", Vector2(220, ADVENTURE_Y), Vector2(180, 32), 14,
		func():
			GameSession.reset()
			SceneManager.go_to(SceneManager.TITLE))
	UIF.add_button(self, "マップへ →", Vector2(820, ADVENTURE_Y), Vector2(180, 32), 14,
		func(): SceneManager.go_to(SceneManager.MAP_SELECT))

func _show_tab(tab_id: String) -> void:
	_current_tab = tab_id
	for tb in _tab_buttons:
		(tb["button"] as Button).modulate = Color(1, 1, 0.6) if tb["id"] == tab_id else Color(1, 1, 1)
	for child in _tab_container.get_children():
		child.queue_free()
	# タブ切替時に素材選択をリセット（持ち物タブ以外ではカード選択を保持）
	if tab_id != "inventory":
		_selected_material = {}

	match tab_id:
		"placement":
			_board.tab_container = _tab_container
			_board.build_placement_tab(_tab_container, _PL)
		"inventory": _build_inventory_tab()
		_: _build_placeholder_tab(tab_id)

	_update_info_lane()

func _process(delta: float) -> void:
	if _board != null:
		_board.process_drag(delta)

# ===== 右側解説レーン =====

func _build_info_lane() -> void:
	_info_container = Control.new()
	_info_container.position = Vector2(INFO_X, INFO_Y)
	_info_container.size = Vector2(INFO_W, INFO_H)
	add_child(_info_container)

	var bg = ColorRect.new()
	bg.size = Vector2(INFO_W, INFO_H)
	bg.color = Color(0.07, 0.07, 0.11)
	_info_container.add_child(bg)

	var border = ColorRect.new()
	border.position = Vector2(0, 0)
	border.size = Vector2(1, INFO_H)
	border.color = Color(0.2, 0.2, 0.3)
	_info_container.add_child(border)

func _update_info_lane() -> void:
	# 背景と枠線（先頭2個）以外を削除
	var children = _info_container.get_children()
	for i in range(children.size() - 1, 1, -1):
		children[i].queue_free()

	# 素材が選択されている場合は素材情報を優先表示
	if _selected_material.size() > 0:
		_show_material_info(_selected_material)
		return

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

# ===== 持ち物タブ（カテゴリフィルタ + 素材グリッド） =====
# 装備スロットは左サイドバーに常時表示。このタブにはカテゴリフィルタ + アイテム/素材グリッド

const INV_SLOT_W = 145    # スロット幅
const INV_SLOT_H = 90     # スロット高さ
const INV_SLOT_GAP = 10   # スロット間隔
const INV_GRID_COLS = 5   # グリッド列数
const INV_GRID_ROWS = 6   # グリッド行数
const INV_TOTAL_SLOTS = 30  # 総スロット数 (INV_GRID_COLS × INV_GRID_ROWS)
const INV_GRID_X = 8      # グリッド開始X
const INV_GRID_Y = 40     # グリッド開始Y
const INV_FILTER_H = 32   # フィルタタブ高さ

func _build_inventory_tab() -> void:
	# カテゴリフィルタタブ（上部）
	_build_category_filter(_tab_container)
	# 素材グリッド（下部）
	_build_inventory_grid(_tab_container)

func _build_category_filter(parent: Node) -> void:
	var categories = [
		{"id": "all",         "label": "全体"},
		{"id": "normal",      "label": "素材"},
		{"id": "cursed",      "label": "呪い"},
		{"id": "consumable",  "label": "消費"},
	]
	var x = 10
	for cat in categories:
		var btn = Button.new()
		btn.text = cat["label"]
		btn.position = Vector2(x, 3)
		btn.size = Vector2(90, 26)
		btn.add_theme_font_size_override("font_size", 12)
		if cat["id"] == _inventory_filter:
			btn.modulate = Color(1.0, 1.0, 0.5)
		var cat_id = cat["id"]
		btn.pressed.connect(func(): _set_inventory_filter(cat_id))
		parent.add_child(btn)
		x += 100

func _set_inventory_filter(filter: String) -> void:
	_inventory_filter = filter
	# タブコンテンツを再描画
	for child in _tab_container.get_children():
		child.queue_free()
	_build_inventory_tab()

func _get_filtered_materials() -> Array:
	var filtered: Array = []
	for mat in CardDB.MATERIALS:
		var is_cursed = mat.get("is_cursed", false)
		var is_consumable = mat.get("is_consumable", false)
		match _inventory_filter:
			"all":
				filtered.append(mat)
			"normal":
				if not is_cursed and not is_consumable:
					filtered.append(mat)
			"cursed":
				if is_cursed:
					filtered.append(mat)
			"consumable":
				if is_consumable:
					filtered.append(mat)
	return filtered

func _count_owned(mat_id: String) -> int:
	var count = 0
	for m in GameSession.materials:
		if m is Dictionary and m.get("id", "") == mat_id:
			count += 1
	return count

func _build_inventory_grid(parent: Node) -> void:
	var materials = _get_filtered_materials()

	for i in range(INV_TOTAL_SLOTS):
		var col = i % INV_GRID_COLS
		var row = i / INV_GRID_COLS
		var x = INV_GRID_X + col * (INV_SLOT_W + INV_SLOT_GAP)
		var y = INV_GRID_Y + row * (INV_SLOT_H + INV_SLOT_GAP)

		if i < materials.size():
			var mat = materials[i]
			var count = _count_owned(mat.get("id", ""))
			_build_material_slot(parent, mat, count, x, y)
		else:
			_build_empty_slot(parent, x, y)

func _build_material_slot(parent: Node, mat: Dictionary, count: int, x: int, y: int) -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(x, y)
	panel.custom_minimum_size = Vector2(INV_SLOT_W, INV_SLOT_H)

	var style = StyleBoxFlat.new()
	var is_cursed = mat.get("is_cursed", false)
	style.bg_color = Color(0.12, 0.12, 0.18) if count > 0 else Color(0.08, 0.08, 0.12)
	if count > 0:
		style.border_color = Color(0.8, 0.3, 0.5) if is_cursed else Color(0.3, 0.5, 0.7)
	else:
		style.border_color = Color(0.15, 0.15, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(4, 6)
	vbox.size = Vector2(INV_SLOT_W - 8, INV_SLOT_H - 12)
	panel.add_child(vbox)

	var name_label = Label.new()
	name_label.text = mat.get("display", "?")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9) if count > 0 else Color(0.4, 0.4, 0.5))
	vbox.add_child(name_label)

	var count_label = Label.new()
	count_label.text = "×%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5) if count > 0 else Color(0.3, 0.3, 0.4))
	vbox.add_child(count_label)

	# クリックで解説レーン更新
	var mat_ref = mat
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_material = mat_ref
			_selected_card_idx = -1
			_update_info_lane()
	)

func _build_empty_slot(parent: Node, x: int, y: int) -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(x, y)
	panel.custom_minimum_size = Vector2(INV_SLOT_W, INV_SLOT_H)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09)
	style.border_color = Color(0.12, 0.12, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

func _show_material_info(mat: Dictionary) -> void:
	var y: float = 20

	var name_lbl = Label.new()
	name_lbl.text = mat.get("display", "?")
	name_lbl.position = Vector2(10, y)
	name_lbl.size = Vector2(INFO_W - 20, 28)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	_info_container.add_child(name_lbl)
	y += 35

	if mat.get("is_cursed", false):
		var cursed_lbl = Label.new()
		cursed_lbl.text = "【呪われた素材】"
		cursed_lbl.position = Vector2(10, y)
		cursed_lbl.size = Vector2(INFO_W - 20, 20)
		cursed_lbl.add_theme_font_size_override("font_size", 12)
		cursed_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.4))
		_info_container.add_child(cursed_lbl)
		y += 22

	var count = _count_owned(mat.get("id", ""))
	var count_lbl = Label.new()
	count_lbl.text = "所持数: ×%d" % count
	count_lbl.position = Vector2(10, y)
	count_lbl.size = Vector2(INFO_W - 20, 20)
	count_lbl.add_theme_font_size_override("font_size", 13)
	count_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
	_info_container.add_child(count_lbl)
	y += 26

	var desc = mat.get("description", "")
	if desc != "":
		var desc_lbl = Label.new()
		desc_lbl.text = desc
		desc_lbl.position = Vector2(10, y)
		desc_lbl.size = Vector2(INFO_W - 20, 100)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", UIF.TEXT_COLOR)
		_info_container.add_child(desc_lbl)
		y += 55

	y += 10
	var sep_lbl = Label.new()
	sep_lbl.text = "── 合成先 ──"
	sep_lbl.position = Vector2(15, y)
	sep_lbl.size = Vector2(INFO_W - 30, 18)
	sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_lbl.add_theme_font_size_override("font_size", 11)
	sep_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	_info_container.add_child(sep_lbl)
	y += 22

	var hint_lbl = Label.new()
	hint_lbl.text = "（工房ノードで合成可能）"
	hint_lbl.position = Vector2(10, y)
	hint_lbl.size = Vector2(INFO_W - 20, 20)
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.add_theme_color_override("font_color", UIF.DIM_COLOR)
	_info_container.add_child(hint_lbl)

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
