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
	var layer_nodes: Array = []  # 各層のノードデータ配列

	# 全層のノードを先に生成（接続は後で）
	for layer in range(LAYERS_PER_ACT):
		var node_count: int
		if layer == 0 or layer == LAYERS_PER_ACT - 1:
			node_count = START_NODES_COUNT  # 層0と層9は3個固定
		else:
			node_count = _rng.randi_range(NODES_PER_LAYER_MIN, NODES_PER_LAYER_MAX)

		var current_layer: Array = []
		for lane in range(node_count):
			var nid = "act%d_L%d_n%d" % [act_num, layer, node_id_counter]
			node_id_counter += 1

			var node_data = {
				"id": nid,
				"layer": layer,
				"lane": lane,
				"type": _pick_node_type(layer),
				"connections": [],
			}

			# ボスノードの場合は追加データ
			if layer == LAYERS_PER_ACT - 1:
				var boss_candidates = _pick_boss_candidates(act_num, race_theme, BOSS_NODES_COUNT)
				node_data["boss_candidates"] = [boss_candidates[lane]] if lane < boss_candidates.size() else []

			nodes.append(node_data)
			current_layer.append(node_data)

		layer_nodes.append(current_layer)

	# 層間の接続を生成（交差禁止アルゴリズム）
	for layer in range(1, LAYERS_PER_ACT):
		var prev_layer = layer_nodes[layer - 1]
		var curr_layer = layer_nodes[layer]
		_generate_layer_connections(prev_layer, curr_layer)

	print("[MapGenerator] Act%d生成完了: %d層, %dノード" % [act_num, LAYERS_PER_ACT, nodes.size()])
	return {
		"act_num": act_num,
		"nodes": nodes,
		"boss_candidates": [],  # ボス候補は各ノードに格納済み
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

# 交差禁止接続生成アルゴリズム（新仕様）
func _generate_layer_connections(layer_a: Array, layer_b: Array) -> void:
	"""
	層Aと層Bの間の接続を生成（交差完全禁止）
	- layer_aのi番目ノードは layer_bのi番目〜(i+1)番目ノードにのみ接続
	- 全ノードに最低1本保証（途切れ禁止）
	- 接続上限 = floor(n * 1.5)
	"""
	var n = layer_a.size()
	var m = layer_b.size()
	var max_conn = int(floor(float(n) * 1.5))

	# Step1: 全ノードに最低1本保証
	for i in range(n):
		# layer_aのi番目は layer_bの対応インデックスへ
		var j = int(float(i) / float(n) * float(m))
		j = clamp(j, 0, m - 1)

		if not layer_b[j]["connections"].has(layer_a[i]["id"]):
			layer_b[j]["connections"].append(layer_a[i]["id"])

	# layer_bの全ノードが少なくとも1本受け取るよう保証
	for j in range(m):
		if layer_b[j]["connections"].is_empty():
			# 最も近いlayer_aノードから接続
			var best_i = int(float(j) / float(m) * float(n))
			best_i = clamp(best_i, 0, n - 1)
			layer_b[j]["connections"].append(layer_a[best_i]["id"])

	# Step2: 追加接続（上限まで・交差しない範囲で）
	var total_connections = 0
	for j in range(m):
		total_connections += layer_b[j]["connections"].size()

	# layer_aのi番目からlayer_bのi+1番目への接続のみ追加可能
	for i in range(n - 1):
		if total_connections >= max_conn:
			break
		var j = clamp(i + 1, 0, m - 1)

		if not layer_b[j]["connections"].has(layer_a[i]["id"]):
			layer_b[j]["connections"].append(layer_a[i]["id"])
			total_connections += 1

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
