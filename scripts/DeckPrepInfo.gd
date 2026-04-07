# DeckPrepInfo.gd
# DeckPrep画面の情報レーン（カード詳細/合成表示/ホバーポップアップ）専門
# DeckPrep.gdから責務分離
extends RefCounted

const UIF = preload("res://scripts/UIFactory.gd")

const RACE_COLORS = {
	"スライム": Color(0.3, 0.6, 0.3),
	"獣": Color(0.6, 0.4, 0.2),
	"アンデッド": Color(0.5, 0.3, 0.6),
}
const SPELL_COLOR = Color(0.3, 0.4, 0.6)
const DEFAULT_COLOR = Color(0.3, 0.3, 0.4)

var _main_node: Control = null  # DeckPrepインスタンス参照
var _info_container: Control = null  # 右側合成レーン
var _info_w: int = 275
var _PL = null
var _hover_popup: Control = null
var _skip_synth_confirm: bool = false  # 合成確認ダイアログのスキップ状態

# 黄金比定数
const GOLDEN_RATIO: float = 1.618
# 詳細カード枠サイズ（縦長黄金比）
const CARD_FRAME_W: int = 260
const CARD_FRAME_H: int = 420  # 260 × 1.615 ≒ 420
# ミニカードアイコンサイズ（黄金比）
const MINI_CARD_W: int = 60
const MINI_CARD_H: int = 97  # 60 × 1.618 ≒ 97

# カード詳細用コンテナ（盤面左下）
var _detail_container: Control = null
var _detail_w: int = 130

func setup(main_node: Control, info_container: Control, info_w: int, pl) -> void:
	_main_node = main_node
	_info_container = info_container
	_info_w = info_w
	_PL = pl

# ===== 解説レーンのクリア（背景・枠線2個を保持） =====

func clear_info() -> void:
	var children = _info_container.get_children()
	for i in range(children.size() - 1, 1, -1):
		children[i].queue_free()

# ===== 空表示 =====

func show_empty() -> void:
	clear_info()
	var hint = Label.new()
	hint.text = "カードを選択すると\n詳細が表示されます"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(10, 250)
	hint.size = Vector2(_info_w - 20, 60)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UIF.DIM_COLOR)
	_info_container.add_child(hint)

# ===== 右側合成レーン専用パネル構築 =====

func build_synthesis_right_panel() -> void:
	# 右側レーンに合成可能エリアを描画
	var children = _info_container.get_children()
	# 背景・枠線(index 0,1)は残す
	for i in range(children.size() - 1, 1, -1):
		children[i].queue_free()

	var header = Label.new()
	header.text = "合成可能"
	header.position = Vector2(10, 10)
	header.size = Vector2(_info_w - 20, 22)
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	_info_container.add_child(header)

	var sep = ColorRect.new()
	sep.position = Vector2(10, 34)
	sep.size = Vector2(_info_w - 20, 1)
	sep.color = Color(0.25, 0.28, 0.35, 0.8)
	_info_container.add_child(sep)

	# カード数カウント
	var card_counts: Dictionary = {}
	for entry in GameSession.selected_deck:
		var name = entry.get("name", "") if entry is Dictionary else str(entry)
		card_counts[name] = card_counts.get(name, 0) + 1

	var y: float = 42.0
	var found = false

	for recipe in CardDB.SYNTHESIS:
		var base = recipe.get("base", "")
		var card = recipe.get("card", "")
		var result_name = recipe.get("result", "")

		var needed: Dictionary = {}
		needed[base] = needed.get(base, 0) + 1
		needed[card] = needed.get(card, 0) + 1
		var can_craft = true
		for n in needed:
			if card_counts.get(n, 0) < needed[n]:
				can_craft = false
				break

		# 結果カードをミニタイルで表示
		var tile_w = _info_w - 20
		var tile_h = 60
		var tile = Panel.new()
		tile.position = Vector2(10, y)
		tile.size = Vector2(tile_w, tile_h)
		var result_color = _get_card_accent_color(result_name)
		var tile_style = StyleBoxFlat.new()
		tile_style.bg_color = result_color.darkened(0.55)
		tile_style.border_color = result_color if can_craft else Color(0.3, 0.3, 0.3)
		tile_style.set_border_width_all(2 if can_craft else 1)
		tile_style.set_corner_radius_all(4)
		tile.add_theme_stylebox_override("panel", tile_style)
		tile.modulate = Color(1.0, 1.0, 1.0) if can_craft else Color(0.5, 0.5, 0.5)
		_info_container.add_child(tile)

		# 結果カード名
		var name_lbl = Label.new()
		name_lbl.text = result_name
		name_lbl.position = Vector2(6, 4)
		name_lbl.size = Vector2(tile_w - 12, 18)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		name_lbl.clip_text = true
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(name_lbl)

		# 素材テキスト
		var mat_lbl = Label.new()
		mat_lbl.text = "%s + %s" % [base, card]
		mat_lbl.position = Vector2(6, 22)
		mat_lbl.size = Vector2(tile_w - 12, 14)
		mat_lbl.add_theme_font_size_override("font_size", 9)
		mat_lbl.add_theme_color_override("font_color", UIF.DIM_COLOR)
		mat_lbl.clip_text = true
		mat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(mat_lbl)

		# 合成ボタン or 素材不足
		var btn_lbl = Label.new()
		btn_lbl.text = "[合成]" if can_craft else "[素材不足]"
		btn_lbl.position = Vector2(6, 38)
		btn_lbl.size = Vector2(tile_w - 12, 16)
		btn_lbl.add_theme_font_size_override("font_size", 10)
		btn_lbl.add_theme_color_override("font_color", UIF.BENEFIT_COLOR if can_craft else UIF.DIM_COLOR)
		btn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(btn_lbl)

		if can_craft:
			var result_ref = result_name
			tile.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					# TODO: 合成実行ロジック（Phase 2対象）
					pass
			)

		y += float(tile_h) + 6.0
		found = true

		if y > 680.0:
			break

	if not found:
		var empty = Label.new()
		empty.text = "合成レシピなし"
		empty.position = Vector2(10, y)
		empty.size = Vector2(_info_w - 20, 20)
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", UIF.DIM_COLOR)
		_info_container.add_child(empty)

