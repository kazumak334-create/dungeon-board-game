# DeckTestTool.gd
# デッキテストツール：効率的に敵デッキをテストする
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null
var _editing_side: int = 0  # 0=自軍, 1=敵軍
var _player_preview: Control = null
var _enemy_preview: Control = null
var _seed_input: LineEdit = null
var _speed_option: OptionButton = null
var _count_option: OptionButton = null

# プレビューセル定数
const PREVIEW_CELL_W = 35
const PREVIEW_CELL_H = 35
const PREVIEW_GAP = 2

func _ready() -> void:
	_build_ui()
	_load_test_data()  # 仮データ読み込み

func _build_ui() -> void:
	UIF.add_bg(self)

	# タスクバー
	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, "tool")

	# タイトル
	var title = Label.new()
	title.text = "デッキテストツール"
	title.position = Vector2(20, 50)
	title.size = Vector2(400, 30)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	add_child(title)

	# 敵軍エリア
	_build_side_area(1, Vector2(40, 100))

	# 自軍エリア
	_build_side_area(0, Vector2(40, 320))

	# コントロールパネル
	_build_control_panel()

func _build_side_area(side: int, pos: Vector2) -> void:
	var side_name = "敵軍" if side == 1 else "自軍"

	# サイドラベル
	var label = Label.new()
	label.text = side_name
	label.position = pos
	label.size = Vector2(100, 25)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	add_child(label)

	# プレビューパネル
	var preview = _create_preview_panel(side)
	preview.position = pos + Vector2(0, 30)
	add_child(preview)

	if side == 0:
		_player_preview = preview
	else:
		_enemy_preview = preview

	# ボタン群
	var btn_x = pos.x + 130
	var btn_y = pos.y + 30

	# [編集]ボタン
	var edit_btn = Button.new()
	edit_btn.text = "編集"
	edit_btn.position = Vector2(btn_x, btn_y)
	edit_btn.size = Vector2(80, 30)
	edit_btn.pressed.connect(func(): _on_edit_pressed(side))
	add_child(edit_btn)

	# [読込]ボタン
	var load_btn = Button.new()
	load_btn.text = "読込"
	load_btn.position = Vector2(btn_x + 90, btn_y)
	load_btn.size = Vector2(80, 30)
	load_btn.pressed.connect(func(): _on_load_pressed(side))
	add_child(load_btn)

	# 敵軍のみ：[ランダム生成]ボタン
	if side == 1:
		var random_btn = Button.new()
		random_btn.text = "ランダム生成"
		random_btn.position = Vector2(btn_x + 180, btn_y)
		random_btn.size = Vector2(120, 30)
		random_btn.pressed.connect(func(): _on_random_pressed())
		add_child(random_btn)

	# 自軍のみ：[敵をコピー]ボタン
	if side == 0:
		var copy_btn = Button.new()
		copy_btn.text = "敵をコピー"
		copy_btn.position = Vector2(btn_x + 180, btn_y)
		copy_btn.size = Vector2(120, 30)
		copy_btn.pressed.connect(func(): _on_copy_enemy())
		add_child(copy_btn)

func _create_preview_panel(side: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 120)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.set_corner_radius_all(5)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.4, 0.5)
	panel.add_theme_stylebox_override("panel", style)

	# 3×3グリッド
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", PREVIEW_GAP)
	grid.add_theme_constant_override("v_separation", PREVIEW_GAP)

	for _i in range(9):
		var cell = ColorRect.new()
		cell.custom_minimum_size = Vector2(PREVIEW_CELL_W, PREVIEW_CELL_H)
		cell.color = Color(0.2, 0.2, 0.25)
		grid.add_child(cell)

	panel.add_child(grid)
	return panel

func _build_control_panel() -> void:
	var panel_y = 540

	# シード入力
	var seed_label = Label.new()
	seed_label.text = "乱数シード:"
	seed_label.position = Vector2(40, panel_y)
	seed_label.size = Vector2(100, 25)
	add_child(seed_label)

	_seed_input = LineEdit.new()
	_seed_input.position = Vector2(140, panel_y)
	_seed_input.size = Vector2(120, 30)
	_seed_input.placeholder_text = "空欄=ランダム"
	add_child(_seed_input)

	# 速度選択
	var speed_label = Label.new()
	speed_label.text = "速度:"
	speed_label.position = Vector2(280, panel_y)
	speed_label.size = Vector2(60, 25)
	add_child(speed_label)

	_speed_option = OptionButton.new()
	_speed_option.position = Vector2(340, panel_y)
	_speed_option.size = Vector2(100, 30)
	_speed_option.add_item("1倍速", 0)
	_speed_option.add_item("2倍速", 1)
	_speed_option.add_item("瞬間決着", 2)
	add_child(_speed_option)

	# 回数選択
	var count_label = Label.new()
	count_label.text = "回数:"
	count_label.position = Vector2(460, panel_y)
	count_label.size = Vector2(60, 25)
	add_child(count_label)

	_count_option = OptionButton.new()
	_count_option.position = Vector2(520, panel_y)
	_count_option.size = Vector2(100, 30)
	_count_option.add_item("1回", 0)
	_count_option.add_item("10回", 1)
	_count_option.add_item("50回", 2)
	_count_option.add_item("100回", 3)
	add_child(_count_option)

	# [テスト開始]ボタン
	var start_btn = Button.new()
	start_btn.text = "テスト開始"
	start_btn.position = Vector2(640, panel_y - 5)
	start_btn.size = Vector2(150, 40)
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.pressed.connect(_on_start_test)
	add_child(start_btn)

