extends SceneTree

func _init():
	var MapGen = load("res://scripts/MapGenerator.gd")
	var gen = MapGen.new()

	print("=== マップ孤立ノードチェック ===")
	var test_seeds = [12345, 99999, 42, 777, 20260410]

	for seed_val in test_seeds:
		print("\n[Seed: %d]" % seed_val)
		var map_data = gen.generate(seed_val, "slime")

		for act in map_data.get("acts", []):
			var act_num = act.get("act_num", 0)
			var nodes = act.get("nodes", [])

			# 前のdepthの全ノードから次のdepthに到達可能かチェック
			var max_depth = 0
			for node in nodes:
				if node.get("depth", 0) > max_depth:
					max_depth = node.get("depth", 0)

			var isolated_count = 0
			for depth in range(max_depth):
				var current_depth_nodes = []
				var next_depth_nodes = []

				for node in nodes:
					if node.get("depth", -1) == depth:
						current_depth_nodes.append(node.get("id", ""))
					elif node.get("depth", -1) == depth + 1:
						next_depth_nodes.append(node)

				# 各current_depthノードから次のdepthに行けるかチェック
				for current_id in current_depth_nodes:
					var has_path = false
					for next_node in next_depth_nodes:
						var conns = next_node.get("connections", [])
						if current_id in conns:
							has_path = true
							break

					if not has_path:
						print("  ⚠ 孤立検出: Act%d depth%d ノード[%s] → depth%d への接続なし" % [act_num, depth, current_id, depth + 1])
						isolated_count += 1

			if isolated_count == 0:
				print("  ✓ Act%d: 孤立ノードなし" % act_num)
			else:
				print("  ✗ Act%d: 孤立ノード %d個" % [act_num, isolated_count])

	print("\n=== チェック完了 ===")
	quit()
