# DeckManager.gd
class_name DeckManager
extends Node

var mana: float = 3.0
const MANA_MAX: float = 10.0
const MANA_REGEN: float = 1.0

var deck: Array = []

# 発動チェック間隔（初期値1秒。将来ユニット効果で変更可能）
var check_interval: float = 1.0
var _check_timer: float = 0.0

signal card_played(unit: Object)
signal mana_changed(current: float)

func _ready() -> void:
	_build_default_deck()

func _build_default_deck() -> void:
	# card_database.md 準拠のユニット定義（race・attack_range を含む。col は deck_list 側で指定）
	var card_pool: Dictionary = {
		"アメーバ":        {"hp":  5, "atk": 1, "interval": 0.5, "cost": 1, "race": "スライム",   "range": "1行"},
		"マッドスライム":  {"hp": 10, "atk": 2, "interval": 1.0, "cost": 1, "race": "スライム",   "range": "1行"},
		"ゼリーフィッシュ":{"hp":  8, "atk": 1, "interval": 1.0, "cost": 1, "race": "スライム",   "range": "1行"},  # 将来のデッキ構築機能用予備カード
		"スケルトン":      {"hp": 20, "atk": 4, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "1行"},
		"グール":          {"hp": 25, "atk": 5, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "1行"},
		"バンシー":        {"hp": 10, "atk": 1, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "上下含む3行"},
		"ゴブリン":        {"hp": 15, "atk": 3, "interval": 1.0, "cost": 1, "race": "獣",         "range": "1行"},
		"ウルフ":          {"hp": 20, "atk": 5, "interval": 1.5, "cost": 2, "race": "獣",         "range": "1行"},
		"コカトリス":      {"hp": 18, "atk": 4, "interval": 2.0, "cost": 2, "race": "獣",         "range": "上含む2行"},  # 将来のデッキ構築機能用予備カード
	}

	# 初期デッキ構成（9枚・前列3/中列3/後列3 均等分散）
	# col: 0=前列 1=中列 2=後列（assigned_col。place_unit で 2-col に変換される）
	var deck_list: Array = [
		{"name": "アメーバ",       "col": 0},  # 前列
		{"name": "ゴブリン",       "col": 0},  # 前列
		{"name": "グール",         "col": 0},  # 前列
		{"name": "マッドスライム", "col": 1},  # 中列
		{"name": "ウルフ",         "col": 1},  # 中列
		{"name": "バンシー",       "col": 1},  # 中列
		{"name": "スケルトン",     "col": 2},  # 後列
		{"name": "アメーバ",       "col": 2},  # 後列
		{"name": "ゴブリン",       "col": 2},  # 後列
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
		deck.append(u)
	deck.shuffle()

func process_deck(delta: float, board: Node) -> void:
	# マナ毎フレーム回復
	mana = min(MANA_MAX, mana + MANA_REGEN * delta)
	emit_signal("mana_changed", mana)

	# 発動チェックは check_interval ごと
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = check_interval

	if deck.is_empty():
		return
	var top = deck[0]
	if mana < top.cost:
		# マナ不足：消費せずに捨て札（末尾）へ送る
		deck.remove_at(0)
		deck.append(top)
		return
	mana -= top.cost
	deck.remove_at(0)
	board.place_unit(0, top)
	emit_signal("card_played", top)
	deck.append(top)

func get_next_card() -> Object:
	if deck.is_empty():
		return null
	return deck[0]
