# EnemyPanelManager.gd
# 敵盤面パネルの3フェーズ管理（NEXT_EI / SCRATCH / SHOP）
class_name EnemyPanelManager
extends Control

enum EnemyPanelPhase { NEXT_EI, SCRATCH, SHOP }

signal phase_changed(phase: EnemyPanelPhase)
signal scratch_completed(card_data: Dictionary)
signal shop_completed()
signal ready_to_battle()
# Qスロット連動シグナル（疎結合: EnemyPanelManagerはSpellSlotSystemを知らない）
signal phase_actions_ready(actions: Array)
signal action_execute_requested(action_id: String, params: Dictionary)

var _phase: EnemyPanelPhase = EnemyPanelPhase.NEXT_EI
var _current_container: Control = null
var _scratch_rewards: Array = []  # 9件の報酬カードデータ
var _show_ready_button: bool = true

# 外部参照（RestScreenManagerからセット）
var wave_manager: Node = null
var game_session: Node = null
var card_db: Node = null

# 盤面セルと同じ座標・サイズを使用
const BOARD_X: float = 650.0
const BOARD_Y: float = 88.0
const CELL_W: float = 130.0
const CELL_H: float = 95.0
const COLS: int = 3
const ROWS: int = 3

func set_phase(phase: EnemyPanelPhase, _context: Dictionary = {}) -> void:
	# コンテキスト読み取り
	_show_ready_button = _context.get("show_ready_button", true)
	# 前フェーズUIを破棄
	if _current_container != null:
		_current_container.queue_free()
		_current_container = null

	# 新しいコンテナを作成
	_current_container = Control.new()
	_current_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_current_container)

	# フェーズに応じてUI構築・フェーズ開始時の状態リセット
	var session = game_session if game_session != null else GameSession
	match phase:
		EnemyPanelPhase.NEXT_EI:
			# NEXT_EI 開始時: 偵察カウントをリセット
			session.scout_use_count = 0
			_build_next_ei_ui()
		EnemyPanelPhase.SCRATCH:
			# SCRATCH 開始時: スクラッチアクション状態をリセット
			session.scratch_peeked = []
			session.scratch_sacrificed_index = -1
			session.scratch_action_used = ""
			_build_scratch_ui()
		EnemyPanelPhase.SHOP:
			_build_shop_ui()

	_phase = phase
	phase_changed.emit(phase)
	print("[EnemyPanelManager] フェーズ変更: %s" % EnemyPanelPhase.keys()[phase])

	# Qスロットにフェーズアクションを通知（疎結合: シグナル経由）
	var actions: Array = _build_phase_actions(phase)
	phase_actions_ready.emit(actions)

# ---- NEXT_EIフェーズ ----

func _build_next_ei_ui() -> void:
	var layout = _get_next_enemy_layout()
	for row in range(ROWS):
		for col in range(COLS):
			var cell = _create_ei_cell(layout[row][col], row, col)
			_current_container.add_child(cell)
	# REQ-QPA-07: 準備完了ボタン廃止（Qスロット「出撃」に移行）

func _create_ei_cell(has_enemy: bool, row: int, col: int) -> Control:
	var cell = Panel.new()
	cell.set_position(Vector2(BOARD_X + col * CELL_W, BOARD_Y + row * CELL_H))
	cell.set_size(Vector2(CELL_W, CELL_H))

	var style = StyleBoxFlat.new()
	if has_enemy:
		style.bg_color = Color(0.12, 0.12, 0.18)
		style.border_color = Color(0.3, 0.3, 0.4)
	else:
		style.bg_color = Color(0.08, 0.08, 0.1)
		style.border_color = Color(0.2, 0.2, 0.25)
	style.set_border_width_all(1)
	cell.add_theme_stylebox_override("panel", style)

	return cell

func _get_next_enemy_layout() -> Array:
	# wave_manager が null または情報取得不可の場合: 全false配列を返す
	if wave_manager == null:
		return _make_empty_layout()
	# フォールバック: 全シルエット非表示
	return _make_empty_layout()

func _make_empty_layout() -> Array:
	var layout: Array = []
	for _r in range(ROWS):
		var row_arr: Array = []
		for _c in range(COLS):
			row_arr.append(false)
		layout.append(row_arr)
	return layout

# ---- SCRATCHフェーズ ----

