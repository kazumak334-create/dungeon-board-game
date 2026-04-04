# DeckManager.gd
class_name DeckManager
extends Node

var mana: float = 3.0
const MANA_MAX: float = 10.0
const MANA_REGEN: float = 1.0

var deck: Array = []
var discard: Array = []
var spell_executor: RefCounted = null  # SpellExecutor（Main.gd が設定）
var enemy_ai_ref: Node = null          # EnemyAI参照（Main.gd が設定）
var _cost_reduction_remaining: int = 0 # 連鎖の触媒：残りコスト軽減枚数

# 発動チェック間隔（初期値1秒。将来ユニット効果で変更可能）
var check_interval: float = 1.0
var _check_timer: float = 0.0

signal card_played(unit: Object)
signal mana_changed(current: float)

func _ready() -> void:
	_build_default_deck()

func _build_default_deck() -> void:
	var card_pool: Dictionary = {
		# ── スライム系 ──
		"アメーバ": {
			"hp":  5, "atk": 1, "interval": 0.5, "cost": 1, "race": "スライム", "range": "1行",
			"support": "HPバフ〈常時発動・前列の味方のみ・微回復〉",
			"active":  "追加召喚〈召喚時・隣接マスに同種を1体〉",
		},
		"マッドスライム": {
			"hp": 10, "atk": 2, "interval": 1.0, "cost": 1, "race": "スライム", "range": "1行",
			"support": "障壁付与〈常時発動・同行前列の味方・物理軽減〉",
			"active":  "火傷付与〈命中時・敵ATK低下〉 / SPD低下〈時間経過10s・同行の敵全体〉",
		},
		"ブラッドスライム": {
			"hp": 12, "atk": 4, "interval": 1.5, "cost": 2, "race": "スライム", "range": "1行",
			"support": "吸血付与〈常時発動・隣接の味方〉",
			"active":  "吸血〈命中時・ダメージ30%回復〉 / 全体回復〈時間経過20s・HP20%消費→全味方+10〉",
		},
		# ── アンデッド系 ──
		"スケルトン": {
			"hp": 20, "atk": 4, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "1行",
			"support": "再起付与〈常時発動・隣接の味方・HP1で1度復活〉",
			"active":  "自己再起〈撃破時・HP5で復活〉",
		},
		"グール": {
			"hp": 25, "atk": 5, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "1行",
			"support": "デバフ波及〈常時発動・前列の敵・撃破時に周囲の敵にデバフ波及〉",
			"active":  "吸血〈命中時・ダメージ25%回復〉 / ATK累積〈撃破時・+2（上限10）〉",
		},
		"バンシー": {
			"hp": 10, "atk": 1, "interval": 2.0, "cost": 2, "race": "アンデッド", "range": "上下含む3行",
			"support": "後列攻撃〈常時発動・全行・極低ATK・命中時効果あり〉 / SPDバフ〈常時発動・同列の味方〉",
			"active":  "火傷付与〈命中時・敵ATK低下〉 / 全体ATK低下〈時間経過15s・敵全行〉 / 敵SPD低下〈撃破時・全体30%・30s〉",
		},
		# ── 獣系 ──
		"ゴブリン": {
			"hp": 15, "atk": 3, "interval": 1.0, "cost": 1, "race": "獣", "range": "1行",
			"support": "ATKバフ〈常時発動・隣接の獣のみ〉",
			"active":  "2枚ドロー〈召喚時・次の2枚をキューに同時積み〉",
		},
		"ウルフ": {
			"hp": 20, "atk": 5, "interval": 1.5, "cost": 2, "race": "獣", "range": "1行",
			"support": "SPDバフ〈常時発動・同行の獣・同行獣数に比例〉",
			"active":  "ATKバフ〈時間経過10s・同行の獣全員+3（5s）〉",
		},
		"タイガー": {
			"hp": 25, "atk": 8, "interval": 2.0, "cost": 3, "race": "獣", "range": "下含む2行",
			"support": "ATKバフ〈常時発動・隣接の獣のみ〉",
			"active":  "クリティカル〈命中時・初撃ATK×2〉 / 最前列突撃〈召喚時〉 / 単体大ダメージ〈時間経過20s〉",
		},
	}

	# 呪文card_pool
	var spell_pool: Dictionary = {
		"召喚加速":   {"cost": 1, "target": "self",         "effect": "マナ即時+3回復"},
		"生命の雫":   {"cost": 2, "target": "single_ally",  "effect": "対象ユニットHP15%回復"},
		"盤面強化":   {"cost": 3, "target": "all_allies",   "effect": "全味方HP+10・ATK+2"},
	}

	# 初期デッキ構成（ユニット9枚 + 呪文3枚 = 12枚）
	var deck_list: Array = [
		{"name": "アメーバ",       "col": 0},
		{"name": "スケルトン",     "col": 0},
		{"name": "ゴブリン",       "col": 0},
		{"name": "マッドスライム", "col": 1},
		{"name": "グール",         "col": 1},
		{"name": "ウルフ",         "col": 1},
		{"name": "ブラッドスライム","col": 2},
		{"name": "バンシー",       "col": 2},
		{"name": "タイガー",       "col": 2},
	]
	var spell_list: Array = ["召喚加速", "生命の雫", "盤面強化"]

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
		deck.append(u)
	for spell_name in spell_list:
		var d: Dictionary = spell_pool[spell_name]
		var u = UnitDataScript.new()
		u.unit_name = spell_name
		u.card_type = "spell"
		u.spell_id = spell_name
		u.cost = d["cost"]
		u.spell_target = d["target"]
		u.spell_effect = d["effect"]
		deck.append(u)
	deck.shuffle()

