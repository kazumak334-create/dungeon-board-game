# DeckPrepSidebar.gd
# DeckPrep左パネル（ステータス表示）専用
extends RefCounted

const UIF = preload("res://scripts/UIFactory.gd")
const UIColors = preload("res://scripts/ui/UIColors.gd")

var _main_node: Control = null
var _board_mana_label: Label = null
var _mana_generation_label: Label = null

# バランスパネル用変数
var _balance_bars: Dictionary = {}  # {"thrust": ColorRect, "guard": ColorRect, "break": ColorRect}
var _balance_labels: Dictionary = {} # {"thrust": Label, "guard": Label, "break": Label}

# レイアウト定数
const SIDEBAR_X = 5
const SIDEBAR_Y = 40
const SIDEBAR_W = 200
const SIDEBAR_H = 675
const STATUS_AREA_Y = 15

# バランスパネル定数
const BALANCE_PANEL_Y = 370
const BAR_MAX_W = 130
const BAR_H = 12
const BALANCE_COLORS = {
	"thrust": Color(0.9, 0.3, 0.3),  # 赤
	"guard":  Color(0.3, 0.5, 0.9),  # 青
	"break":  Color(0.7, 0.3, 0.8),  # 紫
}
const BALANCE_NAMES = {
	"thrust": "突",
	"guard":  "守",
	"break":  "崩",
}

func setup(main_node: Control) -> void:
	_main_node = main_node

func build_sidebar() -> void:
	# サイドバー背景
	var sidebar_panel = UIF.create_panel(
		Vector2(SIDEBAR_X, SIDEBAR_Y),
		Vector2(SIDEBAR_W, SIDEBAR_H),
		UIColors.COLOR_SIDE_PANEL,
		UIColors.COLOR_BORDER,
		1,
		4
	)
	_main_node.add_child(sidebar_panel)

	# ステータス領域
	_build_status_area()

	# バランスパネル
	_build_balance_panel()

func _build_status_area() -> void:
	var cls = CardDB.CLASSES.get(GameSession.class_id, {})

	var total_cost: float = 0.0
	var unit_count: int = 0
	var spell_count: int = 0
	for entry in GameSession.selected_deck:
		var n = entry.get("name", "") if entry is Dictionary else str(entry)
		if CardDB.UNITS.has(n):
			total_cost += CardDB.UNITS[n].get("mana", 0)
			unit_count += 1
		elif CardDB.SPELLS.has(n):
			total_cost += CardDB.SPELLS[n].get("mana", 0)
			spell_count += 1
		elif CardDB.STATUS_SPELLS.has(n):
			total_cost += CardDB.STATUS_SPELLS[n].get("mana", 0)
			spell_count += 1
	var deck_size = GameSession.selected_deck.size()
	var avg_cost = total_cost / max(1, deck_size)

	var base_x = SIDEBAR_X + 15
	var base_y = SIDEBAR_Y + STATUS_AREA_Y
	var cy: float = base_y
	var lbl_w = SIDEBAR_W - 30

	var header = Label.new()
	header.text = "ステータス"
	header.position = Vector2(base_x, cy)
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", UIColors.COLOR_TITLE)
	_main_node.add_child(header)
	cy += 24

	# 盤面ユニットの総mana & マナ生成力計算
	var board_unit_mana = 0
	var mana_generation_rate = 0.0
	for i in range(GameSession.selected_deck.size()):
		var cfg = GameSession.placement_config[i] if i < GameSession.placement_config.size() else {}
		var col = cfg.get("col", -1)
		if col >= 0:  # 盤面配置
			var entry = GameSession.selected_deck[i]
			var card_name = entry.get("name", "") if entry is Dictionary else str(entry)
			if CardDB.UNITS.has(card_name):
				var unit_data = CardDB.UNITS[card_name]
				var mana = unit_data.get("mana", 0)
				var spd = unit_data.get("spd", 1)
				board_unit_mana += mana
				if spd > 0:
					mana_generation_rate += float(mana) / float(spd)

	# グループ1: クラス基本情報
	var group1 = [
		["%s" % cls.get("display", "---"), UIColors.COLOR_TITLE],
		["HP: 30", UIColors.COLOR_TEXT],
		["最大マナ: %d" % board_unit_mana, Color(0.5, 0.7, 0.9)],
		["マナ生成力: %.1f/秒" % mana_generation_rate, Color(0.6, 0.8, 0.5)],
	]
	# グループ2: デッキ情報
	var group2 = [
		["デッキ: %d枚" % deck_size, UIColors.COLOR_TEXT],
		["  ユニット: %d枚" % unit_count, Color(0.6, 0.7, 0.6)],
		["  呪文: %d枚" % spell_count, Color(0.6, 0.6, 0.8)],
		["平均コスト: %.1f" % avg_cost, UIColors.COLOR_TITLE],
	]
	# グループ3: 所持情報
	var group3 = [
		["所持金: %dG" % GameSession.gold, UIF.GOLD_COLOR],
		["スキルPt: %d" % GameSession.skill_points, Color(0.5, 0.8, 0.9)],
		["レリック: %d個" % GameSession.relics.size(), Color(0.7, 0.5, 0.8)],
	]

	for group in [group1, group2, group3]:
		for item in group:
			var lbl = Label.new()
			lbl.text = item[0]
			lbl.position = Vector2(base_x, cy)
			lbl.size = Vector2(lbl_w, 18)
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", item[1])
			_main_node.add_child(lbl)
			# 最大マナラベルとマナ生成力ラベルを保持
			if group == group1:
				if item == group1[-2]:  # "最大マナ: 0"
					_board_mana_label = lbl
				elif item == group1[-1]:  # "マナ生成力: X/秒"
					_mana_generation_label = lbl
			cy += 18
		# グループ間: 区切り線 + 12px余白
		if group != group3:
			cy += 4
			var sep = ColorRect.new()
			sep.position = Vector2(base_x - 5, cy)
			sep.size = Vector2(lbl_w + 10, 1)
			sep.color = Color(0.25, 0.28, 0.35)
			_main_node.add_child(sep)
			cy += 12

