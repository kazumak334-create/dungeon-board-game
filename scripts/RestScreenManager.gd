extends Control

# RestScreen全体の制御・UI構築・状態管理

signal rest_screen_closed

const UIF = preload("res://scripts/UIFactory.gd")
const UIColors = preload("res://scripts/ui/UIColors.gd")

# 座標定義
const LAYOUT = {
	"header": {"x": 0, "y": 0, "w": 1280, "h": 36},
	"card_list": {"x": 0, "y": 36, "w": 230, "h": 684},
	"card_detail": {"x": 1048, "y": 36, "w": 232, "h": 684},
	"footer": {"x": 230, "y": 680, "w": 820, "h": 40}
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
var wave_manager: Node  # WaveManager参照（EnemyPanelManager用）
var hand_area: GridContainer
var card_list_bar: Panel  # 左側カードリストバー
var card_detail_bar: PanelContainer  # 右側カード詳細バー
var card_detail_container: VBoxContainer  # 右側詳細コンテンツ
var shop: Node
var revive: Node
var _shop_config: Dictionary = {}
var _hide_shop: bool = false  # ショップ非表示フラグ（初回デッキ編集用）
var _enemy_panel: EnemyPanelManager = null

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

# タブ管理
var _tab_index: int = 0

# マナ表示ラベル
var _mana_label_unit: Label
var _mana_label_spell: Label

# 初期化
func initialize(session: Node, board: Node, shop_config: Dictionary = {}, hide_shop: bool = false, wm: Node = null) -> void:
	game_session = session
	board_manager = board
	wave_manager = wm
	_hide_shop = hide_shop

	# shop_config正規化
	var cfg: Dictionary = DEFAULT_SHOP_CONFIG.duplicate(true)
	for key in shop_config.keys():
		cfg[key] = shop_config[key]
	_shop_config = cfg

	if game_session:
		rest_state.gold = game_session.gold
		game_session.heal_use_count = 0
		game_session.scout_use_count = 0

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

	# 3.5. ショップ盤面はEnemyPanelManager（敵陣9マス）で担当するため、ここでは生成しない

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

	# 手持ちエリアのD&Dドロップ受付（盤面→手持ち戻し用、build_ui内で1回のみ設定）
	# ScrollContainerにも設定が必要（子のGridContainerより先にイベントを受け取るため）
	card_scroll.set_drag_forwarding(
		func(_pos): return null,
		_hand_area_can_drop_data,
		_hand_area_drop_data
	)
	hand_area.set_drag_forwarding(
		func(_pos): return null,
		_hand_area_can_drop_data,
		_hand_area_drop_data
	)

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

	# 6.5. 敵盤面パネル（EnemyPanelManager）
	_enemy_panel = EnemyPanelManager.new()
	_enemy_panel.wave_manager = wave_manager
	_enemy_panel.game_session = game_session
	_enemy_panel.board_manager = board_manager
	_enemy_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_enemy_panel)
	_enemy_panel.ready_to_battle.connect(_on_ready_to_battle)
	_enemy_panel.shop_item_detail_requested.connect(_on_shop_item_detail_requested)
	_enemy_panel.set_phase(EnemyPanelManager.EnemyPanelPhase.NEXT_EI, {"show_ready_button": not _hide_shop})

	# 7. フッター（次へ/スキップボタン）
	var footer = create_footer()
	ui_root.add_child(footer)

	# 8. マナ表示（左パネル・タブ直下に配置）
	# TabBar は y=25, h=24 → 下端 y=49。Scroll は y=55→y=90 にずらす（build_hand_areaで対応）
	var mana_bg = StyleBoxFlat.new()
	mana_bg.bg_color = Color(0.10, 0.10, 0.14)
	mana_bg.border_color = Color(0.25, 0.25, 0.30)
	mana_bg.set_border_width_all(1)

	# 盤面マナ行（TabBar実高さ考慮: y=25+36=61相当 → y=68で余裕を持たせる）
	var unit_row = Panel.new()
	unit_row.set_position(Vector2(4, 68))
	unit_row.set_size(Vector2(LAYOUT.card_list.w - 8, 18))
	unit_row.add_theme_stylebox_override("panel", mana_bg)
	card_list_bar.add_child(unit_row)

	_mana_label_unit = Label.new()
	_mana_label_unit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mana_label_unit.add_theme_font_size_override("font_size", 11)
	_mana_label_unit.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	_mana_label_unit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mana_label_unit.set_offset(SIDE_LEFT, 4)
	unit_row.add_child(_mana_label_unit)

	# 呪文マナ行
	var spell_row = Panel.new()
	spell_row.set_position(Vector2(4, 88))
	spell_row.set_size(Vector2(LAYOUT.card_list.w - 8, 18))
	spell_row.add_theme_stylebox_override("panel", mana_bg)
	card_list_bar.add_child(spell_row)

	_mana_label_spell = Label.new()
	_mana_label_spell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mana_label_spell.add_theme_font_size_override("font_size", 11)
	_mana_label_spell.add_theme_color_override("font_color", Color(0.9, 0.6, 1.0))
	_mana_label_spell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mana_label_spell.set_offset(SIDE_LEFT, 4)
	spell_row.add_child(_mana_label_spell)

	_refresh_mana_labels()

