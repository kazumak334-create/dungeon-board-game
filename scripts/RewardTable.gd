# RewardTable.gd
# ドロップテーブル: run_depth・エリート混入からレアリティ重みを決定
class_name RewardTable
extends RefCounted

# レアリティ重み定数（企画書値・MVP版）
# MVP: god=0（godカード未実装）、将来 legend=2.5 / god=0.5 に変更可能
const RARITY_WEIGHTS_EARLY = {"common": 65, "uncommon": 30, "rare": 5,  "epic": 0,  "legend": 0, "god": 0}
const RARITY_WEIGHTS_MID   = {"common": 40, "uncommon": 40, "rare": 17, "epic": 3,  "legend": 0, "god": 0}
const RARITY_WEIGHTS_LATE  = {"common": 20, "uncommon": 36, "rare": 30, "epic": 12, "legend": 2, "god": 0}  # uncommon 36 = 合計100調整

# ステージ境界
const STAGE_EARLY_MAX_DEPTH: int = 3  # run_depth <= 3 → Early
const STAGE_MID_MAX_DEPTH:   int = 7  # run_depth <= 7 → Mid
# それ以上は Late

const STAGE_EARLY: int = 0
const STAGE_MID:   int = 1
const STAGE_LATE:  int = 2

# run_depth からベースステージを決定（0=Early, 1=Mid, 2=Late）
static func base_stage(run_depth: int) -> int:
	if run_depth <= STAGE_EARLY_MAX_DEPTH:
		return STAGE_EARLY
	elif run_depth <= STAGE_MID_MAX_DEPTH:
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
			return RARITY_WEIGHTS_EARLY
		STAGE_MID:
			return RARITY_WEIGHTS_MID
		STAGE_LATE:
			return RARITY_WEIGHTS_LATE
		_:
			return RARITY_WEIGHTS_EARLY  # フォールバック

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