func process_deck(delta: float, board: Node) -> void:
	mana = min(MANA_MAX, mana + MANA_REGEN * delta)
	emit_signal("mana_changed", mana)

	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = check_interval

	if deck.is_empty():
		if discard.is_empty():
			return
		deck = discard.duplicate()
		discard.clear()
		deck.shuffle()
	var top = deck[0]
	# コスト計算（連鎖の触媒によるコスト軽減）
	var effective_cost: int = top.cost
	if top.cost == -1:
		effective_cost = int(mana)  # コストXカード：マナ全額
		if effective_cost <= 0:
			return
	elif _cost_reduction_remaining > 0:
		effective_cost = max(0, top.cost - 1)
	if mana < effective_cost:
		return
	mana -= effective_cost
	deck.remove_at(0)
	if _cost_reduction_remaining > 0 and top.cost != -1:
		_cost_reduction_remaining -= 1
	# カードタイプ別処理
	if top.card_type == "unit":
		board.place_unit(0, top)
		emit_signal("card_played", top)
		discard.append(top)
	elif top.card_type == "spell":
		if top.cost == -1:
			top.cost = effective_cost  # 再召喚用：X値をcostに設定
		emit_signal("card_played", top)
		var to_discard: bool = spell_executor.execute(top, 0, board, self, enemy_ai_ref)
		if to_discard:
			discard.append(top)
	elif top.card_type == "status_spell":
		emit_signal("card_played", top)
		spell_executor.execute(top, 0, board, self, enemy_ai_ref)
		# 消滅：捨て札に行かない

func force_play_card(board: Node) -> void:
	if deck.is_empty():
		if discard.is_empty():
			return
		deck = discard.duplicate()
		discard.clear()
		deck.shuffle()
	var top = deck[0]
	deck.remove_at(0)
	if top.card_type == "unit":
		board.place_unit(0, top)
		emit_signal("card_played", top)
		discard.append(top)
	elif top.card_type == "spell":
		emit_signal("card_played", top)
		var to_discard: bool = spell_executor.execute(top, 0, board, self, enemy_ai_ref)
		if to_discard:
			discard.append(top)
	elif top.card_type == "status_spell":
		emit_signal("card_played", top)
		spell_executor.execute(top, 0, board, self, enemy_ai_ref)

func get_next_card() -> Object:
	if deck.is_empty():
		return null
	return deck[0]