# ボタンハンドラ（仮実装）
func _on_edit_pressed(side: int) -> void:
	print("[DeckTestTool] 編集ボタン押下: side=%d" % side)
	# TODO: DeckPrepモーダルを開く

func _on_load_pressed(side: int) -> void:
	print("[DeckTestTool] 読込ボタン押下: side=%d" % side)
	# TODO: プリセット読込ダイアログ

func _on_random_pressed() -> void:
	print("[DeckTestTool] ランダム生成ボタン押下")
	# TODO: ランダム敵デッキ生成

func _on_copy_enemy() -> void:
	print("[DeckTestTool] 敵をコピーボタン押下")
	# TODO: 敵軍デッキを自軍にコピー

func _on_start_test() -> void:
	print("[DeckTestTool] テスト開始")

	# シード取得
	var seed_text = _seed_input.text.strip_edges()
	if seed_text.is_empty():
		GameSession.tool_rng_seed = -1
	else:
		GameSession.tool_rng_seed = int(seed_text)

	# 速度取得
	var speed_idx = _speed_option.get_selected_id()
	match speed_idx:
		0: GameSession.tool_battle_speed = 1.0
		1: GameSession.tool_battle_speed = 2.0
		2: GameSession.tool_battle_speed = 999.0

	# 回数取得
	var count_idx = _count_option.get_selected_id()
	match count_idx:
		0: GameSession.tool_battle_count = 1
		1: GameSession.tool_battle_count = 10
		2: GameSession.tool_battle_count = 50
		3: GameSession.tool_battle_count = 100

	# ツールモード有効化
	GameSession._is_tool_mode = true

	# バトルシーンへ遷移
	SceneManager.go_to(SceneManager.BATTLE)

# プレビュー更新
func _update_preview(side: int) -> void:
	var preview = _player_preview if side == 0 else _enemy_preview
	if preview == null:
		return

	var placement = GameSession.tool_placement_player if side == 0 else GameSession.tool_placement_enemy
	var grid = preview.get_child(0) as GridContainer
	if grid == null:
		return

	# 9マスのプレビューを更新
	for i in range(9):
		var cell = grid.get_child(i) as ColorRect
		if cell == null:
			continue

		var row = i / 3
		var col = i % 3

		# 配置情報から該当ユニットを検索
		var has_unit = false
		for entry in placement:
			if entry.get("row", -1) == row and entry.get("col", -1) == col:
				has_unit = true
				break

		# 色を設定
		if has_unit:
			cell.color = Color(0.4, 0.6, 0.4)  # 緑（ユニットあり）
		else:
			cell.color = Color(0.2, 0.2, 0.25)  # 灰色（空）

# 仮データ読み込み（テスト用）
func _load_test_data() -> void:
	# 自軍：スライム3体
	GameSession.tool_deck_player = [
		{"name": "スライム"},
		{"name": "スライム"},
		{"name": "スライム"},
	]
	GameSession.tool_placement_player = [
		{"name": "スライム", "row": 0, "col": 2},
		{"name": "スライム", "row": 1, "col": 2},
		{"name": "スライム", "row": 2, "col": 2},
	]

	# 敵軍：スケルトン3体
	GameSession.tool_deck_enemy = [
		{"name": "スケルトン"},
		{"name": "スケルトン"},
		{"name": "スケルトン"},
	]
	GameSession.tool_placement_enemy = [
		{"name": "スケルトン", "row": 0, "col": 0},
		{"name": "スケルトン", "row": 1, "col": 0},
		{"name": "スケルトン", "row": 2, "col": 0},
	]

	# プレビュー更新
	_update_preview(0)
	_update_preview(1)

	print("[DeckTestTool] 仮データ読み込み完了")