# フッター作成（REQ-QPA-07: 次へ進む/スキップボタン廃止。error_label のみ残す）
func create_footer() -> HBoxContainer:
	var footer = HBoxContainer.new()
	footer.set_position(Vector2(LAYOUT.footer.x, LAYOUT.footer.y))
	footer.set_size(Vector2(LAYOUT.footer.w, LAYOUT.footer.h))

	# エラーラベル（バリデーション表示用として残す）
	error_label = Label.new()
	error_label.text = ""
	error_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	error_label.set_position(Vector2(4, 0))
	footer.add_child(error_label)

	return footer

# 最低1枚配置チェック（NEXT_EI Q1「出撃」の押下可否判定に流用）
func _has_at_least_one_unit() -> bool:
	if not board_manager:
		return false
	# board_manager.board[0] の中に1枚でもユニットがあればOK
	for row in board_manager.board[0]:
		for unit in row:
			if unit != null:
				return true
	return false

# タブ切り替えハンドラ
func _on_tab_changed(tab: int) -> void:
	_tab_index = tab
	rebuild_hand_area()

# 手持ちカードエリア構築（Phase 2）
func build_hand_area() -> void:
	if not game_session:
		print("[RestScreenManager] GameSession未設定")
		return

	# デバッグログ追加
	print("[RestScreenManager] build_hand_area() tab=%d selected_deck=%s" % [_tab_index, game_session.selected_deck])

	# CardDBからユニットデータ取得（AutoLoadは直接参照可能）
	if not CardDB:
		print("[RestScreenManager] CardDB未取得")
		return

	# TabBarを追加（まだない場合のみ）
	if hand_area.get_parent() != null and not hand_area.get_parent().get_children().any(func(c): return c is TabBar):
		var tab_bar = TabBar.new()
		tab_bar.add_tab("ユニット")
		tab_bar.add_tab("呪文")
		tab_bar.add_tab("素材")
		tab_bar.current_tab = _tab_index
		tab_bar.tab_changed.connect(_on_tab_changed)
		# TabBarをScrollContainerの親(card_list_bar)に追加
		var scroll = hand_area.get_parent()
		var list_bar = scroll.get_parent()
		list_bar.add_child(tab_bar)
		tab_bar.set_position(Vector2(5, 25))
		tab_bar.set_size(Vector2(LAYOUT.card_list.w - 10, 24))
		# ScrollContainerをマナ表示の下にずらす（TabBar実高+マナ2行分）
		scroll.set_position(Vector2(5, 110))
		scroll.set_size(Vector2(LAYOUT.card_list.w - 10, LAYOUT.card_list.h - 115))

	# タブに応じてコンテンツを切り替え
	if _tab_index == 0:
		hand_area.columns = 3
		# ユニットタブ: 従来の手持ちカード表示
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
	elif _tab_index == 1:
		# 呪文タブ: 3列グリッドで入手済み呪文を表示
		hand_area.columns = 3
		if game_session.spell_available.is_empty():
			var no_spell_label = Label.new()
			no_spell_label.text = "入手済み呪文なし"
			no_spell_label.add_theme_font_size_override("font_size", 10)
			no_spell_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			hand_area.add_child(no_spell_label)
		else:
			# 同名カード重複ハイライト防止: デッキ内残枚数カウンター
			var deck_remain: Dictionary = {}
			for sn in game_session.spell_deck:
				deck_remain[sn] = deck_remain.get(sn, 0) + 1
			for spell_entry in game_session.spell_available:
				var spell_name: String = spell_entry.get("name", "") if spell_entry is Dictionary else str(spell_entry)
				var spell_data: Dictionary = CardDB.SPELLS.get(spell_name, {})
				var in_deck: bool = deck_remain.get(spell_name, 0) > 0
				if in_deck:
					deck_remain[spell_name] -= 1
				var spell_card = _create_spell_mini_card(spell_name, spell_data, in_deck)
				if in_deck:
					var hl_style = StyleBoxFlat.new()
					hl_style.bg_color = Color(0.10, 0.12, 0.22)
					hl_style.border_color = Color(1.0, 0.85, 0.1)
					hl_style.set_border_width_all(3)
					spell_card.add_theme_stylebox_override("panel", hl_style)
				var captured_name = spell_name
				spell_card.gui_input.connect(func(event: InputEvent):
					if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
						_on_spell_available_double_click(captured_name)
					elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
						var di: int = game_session.spell_deck.find(captured_name)
						if di >= 0:
							_on_spell_deck_right_click(di)
				)
				hand_area.add_child(spell_card)
		print("[RestScreenManager] 呪文タブ表示（3列）")

	else:
		# 素材タブ: 5列グリッドで素材アイコン表示
		hand_area.columns = 5
		var materials: Dictionary = GameSession.materials if GameSession else {}
		if materials.is_empty():
			var no_mat = Label.new()
			no_mat.text = "素材なし\n（敵を倒すと\n自動取得）"
			no_mat.add_theme_font_size_override("font_size", 10)
			no_mat.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			hand_area.add_child(no_mat)
		else:
			for mat_id in materials.keys():
				var mat_count: int = materials[mat_id]
				var mat_cell = _create_material_cell(mat_id, mat_count)
				hand_area.add_child(mat_cell)
		print("[RestScreenManager] 素材タブ表示")

