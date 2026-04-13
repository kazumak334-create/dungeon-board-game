# MapGenerator.gd
# マップ自動生成アルゴリズム
# 3 Act × 10ノード、横方向StS風分岐、3レーンスタート、ボス2-3体選択
extends RefCounted
class_name MapGenerator

# ノード種別の重み（ConfigLoader経由で取得）
static func get_node_weights() -> Dictionary:
	return ConfigLoader.get_value("map_generation", "node_weights", {
		"battle": 50,
		"elite": 15,
		"gather": 15,
		"shop": 10,
		"event": 10,
	})

# レストノードの深さと確率
static func get_rest_node_depths() -> Array:
	return ConfigLoader.get_value("map_generation", "rest_node_depths", [4, 5, 6])

static func get_rest_node_chance() -> float:
	return ConfigLoader.get_value("map_generation", "rest_node_chance", 0.2)

# Act構造
const ACTS_COUNT = 3
const NODES_PER_ACT = 10
const START_LANES = 3
const MAX_LANES = 6  # 各depthの最大ノード数
const MAX_CONNECTIONS = 2  # 各ノードの最大接続数（1ノードから次の層への接続は最大2本）
const BOSS_CANDIDATES = 3  # 各Act終端のボス候補数

# 再現性用RNG
var _rng: RandomNumberGenerator = null

func generate(seed_value: int, race_theme: String = "slime") -> Dictionary:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

	var acts = []
	for act_idx in range(ACTS_COUNT):
		var act_data = _generate_act(act_idx + 1, race_theme)
		acts.append(act_data)

	return {
		"seed": seed_value,
		"race_theme": race_theme,
		"acts": acts,
		"current_act": 1,
		"current_node": "",
	}

func _generate_act(act_num: int, race_theme: String) -> Dictionary:
	# depth 0: 3レーン固定スタート
	# depth 1-8: ランダム1〜3ノード
	# depth 9: ボス候補（2〜3体）
	var nodes: Array = []
	var node_id_counter: int = 0

	# depth 0: 3つの開始ノード（全てbattle固定）
	var prev_depth_ids: Array = []
	for lane in range(START_LANES):
		var nid = "act%d_d0_n%d" % [act_num, node_id_counter]
		node_id_counter += 1
		nodes.append({
			"id": nid,
			"depth": 0,
			"lane": lane,
			"type": "battle",
			"connections": [],
		})
		prev_depth_ids.append(nid)

	# 強制配置トラッキング
	var has_shop: bool = false
	var has_event: bool = false

	# depth 1〜8: ランダム生成
	for depth in range(1, NODES_PER_ACT - 1):
		# ノード数をdepthに応じて調整（序盤は少なめ、中盤は多め）
		var lane_count: int
		if depth <= 2:
			lane_count = _rng.randi_range(2, 4)  # 序盤: 2-4ノード
		elif depth >= 7:
			lane_count = _rng.randi_range(2, 4)  # 終盤: 2-4ノード
		else:
			lane_count = _rng.randi_range(3, MAX_LANES)  # 中盤: 3-6ノード

		var current_depth_ids: Array = []

		for lane in range(lane_count):
			# 強制配置ロジック（深さ順に判定: event→shop→rest）
			var node_type: String
			if not has_event and depth >= 2 and depth <= 4 and lane == 0:
				# depth 2-4 に event 1個を強制配置
				node_type = "event"
				has_event = true
			elif not has_shop and depth >= 3 and depth <= 5 and lane == 0:
				# depth 3-5 に shop 1個を強制配置
				node_type = "shop"
				has_shop = true
			elif depth in get_rest_node_depths() and lane == 0 and _rng.randf() < get_rest_node_chance():
				# depth 4-6 で確率でrestノード配置
				node_type = "rest"
			else:
				node_type = _weighted_node_type_by_depth(depth)

			var nid = "act%d_d%d_n%d" % [act_num, depth, node_id_counter]
			node_id_counter += 1

			# 接続: 隣接列優先で前のdepthノードから最大MAX_CONNECTIONS個に接続
			var conns: Array = []
			# 前ノードを距離順にソート（現在のlaneに近い順）
			var prev_with_distance: Array = []
			for pid in prev_depth_ids:
				var prev_node = _find_node(nodes, pid)
				var prev_lane = prev_node.get("lane", 0)
				var distance = abs(lane - prev_lane)
				prev_with_distance.append({"id": pid, "distance": distance})
			# 距離でソート（近い順）
			prev_with_distance.sort_custom(func(a, b): return a["distance"] < b["distance"])

			# 最大MAX_CONNECTIONS個の近いノードに接続
			var connection_count = min(MAX_CONNECTIONS, prev_with_distance.size())
			for i in range(connection_count):
				conns.append(prev_with_distance[i]["id"])

			# 孤立防止: 接続がなければ最も近いノードと接続
			if conns.is_empty() and prev_with_distance.size() > 0:
				conns.append(prev_with_distance[0]["id"])

			nodes.append({
				"id": nid,
				"depth": depth,
				"lane": lane,
				"type": node_type,
				"connections": conns,
			})
			current_depth_ids.append(nid)

		# 逆方向孤立チェック: 前のdepthの全ノードから次のdepthに行けるか確認
		for pid in prev_depth_ids:
			var has_outgoing = false
			for nid in current_depth_ids:
				var node = _find_node(nodes, nid)
				if pid in node.get("connections", []):
					has_outgoing = true
					break
			# 前のノードから行けるノードがなければ、最も近いノードに接続追加
			if not has_outgoing and current_depth_ids.size() > 0:
				var target_node = _find_node(nodes, current_depth_ids[0])
				if target_node.has("connections"):
					target_node["connections"].append(pid)

		prev_depth_ids = current_depth_ids

	# 強制配置の未配置分を最終ノードに近い場所に追加（depth 5 を使用）
	if not has_shop:
		# 既存ノードのdepth 5 がなければ最後から2番目のdepthに上書き
		for node in nodes:
			if node.get("depth", -1) == 5 and node.get("lane", 0) == 0:
				node["type"] = "shop"
				has_shop = true
				break
	if not has_event:
		for node in nodes:
			if node.get("depth", -1) == 3 and node.get("lane", 0) == 0:
				node["type"] = "event"
				has_event = true
				break

	# depth 9 (NODES_PER_ACT - 1): ボス候補
	var boss_count: int = _rng.randi_range(2, BOSS_CANDIDATES)
	var boss_candidates: Array = _pick_boss_candidates(act_num, race_theme, boss_count)
	var boss_nid = "act%d_boss" % act_num
	nodes.append({
		"id": boss_nid,
		"depth": NODES_PER_ACT - 1,
		"lane": 0,
		"type": "boss",
		"boss_candidates": boss_candidates,
		"connections": prev_depth_ids.duplicate(),
	})

	print("[MapGenerator] Act%d生成完了: %dノード, ボス候補%d体" % [act_num, nodes.size(), boss_candidates.size()])
	return {
		"act_num": act_num,
		"nodes": nodes,
		"boss_candidates": boss_candidates,
	}

