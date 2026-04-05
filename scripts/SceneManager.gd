# SceneManager.gd
# Autoload: 全画面遷移を一元管理
extends Node

# シーン登録（.tscnが存在しない場合はnull。存在確認後にpreloadに切り替え）
var _scenes: Dictionary = {
	"title": null,
	"class_select": null,
	"battle": "res://scenes/Main.tscn",
	"result": null,
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
	go_to("battle")