# 呪文ミニカード作成（3列用）
func _create_spell_mini_card(spell_name: String, spell_data: Dictionary, in_deck: bool = false) -> Control:
	var card_panel = Panel.new()
	card_panel.set_custom_minimum_size(Vector2(CARD_MINI.w, CARD_MINI.h))

	var rarity: String = spell_data.get("rarity", "common")
	var style = StyleBoxFlat.new()
	match rarity:
		"uncommon": style.bg_color = Color(0.10, 0.12, 0.22)
		"rare":     style.bg_color = Color(0.08, 0.10, 0.28)
		"epic":     style.bg_color = Color(0.18, 0.08, 0.28)
		_:          style.bg_color = Color(0.12, 0.10, 0.22)
	style.border_color = Color(0.5, 0.4, 0.8)
	style.set_border_width_all(1)
	card_panel.add_theme_stylebox_override("panel", style)

	# 呪文名
	var name_lbl = Label.new()
	name_lbl.text = spell_name
	name_lbl.set_position(Vector2(2, 2))
	name_lbl.set_size(Vector2(56, 30))
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	card_panel.add_child(name_lbl)

	# 「呪文」タグ
	var type_lbl = Label.new()
	type_lbl.text = "呪文"
	type_lbl.set_position(Vector2(2, 34))
	type_lbl.add_theme_font_size_override("font_size", 8)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.5, 0.9))
	card_panel.add_child(type_lbl)

	# コスト
	var cost: int = spell_data.get("mana", spell_data.get("mana_cost", spell_data.get("cost", 0)))
	var cost_lbl = Label.new()
	cost_lbl.text = "コスト:%d" % cost
	cost_lbl.set_position(Vector2(2, 48))
	cost_lbl.add_theme_font_size_override("font_size", 8)
	cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	card_panel.add_child(cost_lbl)

	# デッキ内フラグ（呼び出し元から渡されたカウンター判定を使用）
	if in_deck:
		var in_deck_lbl = Label.new()
		in_deck_lbl.text = "★デッキ"
		in_deck_lbl.set_position(Vector2(2, 72))
		in_deck_lbl.add_theme_font_size_override("font_size", 8)
		in_deck_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		card_panel.add_child(in_deck_lbl)

	# クリック → 右詳細表示
	var cap_name = spell_name
	var cap_data = spell_data
	card_panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_show_spell_detail(cap_name, cap_data)
	)

	return card_panel

