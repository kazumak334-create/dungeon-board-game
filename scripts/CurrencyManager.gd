# CurrencyManager.gd
# Autoload: 通貨システムの一元管理（レート計算・変換・残高操作）
extends Node

signal balance_changed(new_balance: int, delta: int)

const CONFIG_PATH: String = "res://data/currency_config.json"

var _currencies: Array = []
var _currency_map: Dictionary = {}
var _default_display: String = "copper"

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		push_error("[CurrencyManager] 設定ファイル読み込み失敗: %s - デフォルト値を使用します" % CONFIG_PATH)
		_use_default_config()
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[CurrencyManager] JSON解析失敗: %s - デフォルト値を使用します" % CONFIG_PATH)
		_use_default_config()
		return
	
	var config = json.data
	if typeof(config) != TYPE_DICTIONARY:
		push_error("[CurrencyManager] 不正な設定フォーマット - デフォルト値を使用します")
		_use_default_config()
		return
	
	_currencies = config.get("currencies", [])
	_default_display = config.get("default_display", "copper")
	
	# 高速検索用のマップ作成
	_currency_map.clear()
	for currency in _currencies:
		var id = currency.get("id", "")
		if id != "":
			_currency_map[id] = currency

func _use_default_config() -> void:
	_currencies = [
		{"id": "copper", "display_name": "銅貨", "base_value": 1},
		{"id": "silver", "display_name": "銀貨", "base_value": 10},
		{"id": "gold", "display_name": "金貨", "base_value": 100}
	]
	_default_display = "copper"
	_currency_map.clear()
	for currency in _currencies:
		_currency_map[currency.id] = currency

# ========================================
# 残高操作
# ========================================

func get_balance() -> int:
	return GameSession.gold

func get_balance_as(currency_id: String) -> int:
	return to_currency(GameSession.gold, currency_id)

func add(amount: int) -> void:
	if amount <= 0:
		return
	
	var old_balance = GameSession.gold
	GameSession.gold += amount
	balance_changed.emit(GameSession.gold, amount)

func add_currency(currency_id: String, amount: int) -> void:
	if amount <= 0:
		return
	
	var copper_amount = to_copper(amount, currency_id)
	add(copper_amount)

func subtract(amount: int) -> bool:
	if amount <= 0:
		return true
	
	if GameSession.gold < amount:
		return false
	
	var old_balance = GameSession.gold
	GameSession.gold -= amount
	balance_changed.emit(GameSession.gold, -amount)
	return true

func subtract_currency(currency_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	
	var copper_amount = to_copper(amount, currency_id)
	return subtract(copper_amount)

func can_afford(amount: int) -> bool:
	return GameSession.gold >= amount

func can_afford_currency(currency_id: String, amount: int) -> bool:
	var copper_amount = to_copper(amount, currency_id)
	return can_afford(copper_amount)

# ========================================
# 変換・表示
# ========================================

func to_currency(copper_amount: int, currency_id: String) -> int:
	if not _currency_map.has(currency_id):
		push_error("[CurrencyManager] 未定義の通貨ID: %s" % currency_id)
		return copper_amount
	
	var base_value = _currency_map[currency_id].get("base_value", 1)
	if base_value <= 0:
		push_error("[CurrencyManager] 不正なbase_value: %s" % currency_id)
		return copper_amount
	
	return int(copper_amount / base_value)

func to_copper(amount: int, currency_id: String) -> int:
	if not _currency_map.has(currency_id):
		push_error("[CurrencyManager] 未定義の通貨ID: %s" % currency_id)
		return amount
	
	var base_value = _currency_map[currency_id].get("base_value", 1)
	return amount * base_value

func format_display(copper_amount: int) -> String:
	if copper_amount < 0:
		return "0銅貨"
	
	var result: Array = []
	var remaining = copper_amount
	
	# 金貨・銀貨・銅貨の順で分解
	for currency_id in ["gold", "silver", "copper"]:
		if not _currency_map.has(currency_id):
			continue
		
		var base_value = _currency_map[currency_id].get("base_value", 1)
		var display_name = _currency_map[currency_id].get("display_name", currency_id)
		
		var count = int(remaining / base_value)
		if count > 0:
			result.append("%d%s" % [count, display_name])
			remaining -= count * base_value
	
	if result.is_empty():
		return "0銅貨"
	
	return " ".join(result)

func format_single(copper_amount: int, currency_id: String) -> String:
	if not _currency_map.has(currency_id):
		push_error("[CurrencyManager] 未定義の通貨ID: %s" % currency_id)
		return "%d銅貨" % copper_amount
	
	var display_name = _currency_map[currency_id].get("display_name", currency_id)
	var amount = to_currency(copper_amount, currency_id)
	return "%d%s" % [amount, display_name]

# ========================================
# 設定取得
# ========================================

func get_currency_ids() -> Array:
	var ids: Array = []
	for currency in _currencies:
		ids.append(currency.get("id", ""))
	return ids

func get_display_name(currency_id: String) -> String:
	if not _currency_map.has(currency_id):
		push_error("[CurrencyManager] 未定義の通貨ID: %s" % currency_id)
		return currency_id
	
	return _currency_map[currency_id].get("display_name", currency_id)

func get_base_value(currency_id: String) -> int:
	if not _currency_map.has(currency_id):
		push_error("[CurrencyManager] 未定義の通貨ID: %s" % currency_id)
		return 1
	
	return _currency_map[currency_id].get("base_value", 1)
