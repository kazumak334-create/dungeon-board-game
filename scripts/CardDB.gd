# CardDB.gd
# カードデータベース（JSONファイルから読み込み）
extends Node

var UNITS: Dictionary = {}
var SPELLS: Dictionary = {}
var STATUS_SPELLS: Dictionary = {}
var SYSTEM_SPELLS: Dictionary = {}
var CLASSES: Dictionary = {}
var SYNTHESIS: Array = []
var PLAYER_DECK: Array = []
var PLAYER_SPELLS: Array = []
var ENEMY_DECK: Array = []
var ENEMY_POOLS: Dictionary = {}
var ELITE_POOLS: Dictionary = {}
var BASE_DECK: Array = []
var ARTIFACTS: Dictionary = {}  # アーティファクト（StS風パッシブアイテム）
var ENVIRONMENTS: Dictionary = {}
var BOSSES: Dictionary = {}
var EVENTS: Dictionary = {}  # イベント（StS風ランダムイベント）
var BOSS_DECKS: Dictionary = {}
var BOSS_EXCLUSIVE_UNITS: Dictionary = {}
var TRAITS: Dictionary = {}  # 特性（カード固有、アーティファクト付与、低確率生成時付与）
var PLAYER_SKILLS: Dictionary = {}  # プレイヤースキル（スキルツリーで解放）
var EQUIPMENT: Dictionary = {}  # 装備（デバッグ・将来機能用）
var MATERIALS: Array = []  # 素材（合成・盤面素材用）

func _ready() -> void:
	var file = FileAccess.open("res://data/cards.json", FileAccess.READ)
	if file == null:
		print("[CardDB] ERROR: data/cards.json not found")
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null:
		print("[CardDB] ERROR: JSON parse failed")
		return
	UNITS = data.get("units", {})
	SPELLS = data.get("spells", {})
	STATUS_SPELLS = data.get("status_spells", {})
	SYSTEM_SPELLS = data.get("system_spells", {})
	CLASSES = data.get("classes", {})
	SYNTHESIS = data.get("synthesis", [])
	PLAYER_DECK = data.get("player_deck", [])
	PLAYER_SPELLS = data.get("player_spells", [])
	ENEMY_DECK = data.get("enemy_deck", [])
	ENEMY_POOLS = data.get("enemy_pools", {})
	ELITE_POOLS = data.get("elite_pools", {})
	BASE_DECK = data.get("base_deck", [])
	ARTIFACTS = data.get("artifacts", {})
	ENVIRONMENTS = data.get("environments", {})
	BOSSES = data.get("bosses", {})
	EVENTS = data.get("events", {})
	BOSS_DECKS = data.get("boss_decks", {})
	BOSS_EXCLUSIVE_UNITS = data.get("boss_exclusive_units", {})
	EQUIPMENT = data.get("equipment", {})
	MATERIALS = data.get("materials", [])

	# ボス専用ユニットをUNITSにマージ（プレイヤー入手不可フラグ付き）
	for unit_name in BOSS_EXCLUSIVE_UNITS:
		UNITS[unit_name] = BOSS_EXCLUSIVE_UNITS[unit_name]

	# 特性データ読み込み
	_load_traits()

	# プレイヤースキルデータ読み込み
	_load_player_skills()

func _load_traits() -> void:
	var file = FileAccess.open("res://data/traits.json", FileAccess.READ)
	if file == null:
		print("[CardDB] WARNING: data/traits.json not found")
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null:
		print("[CardDB] ERROR: traits.json parse failed")
		return
	TRAITS = data.get("traits", {})
	print("[CardDB] Loaded %d traits" % TRAITS.size())

func _load_player_skills() -> void:
	var file = FileAccess.open("res://data/player_skills.json", FileAccess.READ)
	if file == null:
		print("[CardDB] WARNING: data/player_skills.json not found")
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null:
		print("[CardDB] ERROR: player_skills.json parse failed")
		return
	PLAYER_SKILLS = data.get("player_skills", {})

	# sp_costをtierから自動計算
	for skill_id in PLAYER_SKILLS:
		var skill = PLAYER_SKILLS[skill_id]
		if skill.has("tier"):
			skill["sp_cost"] = skill["tier"]

	print("[CardDB] Loaded %d player skills" % PLAYER_SKILLS.size())