# 素材セル作成（5列グリッド用・正方形アイコン）
func _create_material_cell(mat_id: String, count: int) -> Control:
	var ICON_SIZE = 44
	var cell = Panel.new()
	cell.set_custom_minimum_size(Vector2(ICON_SIZE, ICON_SIZE))

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08)
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	cell.add_theme_stylebox_override("panel", style)

	# 素材名（短縮）
	var id_short: String = mat_id.substr(0, 6) if mat_id.length() > 6 else mat_id
	var name_lbl = Label.new()
	name_lbl.text = id_short
	name_lbl.set_position(Vector2(2, 4))
	name_lbl.set_size(Vector2(ICON_SIZE - 4, 20))
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	cell.add_child(name_lbl)

	# 個数
	var count_lbl = Label.new()
	count_lbl.text = "×%d" % count
	count_lbl.set_position(Vector2(2, 28))
	count_lbl.set_size(Vector2(ICON_SIZE - 4, 14))
	count_lbl.add_theme_font_size_override("font_size", 9)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	cell.add_child(count_lbl)

	# クリック → 右詳細表示
	var cap_id = mat_id
	var cap_count = count
	cell.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_show_material_detail(cap_id, cap_count)
	)

	return cell

# CardView作成（小カード表示）
func create_card_view(card_data_dict: Dictionary, card_name: String, index: int = -1) -> Control:
	var card_panel = Panel.new()
	card_panel.set_custom_minimum_size(Vector2(CARD_MINI.w, CARD_MINI.h))

	# レアリティ別背景・ボーダー色
	var rarity: String = card_data_dict.get("rarity", "common")
	var bg_color: Color
	var border_color: Color
	var border_width: int
	match rarity:
		"uncommon":
			bg_color = Color(0.10, 0.18, 0.10)
			border_color = Color(0.3, 0.6, 0.3)
			border_width = 2
		"rare":
			bg_color = Color(0.10, 0.12, 0.22)
			border_color = Color(0.3, 0.4, 0.8)
			border_width = 2
		"epic":
			bg_color = Color(0.18, 0.10, 0.22)
			border_color = Color(0.6, 0.3, 0.8)
			border_width = 2
		_:  # common or default
			bg_color = Color(0.15, 0.15, 0.20)
			border_color = Color(0.5, 0.5, 0.55)
			border_width = 1

	# 背景スタイル
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	card_panel.add_theme_stylebox_override("panel", style)

	# カード名 (y=2, font_size=9, w=56, autowrap)
	var name_label = Label.new()
	name_label.text = card_name
	name_label.set_position(Vector2(2, 2))
	name_label.set_size(Vector2(56, 28))
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_panel.add_child(name_label)

	# 種族2文字 (y=33, font_size=8)
	var race: String = card_data_dict.get("race", "")
	var race_short: String = race.substr(0, 2) if race.length() >= 2 else race
	var race_label = Label.new()
	race_label.text = race_short
	race_label.set_position(Vector2(2, 33))
	race_label.add_theme_font_size_override("font_size", 8)
	card_panel.add_child(race_label)

	# HP (y=48, font_size=9)
	var hp_label = Label.new()
	hp_label.text = "HP %d" % card_data_dict.get("hp", 0)
	hp_label.set_position(Vector2(2, 48))
	hp_label.add_theme_font_size_override("font_size", 9)
	card_panel.add_child(hp_label)

	# ATK (y=58, font_size=9)
	var atk_label = Label.new()
	atk_label.text = "ATK %d" % card_data_dict.get("atk", 0)
	atk_label.set_position(Vector2(2, 58))
	atk_label.add_theme_font_size_override("font_size", 9)
	card_panel.add_child(atk_label)

	# Mana (y=68, font_size=9, color=Color(0.4, 0.7, 1.0))
	var mana_label = Label.new()
	mana_label.text = "Mana %d" % card_data_dict.get("mana", 0)
	mana_label.set_position(Vector2(2, 68))
	mana_label.add_theme_font_size_override("font_size", 9)
	mana_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	card_panel.add_child(mana_label)

	# クリックイベント（要件定義書 §6.1.5）
	if index >= 0:
		card_panel.gui_input.connect(_on_hand_card_gui_input.bind(index))
		card_panel.set_drag_forwarding(
			_card_get_drag_data.bind(index),
			Callable(),
			Callable()
		)

	return card_panel

