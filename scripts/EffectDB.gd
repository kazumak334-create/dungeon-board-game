# EffectDB.gd
# 効果テーブル定義（静的辞書。インスタンス不要）
class_name EffectDB
extends RefCounted

const EFFECTS: Dictionary = {
	# ---- バフ付与 ----
	"lifesteal_apply":  {"type": "buff_apply",  "buff": "lifesteal",  "stacks": 5},
	"penetrate_apply":  {"type": "buff_apply",  "buff": "penetrate",  "stacks": 5},
	"armor_apply":      {"type": "buff_apply",  "buff": "armor",      "stacks": 1},
	"regen_apply":      {"type": "buff_apply",  "buff": "regen",      "stacks": 1},
	"atk_buff_apply":   {"type": "buff_apply",  "buff": "atk",        "stacks": 2},
	"spd_buff_apply":   {"type": "buff_apply",  "buff": "spd",        "stacks": 3},

	# ---- デバフ付与 ----
	"burn_apply":       {"type": "debuff_apply", "status": "burn",      "stacks": 2},
	"freeze_apply":     {"type": "debuff_apply", "status": "freeze",    "stacks": 3},
	"poison_apply":     {"type": "debuff_apply", "status": "poison",    "stacks": 1},
	"paralysis_apply":  {"type": "debuff_apply", "status": "paralysis", "stacks": 1},

	# ---- ダメージ ----
	"direct_damage":    {"type": "damage",        "factor": 1.0},
	"chain_damage":     {"type": "damage",        "target": "adjacent_rows", "factor": 0.5},
	"big_damage":       {"type": "damage",        "target": "enemy_max_hp",  "factor": 3.0},
	"hp_cost":          {"type": "self_damage",   "factor": 0.30, "min_hp": 1},

	# ---- 回復 ----
	"heal_pct":         {"type": "heal",          "factor": 0.15},

	# ---- ATK変化 ----
	"atk_accumulate":   {"type": "atk_permanent", "amount": 2, "cap": 10},

	# ---- 召喚 ----
	"summon_same_row":  {"type": "summon",        "range": "same_row", "unit_id": "スライム", "chain": false},
	"summon_low_cost":  {"type": "summon_low_cost"},

	# ---- デッキ操作 ----
	"deck_add_self":    {"type": "deck_add",      "unit_id": "self", "count": 1},
	"draw_cards":       {"type": "draw",          "count": 2},
	"mana_boost":       {"type": "mana_add",      "amount": 3},

	# ---- バフ奪取 ----
	"steal_buffs":      {"type": "steal_buffs",   "factor": 1.5},
	"steal_all_buffs":  {"type": "steal_all_buffs", "factor": 1.5},

	# ---- 位置移動 ----
	"force_front":      {"type": "move",          "dest": "front"},

	# ---- 復活 ----
	"self_revive":      {"type": "revive",        "hp": 5, "delay": 3.0, "range": "same_row"},
	"revive_undead":    {"type": "revive_ally",   "race": "アンデッド", "hp": "full"},

	# ---- スキルフラグ（ON/OFF） ----
	"snipe":            {"type": "skill_flag",    "flags": {"_can_attack_from_back": true, "_back_target_rear": true, "_back_no_on_hit": true}},
	"support_fire":     {"type": "skill_flag",    "flags": {"_can_attack_from_back": true, "_can_attack_from_mid": true, "_back_no_on_hit": true}},
	"support_revive":   {"type": "skill_flag",    "flags": {"_support_revive": true}},

	# ---- マナ妨害 ----
	"enemy_mana_drain": {"type": "mana_drain",    "per_unit": -0.1},

	# ---- デバフ波及 ----
	"debuff_spread":    {"type": "debuff_spread"},

	# ---- 呪文専用 ----
	"inject_status_card":  {"type": "inject_status",      "card_id": ""},
	"cost_reduction":      {"type": "cost_reduce",        "count": 3, "amount": 1},
	"spd_buff_all":        {"type": "temp_buff_all",      "buff": "spd", "factor": 0.5, "duration": 5.0},
	"atk_hp_boost":        {"type": "stat_boost",         "atk": 5, "hp": 10},
	"all_stat_boost":      {"type": "stat_boost",         "atk": 2, "hp": 10},
	"remove_status_card":  {"type": "deck_remove_status"},
	"front_status_both":   {"type": "front_status",       "status": "", "stacks": 2, "both_sides": true},
	"front_damage_status": {"type": "front_damage_status","damage": 10, "status": "paralysis", "stacks": 2},
	"all_enemy_damage":    {"type": "all_enemy_damage",   "damage": 8},
	"all_enemy_burn":      {"type": "all_enemy_debuff",   "status": "burn",   "stacks": 3},
	"all_enemy_freeze":    {"type": "all_enemy_debuff",   "status": "freeze", "stacks": 8},
	"all_enemy_debuff":    {"type": "all_enemy_debuff",   "status": "burn",   "stacks": 2},
	"move_random":         {"type": "move_enemy_random"},
	"swap_front_back":     {"type": "swap_front_back"},
	"push_to_back":        {"type": "push_to_back"},
	"delay_enemy_spawn":   {"type": "delay_spawn",        "seconds": 3},
	"randomize_enemy_col": {"type": "randomize_col"},
	"slime_global_buff":   {"type": "race_buff",          "race": "スライム", "atk_pct": 0.5},
	"crystallize":         {"type": "crystallize"},
	"critical":            {"type": "critical",           "first_only": true, "factor": 2.0},
}
