# GameSession.gd
# Autoload: ランデータの一時保管（画面遷移間のデータ引き継ぎ）
extends Node

var class_id: String = ""
var selected_deck: Array = []
var last_result: Dictionary = {"win": false, "player_hp_remaining": 0, "enemy_hp_dealt": 0, "turns": 0}
var run_depth: int = 0
var artifacts_acquired: Array = []

func reset() -> void:
	class_id = ""
	selected_deck = []
	last_result = {"win": false, "player_hp_remaining": 0, "enemy_hp_dealt": 0, "turns": 0}
	run_depth = 0
	artifacts_acquired = []
	print("[GameSession] reset")
