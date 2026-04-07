# DeckPrep.gd
# デッキ準備画面: パターンB（左サイドバー型）
# 左サイドバー(w=200): ステータス（装備は持ち物タブに統合済み）
# 中央エリア(w=790): タブバー + タブコンテンツ + 冒険ボタン行
# 右解説レーン(w=275): カード/アイテム詳細
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
var _PL = null
var _board = null  # DeckPrepBoard インスタンス
var _info: Object = null  # DeckPrepInfo インスタンス

var _tab_buttons: Array = []
var _tab_container: Control = null
var _info_container: Control = null  # 右側解説レーン
var _current_tab: String = "placement"

# 選択状態（_boardと同期）
var _selected_card_idx: int = -1

# ピン留め状態（クリックで固定、再クリックで解除、別カードクリックで切り替え）
var _pinned_card_idx: int = -1

# 持ち物タブ選択状態
var _selected_material: Dictionary = {}
var _inventory_filter: String = "all"  # "all" / "normal" / "cursed" / "consumable"

# 装備スロット管理（持ち物タブ統合後）
var _equipped: Dictionary = {}  # slot_id -> item dict（空={}）

# レイアウト定数（パターンB）
const SIDEBAR_X = 5         # 左サイドバー開始X
const SIDEBAR_Y = 5         # 左サイドバー開始Y
const SIDEBAR_W = 200       # 左サイドバー幅
const SIDEBAR_H = 710       # 左サイドバー高さ
const STATUS_AREA_Y = 15    # ステータス領域Y（サイドバー内）
const STATUS_AREA_H = 680   # ステータス領域高さ（装備移動分拡大）
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
		# ピン留め中は他カードのホバーで上書きしない（on_card_selectedはホバー由来の場合も呼ばれるが
		# 現状はクリック由来のみ。on_card_pinnedと分けて管理）
		if _pinned_card_idx < 0:
			_update_info_lane()
		_board.update_highlight()
	_board.on_card_pinned = func(idx: int):
		# ピン留めトグル: 同じカードなら解除、別カードなら切り替え
		if _pinned_card_idx == idx:
			_pinned_card_idx = -1
		else:
			_pinned_card_idx = idx
		_selected_card_idx = _pinned_card_idx if _pinned_card_idx >= 0 else idx
		_update_info_lane()
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

	# ステータス領域（装備は持ち物タブに統合済み）
	_build_status_area()

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
	# タブ切替時に素材選択・ピン留めをリセット（持ち物タブ以外ではカード選択を保持）
	if tab_id != "inventory":
		_selected_material = {}
	_pinned_card_idx = -1

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

	# DeckPrepInfoにinfo_containerを渡してセットアップ
	_info.setup(self, _info_container, INFO_W, _PL)

func _update_info_lane() -> void:
	if _info == null:
		return
	# 素材が選択されている場合は素材情報を優先表示
	if _selected_material.size() > 0:
		_info.show_material_info(_selected_material)
		return
	if _selected_card_idx < 0 or _selected_card_idx >= GameSession.selected_deck.size():
		_info.show_empty()
		return
	_info.show_card_info(_selected_card_idx)

# ===== 持ち物タブ（装備統合 + カテゴリフィルタ + 素材グリッド + 検索） =====
# 装備6スロットを持ち物タブ最上部に統合。左サイドバーの装備セクションは削除済み
# レイアウト: フィルタバー(32) + 装備エリア(80) + 素材グリッド(残り)

