# MapGenerator.gd
# マップ自動生成アルゴリズム
# 3 Act × 10ノード、横方向StS風分岐、3レーンスタート、ボス2-3体選択
extends RefCounted
class_name MapGenerator

# ノード種別の重み
const NODE_WEIGHTS = {
	"battle": 50,
	"elite": 15,
	"gather": 15,
	"shop": 10,
	"event": 10,
}

# Act構造
const ACTS_COUNT = 3
const NODES_PER_ACT = 10
const START_LANES = 3
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
	# TODO: 実装（implementer）
	# - 3レーンスタート
	# - 10ノードを分岐ツリーで配置
	# - Act終端にボス2-3体候補
	# - ノード種別は NODE_WEIGHTS で確率決定
	return {
		"act_num": act_num,
		"nodes": [],
		"boss_candidates": [],
	}

# 接続が有効か検証（終端までパスが通るか）
func validate_connectivity(act_data: Dictionary) -> bool:
	# TODO: 実装
	return true