func _build_scratch_ui() -> void:
	_scratch_rewards = _generate_rewards(9)
	var active_index: int = randi() % 9

	for i in range(9):
		var row: int = i / COLS
		var col: int = i % COLS
		var card_data: Dictionary = _scratch_rewards[i]
		var cell = _create_scratch_cell(card_data, i == active_index)
		cell.set_position(Vector2(BOARD_X + col * CELL_W, BOARD_Y + row * CELL_H))
		_current_container.add_child(cell)

func _create_scratch_cell(card_data: Dictionary, is_active: bool) -> Panel:
	var cell = Panel.new()
	cell.set_size(Vector2(CELL_W, CELL_H))

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(1)
	cell.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "???"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	cell.add_child(label)

	if is_active:
		var captured_data = card_data
		cell.gui_input.connect(func(event: InputEvent):
			_on_scratch_input(event, captured_data, cell)
		)
	else:
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return cell

func _on_scratch_input(event: InputEvent, card_data: Dictionary, cell: Panel) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_scratch_selected(card_data, cell)

func _on_scratch_selected(card_data: Dictionary, cell: Panel) -> void:
	# セルにカード名・種別を表示
	for child in cell.get_children():
		child.queue_free()

	var rarity: String = card_data.get("rarity", "common")
	var style = StyleBoxFlat.new()
	style.bg_color = _get_rarity_color(rarity)
	style.border_color = Color(0.6, 0.6, 0.7)
	style.set_border_width_all(2)
	cell.add_theme_stylebox_override("panel", style)

	var name_label = Label.new()
	name_label.text = card_data.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	cell.add_child(name_label)

	var type_label = Label.new()
	type_label.text = card_data.get("type", "unit")
	type_label.set_position(Vector2(5, CELL_H - 18))
	type_label.set_size(Vector2(CELL_W - 10, 16))
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	cell.add_child(type_label)

	# 他セルを無効化（念のため）
	if _current_container:
		for other_cell in _current_container.get_children():
			other_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# カードをgame_sessionに追加
	if game_session:
		var card_type: String = card_data.get("type", "unit")
		var card_name: String = card_data.get("name", "")
		if card_type == "unit":
			game_session.selected_deck.append({"name": card_name})
			print("[EnemyPanelManager] ユニット獲得: %s" % card_name)
		elif card_type == "spell":
			game_session.spell_available.append({"name": card_name})
			print("[EnemyPanelManager] 呪文獲得: %s" % card_name)

	scratch_completed.emit(card_data)

	# 0.5秒後にSHOPフェーズへ
	get_tree().create_timer(0.5).timeout.connect(func():
		set_phase(EnemyPanelPhase.SHOP)
	)

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.10, 0.22, 0.10)
		"rare":
			return Color(0.10, 0.12, 0.28)
		"epic":
			return Color(0.22, 0.10, 0.28)
		_:
			return Color(0.18, 0.18, 0.22)

func _generate_rewards(count: int) -> Array:
	var result: Array = []
	var db = card_db if card_db != null else CardDB

	var unit_keys: Array = db.UNITS.keys()
	if unit_keys.is_empty():
		for _i in range(count):
			result.append({"name": "不明", "type": "unit", "rarity": "common"})
		return result

	var has_spells: bool = not db.SPELLS.is_empty()
	var spell_keys: Array = db.SPELLS.keys() if has_spells else []

	for _i in range(count):
		var is_spell: bool = has_spells and (randi() % 2 == 0)
		if is_spell:
			var spell_name: String = spell_keys[randi() % spell_keys.size()]
			var spell_data: Dictionary = db.SPELLS[spell_name]
			result.append({
				"name": spell_name,
				"type": "spell",
				"rarity": spell_data.get("rarity", "common")
			})
		else:
			var unit_name: String = unit_keys[randi() % unit_keys.size()]
			var unit_data: Dictionary = db.UNITS[unit_name]
			result.append({
				"name": unit_name,
				"type": "unit",
				"rarity": unit_data.get("rarity", "common")
			})

	return result

# ---- SHOPフェーズ ----

