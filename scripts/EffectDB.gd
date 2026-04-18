# EffectDB.gd
# 効果テーブル定義（静的辞書。インスタンス不要）
# class_name を使わない（循環参照回避：EffectExecutorからload()で参照）
extends RefCounted

const EFFECTS: Dictionary = {
	# ---- バフ付与 ----
	"armor_apply":      {"type": "buff_apply",  "buff": "armor",      "stacks": 1, "display": "鎧付与", "texture": "", "anim": "", "sfx": ""},
	"armor_apply_chance": {"type": "buff_apply_chance", "buff": "armor", "stacks": 1, "chance": 0.5, "display": "鎧付与(確率)", "texture": "", "anim": "", "sfx": ""},
	"regen_apply":      {"type": "buff_apply",  "buff": "regen",      "stacks": 1, "display": "リジェネ付与", "texture": "", "anim": "", "sfx": ""},
	"boots_apply":      {"type": "buff_apply",  "buff": "boots",      "stacks": 1, "display": "ブーツ付与", "texture": "", "anim": "", "sfx": ""},
	"sense_apply":      {"type": "buff_apply",  "buff": "sense",      "stacks": 1, "display": "センス付与", "texture": "", "anim": "", "sfx": ""},
	"power_apply":      {"type": "buff_apply",  "buff": "power",      "stacks": 1, "display": "パワー付与", "texture": "", "anim": "", "sfx": ""},
	"spring_apply":     {"type": "buff_apply",  "buff": "spring",     "stacks": 1, "display": "泉付与", "texture": "", "anim": "", "sfx": ""},

	# ---- デバフ付与 ----
	"burn_apply":       {"type": "debuff_apply", "status": "burn",      "stacks": 2, "display": "火傷付与", "texture": "", "anim": "", "sfx": ""},
	"freeze_apply":     {"type": "debuff_apply", "status": "freeze",    "stacks": 3, "display": "凍結付与", "texture": "", "anim": "", "sfx": ""},
	"poison_apply":     {"type": "debuff_apply", "status": "poison",    "stacks": 1, "display": "毒付与", "texture": "", "anim": "", "sfx": ""},
	"curse_apply":      {"type": "debuff_apply", "status": "curse",     "stacks": 1, "display": "呪い付与", "texture": "", "anim": "", "sfx": ""},
	"brand_apply":      {"type": "debuff_apply", "status": "brand",     "stacks": 1, "display": "烙印付与", "texture": "", "anim": "", "sfx": ""},

	# ---- ダメージ ----
	"direct_damage":       {"type": "damage",             "factor": 1.0,                                "display": "直接ダメージ", "texture": "", "anim": "", "sfx": ""},
	"chain_damage":        {"type": "damage",             "target": "adjacent_rows", "factor": 0.5,    "display": "連鎖ダメージ", "texture": "", "anim": "", "sfx": ""},
	"big_damage":          {"type": "damage",             "target": "enemy_max_hp",  "factor": 3.0,    "display": "単体大ダメージ", "texture": "", "anim": "", "sfx": ""},
	"single_enemy_damage": {"type": "single_enemy_damage", "damage": 15,                                "display": "単体ダメージ", "texture": "", "anim": "", "sfx": ""},
	"front_enemy_damage":  {"type": "front_enemy_damage",  "damage": 10,                                "display": "前列ダメージ", "texture": "", "anim": "", "sfx": ""},
	"back_enemy_damage":   {"type": "back_enemy_damage",   "damage": 12,                                "display": "後列ダメージ", "texture": "", "anim": "", "sfx": ""},
	"column_damage":       {"type": "column_damage",       "damage": 15,                                "display": "列ダメージ", "texture": "", "anim": "", "sfx": ""},
	"hp_cost":             {"type": "self_damage",         "factor": 0.30, "min_hp": 1,                 "display": "HP代償", "texture": "", "anim": "", "sfx": ""},

	# ---- 回復 ----
	"heal_pct":         {"type": "heal",          "factor": 0.15,                               "display": "HP回復", "texture": "", "anim": "", "sfx": ""},

	# ---- ATK変化 ----
	"atk_accumulate":   {"type": "atk_permanent", "amount": 2, "cap": 10,                      "display": "ATK累積", "texture": "", "anim": "", "sfx": ""},

	# ---- 召喚 ----
	"summon_same_row":  {"type": "summon",        "range": "same_row", "unit_id": "スライム", "chain": false, "display": "追加召喚", "texture": "", "anim": "", "sfx": ""},
	"summon_low_cost":  {"type": "summon_low_cost",                                             "display": "急召", "texture": "", "anim": "", "sfx": ""},

	# ---- デッキ操作 ----
	"deck_add_self":       {"type": "deck_add",         "unit_id": "self", "count": 1,               "display": "デッキ追加", "texture": "", "anim": "", "sfx": ""},
	"draw_cards":          {"type": "draw",             "count": 2,                                   "display": "ドロー", "texture": "", "anim": "", "sfx": ""},
	"mana_boost":          {"type": "mana_add",         "amount": 3,                                  "display": "マナ回復", "texture": "", "anim": "", "sfx": ""},
	"mana_gain":           {"type": "mana_add",         "amount": 1,                                  "display": "マナ獲得", "texture": "", "anim": "", "sfx": ""},
	"mana_gain_next_turn": {"type": "mana_add_next_turn", "amount": 2,                               "display": "次ターンマナ", "texture": "", "anim": "", "sfx": ""},

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
	"sturdy":           {"type": "skill_flag",    "flags": {"_has_sturdy": true},                                                                 "display": "頑丈", "texture": "", "anim": "", "sfx": ""},
	"overflow_curse":   {"type": "skill_flag",    "flags": {"_has_overflow_curse": true},                                                         "display": "溢れる呪", "texture": "", "anim": "", "sfx": ""},
	"mana_flare":       {"type": "skill_flag",    "flags": {"_has_mana_flare": true},                                                             "display": "マナフレア", "texture": "", "anim": "", "sfx": ""},
	"unyielding":       {"type": "skill_flag",    "flags": {"_has_unyielding": true},                                                             "display": "不撓不屈", "texture": "", "anim": "", "sfx": ""},

	# ---- マナ妨害 ----
	"enemy_mana_drain": {"type": "mana_drain",    "per_unit": -0.1,                             "display": "マナ妨害", "texture": "", "anim": "", "sfx": ""},

	# ---- デバフ波及 ----
	"debuff_spread":    {"type": "debuff_spread",                                               "display": "デバフ波及", "texture": "", "anim": "", "sfx": ""},

	# ---- 呪文専用 ----
	"inject_status_card":  {"type": "inject_status",      "card_id": "",                        "display": "異常カード注入", "texture": "", "anim": "", "sfx": ""},
	"cost_reduction":      {"type": "cost_reduce",        "count": 3, "amount": 1,             "display": "コスト軽減", "texture": "", "anim": "", "sfx": ""},
	"cleanse_all":         {"type": "cleanse_all",                                              "display": "全体浄化", "texture": "", "anim": "", "sfx": ""},
	"spd_buff_all":        {"type": "temp_buff_all",      "buff": "spd", "factor": 0.5, "duration": 5.0, "display": "全体SPDバフ", "texture": "", "anim": "", "sfx": ""},
	"atk_hp_boost":        {"type": "stat_boost",         "atk": 5, "hp": 10,                  "display": "個体強化", "texture": "", "anim": "", "sfx": ""},
	"all_stat_boost":      {"type": "stat_boost",         "atk": 2, "hp": 10,                  "display": "全体強化", "texture": "", "anim": "", "sfx": ""},
	"atk_buff":            {"type": "stat_boost",         "atk": 3,                            "display": "ATK上昇", "texture": "", "anim": "", "sfx": ""},
	"hp_buff":             {"type": "stat_boost",         "hp": 15,                            "display": "HP上昇", "texture": "", "anim": "", "sfx": ""},
	"remove_status_card":  {"type": "deck_remove_status",                                       "display": "異常カード除去", "texture": "", "anim": "", "sfx": ""},
	"front_status_both":   {"type": "front_status",       "status": "", "stacks": 2, "both_sides": true, "display": "前列状態付与", "texture": "", "anim": "", "sfx": ""},
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

	# ---- アンデッドカード専用効果 ----
	"curse_amplify":               {"type": "curse_amplify",        "factor": 2.0,                                   "display": "呪い倍増", "texture": "", "anim": "", "sfx": ""},
	"curse_spread_trigger":        {"type": "curse_spread_trigger", "threshold": 10,                                 "display": "呪い波及", "texture": "", "anim": "", "sfx": ""},
	"curse_additional_damage":     {"type": "curse_damage",         "factor": 1.0,                                   "display": "呪い追加ダメージ", "texture": "", "anim": "", "sfx": ""},
	"curse_total_spd_boost":       {"type": "curse_spd_boost",      "pct": 0.001,                                    "display": "呪い総数SPD上昇", "texture": "", "anim": "", "sfx": ""},
	"curse_reflect":               {"type": "curse_reflect",        "stacks": 1,                                     "display": "呪い返し", "texture": "", "anim": "", "sfx": ""},
	"revive_on_death":             {"type": "revive_on_death",      "hp_pct": 0.1, "delay": 5.0,                     "display": "再生", "texture": "", "anim": "", "sfx": ""},
	"skill_seal_on_ally_death":    {"type": "skill_seal_trigger",   "duration": 5.0,                                 "display": "味方死亡時封印", "texture": "", "anim": "", "sfx": ""},
	"swap_enemy_positions":        {"type": "swap_positions",       "count": 2, "target": "enemy_back",             "display": "敵位置入替", "texture": "", "anim": "", "sfx": ""},
	"buff_transfer":               {"type": "buff_transfer",        "count": 2,                                      "display": "バフ移動", "texture": "", "anim": "", "sfx": ""},
	"buff_steal_transfer":         {"type": "buff_steal_transfer",  "count": 2,                                      "display": "バフ奪取移動", "texture": "", "anim": "", "sfx": ""},
	"synergy_invert":              {"type": "synergy_invert",       "duration": 5.0,                                 "display": "シナジー反転", "texture": "", "anim": "", "sfx": ""},
	"disable_attack_effects":      {"type": "disable_effects",      "effect_type": "on_hit", "duration": 1.0,        "display": "攻撃効果無効", "texture": "", "anim": "", "sfx": ""},
	"trait_seal":                  {"type": "trait_seal",           "duration": 999.0,                               "display": "特性封印", "texture": "", "anim": "", "sfx": ""},
	"trait_seal_all_same":         {"type": "trait_seal_all",       "duration": 999.0,                               "display": "同特性全封印", "texture": "", "anim": "", "sfx": ""},
	"curse_by_damage_taken":       {"type": "curse_by_damage",      "factor": 0.1,                                   "display": "被ダメ呪い", "texture": "", "anim": "", "sfx": ""},
	"curse_apply_adjacent":        {"type": "curse_adjacent",       "stacks": 1,                                     "display": "隣接呪い", "texture": "", "anim": "", "sfx": ""},
	"curse_apply_random":          {"type": "curse_random",         "stacks": 1, "count": 1,                         "display": "ランダム呪い", "texture": "", "anim": "", "sfx": ""},
	"curse_apply_highest":         {"type": "curse_highest",        "stacks": 1,                                     "display": "呪い最多追加", "texture": "", "anim": "", "sfx": ""},
	"curse_apply_front_random":    {"type": "curse_front_random",   "stacks": 1, "count": 1,                         "display": "前列ランダム呪い", "texture": "", "anim": "", "sfx": ""},
	"total_curse_damage":          {"type": "total_curse_damage",   "factor": 1.0,                                   "display": "全体呪いダメージ", "texture": "", "anim": "", "sfx": ""},
	"random_status_apply":         {"type": "random_status",        "count": 1,                                      "display": "ランダム異常", "texture": "", "anim": "", "sfx": ""},
	"curse_apply_battle_start":    {"type": "curse_battle_start",   "stacks": 1, "max_count": 5,                     "display": "戦闘開始呪い", "texture": "", "anim": "", "sfx": ""},
	"swap_ally_rows":              {"type": "swap_ally_rows",       "row1": "front", "row2": "mid",                  "display": "味方列入替", "texture": "", "anim": "", "sfx": ""},
	"swap_ally_random_rows":       {"type": "swap_ally_random",     "count": 2,                                      "display": "味方ランダム入替", "texture": "", "anim": "", "sfx": ""},
	"swap_enemy_random_rows":      {"type": "swap_enemy_random",    "count": 2,                                      "display": "敵ランダム入替", "texture": "", "anim": "", "sfx": ""},

	# ---- 呪文専用（追加効果） ----
	"poison_apply_single":         {"type": "debuff_apply",         "status": "poison", "stacks": 5,                 "display": "毒付与", "texture": "", "anim": "", "sfx": ""},
	"poison_apply_random_multi":   {"type": "poison_random_multi",  "stacks": 3, "count": 3,                         "display": "ランダム毒付与", "texture": "", "anim": "", "sfx": ""},
	"poison_damage_by_stack":      {"type": "poison_damage",        "consume": false,                                "display": "毒ダメージ", "texture": "", "anim": "", "sfx": ""},
	"debuff_to_curse":             {"type": "debuff_to_curse",      "factor": 1.0,                                   "display": "デバフ→呪い", "texture": "", "anim": "", "sfx": ""},
	"recent_debuff_to_curse":      {"type": "recent_debuff_curse",  "window": 5.0, "factor": 1.0,                    "display": "直近デバフ呪い", "texture": "", "anim": "", "sfx": ""},
	"curse_remove":                {"type": "curse_remove",         "stacks": 5, "target_type": "highest",           "display": "呪い解除", "texture": "", "anim": "", "sfx": ""},
	"debuff_transfer_revived":     {"type": "debuff_transfer",      "target_type": "revived",                        "display": "デバフ移動", "texture": "", "anim": "", "sfx": ""},
	"cleanse_single":              {"type": "cleanse",              "scope": "single",                               "display": "単体浄化", "texture": "", "anim": "", "sfx": ""},
	"cleanse_column_random":       {"type": "cleanse_random",       "scope": "column", "count": 1,                   "display": "列ランダム浄化", "texture": "", "anim": "", "sfx": ""},
	"cleanse_row_random":          {"type": "cleanse_random",       "scope": "row", "count": 1,                      "display": "行ランダム浄化", "texture": "", "anim": "", "sfx": ""},
	"cleanse_all_random":          {"type": "cleanse_random",       "scope": "all", "count": 1,                      "display": "全体ランダム浄化", "texture": "", "anim": "", "sfx": ""},
	"status_immunity_barrier":     {"type": "barrier",              "duration": 5.0, "barrier_type": "status",       "display": "異常無効バリア", "texture": "", "anim": "", "sfx": ""},
	"beast_atk_from_dead":         {"type": "beast_dead_atk",       "target_type": "front_random_beast",             "display": "撃破獣ATK付与", "texture": "", "anim": "", "sfx": ""},
	"beast_retreat_heal":          {"type": "beast_retreat",        "heal_pct": 0.3,                                 "display": "獣後退回復", "texture": "", "anim": "", "sfx": ""},
	"beast_pack_atk_boost":        {"type": "beast_pack_boost",     "atk_pct_per_beast": 0.01, "duration": 5.0,      "display": "群れATKバフ", "texture": "", "anim": "", "sfx": ""},
	"buff_transfer_to_front_beast":{"type": "buff_transfer_beast",  "count": 99, "target_type": "front_random_beast", "display": "バフ前列獣移動", "texture": "", "anim": "", "sfx": ""},

	# ---- Phase 4追加効果（新規ユニット用） ----
	"debuff_double":            {"type": "debuff_amplify",      "factor": 2.0,                                       "display": "デバフ2倍化", "texture": "", "anim": "", "sfx": ""},
	"execute_50_stacks":        {"type": "execute_threshold",   "threshold": 50,                                     "display": "50スタック即死", "texture": "", "anim": "", "sfx": ""},
	"hp_percent_damage":        {"type": "hp_percent_damage",   "percent": 0.1,                                      "display": "HP%追加ダメージ", "texture": "", "anim": "", "sfx": ""},
	"skill_disable":            {"type": "skill_disable",       "duration": 5.0,                                     "display": "特性無効化", "texture": "", "anim": "", "sfx": ""},
	"position_swap":            {"type": "position_swap",                                                            "display": "位置入替", "texture": "", "anim": "", "sfx": ""},
	"support_disable":          {"type": "support_disable",                                                          "display": "サポート無効", "texture": "", "anim": "", "sfx": ""},
	"position_shuffle":         {"type": "position_shuffle",    "threshold": 5,                                      "display": "呪い5→シャッフル", "texture": "", "anim": "", "sfx": ""},
	"initial_swap":             {"type": "initial_swap",                                                             "display": "初期入替", "texture": "", "anim": "", "sfx": ""},
	"self_heal_percent":        {"type": "heal_percent",        "percent": 0.1,                                      "display": "自己HP%回復", "texture": "", "anim": "", "sfx": ""},
	"front_heal_percent":       {"type": "heal_front_percent",  "percent": 0.25,                                     "display": "前マスHP%回復", "texture": "", "anim": "", "sfx": ""},
	"full_hp_defense":          {"type": "full_hp_defense",     "reduction": 0.5,                                    "display": "満HP被ダメ減少", "texture": "", "anim": "", "sfx": ""},
	"damage_reduction_buff":    {"type": "buff_apply",          "buff": "armor", "stacks": 10,                       "display": "盾バフ", "texture": "", "anim": "", "sfx": ""},
	"damage_accumulate":        {"type": "damage_accumulate",                                                        "display": "ダメージ蓄積", "texture": "", "anim": "", "sfx": ""},
	"hp_equalize":              {"type": "hp_equalize",                                                              "display": "HP平均化", "texture": "", "anim": "", "sfx": ""},
	"front_spd_reduce":         {"type": "front_spd_reduce",    "factor": 0.2,                                       "display": "前列SPD減少", "texture": "", "anim": "", "sfx": ""},
	"self_damage_on_attack":    {"type": "self_damage_attack",  "hp_percent": 0.025, "atk_percent": 0.01, "spd_percent": 0.01, "display": "攻撃時自傷", "texture": "", "anim": "", "sfx": ""},
	"ally_death_penalty":       {"type": "ally_death_penalty",  "atk_percent": 0.1, "spd_percent": 0.1, "hp_percent": 0.2,  "display": "味方死亡ペナルティ", "texture": "", "anim": "", "sfx": ""},
	"heal_to_damage":           {"type": "heal_to_damage",      "duration": 3.0,                                     "display": "回復→ダメージ", "texture": "", "anim": "", "sfx": ""},
	"curse_heal_reduction":     {"type": "curse_heal_reduce",                                                        "display": "呪い回復減少", "texture": "", "anim": "", "sfx": ""},
	"buff_to_curse":            {"type": "buff_to_curse",       "percent": 0.3,                                      "display": "バフ→呪い", "texture": "", "anim": "", "sfx": ""},
	"extended_range":           {"type": "extended_range",      "range": 4,                                          "display": "攻撃範囲拡張", "texture": "", "anim": "", "sfx": ""},
	"mana_gen_trigger":         {"type": "mana_gen_trigger",                                                         "display": "マナ生成発動", "texture": "", "anim": "", "sfx": ""},
	"thorn_damage_all":         {"type": "thorn_damage_all",                                                         "display": "棘爆発", "texture": "", "anim": "", "sfx": ""},
	"mana_flare_damage":        {"type": "mana_flare_damage",                                                        "display": "マナフレア", "texture": "", "anim": "", "sfx": ""},
	"revive":                   {"type": "revive_on_death",     "hp_pct": 0.3, "delay": 5.0,                         "display": "再生", "texture": "", "anim": "", "sfx": ""},
}