func _get_card_accent_color(card_name: String) -> Color:
	if CardDB.UNITS.has(card_name):
		var race = CardDB.UNITS[card_name].get("race", "")
		return RACE_COLORS.get(race, DEFAULT_COLOR)
	if CardDB.SPELLS.has(card_name):
		return SPELL_COLOR
	return DEFAULT_COLOR

# ===== カード詳細を指定コンテナに描画（盤面左下用）=====

func _clear_detail() -> void:
	if _detail_container == null:
		return
	for child in _detail_container.get_children():
		child.queue_free()

func show_empty_in_container(container: Control) -> void:
	_detail_container = container
	_detail_w = int(container.size.x) if container.size.x > 0 else 130
	_clear_detail()
	var hint = Label.new()
	hint.text = "カードを\n選択"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(4, 40)
	hint.size = Vector2(_detail_w - 8, 50)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", UIF.DIM_COLOR)
	_detail_container.add_child(hint)

func show_card_info_in_container(container: Control, card_idx: int) -> void:
	_detail_container = container
	_detail_w = int(container.size.x) if container.size.x > 0 else 130
	_clear_detail()
	if card_idx < 0 or card_idx >= GameSession.selected_deck.size():
		show_empty_in_container(container)
		return
	var entry = GameSession.selected_deck[card_idx]
	var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)

	# コンパクト版カード情報（盤面左下 130px幅）
	var accent = _get_card_accent_color(card_name)
	# ヘッダー帯
	var header = ColorRect.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(_detail_w, 22)
	header.color = accent
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_container.add_child(header)
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(4, 3)
	name_lbl.size = Vector2(_detail_w - 8, 16)
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_container.add_child(name_lbl)

	var y: float = 26.0
	# ステータス
	if CardDB.UNITS.has(card_name):
		var d = CardDB.UNITS[card_name]
		for stat_pair in [
			["コスト", str(d.get("cost", 0))],
			["HP", str(d.get("hp", 0))],
			["ATK", str(d.get("atk", 0))],
			["SPD", "%.1fs" % d.get("interval", 0)],
			["種族", d.get("race", "")],
		]:
			var row = Label.new()
			row.text = "%s:%s" % [stat_pair[0], stat_pair[1]]
			row.position = Vector2(4, y)
			row.size = Vector2(_detail_w - 8, 14)
			row.add_theme_font_size_override("font_size", 9)
			row.add_theme_color_override("font_color", UIF.TEXT_COLOR)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_detail_container.add_child(row)
			y += 15.0
	elif CardDB.SPELLS.has(card_name):
		var d = CardDB.SPELLS[card_name]
		var row = Label.new()
		row.text = "[呪文] C:%d" % d.get("cost", 0)
		row.position = Vector2(4, y)
		row.size = Vector2(_detail_w - 8, 14)
		row.add_theme_font_size_override("font_size", 9)
		row.add_theme_color_override("font_color", SPELL_COLOR)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail_container.add_child(row)
		y += 15.0
	elif CardDB.STATUS_SPELLS.has(card_name):
		var d = CardDB.STATUS_SPELLS[card_name]
		var row = Label.new()
		row.text = "[異常] C:%d" % d.get("cost", 0)
		row.position = Vector2(4, y)
		row.size = Vector2(_detail_w - 8, 14)
		row.add_theme_font_size_override("font_size", 9)
		row.add_theme_color_override("font_color", UIF.DEMERIT_COLOR)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail_container.add_child(row)
		y += 15.0

func show_material_in_container(container: Control, mat: Dictionary) -> void:
	_detail_container = container
	_detail_w = int(container.size.x) if container.size.x > 0 else 130
	_clear_detail()
	var name_lbl = Label.new()
	name_lbl.text = mat.get("display", "?")
	name_lbl.position = Vector2(4, 4)
	name_lbl.size = Vector2(_detail_w - 8, 20)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	_detail_container.add_child(name_lbl)
	var count = _count_owned(mat.get("id", ""))
	var count_lbl = Label.new()
	count_lbl.text = "所持: ×%d" % count
	count_lbl.position = Vector2(4, 26)
	count_lbl.size = Vector2(_detail_w - 8, 16)
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
	_detail_container.add_child(count_lbl)

# ===== カード詳細表示（DeckPrep.gdから移植） =====

func show_card_info(card_idx: int) -> void:
	clear_info()
	if card_idx < 0 or card_idx >= GameSession.selected_deck.size():
		show_empty()
		return
	var entry = GameSession.selected_deck[card_idx]
	var card_name = entry.get("name", "???") if entry is Dictionary else str(entry)

	if CardDB.UNITS.has(card_name):
		_show_unit_info(card_name)
	elif CardDB.SPELLS.has(card_name):
		_show_spell_info(card_name)
	elif CardDB.STATUS_SPELLS.has(card_name):
		_show_spell_info_status(card_name)
	else:
		show_empty()

# ===== 素材詳細表示（DeckPrep.gdから移植） =====

