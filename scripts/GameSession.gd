# GameSession.gd
# Autoload: ランデータの一時保管（画面遷移間のデータ引き継ぎ）
extends Node

const DEFAULT_BATTLE_CONFIG: Dictionary = {
	"time_limit":            60.0,   # 0.0=制限なし
	"time_up_result":        "lose", # "lose"/"draw"/"win"
	"win_condition":         "enemy_hp_zero",
	"lose_condition":        "player_hp_zero",
	"player_base_hp":        30,
	"enemy_base_hp":         30,
	"enemy_check_interval":  1.0,
	"mana_regen_rate":       1.0,
	"card_play_interval":    1.0,
	"enemy_atk_scale":       1.0,
	"enemy_hp_scale":        1.0,
	"reward_multiplier":     1.0,
	"skill_points_reward":   1,
	"initial_units":         [],    # 開始時配置済みユニット（入れ物のみ）
	"summon_race_filter":    "",    # 空=制限なし（入れ物のみ）
	"placement_restriction": "",    # 空=制限なし（入れ物のみ）
	"mana_max_override":     0.0,  # 0.0=通常（クラス依存）（入れ物のみ）
}

var battle_config: Dictionary = {}

var class_id: String = ""
var dev_mode: bool = false
var battle_type: String = "normal"  # "normal" / "elite" / "boss"
var base_environment: String = "env_none"  # ベース環境（ボス区間共通）
var environment_override: Dictionary = {}  # 環境変化（side→tile_id）
var selected_deck: Array = []
var selected_material: Dictionary = {}
var placement_config: Array = []  # デッキインデックス→{col_priority, row_priority, modifiers}
var materials: Array = []  # 所持素材（バトル報酬で蓄積）
var gold: int = 0          # 通貨
var skill_points: int = 0  # スキルポイント
var last_result: Dictionary = {"win": false, "player_hp_remaining": 0, "enemy_hp_dealt": 0, "turns": 0}
var run_depth: int = 0
var artifacts_acquired: Array = []
var battle_seed: int = 0       # リプレイ用ランダムシード
var battle_log: Array = []     # リプレイ用イベントログ

func reset() -> void:
	battle_config = DEFAULT_BATTLE_CONFIG.duplicate(true)
	class_id = ""
	dev_mode = false
	battle_type = "normal"
	base_environment = "env_none"
	environment_override = {}
	selected_deck = []
	selected_material = {}
	placement_config = []
	materials = []
	gold = 0
	skill_points = 0
	last_result = {"win": false, "player_hp_remaining": 0, "enemy_hp_dealt": 0, "turns": 0}
	run_depth = 0
	artifacts_acquired = []
	battle_seed = 0
	battle_log = []
	print("[GameSession] reset")
