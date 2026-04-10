# DeckPrep.gd
# デッキ準備画面: カード配置専用画面
# 左パネル(w=200): ステータス表示のみ
# 中央エリア(w=880): 配置タブ（盤面・手持ちカード・呪文デッキ）+ 冒険ボタン
# 右パネル(w=200): カード詳細専用（5:7比率TCGカード）
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

# 色彩設計（企画書3節準拠・MaterialSelect.gd踏襲）
const COLOR_BG          := Color(0.08, 0.08, 0.12)  # 背景
const COLOR_SIDE_PANEL  := Color(0.07, 0.07, 0.11)  # 左右パネル背景（中央より暗く）
const COLOR_PANEL       := Color(0.13, 0.13, 0.2)   # 中央パネル背景
const COLOR_BORDER      := Color(0.3, 0.3, 0.4)     # 枠線（通常）
const COLOR_TITLE       := Color(0.9, 0.85, 0.6)    # タイトル文字
const COLOR_TEXT        := Color(0.8, 0.8, 0.8)     # 通常テキスト
const COLOR_SELECTED    := Color(0.9, 0.75, 0.3)    # 選択中ハイライト
const COLOR_DIM         := Color(0.5, 0.5, 0.5)     # タブ非選択

var _taskbar: RefCounted = null
var _PL = null
var _board = null  # DeckPrepBoard インスタンス
var _info: Object = null  # DeckPrepInfo インスタンス

var _tab_container: Control = null
var _info_container: Control = null  # 右パネル（カード詳細専用）

# 選択状態（_boardと同期）
var _selected_card_idx: int = -1

# 盤面マナ表示用ラベル
var _board_mana_label: Label = null

# レイアウト定数
const SIDEBAR_X = 5         # 左パネル開始X
const SIDEBAR_Y = 40        # 左パネル開始Y（タスクバー36px分オフセット）
const SIDEBAR_W = 200       # 左パネル幅
const SIDEBAR_H = 675       # 左パネル高さ
const STATUS_AREA_Y = 15    # ステータス領域Y（サイドバー内）
const CONTENT_X = 210       # コンテンツ開始X
const CONTENT_Y = 40        # コンテンツ開始Y
const CONTENT_W = 860       # コンテンツ幅（210+860+5=1075=INFO_X）
const CONTENT_H = 636       # コンテンツ高さ
const ADVENTURE_Y = 680     # 冒険ボタン行Y
# 右パネル（カード詳細専用）: 左パネルと同じ幅
const SIDE_PANEL_W = SIDEBAR_W  # 共通定数: 左右パネル幅
const INFO_X = 1075         # 右パネル開始X（左右余白5pxで線対称）
const INFO_Y = 40           # 右パネル開始Y（タスクバー36px分オフセット）
const INFO_W = SIDE_PANEL_W # 右パネル幅（=左パネル幅 200px）
const INFO_H = 675          # 右パネル高さ

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
	_board.on_cards_populated = func():
		_update_board_mana()  # タスク#4: 盤面マナ更新
	var InfoClass = load("res://scripts/DeckPrepInfo.gd")
	_info = InfoClass.new()
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	# 共通タスクバー（最上部36px）
	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.DECK_PREP)

	# 左パネル（ステータス表示のみ）
	_build_sidebar()

	# コンテンツコンテナ（中央メイン）
	_tab_container = Control.new()
	_tab_container.position = Vector2(CONTENT_X, CONTENT_Y)
	_tab_container.size = Vector2(CONTENT_W, CONTENT_H)
	add_child(_tab_container)

	# 右パネル（カード詳細専用）
	_build_info_lane()

	# 冒険ボタン行（下部）
	_build_adventure_buttons()

	# 配置タブを表示
	_board.tab_container = _tab_container
	_board.build_placement_tab(_tab_container, _PL)

# ===== 左サイドバー =====

