# DeckPrep.gd
# デッキ準備画面: カード配置専用画面
# 左パネル(w=200): ステータス表示のみ
# 中央エリア(w=880): 配置タブ（盤面・手持ちカード・呪文デッキ）+ 冒険ボタン
# 右パネル(w=200): カード詳細専用（5:7比率TCGカード）
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")
const UIColors = preload("res://scripts/ui/UIColors.gd")
const SidebarClass = preload("res://scripts/DeckPrepSidebar.gd")
const RightPanelClass = preload("res://scripts/DeckPrepRightPanel.gd")

# 色彩設計（UIColors.gd参照）

var _taskbar: RefCounted = null
var _PL = null
var _board = null  # DeckPrepBoard インスタンス
var _info: Object = null  # DeckPrepInfo インスタンス
var _sidebar = null  # DeckPrepSidebar インスタンス
var _right_panel = null  # DeckPrepRightPanel インスタンス

var _tab_container: Control = null
var _info_container: Control = null  # 右パネル（カード詳細専用）

# 選択状態（_boardと同期）
var _selected_card_idx: int = -1

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

	# サブコンポーネント初期化
	_sidebar = SidebarClass.new()
	_sidebar.setup(self)
	_right_panel = RightPanelClass.new()
	_right_panel.setup(self)

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
	_sidebar.build_sidebar()

	# コンテンツコンテナ（中央メイン）
	_tab_container = Control.new()
	_tab_container.position = Vector2(CONTENT_X, CONTENT_Y)
	_tab_container.size = Vector2(CONTENT_W, CONTENT_H)
	add_child(_tab_container)

	# 右パネル（カード詳細専用）
	_info_container = _right_panel.build_info_lane()

	# 冒険ボタン行（下部）
	_build_adventure_buttons()

	# 配置タブを表示
	_board.tab_container = _tab_container
	_board.build_placement_tab(_tab_container, _PL)

	# DeckPrepInfoにinfo_containerを渡してセットアップ
	_info.setup(self, _info_container, INFO_W, _PL)
	_info.show_empty()

	# 盤面マナ初期値を計算
	_update_board_mana()

# ===== サイドバー・右パネルは別ファイルに分離済み =====

func _process(delta: float) -> void:
	if _board != null:
		_board.process_drag(delta)

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
	var board_mana: int = 0
	var mana_generation_rate: float = 0.0
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
			var unit_data = CardDB.UNITS[card_name]
			var mana = unit_data.get("mana", 0)
			var spd = unit_data.get("spd", 1)
			board_mana += mana
			if spd > 0:
				mana_generation_rate += float(mana) / float(spd)
	_sidebar.update_board_mana(board_mana, mana_generation_rate)
	_sidebar.update_balance_panel(GameSession.placement_config, GameSession.selected_deck)

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
