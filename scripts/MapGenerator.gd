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

# Act構造（新仕様: グリッドベース）
const ACTS_COUNT = 3
const GRID_COLS = 10  # 列数: 0-9
const GRID_ROWS = 10  # 行数: 0-9
const MIN_NODES = 2   # 各列の最小ノード数
const MAX_NODES = 6   # 各列の最大ノード数
const START_NODES_COUNT = 3  # 列0の開始ノード数
const BOSS_NODES_COUNT = 3   # 列9のボスノード数

# 列ごとのノードタイプ出現率（グリッドベース）
const COL_NODE_TYPES = {
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
	# グリッドベース生成（Python版準拠）
	var node_counts = _generate_node_counts()
	var node_grid = _place_nodes(node_counts)
	var connections = _generate_all_connections(node_grid)

	# ノードデータ構築
	var nodes: Array = []
	var node_id_counter: int = 0
	var boss_candidates = _pick_boss_candidates(act_num, race_theme, BOSS_NODES_COUNT)

	for col in range(GRID_COLS):
		for row in node_grid[col]:
			var nid = "act%d_c%d_r%d" % [act_num, col, row]
			var node_data = {
				"id": nid,
				"col": col,
				"row": row,
				"type": _pick_node_type(col),
				"connections": [],
			}

			# ボスノードの場合は追加データ
			if col == GRID_COLS - 1:
				var boss_idx = node_grid[col].find(row)
				node_data["boss_candidates"] = [boss_candidates[boss_idx]] if boss_idx < boss_candidates.size() else []

			nodes.append(node_data)
			node_id_counter += 1

	# 接続データを設定
	for col in range(connections.size()):
		for conn in connections[col]:
			var row_a = conn[0]
			var row_b = conn[1]

			# col+1列のrow_bノードの接続リストに col列のrow_aノードIDを追加
			var target_id = "act%d_c%d_r%d" % [act_num, col, row_a]
			var dest_id = "act%d_c%d_r%d" % [act_num, col + 1, row_b]

			# dest_idのノードを探して接続を追加
			for node in nodes:
				if node["id"] == dest_id:
					if not node["connections"].has(target_id):
						node["connections"].append(target_id)
					break

	print("[MapGenerator] Act%d生成完了: %d列, %dノード" % [act_num, GRID_COLS, nodes.size()])
	return {
		"act_num": act_num,
		"nodes": nodes,
		"boss_candidates": boss_candidates,
	}

# 層ごとのノードタイプを重み付きランダムで選択
func _pick_node_type(col: int) -> String:
	var weights = COL_NODE_TYPES.get(col, {"battle": 100})
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

# グリッドベース生成関数群（Python版準拠）

func _generate_node_counts() -> Array:
	"""各列のノード数を抽選"""
	var counts = []
	for col in range(GRID_COLS):
		if col == 0 or col == GRID_COLS - 1:
			counts.append(START_NODES_COUNT)  # スタート・ボス固定
		else:
			counts.append(_rng.randi_range(MIN_NODES, MAX_NODES))
	return counts

func _place_nodes(counts: Array) -> Array:
	"""各列のノードをランダムな行に配置（Y座標小さい順ソート済み）"""
	var nodes = []
	for col in range(GRID_COLS):
		var count = counts[col]
		var rows = range(GRID_ROWS)
		var rows_arr: Array = []
		for r in rows:
			rows_arr.append(r)

		# シャッフル（RNGを使用）
		for i in range(rows_arr.size() - 1, 0, -1):
			var j = _rng.randi_range(0, i)
			var tmp = rows_arr[i]
			rows_arr[i] = rows_arr[j]
			rows_arr[j] = tmp

		# 先頭count個を選択してソート
		var selected = rows_arr.slice(0, count)
		selected.sort()
		nodes.append(selected)
	return nodes

func _is_crossing(conn1: Array, conn2: Array) -> bool:
	"""交差判定"""
	var a1 = conn1[0]
	var b1 = conn1[1]
	var a2 = conn2[0]
	var b2 = conn2[1]
	return (a1 < a2 and b1 > b2) or (a1 > a2 and b1 < b2)

func _get_valid_connections(rows_a: Array, rows_b: Array, max_conn: int) -> Array:
	"""交差なし接続生成（途切れ禁止）"""
	var result = []

	# Step A: rows_aの全ノードに最低1本（最近接へ）
	for row_a in rows_a:
		var best = rows_b[0]
		for r in rows_b:
			if abs(r - row_a) < abs(best - row_a):
				best = r
		var conn = [row_a, best]
		var ok = true
		for e in result:
			if _is_crossing(conn, e):
				ok = false
				break
		if ok and not result.has(conn):
			result.append(conn)

	# Step B: rows_bの全ノードに最低1本（途切れ禁止）
	for row_b in rows_b:
		var already = false
		for c in result:
			if c[1] == row_b:
				already = true
				break
		if already:
			continue
		var best = rows_a[0]
		for r in rows_a:
			if abs(r - row_b) < abs(best - row_b):
				best = r
		var conn = [best, row_b]
		var ok = true
		for e in result:
			if _is_crossing(conn, e):
				ok = false
				break
		if ok and not result.has(conn):
			result.append(conn)

	# Step C: 上限まで追加接続（交差しない候補からランダムに）
	var candidates = []
	for a in rows_a:
		for b in rows_b:
			candidates.append([a, b])

	# シャッフル（RNGを使用）
	for i in range(candidates.size() - 1, 0, -1):
		var j = _rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	for conn in candidates:
		if result.size() >= max_conn:
			break
		if result.has(conn):
			continue
		var ok = true
		for e in result:
			if _is_crossing(conn, e):
				ok = false
				break
		if ok:
			result.append(conn)

	return result

func _generate_all_connections(nodes: Array) -> Array:
	"""全列間の接続生成"""
	var all_connections = []
	for col in range(GRID_COLS - 1):
		var rows_a = nodes[col]
		var rows_b = nodes[col + 1]
		var max_conn = int(floor(float(rows_a.size()) * 1.5))
		var conns = _get_valid_connections(rows_a, rows_b, max_conn)
		all_connections.append(conns)
	return all_connections

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

# 接続が有効か検証（col 0 から boss ノードまでパスが通るか）
func validate_connectivity(act_data: Dictionary) -> bool:
	var nodes: Array = act_data.get("nodes", [])
	if nodes.is_empty():
		return false

	# BFS: col 0 ノードからbossまで到達できるか
	# 逆方向（接続先→起点）でリバースグラフを構築
	var reachable: Dictionary = {}
	for node in nodes:
		if node.get("col", -1) == 0:
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
