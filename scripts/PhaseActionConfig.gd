# PhaseActionConfig.gd
# バランス値一元管理。ここだけ変えれば全体に反映される。
class_name PhaseActionConfig
extends RefCounted

# --- SHOP リロールコスト ---
# index=使用回数（3回目以降は末尾固定）
const REROLL_COSTS: Array = [0, 30, 50]

# --- NEXT_EI 偵察コスト ---
const SCOUT_BASE_COST: Dictionary = {1: 20, 2: 35, 3: 55}  # キー=Act番号
const SCOUT_COST_PER_USE: int = 20  # 使用のたびに加算

# --- SHOP 交渉 ---
const NEGOTIATE_SUCCESS_RATE: float = 0.6
const NEGOTIATE_DISCOUNT: float = 0.30   # 成功時の値引き率（1.0 - この値が乗数）
const NEGOTIATE_PENALTY_RARITY_SHIFT: int = 1  # 失敗時にレア度を下げるステップ数

# --- SCRATCH 覗き見 ---
const PEEK_COST: int = 20

# --- レアリティ重みテーブル（ペナルティ適用後）---
const RARITY_WEIGHTS_NORMAL: Dictionary   = {"common": 70, "uncommon": 20, "rare": 8, "epic": 2}
const RARITY_WEIGHTS_PENALIZED: Dictionary = {"common": 85, "uncommon": 12, "rare": 3, "epic": 0}

static func get_reroll_cost(use_count: int) -> int:
	return REROLL_COSTS[min(use_count, REROLL_COSTS.size() - 1)]

static func get_scout_cost(act: int, use_count: int) -> int:
	var base: int = SCOUT_BASE_COST.get(act, SCOUT_BASE_COST[1])
	return base + use_count * SCOUT_COST_PER_USE
