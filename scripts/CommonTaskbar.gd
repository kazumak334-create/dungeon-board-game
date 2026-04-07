# CommonTaskbar.gd
# 全画面共通のタスクバーコンポーネント
# 使用方法: 各画面の _ready() で CommonTaskbar.new().attach(self, "scene_name") を呼ぶ
extends RefCounted
class_name CommonTaskbar

const UIF = preload("res://scripts/UIFactory.gd")

const TASKBAR_H = 36
const TASKBAR_BG_COLOR = Color(0.08, 0.08, 0.12, 0.95)
const TASKBAR_BORDER_COLOR = Color(0.3, 0.35, 0.45)
const BUTTON_SIZE = 30
const BUTTON_GAP = 6

# シーン別表示設定
# {scene_name: {deck, inventory, skill, settings, gold, sp, act, race}}
const VISIBILITY = {
	"title": {
		"deck": false, "inventory": false, "skill": false, "settings": true,
		"gold": false, "sp": false, "act": false, "race": false
	},
	"material_select": {
		"deck": false, "inventory": true, "skill": false, "settings": true,
		"gold": false, "sp": false, "act": false, "race": false
	},
	"deck_prep": {
		"deck": true, "inventory": true, "skill": true, "settings": true,
		"gold": true, "sp": true, "act": true, "race": true
	},
	"map_select": {
		"deck": true, "inventory": true, "skill": true, "settings": true,
		"gold": true, "sp": true, "act": true, "race": true
	},
	"battle": {
		"deck": true, "inventory": true, "skill": true, "settings": true,
		"gold": true, "sp": false, "act": true, "race": true
	},
	"shop": {
		"deck": true, "inventory": true, "skill": true, "settings": true,
		"gold": true, "sp": false, "act": true, "race": true
	},
	"result": {
		"deck": true, "inventory": true, "skill": true, "settings": true,
		"gold": true, "sp": true, "act": true, "race": false
	},
}

var _parent: Control = null
var _scene_name: String = ""

func attach(parent: Control, scene_name: String) -> void:
	_parent = parent
	_scene_name = scene_name
	_build_taskbar()

func _build_taskbar() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = TASKBAR_BG_COLOR
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1280, TASKBAR_H)
	bg.z_index = 100
	_parent.add_child(bg)

	# 下境界線
	var border = ColorRect.new()
	border.color = TASKBAR_BORDER_COLOR
	border.position = Vector2(0, TASKBAR_H - 1)
	border.size = Vector2(1280, 1)
	border.z_index = 101
	_parent.add_child(border)

	var vis = VISIBILITY.get(_scene_name, {})

	# 左側: 情報表示
	_build_info_section(vis)

	# 右側: アクセスボタン
	_build_button_section(vis)

func _build_info_section(vis: Dictionary) -> void:
	var x = 10
	var y = 8

	if vis.get("act", false):
		var act_lbl = Label.new()
		act_lbl.text = "Act %d / %d" % [GameSession.get("current_act") if "current_act" in GameSession else 1, 3]
		act_lbl.position = Vector2(x, y)
		act_lbl.add_theme_font_size_override("font_size", 12)
		act_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		act_lbl.z_index = 102
		_parent.add_child(act_lbl)
		x += 100

	if vis.get("race", false):
		var race_lbl = Label.new()
		var race = GameSession.get("race_theme") if "race_theme" in GameSession else "slime"
		race_lbl.text = "種族: %s" % race
		race_lbl.position = Vector2(x, y)
		race_lbl.add_theme_font_size_override("font_size", 12)
		race_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
		race_lbl.z_index = 102
		_parent.add_child(race_lbl)
		x += 110

	if vis.get("gold", false):
		var gold_lbl = Label.new()
		gold_lbl.text = "G: %d" % GameSession.gold
		gold_lbl.position = Vector2(x, y)
		gold_lbl.add_theme_font_size_override("font_size", 12)
		gold_lbl.add_theme_color_override("font_color", UIF.GOLD_COLOR)
		gold_lbl.z_index = 102
		_parent.add_child(gold_lbl)
		x += 80

	if vis.get("sp", false):
		var sp_lbl = Label.new()
		sp_lbl.text = "SP: %d" % GameSession.skill_points
		sp_lbl.position = Vector2(x, y)
		sp_lbl.add_theme_font_size_override("font_size", 12)
		sp_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
		sp_lbl.z_index = 102
		_parent.add_child(sp_lbl)
		x += 60

func _build_button_section(vis: Dictionary) -> void:
	# アイコン順序: デッキ → 持ち物 → スキル → 設定
	var buttons = []
	if vis.get("deck", false):
		buttons.append({"id": "deck", "label": "デッキ", "scene": SceneManager.DECK_VIEW})
	if vis.get("inventory", false):
		buttons.append({"id": "inventory", "label": "持物", "scene": SceneManager.INVENTORY})
	if vis.get("skill", false):
		buttons.append({"id": "skill", "label": "スキル", "scene": SceneManager.SKILL_TREE})
	if vis.get("settings", false):
		buttons.append({"id": "settings", "label": "設定", "scene": SceneManager.SETTINGS})

	# 右端から配置
	var total_w = buttons.size() * BUTTON_SIZE + (buttons.size() - 1) * BUTTON_GAP
	var start_x = 1280 - total_w - 10
	for i in range(buttons.size()):
		var btn_data = buttons[i]
		var btn = Button.new()
		btn.text = btn_data["label"]
		btn.position = Vector2(start_x + i * (BUTTON_SIZE + BUTTON_GAP) - 5, 4)
		btn.size = Vector2(BUTTON_SIZE + 10, 28)
		btn.add_theme_font_size_override("font_size", 10)
		btn.z_index = 102
		var scene_id = btn_data["scene"]
		btn.pressed.connect(func(): SceneManager.go_to(scene_id))
		_parent.add_child(btn)