func show_material_info(mat: Dictionary) -> void:
	clear_info()
	var y: float = 20

	var name_lbl = Label.new()
	name_lbl.text = mat.get("display", "?")
	name_lbl.position = Vector2(10, y)
	name_lbl.size = Vector2(_info_w - 20, 28)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	_info_container.add_child(name_lbl)
	y += 35

	if mat.get("is_cursed", false):
		var cursed_lbl = Label.new()
		cursed_lbl.text = "【呪われた素材】"
		cursed_lbl.position = Vector2(10, y)
		cursed_lbl.size = Vector2(_info_w - 20, 20)
		cursed_lbl.add_theme_font_size_override("font_size", 12)
		cursed_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.4))
		_info_container.add_child(cursed_lbl)
		y += 22

	var count = _count_owned(mat.get("id", ""))
	var count_lbl = Label.new()
	count_lbl.text = "所持数: ×%d" % count
	count_lbl.position = Vector2(10, y)
	count_lbl.size = Vector2(_info_w - 20, 20)
	count_lbl.add_theme_font_size_override("font_size", 13)
	count_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
	_info_container.add_child(count_lbl)
	y += 26

	var desc = mat.get("description", "")
	if desc != "":
		var desc_lbl = Label.new()
		desc_lbl.text = desc
		desc_lbl.position = Vector2(10, y)
		desc_lbl.size = Vector2(_info_w - 20, 100)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", UIF.TEXT_COLOR)
		_info_container.add_child(desc_lbl)
		y += 55

	y += 10
	var sep_lbl = Label.new()
	sep_lbl.text = "── 合成先 ──"
	sep_lbl.position = Vector2(15, y)
	sep_lbl.size = Vector2(_info_w - 30, 18)
	sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_lbl.add_theme_font_size_override("font_size", 11)
	sep_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	_info_container.add_child(sep_lbl)
	y += 22

	var hint_lbl = Label.new()
	hint_lbl.text = "（工房ノードで合成可能）"
	hint_lbl.position = Vector2(10, y)
	hint_lbl.size = Vector2(_info_w - 20, 20)
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.add_theme_color_override("font_color", UIF.DIM_COLOR)
	_info_container.add_child(hint_lbl)

# ===== 合成情報表示（カード枠+ホバー対応）[項目4,5,6,7] =====

func build_synthesis_info(card_name: String) -> void:
	# 合成セクション（カード枠+ホバーポップアップ対応）
	var y_start: float = 0.0
	# 既存の解説Y末尾を動的に計算するのではなく、固定Yに差し込む
	# 呼び出し元で y を引数として渡す構成にするため、別関数で実現
	pass

func build_synthesis_section(y_start: float, card_name: String) -> float:
	var y: float = y_start

	# 上位合成セクション（カード+素材→上位カード、material_id を持つレシピ）
	y = _build_upper_synthesis_section(y, card_name)

	# 盤面合成セクション（カード+カード→結果）
	y = _build_board_synthesis_section(y, card_name)

	return y

# 合成確認省略トグルスイッチ
func _build_synth_confirm_toggle(y: float) -> float:
	var cb = CheckBox.new()
	cb.text = "Yes/No確認を省略"
	cb.button_pressed = _skip_synth_confirm
	cb.position = Vector2(10, y)
	cb.size = Vector2(_info_w - 20, 22)
	cb.add_theme_font_size_override("font_size", 11)
	cb.toggled.connect(func(pressed: bool): _skip_synth_confirm = pressed)
	_info_container.add_child(cb)
	return y + 26

# 上位合成: material_id フィールドを持つレシピ（素材消費型）
func _build_upper_synthesis_section(y_start: float, card_name: String) -> float:
	var y: float = y_start
	y = _info_section("上位合成", y)

	var recipes: Array = []
	for recipe in CardDB.SYNTHESIS:
		if not recipe.has("material_id"):
			continue
		if recipe.get("base", "") == card_name or recipe.get("card", "") == card_name or recipe.get("result", "") == card_name:
			recipes.append(recipe)

	if recipes.size() == 0:
		y = _info_label("（上位合成は素材入手後に解放）", y, 11, UIF.DIM_COLOR)
		return y

	# 結果カードのみをグリッド表示（最大4件/行）
	y = _build_synthesis_result_grid(recipes, y)
	return y

# 盤面合成セクション（旧: 追加召喚）カード+カード→結果
func _build_board_synthesis_section(y_start: float, card_name: String) -> float:
	var y: float = y_start
	y = _info_section("盤面合成", y)

	var recipes: Array = []
	for recipe in CardDB.SYNTHESIS:
		if recipe.has("material_id"):
			continue  # 上位合成のみのレシピは除外
		if recipe.get("base", "") == card_name or recipe.get("card", "") == card_name or recipe.get("result", "") == card_name:
			recipes.append(recipe)

	if recipes.size() == 0:
		y = _info_label("なし", y, 12, UIF.DIM_COLOR)
		return y

	# 結果カードのみをグリッド表示
	y = _build_synthesis_result_grid(recipes, y)
	return y

# 結果カードのみをグリッド表示する（ホバーで素材情報、クリックで合成確認）
func _build_synthesis_result_grid(recipes: Array, y: float) -> float:
	const ICON_W: int = MINI_CARD_W
	const ICON_H: int = MINI_CARD_H
	const GAP: int = 6
	const COLS: int = 4  # 1行あたりの最大アイコン数
	var row_x: float = 8
	var row_y: float = y
	var col_idx: int = 0

	for recipe in recipes:
		var result_name: String = recipe.get("result", "")
		var base_name: String = recipe.get("base", "")
		var mat_name: String = recipe.get("card", recipe.get("material_id", ""))

		var icon = create_mini_card_icon(result_name, Vector2(ICON_W, ICON_H))
		icon.position = Vector2(row_x + col_idx * (ICON_W + GAP), row_y)

		# ホバー: 素材ポップアップ
		icon.mouse_entered.connect(func():
			var global_pos = _info_container.global_position + Vector2(
				row_x + col_idx * (ICON_W + GAP) - 10,
				row_y - ICON_H - 10
			)
			_show_synthesis_hover_popup(base_name, mat_name, result_name, global_pos)
		)
		icon.mouse_exited.connect(func(): _hide_hover_popup())

		# クリック: 合成確認ダイアログ or 即合成
		icon.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if _skip_synth_confirm:
					_execute_synthesis(base_name, mat_name, result_name)
				else:
					_show_synth_confirm_dialog(base_name, mat_name, result_name)
		)

		_info_container.add_child(icon)
		col_idx += 1
		if col_idx >= COLS:
			col_idx = 0
			row_y += ICON_H + GAP

	if col_idx > 0:
		row_y += ICON_H + GAP

	return row_y

