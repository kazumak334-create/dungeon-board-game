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
var _info_container: Control = null
var _info_w: int = 275
var _PL = null
var _hover_popup: Control = null

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
	y = _info_section("── 合成 ──", y)

	var has_synthesis = false

	# 合成素材として使われるレシピ（項目6: 合成先箇条書き+ホバー）
	for recipe in CardDB.SYNTHESIS:
		if recipe.get("base", "") == card_name or recipe.get("card", "") == card_name:
			var result_name = recipe.get("result", "")
			y = _build_synthesis_row(
				"%s + %s → %s" % [recipe["base"], recipe["card"], result_name],
				result_name, y, UIF.BENEFIT_COLOR
			)
			has_synthesis = true

	# 合成先（このカードが結果になるレシピ）（項目7: 合成素材ホバー）
	for recipe in CardDB.SYNTHESIS:
		if recipe.get("result", "") == card_name:
			var base_name = recipe.get("base", "")
			var card2_name = recipe.get("card", "")
			y = _build_synthesis_row(
				"← %s + %s" % [base_name, card2_name],
				base_name, y, Color(0.7, 0.7, 0.5)
			)
			has_synthesis = true

	if not has_synthesis:
		y = _info_label("なし", y, 12, UIF.DIM_COLOR)
	return y

# 合成行1件（テキスト + ホバーエリア）
func _build_synthesis_row(display_text: String, hover_target: String, y: float, color: Color) -> float:
	var row = Control.new()
	row.position = Vector2(15, y)
	row.size = Vector2(_info_w - 30, 18)
	_info_container.add_child(row)

	var lbl = Label.new()
	lbl.text = display_text
	lbl.size = Vector2(_info_w - 30, 18)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(lbl)

	# ホバーポップアップ（項目6,7）
	if hover_target != "" and (CardDB.UNITS.has(hover_target) or CardDB.SPELLS.has(hover_target)):
		var target_name = hover_target
		row.mouse_entered.connect(func(): _show_hover_popup(target_name, row.global_position + Vector2(0, -80)))
		row.mouse_exited.connect(func(): _hide_hover_popup())

	return y + 20

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

	# 項目5: カード詳細右上に選択カードのカード枠を追加
	y = _build_card_frame_header(card_name, d, y)
	y += 5

	# 基本ステータス
	y = _info_label("コスト: %d" % d.get("cost", 0), y, 13, Color(0.5, 0.7, 0.9))
	y = _info_label("HP: %d  ATK: %d  SPD: %.1fs" % [d.get("hp", 0), d.get("atk", 0), d.get("interval", 0)], y, 12, UIF.TEXT_COLOR)
	var race = d.get("race", "")
	var race_color = RACE_COLORS.get(race, DEFAULT_COLOR)
	y = _info_label("種族: %s" % race, y, 12, race_color)
	y += 8

	# 効果セクション（3分類）
	var skills = d.get("skills", [])
	var _edb = load("res://scripts/EffectDB.gd")
	var attack_skills: Array = []
	var support_skills: Array = []
	var passive_skills: Array = []
	for skill in skills:
		var trigger = skill.get("trigger", "")
		var target = skill.get("target", "self")
		match trigger:
			"on_hit", "on_kill":
				attack_skills.append(skill)
			"always":
				support_skills.append(skill)
			"timer":
				if target == "self":
					passive_skills.append(skill)
				else:
					support_skills.append(skill)
			_:
				passive_skills.append(skill)

	y = _info_section("攻撃時効果（前列）", y)
	if attack_skills.size() == 0:
		y = _info_label("なし", y, 11, UIF.DIM_COLOR)
	else:
		for skill in attack_skills:
			var edef = _edb.EFFECTS.get(skill.get("effect_id", ""), {})
			y = _info_label("  %s" % edef.get("display", skill.get("effect_id", "")), y, 11, Color(0.9, 0.6, 0.5))

	y = _info_section("サポート効果（中後列）", y)
	if support_skills.size() == 0:
		y = _info_label("なし", y, 11, UIF.DIM_COLOR)
	else:
		for skill in support_skills:
			var edef = _edb.EFFECTS.get(skill.get("effect_id", ""), {})
			y = _info_label("  %s" % edef.get("display", skill.get("effect_id", "")), y, 11, Color(0.5, 0.8, 0.6))

	y = _info_section("パッシブ効果（位置無関係）", y)
	if passive_skills.size() == 0:
		y = _info_label("なし", y, 11, UIF.DIM_COLOR)
	else:
		for skill in passive_skills:
			var edef = _edb.EFFECTS.get(skill.get("effect_id", ""), {})
			y = _info_label("  %s" % edef.get("display", skill.get("effect_id", "")), y, 11, Color(0.5, 0.6, 0.9))
	y += 6

	# 合成セクション（項目4,6,7: カード枠+ホバー対応）
	y = build_synthesis_section(y, card_name)
	y += 8

	# フレーバーテキスト
	y = _info_section("フレーバー", y)
	var flavor = _get_flavor_text(card_name)
	_info_label_wrap(flavor, y, 11, Color(0.6, 0.6, 0.5))