const INV_SLOT_W = 120    # 素材スロット幅（旧145→縮小）
const INV_SLOT_H = 72     # 素材スロット高さ（旧90→縮小）
const INV_SLOT_GAP = 8    # スロット間隔（旧10→縮小）
const INV_GRID_COLS = 6   # グリッド列数（旧5→6）
const INV_GRID_ROWS = 7   # グリッド行数（装備2行+素材5行、CONTENT_H=636内に収まる）
const INV_EQUIP_ROWS = 2  # 装備行数（上位2行=装備エリア）
const INV_MAT_ROWS = 5    # 素材行数（残り5行=素材エリア）
const INV_TOTAL_SLOTS = 42  # 総スロット数 (INV_GRID_COLS × INV_GRID_ROWS)
const INV_EQUIP_SLOTS_COUNT = 6  # 装備スロット数（6個固定・変更禁止）
const INV_LOCKED_ROWS_START = 2  # ロック開始行（0-indexed、装備2行+素材2行=4行目以降をロック）
const INV_GRID_X = 8      # グリッド開始X
const INV_GRID_Y = 40     # グリッド開始Y（フィルタバー下）
const INV_FILTER_H = 32   # フィルタタブ高さ
const INV_SEARCH_W = 200  # 検索ボックス幅（フィルタバー右端）

func _build_inventory_tab() -> void:
	# カテゴリフィルタタブ + 検索ボックス（上部）
	_build_category_filter(_tab_container)
	# 統合グリッド（装備エリア + 素材エリア）
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

	# 検索ボックス（右端・将来実装のダミー）
	_build_search_box(parent)

func _set_inventory_filter(filter: String) -> void:
	_inventory_filter = filter
	# タブコンテンツを再描画
	for child in _tab_container.get_children():
		child.queue_free()
	_build_inventory_tab()

func _build_search_box(parent: Node) -> void:
	# フィルタバー右端に検索ボックスを配置（将来実装のスペース確保）
	var search_x = CONTENT_W - INV_SEARCH_W - 8
	# 虫眼鏡ラベル
	var icon_lbl = Label.new()
	icon_lbl.text = "[検索]"
	icon_lbl.position = Vector2(search_x, 3)
	icon_lbl.size = Vector2(48, 26)
	icon_lbl.add_theme_font_size_override("font_size", 11)
	icon_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	parent.add_child(icon_lbl)
	# LineEdit（将来実装・現状は入力不可）
	var search_edit = LineEdit.new()
	search_edit.name = "search_box"
	search_edit.placeholder_text = "検索（将来実装）"
	search_edit.position = Vector2(search_x + 50, 3)
	search_edit.size = Vector2(INV_SEARCH_W - 50, 26)
	search_edit.editable = false
	search_edit.add_theme_font_size_override("font_size", 11)
	parent.add_child(search_edit)

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
	# グリッド全体: 6列×8行=48スロット
	# 行0-1（12スロット）: 装備エリア（EQUIP_SLOTS 6個 + 空スロット6個）
	# 行2-3（12スロット）: 素材エリア（所持素材を左上から詰める）
	# 行4-7（24スロット）: ロックエリア（錠前表示・クリック不可）

	# ── 装備エリアセクションヘッダー ──
	var equip_header = Label.new()
	equip_header.text = "装備"
	equip_header.position = Vector2(INV_GRID_X, INV_GRID_Y - 2)
	equip_header.size = Vector2(100, 18)
	equip_header.add_theme_font_size_override("font_size", 11)
	equip_header.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	parent.add_child(equip_header)

	# 装備スロット（行0-1、スロット0-11のうち0-5に EQUIP_SLOTS を配置）
	for i in range(INV_GRID_COLS * INV_EQUIP_ROWS):
		var col = i % INV_GRID_COLS
		var row = i / INV_GRID_COLS
		var x = INV_GRID_X + col * (INV_SLOT_W + INV_SLOT_GAP)
		var y = INV_GRID_Y + row * (INV_SLOT_H + INV_SLOT_GAP)
		if i < EQUIP_SLOTS.size():
			var slot = EQUIP_SLOTS[i]
			_build_inventory_equipment_slot(parent, slot["id"], slot["label"], x, y)
		else:
			_build_empty_slot(parent, x, y)

	# ── 素材エリアセクションヘッダー ──
	var mat_section_y = INV_GRID_Y + INV_EQUIP_ROWS * (INV_SLOT_H + INV_SLOT_GAP)
	var mat_header = Label.new()
	mat_header.text = "素材"
	mat_header.position = Vector2(INV_GRID_X, mat_section_y - 2)
	mat_header.size = Vector2(100, 18)
	mat_header.add_theme_font_size_override("font_size", 11)
	mat_header.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6))
	parent.add_child(mat_header)

	# 所持素材を左上から詰める（モンハン式）
	var materials = _get_filtered_materials()
	var owned_mats: Array = []
	for mat in materials:
		var count = _count_owned(mat.get("id", ""))
		if count > 0:
			owned_mats.append({"mat": mat, "count": count})

	var mat_slot_total = INV_GRID_COLS * INV_MAT_ROWS  # 6×6=36スロット
	for i in range(mat_slot_total):
		var col = i % INV_GRID_COLS
		var row = INV_EQUIP_ROWS + (i / INV_GRID_COLS)
		var x = INV_GRID_X + col * (INV_SLOT_W + INV_SLOT_GAP)
		var y = INV_GRID_Y + row * (INV_SLOT_H + INV_SLOT_GAP)
		# 下半分（行4-7相当のうち、素材エリア内では行2-5=3行目以降）はロック
		var local_row = i / INV_GRID_COLS  # 素材エリア内の行（0-5）
		var is_locked = local_row >= (INV_MAT_ROWS / 2)  # 3行目以降（行3-5）をロック
		if is_locked:
			_build_locked_slot(parent, x, y)
		elif i < owned_mats.size():
			var entry = owned_mats[i]
			_build_material_slot_mh(parent, entry["mat"], entry["count"], x, y)
		else:
			_build_empty_slot(parent, x, y)

