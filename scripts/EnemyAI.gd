# EnemyAI.gd
class_name EnemyAI
extends Node

var spawn_timer: float = 3.0
const SPAWN_INTERVAL: float = 3.5

var enemy_deck: Array = []
var enemy_discard: Array = []
var next_card: Object = null  # 次に召喚するカード（表示用に事前決定）

func _ready() -> void:
	_build_enemy_deck()
	_pick_next_card()

func _build_enemy_deck() -> void:
	# card_database.md 準拠のユニット定義（プレイヤーと同一データ）
	var card_pool: Dictionary = {
		"ゼリーフィッシュ":  {"hp":  8, "atk": 1, "interval": 1.0, "cost": 1, "race": "スライム",   "range": "1行"},
		"クリスタルスライム":{"hp": 15, "atk": 3, "interval": 2.0, "cost": 2, "race": "スライム",   "range": "1行"},
		"ブラッドスライム":  {"hp": 12, "atk": 4, "interval": 1.5, "cost": 2, "race": "スライム",   "range": "1行"},
		"シャドウ":          {"hp": 15, "atk": 3, "interval": 1.0, "cost": 2, "race": "アンデッド", "range": "1行"},
		"グール":            {"hp": 25, "atk": 5, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "1行"},
		"ワイト":            {"hp": 35, "atk": 4, "interval": 3.0, "cost": 3, "race": "アンデッド", "range": "1行"},
		"ゴブリン":          {"hp": 15, "atk": 3, "interval": 1.0, "cost": 1, "race": "獣",         "range": "1行"},
		"コカトリス":        {"hp": 18, "atk": 4, "interval": 2.0, "cost": 2, "race": "獣",         "range": "上含む2行"},
		"タイガー":          {"hp": 25, "atk": 8, "interval": 2.0, "cost": 3, "race": "獣",         "range": "下含む2行"},
	}

	# 敵デッキ構成（9枚・前列3/中列3/後列3 均等分散）
	# スライム3・アンデッド3・獣3 の種族バランス
	var deck_list: Array = [
		{"name": "ゼリーフィッシュ",   "col": 0},  # 前列 / スライム
		{"name": "シャドウ",           "col": 0},  # 前列 / アンデッド
		{"name": "ゴブリン",           "col": 0},  # 前列 / 獣
		{"name": "クリスタルスライム", "col": 1},  # 中列 / スライム
		{"name": "グール",             "col": 1},  # 中列 / アンデッド
		{"name": "コカトリス",         "col": 1},  # 中列 / 獣
		{"name": "ブラッドスライム",   "col": 2},  # 後列 / スライム
		{"name": "ワイト",             "col": 2},  # 後列 / アンデッド
		{"name": "タイガー",           "col": 2},  # 後列 / 獣
	]

	var UnitDataScript = load("res://scripts/UnitData.gd")
	for entry in deck_list:
		var d: Dictionary = card_pool[entry["name"]]
		var u = UnitDataScript.new()
		u.unit_name = entry["name"]
		u.max_hp = d["hp"]
		u.current_hp = d["hp"]
		u.attack = d["atk"]
		u.attack_interval = d["interval"]
		u.cost = d["cost"]
		u.assigned_col = entry["col"]
		u.race = d["race"]
		u.attack_range = d["range"]
		enemy_deck.append(u)
	enemy_deck.shuffle()

func _pick_next_card() -> void:
	# 山札が空なら捨て札をシャッフルして山札に戻す
	if enemy_deck.is_empty():
		if enemy_discard.is_empty():
			next_card = null
			return
		enemy_deck = enemy_discard.duplicate()
		enemy_discard.clear()
		enemy_deck.shuffle()
	next_card = enemy_deck[0]  # 山札先頭を次の召喚カードとして確定

func get_next_card() -> Object:
	return next_card

func process_ai(delta: float, board: Node) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = SPAWN_INTERVAL
		if next_card != null:
			board.place_unit(1, next_card)
			enemy_deck.remove_at(0)     # 山札から消費
			enemy_discard.append(next_card)  # 捨て札へ
		_pick_next_card()  # 次の召喚カードを事前決定
