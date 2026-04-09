# test_map_generator.gd
# MapGenerator の単体テスト
extends GutTest

const MapGenerator = preload("res://scripts/MapGenerator.gd")

func test_generate_creates_valid_map():
	var gen = MapGenerator.new()
	var map_data = gen.generate(12345, "slime")

	assert_not_null(map_data, "マップデータが生成される")
	assert_eq(map_data.get("seed"), 12345, "シードが保存される")
	assert_eq(map_data.get("race_theme"), "slime", "テーマが保存される")
	assert_eq(map_data.get("acts", []).size(), 3, "3 Actが生成される")

func test_act_structure():
	var gen = MapGenerator.new()
	var map_data = gen.generate(12345, "slime")
	var acts = map_data.get("acts", [])

	for i in range(acts.size()):
		var act = acts[i]
		assert_eq(act.get("act_num"), i + 1, "Act番号が正しい")
		var nodes = act.get("nodes", [])
		assert_gt(nodes.size(), 0, "ノードが存在する")

		# depth 0 に3つのスタートノードがあるか
		var depth0_count = 0
		for node in nodes:
			if node.get("depth") == 0:
				depth0_count += 1
				assert_eq(node.get("type"), "battle", "depth 0 は battle 固定")
		assert_eq(depth0_count, 3, "depth 0 に3つのノードがある")

		# ボスノードが1つあるか
		var boss_count = 0
		for node in nodes:
			if node.get("type") == "boss":
				boss_count += 1
				assert_eq(node.get("depth"), 9, "ボスは depth 9 にある")
		assert_eq(boss_count, 1, "ボスノードが1つある")

func test_node_connections():
	var gen = MapGenerator.new()
	var map_data = gen.generate(12345, "slime")
	var act = map_data.get("acts", [])[0]
	var nodes = act.get("nodes", [])

	# depth 0 ノードは connections が空
	for node in nodes:
		if node.get("depth") == 0:
			assert_eq(node.get("connections", []).size(), 0, "depth 0 は接続元なし")

	# depth 1以降のノードは connections が存在
	for node in nodes:
		if node.get("depth") > 0:
			var conns = node.get("connections", [])
			assert_gt(conns.size(), 0, "depth 1以降は接続元がある")

func test_connectivity_validation():
	var gen = MapGenerator.new()
	var map_data = gen.generate(12345, "slime")

	for act in map_data.get("acts", []):
		var is_valid = gen.validate_connectivity(act)
		assert_true(is_valid, "Act %d の接続が有効" % act.get("act_num"))

func test_forced_shop_and_event():
	var gen = MapGenerator.new()
	var map_data = gen.generate(12345, "slime")

	for act in map_data.get("acts", []):
		var nodes = act.get("nodes", [])
		var has_shop = false
		var has_event = false

		for node in nodes:
			if node.get("type") == "shop":
				has_shop = true
			if node.get("type") == "event":
				has_event = true

		assert_true(has_shop, "Act %d に shop が存在" % act.get("act_num"))
		assert_true(has_event, "Act %d に event が存在" % act.get("act_num"))

func test_reproducibility():
	var gen1 = MapGenerator.new()
	var gen2 = MapGenerator.new()

	var map1 = gen1.generate(99999, "beast")
	var map2 = gen2.generate(99999, "beast")

	var act1 = map1.get("acts", [])[0]
	var act2 = map2.get("acts", [])[0]

	var nodes1 = act1.get("nodes", [])
	var nodes2 = act2.get("nodes", [])

	assert_eq(nodes1.size(), nodes2.size(), "同じシードで同じノード数")

	for i in range(nodes1.size()):
		var n1 = nodes1[i]
		var n2 = nodes2[i]
		assert_eq(n1.get("type"), n2.get("type"), "同じシードで同じノード種別")
		assert_eq(n1.get("depth"), n2.get("depth"), "同じシードで同じdepth")
		assert_eq(n1.get("lane"), n2.get("lane"), "同じシードで同じlane")