# ノード種別を重み付きランダムで選択
func _weighted_node_type() -> String:
	var node_weights = get_node_weights()
	var total: int = 0
	for w in node_weights.values():
		total += w
	var roll: int = _rng.randi_range(0, total - 1)
	var accum: int = 0
	for type in node_weights:
		accum += node_weights[type]
		if roll < accum:
			return type
	return "battle"

# 層ごとのノードタイプ出現率
func _weighted_node_type_by_depth(depth: int) -> String:
	var weights: Dictionary

	if depth <= 2:
		# 層1-2（序盤）: 戦闘70% / イベント20% / ショップ10%
		weights = {
			"battle": 70,
			"event": 20,
			"shop": 10,
		}
	elif depth <= 4:
		# 層3-4（中盤）: 戦闘50% / イベント25% / ショップ15% / 鍛冶10%
		weights = {
			"battle": 50,
			"event": 25,
			"shop": 15,
			"gather": 10,
		}
	else:
		# 層5-6（終盤）: エリート50% / 戦闘30% / イベント20%
		weights = {
			"elite": 50,
			"battle": 30,
			"event": 20,
		}

	var total: int = 0
	for w in weights.values():
		total += w
	var roll: int = _rng.randi_range(0, total - 1)
	var accum: int = 0
	for type in weights:
		accum += weights[type]
		if roll < accum:
			return type
	return "battle"

# ノードIDからノードデータを検索
func _find_node(nodes: Array, nid: String) -> Dictionary:
	for node in nodes:
		if node.get("id", "") == nid:
			return node
	return {}

# ボス候補をCardDB.BOSSESから選択（act/race_theme一致優先）
func _pick_boss_candidates(act_num: int, race_theme: String, count: int) -> Array:
	var candidates: Array = []
	var bosses: Dictionary = CardDB.BOSSES
	# act一致かつrace_theme一致を優先
	var matched: Array = []
	var act_only: Array = []
	for boss_id in bosses:
		var boss = bosses[boss_id]
		if boss.get("act", 0) == act_num:
			if boss.get("race_theme", "") == race_theme:
				matched.append(boss_id)
			else:
				act_only.append(boss_id)
	# 候補プール: race_theme一致 → act一致 → 全体
	var pool: Array = matched + act_only
	if pool.size() == 0:
		for boss_id in bosses:
			pool.append(boss_id)
	# RNGでcount体選択（再現性のため_rngを使って手動シャッフル）
	for i in range(pool.size() - 1, 0, -1):
		var j = _rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for i in range(min(count, pool.size())):
		candidates.append(pool[i])
	return candidates

# 接続が有効か検証（depth 0 から boss ノードまでパスが通るか）
func validate_connectivity(act_data: Dictionary) -> bool:
	var nodes: Array = act_data.get("nodes", [])
	if nodes.is_empty():
		return false

	# BFS: depth 0 ノードからbossまで到達できるか
	# 逆方向（接続先→起点）でリバースグラフを構築
	var reachable: Dictionary = {}
	for node in nodes:
		if node.get("depth", -1) == 0:
			reachable[node.get("id", "")] = true

	var changed: bool = true
	while changed:
		changed = false
		for node in nodes:
			var nid = node.get("id", "")
			if reachable.has(nid):
				continue
			var conns: Array = node.get("connections", [])
			for conn_id in conns:
				if reachable.has(conn_id):
					reachable[nid] = true
					changed = true
					break

	# bossノードに到達できるか確認
	for node in nodes:
		if node.get("type", "") == "boss":
			if not reachable.has(node.get("id", "")):
				print("[MapGenerator] validate_connectivity: bossノードに到達不可")
				return false
	return true