func _build_shop_ui() -> void:
	"""敵陣9マスをショップに転用（ユニット3+呪文3+空3）"""
	var session = game_session if game_session != null else GameSession
	# REQ-QPA-04: ショップ開始時に shop_reroll_count / shop_negotiated をリセット
	session.shop_reroll_count = 0
	session.shop_negotiated = false
	var shop_items: Array = _generate_shop_items(9)

	for i in range(9):
		var row: int = i / COLS
		var col: int = i % COLS
		var item: Dictionary = shop_items[i] if i < shop_items.size() else {}
		var cell = _create_shop_cell(item, session)
		cell.set_position(Vector2(BOARD_X + col * CELL_W, BOARD_Y + row * CELL_H))
		_current_container.add_child(cell)
	# REQ-QPA-07: 準備完了ボタン廃止（Qスロット「退店」に移行）

func _generate_shop_items(count: int) -> Array:
	var result: Array = []
	var db = card_db if card_db != null else CardDB

	# ユニット5枠 + 呪文4枠
	var unit_keys: Array = db.UNITS.keys()
	var spell_keys: Array = db.SPELLS.keys()

	for i in range(count):
		var is_spell: bool = (i >= 5)  # 後半4枠を呪文
		if is_spell and not spell_keys.is_empty():
			var spell_name: String = spell_keys[randi() % spell_keys.size()]
			var spell_data: Dictionary = db.SPELLS[spell_name]
			result.append({
				"name": spell_name,
				"type": "spell",
				"rarity": spell_data.get("rarity", "common"),
				"price": _calc_price(spell_data),
				"sold": false
			})
		elif not unit_keys.is_empty():
			var unit_name: String = unit_keys[randi() % unit_keys.size()]
			var unit_data: Dictionary = db.UNITS[unit_name]
			result.append({
				"name": unit_name,
				"type": "unit",
				"rarity": unit_data.get("rarity", "common"),
				"price": _calc_price(unit_data),
				"sold": false
			})
		else:
			result.append({})

	return result

func _calc_price(card_data: Dictionary) -> int:
	match card_data.get("rarity", "common"):
		"uncommon": return 100
		"rare":     return 200
		"epic":     return 400
	return 50

func _create_shop_cell(item: Dictionary, session) -> Panel:
	var cell = Panel.new()
	cell.set_size(Vector2(CELL_W, CELL_H))

	var is_empty: bool = item.is_empty()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.15) if not is_empty else Color(0.07, 0.07, 0.10)
	style.border_color = Color(0.35, 0.35, 0.5) if not is_empty else Color(0.2, 0.2, 0.25)
	style.set_border_width_all(1)
	cell.add_theme_stylebox_override("panel", style)

	if is_empty:
		return cell

	# 種別ラベル
	var type_lbl = Label.new()
	type_lbl.text = "ユニット" if item.get("type", "") == "unit" else "呪文"
	type_lbl.set_position(Vector2(4, 4))
	type_lbl.add_theme_font_size_override("font_size", 9)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	cell.add_child(type_lbl)

	# カード名
	var name_lbl = Label.new()
	name_lbl.text = item.get("name", "???")
	name_lbl.set_position(Vector2(4, 18))
	name_lbl.set_size(Vector2(CELL_W - 8, 36))
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	cell.add_child(name_lbl)

	# 価格
	var price_lbl = Label.new()
	price_lbl.text = "%dG" % item.get("price", 0)
	price_lbl.set_position(Vector2(4, CELL_H - 22))
	price_lbl.set_size(Vector2(CELL_W - 8, 18))
	price_lbl.add_theme_font_size_override("font_size", 12)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	cell.add_child(price_lbl)

	# クリックで購入
	var captured_item = item
	var captured_cell = cell
	cell.gui_input.connect(func(event: InputEvent):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		if captured_item.get("sold", false):
			return
		var price: int = captured_item.get("price", 0)
		var gold: int = session.gold if session else 0
		if gold < price:
			return
		# 購入処理
		session.gold -= price
		captured_item["sold"] = true
		var card_type: String = captured_item.get("type", "unit")
		var card_name: String = captured_item.get("name", "")
		if card_type == "unit":
			session.selected_deck.append({"name": card_name})
		elif card_type == "spell":
			session.spell_available.append({"name": card_name})
		print("[EnemyPanelManager] ショップ購入: %s (%s) -%dG" % [card_name, card_type, price])
		# セルを売り切れ表示に
		for child in captured_cell.get_children():
			child.modulate = Color(0.4, 0.4, 0.4)
		var sold_lbl = Label.new()
		sold_lbl.text = "売り切れ"
		sold_lbl.set_position(Vector2(4, 55))
		sold_lbl.add_theme_font_size_override("font_size", 10)
		sold_lbl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
		captured_cell.add_child(sold_lbl)
		shop_completed.emit()
	)

	return cell