# 合成時のホバーポップアップ（素材情報表示）
func _show_synthesis_hover_popup(base_name: String, mat_name: String, result_name: String, pos: Vector2) -> void:
	_hide_hover_popup()
	if _main_node == null:
		return

	var popup = PanelContainer.new()
	popup.z_index = 200
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	style.border_color = Color(0.4, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	popup.add_theme_stylebox_override("panel", style)
	popup.custom_minimum_size = Vector2(180, 80)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	popup.add_child(vbox)

	# 結果カード名
	var res_lbl = Label.new()
	res_lbl.text = "▶ %s" % result_name
	res_lbl.add_theme_font_size_override("font_size", 12)
	res_lbl.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	vbox.add_child(res_lbl)

	# 必要素材
	var mat_hbox = HBoxContainer.new()
	mat_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(mat_hbox)

	var mini_base = create_mini_card_icon(base_name, Vector2(40, 65))
	mat_hbox.add_child(mini_base)

	var plus_lbl = Label.new()
	plus_lbl.text = "+"
	plus_lbl.add_theme_font_size_override("font_size", 14)
	plus_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mat_hbox.add_child(plus_lbl)

	var mini_mat = create_mini_card_icon(mat_name, Vector2(40, 65))
	mat_hbox.add_child(mini_mat)

	popup.position = pos
	_main_node.add_child(popup)
	_hover_popup = popup

# 合成確認ダイアログ（Yes/No）
func _show_synth_confirm_dialog(base_name: String, mat_name: String, result_name: String) -> void:
	if _main_node == null:
		return
	# 既存ダイアログがあれば削除
	var existing = _main_node.find_child("SynthConfirmDialog", false, false)
	if existing:
		existing.queue_free()

	var dialog = Panel.new()
	dialog.name = "SynthConfirmDialog"
	dialog.z_index = 300
	dialog.size = Vector2(240, 120)
	dialog.position = Vector2(
		(_main_node.size.x - 240) / 2.0,
		(_main_node.size.y - 120) / 2.0
	)
	var dstyle = StyleBoxFlat.new()
	dstyle.bg_color = Color(0.1, 0.1, 0.18, 0.97)
	dstyle.border_color = Color(0.5, 0.5, 0.7)
	dstyle.set_border_width_all(2)
	dstyle.set_corner_radius_all(6)
	dialog.add_theme_stylebox_override("panel", dstyle)
	_main_node.add_child(dialog)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(220, 100)
	dialog.add_child(vbox)

	var msg = Label.new()
	msg.text = "%s を合成しますか？" % result_name
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.add_theme_font_size_override("font_size", 13)
	msg.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	vbox.add_child(msg)

	var sub = Label.new()
	sub.text = "[%s] + [%s]" % [base_name, mat_name]
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", UIF.DIM_COLOR)
	sub.clip_text = true
	vbox.add_child(sub)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_hbox)

	var yes_btn = Button.new()
	yes_btn.text = "合成する"
	yes_btn.add_theme_font_size_override("font_size", 12)
	yes_btn.pressed.connect(func():
		_execute_synthesis(base_name, mat_name, result_name)
		dialog.queue_free()
	)
	btn_hbox.add_child(yes_btn)

	var no_btn = Button.new()
	no_btn.text = "キャンセル"
	no_btn.add_theme_font_size_override("font_size", 12)
	no_btn.pressed.connect(func(): dialog.queue_free())
	btn_hbox.add_child(no_btn)

# 合成実行（現時点はログのみ、Phase 3で実装）
func _execute_synthesis(base_name: String, mat_name: String, result_name: String) -> void:
	print("[DeckPrepInfo] 合成試行: [%s] + [%s] → [%s]" % [base_name, mat_name, result_name])

# VBoxContainer内配置用の合成行生成（ScrollContainer内で使用・後方互換のために残す）
func _create_synthesis_row_for_vbox(base_name: String, mat_name: String, result_name: String) -> Control:
	const ICON_W = 60
	const ICON_H = 78
	const OP_W = 14
	var total_w = ICON_W * 3 + OP_W * 2 + 4
	var start_x = (_info_w - total_w) / 2.0

	var row_ctrl = Control.new()
	row_ctrl.custom_minimum_size = Vector2(_info_w, ICON_H + 10)
	row_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var operators = [
		{"text": "+", "x": start_x + ICON_W},
		{"text": "→", "x": start_x + ICON_W * 2 + OP_W},
	]
	for op in operators:
		var op_lbl = Label.new()
		op_lbl.text = op["text"]
		op_lbl.position = Vector2(op["x"], ICON_H / 2.0 - 10)
		op_lbl.size = Vector2(OP_W, 20)
		op_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		op_lbl.add_theme_font_size_override("font_size", 12)
		op_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		op_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_ctrl.add_child(op_lbl)

	for icon_data in [
		{"name": base_name,   "x": start_x},
		{"name": mat_name,    "x": start_x + ICON_W + OP_W},
		{"name": result_name, "x": start_x + (ICON_W + OP_W) * 2},
	]:
		var icon = create_mini_card_icon(icon_data["name"], Vector2(ICON_W, ICON_H))
		icon.position = Vector2(icon_data["x"], 0)
		row_ctrl.add_child(icon)

	return row_ctrl

