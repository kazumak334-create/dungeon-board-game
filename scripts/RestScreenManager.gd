extends Control

# RestScreen全体の制御・UI構築・状態管理

signal rest_screen_closed

const UIF = preload("res://scripts/UIFactory.gd")
const UIColors = preload("res://scripts/ui/UIColors.gd")

# 座標定義
const LAYOUT = {
	"header": {"x": 0, "y": 0, "w": 1280, "h": 36},
	"card_list": {"x": 0, "y": 36, "w": 200, "h": 684},
	"card_detail": {"x": 1080, "y": 36, "w": 200, "h": 684},
	"footer": {"x": 200, "y": 680, "w": 780, "h": 40}
}

const CARD_MINI = {"w": 60, "h": 95}  # 小カードサイズ

const DEFAULT_SHOP_CONFIG: Dictionary = {
	"unit_count": 6,
	"spell_count": 3,
	"material_count": 3,
	"rarity_weights": {"common": 70, "uncommon": 20, "rare": 8, "epic": 2},
	"allow_duplicates": true
}

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
var hand_area: GridContainer
var card_list_bar: Panel  # 左側カードリストバー
var card_detail_bar: PanelContainer  # 右側カード詳細バー
var card_detail_container: VBoxContainer  # 右側詳細コンテンツ
var shop: Node
var revive: Node
var _shop_config: Dictionary = {}
var _hide_shop: bool = false  # ショップ非表示フラグ（初回デッキ編集用）

var rest_state: Dictionary = {
	"mode": RestMode.NONE,
	"selected_card": null,
	"selected_index": -1,
	"shop_items": [],
	"gold": 0,
	"hover_source": "",        # "hand"/"board"/"shop"/""
	"hover_card_name": ""      # 現在ホバー中のカード名
}

var error_label: Label  # バリデーションエラー表示

# 初期化
func initialize(session: Node, board: Node, shop_config: Dictionary = {}, hide_shop: bool = false) -> void:
	game_session = session
	board_manager = board
	_hide_shop = hide_shop

	# shop_config正規化
	var cfg: Dictionary = DEFAULT_SHOP_CONFIG.duplicate(true)
	for key in shop_config.keys():
		cfg[key] = shop_config[key]
	_shop_config = cfg

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

	# 3. 自陣盤面はMain.gdのBoardManagerをそのまま使用（独自UI不要）
	# BoardManager.enable_rest_mode()でRest用の挙動に切り替える
	if board_manager:
		board_manager.enable_rest_mode()

	# 3.5. ショップ盤面（hide_shop=trueの場合は非表示）
	if not _hide_shop:
		shop = preload("res://scripts/RestScreenShop.gd").new()
		add_child(shop)
		shop.initialize(game_session, ui_root, _shop_config)
		shop.purchase_completed.connect(_on_shop_purchase_completed)

	# 3.6. ユニット復帰
	revive = preload("res://scripts/RestScreenRevive.gd").new()
	add_child(revive)
	revive.initialize(game_session, ui_root)
	revive.revive_completed.connect(_on_revive_completed)

	# 4. 左側カードリストバー（RestScreen独自）
	card_list_bar = Panel.new()
	card_list_bar.set_position(Vector2(LAYOUT.card_list.x, LAYOUT.card_list.y))
	card_list_bar.set_size(Vector2(LAYOUT.card_list.w, LAYOUT.card_list.h))
	var list_style = StyleBoxFlat.new()
	list_style.bg_color = Color(0.15, 0.15, 0.18)
	list_style.border_color = Color(0.3, 0.3, 0.35)
	list_style.set_border_width_all(1)
	card_list_bar.add_theme_stylebox_override("panel", list_style)
	ui_root.add_child(card_list_bar)

	# 手持ちカードリスト見出し
	var card_list_label = Label.new()
	card_list_label.text = "手持ちカード"
	card_list_label.set_position(Vector2(10, 5))
	card_list_label.add_theme_font_size_override("font_size", 14)
	card_list_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	card_list_bar.add_child(card_list_label)

	# 手持ちカードリスト（3列グリッド）
	var card_scroll = ScrollContainer.new()
	card_scroll.set_position(Vector2(5, 30))
	card_scroll.set_size(Vector2(LAYOUT.card_list.w - 10, LAYOUT.card_list.h - 35))
	card_list_bar.add_child(card_scroll)

	hand_area = GridContainer.new()
	hand_area.columns = 3
	hand_area.set_h_size_flags(Control.SIZE_FILL)
	card_scroll.add_child(hand_area)

	# 手持ちカード表示
	build_hand_area()

	# 5. 右側カード詳細バー（DeckPrep流用）
	card_detail_bar = UIF.create_panel(
		Vector2(LAYOUT.card_detail.x, LAYOUT.card_detail.y),
		Vector2(LAYOUT.card_detail.w, LAYOUT.card_detail.h),
		UIColors.COLOR_SIDE_PANEL,
		UIColors.COLOR_BORDER,
		1,
		4
	)
	ui_root.add_child(card_detail_bar)

	# カード詳細コンテンツコンテナ
	card_detail_container = VBoxContainer.new()
	card_detail_container.position = Vector2(LAYOUT.card_detail.x, LAYOUT.card_detail.y)
	card_detail_container.size = Vector2(LAYOUT.card_detail.w, LAYOUT.card_detail.h)
	ui_root.add_child(card_detail_container)

	# 初期表示（未選択ガイド）
	_show_card_detail_guide()

	# 6. 盤面クリック用オーバーレイ（自陣3×3）
	_setup_board_click_overlay()

	# 7. フッター（次へ/スキップボタン）
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

	# エラーラベル追加
	error_label = Label.new()
	error_label.text = ""
	error_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	error_label.set_position(Vector2(200, 0))
	footer.add_child(error_label)

	return footer

