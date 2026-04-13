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

# Act構造（新仕様）
const ACTS_COUNT = 3
const LAYERS_PER_ACT = 10  # 層数: 0-9
const NODES_PER_LAYER_MIN = 2  # 各層の最小ノード数（層1-8用）
const NODES_PER_LAYER_MAX = 6  # 各層の最大ノード数（層1-8用）
const START_NODES_COUNT = 3  # 層0の開始ノード数
const BOSS_NODES_COUNT = 3  # 層9のボスノード数

# 層ごとのノードタイプ出現率（新仕様）
const LAYER_NODE_TYPES = {
	0: {"battle": 100},  # スタート固定
	1: {"battle": 70, "event": 20, "shop": 10},
	2: {"battle": 60, "event": 20, "shop": 20},
	3: {"battle": 50, "event": 25, "shop": 25},
	4: {"elite": 50, "battle": 30, "event": 20},
	5: {"battle": 50, "shop": 25, "event": 25},
	6: {"elite": 40, "battle": 30, "event": 20, "rest": 10},
	7: {"battle": 40, "elite": 30, "rest": 20, "shop": 10},
	8: {"elite": 60, "battle": 20, "rest": 20},
	9: {"boss": 100},  # ボス固定
}

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
	# 新仕様: 10層（0-9）、層0=3スタート、層1-8=2-6ノード、層9=3ボス
	var nodes: Array = []
	var node_id_counter: int = 0
	var layer_nodes: Array = []  # 各層のノードID配列

	# 層0: スタートノード3個
	var start_nodes: Array = []
	for i in range(START_NODES_COUNT):
		var start_nid = "act%d_L0_n%d" % [act_num, node_id_counter]
		nodes.append({
			"id": start_nid,
			"layer": 0,
			"lane": i,
			"type": _pick_node_type(0),
			"connections": [],
		})
		start_nodes.append(start_nid)
		node_id_counter += 1
	layer_nodes.append(start_nodes)

	# 層1-8: 各層2-6個のノード
	for layer in range(1, LAYERS_PER_ACT - 1):
		var node_count = _rng.randi_range(NODES_PER_LAYER_MIN, NODES_PER_LAYER_MAX)
		var current_layer_nodes: Array = []

		for lane in range(node_count):
			var nid = "act%d_L%d_n%d" % [act_num, layer, node_id_counter]
			node_id_counter += 1

			# 接続生成（交差禁止アルゴリズム）
			var conns: Array = _generate_connections(layer, lane, node_count, layer_nodes)

			nodes.append({
				"id": nid,
				"layer": layer,
				"lane": lane,
				"type": _pick_node_type(layer),
				"connections": conns,
			})
			current_layer_nodes.append(nid)

		layer_nodes.append(current_layer_nodes)

	# 層9: ボスノード3個
	var boss_candidates = _pick_boss_candidates(act_num, race_theme, BOSS_NODES_COUNT)
	for i in range(BOSS_NODES_COUNT):
		var boss_nid = "act%d_L9_boss%d" % [act_num, i]

		# 各ボスノードは前層から接続（交差禁止アルゴリズム）
		var boss_conns: Array = _generate_connections(LAYERS_PER_ACT - 1, i, BOSS_NODES_COUNT, layer_nodes)

		nodes.append({
			"id": boss_nid,
			"layer": LAYERS_PER_ACT - 1,
			"lane": i,
			"type": "boss",
			"boss_candidates": [boss_candidates[i]] if i < boss_candidates.size() else [],
			"connections": boss_conns,
		})

	print("[MapGenerator] Act%d生成完了: %d層, %dノード" % [act_num, LAYERS_PER_ACT, nodes.size()])
	return {
		"act_num": act_num,
		"nodes": nodes,
		"boss_candidates": boss_candidates,
	}

# 層ごとのノードタイプを重み付きランダムで選択
func _pick_node_type(layer: int) -> String:
	var weights = LAYER_NODE_TYPES.get(layer, {"battle": 100})
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

# 交差禁止接続生成アルゴリズム
func _generate_connections(layer: int, lane: int, current_layer_count: int, layer_nodes: Array) -> Array:
	"""
	交差禁止ルールに従って前層ノードとの接続を生成
	- 接続数: min = 前層ノード数, max = floor(前層ノード数 * 1.5)
	- 単調増加インデックス順を維持（交差防止）
	- 孤立防止: 最低1本は接続
	"""
	if layer == 0:
		return []

	var prev_layer_nodes = layer_nodes[layer - 1]
	var prev_count = prev_layer_nodes.size()

	# 接続数を計算
	var min_connections = prev_count
	var max_connections = int(floor(float(prev_count) * 1.5))
	var connection_count = _rng.randi_range(min_connections, max_connections)

	# 現在ノードの位置比率（0.0〜1.0）
	var current_ratio = float(lane) / float(max(1, current_layer_count - 1))

	# 接続候補範囲を計算（交差防止のため範囲を制限）
	var center_idx = int(current_ratio * float(prev_count - 1))
	var half_range = int(ceil(float(connection_count) / 2.0))

	var start_idx = max(0, center_idx - half_range)
	var end_idx = min(prev_count - 1, center_idx + half_range)

	# 接続数が範囲内に収まるように調整
	while (end_idx - start_idx + 1) < connection_count and start_idx > 0:
		start_idx -= 1
	while (end_idx - start_idx + 1) < connection_count and end_idx < prev_count - 1:
		end_idx += 1

	# 接続を生成（単調増加順）
	var conns: Array = []
	var available_indices: Array = []
	for i in range(start_idx, end_idx + 1):
		available_indices.append(i)

	# ランダムに選択（接続数分）
	available_indices.shuffle()
	for i in range(min(connection_count, available_indices.size())):
		conns.append(prev_layer_nodes[available_indices[i]])

	# 孤立防止: 接続が0本なら最も近いノードと接続
	if conns.is_empty() and prev_layer_nodes.size() > 0:
		conns.append(prev_layer_nodes[center_idx])

	return conns

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

# 接続が有効か検証（layer 0 から boss ノードまでパスが通るか）
func validate_connectivity(act_data: Dictionary) -> bool:
	var nodes: Array = act_data.get("nodes", [])
	if nodes.is_empty():
		return false

	# BFS: layer 0 ノードからbossまで到達できるか
	# 逆方向（接続先→起点）でリバースグラフを構築
	var reachable: Dictionary = {}
	for node in nodes:
		if node.get("layer", -1) == 0:
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