# 手持ちカードGUI入力処理
func _on_hand_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		on_hand_card_clicked(index)

# D&D: 手持ちカードドラッグデータ生成
func _card_get_drag_data(at_position: Vector2, index: int) -> Variant:
	if index < 0:
		return null
	if not game_session or index >= game_session.selected_deck.size():
		return null
	var card_data_ref = game_session.selected_deck[index]
	var card_name: String = card_data_ref.get("name", "") if card_data_ref is Dictionary else str(card_data_ref)
	var card_data_dict: Dictionary = CardDB.UNITS.get(card_name, {})
	var preview = create_card_view(card_data_dict, card_name, -1)
	set_drag_preview(preview)
	return {"card_index": index}

# D&D: 盤面セルへのドロップ可否判定
func _cell_can_drop_data(at_position: Vector2, data: Variant, _row: int, _col: int) -> bool:
	return data is Dictionary and (data.has("card_index") or data.has("board_row"))

# D&D: 盤面セルへのドロップ処理
func _cell_drop_data(at_position: Vector2, data: Variant, row: int, col: int) -> void:
	if not (data is Dictionary and data.has("card_index")):
		return
	_selected_hand_index = data["card_index"]
	on_board_cell_clicked(row, col)

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

		var _edb = load("res://scripts/EffectDB.gd")
		var TRIGGER_NAMES: Dictionary = {
			"on_hit": "命中時",
			"on_kill": "撃破時",
			"on_summon": "召喚時",
			"on_death": "撃破された時",
			"on_play": "使用時",
			"on_hp_threshold": "HP閾値",
			"always": "常時",
			"timer": "定期",
			"on_front_attack": "前列攻撃時",
			"on_support": "サポート時",
		}
		for skill in skills:
			if skill is Dictionary:
				var trigger = skill.get("trigger", "")
				var effect_id = skill.get("effect_id", "")
				var trigger_disp = TRIGGER_NAMES.get(trigger, trigger)
				var edef = _edb.EFFECTS.get(effect_id, {})
				var effect_disp = edef.get("display", effect_id)
				var skill_text = "%s: %s" % [trigger_disp, effect_disp]
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

# 呪文詳細表示
func _show_spell_detail(spell_name: String, spell_data: Dictionary) -> void:
	_clear_card_detail()
	var cost: int = spell_data.get("mana", spell_data.get("mana_cost", spell_data.get("cost", 0)))

	var _add = func(text: String, size: int = 12, color: Color = Color(0.85, 0.85, 0.9)) -> void:
		var lbl = Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", size)
		lbl.add_theme_color_override("font_color", color)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_detail_container.add_child(lbl)

	_add.call(spell_name, 16, Color(0.85, 0.7, 1.0))
	_add.call("呪文", 11, Color(0.6, 0.5, 0.9))
	_add.call("マナコスト: %d" % cost, 12, Color(0.4, 0.7, 1.0))
	var target = spell_data.get("target", spell_data.get("spell_target", ""))
	if target != "":
		_add.call("対象: %s" % target, 11, Color(0.7, 0.7, 0.8))
	var effect = spell_data.get("effect", spell_data.get("spell_effect", ""))
	if effect != "":
		_add.call("\n効果:\n%s" % effect, 11, Color(0.75, 0.9, 0.75))
	var rarity = spell_data.get("rarity", "common")
	_add.call("レアリティ: %s" % rarity, 10, Color(0.6, 0.6, 0.7))

# 素材詳細表示
func _show_material_detail(mat_id: String, count: int) -> void:
	_clear_card_detail()
	var mat_data: Dictionary = {}
	for m in CardDB.MATERIALS:
		if m.get("id", m.get("name", "")) == mat_id:
			mat_data = m
			break

	var _add = func(text: String, size: int = 12, color: Color = Color(0.85, 0.85, 0.9)) -> void:
		var lbl = Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", size)
		lbl.add_theme_color_override("font_color", color)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_detail_container.add_child(lbl)

	_add.call(mat_id, 16, Color(0.9, 0.8, 0.6))
	_add.call("素材", 11, Color(0.7, 0.6, 0.4))
	_add.call("所持数: %d" % count, 12, Color(1.0, 0.9, 0.5))
	if not mat_data.is_empty():
		var desc = mat_data.get("description", mat_data.get("desc", ""))
		if desc != "":
			_add.call("\n%s" % desc, 11, Color(0.75, 0.85, 0.75))