# 次へ進むボタン処理
func on_next_button_clicked() -> void:
	# 最低1枚配置チェック（0マス配置では進行不可）
	if not _has_at_least_one_unit():
		_show_validation_error("最低1枚は配置してください")
		return
	_transition_to_next_wave()

# 最低1枚配置チェック
func _has_at_least_one_unit() -> bool:
	if not board_manager:
		return false
	# board_manager.board[0] の中に1枚でもユニットがあればOK
	for row in board_manager.board[0]:
		for unit in row:
			if unit != null:
				return true
	return false

# スキップボタン処理
func on_skip_button_clicked() -> void:
	print("[RestScreenManager] スキップ（バリデーション省略）")
	_transition_to_next_wave()

# 手持ちカードエリア構築（Phase 2）
func build_hand_area() -> void:
	if not game_session:
		print("[RestScreenManager] GameSession未設定")
		return

	# デバッグログ追加
	print("[RestScreenManager] build_hand_area() selected_deck=%s" % [game_session.selected_deck])

	# CardDBからユニットデータ取得（AutoLoadは直接参照可能）
	if not CardDB:
		print("[RestScreenManager] CardDB未取得")
		return

	# selected_deckを読み込み（生存ユニット）
	var deck: Array = game_session.selected_deck
	for i in range(deck.size()):
		var card_data = deck[i]
		# Dictionary形式 {name: "card_name"} または文字列に対応
		var card_name: String = card_data.get("name", "") if card_data is Dictionary else str(card_data)

		if not CardDB.UNITS.has(card_name):
			print("[RestScreenManager] カード未登録: %s" % card_name)
			continue

		var card_data_dict: Dictionary = CardDB.UNITS[card_name]
		var card_view = create_card_view(card_data_dict, card_name, i)
		hand_area.add_child(card_view)

	# 死亡ユニットを表示（revivable_units から）
	if revive and revive.revivable_units.size() > 0:
		for revivable_unit in revive.revivable_units:
			var unit_name: String = revivable_unit.unit_name
			if not CardDB.UNITS.has(unit_name):
				continue

			var card_data_dict: Dictionary = CardDB.UNITS[unit_name]
			var card_view = create_card_view(card_data_dict, unit_name, -1)

			# 復帰ボタンを追加
			var revive_button = revive.create_revive_button(card_view, revivable_unit)

			hand_area.add_child(card_view)

	print("[RestScreenManager] 手持ちカード %d枚 + 死亡ユニット %d体表示" % [deck.size(), revive.revivable_units.size() if revive else 0])

# CardView作成（小カード表示）
func create_card_view(card_data_dict: Dictionary, card_name: String, index: int = -1) -> Control:
	var card_panel = Panel.new()
	card_panel.set_custom_minimum_size(Vector2(CARD_MINI.w, CARD_MINI.h))

	# 背景スタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(1)
	card_panel.add_theme_stylebox_override("panel", style)

	# カード名
	var name_label = Label.new()
	name_label.text = card_name
	name_label.set_position(Vector2(2, 2))
	name_label.set_size(Vector2(56, 40))
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_panel.add_child(name_label)

	# HP/ATK
	var hp_label = Label.new()
	hp_label.text = "HP %d" % card_data_dict.get("hp", 0)
	hp_label.set_position(Vector2(2, 45))
	hp_label.add_theme_font_size_override("font_size", 9)
	card_panel.add_child(hp_label)

	var atk_label = Label.new()
	atk_label.text = "ATK %d" % card_data_dict.get("atk", 0)
	atk_label.set_position(Vector2(2, 60))
	atk_label.add_theme_font_size_override("font_size", 9)
	card_panel.add_child(atk_label)

	# クリックイベント（要件定義書 §6.1.5）
	if index >= 0:
		card_panel.gui_input.connect(_on_hand_card_gui_input.bind(index))

	return card_panel

