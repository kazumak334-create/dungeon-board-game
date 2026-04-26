# SceneManager.gd
# Autoload: 全画面遷移を一元管理
extends Node

# シーン名定数（typo防止・全画面で参照）
const TITLE          = "title"
const MATERIAL_SELECT = "material_select"
const DECK_PREP      = "deck_prep"
const MAP_SELECT     = "map_select"
const BATTLE         = "battle"
const RESULT         = "result"
const SHOP           = "shop"
const EVENT          = "event"
const GATHER         = "gather"
const BOSS_REWARD    = "boss_reward"
const WORKSHOP       = "workshop"
const DECK_VIEW      = "deck_view"
const INVENTORY      = "inventory"
const SKILL_TREE     = "skill_tree"
const SETTINGS       = "settings"
const DECK_TEST_TOOL = "deck_test_tool"
const REST_SCREEN    = "rest_screen"  # Wave間休憩画面（Phase 4 #0-0a）

# シーン登録
var _scenes: Dictionary = {
	"title": "res://scenes/Title.tscn",
	"material_select": "res://scenes/InitialCardPick.tscn",
	# "deck_prep": "res://scenes/DeckPrep.tscn",  # シーンファイル未作成・go_to未使用
	"map_select": "res://scenes/MapSelect.tscn",
	"battle": "res://scenes/Main.tscn",
	"result": "res://scenes/Result.tscn",
	"shop": "res://scenes/Shop.tscn",
	"event": "res://scenes/Event.tscn",
	"gather": "res://scenes/Gather.tscn",
	"boss_reward": "res://scenes/BossReward.tscn",
	"workshop": "res://scenes/Workshop.tscn",
	"deck_view": "res://scenes/DeckView.tscn",
	"inventory": "res://scenes/Inventory.tscn",
	"skill_tree": "res://scenes/SkillTree.tscn",
	"settings": "res://scenes/Settings.tscn",
	"deck_test_tool": "res://scenes/tools/DeckTestTool.tscn",
	# "rest_screen": "res://scenes/RestScreen.tscn",  # シーンファイル未作成・Main.gdが直接生成
}

func go_to(scene_name: String) -> void:
	var path = _scenes.get(scene_name)
	if path == null:
		print("[SceneManager] シーン未登録: %s" % scene_name)
		return
	var scene = load(path)
	if scene == null:
		print("[SceneManager] シーンロード失敗: %s" % path)
		return
	print("[SceneManager] go_to: %s -> %s" % [scene_name, path])
	get_tree().change_scene_to_packed(scene)

func go_to_battle(class_id: String) -> void:
	GameSession.class_id = class_id
	print("[SceneManager] go_to_battle: class_id=%s" % class_id)
	go_to(BATTLE)
