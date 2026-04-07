# DeckPrep.gd
# デッキ準備画面: 完全統合版レイアウト
# 左パネル(w=200): ステータス上部 + 装備スロット下部
# 中央エリア(w=880): タブコンテンツ（配置のみ）+ 冒険ボタン行
# 右パネル(w=200): カード詳細専用（5:7比率TCGカード）
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null
var _PL = null
var _board = null  # DeckPrepBoard インスタンス
var _info: Object = null  # DeckPrepInfo インスタンス

var _tab_buttons: Array = []
var _tab_container: Control = null
var _info_container: Control = null  # 右パネル（カード詳細専用）
var _current_tab: String = "placement"

# 選択状態（_boardと同期）
var _selected_card_idx: int = -1

# 持ち物タブ選択状態
var _selected_material: Dictionary = {}
var _inventory_filter: String = "all"  # "all" / "normal" / "cursed" / "consumable"

# 配置タブ内のカード詳細コンテナ（盤面左下・廃止→右パネルへ移管）
var _board_detail_container: Control = null

# レイアウト定数（完全統合版）
const SIDEBAR_X = 5         # 左パネル開始X
const SIDEBAR_Y = 5         # 左パネル開始Y
const SIDEBAR_W = 200       # 左パネル幅
const SIDEBAR_H = 710       # 左パネル高さ
const STATUS_AREA_Y = 15    # ステータス領域Y（サイドバー内）
const STATUS_AREA_H = 460   # ステータス領域高さ
const EQUIP_AREA_Y = 460    # 装備スロット領域Y（サイドバー内）
const EQUIP_AREA_H = 220    # 装備スロット領域高さ
const TAB_BAR_X = 210       # タブバー開始X
const TAB_BAR_Y = 5         # タブバー開始Y
const TAB_BAR_W = 870       # タブバー幅（中央エリア）
const TAB_BAR_H = 30        # タブバー高さ
const CONTENT_X = 210       # タブコンテンツ開始X
const CONTENT_Y = 40        # タブコンテンツ開始Y
const CONTENT_W = 870       # タブコンテンツ幅
const CONTENT_H = 636       # タブコンテンツ高さ
const ADVENTURE_Y = 680     # 冒険ボタン行Y
# 右パネル（カード詳細専用）: 左パネルと同じ幅
const SIDE_PANEL_W = SIDEBAR_W  # 共通定数: 左右パネル幅
const INFO_X = 1080         # 右パネル開始X（5 + 200 + 870 + 5）
const INFO_Y = 5            # 右パネル開始Y
const INFO_W = SIDE_PANEL_W # 右パネル幅（=左パネル幅 200px）
const INFO_H = 710          # 右パネル高さ

# 装備スロット定義（絶対変更禁止: 頭/胴/足/アクセ×3の6個固定）
# 配置: 3行×2列（左列=頭/胴/足, 右列=アクセ1/2/3）
const EQUIP_SLOTS = [
	{"id": "head",       "label": "頭",    "row": 0, "col": 0},
	{"id": "body",       "label": "胴",    "row": 1, "col": 0},
	{"id": "feet",       "label": "足",    "row": 2, "col": 0},
	{"id": "accessory1", "label": "アクセ1", "row": 0, "col": 1},
	{"id": "accessory2", "label": "アクセ2", "row": 1, "col": 1},
	{"id": "accessory3", "label": "アクセ3", "row": 2, "col": 1},
]
const EQUIP_SLOT_SIZE = 55   # スロットサイズ（持ち物グリッドのセルサイズと同一）
const EQUIP_SLOT_GAP = 8     # スロット間隔（持ち物グリッドのギャップと同一）