func _build_sidebar() -> void:
	# サイドバー背景（企画書3節: COLOR_SIDE_PANEL使用）
	var sidebar_panel = UIF.create_panel(
		Vector2(SIDEBAR_X, SIDEBAR_Y),
		Vector2(SIDEBAR_W, SIDEBAR_H),
		COLOR_SIDE_PANEL,  # 左右パネルは中央より暗く
		COLOR_BORDER,
		1,
		4
	)
	add_child(sidebar_panel)

	# ステータス領域
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
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", COLOR_TITLE)
	add_child(header)
	cy += 24

	# 項目8: グループ間を区切り線+12px余白で分割
	# グループ1: クラス基本情報
	var group1 = [
		["%s" % cls.get("display", "---"), COLOR_TITLE],
		["HP: 30", COLOR_TEXT],
		["マナ: %.0f / %d" % [cls.get("initial_mana", 3), int(cls.get("mana_max", 10))], Color(0.5, 0.7, 0.9)],
		["リジェネ: %.1f/s" % mana_regen, Color(0.5, 0.7, 0.9)],
		["盤面マナ: 0", COLOR_SELECTED],  # タスク#4: 盤面総マナ表示
	]
	# グループ2: デッキ情報
	var group2 = [
		["デッキ: %d枚" % deck_size, COLOR_TEXT],
		["  ユニット: %d枚" % unit_count, Color(0.6, 0.7, 0.6)],
		["  呪文: %d枚" % spell_count, Color(0.6, 0.6, 0.8)],
		["平均コスト: %.1f" % avg_cost, COLOR_TITLE],
		["循環: 約%.0f秒/周" % cycle_time, COLOR_TITLE],
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
			# タスク#4: 盤面マナラベルを保持
			if group == group1 and item == group1[-1]:
				_board_mana_label = lbl
			cy += 18
		# グループ間: 区切り線 + 12px余白
		if group != group3:
			cy += 4
			var sep = ColorRect.new()
			sep.position = Vector2(base_x - 5, cy)
			sep.size = Vector2(lbl_w + 10, 1)
			sep.color = Color(0.25, 0.28, 0.35)
			add_child(sep)
			cy += 12

	# タスク#4: 盤面マナ初期値を計算
	_update_board_mana()

func _process(delta: float) -> void:
	if _board != null:
		_board.process_drag(delta)

# ===== 右パネル（カード詳細専用） =====

func _build_info_lane() -> void:
	# 右パネル（企画書4.5節: カード詳細専用、背景=COLOR_SIDE_PANEL、枠線=COLOR_BORDER）
	var info_panel = UIF.create_panel(
		Vector2(INFO_X, INFO_Y),
		Vector2(INFO_W, INFO_H),
		COLOR_SIDE_PANEL,  # 左右パネルは中央より暗く
		COLOR_BORDER,
		1,
		4
	)
	add_child(info_panel)

	_info_container = Control.new()
	_info_container.position = Vector2(INFO_X, INFO_Y)
	_info_container.size = Vector2(INFO_W, INFO_H)
	add_child(_info_container)

	# DeckPrepInfoにinfo_containerを渡してセットアップ（カード詳細専用モード）
	_info.setup(self, _info_container, INFO_W, _PL)
	_info.show_empty()

func _update_info_lane() -> void:
	if _info == null:
		return
	# 右パネルはカード詳細専用
	if _selected_card_idx < 0 or _selected_card_idx >= GameSession.selected_deck.size():
		_info.show_empty()
		return
	_info.show_card_info(_selected_card_idx)

# タスク#4: 盤面マナ更新
func _update_board_mana() -> void:
	if _board_mana_label == null:
		return
	var board_mana: int = 0
	for i in range(GameSession.selected_deck.size()):
		if i >= GameSession.placement_config.size():
			continue
		var config = GameSession.placement_config[i]
		var col = config.get("col", -1)
		if col < 0:  # col=-1は呪文デッキ・手持ちカード（盤面外）
			continue
		var entry = GameSession.selected_deck[i]
		var card_name = entry.get("name", "") if entry is Dictionary else str(entry)
		if CardDB.UNITS.has(card_name):
			board_mana += CardDB.UNITS[card_name].get("cost", 0)
	_board_mana_label.text = "盤面マナ: %d" % board_mana

func _build_adventure_buttons() -> void:
	# 冒険ボタン「冒険を始める」860×35、フォントサイズ18、青系背景
	var start_btn = Button.new()
	start_btn.text = "冒険を始める"
	start_btn.position = Vector2(CONTENT_X, ADVENTURE_Y)
	start_btn.size = Vector2(CONTENT_W, 35)
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.pressed.connect(_on_start_battle)
	add_child(start_btn)

	# 背景色=青系（Color(0.3, 0.5, 0.7)）、ホバー時Color(0.4, 0.6, 0.8)
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.3, 0.5, 0.7)
	normal_style.set_corner_radius_all(4)
	start_btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.4, 0.6, 0.8)
	hover_style.set_corner_radius_all(4)
	start_btn.add_theme_stylebox_override("hover", hover_style)

func _on_start_battle() -> void:
	# v2設計: 初期配置9マス情報をGameSession.initial_unitsに保存
	_save_initial_units()
	SceneManager.go_to(SceneManager.BATTLE)

func _save_initial_units() -> void:
	# 配置タブの9マス状態をGameSession.initial_unitsに保存
	GameSession.initial_units.clear()
	if _board == null:
		return

	# _board._cell_card_containersから各セルの配置情報を取得（自陣side=0のみ）
	for row in range(3):
		for col in range(3):
			var container = _board._cell_card_containers[0][row][col]
			var unit_info = null

			# コンテナ内のカードを確認
			if container.get_child_count() > 0:
				var card_ui = container.get_child(0)
				if card_ui.has_meta("card_name"):
					var card_name = card_ui.get_meta("card_name")
					unit_info = {"name": card_name, "row": row, "col": col}

			GameSession.initial_units.append(unit_info)

	print("[DeckPrep] 初期配置保存: %d個のユニット" % GameSession.initial_units.filter(func(x): return x != null).size())

# 後方互換用定数（装備欄廃止後もテスト等が参照する可能性があるため残す）
const INV_CELL_SIZE = 55         # セルサイズ（元EQUIP_SLOT_SIZE）
const INV_CELL_GAP = 8           # セル間隔（元EQUIP_SLOT_GAP）
const INV_GRID_OFFSET_X = 8      # グリッド開始X
const INV_GRID_OFFSET_Y = 40     # グリッド開始Y
const INV_FILTER_H = 32          # フィルタタブ高さ
const INV_SLOT_W = INV_CELL_SIZE # スロット幅
const INV_SLOT_H = INV_CELL_SIZE # スロット高さ（正方形）
const INV_SLOT_GAP = INV_CELL_GAP # スロット間隔
const INV_GRID_X = INV_GRID_OFFSET_X
const INV_GRID_Y = INV_GRID_OFFSET_Y
