# RewardTable.gd
# ドロップテーブル: run_depth・エリート混入からレアリティ重みを決定
class_name RewardTable
extends RefCounted

# レアリティ重み定数を関数化（ConfigLoader経由で取得）
static func get_rarity_weights_early() -> Dictionary:
	return ConfigLoader.get_value("drop_table", "rarity_weights_early", {"common": 65, "uncommon": 30, "rare": 5, "epic": 0, "legend": 0, "god": 0})

static func get_rarity_weights_mid() -> Dictionary:
	return ConfigLoader.get_value("drop_table", "rarity_weights_mid", {"common": 40, "uncommon": 40, "rare": 17, "epic": 3, "legend": 0, "god": 0})

static func get_rarity_weights_late() -> Dictionary:
	return ConfigLoader.get_value("drop_table", "rarity_weights_late", {"common": 20, "uncommon": 36, "rare": 30, "epic": 12, "legend": 2, "god": 0})

# ステージ境界
static func get_stage_early_max_depth() -> int:
	return ConfigLoader.get_value("drop_table", "stage_early_max_depth", 3)

static func get_stage_mid_max_depth() -> int:
	return ConfigLoader.get_value("drop_table", "stage_mid_max_depth", 7)

const STAGE_EARLY: int = 0
const STAGE_MID:   int = 1
const STAGE_LATE:  int = 2

# run_depth からベースステージを決定（0=Early, 1=Mid, 2=Late）
static func base_stage(run_depth: int) -> int:
	var stage_early_max = get_stage_early_max_depth()
	var stage_mid_max = get_stage_mid_max_depth()
	if run_depth <= stage_early_max:
		return STAGE_EARLY
	elif run_depth <= stage_mid_max:
		return STAGE_MID
	else:
		return STAGE_LATE

# エリート混入時はステージ+1（上限: Late）
static func effective_stage(run_depth: int, elite_injected: bool) -> int:
	var base = base_stage(run_depth)
	if elite_injected:
		return min(base + 1, STAGE_LATE)
	else:
		return base

# ステージインデックスから重み Dictionary を取得
static func weights_for_stage(stage: int) -> Dictionary:
	match stage:
		STAGE_EARLY:
			return get_rarity_weights_early()
		STAGE_MID:
			return get_rarity_weights_mid()
		STAGE_LATE:
			return get_rarity_weights_late()
		_:
			return get_rarity_weights_early()  # フォールバック

# 便利メソッド: 一発で重みを取得
static func get_weights(run_depth: int, elite_injected: bool) -> Dictionary:
	var stage = effective_stage(run_depth, elite_injected)
	return weights_for_stage(stage)

# ブーストが発生しているか（UI表示判定用）
# ベースステージより実効ステージが上なら true
static func is_boosted(run_depth: int, elite_injected: bool) -> bool:
	var base = base_stage(run_depth)
	var effective = effective_stage(run_depth, elite_injected)
	return effective > base