# 項目4: 合成行を「[対象] + [素材] → [結果]」のカードアイコン形式で表示
func _build_synthesis_card_row(base_name: String, mat_name: String, result_name: String, y: float) -> float:
	const ICON_W = 60
	const ICON_H = 78
	const OP_W = 14
	var total_w = ICON_W * 3 + OP_W * 2 + 4
	var start_x = (_info_w - total_w) / 2.0

	var row_ctrl = Control.new()
	row_ctrl.position = Vector2(0, y)
	row_ctrl.size = Vector2(_info_w, ICON_H + 2)
	row_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_container.add_child(row_ctrl)

	# 3枚のカードアイコン + 演算子を配置
	var icons = [
		{"name": base_name,   "x": start_x},
		{"name": mat_name,    "x": start_x + ICON_W + OP_W},
		{"name": result_name, "x": start_x + (ICON_W + OP_W) * 2},
	]
	var operators = [
		{"text": "+", "x": start_x + ICON_W},
		{"text": "→", "x": start_x + ICON_W * 2 + OP_W},
	]

	for op in operators:
		var op_lbl = Label.new()
		op_lbl.text = op["text"]
		op_lbl.position = Vector2(op["x"], ICON_H / 2.0 - 10)
		op_lbl.size = Vector2(OP_W, 20)
		op_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		op_lbl.add_theme_font_size_override("font_size", 12)
		op_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		op_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_ctrl.add_child(op_lbl)

	for icon_data in icons:
		var icon_name: String = icon_data["name"]
		var icon_x: float = icon_data["x"]
		var icon = create_mini_card_icon(icon_name, Vector2(ICON_W, ICON_H))
		icon.position = Vector2(icon_x, 0)
		# ホバーポップアップ（項目5）
		icon.mouse_entered.connect(func():
			_show_hover_popup(icon_name, row_ctrl.global_position + Vector2(icon_x - 20, -90))
		)
		icon.mouse_exited.connect(func(): _hide_hover_popup())
		row_ctrl.add_child(icon)

	return y + ICON_H + 8

# ミニカードアイコン生成（黄金比 60×97、グラフィック領域+名前+枠色でレア表現）
func create_mini_card_icon(card_name: String, size: Vector2 = Vector2(MINI_CARD_W, MINI_CARD_H)) -> Control:
	var frame = Panel.new()
	frame.custom_minimum_size = size
	frame.size = size
	frame.mouse_filter = Control.MOUSE_FILTER_STOP  # ホバー検知のため

	# 枠色決定（種族 or 呪文 or デフォルト）
	var accent_color = DEFAULT_COLOR
	if CardDB.UNITS.has(card_name):
		var race = CardDB.UNITS[card_name].get("race", "")
		accent_color = RACE_COLORS.get(race, DEFAULT_COLOR)
	elif CardDB.SPELLS.has(card_name):
		accent_color = SPELL_COLOR
	elif CardDB.STATUS_SPELLS.has(card_name):
		accent_color = Color(0.6, 0.3, 0.5)

	var style = StyleBoxFlat.new()
	style.bg_color = accent_color.darkened(0.55)
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", style)

	# ヘッダー帯（名前表示）
	var header = ColorRect.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(size.x, 16)
	header.color = accent_color
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(header)

	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(2, 0)
	name_lbl.size = Vector2(size.x - 4, 15)
	name_lbl.add_theme_font_size_override("font_size", 7)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(name_lbl)

	# グラフィック領域（仮: 色帯）
	var illust = ColorRect.new()
	illust.position = Vector2(3, 19)
	illust.size = Vector2(size.x - 6, size.y - 32)
	illust.color = accent_color.darkened(0.65)
	illust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(illust)

	# 下部: 簡易ステータス
	var bot_lbl = Label.new()
	if CardDB.UNITS.has(card_name):
		var d = CardDB.UNITS[card_name]
		bot_lbl.text = "HP%d" % d.get("hp", 0)
	elif CardDB.SPELLS.has(card_name):
		var d = CardDB.SPELLS[card_name]
		bot_lbl.text = "C:%d" % d.get("cost", 0)
	else:
		bot_lbl.text = "???"
	bot_lbl.position = Vector2(2, size.y - 13)
	bot_lbl.size = Vector2(size.x - 4, 12)
	bot_lbl.add_theme_font_size_override("font_size", 7)
	bot_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	bot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bot_lbl)

	return frame

# ===== ホバーポップアップ（項目6,7対応）=====

