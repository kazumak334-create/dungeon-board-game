# CardDB.gd
# カードデータベース（全カード定義の一元管理）
# class_nameを使わない（load()で参照・循環参照回避）
extends RefCounted

# ---- ユニット定義 ----
const UNITS: Dictionary = {
	# ── スライム系 ──
	"スライム": {
		"hp": 15, "atk": 1, "interval": 4.0, "cost": 1, "race": "スライム", "range": "1行", "col": 1,
		"skills": [
			{"trigger": "on_summon", "target": "same_row", "effect_id": "summon_same_row", "params": {"unit_id": "スライム", "chain": false}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"マッドスライム": {
		"hp": 40, "atk": 2, "interval": 3.8, "cost": 3, "race": "スライム", "range": "1行", "col": 1,
		"skills": [
			{"trigger": "always", "target": "self", "effect_id": "armor_apply", "params": {"stacks": 1}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"ブラッドスライム": {
		"hp": 25, "atk": 2, "interval": 3.8, "cost": 4, "race": "スライム", "range": "1行", "col": 0,
		"skills": [
			{"trigger": "on_summon", "target": "random_front_ally", "effect_id": "lifesteal_apply", "params": {"stacks": 5}},
			{"trigger": "on_summon", "target": "self_deck", "effect_id": "deck_add_self", "params": {}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"ラージスライム": {
		"hp": 25, "atk": 2, "interval": 3.8, "cost": 2, "race": "スライム", "range": "1行", "col": 1,
		"skills": [
			{"trigger": "on_summon", "target": "self_deck", "effect_id": "synthesis_boost", "params": {}},
			{"trigger": "on_death", "target": "same_row", "effect_id": "split_on_death", "params": {}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"ファットスライム": {
		"hp": 50, "atk": 3, "interval": 6.0, "cost": 3, "race": "スライム", "range": "1行", "col": 0,
		"skills": [
			{"trigger": "on_summon", "target": "self_deck", "effect_id": "synthesis_boost", "params": {}},
			{"trigger": "on_death", "target": "same_row", "effect_id": "split_on_death", "params": {}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"キングスライム": {
		"hp": 100, "atk": 5, "interval": 6.0, "cost": 10, "race": "スライム", "range": "1行", "col": 2,
		"skills": [
			{"trigger": "always", "target": "all_allies", "effect_id": "slime_global_buff", "params": {"race": "スライム", "atk_pct": 0.5}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"ヒートスライム": {
		"hp": 25, "atk": 2, "interval": 3.8, "cost": 3, "race": "スライム", "range": "1行", "col": 0,
		"skills": [
			{"trigger": "on_hit", "target": "hit_target", "effect_id": "burn_apply", "params": {"stacks": 2}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"フロストスライム": {
		"hp": 25, "atk": 2, "interval": 3.8, "cost": 3, "race": "スライム", "range": "1行", "col": 0,
		"skills": [
			{"trigger": "on_hit", "target": "hit_target", "effect_id": "freeze_apply", "params": {"stacks": 3}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"パラライズスライム": {
		"hp": 25, "atk": 2, "interval": 3.0, "cost": 3, "race": "スライム", "range": "1行", "col": 0,
		"skills": [
			{"trigger": "on_hit", "target": "hit_target", "effect_id": "paralysis_apply", "params": {"stacks": 1}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"ポイズンスライム": {
		"hp": 25, "atk": 2, "interval": 3.0, "cost": 3, "race": "スライム", "range": "1行", "col": 0,
		"skills": [
			{"trigger": "on_hit", "target": "hit_target", "effect_id": "poison_apply", "params": {"stacks": 1}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"クリスタルスライム": {
		"hp": 10, "atk": 1, "interval": 2.0, "cost": 4, "race": "スライム", "range": "1行", "col": 2,
		"skills": [],
		"texture": "", "anim": "", "sfx": "",
	},
	"ゼリーフィッシュ": {
		"hp": 10, "atk": 1, "interval": 5.0, "cost": 3, "race": "スライム", "range": "1行", "col": 2,
		"skills": [],
		"texture": "", "anim": "", "sfx": "",
	},
	# ── アンデッド系 ──
	"スケルトン": {
		"hp": 20, "atk": 2, "interval": 3.0, "cost": 2, "race": "アンデッド", "range": "1行", "col": 0,
		"skills": [
			{"trigger": "always", "target": "enemy", "effect_id": "enemy_mana_drain", "params": {}},
			{"trigger": "on_death", "target": "same_row", "effect_id": "self_revive", "params": {"hp": 5, "delay": 3.0}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"グール": {
		"hp": 25, "atk": 5, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "1行", "col": 1,
		"skills": [
			{"trigger": "always", "target": "front_enemy", "effect_id": "debuff_spread", "params": {}},
			{"trigger": "on_hit", "target": "self", "effect_id": "lifesteal_apply", "params": {"stacks": 8}},
			{"trigger": "on_kill", "target": "self", "effect_id": "atk_accumulate", "params": {"amount": 2, "cap": 10}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"バンシー": {
		"hp": 10, "atk": 1, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "上下含む3行", "col": 2,
		"skills": [
			{"trigger": "always", "target": "self", "effect_id": "support_fire", "params": {"atk_factor": 0.3}},
			{"trigger": "always", "target": "same_col_ally", "effect_id": "spd_buff_apply", "params": {"stacks": 3}},
			{"trigger": "on_hit", "target": "hit_target", "effect_id": "burn_apply", "params": {"stacks": 2}},
			{"trigger": "timer", "target": "all_enemies", "effect_id": "all_enemy_debuff", "params": {"interval": 15.0, "status": "burn", "stacks": 2}},
			{"trigger": "on_kill", "target": "all_enemies", "effect_id": "freeze_apply", "params": {"stacks": 4}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"リッチ": {
		"hp": 15, "atk": 2, "interval": 3.0, "cost": 3, "race": "アンデッド", "range": "上下含む3行", "col": 2,
		"skills": [
			{"trigger": "always", "target": "self", "effect_id": "snipe", "params": {}},
			{"trigger": "always", "target": "same_row", "effect_id": "support_revive", "params": {}},
			{"trigger": "on_hit", "target": "hit_target", "effect_id": "freeze_apply", "params": {"stacks": 3}},
			{"trigger": "timer", "target": "all_enemies", "effect_id": "poison_apply", "params": {"interval": 20.0, "stacks": 3}},
			{"trigger": "on_kill", "target": "ally_undead_lowest", "effect_id": "revive_undead", "params": {}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"ヴリコラカス": {
		"hp": 30, "atk": 6, "interval": 2.0, "cost": 3, "race": "アンデッド", "range": "1行", "col": 1,
		"skills": [
			{"trigger": "always", "target": "adjacent_enemy", "effect_id": "debuff_spread", "params": {}},
			{"trigger": "on_hit", "target": "hit_target", "effect_id": "steal_buffs", "params": {}},
			{"trigger": "timer", "target": "enemy_most_buffs", "effect_id": "steal_all_buffs", "params": {"interval": 20.0}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	# ── 獣系 ──
	"ゴブリン": {
		"hp": 15, "atk": 3, "interval": 1.0, "cost": 1, "race": "獣", "range": "1行", "col": 0,
		"skills": [
			{"trigger": "always", "target": "front_one", "effect_id": "atk_buff_apply", "params": {"stacks": 2}},
			{"trigger": "on_summon", "target": "self", "effect_id": "draw_cards", "params": {"count": 2}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"ワイルドホーク": {
		"hp": 15, "atk": 2, "interval": 1.5, "cost": 2, "race": "獣", "range": "1行", "col": 2,
		"skills": [
			{"trigger": "always", "target": "front_beast", "effect_id": "spd_buff_apply", "params": {"stacks": 1}},
			{"trigger": "always", "target": "self", "effect_id": "flying", "params": {}},
			{"trigger": "always", "target": "self", "effect_id": "penetrate", "params": {}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"ウルフ": {
		"hp": 20, "atk": 5, "interval": 1.5, "cost": 2, "race": "獣", "range": "1行", "col": 1,
		"skills": [
			{"trigger": "always", "target": "same_row_beast", "effect_id": "spd_buff_apply", "params": {"stacks": 3}},
			{"trigger": "timer", "target": "same_row_beast", "effect_id": "atk_buff_apply", "params": {"interval": 10.0, "stacks": 3, "duration": 5.0}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"タイガー": {
		"hp": 25, "atk": 8, "interval": 2.0, "cost": 3, "race": "獣", "range": "下含む2行", "col": 2,
		"skills": [
			{"trigger": "always", "target": "adjacent_beast", "effect_id": "atk_buff_apply", "params": {"stacks": 2}},
			{"trigger": "on_hit", "target": "hit_target", "effect_id": "critical", "params": {"first_only": true, "factor": 2.0}},
			{"trigger": "on_summon", "target": "self", "effect_id": "force_front", "params": {}},
			{"trigger": "timer", "target": "enemy_max_hp", "effect_id": "big_damage", "params": {"interval": 20.0}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
}

# ---- 呪文定義 ----
const SPELLS: Dictionary = {
	"召喚加速":   {"cost": 1, "target": "self",        "effect": "マナ即時+3回復",
		"skills": [{"trigger": "on_play", "target": "self", "effect_id": "mana_boost", "params": {"amount": 3}}],
		"texture": "", "anim": "", "sfx": ""},
	"血の契約":   {"cost": 2, "target": "single_ally",  "effect": "対象1体にHP30%代償+吸血付与",
		"skills": [
			{"trigger": "on_play", "target": "ally_max_atk", "effect_id": "hp_cost", "params": {"factor": 0.30}},
			{"trigger": "on_play", "target": "ally_max_atk", "effect_id": "lifesteal_apply", "params": {"stacks": 10}},
		],
		"texture": "", "anim": "", "sfx": ""},
	"戦場の鼓動": {"cost": 2, "target": "all_allies",   "effect": "全味方SPD+50%(5s)",
		"skills": [{"trigger": "on_play", "target": "all_allies", "effect_id": "spd_buff_all", "params": {"factor": 0.5, "duration": 5.0}}],
		"texture": "", "anim": "", "sfx": ""},
	"急召":       {"cost": 1, "target": "self",          "effect": "低コストユニット1体即時召喚",
		"skills": [{"trigger": "on_play", "target": "self", "effect_id": "summon_low_cost", "params": {}}],
		"texture": "", "anim": "", "sfx": ""},
	"連鎖の触媒": {"cost": 2, "target": "self",          "effect": "次の3枚コスト-1",
		"skills": [{"trigger": "on_play", "target": "self", "effect_id": "cost_reduction", "params": {"count": 3, "amount": 1}}],
		"texture": "", "anim": "", "sfx": ""},
	"強化の儀式": {"cost": 3, "target": "single_ally",   "effect": "対象1体ATK+5・HP+10",
		"skills": [{"trigger": "on_play", "target": "single_ally", "effect_id": "atk_hp_boost", "params": {"atk": 5, "hp": 10}}],
		"texture": "", "anim": "", "sfx": ""},
	"盤面強化":   {"cost": 3, "target": "all_allies",    "effect": "全味方HP+10・ATK+2",
		"skills": [{"trigger": "on_play", "target": "all_allies", "effect_id": "all_stat_boost", "params": {"atk": 2, "hp": 10}}],
		"texture": "", "anim": "", "sfx": ""},
	"圧縮の書":   {"cost": 2, "target": "self",          "effect": "山札から異常状態カード除去",
		"skills": [{"trigger": "on_play", "target": "self_deck", "effect_id": "remove_status_card", "params": {}}],
		"texture": "", "anim": "", "sfx": ""},
	"生命の雫":   {"cost": 2, "target": "single_ally",   "effect": "対象1体HP15%回復",
		"skills": [{"trigger": "on_play", "target": "single_ally", "effect_id": "heal_pct", "params": {"factor": 0.15}}],
		"texture": "", "anim": "", "sfx": ""},
	"全体再生":   {"cost": 4, "target": "all_allies",    "effect": "全味方にリジェネ+1",
		"skills": [{"trigger": "on_play", "target": "all_allies", "effect_id": "regen_apply", "params": {"stacks": 1}}],
		"texture": "", "anim": "", "sfx": ""},
	"泥の鎧":     {"cost": 1, "target": "single_ally",   "effect": "対象1体に鎧付与",
		"skills": [{"trigger": "on_play", "target": "single_ally", "effect_id": "armor_apply", "params": {"stacks": 1}}],
		"texture": "", "anim": "", "sfx": ""},
	"結晶化":     {"cost": 3, "target": "single_ally",   "effect": "対象1体に呪文無効(1回)",
		"skills": [{"trigger": "on_play", "target": "single_ally", "effect_id": "crystallize", "params": {}}],
		"texture": "", "anim": "", "sfx": ""},
	"毒霧":       {"cost": 2, "target": "column",        "effect": "敵ランダム列に毒5+自デッキに毒カード",
		"skills": [
			{"trigger": "on_play", "target": "enemy_random_col", "effect_id": "poison_apply", "params": {"stacks": 5}},
			{"trigger": "on_play", "target": "self_deck", "effect_id": "inject_status_card", "params": {"card_id": "毒カード"}},
		],
		"texture": "", "anim": "", "sfx": ""},
	"寒波":       {"cost": 2, "target": "front_all",     "effect": "前列全体に凍結+両デッキに凍結カード",
		"skills": [
			{"trigger": "on_play", "target": "all_front", "effect_id": "front_status_both", "params": {"status": "freeze", "stacks": 2}},
			{"trigger": "on_play", "target": "self_deck", "effect_id": "inject_status_card", "params": {"card_id": "凍結カード"}},
			{"trigger": "on_play", "target": "enemy_deck", "effect_id": "inject_status_card", "params": {"card_id": "凍結カード"}},
		],
		"texture": "", "anim": "", "sfx": ""},
	"山火事":     {"cost": 2, "target": "front_all",     "effect": "前列全体に火傷+両デッキに火傷カード",
		"skills": [
			{"trigger": "on_play", "target": "all_front", "effect_id": "front_status_both", "params": {"status": "burn", "stacks": 2}},
			{"trigger": "on_play", "target": "self_deck", "effect_id": "inject_status_card", "params": {"card_id": "火傷カード"}},
			{"trigger": "on_play", "target": "enemy_deck", "effect_id": "inject_status_card", "params": {"card_id": "火傷カード"}},
		],
		"texture": "", "anim": "", "sfx": ""},
	"落雷":       {"cost": 3, "target": "front_all",     "effect": "前列全体に10dmg+麻痺+両デッキに麻痺カード",
		"skills": [
			{"trigger": "on_play", "target": "all_front", "effect_id": "front_damage_status", "params": {"damage": 10, "status": "paralysis", "stacks": 2}},
			{"trigger": "on_play", "target": "self_deck", "effect_id": "inject_status_card", "params": {"card_id": "麻痺カード"}},
			{"trigger": "on_play", "target": "enemy_deck", "effect_id": "inject_status_card", "params": {"card_id": "麻痺カード"}},
		],
		"texture": "", "anim": "", "sfx": ""},
	"烈風斬":     {"cost": 3, "target": "all_enemies",   "effect": "敵全体に中ダメージ",
		"skills": [{"trigger": "on_play", "target": "all_enemies", "effect_id": "all_enemy_damage", "params": {"damage": 8}}],
		"texture": "", "anim": "", "sfx": ""},
	"弱体の呪詛": {"cost": 3, "target": "all_enemies",   "effect": "敵全体ATK低下",
		"skills": [{"trigger": "on_play", "target": "all_enemies", "effect_id": "all_enemy_debuff", "params": {"status": "burn", "stacks": 3}}],
		"texture": "", "anim": "", "sfx": ""},
	"盤面凍結":   {"cost": 4, "target": "all_enemies",   "effect": "敵全体を8s間凍結",
		"skills": [{"trigger": "on_play", "target": "all_enemies", "effect_id": "all_enemy_debuff", "params": {"status": "freeze", "stacks": 8}}],
		"texture": "", "anim": "", "sfx": ""},
	"混沌の手":   {"cost": 2, "target": "single_enemy",  "effect": "敵1体をランダム行に移動",
		"skills": [{"trigger": "on_play", "target": "single_enemy", "effect_id": "move_random", "params": {}}],
		"texture": "", "anim": "", "sfx": ""},
	"反転の波":   {"cost": 3, "target": "all_enemies",   "effect": "敵前列と後列を入れ替え",
		"skills": [{"trigger": "on_play", "target": "all_enemies", "effect_id": "swap_front_back", "params": {}}],
		"texture": "", "anim": "", "sfx": ""},
	"押し込み":   {"cost": 2, "target": "single_enemy",  "effect": "敵前列1体を後列に移動",
		"skills": [{"trigger": "on_play", "target": "enemy_front_one", "effect_id": "push_to_back", "params": {}}],
		"texture": "", "anim": "", "sfx": ""},
	"召喚妨害":   {"cost": 1, "target": "enemy_queue",   "effect": "敵の次の召喚を3s遅延",
		"skills": [{"trigger": "on_play", "target": "enemy", "effect_id": "delay_enemy_spawn", "params": {"seconds": 3}}],
		"texture": "", "anim": "", "sfx": ""},
	"配置崩し":   {"cost": 2, "target": "enemy_queue",   "effect": "敵の次の召喚列をランダム化",
		"skills": [{"trigger": "on_play", "target": "enemy", "effect_id": "randomize_enemy_col", "params": {}}],
		"texture": "", "anim": "", "sfx": ""},
	"アースクエイク": {"cost": 6, "target": "all_enemies", "effect": "全体30ダメージ＋全マスをヒビ床に",
		"skills": [
			{"trigger": "on_play", "target": "all_enemies", "effect_id": "all_enemy_damage", "params": {"damage": 30}},
			{"trigger": "on_play", "target": "all", "effect_id": "tile_set_all", "params": {"tile_id": "tile_crack"}},
		],
		"texture": "", "anim": "", "sfx": ""},
}

# ---- 異常状態カード定義 ----
const STATUS_SPELLS: Dictionary = {
	"毒カード":   {"cost": 0, "target": "single_ally", "effect": "味方ランダム1体に毒2付与",
		"skills": [{"trigger": "on_play", "target": "random_ally", "effect_id": "poison_apply", "params": {"stacks": 2}}],
		"texture": "", "anim": "", "sfx": ""},
	"凍結カード": {"cost": 0, "target": "single_ally", "effect": "味方ランダム1体に凍結2付与",
		"skills": [{"trigger": "on_play", "target": "random_ally", "effect_id": "freeze_apply", "params": {"stacks": 2}}],
		"texture": "", "anim": "", "sfx": ""},
	"火傷カード": {"cost": 0, "target": "single_ally", "effect": "味方ランダム1体に火傷2付与",
		"skills": [{"trigger": "on_play", "target": "random_ally", "effect_id": "burn_apply", "params": {"stacks": 2}}],
		"texture": "", "anim": "", "sfx": ""},
	"麻痺カード": {"cost": 0, "target": "single_ally", "effect": "味方ランダム1体に麻痺2付与",
		"skills": [{"trigger": "on_play", "target": "random_ally", "effect_id": "paralysis_apply", "params": {"stacks": 2}}],
		"texture": "", "anim": "", "sfx": ""},
}

# ---- システムカード定義 ----
const SYSTEM_SPELLS: Dictionary = {
	"シャッフル": {"cost": 0, "target": "self", "effect": "山札をシャッフル＋自身を山札最下部に追加",
		"is_consumable": true,
		"skills": [
			{"trigger": "on_play", "target": "self_deck", "effect_id": "shuffle_deck", "params": {}},
			{"trigger": "on_play", "target": "self_deck", "effect_id": "deck_add_self", "params": {"position": "bottom"}},
		],
		"texture": "", "anim": "", "sfx": ""},
}

# ---- アーティファクト定義 ----
# 永久効果型（3種）: card_type="permanent_artifact" デッキ外・常時発動
# 盤面出現型（4種）: card_type="artifact" 盤面配置・HPあり・アクティブスキルのみ
const ARTIFACTS: Dictionary = {
	# ── 永久効果型 ──
	"加速の石板": {
		"card_type": "permanent_artifact",
		"skills": [
			{"trigger": "always", "target": "self", "effect_id": "mana_regen_boost", "params": {"pct": 0.2}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"速攻の刃": {
		"card_type": "permanent_artifact",
		"skills": [
			{"trigger": "always", "target": "front_ally_all", "effect_id": "atk_buff_apply", "params": {"stacks": 2}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	"守護の紋章": {
		"card_type": "permanent_artifact",
		"skills": [
			{"trigger": "always", "target": "self", "effect_id": "base_damage_reduce", "params": {"pct": 0.1}},
		],
		"texture": "", "anim": "", "sfx": "",
	},
	# ── 盤面出現型 ──
	"戦旗": {
		"card_type": "artifact", "hp": 20,
		"skills": [
			{"trigger": "always", "target": "adjacent_8", "effect_id": "atk_buff_apply", "params": {"stacks": 2}},
			{"trigger": "always", "target": "adjacent_8", "effect_id": "spd_buff_apply", "params": {"stacks": 1}},
		],
		"protect_tiles": false,
		"texture": "", "anim": "", "sfx": "",
	},
	"呪いの祭壇": {
		"card_type": "artifact", "hp": 15,
		"skills": [
			{"trigger": "timer", "target": "all_enemies", "effect_id": "poison_apply", "params": {"interval": 5.0, "stacks": 1}},
		],
		"protect_tiles": false,
		"texture": "", "anim": "", "sfx": "",
	},
	"召喚門": {
		"card_type": "artifact", "hp": 30,
		"skills": [
			{"trigger": "timer", "target": "random_empty_ally", "effect_id": "summon_to_empty", "params": {"interval": 8.0, "unit_id": "ゴブリン"}},
		],
		"protect_tiles": false,
		"texture": "", "anim": "", "sfx": "",
	},
	"王墓の石碑": {
		"card_type": "artifact", "hp": 25,
		"skills": [
			{"trigger": "on_summon", "target": "adjacent_8", "effect_id": "tile_set_all", "params": {"tile_id": "tile_grave"}},
			{"trigger": "on_death",  "target": "adjacent_8", "effect_id": "tile_set_all", "params": {"tile_id": "tile_crack"}},
		],
		"protect_tiles": true,
		"texture": "", "anim": "", "sfx": "",
	},
}

# ---- 合成レシピ定義 ----
const SYNTHESIS: Array = [
	# スライム合体チェーン
	{"base": "スライム",       "card": "スライム",       "result": "ラージスライム"},
	{"base": "ラージスライム", "card": "ラージスライム", "result": "ファットスライム"},
	{"base": "ファットスライム","card": "ファットスライム","result": "キングスライム"},
	# スライム＋呪文合成
	{"base": "スライム", "card": "泥の鎧",     "result": "マッドスライム"},
	{"base": "スライム", "card": "火傷カード",  "result": "ヒートスライム"},
	{"base": "スライム", "card": "凍結カード",  "result": "フロストスライム"},
	{"base": "スライム", "card": "麻痺カード",  "result": "パラライズスライム"},
	{"base": "スライム", "card": "毒カード",    "result": "ポイズンスライム"},
	{"base": "スライム", "card": "結晶化",     "result": "クリスタルスライム"},
	{"base": "スライム", "card": "血の契約",   "result": "ブラッドスライム"},
	{"base": "スライム", "card": "生命の雫",   "result": "ゼリーフィッシュ"},
]

# ---- デッキ構成 ----
const PLAYER_DECK: Array = [
	{"name": "スライム",       "col": 1},
	{"name": "スケルトン",     "col": 0},
	{"name": "ゴブリン",       "col": 0},
	{"name": "マッドスライム", "col": 1},
	{"name": "グール",         "col": 1},
	{"name": "ウルフ",         "col": 1},
	{"name": "ブラッドスライム","col": 2},
	{"name": "バンシー",       "col": 2},
	{"name": "タイガー",       "col": 2},
	{"name": "リッチ",         "col": 2},
	{"name": "ヴリコラカス",   "col": 1},
]
const PLAYER_SPELLS: Array = ["召喚加速", "生命の雫", "盤面強化"]

const ENEMY_DECK: Array = [
	{"name": "スライム",         "col": 1},
	{"name": "スケルトン",       "col": 0},
	{"name": "ゴブリン",         "col": 0},
	{"name": "マッドスライム",   "col": 1},
	{"name": "グール",           "col": 1},
	{"name": "ウルフ",           "col": 1},
	{"name": "ブラッドスライム", "col": 2},
	{"name": "バンシー",         "col": 2},
	{"name": "タイガー",         "col": 2},
	{"name": "リッチ",           "col": 2},
	{"name": "ヴリコラカス",     "col": 1},
]
