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
var shop: Node
var revive: Node

var rest_state: Dictionary = {
	"mode": RestMode.NONE,
	"selected_card": null,
	"selected_index": -1,
	"shop_items": [],
	"gold": 0,
	"hover_source": "",        # "hand"/"board"/"shop"/""
	"hover_card_name": ""      # 現在ホバー中のカード名
}

var right_panel_content: VBoxContainer  # 状態別コンテンツ入れ替え用
var error_label: Label                   # バリデーションエラー表示

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

	# 3.5. ショップ盤面
	shop = preload("res://scripts/RestScreenShop.gd").new()
	add_child(shop)
	shop.initialize(game_session, ui_root)
	shop.purchase_completed.connect(_on_shop_purchase_completed)

	# 3.6. ユニット復帰
	revive = preload("res://scripts/RestScreenRevive.gd").new()
	add_child(revive)
	revive.initialize(game_session, ui_root)
	revive.revive_completed.connect(_on_revive_completed)

	# 4. 右パネル
	right_panel = Panel.new()
	right_panel.set_position(Vector2(LAYOUT.right_panel.x, LAYOUT.right_panel.y))
	right_panel.set_size(Vector2(LAYOUT.right_panel.w, LAYOUT.right_panel.h))
	ui_root.add_child(right_panel)

	# 右パネルコンテンツコンテナ
	right_panel_content = VBoxContainer.new()
	right_panel_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_panel.add_child(right_panel_content)

	# 初期表示（未選択状態）
	update_right_panel()

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

	# エラーラベル追加
	error_label = Label.new()
	error_label.text = ""
	error_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	error_label.set_position(Vector2(200, 0))
	footer.add_child(error_label)

	return footer

# 次へ進むボタン処理
func on_next_button_clicked() -> void:
	if not validate_deck():
		_show_validation_error("盤面を3×3全て埋めてください")
		return
	_transition_to_next_wave()

# スキップボタン処理
func on_skip_button_clicked() -> void:
	print("[RestScreenManager] スキップ（バリデーション省略）")
	_transition_to_next_wave()

# 手持ちカードエリア構築（Phase 2）
func build_hand_area() -> void:
	if not game_session:
		print("[RestScreenManager] GameSession未設定")
		return

	# CardDBからユニットデータ取得
	var card_db = get_node_or_null("/root/CardDB")
	if not card_db:
		print("[RestScreenManager] CardDB未取得")
		return

	# selected_deckを読み込み（生存ユニット）
	var deck: Array = game_session.selected_deck
	for card_name in deck:
		if not card_db.UNITS.has(card_name):
			print("[RestScreenManager] カード未登録: %s" % card_name)
			continue

		var card_data_dict: Dictionary = card_db.UNITS[card_name]
		var card_view = create_card_view(card_data_dict, card_name)
		hand_area.add_child(card_view)

	# 死亡ユニットを表示（revivable_units から）
	if revive and revive.revivable_units.size() > 0:
		for revivable_unit in revive.revivable_units:
			var unit_name: String = revivable_unit.unit_name
			if not card_db.UNITS.has(unit_name):
				continue

			var card_data_dict: Dictionary = card_db.UNITS[unit_name]
			var card_view = create_card_view(card_data_dict, unit_name)

			# 復帰ボタンを追加
			var revive_button = revive.create_revive_button(card_view, revivable_unit)

			hand_area.add_child(card_view)

	print("[RestScreenManager] 手持ちカード %d枚 + 死亡ユニット %d体表示" % [deck.size(), revive.revivable_units.size() if revive else 0])

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

	# ホバーイベント接続
	card_container.mouse_entered.connect(_on_card_hover_enter.bind(card_name, "hand"))
	card_container.mouse_exited.connect(_on_card_hover_exit)

	return card_container

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

# 右パネル更新
func update_right_panel() -> void:
	_clear_right_panel_contents()

	match rest_state.mode:
		RestMode.NONE:
			_build_right_panel_empty()
		RestMode.CARD_SELECTED:
			_build_right_panel_card_detail(rest_state.selected_card, false)
		RestMode.SHOP_HOVER:
			_build_right_panel_card_detail(rest_state.selected_card, true)

# 右パネルコンテンツクリア
func _clear_right_panel_contents() -> void:
	if not right_panel_content:
		return
	for child in right_panel_content.get_children():
		child.queue_free()

# 未選択時のガイドテキスト
func _build_right_panel_empty() -> void:
	var guide1 = Label.new()
	guide1.text = "カードを選択して"
	guide1.add_theme_font_size_override("font_size", 12)
	guide1.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	guide1.set_position(Vector2(40, 240))
	right_panel_content.add_child(guide1)

	var guide2 = Label.new()
	guide2.text = "詳細を表示"
	guide2.add_theme_font_size_override("font_size", 12)
	guide2.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	guide2.set_position(Vector2(55, 260))
	right_panel_content.add_child(guide2)