func create_card_hover_popup(card_name: String) -> Control:
	var popup = PanelContainer.new()
	popup.z_index = 200
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	style.border_color = Color(0.4, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	popup.add_theme_stylebox_override("panel", style)
	popup.custom_minimum_size = Vector2(160, 80)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	popup.add_child(vbox)

	# カード名
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	vbox.add_child(name_lbl)

	if CardDB.UNITS.has(card_name):
		var d = CardDB.UNITS[card_name]
		var stats_lbl = Label.new()
		stats_lbl.text = "HP:%d ATK:%d SPD:%.1f" % [d.get("hp", 0), d.get("atk", 0), d.get("interval", 0)]
		stats_lbl.add_theme_font_size_override("font_size", 10)
		stats_lbl.add_theme_color_override("font_color", UIF.TEXT_COLOR)
		vbox.add_child(stats_lbl)
		var cost_lbl = Label.new()
		cost_lbl.text = "コスト:%d  %s" % [d.get("cost", 0), d.get("race", "")]
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
		vbox.add_child(cost_lbl)
	elif CardDB.SPELLS.has(card_name):
		var d = CardDB.SPELLS[card_name]
		var cost_lbl = Label.new()
		cost_lbl.text = "[呪文] コスト:%d" % d.get("cost", 0)
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", SPELL_COLOR)
		vbox.add_child(cost_lbl)
	elif CardDB.STATUS_SPELLS.has(card_name):
		var d = CardDB.STATUS_SPELLS[card_name]
		var cost_lbl = Label.new()
		cost_lbl.text = "[異常状態] コスト:%d" % d.get("cost", 0)
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", UIF.DEMERIT_COLOR)
		vbox.add_child(cost_lbl)

	return popup

func _show_hover_popup(card_name: String, pos: Vector2) -> void:
	_hide_hover_popup()
	if _main_node == null:
		return
	_hover_popup = create_card_hover_popup(card_name)
	_hover_popup.position = pos
	_main_node.add_child(_hover_popup)

func _hide_hover_popup() -> void:
	if _hover_popup != null:
		_hover_popup.queue_free()
		_hover_popup = null

# ===== 内部ヘルパー =====

func _count_owned(mat_id: String) -> int:
	var count = 0
	for m in GameSession.materials:
		if m is Dictionary and m.get("id", "") == mat_id:
			count += 1
	return count

func _show_unit_info(card_name: String) -> void:
	var d = CardDB.UNITS[card_name]
	var y: float = 8

	# 大型カード枠（黄金比縦長・効果表/フレーバー内包）
	y = _build_card_frame_header(card_name, d, y)
	y += 6

	# 合成セクション（結果カードのみ表示+ホバー詳細+クリック確認）
	y = build_synthesis_section(y, card_name)

func _show_spell_info(card_name: String) -> void:
	var d = CardDB.SPELLS[card_name]
	var y: float = 8

	# 項目3: 大型カード枠ヘッダー（コスト含む）
	y = _build_card_frame_header(card_name, d, y)
	y = _info_label("[呪文]", y, 12, SPELL_COLOR)
	y += 5

	y = _info_section("効果", y)
	var effect_text = d.get("effect", "")
	if effect_text != "":
		y = _info_label_wrap(effect_text, y, 12, UIF.TEXT_COLOR)
	y += 5

	var skills = d.get("skills", [])
	var _edb = load("res://scripts/EffectDB.gd")
	for skill in skills:
		var eid = skill.get("effect_id", "")
		var edef = _edb.EFFECTS.get(eid, {})
		var target = skill.get("target", "")
		y = _info_label("  %s → %s" % [edef.get("display", eid), target], y, 11, Color(0.6, 0.8, 0.7))

	if _PL != null:
		var entry = {"name": card_name}
		var scope = _PL.get_effect_scope(entry)
		var scope_names = {"cell": "単体", "row": "行全体", "col": "列全体", "all": "全体"}
		y += 5
		y = _info_label("効果範囲: %s" % scope_names.get(scope, "単体"), y, 12, Color(0.7, 0.6, 0.8))

func _show_spell_info_status(card_name: String) -> void:
	var d = CardDB.STATUS_SPELLS[card_name]
	var y: float = 8
	y = _build_card_frame_header(card_name, d, y)
	y = _info_label("[異常状態カード]", y, 12, UIF.DEMERIT_COLOR)
	y += 5
	if d.get("is_consumable", false):
		_info_label("消費型（使用後デッキから消滅）", y, 11, UIF.DEMERIT_COLOR)

# 大型カード枠ヘッダー（5:7比率縦長・仕様カード内レイアウト準拠）
# カード内レイアウト（上から・高さ比率）:
#   ヘッダー行（種族+マナ+カード名+コスト）  10%
#   イラスト枠                             35%
#   Skillsラベル                            5%
#   スキル3列グリッド（攻撃時/サポート/パッシブ） 25%
#   HP/ATK/SPD行                           10%
#   フレーバーテキスト                      15%
func _build_card_frame_header(card_name: String, d: Dictionary, y: float) -> float:
	# 右パネル幅いっぱい（パディング8px分引く）。_info_w=200の場合は192px幅
	var frame_w: int = _info_w - 8
	var frame_h: int = int(float(frame_w) * 7.0 / 5.0)  # 5:7比率（192×7/5=268px）
	var race = d.get("race", "")
	var accent_color = RACE_COLORS.get(race, SPELL_COLOR)

	var card_frame = Panel.new()
	card_frame.position = Vector2((_info_w - frame_w) / 2.0, y)
	card_frame.size = Vector2(frame_w, frame_h)
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = accent_color.darkened(0.55)
	frame_style.border_color = accent_color
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(6)
	card_frame.add_theme_stylebox_override("panel", frame_style)
	_info_container.add_child(card_frame)

	var cy: float = 0  # カード内部Y座標

	# ---- ヘッダー行（10%）: 種族(左) + マナ(右隣) + カード名(中央) + コスト(右) ----
	var header_h: float = float(frame_h) * 0.10
	var header_bar = ColorRect.new()
	header_bar.position = Vector2(0, cy)
	header_bar.size = Vector2(frame_w, header_h)
	header_bar.color = accent_color
	card_frame.add_child(header_bar)

	# 種族（左寄り・小）
	var race_lbl = Label.new()
	race_lbl.text = race if race != "" else "呪文"
	race_lbl.position = Vector2(4, cy + 2)
	race_lbl.size = Vector2(40, header_h - 4)
	race_lbl.add_theme_font_size_override("font_size", 9)
	race_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	race_lbl.clip_text = true
	race_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_frame.add_child(race_lbl)

	# マナ（種族右隣・小）
	var mana_val = d.get("cost", 0)
	var mana_lbl = Label.new()
	mana_lbl.text = "M%d" % mana_val
	mana_lbl.position = Vector2(44, cy + 2)
	mana_lbl.size = Vector2(24, header_h - 4)
	mana_lbl.add_theme_font_size_override("font_size", 9)
	mana_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	mana_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_frame.add_child(mana_lbl)

	# カード名（中央・大）
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(68, cy + 2)
	name_lbl.size = Vector2(frame_w - 96, header_h - 4)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_frame.add_child(name_lbl)

	# コスト（右寄り・小）
	var cost_lbl = Label.new()
	cost_lbl.text = "%d" % mana_val
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.position = Vector2(frame_w - 24, cy + 2)
	cost_lbl.size = Vector2(20, header_h - 4)
	cost_lbl.add_theme_font_size_override("font_size", 9)
	cost_lbl.add_theme_color_override("font_color", Color(1, 1, 0.5))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_frame.add_child(cost_lbl)
	cy += header_h + 1

	# ---- イラスト枠（35%）----
	var illust_h: float = float(frame_h) * 0.35
	var illust = ColorRect.new()
	illust.position = Vector2(4, cy)
	illust.size = Vector2(frame_w - 8, illust_h)
	illust.color = accent_color.darkened(0.65)
	card_frame.add_child(illust)
	cy += illust_h + 2

	# ---- Skillsラベル（5%）----
	var skills_label_h: float = float(frame_h) * 0.05
	var skills_center_lbl = Label.new()
	skills_center_lbl.text = "Skills"
	skills_center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skills_center_lbl.position = Vector2(4, cy)
	skills_center_lbl.size = Vector2(frame_w - 8, skills_label_h)
	skills_center_lbl.add_theme_font_size_override("font_size", 9)
	skills_center_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	skills_center_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_frame.add_child(skills_center_lbl)
	cy += skills_label_h

	# ---- スキル3列グリッド（25%）: 攻撃時 / サポート / パッシブ ----
	var skills_grid_h: float = float(frame_h) * 0.25
	cy = _build_skills_3col_in_card(card_frame, d, cy, frame_w, skills_grid_h)

	# ---- HP/ATK/SPD行（10%）----
	var stat_h: float = float(frame_h) * 0.10
	if CardDB.UNITS.has(card_name):
		var stats_hbox = HBoxContainer.new()
		stats_hbox.position = Vector2(4, cy)
		stats_hbox.size = Vector2(frame_w - 8, stat_h)
		stats_hbox.add_theme_constant_override("separation", 4)
		card_frame.add_child(stats_hbox)
		for stat_data in [
			["HP", str(d.get("hp", 0))],
			["ATK", str(d.get("atk", 0))],
			["SPD", "%.1fs" % d.get("interval", 0)],
		]:
			var sl = Label.new()
			sl.text = "%s%s" % [stat_data[0], stat_data[1]]
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sl.add_theme_font_size_override("font_size", 9)
			sl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			stats_hbox.add_child(sl)
	else:
		var type_lbl = Label.new()
		type_lbl.text = "[呪文]" if CardDB.SPELLS.has(card_name) else "[異常状態]"
		type_lbl.position = Vector2(4, cy)
		type_lbl.size = Vector2(frame_w - 8, stat_h)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_lbl.add_theme_font_size_override("font_size", 10)
		type_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		card_frame.add_child(type_lbl)
	cy += stat_h

	# ---- フレーバーテキスト（15%・斜体・小・中央）----
	var flavor_h: float = float(frame_h) * 0.15
	var flavor = _get_flavor_text(card_name)
	var flavor_lbl = Label.new()
	flavor_lbl.text = flavor
	flavor_lbl.position = Vector2(6, cy)
	flavor_lbl.size = Vector2(frame_w - 12, flavor_h)
	flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	flavor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor_lbl.add_theme_font_size_override("font_size", 9)
	flavor_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.45))
	card_frame.add_child(flavor_lbl)

	return y + float(frame_h) + 8.0

