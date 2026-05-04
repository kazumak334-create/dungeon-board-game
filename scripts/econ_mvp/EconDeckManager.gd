class_name EconDeckManager
extends Node

# 要件定義書 req_econ_draw_hand_circulation.md §8.1 に準拠

# 定数（パラメータ化・§13.6）
const TURN_DURATION_SEC: float = 30.0
const MAX_TURNS: int = 10
const HAND_MAX_SIZE: int = 8  # ★ v0.2 改訂（5→8）
const INITIAL_HAND_SIZE: int = 5
const LIBRARY_CD_SEC: float = 5.0
const LIBRARY_DRAW_COST_CURRENCY: int = 1
const INITIAL_DECK_SPEC: Array = [
	{"id": "card_house", "count": 3},
	{"id": "card_village", "count": 2},
	{"id": "card_wood_extractor", "count": 2},
	{"id": "card_stone_extractor", "count": 2},
	{"id": "card_diner", "count": 1},
	{"id": "card_barracks", "count": 1},
	{"id": "card_plaza", "count": 1},
	{"id": "card_trade_post", "count": 1},
]

# 状態（§7.2）
var deck: Array = []           # Array[Dictionary]（Card）
var hand: Array = []           # Array[Dictionary]
var discard_pile: Array = []   # v0.1未使用
var excluded: Array = []       # 建設後カード

var draw_gauge_value: float = 0.0
var current_turn: int = 0
var pending_draws: int = 0
var force_charge_triggered: bool = false
var battle_elapsed_sec: float = 0.0

# リロードクールタイム（§2.2.3）
var reload_timer: float = 0.0
const RELOAD_COOLDOWN_SEC: float = 5.0

var draw_callback: Callable       # UI通知（カード飛来Tween発火）
var battle: EconBattle = null     # 親バトル参照

# デッキロードフラグ（_ready前に setup が呼ばれることへの対応）
var _initialized: bool = false
# ターン境界の二重発火防止用（直前のターン番号を保持）
var _last_processed_turn: int = 0

func setup(initial_deck: Array, battle_ref: EconBattle, on_draw: Callable) -> void:
	# §8.1.2 setup
	print("[EconDeckManager] setup: deck=%d cards" % initial_deck.size())
	deck = initial_deck.duplicate()
	deck.shuffle()
	hand = []
	discard_pile = []
	excluded = []
	current_turn = 1
	_last_processed_turn = 1  # ターン1ドロー不要（初期5枚で補完）
	battle = battle_ref
	draw_callback = on_draw
	_initialized = true
	# 初期手札5枚を確定ドロー（§2.2.2）
	for i in range(INITIAL_HAND_SIZE):
		draw_card()
	print("[EconDeckManager] initial hand: %d cards" % hand.size())

func update(delta: float) -> void:
	# §4.3 §9.1 §9.2 ターン進行とドローゲージ更新
	if not _initialized:
		return
	if force_charge_triggered:
		return

	battle_elapsed_sec += delta
	# ターン番号は経過秒から独立算出（§4.3 ドロー保留と無関係）
	# +1 で 1始まり（t=0〜30秒=ターン1 / §4.3具体例「ターン1(t=0〜30秒)」準拠）
	current_turn = int(battle_elapsed_sec / TURN_DURATION_SEC) + 1

	# ターン境界を検知してドロー発火（二重発火防止）
	if current_turn > _last_processed_turn:
		_last_processed_turn = current_turn
		_on_turn_elapsed()

	# リロードクールタイム更新（§2.2.3）
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer < 0.0:
			reload_timer = 0.0

	# draw_gauge_value 更新（手札MAX保留中はゲージ100%停止）
	if pending_draws > 0:
		draw_gauge_value = TURN_DURATION_SEC
	else:
		# 現在ターン内の経過秒（0.0〜30.0）
		draw_gauge_value = fmod(battle_elapsed_sec, TURN_DURATION_SEC)

func _on_turn_elapsed() -> void:
	# §9.1 ターン経過時のドロー発動
	print("[EconDeckManager] turn elapsed: current_turn=%d" % current_turn)
	draw_card()
	# ターン10ドロー直後に強制突撃自動発動（§4.5, §9.3）
	if current_turn >= MAX_TURNS:
		print("[EconDeckManager] MAX_TURNS reached, triggering force charge")
		trigger_force_charge()

func draw_card() -> Dictionary:
	# §8.1.3 draw_card
	# 山札枯渇チェック（§9.5）
	if deck.is_empty():
		print("[EconDeckManager] draw_card: deck empty, skip")
		draw_gauge_value = 0.0
		return {}
	# 手札MAX保留（§4.3）
	if hand.size() >= HAND_MAX_SIZE:
		print("[EconDeckManager] draw_card: hand full, pending_draws=%d" % (pending_draws + 1))
		pending_draws += 1
		return {}
	# 通常ドロー
	var card: Dictionary = deck.pop_front()
	hand.append(card)
	draw_gauge_value = 0.0
	print("[EconDeckManager] draw_card: drew '%s', hand=%d, deck=%d" % [card.get("name", "?"), hand.size(), deck.size()])
	# UI通知（カード飛来Tween発火）
	if draw_callback.is_valid():
		draw_callback.call(card)
	return card

