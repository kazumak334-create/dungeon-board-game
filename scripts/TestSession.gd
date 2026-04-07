# TestSession.gd
# セッション/画面遷移テスト（GameSession, materials, base_deck, scene_manager）
extends RefCounted

func run(runner: RefCounted) -> void:
	_test_game_session(runner)
	_test_materials_integrity(runner)
	_test_base_deck_integrity(runner)
	_test_scene_manager_paths(runner)

func _test_game_session(r: RefCounted) -> void:
	# reset()で全フィールドが初期化されるか
	GameSession.class_id = "test"
	GameSession.dev_mode = true
	GameSession.gold = 999
	GameSession.skill_points = 5
	GameSession.materials = [{"id": "test"}]
	GameSession.selected_deck = [{"name": "test"}]
	GameSession.selected_material = {"id": "test"}
	GameSession.reset()
	r._assert_eq(GameSession.class_id, "", "reset: class_id空")
	r._assert_eq(GameSession.dev_mode, false, "reset: dev_mode=false")
	r._assert_eq(GameSession.gold, 0, "reset: gold=0")
	r._assert_eq(GameSession.skill_points, 0, "reset: skill_points=0")
	r._assert_eq(GameSession.materials.size(), 0, "reset: materials空")
	r._assert_eq(GameSession.selected_deck.size(), 0, "reset: selected_deck空")
	r._assert_eq(GameSession.selected_material.size(), 0, "reset: selected_material空")

func _test_materials_integrity(r: RefCounted) -> void:
	r._assert_true(CardDB.MATERIALS.size() > 0, "MATERIALS: 1個以上存在")
	for mat in CardDB.MATERIALS:
		r._assert_true(mat.has("id"), "素材にid: %s" % mat.get("display", "???"))
		r._assert_true(mat.has("display"), "素材にdisplay: %s" % mat.get("id", "???"))
		r._assert_true(mat.has("is_cursed"), "素材にis_cursed: %s" % mat.get("id", "???"))
		r._assert_true(mat.has("benefits"), "素材にbenefits: %s" % mat.get("id", "???"))
		r._assert_true(mat.has("demerits"), "素材にdemerits: %s" % mat.get("id", "???"))
	# 呪い素材はデメリット必須
	for mat in CardDB.MATERIALS:
		if mat.get("is_cursed", false):
			r._assert_true(mat.get("demerits", []).size() > 0, "呪い素材にデメリット: %s" % mat.get("id", ""))

func _test_base_deck_integrity(r: RefCounted) -> void:
	r._assert_true(CardDB.BASE_DECK.size() > 0, "BASE_DECK: 1個以上存在")
	for entry in CardDB.BASE_DECK:
		var name = entry.get("name", "")
		r._assert_true(name != "", "BASE_DECKエントリにname")
		var is_unit = CardDB.UNITS.has(name)
		var is_spell = CardDB.SPELLS.has(name)
		var is_status = CardDB.STATUS_SPELLS.has(name)
		r._assert_true(is_unit or is_spell or is_status, "BASE_DECKカードがDB存在: %s" % name)

func _test_scene_manager_paths(r: RefCounted) -> void:
	# SceneManagerの全パスにファイルが存在するか
	var scenes = SceneManager._scenes
	for key in scenes:
		var path = scenes[key]
		if path != null:
			r._assert_true(FileAccess.file_exists(path), "シーン存在: %s -> %s" % [key, path])