func _show_spell_info(card_name: String) -> void:
	var d = CardDB.SPELLS[card_name]
	var y: float = 8

	# 項目5: カード枠ヘッダー
	y = _build_card_frame_header(card_name, d, y)
	y = _info_label("[呪文]", y, 12, SPELL_COLOR)
	y += 5
	y = _info_label("コスト: %d" % d.get("cost", 0), y, 13, Color(0.5, 0.7, 0.9))
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
	y = _info_label("コスト: %d" % d.get("cost", 0), y, 13, Color(0.5, 0.7, 0.9))
	if d.get("is_consumable", false):
		_info_label("消費型（使用後デッキから消滅）", y, 11, UIF.DEMERIT_COLOR)

# 項目5: 右上にカード型ミニ枠を表示
func _build_card_frame_header(card_name: String, d: Dictionary, y: float) -> float:
	# カード型枠（右上）
	var card_frame = Panel.new()
	var frame_w = 72
	var frame_h = 88
	card_frame.position = Vector2(_info_w - frame_w - 8, y)
	card_frame.size = Vector2(frame_w, frame_h)
	var frame_style = StyleBoxFlat.new()
	var race = d.get("race", "")
	frame_style.bg_color = RACE_COLORS.get(race, SPELL_COLOR).darkened(0.3)
	frame_style.border_color = RACE_COLORS.get(race, SPELL_COLOR)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(4)
	card_frame.add_theme_stylebox_override("panel", frame_style)
	_info_container.add_child(card_frame)

	# カード枠内: ヘッダー色帯
	var header_bar = ColorRect.new()
	header_bar.position = Vector2(0, 0)
	header_bar.size = Vector2(frame_w, 18)
	header_bar.color = RACE_COLORS.get(race, SPELL_COLOR)
	card_frame.add_child(header_bar)

	# カード枠内: 名前（短縮）
	var mini_name = Label.new()
	mini_name.text = card_name
	mini_name.position = Vector2(2, 1)
	mini_name.size = Vector2(frame_w - 4, 16)
	mini_name.add_theme_font_size_override("font_size", 8)
	mini_name.add_theme_color_override("font_color", Color(1, 1, 1))
	mini_name.clip_text = true
	card_frame.add_child(mini_name)

	# カード枠内: イラスト枠（仮: 色帯）
	var illust = ColorRect.new()
	illust.position = Vector2(4, 21)
	illust.size = Vector2(frame_w - 8, 38)
	illust.color = RACE_COLORS.get(race, SPELL_COLOR).darkened(0.5)
	card_frame.add_child(illust)

	# カード枠内: ステータス縦並び
	if CardDB.UNITS.has(card_name):
		var stats_box = VBoxContainer.new()
		stats_box.position = Vector2(3, 62)
		stats_box.size = Vector2(frame_w - 6, 24)
		stats_box.add_theme_constant_override("separation", 0)
		card_frame.add_child(stats_box)
		for stat_text in ["HP:%d" % d.get("hp", 0), "ATK:%d SPD:%.0f" % [d.get("atk", 0), d.get("interval", 0)]]:
			var sl = Label.new()
			sl.text = stat_text
			sl.add_theme_font_size_override("font_size", 7)
			sl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			stats_box.add_child(sl)

	# カード名（左側、大きく）
	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(10, y + 4)
	name_lbl.size = Vector2(_info_w - frame_w - 24, 22)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	name_lbl.clip_text = true
	_info_container.add_child(name_lbl)

	return y + frame_h + 4

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