func _on_shop_purchase_completed(_card_id: String, _new_gold: int) -> void:
	print("[EnemyPanelManager] ショップ購入完了: %s" % _card_id)

# ---- Qスロット連動（REQ-QPA-10 疎結合設計） ----

func _build_phase_actions(phase: EnemyPanelPhase) -> Array:
	"""フェーズ別アクション定義を組み立てて返す（PhaseActionDefsに委譲）"""
	var session = game_session if game_session != null else GameSession
	var actions: Array = []
	var phase_name: String = ""
	match phase:
		EnemyPanelPhase.SCRATCH:
			phase_name = "SCRATCH"
			actions = PhaseActionDefs.build_scratch(
				session.gold,
				session.scratch_action_used
			)
		EnemyPanelPhase.SHOP:
			phase_name = "SHOP"
			actions = PhaseActionDefs.build_shop(
				session.gold,
				session.shop_reroll_count,
				session.shop_negotiated
			)
		EnemyPanelPhase.NEXT_EI:
			phase_name = "NEXT_EI"
			var act: int = session.current_act if session.get("current_act") != null else 1
			actions = PhaseActionDefs.build_next_ei(
				session.gold,
				act,
				session.scout_use_count
			)
	# phase_name フィールドを全アクションに付加（SpellSlotSystem.current_phase_name 設定用）
	if not actions.is_empty():
		actions[0]["phase_name"] = phase_name
	return actions

func execute_action(action_id: String, _params: Dictionary = {}) -> void:
	"""Main.gdのワイヤリングから呼ばれるアクション実行ハンドラ"""
	print("[EnemyPanelManager] execute_action: %s" % action_id)
	match action_id:
		"scratch_confirm":  _execute_scratch_confirm()
		"scratch_peek":     _execute_scratch_peek()
		"scratch_greed":    _execute_scratch_greed()
		"shop_leave":       set_phase(EnemyPanelPhase.NEXT_EI)
		"shop_reroll":      _execute_shop_reroll()
		"shop_negotiate":   _execute_shop_negotiate()
		"next_ei_launch":   ready_to_battle.emit()
		"next_ei_scout":    _execute_next_ei_scout()

func _execute_scratch_confirm() -> void:
	"""SCRATCH Q1: 確定（既存の_on_scratch_selected経路に委譲）"""
	# アクティブセルは_build_scratch_ui内で選択済み→現状はSCRATCH画面内部で完結
	# 既存フロー: SCRATCHセルをクリック → _on_scratch_selected → SHOPへ遷移
	# Q1「確定」はアクティブセルがある場合にSHOPフェーズへ即遷移
	print("[EnemyPanelManager] SCRATCH確定（Q1）")
	set_phase(EnemyPanelPhase.SHOP)

func _execute_scratch_peek() -> void:
	"""SCRATCH Q2: 覗き見"""
	var session = game_session if game_session != null else GameSession
	if session.gold < PhaseActionConfig.PEEK_COST:
		print("[EnemyPanelManager] 覗き見: 金不足")
		return
	session.gold -= PhaseActionConfig.PEEK_COST
	session.scratch_action_used = "peek"
	print("[EnemyPanelManager] SCRATCH覗き見: -%dG" % PhaseActionConfig.PEEK_COST)
	# Qスロット表示を更新（コスト消費後にenabledが変わる可能性があるため再emit）
	var actions: Array = _build_phase_actions(EnemyPanelPhase.SCRATCH)
	phase_actions_ready.emit(actions)

func _execute_scratch_greed() -> void:
	"""SCRATCH Q3: 強欲（1マス犠牲→2マス取得）"""
	var session = game_session if game_session != null else GameSession
	if session.scratch_action_used != "":
		print("[EnemyPanelManager] 強欲: 既にアクション使用済み")
		return
	session.scratch_action_used = "greed"
	session.scratch_sacrificed_index = -1  # 犠牲マス選択待ち
	print("[EnemyPanelManager] SCRATCH強欲: 犠牲マス選択モード")
	# アクション更新
	var actions: Array = _build_phase_actions(EnemyPanelPhase.SCRATCH)
	phase_actions_ready.emit(actions)

