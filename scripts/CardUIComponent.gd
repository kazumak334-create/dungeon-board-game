# CardUIComponent.gd
# キュー用カードUIコンポーネント
extends RefCounted

# レアリティ枠色
const RARITY_BORDER = {
	"common": Color(0.5, 0.5, 0.5),
	"uncommon": Color(0.3, 0.7, 0.3),
	"rare": Color(0.3, 0.5, 0.9),
	"epic": Color(0.6, 0.3, 0.8),
	"legend": Color(0.85, 0.7, 0.15),
	"god": Color(0.9, 0.25, 0.25),
}

# 種族背景色
const RACE_BG = {
	"スライム": Color(0.08, 0.15, 0.08),
	"獣": Color(0.15, 0.1, 0.05),
	"アンデッド": Color(0.1, 0.06, 0.12),
}

# カードを生成（ユニット用）
static func create_unit_card(card_name: String, unit_data: Dictionary, width: float = 160.0, height: float = 220.0) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(width, height)
	card.size = Vector2(width, height)

	var rarity = unit_data.get("rarity", "common")
	var race = unit_data.get("race", "")
	var border_color = RARITY_BORDER.get(rarity, RARITY_BORDER["common"])
	var bg_color = RACE_BG.get(race, Color(0.08, 0.08, 0.12))

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(2)
	style.border_color = border_color
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	# ---- ヘッダー（コスト+名前+HP） ----
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)

	var cost_lbl = Label.new()
	cost_lbl.text = "%d💎" % unit_data.get("cost", 0)
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9))
	header.add_child(cost_lbl)

	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	var hp_lbl = Label.new()
	hp_lbl.text = "HP%d" % unit_data.get("hp", 0)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	header.add_child(hp_lbl)

	vbox.add_child(header)

	# サブステータス
	var stats_lbl = Label.new()
	stats_lbl.text = "ATK:%d  SPD:%.1fs" % [unit_data.get("atk", 0), unit_data.get("interval", 0)]
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	vbox.add_child(stats_lbl)

	# ---- イラストエリア（空ボックス） ----
	var illust = ColorRect.new()
	illust.custom_minimum_size = Vector2(width - 16, height * 0.35)
	illust.color = Color(0.12, 0.12, 0.18)
	vbox.add_child(illust)

	# 種族ラベル（イラスト上に重ねる）
	var race_lbl = Label.new()
	race_lbl.text = race
	race_lbl.add_theme_font_size_override("font_size", 9)
	race_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.4))
	vbox.add_child(race_lbl)

	# ---- スキルエリア ----
	var _edb = load("res://scripts/EffectDB.gd")
	var skills = unit_data.get("skills", [])

	# スキルを分類
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

	# スキル表示（最大3行）
	var skill_sets = [
		{"label": "攻撃", "skills": attack_skills, "color": Color(0.9, 0.5, 0.4)},
		{"label": "サポ", "skills": support_skills, "color": Color(0.4, 0.8, 0.5)},
		{"label": "パッシブ", "skills": passive_skills, "color": Color(0.5, 0.6, 0.9)},
	]

	for ss in skill_sets:
		if ss["skills"].size() == 0:
			continue
		var skill_line = HBoxContainer.new()
		skill_line.add_theme_constant_override("separation", 3)

		# ラベルバッジ
		var badge = Label.new()
		badge.text = "[%s]" % ss["label"]
		badge.add_theme_font_size_override("font_size", 8)
		badge.add_theme_color_override("font_color", ss["color"])
		skill_line.add_child(badge)

		# 効果名
		var first_skill = ss["skills"][0]
		var eid = first_skill.get("effect_id", "")
		var edef = _edb.EFFECTS.get(eid, {})
		var effect_name = edef.get("display", eid)
		var effect_lbl = Label.new()
		effect_lbl.text = effect_name
		effect_lbl.add_theme_font_size_override("font_size", 9)
		effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		skill_line.add_child(effect_lbl)

		if ss["skills"].size() > 1:
			var more = Label.new()
			more.text = "+%d" % (ss["skills"].size() - 1)
			more.add_theme_font_size_override("font_size", 8)
			more.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			skill_line.add_child(more)

		vbox.add_child(skill_line)

	card.add_child(vbox)
	return card

# 呪文カード生成
static func create_spell_card(card_name: String, spell_data: Dictionary, width: float = 160.0, height: float = 220.0) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(width, height)
	card.size = Vector2(width, height)

	var rarity = spell_data.get("rarity", "common")
	var border_color = RARITY_BORDER.get(rarity, RARITY_BORDER["common"])

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.14)
	style.set_border_width_all(2)
	style.border_color = border_color
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	# ヘッダー
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)

	var cost_lbl = Label.new()
	cost_lbl.text = "%d💎" % spell_data.get("cost", 0)
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9))
	header.add_child(cost_lbl)

	var name_lbl = Label.new()
	name_lbl.text = card_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = "呪文"
	type_lbl.add_theme_font_size_override("font_size", 10)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.5, 0.8))
	header.add_child(type_lbl)

	vbox.add_child(header)

	# イラストエリア
	var illust = ColorRect.new()
	illust.custom_minimum_size = Vector2(width - 16, height * 0.35)
	illust.color = Color(0.1, 0.08, 0.18)
	vbox.add_child(illust)

	# 効果テキスト
	var effect_text = spell_data.get("effect", "")
	if effect_text != "":
		var effect_lbl = Label.new()
		effect_lbl.text = effect_text
		effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		effect_lbl.add_theme_font_size_override("font_size", 9)
		effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(effect_lbl)

	card.add_child(vbox)
	return card