# カード詳細表示（ステータス・効果・特性）
func _build_right_panel_card_detail(card_data: Dictionary, is_shop: bool) -> void:
	if not card_data:
		return

	# カード名
	var name_label = Label.new()
	name_label.text = card_data.get("unit_name", "???")
	name_label.set_position(Vector2(10, 10))
	name_label.set_size(Vector2(180, 22))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	right_panel_content.add_child(name_label)

	# レアリティ
	var rarity = card_data.get("rarity", "Common")
	var rarity_label = Label.new()
	rarity_label.text = rarity
	rarity_label.set_position(Vector2(10, 34))
	rarity_label.set_size(Vector2(180, 18))
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", _get_rarity_color(rarity))
	right_panel_content.add_child(rarity_label)

	# ステータス
	var hp_label = Label.new()
	hp_label.text = "HP: %d" % card_data.get("hp", 0)
	hp_label.set_position(Vector2(10, 60))
	hp_label.set_size(Vector2(180, 16))
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	right_panel_content.add_child(hp_label)

	var atk_label = Label.new()
	atk_label.text = "ATK: %d" % card_data.get("atk", 0)
	atk_label.set_position(Vector2(10, 78))
	atk_label.set_size(Vector2(180, 16))
	atk_label.add_theme_font_size_override("font_size", 11)
	atk_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	right_panel_content.add_child(atk_label)

	var spd_label = Label.new()
	spd_label.text = "SPD: %.1f" % card_data.get("spd", 0.0)
	spd_label.set_position(Vector2(10, 96))
	spd_label.set_size(Vector2(180, 16))
	spd_label.add_theme_font_size_override("font_size", 11)
	spd_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	right_panel_content.add_child(spd_label)

	var mana_label = Label.new()
	mana_label.text = "Mana: %d" % card_data.get("mana", 0)
	mana_label.set_position(Vector2(10, 114))
	mana_label.set_size(Vector2(180, 16))
	mana_label.add_theme_font_size_override("font_size", 11)
	mana_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	right_panel_content.add_child(mana_label)

	# 種族
	var race = card_data.get("race", "不明")
	var race_label = Label.new()
	race_label.text = race
	race_label.set_position(Vector2(10, 140))
	race_label.set_size(Vector2(180, 18))
	race_label.add_theme_font_size_override("font_size", 12)
	race_label.add_theme_color_override("font_color", _get_race_color(race))
	right_panel_content.add_child(race_label)

	# 特性バッジ
	var traits = card_data.get("traits", [])
	if traits.size() > 0:
		var traits_container = HBoxContainer.new()
		traits_container.set_position(Vector2(10, 164))
		traits_container.set_size(Vector2(180, 20))
		for trait in traits:
			var trait_label = Label.new()
			trait_label.text = "[%s]" % trait
			trait_label.add_theme_font_size_override("font_size", 10)
			trait_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
			traits_container.add_child(trait_label)
		right_panel_content.add_child(traits_container)

	# 効果テキスト
	var effect_text = card_data.get("support_effect", "")
	if effect_text != "":
		var effect_label = Label.new()
		effect_label.text = effect_text
		effect_label.set_position(Vector2(10, 190))
		effect_label.set_size(Vector2(180, 80))
		effect_label.add_theme_font_size_override("font_size", 11)
		effect_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		right_panel_content.add_child(effect_label)

	# ショップ時の価格表示
	if is_shop:
		var price = card_data.get("price", 0)
		var price_label = Label.new()
		price_label.text = "価格: %dG" % price
		price_label.set_position(Vector2(10, 280))
		price_label.set_size(Vector2(180, 18))
		price_label.add_theme_font_size_override("font_size", 12)
		price_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		right_panel_content.add_child(price_label)

		var affordable = rest_state.gold >= price
		var status_label = Label.new()
		status_label.text = "購入可能" if affordable else "資金不足"
		status_label.set_position(Vector2(10, 300))
		status_label.set_size(Vector2(180, 18))
		status_label.add_theme_font_size_override("font_size", 11)
		status_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3) if affordable else Color(0.8, 0.3, 0.3))
		right_panel_content.add_child(status_label)

# レアリティ色取得
func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"Common":
			return Color(0.7, 0.7, 0.7)
		"Rare":
			return Color(0.3, 0.6, 0.9)
		"Epic":
			return Color(0.8, 0.3, 0.9)
		_:
			return Color(0.5, 0.5, 0.5)

# 種族色取得
func _get_race_color(race: String) -> Color:
	match race:
		"スライム":
			return Color(0.3, 0.8, 0.5)
		"獣":
			return Color(0.9, 0.6, 0.3)
		"アンデッド":
			return Color(0.6, 0.4, 0.7)
		_:
			return Color(0.6, 0.6, 0.6)

# ホバー開始ハンドラ
func _on_card_hover_enter(card_name: String, source: String) -> void:
	var card_db = get_node_or_null("/root/CardDB")
	if not card_db or not card_db.UNITS.has(card_name):
		return

	rest_state.hover_source = source
	rest_state.hover_card_name = card_name
	rest_state.selected_card = card_db.UNITS[card_name]
	rest_state.mode = RestMode.SHOP_HOVER if source == "shop" else RestMode.CARD_SELECTED
	update_right_panel()

# ホバー終了ハンドラ
func _on_card_hover_exit() -> void:
	# 選択がない状態ならNONEへ戻す
	if rest_state.selected_index == -1:
		rest_state.mode = RestMode.NONE
		rest_state.selected_card = null
	rest_state.hover_source = ""
	rest_state.hover_card_name = ""
	update_right_panel()

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
	# Main.gd の _on_rest_screen_closed() を呼び出す
	var main = get_tree().get_root().get_node_or_null("Main")
	if main and main.has_method("_on_rest_screen_closed"):
		main._on_rest_screen_closed()
	else:
		# フォールバック: GameSession.wave_rest_pending をクリア
		if game_session:
			game_session.wave_rest_pending = false
	cleanup()

# クリーンアップ
func cleanup() -> void:
	if shop:
		shop.cleanup()
	if revive:
		revive.cleanup()
	if ui_root:
		ui_root.queue_free()
	queue_free()
