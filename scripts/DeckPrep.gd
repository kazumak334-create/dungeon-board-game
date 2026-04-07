# DeckPrep.gd
# デッキ準備画面: パターンB（左サイドバー型）
# 左サイドバー(w=200): ステータス上部 + 装備スロット下部
# 中央エリア(w=790): タブバー + タブコンテンツ + 冒険ボタン行
# 右解説レーン(w=275): 合成可能エリア（上半分） ← カード詳細は配置タブ盤面左下に移動
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
var _PL = null
var _board = null  # DeckPrepBoard インスタンス
var _info: Object = null  # DeckPrepInfo インスタンス

var _tab_buttons: Array = []
var _tab_container: Control = null
var _info_container: Control = null  # 右側合成レーン
var _current_tab: String = "placement"

# 選択状態（_boardと同期）
var _selected_card_idx: int = -1

# 持ち物タブ選択状態
var _selected_material: Dictionary = {}
var _inventory_filter: String = "all"  # "all" / "normal" / "cursed" / "consumable"

# 配置タブ内のカード詳細コンテナ（盤面左下）
var _board_detail_container: Control = null

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
# 配置: 3行×2列（左列=頭/胴/足, 右列=アクセ1/2/3）
const EQUIP_SLOTS = [
	{"id": "head",       "label": "頭",    "row": 0, "col": 0},
	{"id": "body",       "label": "胴",    "row": 1, "col": 0},
	{"id": "feet",       "label": "足",    "row": 2, "col": 0},
	{"id": "accessory1", "label": "アクセ1", "row": 0, "col": 1},
	{"id": "accessory2", "label": "アクセ2", "row": 1, "col": 1},
	{"id": "accessory3", "label": "アクセ3", "row": 2, "col": 1},
]
const EQUIP_SLOT_SIZE = 55   # スロットサイズ
const EQUIP_SLOT_GAP = 8     # スロット間隔

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

	# 左サイドバー（ステータス上部 + 装備スロット下部）
	_build_sidebar()

	# タブバー（中央上部）
	_build_tab_bar()

	# タブコンテナ（中央メイン）
	_tab_container = Control.new()
	_tab_container.position = Vector2(CONTENT_X, CONTENT_Y)
	_tab_container.size = Vector2(CONTENT_W, CONTENT_H)
	add_child(_tab_container)

	# 右側合成レーン（合成可能エリア専用）
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
	_board_detail_container = null
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
			# 盤面左下にカード詳細コンテナを作成
			_board_detail_container = _board.build_card_detail_container(_tab_container)
		"inventory": _build_inventory_tab()
		_: _build_placeholder_tab(tab_id)

	_update_info_lane()

func _process(delta: float) -> void:
	if _board != null:
		_board.process_drag(delta)

# ===== 右側合成レーン（合成専用） =====

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

	# DeckPrepInfoにinfo_containerを渡してセットアップ（合成専用モード）
	_info.setup(self, _info_container, INFO_W, _PL)
	_info.build_synthesis_right_panel()

func _update_info_lane() -> void:
	if _info == null:
		return
	# 右側レーンは合成専用: 常に合成パネルを表示
	# 素材選択・カード選択は盤面左下のカード詳細に表示
	_update_board_detail()

# ===== 配置タブ内カード詳細（盤面左下）の更新 =====

func _update_board_detail() -> void:
	if _info == null or _board_detail_container == null:
		return
	# 持ち物タブ以外では素材選択リセット
	if _current_tab != "inventory":
		_selected_material = {}
	# 素材選択優先（持ち物タブ）
	if _selected_material.size() > 0:
		_info.show_material_in_container(_board_detail_container, _selected_material)
		return
	if _selected_card_idx < 0 or _selected_card_idx >= GameSession.selected_deck.size():
		_info.show_empty_in_container(_board_detail_container)
		return
	_info.show_card_info_in_container(_board_detail_container, _selected_card_idx)

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
	# 項目10: モンハン式 — 所持素材を左上から順に詰める（所持数>0のみ表示）
	var materials = _get_filtered_materials()
	var owned_mats: Array = []
	for mat in materials:
		var count = _count_owned(mat.get("id", ""))
		if count > 0:
			owned_mats.append({"mat": mat, "count": count})

	for i in range(INV_TOTAL_SLOTS):
		var col = i % INV_GRID_COLS
		var row = i / INV_GRID_COLS
		var x = INV_GRID_X + col * (INV_SLOT_W + INV_SLOT_GAP)
		var y = INV_GRID_Y + row * (INV_SLOT_H + INV_SLOT_GAP)

		if i < owned_mats.size():
			var entry = owned_mats[i]
			_build_material_slot_mh(parent, entry["mat"], entry["count"], x, y)
		else:
			_build_empty_slot(parent, x, y)

# 項目10: モンハン式スロット（アイコン+スタック数のみ、名前非表示）
func _build_material_slot_mh(parent: Node, mat: Dictionary, count: int, x: int, y: int) -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(x, y)
	panel.custom_minimum_size = Vector2(INV_SLOT_W, INV_SLOT_H)
	var style = StyleBoxFlat.new()
	var is_cursed = mat.get("is_cursed", false)
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.border_color = Color(0.8, 0.3, 0.5) if is_cursed else Color(0.3, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	# アイコン枠（仮: 色付き矩形）
	var icon_bg = ColorRect.new()
	icon_bg.position = Vector2(6, 6)
	icon_bg.size = Vector2(INV_SLOT_W - 12, INV_SLOT_H - 22)
	icon_bg.color = Color(0.8, 0.3, 0.5, 0.3) if is_cursed else Color(0.3, 0.5, 0.7, 0.3)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_bg)

	# スタック数（右下）
	var stack_lbl = Label.new()
	stack_lbl.text = "×%d" % count
	stack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack_lbl.position = Vector2(4, INV_SLOT_H - 20)
	stack_lbl.size = Vector2(INV_SLOT_W - 14, 16)
	stack_lbl.add_theme_font_size_override("font_size", 12)
	stack_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	stack_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack_lbl)

	# クリックで解説レーン更新（素材名は解説レーンで表示）
	var mat_ref = mat
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_material = mat_ref
			_selected_card_idx = -1
			_update_info_lane()
	)

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