# 手持ちカードGUI入力処理
func _on_hand_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		on_hand_card_clicked(index)

# 右側カード詳細表示（未選択ガイド）- DeckPrep流用
func _show_card_detail_guide() -> void:
	_clear_card_detail()
	var hint = Label.new()
	hint.text = "カードを選択すると\n詳細が表示されます"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(10, 250)
	hint.size = Vector2(LAYOUT.card_detail.w - 20, 60)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UIF.DIM_COLOR)
	card_detail_container.add_child(hint)

# 右側カード詳細表示（カード選択時）
func _show_card_detail(card_name: String, card_data: Dictionary) -> void:
	_clear_card_detail()

	# カード名
	var name_label = Label.new()
	name_label.text = card_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	card_detail_container.add_child(name_label)

	# ステータス
	var hp_label = Label.new()
	hp_label.text = "HP: %d" % card_data.get("hp", 0)
	hp_label.add_theme_font_size_override("font_size", 12)
	card_detail_container.add_child(hp_label)

	var atk_label = Label.new()
	atk_label.text = "ATK: %d" % card_data.get("atk", 0)
	atk_label.add_theme_font_size_override("font_size", 12)
	card_detail_container.add_child(atk_label)

	var spd_label = Label.new()
	spd_label.text = "SPD: %.1f" % card_data.get("spd", 1.0)
	spd_label.add_theme_font_size_override("font_size", 12)
	card_detail_container.add_child(spd_label)

	var mana_label = Label.new()
	mana_label.text = "Mana: %d" % card_data.get("mana", 0)
	mana_label.add_theme_font_size_override("font_size", 12)
	card_detail_container.add_child(mana_label)

	# 種族
	var race = card_data.get("race", "不明")
	var race_label = Label.new()
	race_label.text = "種族: %s" % race
	race_label.add_theme_font_size_override("font_size", 12)
	card_detail_container.add_child(race_label)

	# スキル
	var skills = card_data.get("skills", [])
	if skills is Array and skills.size() > 0:
		var skills_label = Label.new()
		skills_label.text = "\nスキル:"
		skills_label.add_theme_font_size_override("font_size", 12)
		card_detail_container.add_child(skills_label)

		for skill in skills:
			if skill is Dictionary:
				var trigger = skill.get("trigger", "")
				var effect_id = skill.get("effect_id", "")
				var skill_text = "%s: %s" % [trigger, effect_id]
				var skill_label = Label.new()
				skill_label.text = "・%s" % skill_text
				skill_label.add_theme_font_size_override("font_size", 10)
				skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD
				card_detail_container.add_child(skill_label)
			else:
				var skill_label = Label.new()
				skill_label.text = "・%s" % str(skill)
				skill_label.add_theme_font_size_override("font_size", 10)
				skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD
				card_detail_container.add_child(skill_label)

# 右側カード詳細クリア
func _clear_card_detail() -> void:
	if not card_detail_container:
		return
	for child in card_detail_container.get_children():
		child.queue_free()

# ショップ購入完了コールバック
func _on_shop_purchase_completed(card_id: String, new_gold: int) -> void:
	rest_state.gold = new_gold
	# 手持ちカードエリア再構築
	for child in hand_area.get_children():
		child.queue_free()
	build_hand_area()

# ユニット復帰完了コールバック
func _on_revive_completed(unit_name: String, new_gold: int) -> void:
	rest_state.gold = new_gold
	# 手持ちカードエリア再構築
	for child in hand_area.get_children():
		child.queue_free()
	build_hand_area()

# 盤面クリック用オーバーレイ設定
func _setup_board_click_overlay() -> void:
	if not board_manager:
		return

	# Main.gdの盤面定数
	const CELL_W = 130
	const CELL_H = 95
	const BOARD_TOP = 88
	const BOARD_LEFT = 230  # 自陣開始X位置（左側バー200px + マージン30px）

	# 自陣3×3グリッドにクリック領域を追加
	for row in range(3):
		for col in range(3):
			var cell_btn = Button.new()
			cell_btn.set_position(Vector2(BOARD_LEFT + col * CELL_W, BOARD_TOP + row * CELL_H))
			cell_btn.set_size(Vector2(CELL_W, CELL_H))
			cell_btn.flat = true
			cell_btn.modulate.a = 0.0  # 完全透明
			cell_btn.pressed.connect(on_board_cell_clicked.bind(row, col))
			ui_root.add_child(cell_btn)


# ホバー開始ハンドラ
func _on_card_hover_enter(card_name: String, source: String) -> void:
	var card_db = get_node_or_null("/root/CardDB")
	if not card_db or not card_db.UNITS.has(card_name):
		return

	rest_state.hover_source = source
	rest_state.hover_card_name = card_name
	rest_state.selected_card = card_db.UNITS[card_name]
	rest_state.mode = RestMode.SHOP_HOVER if source == "shop" else RestMode.CARD_SELECTED

