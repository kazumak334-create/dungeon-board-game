# GameSession.gd
# Autoload: ランデータの一時保管（画面遷移間のデータ引き継ぎ）
extends Node

# DEFAULT_BATTLE_CONFIG を関数化（ConfigLoader経由で取得）
func get_default_battle_config() -> Dictionary:
	var time_limit: float = ConfigLoader.get_value("battle_config", "time_limit", 60.0)
	var player_base_hp: int = ConfigLoader.get_value("battle_config", "player_base_hp", 30)
	var enemy_base_hp: int = ConfigLoader.get_value("battle_config", "enemy_base_hp", 30)

	return {
		"time_limit":            time_limit,
		"time_up_result":        "lose", # "lose"/"draw"/"win"
		"win_condition":         "enemy_hp_zero",
		"lose_condition":        "player_hp_zero",
		"player_base_hp":        player_base_hp,
		"enemy_base_hp":         enemy_base_hp,
		"enemy_check_interval":  1.0,
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
var boss_id: String = ""  # ボスID（例: "boss_beast_king"）
var boss_phase: int = 1  # ボス連戦のフェーズ（1 or 2）
var base_environment: String = "env_none"  # ベース環境（ボス区間共通）
var environment_override: Dictionary = {}  # 環境変化（side→tile_id）
var selected_deck: Array = []
var selected_material: Dictionary = {}
var placement_config: Array = []  # デッキインデックス→{col_priority, row_priority, modifiers}
# v2設計: 初期配置9マス（呪文はselected_deckに残る）
var initial_units: Array = []  # 9個の要素 [{name, row, col}, ...] or null
# v2設計: 呪文3スロット設定
var spell_slots: Array = []  # 3個の要素 [{spell_name, condition}, ...] or null
var relics: Array = []  # 所持レリック（バトル報酬・ショップ・イベントで取得）
var gold: int = 0          # 通貨
var skill_points: int = 0  # スキルポイント
var unlocked_skills: Array = []  # 解放済みスキルID配列
var skill_tree_data: Dictionary = {}  # 現在のランで生成されたスキルツリー（SkillTreeGenerator.generate()の結果）
var last_result: Dictionary = {"win": false, "player_hp_remaining": 0, "enemy_hp_remaining": 0, "turns": 0}
var run_depth: int = 0
var artifacts_acquired: Array = []
var battle_seed: int = 0       # リプレイ用ランダムシード
var battle_log: Array = []     # リプレイ用イベントログ
var current_battle_gold: int = 0  # バトル中に獲得した累積通貨（敵撃破ドロップ）
var battle_drops: Array = []      # バトル中に獲得したアイテムドロップ（Phase 3で実装）
# Phase 3: マップシステム
var map_data: Dictionary = {}        # MapGenerator.generate()の結果
var race_theme: String = ""          # "slime"/"beast"/"undead" - ラン開始時に決定
var map_seed: int = 0                # マップ生成シード
var current_act: int = 1             # 現在のAct（1-3）
var current_node: String = ""        # 現在地ノードID
var completed_nodes: Array = []      # 通過済みノードID
var boss_candidates: Array = []      # 表示するボス候補
var selected_boss_id: String = ""    # 選択したボスID
var current_event_id: String = ""    # 現在表示中のイベントID
var visited_events: Array = []       # 既に発生したイベントID（1ラン中に同じイベントは2回出ない）
var last_scene: String = ""          # 直前のシーン名（戻るボタン用）
var alert_level: int = 0             # 警戒レベル（戦闘マス選択で+1、レストで-2）
var elite_injected_in_battle: bool = false  # エリート混入済みフラグ（報酬選択肢+1用）

# Godモードフラグ（デバッグUI専用）
var god_mode_invincible: bool = false     # 無敵モード
var god_mode_infinite_mana: bool = false  # マナ無限
var god_mode_infinite_time: bool = false  # 時間無限
var god_mode_auto_win: bool = false       # 必ず勝利

func reset() -> void:
	battle_config = get_default_battle_config()
	class_id = ""
	dev_mode = false
	battle_type = "normal"
	boss_id = ""
	boss_phase = 1
	base_environment = "env_none"
	environment_override = {}
	selected_deck = []
	selected_material = {}
	placement_config = []
	initial_units = []
	spell_slots = []
	relics = []
	gold = 0
	skill_points = 0
	unlocked_skills = []
	skill_tree_data = {}
	last_result = {"win": false, "player_hp_remaining": 0, "enemy_hp_remaining": 0, "turns": 0}
	run_depth = 0
	artifacts_acquired = []
	battle_seed = 0
	battle_log = []
	current_battle_gold = 0
	battle_drops = []
	# Phase 3: マップシステム
	map_data = {}
	race_theme = ""
	map_seed = 0
	current_act = 1
	current_node = ""
	completed_nodes = []
	boss_candidates = []
	selected_boss_id = ""
	current_event_id = ""
	visited_events = []
	last_scene = ""
	alert_level = 0
	elite_injected_in_battle = false
	# Godモードフラグはreset時にクリア
	god_mode_invincible = false
	god_mode_infinite_mana = false
	god_mode_infinite_time = false
	god_mode_auto_win = false
	print("[GameSession] reset")
