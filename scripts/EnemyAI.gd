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
	# card_database.md 準拠のユニット定義（プレイヤーと異なるカードセット）
	var card_pool: Dictionary = {
		# ── スライム系 ──
		"ゼリーフィッシュ": {
			"hp":  8, "atk": 1, "interval": 1.0, "cost": 1, "race": "スライム", "range": "1行",
			"support": "HPバフ〈常時発動・隣接の味方〉",
			"active":  "毒付与〈命中時・継続ダメージスタック可〉 / 追加ダメージ〈その他・毒3スタック時〉 / 後退〈HP閾値30%以下・後列に退避〉",
		},
		"ミミック": {
			"hp": 10, "atk": 2, "interval": 1.0, "cost": 2, "race": "スライム", "range": "1行",
			"support": "シナジー増幅〈常時発動・同列の味方・隣接効果の発動頻度・強度UP〉",
			"active":  "毒付与〈命中時〉 / 能力コピー〈時間経過15s・最強隣接味方の能力値を一時コピー〉",
		},
		"アビスゼリー": {
			"hp": 20, "atk": 3, "interval": 2.0, "cost": 3, "race": "スライム", "range": "1行",
			"support": "後列攻撃〈常時発動・1行・命中時効果あり〉 / HPバフ〈常時発動・全体〉",
			"active":  "石化付与〈命中時・5s攻撃不能〉 / 全体石化〈時間経過20s・敵全行〉",
		},
		# ── アンデッド系 ──
		"シャドウ": {
			"hp": 15, "atk": 3, "interval": 1.0, "cost": 2, "race": "アンデッド", "range": "1行",
			"support": "障壁付与〈常時発動・隣接の味方〉",
			"active":  "貫通〈命中時・後列にも50%減衰ダメージ〉 / 前列突撃＋透明化5s〈召喚時〉",
		},
		"ヴリコラカス": {
			"hp": 30, "atk": 6, "interval": 2.0, "cost": 3, "race": "アンデッド", "range": "1行",
			"support": "デバフ波及〈常時発動・隣接の敵〉",
			"active":  "バフ奪取〈命中時・敵バフを自分に1.5倍〉 / 全バフ奪取〈時間経過20s・敵1体〉",
		},
		"ワイト": {
			"hp": 35, "atk": 4, "interval": 3.0, "cost": 3, "race": "アンデッド", "range": "1行",
			"support": "デバフ波及〈常時発動・同行の敵・凍結波及〉",
			"active":  "凍結付与〈命中時・3s行動不能〉 / 全体凍結〈時間経過18s・同行の敵〉",
		},
		# ── 獣系 ──
		"コカトリス": {
			"hp": 18, "atk": 4, "interval": 2.0, "cost": 2, "race": "獣", "range": "上含む2行",
			"support": "石化付与〈時間経過10s・敵前列ランダム1体〉",
			"active":  "石化付与〈命中時・5s攻撃不能〉 / 全体石化〈時間経過15s・同行の敵〉",
		},
		"ケットシー": {
			"hp": 12, "atk": 2, "interval": 1.0, "cost": 2, "race": "獣", "range": "1行",
			"support": "シナジー増幅〈常時発動・隣接の味方・隣接効果UP〉",
			"active":  "指定ドロー〈時間経過10s・最低コストユニットをキュー先頭へ〉",
		},
		"マンティコア": {
			"hp": 30, "atk": 7, "interval": 2.0, "cost": 3, "race": "獣", "range": "下含む2行",
			"support": "デバフ波及〈常時発動・同行の敵・毒波及〉",
			"active":  "貫通＋毒付与〈命中時〉 / 強力な毒〈時間経過18s・同行の敵全体〉",
		},
	}

	# 敵デッキ構成（9枚・前列3/中列3/後列3）
	# スライム3・アンデッド3・獣3
	var deck_list: Array = [
		{"name": "ゼリーフィッシュ", "col": 0},  # 前列 / スライム
		{"name": "シャドウ",         "col": 0},  # 前列 / アンデッド
		{"name": "コカトリス",       "col": 0},  # 前列 / 獣
		{"name": "ミミック",         "col": 1},  # 中列 / スライム
		{"name": "ヴリコラカス",     "col": 1},  # 中列 / アンデッド
		{"name": "ケットシー",       "col": 1},  # 中列 / 獣
		{"name": "アビスゼリー",     "col": 2},  # 後列 / スライム
		{"name": "ワイト",           "col": 2},  # 後列 / アンデッド
		{"name": "マンティコア",     "col": 2},  # 後列 / 獣
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
		u.support_effect = d["support"]
		u.active_skill = d["active"]
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
			enemy_deck.remove_at(0)          # 山札から消費
			enemy_discard.append(next_card)  # 捨て札へ
		_pick_next_card()  # 次の召喚カードを事前決定