# 持ち物グリッド定数（装備スロットと同一サイズ・間隔を使用）
# セルサイズ = EQUIP_SLOT_SIZE, セル間隔 = EQUIP_SLOT_GAP
const INV_CELL_SIZE = EQUIP_SLOT_SIZE   # 正方形セルサイズ（装備スロットと統一）
const INV_CELL_GAP  = EQUIP_SLOT_GAP   # セル間隔（装備スロットと統一）
const INV_GRID_OFFSET_X = 8            # グリッド開始X（タブコンテナ内）
const INV_GRID_OFFSET_Y = 40           # グリッド開始Y（フィルタタブ下）
# 列数: コンテンツ幅(870) - 右パネル干渉なし - OFFSET_X - 余白 から計算
# 870 - 8 - 8 = 854 / (55 + 8) = 13.5 → 13列
# ただし右パネル（INFO_X=1080）まで中央エリア幅870内なので問題なし
const INV_GRID_COLS = 12               # グリッド列数（870px内に収まる最大列数）
# 行数: コンテンツ高さ(636) - OFFSET_Y - フィルタ(32) = 564 / (55+8) = 8.9 → 8行
const INV_GRID_ROWS = 8                # グリッド行数
const INV_TOTAL_SLOTS = INV_GRID_COLS * INV_GRID_ROWS  # 総スロット数

# ソートタブ定義（持ち物タブ内サブタブ）
const INV_SORT_TABS = [
	{"id": "all",       "label": "全体"},
	{"id": "equipment", "label": "装備"},
	{"id": "normal",    "label": "素材"},
	{"id": "cursed",    "label": "呪い"},
	{"id": "consumable","label": "消費"},
]

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
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	_info = InfoClass.new()
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	# 共通タスクバー（最上部36px）
	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.DECK_PREP)

	# 左パネル（ステータス上部 + 装備スロット下部）
	_build_sidebar()

	# タブコンテナ（中央メイン: タブバーなし・配置のみ）
	_tab_container = Control.new()
	_tab_container.position = Vector2(CONTENT_X, CONTENT_Y)
	_tab_container.size = Vector2(CONTENT_W, CONTENT_H)
	add_child(_tab_container)

	# 右パネル（カード詳細専用）
	_build_info_lane()

	# 冒険ボタン行（下部）
	_build_adventure_buttons()

	# 配置タブを直接表示（タブバー廃止）
	_board.tab_container = _tab_container
	_board.build_placement_tab(_tab_container, _PL)
	_update_info_lane()

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

	# 項目8: グループ間を区切り線+12px余白で分割
	# グループ1: クラス基本情報
	var group1 = [
		["%s" % cls.get("display", "---"), UIF.TITLE_COLOR],
		["HP: 30", UIF.TEXT_COLOR],
		["マナ: %.0f / %d" % [cls.get("initial_mana", 3), int(cls.get("mana_max", 10))], Color(0.5, 0.7, 0.9)],
		["リジェネ: %.1f/s" % mana_regen, Color(0.5, 0.7, 0.9)],
	]
	# グループ2: デッキ情報
	var group2 = [
		["デッキ: %d枚" % deck_size, UIF.TEXT_COLOR],
		["  ユニット: %d枚" % unit_count, Color(0.6, 0.7, 0.6)],
		["  呪文: %d枚" % spell_count, Color(0.6, 0.6, 0.8)],
		["平均コスト: %.1f" % avg_cost, UIF.TITLE_COLOR],
		["循環: 約%.0f秒/周" % cycle_time, UIF.TITLE_COLOR],
	]
	# グループ3: 所持情報
	var group3 = [
		["所持金: %dG" % GameSession.gold, UIF.GOLD_COLOR],
		["スキルPt: %d" % GameSession.skill_points, Color(0.5, 0.8, 0.9)],
		["素材: %d個" % GameSession.materials.size(), UIF.BENEFIT_COLOR],
	]

	for group in [group1, group2, group3]:
		for item in group:
			var lbl = Label.new()
			lbl.text = item[0]
			lbl.position = Vector2(base_x, cy)
			lbl.size = Vector2(lbl_w, 18)
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", item[1])
			add_child(lbl)
			cy += 18
		# グループ間: 区切り線 + 12px余白
		if group != group3:
			cy += 4
			var sep = ColorRect.new()
			sep.position = Vector2(base_x - 5, cy)
			sep.size = Vector2(lbl_w + 10, 1)
			sep.color = Color(0.25, 0.28, 0.35, 0.8)
			add_child(sep)
			cy += 12

