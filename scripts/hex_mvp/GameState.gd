class_name GameStateClass
extends Node

# デッキ（手持ちユニット種類IDの配列）
# UnitTypeのint値を格納（0=ATTACKER, 1=TANK, 2=BREAKER）
var deck: Array[int] = []

# 現在のWave番号（1〜3）
var current_wave: int = 1

# 配置されたユニット（Wave開始時に決まる）
# [{unit_type: int, col: int, row: int}, ...]
var deployed_units: Array = []

# バトル結果（BattleScreen→ResultScreenへの受け渡し）
var last_battle_won: bool = false

# 定数
const DECK_MAX: int = 12
const DEPLOY_MAX: int = 8
const WAVE_COUNT: int = 3

func reset_run() -> void:
	print("[GameState] reset_run called")
	deck = get_initial_deck()
	current_wave = 1
	deployed_units = []
	last_battle_won = false

func add_to_deck(unit_type: int) -> bool:
	if deck.size() >= DECK_MAX:
		print("[GameState] deck full, cannot add unit_type=", unit_type)
		return false
	deck.append(unit_type)
	print("[GameState] added unit_type=", unit_type, " deck_size=", deck.size())
	return true

func get_initial_deck() -> Array[int]:
	# 突2 守2 崩2
	return [0, 0, 1, 1, 2, 2]