func update_board_mana(board_mana: int, mana_generation_rate: float = 0.0) -> void:
	if _board_mana_label != null:
		_board_mana_label.text = "最大マナ: %d" % board_mana
	if _mana_generation_label != null:
		_mana_generation_label.text = "マナ生成力: %.1f/秒" % mana_generation_rate

func _build_balance_panel() -> void:
	var base_x = SIDEBAR_X + 15
	var base_y = BALANCE_PANEL_Y
	var cy: float = base_y
	var lbl_w = SIDEBAR_W - 30

	# ヘッダー "バランス"
	var header = Label.new()
	header.text = "バランス"
	header.position = Vector2(base_x, cy)
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", UIColors.COLOR_TITLE)
	_main_node.add_child(header)
	cy += 24

	# 3本のバー
	for category in ["thrust", "guard", "break"]:
		var color = BALANCE_COLORS[category]
		var name_text = BALANCE_NAMES[category]

		# 名前ラベル
		var name_lbl = Label.new()
		name_lbl.text = name_text
		name_lbl.position = Vector2(base_x, cy)
		name_lbl.size = Vector2(20, BAR_H)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT)
		_main_node.add_child(name_lbl)

		# バー背景（灰色）
		var bar_bg = ColorRect.new()
		bar_bg.position = Vector2(base_x + 22, cy)
		bar_bg.size = Vector2(BAR_MAX_W, BAR_H)
		bar_bg.color = Color(0.2, 0.2, 0.25)
		_main_node.add_child(bar_bg)

		# バー（カラー）
		var bar = ColorRect.new()
		bar.position = Vector2(base_x + 22, cy)
		bar.size = Vector2(0, BAR_H)  # 初期幅0
		bar.color = color
		_main_node.add_child(bar)
		_balance_bars[category] = bar

		# 枚数ラベル
		var count_lbl = Label.new()
		count_lbl.text = "0枚"
		count_lbl.position = Vector2(base_x + 22 + BAR_MAX_W + 5, cy)
		count_lbl.size = Vector2(30, BAR_H)
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT)
		_main_node.add_child(count_lbl)
		_balance_labels[category] = count_lbl

		cy += 24


func update_balance_panel(placement_config: Array, selected_deck: Array) -> void:
	var counts = {"thrust": 0, "guard": 0, "break": 0}

	# 盤面ユニットをカウント
	for i in range(selected_deck.size()):
		if i >= placement_config.size():
			continue
		var config = placement_config[i]
		var col = config.get("col", -1)
		if col < 0:  # 盤面外
			continue
		var entry = selected_deck[i]
		var card_name = entry.get("name", "") if entry is Dictionary else str(entry)
		if CardDB.UNITS.has(card_name):
			var unit_data = CardDB.UNITS[card_name]
			var category = _classify_unit(unit_data, col)
			counts[category] += 1

	# バー幅と枚数を更新
	var total = counts["thrust"] + counts["guard"] + counts["break"]
	for category in ["thrust", "guard", "break"]:
		var count = counts[category]
		var bar = _balance_bars.get(category)
		var lbl = _balance_labels.get(category)
		if bar != null:
			var width = 0
			if total > 0:
				width = int(float(count) / float(total) * BAR_MAX_W)
			bar.size = Vector2(width, BAR_H)
		if lbl != null:
			lbl.text = "%d枚" % count

func _classify_unit(unit_data: Dictionary, col: int) -> String:
	var traits = unit_data.get("traits", [])

	# 優先1: traits による分類
	if "pierce" in traits or "flying" in traits or "mana_drain" in traits:
		return "break"
	if "swarm" in traits:
		return "thrust"
	if "indomitable" in traits:
		return "guard"

	# 優先2: category フィールド（あれば）
	if unit_data.has("category"):
		return unit_data.get("category")

	# 優先3: ステータス比率
	var hp = unit_data.get("hp", 1)
	var atk = unit_data.get("atk", 0)
	var ratio = float(atk) / float(max(1, hp))

	if ratio >= 0.15:
		return "thrust"
	elif hp >= 40:
		return "guard"
	else:
		return "break"
