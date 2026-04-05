# EffectDB.gd
# 効果テーブル定義（静的辞書。インスタンス不要）
# class_name を使わない（循環参照回避：EffectExecutorからload()で参照）
extends RefCounted

const EFFECTS: Dictionary = {
	# ---- バフ付与 ----
	"lifesteal_apply":  {"type": "buff_apply",  "buff": "lifesteal",  "stacks": 5, "display": "吸血付与"},
	"armor_apply":      {"type": "buff_apply",  "buff": "armor",      "stacks": 1, "display": "鎧付与"},
	"regen_apply":      {"type": "buff_apply",  "buff": "regen",      "stacks": 1, "display": "リジェネ付与"},
	"atk_buff_apply":   {"type": "buff_apply",  "buff": "atk",        "stacks": 2, "display": "ATKバフ"},
	"spd_buff_apply":   {"type": "buff_apply",  "buff": "spd",        "stacks": 3, "display": "SPDバフ"},

	# ---- デバフ付与 ----
	"burn_apply":       {"type": "debuff_apply", "status": "burn",      "stacks": 2, "display": "火傷付与"},
	"freeze_apply":     {"type": "debuff_apply", "status": "freeze",    "stacks": 3, "display": "凍結付与"},
	"poison_apply":     {"type": "debuff_apply", "status": "poison",    "stacks": 1, "display": "毒付与"},
	"paralysis_apply":  {"type": "debuff_apply", "status": "paralysis", "stacks": 1, "display": "麻痺付与"},

	# ---- ダメージ ----
	"direct_damage":    {"type": "damage",        "factor": 1.0,                                "display": "直接ダメージ"},
	"chain_damage":     {"type": "damage",        "target": "adjacent_rows", "factor": 0.5,    "display": "連鎖ダメージ"},
	"big_damage":       {"type": "damage",        "target": "enemy_max_hp",  "factor": 3.0,    "display": "単体大ダメージ"},
	"hp_cost":          {"type": "self_damage",   "factor": 0.30, "min_hp": 1,                 "display": "HP代償"},

	# ---- 回復 ----
	"heal_pct":         {"type": "heal",          "factor": 0.15,                               "display": "HP回復"},

	# ---- ATK変化 ----
	"atk_accumulate":   {"type": "atk_permanent", "amount": 2, "cap": 10,                      "display": "ATK累積"},

	# ---- 召喚 ----
	"summon_same_row":  {"type": "summon",        "range": "same_row", "unit_id": "スライム", "chain": false, "display": "追加召喚"},
	"summon_low_cost":  {"type": "summon_low_cost",                                             "display": "急召"},

	# ---- デッキ操作 ----
	"deck_add_self":    {"type": "deck_add",      "unit_id": "self", "count": 1,               "display": "デッキ追加"},
	"draw_cards":       {"type": "draw",          "count": 2,                                   "display": "ドロー"},
	"mana_boost":       {"type": "mana_add",      "amount": 3,                                  "display": "マナ回復"},

	# ---- バフ奪取 ----
	"steal_buffs":      {"type": "steal_buffs",   "factor": 1.5,                               "display": "バフ奪取"},
	"steal_all_buffs":  {"type": "steal_all_buffs", "factor": 1.5,                             "display": "全バフ奪取"},

	# ---- 位置移動 ----
	"force_front":      {"type": "move",          "dest": "front",                              "display": "最前列突撃"},

	# ---- 復活 ----
	"self_revive":      {"type": "revive",        "hp": 5, "delay": 3.0, "range": "same_row",  "display": "自己再起"},
	"revive_undead":    {"type": "revive_ally",   "race": "アンデッド", "hp": "full",          "display": "魂の器"},

	# ---- スキルフラグ（ON/OFF） ----
	"snipe":            {"type": "skill_flag",    "flags": {"_can_attack_from_back": true, "_back_target_rear": true, "_back_no_on_hit": true},  "display": "狙撃"},
	"support_fire":     {"type": "skill_flag",    "flags": {"_can_attack_from_back": true, "_can_attack_from_mid": true, "_back_no_on_hit": true}, "display": "支援攻撃"},
	"support_revive":   {"type": "skill_flag",    "flags": {"_support_revive": true},                                                             "display": "再起付与"},
	"flying":           {"type": "skill_flag",    "flags": {"_is_flying": true},                                                                  "display": "飛行"},
	"impact":           {"type": "skill_flag",    "flags": {"_has_impact": true},                                                                 "display": "衝撃"},
	"penetrate":        {"type": "skill_flag",    "flags": {"_has_penetrate": true},                                                              "display": "貫通"},
	"big_penetrate":    {"type": "skill_flag",    "flags": {"_has_big_penetrate": true},                                                          "display": "大貫通"},

	# ---- マナ妨害 ----
	"enemy_mana_drain": {"type": "mana_drain",    "per_unit": -0.1,                             "display": "マナ妨害"},

	# ---- デバフ波及 ----
	"debuff_spread":    {"type": "debuff_spread",                                               "display": "デバフ波及"},

	# ---- 呪文専用 ----
	"inject_status_card":  {"type": "inject_status",      "card_id": "",                        "display": "異常カード注入"},
	"cost_reduction":      {"type": "cost_reduce",        "count": 3, "amount": 1,             "display": "コスト軽減"},
	"spd_buff_all":        {"type": "temp_buff_all",      "buff": "spd", "factor": 0.5, "duration": 5.0, "display": "全体SPDバフ"},
	"atk_hp_boost":        {"type": "stat_boost",         "atk": 5, "hp": 10,                  "display": "個体強化"},
	"all_stat_boost":      {"type": "stat_boost",         "atk": 2, "hp": 10,                  "display": "全体強化"},
	"remove_status_card":  {"type": "deck_remove_status",                                       "display": "異常カード除去"},
	"front_status_both":   {"type": "front_status",       "status": "", "stacks": 2, "both_sides": true, "display": "前列状態付与"},
	"front_damage_status": {"type": "front_damage_status","damage": 10, "status": "paralysis", "stacks": 2, "display": "前列ダメージ+状態"},
	"all_enemy_damage":    {"type": "all_enemy_damage",   "damage": 8,                          "display": "全体ダメージ"},
	"all_enemy_burn":      {"type": "all_enemy_debuff",   "status": "burn",   "stacks": 3,     "display": "全体デバフ"},
	"all_enemy_freeze":    {"type": "all_enemy_debuff",   "status": "freeze", "stacks": 8,     "display": "全体デバフ"},
	"all_enemy_debuff":    {"type": "all_enemy_debuff",   "status": "burn",   "stacks": 2,     "display": "全体デバフ"},
	"move_random":         {"type": "move_enemy_random",                                        "display": "ランダム移動"},
	"swap_front_back":     {"type": "swap_front_back",                                          "display": "前後入替"},
	"push_to_back":        {"type": "push_to_back",                                             "display": "押し込み"},
	"delay_enemy_spawn":   {"type": "delay_spawn",        "seconds": 3,                         "display": "召喚妨害"},
	"randomize_enemy_col": {"type": "randomize_col",                                            "display": "配置崩し"},
	"slime_global_buff":   {"type": "race_buff",          "race": "スライム", "atk_pct": 0.5,  "display": "スライム全体強化"},
	"crystallize":         {"type": "crystallize",                                              "display": "結晶化"},
	"critical":            {"type": "critical",           "first_only": true, "factor": 2.0,   "display": "クリティカル"},

	# ---- ラージ/ファット専用 ----
	"synthesis_boost":     {"type": "deck_add",           "unit_id": "self", "count": 1,       "display": "合成促進"},
	"shuffle_deck":        {"type": "shuffle_deck",                                            "display": "デッキシャッフル"},
	"split_on_death":      {"type": "summon_on_death",                                          "display": "分裂"},

	# ---- 盤面効果 ----
	"tile_curse":        {"type": "tile_effect", "trigger": "on_stay",  "display": "呪われた地", "damage_mult": 1.5},
	"tile_fire":         {"type": "tile_effect", "trigger": "on_tick",  "display": "炎床",       "damage": 3, "tick_interval": 1.0},
	"tile_beast_forest": {"type": "tile_effect", "trigger": "on_stay",  "display": "獣の森",     "race": "獣", "atk_bonus": 3},
	"tile_fortress":     {"type": "tile_effect", "trigger": "on_enter", "display": "鉄壁の地",   "armor_stacks": 2},
	"tile_crack":        {"type": "tile_effect", "trigger": "on_leave", "display": "ヒビ床",     "transform_to": "tile_hole"},
	"tile_poison":       {"type": "tile_effect", "trigger": "on_tick",  "display": "毒沼",       "status": "poison", "stacks": 2, "tick_interval": 1.0},
	"tile_hole":         {"type": "tile_effect", "trigger": "on_enter", "display": "穴",         "block_summon": true, "duration": 5.0},

	# ---- 盤面効果設置（呪文用） ----
	"tile_set_all":      {"type": "tile_set",   "scope": "all",    "tile_id": "",              "display": "全マス盤面効果"},
	"tile_set_enemy":    {"type": "tile_set",   "scope": "enemy",  "tile_id": "",              "display": "敵盤面効果"},
	"tile_set_ally":     {"type": "tile_set",   "scope": "ally",   "tile_id": "",              "display": "味方盤面効果"},
}