# 右側カード詳細クリア
func _clear_card_detail() -> void:
	if not card_detail_container:
		return
	for child in card_detail_container.get_children():
		child.queue_free()

func _on_shop_item_detail_requested(item: Dictionary) -> void:
	var item_name: String = item.get("name", "")
	var item_type: String = item.get("type", "unit")
	if item_type == "spell":
		var spell_data: Dictionary = CardDB.SPELLS.get(item_name, {})
		_show_spell_detail(item_name, spell_data)
	else:
		var card_data: Dictionary = CardDB.UNITS.get(item_name, {})
		_show_card_detail(item_name, card_data)

func _on_ready_to_battle() -> void:
	rest_screen_closed.emit()
	cleanup()

# バトル終了後にSCRATCHフェーズへ切り替える（外部から呼び出し）
func trigger_scratch_phase() -> void:
	if _enemy_panel:
		_enemy_panel.set_phase(EnemyPanelManager.EnemyPanelPhase.SCRATCH)

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
			# キャプチャ変数でクロージャにrow/colを保持
			var r_cap = row
			var c_cap = col
			cell_btn.set_drag_forwarding(
				func(pos): return _board_cell_get_drag_data(pos, r_cap, c_cap),
				func(pos, data): return _board_cell_can_drop(pos, data, r_cap, c_cap),
				func(pos, data): _board_cell_drop(pos, data, r_cap, c_cap)
			)
			ui_root.add_child(cell_btn)


# ホバー開始ハンドラ
func _on_card_hover_enter(card_name: String, source: String) -> void:
	if not CardDB.UNITS.has(card_name):
		return

	rest_state.hover_source = source
	rest_state.hover_card_name = card_name
	rest_state.selected_card = CardDB.UNITS[card_name]
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
	if _enemy_panel:
		_enemy_panel.queue_free()
		_enemy_panel = null
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
		# 盤面セル描画を更新
		var main = get_node_or_null("/root/Main")
		if main and main.get("game_ui") != null:
			main.game_ui.render_cell(0, row, col)
		# 配置成功→selected_deckから削除
		game_session.selected_deck.remove_at(_selected_hand_index)
		_selected_hand_index = -1
		rebuild_hand_area()
		_show_card_detail_guide()
		_show_validation_error("")
		_refresh_mana_labels()
	else:
		_show_validation_error("配置に失敗しました")

# 手持ちカードエリア再構築（要件定義書 §6.1.5）
func rebuild_hand_area() -> void:
	for child in hand_area.get_children():
		child.queue_free()
	build_hand_area()

# ---- 盤面D&D（REQ-2a: 盤面→盤面入れ替え） ----

func _board_cell_get_drag_data(at_position: Vector2, row: int, col: int) -> Variant:
	if not board_manager:
		return null
	var cell_data = board_manager.board[0][row][col]
	if cell_data == null:
		return null
	# カード名取得: cell_data が UnitData(unit_name属性あり) なら unit_name、Dictionary なら ["name"]
	var card_name: String
	var card_data_dict: Dictionary
	if cell_data is Dictionary:
		card_name = cell_data.get("name", "")
		card_data_dict = CardDB.UNITS.get(card_name, {})
	else:
		card_name = cell_data.unit_name if cell_data.get("unit_name") != null else str(cell_data)
		card_data_dict = CardDB.UNITS.get(card_name, {})
	var preview = create_card_view(card_data_dict, card_name, -1)
	set_drag_preview(preview)
	return {"board_row": row, "board_col": col, "card_data": cell_data}

func _board_cell_can_drop(at_position: Vector2, data: Variant, row: int, col: int) -> bool:
	if not (data is Dictionary):
		return false
	# 盤面→盤面スワップは常に許可
	if data.has("board_row"):
		return true
	# 手持ち→盤面は空きマスのみ許可（上書き防止）
	if data.has("card_index"):
		if board_manager and board_manager.board[0][row][col] != null:
			return false
		return true
	return false

