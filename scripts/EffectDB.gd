# EffectDB.gd
# 効果テーブル定義（静的辞書。インスタンス不要）
# class_name を使わない（循環参照回避：EffectExecutorからload()で参照）
extends RefCounted

const EFFECTS: Dictionary = {
	# ---- バフ付与 ----
	"lifesteal_apply":  {"type": "buff_apply",  "buff": "lifesteal",  "stacks": 5, "display": "吸血付与", "texture": "", "anim": "", "sfx": ""},
	"armor_apply":      {"type": "buff_apply",  "buff": "armor",      "stacks": 1, "display": "鎧付与", "texture": "", "anim": "", "sfx": ""},
	"armor_apply_chance": {"type": "buff_apply_chance", "buff": "armor", "stacks": 1, "chance": 0.5, "display": "鎧付与(確率)", "texture": "", "anim": "", "sfx": ""},
	"regen_apply":      {"type": "buff_apply",  "buff": "regen",      "stacks": 1, "display": "リジェネ付与", "texture": "", "anim": "", "sfx": ""},
	"atk_buff_apply":   {"type": "buff_apply",  "buff": "atk",        "stacks": 2, "display": "ATKバフ", "texture": "", "anim": "", "sfx": ""},
	"spd_buff_apply":   {"type": "buff_apply",  "buff": "spd",        "stacks": 3, "display": "SPDバフ", "texture": "", "anim": "", "sfx": ""},

	# ---- デバフ付与 ----
	"burn_apply":       {"type": "debuff_apply", "status": "burn",      "stacks": 2, "display": "火傷付与", "texture": "", "anim": "", "sfx": ""},
	"freeze_apply":     {"type": "debuff_apply", "status": "freeze",    "stacks": 3, "display": "凍結付与", "texture": "", "anim": "", "sfx": ""},
	"poison_apply":     {"type": "debuff_apply", "status": "poison",    "stacks": 1, "display": "毒付与", "texture": "", "anim": "", "sfx": ""},
	"paralysis_apply":  {"type": "debuff_apply", "status": "paralysis", "stacks": 1, "display": "麻痺付与", "texture": "", "anim": "", "sfx": ""},

	# ---- ダメージ ----
	"direct_damage":    {"type": "damage",        "factor": 1.0,                                "display": "直接ダメージ", "texture": "", "anim": "", "sfx": ""},
	"chain_damage":     {"type": "damage",        "target": "adjacent_rows", "factor": 0.5,    "display": "連鎖ダメージ", "texture": "", "anim": "", "sfx": ""},
	"big_damage":       {"type": "damage",        "target": "enemy_max_hp",  "factor": 3.0,    "display": "単体大ダメージ", "texture": "", "anim": "", "sfx": ""},
	"hp_cost":          {"type": "self_damage",   "factor": 0.30, "min_hp": 1,                 "display": "HP代償", "texture": "", "anim": "", "sfx": ""},

	# ---- 回復 ----
	"heal_pct":         {"type": "heal",          "factor": 0.15,                               "display": "HP回復", "texture": "", "anim": "", "sfx": ""},

	# ---- ATK変化 ----
	"atk_accumulate":   {"type": "atk_permanent", "amount": 2, "cap": 10,                      "display": "ATK累積", "texture": "", "anim": "", "sfx": ""},

	# ---- 召喚 ----
	"summon_same_row":  {"type": "summon",        "range": "same_row", "unit_id": "スライム", "chain": false, "display": "追加召喚", "texture": "", "anim": "", "sfx": ""},
	"summon_low_cost":  {"type": "summon_low_cost",                                             "display": "急召", "texture": "", "anim": "", "sfx": ""},

	# ---- デッキ操作 ----
	"deck_add_self":    {"type": "deck_add",      "unit_id": "self", "count": 1,               "display": "デッキ追加", "texture": "", "anim": "", "sfx": ""},
	"draw_cards":       {"type": "draw",          "count": 2,                                   "display": "ドロー", "texture": "", "anim": "", "sfx": ""},
	"mana_boost":       {"type": "mana_add",      "amount": 3,                                  "display": "マナ回復", "texture": "", "anim": "", "sfx": ""},

	# ---- バフ奪取 ----
	"steal_buffs":      {"type": "steal_buffs",   "factor": 1.5,                               "display": "バフ奪取", "texture": "", "anim": "", "sfx": ""},
	"steal_all_buffs":  {"type": "steal_all_buffs", "factor": 1.5,                             "display": "全バフ奪取", "texture": "", "anim": "", "sfx": ""},

	# ---- 位置移動 ----
	"force_front":      {"type": "move",          "dest": "front",                              "display": "最前列突撃", "texture": "", "anim": "", "sfx": ""},

	# ---- 復活 ----
	"self_revive":      {"type": "revive",        "hp": 5, "delay": 3.0, "range": "same_row",  "display": "自己再起", "texture": "", "anim": "", "sfx": ""},
	"revive_undead":    {"type": "revive_ally",   "race": "アンデッド", "hp": "full",          "display": "魂の器", "texture": "", "anim": "", "sfx": ""},

	# ---- スキルフラグ（ON/OFF） ----
	"snipe":            {"type": "skill_flag",    "flags": {"_can_attack_from_back": true, "_back_target_rear": true, "_back_no_on_hit": true},  "display": "狙撃", "texture": "", "anim": "", "sfx": ""},
	"support_fire":     {"type": "skill_flag",    "flags": {"_can_attack_from_back": true, "_can_attack_from_mid": true, "_back_no_on_hit": true}, "display": "支援攻撃", "texture": "", "anim": "", "sfx": ""},
	"support_revive":   {"type": "skill_flag",    "flags": {"_support_revive": true},                                                             "display": "再起付与", "texture": "", "anim": "", "sfx": ""},
	"flying":           {"type": "skill_flag",    "flags": {"_is_flying": true},                                                                  "display": "飛行", "texture": "", "anim": "", "sfx": ""},
	"auto_promote":     {"type": "skill_flag",    "flags": {"_auto_promote": true},                                                               "display": "自動前進", "texture": "", "anim": "", "sfx": ""},
	"impact":           {"type": "skill_flag",    "flags": {"_has_impact": true},                                                                 "display": "衝撃", "texture": "", "anim": "", "sfx": ""},
	"penetrate":        {"type": "skill_flag",    "flags": {"_has_penetrate": true},                                                              "display": "貫通", "texture": "", "anim": "", "sfx": ""},
	"big_penetrate":    {"type": "skill_flag",    "flags": {"_has_big_penetrate": true},                                                          "display": "大貫通", "texture": "", "anim": "", "sfx": ""},

	# ---- マナ妨害 ----
	"enemy_mana_drain": {"type": "mana_drain",    "per_unit": -0.1,                             "display": "マナ妨害", "texture": "", "anim": "", "sfx": ""},

	# ---- デバフ波及 ----
	"debuff_spread":    {"type": "debuff_spread",                                               "display": "デバフ波及", "texture": "", "anim": "", "sfx": ""},

	# ---- 呪文専用 ----
	"inject_status_card":  {"type": "inject_status",      "card_id": "",                        "display": "異常カード注入", "texture": "", "anim": "", "sfx": ""},
	"cost_reduction":      {"type": "cost_reduce",        "count": 3, "amount": 1,             "display": "コスト軽減", "texture": "", "anim": "", "sfx": ""},
	"spd_buff_all":        {"type": "temp_buff_all",      "buff": "spd", "factor": 0.5, "duration": 5.0, "display": "全体SPDバフ", "texture": "", "anim": "", "sfx": ""},
	"atk_hp_boost":        {"type": "stat_boost",         "atk": 5, "hp": 10,                  "display": "個体強化", "texture": "", "anim": "", "sfx": ""},
	"all_stat_boost":      {"type": "stat_boost",         "atk": 2, "hp": 10,                  "display": "全体強化", "texture": "", "anim": "", "sfx": ""},
	"remove_status_card":  {"type": "deck_remove_status",                                       "display": "異常カード除去", "texture": "", "anim": "", "sfx": ""},
	"front_status_both":   {"type": "front_status",       "status": "", "stacks": 2, "both_sides": true, "display": "前列状態付与", "texture": "", "anim": "", "sfx": ""},
	"front_damage_status": {"type": "front_damage_status","damage": 10, "status": "paralysis", "stacks": 2, "display": "前列ダメージ+状態", "texture": "", "anim": "", "sfx": ""},
	"all_enemy_damage":    {"type": "all_enemy_damage",   "damage": 8,                          "display": "全体ダメージ", "texture": "", "anim": "", "sfx": ""},
	"all_enemy_burn":      {"type": "all_enemy_debuff",   "status": "burn",   "stacks": 3,     "display": "全体デバフ", "texture": "", "anim": "", "sfx": ""},
	"all_enemy_freeze":    {"type": "all_enemy_debuff",   "status": "freeze", "stacks": 8,     "display": "全体デバフ", "texture": "", "anim": "", "sfx": ""},
	"all_enemy_debuff":    {"type": "all_enemy_debuff",   "status": "burn",   "stacks": 2,     "display": "全体デバフ", "texture": "", "anim": "", "sfx": ""},
	"move_random":         {"type": "move_enemy_random",                                        "display": "ランダム移動", "texture": "", "anim": "", "sfx": ""},
	"swap_front_back":     {"type": "swap_front_back",                                          "display": "前後入替", "texture": "", "anim": "", "sfx": ""},
	"push_to_back":        {"type": "push_to_back",                                             "display": "押し込み", "texture": "", "anim": "", "sfx": ""},
	"delay_enemy_spawn":   {"type": "delay_spawn",        "seconds": 3,                         "display": "召喚妨害", "texture": "", "anim": "", "sfx": ""},
	"randomize_enemy_col": {"type": "randomize_col",                                            "display": "配置崩し", "texture": "", "anim": "", "sfx": ""},
	"slime_global_buff":   {"type": "race_buff",          "race": "スライム", "atk_pct": 0.5,  "display": "スライム全体強化", "texture": "", "anim": "", "sfx": ""},
	"crystallize":         {"type": "crystallize",                                              "display": "結晶化", "texture": "", "anim": "", "sfx": ""},
	"critical":            {"type": "critical",           "first_only": true, "factor": 2.0,   "display": "クリティカル", "texture": "", "anim": "", "sfx": ""},

	# ---- ラージ/ファット専用 ----
	"synthesis_boost":     {"type": "deck_add",           "unit_id": "self", "count": 1,       "display": "合成促進", "texture": "", "anim": "", "sfx": ""},
	"shuffle_deck":        {"type": "shuffle_deck",                                            "display": "デッキシャッフル", "texture": "", "anim": "", "sfx": ""},
	"split_on_death":      {"type": "summon_on_death",                                          "display": "分裂", "texture": "", "anim": "", "sfx": ""},

	# ---- 盤面効果 ----
	# 盤面効果の共通フィールド:
	#   display     : テキスト表示名（ユニット不在時のセル表示）
	#   unit_label  : ユニットありセルに表示するテキスト（""=非表示）
	#   color       : [r,g,b,a] 色オーバーレイ（[]=色なし。将来テクスチャに置換予定）
	#   race        : 種族フィルタ（""=全種族対象）
	#   texture     : テクスチャID（将来実装。""=未設定→colorフォールバック）
	#   anim        : アニメーションID（将来実装。""=なし）
	#   sfx         : 効果音ID（将来実装。""=なし）
	"tile_curse":        {"type": "tile_effect", "trigger": "on_stay",  "display": "呪われた地", "unit_label": "被ダメ+50%", "damage_mult": 1.5, "color": [0.8, 0.2, 0.6, 0.4], "texture": "", "anim": "", "sfx": ""},
	"tile_thorn":        {"type": "tile_effect", "trigger": "on_enter", "display": "棘",         "unit_label": "棘5dmg",     "damage": 5,                        "color": [0.6, 0.3, 0.0, 0.3], "texture": "", "anim": "", "sfx": ""},
	"tile_beast_forest": {"type": "tile_effect", "trigger": "on_stay",  "display": "獣の森",     "unit_label": "獣ATK+3", "race": "獣", "atk_bonus": 3, "color": [0.0, 0.5, 0.0, 0.3], "texture": "", "anim": "", "sfx": ""},
	"tile_fortress":     {"type": "tile_effect", "trigger": "on_enter", "display": "鉄壁の地",   "unit_label": "鎧+2", "armor_stacks": 2, "color": [0.3, 0.3, 0.6, 0.3], "texture": "", "anim": "", "sfx": ""},
	"tile_crack":        {"type": "tile_effect", "trigger": "on_leave", "display": "╳╳╳\n╳ヒビ╳\n╳╳╳", "unit_label": "─ヒビ─", "transform_to": "tile_hole", "color": [], "texture": "", "anim": "crack_idle", "sfx": "crack"},
	"tile_poison":       {"type": "tile_effect", "trigger": "on_tick",  "display": "毒沼",       "unit_label": "毒+2/s", "status": "poison", "stacks": 2, "tick_interval": 1.0, "color": [0.3, 0.0, 0.4, 0.3], "texture": "", "anim": "poison_bubble", "sfx": "poison_ambient"},
	"tile_hole":         {"type": "tile_effect", "trigger": "on_enter", "display": "■■■\n■ 穴 ■\n■■■", "unit_label": "", "block_summon": true, "duration": 5.0, "color": [0.1, 0.1, 0.1, 0.5], "texture": "", "anim": "", "sfx": ""},

	# ---- 盤面効果設置（呪文用） ----
	"tile_set_all":      {"type": "tile_set",   "scope": "all",    "tile_id": "",              "display": "全マス盤面効果", "texture": "", "anim": "", "sfx": ""},
	"tile_set_enemy":    {"type": "tile_set",   "scope": "enemy",  "tile_id": "",              "display": "敵盤面効果", "texture": "", "anim": "", "sfx": ""},
	"tile_set_ally":     {"type": "tile_set",   "scope": "ally",   "tile_id": "",              "display": "味方盤面効果", "texture": "", "anim": "", "sfx": ""},

	# ---- プレイヤークラススキル ----
	"status_card_cost_reduce": {"type": "cost_modifier",   "card_type": "status_spell", "amount": -1, "display": "異常カードコスト軽減", "texture": "", "anim": "", "sfx": ""},
	"spd_buff_pct":            {"type": "spd_pct_buff",    "pct": 0.2,                               "display": "SPD%バフ", "texture": "", "anim": "", "sfx": ""},
	"low_hp_atk_boost":        {"type": "conditional_buff","threshold": 0.5, "atk": 3,               "display": "逆転バフ", "texture": "", "anim": "", "sfx": ""},
	"hp_pct_boost":            {"type": "hp_pct_buff",     "race": "", "pct": 0.1,                    "display": "HP%バフ", "texture": "", "anim": "", "sfx": ""},

	# ---- アーティファクト用盤面効果 ----
	"tile_grave":        {"type": "tile_effect", "trigger": "on_tick", "tick_interval": 3.0, "display": "墓地", "unit_label": "墓地", "summon_unit": "スケルトン", "color": [0.2, 0.15, 0.1, 0.3], "texture": "", "anim": "", "sfx": ""},

	# ---- アーティファクト用永久効果 ----
	"mana_regen_boost":    {"type": "mana_regen_modify", "pct": 0.2, "display": "マナ加速", "texture": "", "anim": "", "sfx": ""},
	"base_damage_reduce":  {"type": "base_damage_reduce", "pct": 0.1, "display": "本体守護", "texture": "", "anim": "", "sfx": ""},

	# ---- アーティファクト用召喚（random_empty_ally） ----
	"summon_to_empty":   {"type": "summon_to_empty", "unit_id": "スライム", "display": "空きマス召喚", "texture": "", "anim": "", "sfx": ""},

	# ---- スライムカード専用効果 ----
	"max_hp_boost":                {"type": "stat_boost",           "hp": 5,                                     "display": "最大HP上昇", "texture": "", "anim": "", "sfx": ""},
	"max_hp_boost_periodic":       {"type": "stat_boost_periodic",  "hp": 3, "interval": 1.0,                   "display": "継続HP上昇", "texture": "", "anim": "", "sfx": ""},
	"heal":                        {"type": "heal",                 "amount": 10,                                "display": "HP回復", "texture": "", "anim": "", "sfx": ""},
	"heal_periodic":               {"type": "heal_periodic",        "amount": 3, "interval": 1.0,               "display": "継続回復", "texture": "", "anim": "", "sfx": ""},
	"thorn_apply":                 {"type": "buff_apply",           "buff": "thorn", "stacks": 1,               "display": "棘付与", "texture": "", "anim": "", "sfx": ""},
	"shield_apply":                {"type": "buff_apply",           "buff": "shield", "stacks": 5,              "display": "盾付与", "texture": "", "anim": "", "sfx": ""},
	"poison_apply_periodic":       {"type": "debuff_apply_periodic","status": "poison", "stacks": 1, "interval": 2.0, "display": "継続毒付与", "texture": "", "anim": "", "sfx": ""},
	"atk_debuff":                  {"type": "debuff_apply",         "status": "atk_down", "stacks": 2, "duration": 5.0, "display": "ATK低下", "texture": "", "anim": "", "sfx": ""},
	"spd_debuff_by_poison":        {"type": "debuff_conditional",   "status": "spd_down", "factor": 0.1, "duration": 3.0, "display": "毒依存SPD低下", "texture": "", "anim": "", "sfx": ""},
	"poison_amplify":              {"type": "poison_amplify",       "factor": 3.0,                               "display": "毒増幅", "texture": "", "anim": "", "sfx": ""},
	"poison_amplify_all":          {"type": "poison_amplify_all",   "factor": 1.5,                               "display": "全体毒増幅", "texture": "", "anim": "", "sfx": ""},
	"poison_add_if_poisoned":      {"type": "poison_add_conditional", "stacks": 5,                              "display": "条件付き毒追加", "texture": "", "anim": "", "sfx": ""},
	"poison_add_periodic":         {"type": "poison_add_periodic",  "stacks": 5, "interval": 2.0,               "display": "継続毒追加", "texture": "", "anim": "", "sfx": ""},
	"atk_boost_periodic":          {"type": "atk_boost_periodic",   "amount": 0.5, "interval": 1.0,             "display": "継続ATK上昇", "texture": "", "anim": "", "sfx": ""},
	"atk_boost_by_shield":         {"type": "atk_boost_conditional","factor": 1.0,                               "display": "シールド依存ATK", "texture": "", "anim": "", "sfx": ""},
	"shield_accumulate":           {"type": "shield_accumulate",    "amount": 1, "interval": 1.0,               "display": "シールド蓄積", "texture": "", "anim": "", "sfx": ""},
	"mana_drain":                  {"type": "mana_drain",           "amount": 3,                                 "display": "マナ減少", "texture": "", "anim": "", "sfx": ""},
	"mana_drain_periodic":         {"type": "mana_drain_periodic",  "amount": 3, "interval": 2.0,               "display": "継続マナ減少", "texture": "", "anim": "", "sfx": ""},
	"max_hp_boost_by_mana_drained":{"type": "stat_boost_conditional", "factor": 0.05,                           "display": "マナ減少依存HP", "texture": "", "anim": "", "sfx": ""},
	"spell_seal":                  {"type": "spell_seal",           "duration": 3.0,                             "display": "呪文封印", "texture": "", "anim": "", "sfx": ""},
	"heal_seal":                   {"type": "heal_seal",            "duration": 5.0,                             "display": "回復封印", "texture": "", "anim": "", "sfx": ""},

	# ---- 獣カード専用効果 ----
	"same_row_atk_boost":          {"type": "buff_apply",           "buff": "atk", "stacks": 3,                  "display": "同行ATK上昇", "texture": "", "anim": "", "sfx": ""},
	"grant_pierce_to_same_row":    {"type": "grant_skill_flag",     "flags": {"_has_penetrate": true},           "display": "同行貫通付与", "texture": "", "anim": "", "sfx": ""},
	"poison_stack_variable":       {"type": "poison_variable",      "variable": "X",                             "display": "毒X付与", "texture": "", "anim": "", "sfx": ""},
	"poison_stack_increment":      {"type": "variable_increment",   "variable": "X", "amount": 2, "interval": 2.0, "display": "X増加", "texture": "", "anim": "", "sfx": ""},
	"atk_by_empty_slots":          {"type": "atk_by_empty_slots",                                                "display": "空きマス依存ATK", "texture": "", "anim": "", "sfx": ""},
	"heal_pct_front":              {"type": "heal_pct_periodic",    "pct": 0.05, "interval": 2.0,                "display": "前列HP%回復", "texture": "", "anim": "", "sfx": ""},
	"atk_by_thorn_stacks":         {"type": "atk_by_buff_stacks",   "buff": "thorn", "factor": 0.5,              "display": "棘依存ATK", "texture": "", "anim": "", "sfx": ""},
	"on_ally_death_heal_and_buff": {"type": "on_ally_death_trigger","heal_pct": 0.25, "atk_pct": 0.05, "spd_pct": 0.05, "display": "味方死亡時回復・バフ", "texture": "", "anim": "", "sfx": ""},
	"same_row_beast_atk_boost":    {"type": "temp_buff_race",       "race": "獣", "buff": "atk", "pct": 0.02, "duration": 3.0, "display": "同列獣ATK%上昇", "texture": "", "anim": "", "sfx": ""},
	"front_beast_spd_boost":       {"type": "temp_buff_race",       "race": "獣", "buff": "spd", "pct": 0.01, "duration": 1.0, "display": "前列獣SPD%上昇", "texture": "", "anim": "", "sfx": ""},
}