# 効果表をカード内部に描画する（2列3行、列名なし）
# 左列: trigger表示名（最大9文字）、右列: effect_id display
# 最大3行。超過は「...」で省略
func _build_effect_table_in_card(card_frame: Control, d: Dictionary, cy: float, frame_w: int) -> float:
	const ROW_H: int = 21
	const MAX_ROWS: int = 3
	const LEFT_W: int = 85
	const RIGHT_W: int = 160
	const TRIGGER_LABELS: Dictionary = {
		"always": "サポート",
		"on_hit": "命中時",
		"on_kill": "撃破時",
		"on_death": "死亡時",
		"on_summon": "召喚時",
		"on_hp_threshold": "HP閾値",
		"timer": "定期",
		"on_play": "使用時",
	}
	const TRIGGER_COLORS: Dictionary = {
		"on_hit": Color(0.9, 0.6, 0.5),
		"on_kill": Color(0.9, 0.5, 0.4),
		"always": Color(0.5, 0.8, 0.6),
		"timer": Color(0.5, 0.8, 0.6),
		"on_summon": Color(0.5, 0.6, 0.9),
		"on_death": Color(0.7, 0.5, 0.8),
		"on_hp_threshold": Color(0.8, 0.7, 0.4),
		"on_play": Color(0.6, 0.8, 1.0),
	}

	var skills = d.get("skills", [])
	if skills.size() == 0:
		return cy

	var _edb = load("res://scripts/EffectDB.gd")
	var display_rows: Array = []
	for skill in skills:
		var trigger = skill.get("trigger", "")
		var eid = skill.get("effect_id", "")
		var edef = _edb.EFFECTS.get(eid, {})
		var disp = edef.get("display", eid)
		if disp == "":
			continue
		display_rows.append({
			"trigger": trigger,
			"display": disp,
		})

	var row_count = mini(display_rows.size(), MAX_ROWS)
	var has_overflow = display_rows.size() > MAX_ROWS

	for i in range(row_count):
		var row = display_rows[i]
		var trigger = row["trigger"]
		var row_y = cy + i * ROW_H

		# 左列: trigger表示名
		var left_lbl = Label.new()
		left_lbl.text = "[%s]" % TRIGGER_LABELS.get(trigger, trigger)
		left_lbl.position = Vector2(8, row_y)
		left_lbl.size = Vector2(LEFT_W, ROW_H - 2)
		left_lbl.add_theme_font_size_override("font_size", 9)
		left_lbl.add_theme_color_override("font_color", TRIGGER_COLORS.get(trigger, Color(0.7, 0.7, 0.7)))
		left_lbl.clip_text = true
		card_frame.add_child(left_lbl)

		# 縦区切り
		var div = ColorRect.new()
		div.position = Vector2(8 + LEFT_W, row_y + 2)
		div.size = Vector2(1, ROW_H - 4)
		div.color = Color(0.4, 0.4, 0.5, 0.6)
		card_frame.add_child(div)

		# 右列: 効果display
		var right_lbl = Label.new()
		right_lbl.text = row["display"]
		right_lbl.position = Vector2(8 + LEFT_W + 4, row_y)
		right_lbl.size = Vector2(RIGHT_W, ROW_H - 2)
		right_lbl.add_theme_font_size_override("font_size", 9)
		right_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		right_lbl.clip_text = true
		card_frame.add_child(right_lbl)

	if has_overflow:
		var more_lbl = Label.new()
		more_lbl.text = "..."
		more_lbl.position = Vector2(8, cy + row_count * ROW_H)
		more_lbl.add_theme_font_size_override("font_size", 9)
		more_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		card_frame.add_child(more_lbl)

	cy += (row_count + (1 if has_overflow else 0)) * ROW_H + 6
	return cy

