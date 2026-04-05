# UnitData.gd
class_name UnitData
extends RefCounted

var unit_name: String = "Unknown"
var max_hp: int = 10
var current_hp: int = 10
var attack: int = 2
var attack_interval: float = 1.5
var cost: int = 2
var assigned_col: int = 0
var race: String = ""
var attack_range: String = "1行"
var support_effect: String = ""   # サポート効果（常時発動/召喚時/条件達成時）
var active_skill: String = ""     # アクティブスキル（命中時/撃破時/HP閾値時/時間経過/その他）
# 呪文カード用フィールド（ユニットカードでは使用しない）
var card_type: String = "unit"    # "unit" | "spell" | "status_spell"
var spell_id: String = ""         # 呪文識別子
var spell_target: String = ""     # "self" | "single_ally" | "all_allies" | "all_enemies" | "front_all" | "column" | "enemy_queue"
var spell_effect: String = ""     # 効果記述
var is_consumable: bool = false   # true = 発動後消滅（捨て札に行かない）
# 盤面合成フィールド
var synthesis_base: String = ""   # 盤面合成の盤面ユニット名（空=合成不可）
var synthesis_card: String = ""   # 盤面合成の発動カード名
# 効果テーブルシステム（新方式）
var skills: Array = []            # [{trigger, effect_id, params}]

# ランタイムサポートボーナス（毎フレームBoardManagerが再計算・cloneには引き継がない）
var _atk_bonus: int = 0
var _interval_bonus: float = 0.0
var _regen: float = 0.0
var _can_attack_from_back: bool = false   # 後列から攻撃可能（狙撃/支援攻撃）
var _can_attack_from_mid: bool = false   # 中列から攻撃可能（支援攻撃）
var _back_atk_factor: float = 1.0
var _back_target_rear: bool = false      # 敵最後列を優先（狙撃）
var _back_no_on_hit: bool = false        # 命中時アクティブを発動しない
var _is_flying: bool = false             # 飛行スキル：盤面効果を受けない
var _damage_reduction: int = 0  # 鎧バフ：被ダメージ-N
var _has_lifesteal: bool = false  # 吸血（後方互換：スタック>0ならtrue）
var _has_penetrate: bool = false  # 貫通：後ろ1マス100%
var _has_impact: bool = false     # 衝撃：後ろ1マス50%
var _has_big_penetrate: bool = false  # 大貫通：後ろ1マス100% + 後ろ2マス50%
var lifesteal_stacks: int = 0    # 吸血スタック：回復率3%/スタック、2秒ごと-1
var _regen_stacks: int = 0       # リジェネバフ：2秒ごとにHP5%×スタック数回復（重複可）
# アクティブスキル状態（永続・cloneには引き継がない）
var _has_revived: bool = false
var _support_revive: bool = false    # サポート効果由来の再起（毎フレーム再計算）
var _support_revive_used: bool = false  # サポート再起を使用済みか（1回限り）
var _first_attack: bool = true  # クリティカル用：初撃フラグ
var _kill_atk_bonus: int = 0    # ATK累積：撃破時の累積ボーナス（上限10）
# バフ奪取で得た永続ボーナス（サポート再計算でリセットされない）
var _stolen_atk: int = 0
var _stolen_spd: float = 0.0
var _stolen_lifesteal: bool = false
var _stolen_penetrate: bool = false
var _stolen_regen: int = 0
var _stolen_armor: int = 0
# 状態異常（Timerノードで1秒ごとに管理・cloneには引き継がない）
var poison_stacks:    int = 0  # 毒: 毎秒スタック数分ダメージ（線形）
var frozen_turns:     int = 0  # 凍結: 攻撃速度低下（逓減・最大80%）
var burn_turns:       int = 0  # 火傷: ATK低下（逓減・最大80%）
var paralysis_turns:  int = 0  # 麻痺: 行動不能
# 時間経過スキル（cloneには引き継がない）
var _skill_timers: Dictionary = {}  # {entry文字列: 残り秒数}
var _temp_atk_bonus: int = 0        # 一時ATKバフ（時間経過スキル用）
var _temp_atk_timer: float = 0.0    # 一時ATKバフ残り時間
var _temp_spd_bonus: float = 0.0    # 一時SPDバフ（攻撃間隔短縮）
var _temp_spd_timer: float = 0.0    # 一時SPDバフ残り時間
# HP閾値スキル（cloneには引き継がない）
var _hp_threshold_triggered: Dictionary = {}  # {entry: true} 発動済みフラグ
var _invincible_timer: float = 0.0            # 結晶化：無敵残り時間

func is_alive() -> bool:
	return current_hp > 0

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)

func clone() -> RefCounted:
	# class_name による自己参照を避けるため get_script() で生成
	var d = get_script().new()
	d.unit_name = unit_name
	d.max_hp = max_hp
	d.current_hp = max_hp
	d.attack = attack
	d.attack_interval = attack_interval
	d.cost = cost
	d.assigned_col = assigned_col
	d.race = race
	d.attack_range = attack_range
	d.support_effect = support_effect
	d.active_skill = active_skill
	d.card_type = card_type
	d.spell_id = spell_id
	d.spell_target = spell_target
	d.spell_effect = spell_effect
	d.is_consumable = is_consumable
	d.synthesis_base = synthesis_base
	d.synthesis_card = synthesis_card
	d.skills = skills.duplicate(true)
	return d
