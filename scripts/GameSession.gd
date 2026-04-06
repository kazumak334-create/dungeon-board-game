# GameSession.gd
# Autoload: ランデータの一時保管（画面遷移間のデータ引き継ぎ）
extends Node

var class_id: String = ""
var dev_mode: bool = false
var battle_type: String = "normal"  # "normal" / "elite" / "boss"
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
	class_id = ""
	dev_mode = false
	battle_type = "normal"
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