# スキル3列グリッド（攻撃時/サポート/パッシブ）描画（右パネル用カード詳細 ⑤仕様準拠）
# スキル分類:
#   攻撃時   = trigger が "on_hit" or "on_kill"（命中/撃破時）
#   サポート = trigger が "always" or "timer"（常時/定期）
#   パッシブ = その他（on_summon / on_death / on_hp_threshold / on_play 等）
func _build_skills_3col_in_card(card_frame: Control, d: Dictionary, cy: float, frame_w: int, grid_h: float) -> float:
	var col_w: float = float(frame_w) / 3.0
	var col_labels = ["攻撃時", "サポート", "パッシブ"]
	var col_colors = [Color(0.9, 0.5, 0.4), Color(0.5, 0.8, 0.6), Color(0.6, 0.6, 0.9)]
	const LABEL_H: float = 14.0
	const EFFECT_H: float = 14.0

	# 列ラベル行
	for ci_col in range(3):
		var col_lbl = Label.new()
		col_lbl.text = col_labels[ci_col]
		col_lbl.position = Vector2(float(ci_col) * col_w + 2.0, cy)
		col_lbl.size = Vector2(col_w - 4.0, LABEL_H)
		col_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col_lbl.add_theme_font_size_override("font_size", 8)
		col_lbl.add_theme_color_override("font_color", col_colors[ci_col])
		col_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_frame.add_child(col_lbl)
	cy += LABEL_H + 1

	# 縦区切り線
	for ci_div in range(1, 3):
		var div = ColorRect.new()
		div.position = Vector2(float(ci_div) * col_w, cy - LABEL_H - 1)
		div.size = Vector2(1.0, grid_h)
		div.color = Color(0.35, 0.35, 0.45, 0.5)
		card_frame.add_child(div)

	# スキルを3列に分類
	var skills = d.get("skills", [])
	var _edb = load("res://scripts/EffectDB.gd")
	var col_effects: Array = [[], [], []]  # [攻撃時, サポート, パッシブ]
	for skill in skills:
		var trigger = skill.get("trigger", "")
		var eid = skill.get("effect_id", "")
		var edef = _edb.EFFECTS.get(eid, {})
		var disp = edef.get("display", eid)
		if disp == "":
			continue
		var col_idx: int
		if trigger in ["on_hit", "on_kill"]:
			col_idx = 0  # 攻撃時
		elif trigger in ["always", "timer"]:
			col_idx = 1  # サポート
		else:
			col_idx = 2  # パッシブ
		col_effects[col_idx].append(disp)

	# 各列の効果名を描画（最大2行）
	for ci_col in range(3):
		var effects = col_effects[ci_col]
		if effects.size() == 0:
			# スキルなし → グレーアウト
			var none_lbl = Label.new()
			none_lbl.text = "—"
			none_lbl.position = Vector2(float(ci_col) * col_w + 2.0, cy)
			none_lbl.size = Vector2(col_w - 4.0, EFFECT_H)
			none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			none_lbl.add_theme_font_size_override("font_size", 8)
			none_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
			none_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_frame.add_child(none_lbl)
		else:
			for ei in range(mini(effects.size(), 2)):
				var eff_lbl = Label.new()
				eff_lbl.text = effects[ei]
				eff_lbl.position = Vector2(float(ci_col) * col_w + 2.0, cy + float(ei) * EFFECT_H)
				eff_lbl.size = Vector2(col_w - 4.0, EFFECT_H)
				eff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				eff_lbl.add_theme_font_size_override("font_size", 8)
				eff_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
				eff_lbl.clip_text = true
				eff_lbl.mouse_filter = Control.MOUSE_FILTER_STOP  # ホバー検知
				# ホバーで効果詳細ポップアップ（将来実装プレースホルダー）
				card_frame.add_child(eff_lbl)

	cy += maxf(EFFECT_H * 2.0, grid_h - LABEL_H - 1.0)
	return cy

func _get_effect_summary(card_name: String, d: Dictionary) -> String:
	var skills = d.get("skills", [])
	if skills.size() == 0:
		return ""
	var _edb = load("res://scripts/EffectDB.gd")
	var parts: Array = []
	for skill in skills.slice(0, 2):
		var eid = skill.get("effect_id", "")
		var edef = _edb.EFFECTS.get(eid, {})
		var disp = edef.get("display", eid)
		if disp != "":
			parts.append(disp)
	return " / ".join(parts)

func _get_flavor_text(card_name: String) -> String:
	var flavors = {
		"スライム": "最も弱く、最も可能性に満ちた存在",
		"ゴブリン": "素早さだけが取り柄の小さな戦士",
		"スケルトン": "死してなお戦場に立つ不屈の骨",
		"マッドスライム": "泥に混じった怒りが形になった",
		"ウルフ": "群れの先頭を走る誇り高き獣",
		"グール": "腐敗の中に宿る異常な生命力",
	}
	return flavors.get(card_name, "...")

func _info_label(text: String, y: float, size: int, color: Color) -> float:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = Vector2(15, y)
	lbl.size = Vector2(_info_w - 30, 20)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	_info_container.add_child(lbl)
	return y + size + 6

func _info_label_wrap(text: String, y: float, size: int, color: Color) -> float:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = Vector2(15, y)
	lbl.size = Vector2(_info_w - 30, 80)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	_info_container.add_child(lbl)
	return y + 50

func _info_section(text: String, y: float) -> float:
	var lbl = Label.new()
	lbl.text = "── %s ──" % text
	lbl.position = Vector2(15, y)
	lbl.size = Vector2(_info_w - 30, 18)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	_info_container.add_child(lbl)
	return y + 20