func _execute_shop_reroll() -> void:
	"""SHOP Q2: リロール"""
	var session = game_session if game_session != null else GameSession
	var cost: int = PhaseActionConfig.get_reroll_cost(session.shop_reroll_count)
	if session.gold < cost:
		print("[EnemyPanelManager] リロール: 金不足")
		return
	if cost > 0:
		session.gold -= cost
	session.shop_reroll_count += 1
	print("[EnemyPanelManager] ショップリロール #%d: -%dG" % [session.shop_reroll_count, cost])
	# ショップ商品を再生成（_current_container 再構築）
	_rebuild_shop_items()
	# Qスロット更新（リロールコスト変化のため）
	var actions: Array = _build_phase_actions(EnemyPanelPhase.SHOP)
	phase_actions_ready.emit(actions)

func _rebuild_shop_items() -> void:
	"""ショップ商品を再生成して表示更新（リロール用）"""
	var session = game_session if game_session != null else GameSession
	# 既存セルをすべて削除してショップを再構築
	if _current_container:
		for child in _current_container.get_children():
			child.queue_free()
	var shop_items: Array = _generate_shop_items(9)
	for i in range(9):
		var row: int = i / COLS
		var col: int = i % COLS
		var item: Dictionary = shop_items[i] if i < shop_items.size() else {}
		var cell = _create_shop_cell(item, session)
		cell.set_position(Vector2(BOARD_X + col * CELL_W, BOARD_Y + row * CELL_H))
		_current_container.add_child(cell)

func _execute_shop_negotiate() -> void:
	"""SHOP Q3: 交渉（成功60%: 値引き / 失敗: 即退店+ペナルティ）"""
	var session = game_session if game_session != null else GameSession
	if session.shop_negotiated:
		print("[EnemyPanelManager] 交渉: 既に交渉済み")
		return
	session.shop_negotiated = true
	var success: bool = randf() < PhaseActionConfig.NEGOTIATE_SUCCESS_RATE
	print("[EnemyPanelManager] 交渉結果: %s" % ("成功" if success else "失敗"))
	if success:
		# 全商品の価格を -30% に更新（表示セルを再構築）
		_apply_negotiate_discount()
	else:
		# 失敗: レア度ペナルティフラグを立てて即退店
		session.next_shop_rarity_penalty = true
		set_phase(EnemyPanelPhase.NEXT_EI)

func _apply_negotiate_discount() -> void:
	"""交渉成功: ショップ内の全商品価格を 0.7 倍に更新"""
	# _current_container 内の price_lbl を探して更新するより、
	# ショップを再生成する方がシンプル（価格は _create_shop_cell が参照するため）
	# 代わりに既存セルのラベルを直接更新
	if _current_container == null:
		return
	for cell in _current_container.get_children():
		# セルの子ラベルを走査して "G" を含む価格ラベルを特定して更新
		for child in cell.get_children():
			if child is Label and child.text.ends_with("G") and not child.text.contains("売"):
				var text: String = child.text
				var price_str: String = text.trim_suffix("G")
				if price_str.is_valid_int():
					var old_price: int = int(price_str)
					var new_price: int = int(old_price * (1.0 - PhaseActionConfig.NEGOTIATE_DISCOUNT))
					child.text = "%dG" % new_price
					child.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))  # 値引き表示: 緑
	print("[EnemyPanelManager] 交渉成功: 全商品 -%.0f%%" % (PhaseActionConfig.NEGOTIATE_DISCOUNT * 100))
	# Qスロット更新（交渉済みフラグが立ったため）
	var actions: Array = _build_phase_actions(EnemyPanelPhase.SHOP)
	phase_actions_ready.emit(actions)

func _execute_next_ei_scout() -> void:
	"""NEXT_EI Q2: 偵察"""
	var session = game_session if game_session != null else GameSession
	var act: int = session.current_act if session.get("current_act") != null else 1
	var cost: int = PhaseActionConfig.get_scout_cost(act, session.scout_use_count)
	if session.gold < cost:
		print("[EnemyPanelManager] 偵察: 金不足")
		return
	session.gold -= cost
	session.scout_use_count += 1
	print("[EnemyPanelManager] 偵察実行: -%dG (合計%d回)" % [cost, session.scout_use_count])
	# Qスロット更新（偵察コスト変化のため）
	var actions: Array = _build_phase_actions(EnemyPanelPhase.NEXT_EI)
	phase_actions_ready.emit(actions)