func discard_card(card: Dictionary) -> void:
	# §8.1.2 discard_card（v0.1未使用、APIのみ）
	hand.erase(card)
	discard_pile.append(card)
	print("[EconDeckManager] discard_card: '%s'" % card.get("name", "?"))

func exclude_card(card: Dictionary) -> void:
	# §8.1.3 exclude_card（建設完了時）
	# 配列直接操作は本クラス内のみ（ADR-001）
	hand.erase(card)
	excluded.append(card)
	print("[EconDeckManager] exclude_card: '%s', hand=%d, excluded=%d" % [card.get("name", "?"), hand.size(), excluded.size()])

func exclude_card_at(idx: int) -> Dictionary:
	# §8.1.2 exclude_card_at（インデックス指定・§4.4.3 ステップ②）
	if idx < 0 or idx >= hand.size():
		print("[EconDeckManager] exclude_card_at: invalid idx=%d" % idx)
		return {}
	var card: Dictionary = hand[idx]
	hand.remove_at(idx)
	excluded.append(card)
	print("[EconDeckManager] exclude_card_at: '%s', hand=%d, excluded=%d" % [card.get("name", "?"), hand.size(), excluded.size()])
	return card

func remove_card_at(idx: int) -> Dictionary:
	if idx < 0 or idx >= hand.size():
		print("[EconDeckManager] remove_card_at: invalid idx=%d" % idx)
		return {}
	var card: Dictionary = hand[idx]
	hand.remove_at(idx)
	print("[EconDeckManager] remove_card_at: '%s', hand=%d" % [card.get("name", "?"), hand.size()])
	return card

func play_card(card_idx: int) -> Dictionary:
	# §8.1.2 play_card: hand から remove、exclude_card を呼び、カードを返す
	if card_idx < 0 or card_idx >= hand.size():
		print("[EconDeckManager] play_card: invalid idx=%d" % card_idx)
		return {}
	var card: Dictionary = hand[card_idx]
	exclude_card(card)
	return card

func request_library_draw() -> bool:
	# §8.1.3 request_library_draw（書庫ドロー）
	if battle == null or battle.economy == null:
		return false
	if battle.economy.currency < LIBRARY_DRAW_COST_CURRENCY:
		print("[EconDeckManager] request_library_draw: currency insufficient")
		return false
	if deck.is_empty():
		print("[EconDeckManager] request_library_draw: deck empty")
		return false
	battle.economy.currency -= LIBRARY_DRAW_COST_CURRENCY
	draw_card()
	return true

func try_resolve_pending_draws() -> void:
	# §4.3 毎フレーム呼出。pending_draws > 0 かつ手札<8 なら1枚消化
	if pending_draws <= 0:
		return
	if hand.size() >= HAND_MAX_SIZE:
		return
	if deck.is_empty():
		pending_draws = 0
		print("[EconDeckManager] try_resolve_pending_draws: deck empty, clear pending")
		return
	pending_draws -= 1
	print("[EconDeckManager] try_resolve_pending_draws: resolve pending, remaining=%d" % pending_draws)
	draw_card()

func trigger_force_charge() -> void:
	# §8.1.3 trigger_force_charge
	if force_charge_triggered:
		return
	force_charge_triggered = true
	print("[EconDeckManager] trigger_force_charge: activated")
	# 全プレイヤーユニットの target_priority を「前線制圧」（1）に上書き（§4.5）
	if battle != null:
		for u in battle.player_units:
			if u.is_alive:
				u.target_priority = 1  # 前線制圧
		# 旗倒しイベントも自動連鎖発火（§9.6）
		for f in battle.player_flags:
			f.is_assault_mode = true
			f.queue_redraw()

func refresh_hand_ui() -> void:
	# §8.1.2 refresh_hand_ui（draw_callback でも代替可）
	if draw_callback.is_valid():
		draw_callback.call({})

func is_battle_ended_by_turn_limit() -> bool:
	# §8.1.2
	return current_turn >= MAX_TURNS and force_charge_triggered

func get_econ_state_snapshot() -> Dictionary:
	# §7.2 UI描画用 state スナップショット（v0.2 拡張）
	var eco: EconEconomy = battle.economy if battle != null else null
	return {
		"deck_count": deck.size(),
		"hand": hand.duplicate(),
		"discard_count": discard_pile.size(),
		"excluded_count": excluded.size(),
		"draw_gauge_value": draw_gauge_value,
		"draw_gauge_max": TURN_DURATION_SEC,
		"current_turn": current_turn,
		"force_charge_triggered": force_charge_triggered,
		"currency": eco.currency if eco != null else 0,
		"food": eco.food if eco != null else 0,
		"satisfaction": eco.satisfaction if eco != null else 0,
		"military_power": eco.military_power if eco != null else 0.0,
		"population_used": eco.population_used if eco != null else 0,
		"population_cap": eco.population_cap if eco != null else 0,
		"resources": eco.resources.duplicate() if eco != null else {},
	}