func _board_cell_drop(at_position: Vector2, data: Variant, row: int, col: int) -> void:
	if not (data is Dictionary):
		return
	if data.has("card_index"):
		# 手持ち→盤面（既存ロジック）
		_selected_hand_index = data["card_index"]
		on_board_cell_clicked(row, col)
	elif data.has("board_row"):
		# 盤面→盤面（入れ替え）
		var from_r: int = data["board_row"]
		var from_c: int = data["board_col"]
		if from_r == row and from_c == col:
			return
		board_manager.swap_rest_cells(from_r, from_c, row, col)
		# 両セルを再描画
		var main = get_node_or_null("/root/Main")
		if main and main.get("game_ui") != null:
			main.game_ui.render_cell(0, from_r, from_c)
			main.game_ui.render_cell(0, row, col)
		_refresh_mana_labels()

# ---- 盤面D&D（REQ-2b: 盤面→手持ち戻し） ----

func _hand_area_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("board_row")

func _hand_area_drop_data(at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary and data.has("board_row")):
		return
	var row: int = data["board_row"]
	var col: int = data["board_col"]
	# 削除前にカード名を取得
	var removed_unit = board_manager.board[0][row][col]
	var card_name: String = removed_unit.unit_name if removed_unit != null else ""
	# 盤面から削除
	board_manager.remove_rest_unit(row, col)
	# selected_deckに戻す
	if card_name != "" and game_session:
		game_session.selected_deck.append({"name": card_name})
	# 盤面セルを再描画
	var main = get_node_or_null("/root/Main")
	if main and main.get("game_ui") != null:
		main.game_ui.render_cell(0, row, col)
	rebuild_hand_area()
	_refresh_mana_labels()

# ---- マナ総量表示（REQ-5） ----

func _refresh_mana_labels() -> void:
	if not game_session:
		return

	# 盤面Mana: initial_units の各要素（非null）の mana 合計
	var unit_mana: int = 0
	for entry in game_session.initial_units:
		if entry == null:
			continue
		var unit_name: String = ""
		if entry is Dictionary:
			unit_name = entry.get("name", "")
		if unit_name != "" and CardDB.UNITS.has(unit_name):
			unit_mana += CardDB.UNITS[unit_name].get("mana", 0)

	# 呪文Mana: spell_deck の各呪文マナ合計（REQ-6d）
	var spell_mana: int = _calc_spell_deck_mana()

	if _mana_label_unit:
		_mana_label_unit.text = "⚡ 盤面マナ: %d" % unit_mana
	if _mana_label_spell:
		_mana_label_spell.text = "✨ 呪文マナ合計: %d" % spell_mana

# ---- 呪文デッキ編成（REQ-6c） ----

func _calc_board_mana() -> int:
	var total: int = 0
	for unit_entry in game_session.initial_units:
		if unit_entry == null:
			continue
		var unit_name: String = unit_entry.get("name", "")
		if unit_name != "" and CardDB.UNITS.has(unit_name):
			total += CardDB.UNITS[unit_name].get("mana", 0)
	return total

func _calc_spell_deck_mana() -> int:
	var total: int = 0
	if not game_session:
		return total
	for spell_name in game_session.spell_deck:
		if CardDB.SPELLS.has(spell_name):
			total += CardDB.SPELLS[spell_name].get("mana", 0)
	return total

func _on_spell_available_double_click(spell_name: String) -> void:
	var spell_mana: int = 0
	if CardDB.SPELLS.has(spell_name):
		spell_mana = CardDB.SPELLS[spell_name].get("mana", 0)
	var board_mana: int = _calc_board_mana()
	var current_spell_mana: int = _calc_spell_deck_mana()
	if current_spell_mana + spell_mana > board_mana:
		_show_spell_mana_error()
		return
	game_session.spell_deck.append(spell_name)
	rebuild_hand_area()
	_refresh_mana_labels()

func _on_spell_deck_right_click(index: int) -> void:
	if index < 0 or index >= game_session.spell_deck.size():
		return
	game_session.spell_deck.remove_at(index)
	rebuild_hand_area()
	_refresh_mana_labels()

func _show_spell_mana_error() -> void:
	if error_label:
		error_label.text = "マナ不足: 呪文Manaが盤面Manaを超えます"
		error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		get_tree().create_timer(2.0).timeout.connect(func():
			if error_label:
				error_label.text = ""
		)
