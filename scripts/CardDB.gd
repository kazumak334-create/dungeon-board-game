# CardDB.gd
# カードデータベース（JSONファイルから読み込み）
extends RefCounted

var UNITS: Dictionary = {}
var SPELLS: Dictionary = {}
var STATUS_SPELLS: Dictionary = {}
var SYSTEM_SPELLS: Dictionary = {}
var ARTIFACTS: Dictionary = {}
var EQUIPMENT: Dictionary = {}
var CLASSES: Dictionary = {}
var SYNTHESIS: Array = []
var PLAYER_DECK: Array = []
var PLAYER_SPELLS: Array = []
var ENEMY_DECK: Array = []

func _init() -> void:
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
	ARTIFACTS = data.get("artifacts", {})
	EQUIPMENT = data.get("equipment", {})
	CLASSES = data.get("classes", {})
	SYNTHESIS = data.get("synthesis", [])
	PLAYER_DECK = data.get("player_deck", [])
	PLAYER_SPELLS = data.get("player_spells", [])
	ENEMY_DECK = data.get("enemy_deck", [])