func _build_equipment_area() -> void:
	var base_x = SIDEBAR_X + 15
	var base_y = SIDEBAR_Y + EQUIP_AREA_Y

	var header = Label.new()
	header.text = "装備"
	header.position = Vector2(base_x, base_y)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(header)

	# 装備スロット3×2配置（左列=頭/胴/足, 右列=アクセ1/2/3）
	for slot in EQUIP_SLOTS:
		var sx = base_x + 3 + slot["col"] * (EQUIP_SLOT_SIZE + EQUIP_SLOT_GAP + 10)
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

	# スロットラベル（スロット内下部に収める・パネル外に飛び出さない）
	var slot_lbl = Label.new()
	slot_lbl.text = label
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lbl.position = Vector2(0, EQUIP_SLOT_SIZE - 14)
	slot_lbl.size = Vector2(EQUIP_SLOT_SIZE, 12)
	slot_lbl.add_theme_font_size_override("font_size", 9)
	slot_lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6))
	cell.add_child(slot_lbl)

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
	# タブバー廃止: 配置のみ。互換維持のため関数は残す
	_current_tab = "placement"
	_board_detail_container = null
	_selected_material = {}
	for child in _tab_container.get_children():
		child.queue_free()
	_board.tab_container = _tab_container
	_board.build_placement_tab(_tab_container, _PL)
	_update_info_lane()

func _process(delta: float) -> void:
	if _board != null:
		_board.process_drag(delta)

# ===== 右パネル（カード詳細専用） =====

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

	# DeckPrepInfoにinfo_containerを渡してセットアップ（カード詳細専用モード）
	_info.setup(self, _info_container, INFO_W, _PL)
	_info.show_empty()

func _update_info_lane() -> void:
	if _info == null:
		return
	# 右パネルはカード詳細専用
	# 持ち物タブ以外では素材選択リセット
	if _current_tab != "inventory":
		_selected_material = {}
	# 素材選択優先（持ち物タブ）
	if _selected_material.size() > 0:
		_info.show_material_info(_selected_material)
		return
	if _selected_card_idx < 0 or _selected_card_idx >= GameSession.selected_deck.size():
		_info.show_empty()
		return
	_info.show_card_info(_selected_card_idx)

# ===== 配置タブ内カード詳細（廃止: 右パネルへ移管） =====

func _update_board_detail() -> void:
	# 右パネルで統一したので不使用（互換のため残す）
	pass

# ===== 持ち物タブ（ソートタブ + 正方形グリッド） =====
# 装備スロットは左サイドバーに常時表示。このタブには装備含むソートタブ + 正方形グリッド
# セルサイズ・間隔は装備スロットと統一（EQUIP_SLOT_SIZE / EQUIP_SLOT_GAP）

const INV_FILTER_H = 32   # フィルタタブ高さ（後方互換維持）
# 後方互換用エイリアス（テスト等が参照する可能性があるため残す）
const INV_SLOT_W = INV_CELL_SIZE   # スロット幅（=EQUIP_SLOT_SIZE）
const INV_SLOT_H = INV_CELL_SIZE   # スロット高さ（正方形・=EQUIP_SLOT_SIZE）
const INV_SLOT_GAP = INV_CELL_GAP  # スロット間隔（=EQUIP_SLOT_GAP）
const INV_GRID_X = INV_GRID_OFFSET_X
const INV_GRID_Y = INV_GRID_OFFSET_Y

func _build_inventory_tab() -> void:
	# ソートタブ（上部）
	_build_inventory_sort_tabs(_tab_container)
	# 正方形グリッド（下部）
	_build_inventory_square_grid(_tab_container)

func _build_inventory_sort_tabs(parent: Node) -> void:
	var x = 10
	for tab in INV_SORT_TABS:
		var btn = Button.new()
		btn.text = tab["label"]
		btn.position = Vector2(x, 3)
		btn.size = Vector2(80, 26)
		btn.add_theme_font_size_override("font_size", 12)
		if tab["id"] == _inventory_filter:
			btn.modulate = Color(1.0, 1.0, 0.5)
		var tab_id = tab["id"]
		btn.pressed.connect(func(): _set_inventory_filter(tab_id))
		parent.add_child(btn)
		x += 88

func _set_inventory_filter(filter: String) -> void:
	_inventory_filter = filter
	for child in _tab_container.get_children():
		child.queue_free()
	_build_inventory_tab()