func _build_inventory_equipment_slot(parent: Node, slot_id: String, label: String, x: float, y: float) -> void:
	# 持ち物タブ内の装備スロット（アイコン将来差し込み対応）
	var cell = Panel.new()
	cell.position = Vector2(x, y)
	cell.size = Vector2(INV_SLOT_W, INV_SLOT_H)
	cell.name = "inv_equip_slot_" + slot_id
	var style = StyleBoxFlat.new()
	var item = _equipped.get(slot_id, {})
	var is_equipped = item.size() > 0
	style.bg_color = Color(0.15, 0.12, 0.22) if is_equipped else Color(0.10, 0.08, 0.16)
	style.border_color = Color(0.6, 0.45, 0.8) if is_equipped else Color(0.35, 0.28, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", style)
	parent.add_child(cell)

	# スロット種別ラベル（左上）
	var kind_lbl = Label.new()
	kind_lbl.text = label
	kind_lbl.position = Vector2(4, 3)
	kind_lbl.size = Vector2(INV_SLOT_W - 8, 16)
	kind_lbl.add_theme_font_size_override("font_size", 10)
	kind_lbl.add_theme_color_override("font_color", Color(0.55, 0.48, 0.65))
	kind_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(kind_lbl)

	# 装備名（中央）
	var name_lbl = Label.new()
	name_lbl.text = item.get("display", "---") if is_equipped else "（空）"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, INV_SLOT_H / 2 - 10)
	name_lbl.size = Vector2(INV_SLOT_W, 20)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5) if is_equipped else Color(0.35, 0.35, 0.45))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(name_lbl)

func _build_locked_slot(parent: Node, x: float, y: float) -> void:
	# ロックスロット（錠前表示・クリック不可）
	var panel = PanelContainer.new()
	panel.position = Vector2(x, y)
	panel.custom_minimum_size = Vector2(INV_SLOT_W, INV_SLOT_H)
	panel.name = "locked_slot"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08)
	style.border_color = Color(0.15, 0.15, 0.20)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)

	# 錠前マーク
	var lock_lbl = Label.new()
	lock_lbl.text = "LOCK"
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.position = Vector2(0, INV_SLOT_H / 2 - 10)
	lock_lbl.size = Vector2(INV_SLOT_W, 20)
	lock_lbl.add_theme_font_size_override("font_size", 11)
	lock_lbl.add_theme_color_override("font_color", Color(0.25, 0.25, 0.30))
	lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lock_lbl)

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