# ホバー終了ハンドラ
func _on_card_hover_exit() -> void:
	# 選択がない状態ならNONEへ戻す
	if rest_state.selected_index == -1:
		rest_state.mode = RestMode.NONE
		rest_state.selected_card = null
	rest_state.hover_source = ""
	rest_state.hover_card_name = ""

# デッキバリデーション
func validate_deck() -> bool:
	if not game_session:
		return false

	var initial_units = game_session.initial_units
	if initial_units.size() != 9:
		return false

	for slot in initial_units:
		if slot == null:
			return false
		if slot is Dictionary and slot.get("name", "") == "":
			return false

	return true

# バリデーションエラー表示
func _show_validation_error(msg: String) -> void:
	if not error_label:
		return

	error_label.text = msg
	await get_tree().create_timer(3.0).timeout
	if error_label:
		error_label.text = ""

# WaveManagerへ遷移
func _transition_to_next_wave() -> void:
	# 左右のバーをスライドアウト
	await _slideout_bars()
	rest_screen_closed.emit()
	cleanup()

# 左右バーのスライドアウトアニメーション
func _slideout_bars() -> void:
	if not card_list_bar or not card_detail_bar:
		return

	var tween = create_tween()
	tween.set_parallel(true)
	# 左側バーを左へスライドアウト
	tween.tween_property(card_list_bar, "position:x", -LAYOUT.card_list.w, 0.3).set_ease(Tween.EASE_IN_OUT)
	# 右側バーを右へスライドアウト
	tween.tween_property(card_detail_bar, "position:x", 1280, 0.3).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

# クリーンアップ
func cleanup() -> void:
	if shop:
		shop.cleanup()
	if revive:
		revive.cleanup()
	if ui_root:
		ui_root.queue_free()
	queue_free()

# ---- カード配置システム ----
# 手持ちカードインデックス管理（要件定義書 §6.1.5）
var _selected_hand_index: int = -1

# 手持ちカードクリック処理（要件定義書 §6.1.5 準拠）
func on_hand_card_clicked(index: int) -> void:
	_selected_hand_index = index
	# カードデータ取得
	if not game_session or index < 0 or index >= game_session.selected_deck.size():
		return
	var card_data = game_session.selected_deck[index]
	var card_name: String = card_data.get("name", "") if card_data is Dictionary else str(card_data)
	if CardDB.UNITS.has(card_name):
		var card_data_dict: Dictionary = CardDB.UNITS[card_name]
		_show_card_detail(card_name, card_data_dict)
		_show_validation_error("盤面のマスをクリックして配置してください")

# 盤面セルクリック処理（要件定義書 §6.1.5 準拠）
func on_board_cell_clicked(row: int, col: int) -> void:
	if _selected_hand_index < 0:
		return
	if not game_session or _selected_hand_index >= game_session.selected_deck.size():
		return

	# 手持ちカードデータ取得
	var card_data_ref = game_session.selected_deck[_selected_hand_index]
	var card_name: String = card_data_ref.get("name", "") if card_data_ref is Dictionary else str(card_data_ref)

	if not CardDB.UNITS.has(card_name):
		_show_validation_error("カードが見つかりません")
		return

	var card_data: Dictionary = CardDB.UNITS[card_name]

	# UnitDataに変換
	var UnitDataScript = load("res://scripts/UnitData.gd")
	var unit_data = UnitDataScript.new()
	unit_data.unit_name = card_name
	unit_data.max_hp = card_data.get("hp", 0)
	unit_data.current_hp = card_data.get("hp", 0)
	unit_data.attack = card_data.get("atk", 0)
	unit_data.spd = card_data.get("spd", 1.0)
	unit_data.mana = card_data.get("mana", 0)
	unit_data.race = card_data.get("race", "")
	unit_data.attack_range = card_data.get("range", "1行")
	unit_data.assigned_col = card_data.get("col", 0)
	unit_data.skills = card_data.get("skills", []).duplicate(true)

	# BoardManagerに配置（要件定義書 §6.1.5）
	if board_manager.on_rest_drop(unit_data, row, col):
		# 配置成功→selected_deckから削除
		game_session.selected_deck.remove_at(_selected_hand_index)
		_selected_hand_index = -1
		rebuild_hand_area()
		_show_card_detail_guide()
		_show_validation_error("")
	else:
		_show_validation_error("配置に失敗しました")

# 手持ちカードエリア再構築（要件定義書 §6.1.5）
func rebuild_hand_area() -> void:
	for child in hand_area.get_children():
		child.queue_free()
	build_hand_area()
