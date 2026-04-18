extends Node

# RestScreen全体の制御・UI構築・状態管理

# 座標定義（要件定義書 5.1準拠）
const LAYOUT = {
	"header": {"x": 0, "y": 0, "w": 1280, "h": 36},
	"player_board": {"x": 20, "y": 52, "w": 390, "h": 315},
	"shop_board": {"x": 430, "y": 52, "w": 390, "h": 315},
	"center_gap": {"x": 410, "y": 52, "w": 20, "h": 315},
	"right_panel": {"x": 840, "y": 52, "w": 200, "h": 508},
	"hand_area": {"x": 20, "y": 390, "w": 800, "h": 150},
	"footer": {"x": 20, "y": 560, "w": 800, "h": 20}
}

const CELL = {"w": 130, "h": 95}

# RestScreen状態
enum RestMode {
	NONE,
	CARD_SELECTED,
	SHOP_HOVER
}

# 主要フィールド
var board_manager: Node
var game_session: Node
var ui_root: Control
var right_panel: Panel
var hand_area: HBoxContainer

var rest_state: Dictionary = {
	"mode": RestMode.NONE,
	"selected_card": null,
	"selected_index": -1,
	"shop_items": [],
	"gold": 0
}

# 初期化
func initialize(session: Node, board: Node) -> void:
	game_session = session
	board_manager = board

	if game_session:
		rest_state.gold = game_session.gold

	build_ui()

# UI構築
func build_ui() -> void:
	# 1. ルートContainer作成
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui_root)

	# 2. ヘッダーバー（CommonTaskbar使用）
	var header = preload("res://scripts/CommonTaskbar.gd").new()
	header.set_position(Vector2(LAYOUT.header.x, LAYOUT.header.y))
	header.set_size(Vector2(LAYOUT.header.w, LAYOUT.header.h))
	ui_root.add_child(header)

	# 3. 自陣盤面（既存BoardManager利用）
	if board_manager:
		board_manager.set_position(Vector2(LAYOUT.player_board.x, LAYOUT.player_board.y))
		ui_root.add_child(board_manager)

	# 4. 右パネル
	right_panel = Panel.new()
	right_panel.set_position(Vector2(LAYOUT.right_panel.x, LAYOUT.right_panel.y))
	right_panel.set_size(Vector2(LAYOUT.right_panel.w, LAYOUT.right_panel.h))
	ui_root.add_child(right_panel)

	var panel_label = Label.new()
	panel_label.text = "カードを選択してください"
	panel_label.set_position(Vector2(10, 10))
	right_panel.add_child(panel_label)

	# 5. 手持ちカードエリア
	hand_area = HBoxContainer.new()
	hand_area.set_position(Vector2(LAYOUT.hand_area.x, LAYOUT.hand_area.y))
	hand_area.set_size(Vector2(LAYOUT.hand_area.w, LAYOUT.hand_area.h))
	ui_root.add_child(hand_area)

	# 手持ちカード表示
	build_hand_area()

	# 6. フッター（次へ/スキップボタン）
	var footer = create_footer()
	ui_root.add_child(footer)

# フッター作成
func create_footer() -> HBoxContainer:
	var footer = HBoxContainer.new()
	footer.set_position(Vector2(LAYOUT.footer.x, LAYOUT.footer.y))
	footer.set_size(Vector2(LAYOUT.footer.w, LAYOUT.footer.h))

	var next_button = Button.new()
	next_button.text = "次へ進む"
	next_button.pressed.connect(on_next_button_clicked)
	footer.add_child(next_button)

	var skip_button = Button.new()
	skip_button.text = "スキップ"
	skip_button.pressed.connect(on_skip_button_clicked)
	footer.add_child(skip_button)

	return footer

# 次へ進むボタン処理（Phase 1では空実装）
func on_next_button_clicked() -> void:
	print("[RestScreenManager] 次へ進むボタン押下")
	cleanup()

# スキップボタン処理（Phase 1では空実装）
func on_skip_button_clicked() -> void:
	print("[RestScreenManager] スキップボタン押下")
	cleanup()

# 手持ちカードエリア構築（Phase 2）
func build_hand_area() -> void:
	if not game_session:
		print("[RestScreenManager] GameSession未設定")
		return

	# selected_deckを読み込み
	var deck: Array = game_session.selected_deck
	if deck.size() == 0:
		print("[RestScreenManager] selected_deckが空")
		return

	# CardDBからユニットデータ取得
	var card_db = get_node_or_null("/root/CardDB")
	if not card_db:
		print("[RestScreenManager] CardDB未取得")
		return

	# 各カードのCardView作成
	for card_name in deck:
		if not card_db.UNITS.has(card_name):
			print("[RestScreenManager] カード未登録: %s" % card_name)
			continue

		var card_data_dict: Dictionary = card_db.UNITS[card_name]
		var card_view = create_card_view(card_data_dict, card_name)
		hand_area.add_child(card_view)

	print("[RestScreenManager] 手持ちカード %d枚表示" % deck.size())

# CardView作成
func create_card_view(card_data: Dictionary, card_name: String) -> Control:
	var card_container = Control.new()
	card_container.set_custom_minimum_size(Vector2(100, 130))

	# カード背景
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.3)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_container.add_child(bg)

	# カード名
	var name_label = Label.new()
	name_label.text = card_name
	name_label.set_position(Vector2(5, 5))
	name_label.add_theme_font_size_override("font_size", 10)
	card_container.add_child(name_label)

	# ステータス表示
	var stats_label = Label.new()
	stats_label.text = "HP:%d ATK:%d" % [card_data.get("hp", 0), card_data.get("atk", 0)]
	stats_label.set_position(Vector2(5, 25))
	stats_label.add_theme_font_size_override("font_size", 9)
	card_container.add_child(stats_label)

	# D&D対応（Phase 2実装範囲外だが準備）
	# card_container.gui_input.connect(_on_card_gui_input.bind(card_name))

	return card_container

# クリーンアップ
func cleanup() -> void:
	if ui_root:
		ui_root.queue_free()
	queue_free()