func _get_filtered_items() -> Array:
	# 装備・素材・消費・呪いをフィルタして返す（装備タブ追加対応）
	var result: Array = []
	# 装備（GameSession.equipmentから取得予定。現在は空）
	if _inventory_filter == "all" or _inventory_filter == "equipment":
		pass  # 将来: GameSession.equipment から生成
	# 素材（装備タブ専用の場合は素材を含めない）
	if _inventory_filter != "equipment":
		for mat in CardDB.MATERIALS:
			var is_cursed = mat.get("is_cursed", false)
			var is_consumable = mat.get("is_consumable", false)
			var count = _count_owned(mat.get("id", ""))
			if count <= 0:
				continue
			match _inventory_filter:
				"all":
					result.append({"type": "material", "data": mat, "count": count})
				"normal":
					if not is_cursed and not is_consumable:
						result.append({"type": "material", "data": mat, "count": count})
				"cursed":
					if is_cursed:
						result.append({"type": "material", "data": mat, "count": count})
				"consumable":
					if is_consumable:
						result.append({"type": "material", "data": mat, "count": count})
	return result

# 後方互換: 旧_get_filtered_materialsと同等動作
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

func _build_inventory_square_grid(parent: Node) -> void:
	# 正方形グリッド: セルサイズ=EQUIP_SLOT_SIZE, 間隔=EQUIP_SLOT_GAP
	var items = _get_filtered_items()
	var cell = INV_CELL_SIZE
	var gap = INV_CELL_GAP
	var ox = INV_GRID_OFFSET_X
	var oy = INV_GRID_OFFSET_Y

	for i in range(INV_TOTAL_SLOTS):
		var col_i = i % INV_GRID_COLS
		var row_i = i / INV_GRID_COLS
		var x = ox + col_i * (cell + gap)
		var y = oy + row_i * (cell + gap)
		if i < items.size():
			var item = items[i]
			_build_inv_square_cell(parent, item, x, y, cell)
		else:
			_build_inv_empty_cell(parent, x, y, cell)

func _build_inv_square_cell(parent: Node, item: Dictionary, x: int, y: int, size: int) -> void:
	var panel = Panel.new()
	panel.position = Vector2(x, y)
	panel.size = Vector2(size, size)
	var style = StyleBoxFlat.new()
	var item_type = item.get("type", "material")
	var is_cursed = item["data"].get("is_cursed", false) if item_type == "material" else false
	style.bg_color = Color(0.12, 0.12, 0.18)
	if item_type == "equipment":
		style.border_color = Color(0.6, 0.5, 0.2)  # 装備: 金色
	elif is_cursed:
		style.border_color = Color(0.8, 0.3, 0.5)  # 呪い: 紫
	else:
		style.border_color = Color(0.3, 0.5, 0.7)  # 通常: 青
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	# アイコン枠（仮: 色付き矩形、テクスチャ実装後は置き換え）
	var icon_bg = ColorRect.new()
	icon_bg.position = Vector2(3, 3)
	icon_bg.size = Vector2(size - 6, size - 18)
	icon_bg.color = style.border_color * Color(1, 1, 1, 0.25)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_bg)

	# スタック数（右下）
	var count = item.get("count", 1)
	if count >= 2:
		var stack_lbl = Label.new()
		stack_lbl.text = "×%d" % count
		stack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack_lbl.position = Vector2(2, size - 16)
		stack_lbl.size = Vector2(size - 4, 14)
		stack_lbl.add_theme_font_size_override("font_size", 9)
		stack_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		stack_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(stack_lbl)

	# クリックで解説レーン更新
	var mat_ref = item["data"]
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_material = mat_ref
			_selected_card_idx = -1
			_update_info_lane()
	)

func _build_inv_empty_cell(parent: Node, x: int, y: int, size: int) -> void:
	var panel = Panel.new()
	panel.position = Vector2(x, y)
	panel.size = Vector2(size, size)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09)
	style.border_color = Color(0.12, 0.12, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

# 後方互換: _build_material_slot_mh（旧テスト・外部参照用）
func _build_material_slot_mh(parent: Node, mat: Dictionary, count: int, x: int, y: int) -> void:
	_build_inv_square_cell(parent, {"type": "material", "data": mat, "count": count}, x, y, INV_CELL_SIZE)

func _build_empty_slot(parent: Node, x: int, y: int) -> void:
	_build_inv_empty_cell(parent, x, y, INV_CELL_SIZE)

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
