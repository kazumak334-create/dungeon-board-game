# DeckPrep.gd
# デッキ準備画面: タブ構成（配置/アイテム/スキル）+ 上部ステータスバー + 右側解説レーン
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

# レイアウト定数（全座標はここから自動計算）
const TAB_BAR_H = 30       # タブバー高さ
const TAB_BAR_Y = 4        # タブバーY位置
const CONTENT_Y = TAB_BAR_Y + TAB_BAR_H + 4  # タブコンテンツ開始Y
const INFO_W = 280          # 解説レーン幅
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
		{"id": "inventory", "label": "持ち物"},
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
	# _selected_card_idx は保持（タブ切替で解説レーンを消さない）

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

# ===== 持ち物タブ（マス目インベントリ） =====

const INV_COLS = 6       # グリッド列数
const INV_CELL = 80      # セルサイズ
const INV_GAP = 4        # セル間隔
const INV_X = 20         # 開始X
const INV_Y = 10         # 開始Y
const EQUIP_ROWS = 2     # 装備スロット行数
const INV_ROWS = 6       # 全行数（装備2+アイテム4）

func _build_inventory_tab() -> void:
	# 装備スロットラベル
	var equip_names = [
		["武器", "頭", "体", "脚", "飾1", "飾2"],
		["", "", "", "", "", ""],  # 2行目は値表示用
	]

	# グリッド描画
	for r in range(INV_ROWS):
		for c in range(INV_COLS):
			var cx = INV_X + c * (INV_CELL + INV_GAP)
			var cy = INV_Y + r * (INV_CELL + INV_GAP)

			var is_equip = r < EQUIP_ROWS
			var cell = Panel.new()
			cell.position = Vector2(cx, cy)
			cell.size = Vector2(INV_CELL, INV_CELL)
			var style = StyleBoxFlat.new()
			if is_equip:
				style.bg_color = Color(0.15, 0.13, 0.2)
				style.border_color = Color(0.4, 0.3, 0.5)
			else:
				style.bg_color = Color(0.1, 0.12, 0.16)
				style.border_color = Color(0.25, 0.25, 0.35)
			style.set_border_width_all(1)
			style.set_corner_radius_all(4)
			cell.add_theme_stylebox_override("panel", style)
			_tab_container.add_child(cell)

			# 装備スロットラベル（1行目のみ）
			if r == 0 and c < equip_names[0].size():
				var sl = Label.new()
				sl.text = equip_names[0][c]
				sl.position = Vector2(cx + 4, cy + 2)
				sl.add_theme_font_size_override("font_size", 9)
				sl.add_theme_color_override("font_color", Color(0.5, 0.4, 0.6))
				_tab_container.add_child(sl)

	# 装備スロット区切りライン
	var sep_y = INV_Y + EQUIP_ROWS * (INV_CELL + INV_GAP) - 2
	var sep = ColorRect.new()
	sep.position = Vector2(INV_X, sep_y)
	sep.size = Vector2(INV_COLS * (INV_CELL + INV_GAP) - INV_GAP, 1)
	sep.color = Color(0.4, 0.3, 0.5, 0.5)
	_tab_container.add_child(sep)

	# アイテム配置（装備行の下）
	var item_cells: Array = []  # [{row, col, type, data}]

	# 消費アイテム（左上優先）
	# 仮: GameSessionに消費アイテムリストがないので、materialsから消費可能なものを抽出
	var consumables: Array = []
	var materials_grouped: Dictionary = {}  # id -> {data, count}

	for mat in GameSession.materials:
		var mid = mat.get("id", "")
		# is_cursed等で消費可能か判定（仮: 全素材を素材扱い）
		if not materials_grouped.has(mid):
			materials_grouped[mid] = {"data": mat, "count": 0}
		materials_grouped[mid]["count"] += 1

	# マス目にアイテムを配置
	var item_row = EQUIP_ROWS
	var item_col = 0

	# 消費アイテムを先に配置（将来: GameSession.consumablesから）
	# 現状は消費アイテムなし

	# 素材をスタック表示で配置
	for mid in materials_grouped:
		var g = materials_grouped[mid]
		var mat = g["data"]
		var count = g["count"]

		if item_row >= INV_ROWS:
			break

		var cx = INV_X + item_col * (INV_CELL + INV_GAP)
		var cy = INV_Y + item_row * (INV_CELL + INV_GAP)

		# アイテム名
		var name_lbl = Label.new()
		name_lbl.text = mat.get("display", "???")
		name_lbl.position = Vector2(cx + 4, cy + 15)
		name_lbl.size = Vector2(INV_CELL - 8, 20)
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", UIF.TEXT_COLOR)
		_tab_container.add_child(name_lbl)

		# スタック数
		if count > 1:
			var count_lbl = Label.new()
			count_lbl.text = "×%d" % count
			count_lbl.position = Vector2(cx + INV_CELL - 28, cy + INV_CELL - 18)
			count_lbl.add_theme_font_size_override("font_size", 11)
			count_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
			_tab_container.add_child(count_lbl)

		# クリックで解説レーン更新
		var click_area = Button.new()
		click_area.position = Vector2(cx, cy)
		click_area.size = Vector2(INV_CELL, INV_CELL)
		click_area.flat = true
		click_area.modulate = Color(1, 1, 1, 0)  # 透明
		var mat_data = mat
		click_area.pressed.connect(func():
			_selected_card_idx = -1
			_show_material_info(mat_data, materials_grouped.get(mat_data.get("id", ""), {}).get("count", 0))
		)
		_tab_container.add_child(click_area)

		item_col += 1
		if item_col >= INV_COLS:
			item_col = 0
			item_row += 1

	# 空グリッドの場合のエンプティステート
	if materials_grouped.size() == 0:
		var empty = Label.new()
		empty.text = "アイテムなし"
		empty.position = Vector2(INV_X + 10, INV_Y + EQUIP_ROWS * (INV_CELL + INV_GAP) + 30)
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", UIF.DIM_COLOR)
		_tab_container.add_child(empty)

func _show_material_info(mat: Dictionary, count: int) -> void:
	# 解説レーンを素材情報で更新
	var children = _info_container.get_children()
	for i in range(children.size() - 1, 1, -1):
		children[i].queue_free()

	var y: float = 15
	y = _info_label(mat.get("display", "???"), y, 18, UIF.TITLE_COLOR)
	y = _info_label("素材  ×%d" % count, y, 13, Color(0.6, 0.7, 0.5))
	y += 5

	var desc = mat.get("description", "")
	if desc != "":
		y = _info_label_wrap(desc, y, 12, UIF.TEXT_COLOR)
	y += 10

	# 合成先一覧（将来: craftingテーブルから逆引き）
	y = _info_section("── 合成先 ──", y)
	y = _info_label("（工房ノードで合成可能）", y, 11, UIF.DIM_COLOR)

	# 呪い表示
	if mat.get("is_cursed", false):
		y += 10
		y = _info_label("呪いの素材", y, 12, UIF.DEMERIT_COLOR)

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
