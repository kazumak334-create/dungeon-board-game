# ConfigLoader.gd
# AutoLoad: バランス調整パラメータ外部設定ファイル読み込み
extends Node

const CONFIG_PATH: String = "res://config/balance.json"

# デフォルト値（balance.json が読み込めない場合のフォールバック）
const DEFAULT_CONFIG: Dictionary = {
	"mana_economy": {
		"initial_mana": 3,
		"mana_max": 3,
		"mana_regen_rate": 1.0
	},
	"battle_config": {
		"time_limit": 60.0,
		"player_base_hp": 30,
		"enemy_base_hp": 30
	},
	"alert_system": {
		"tile_effect_count_lv1": 3,
		"tile_effect_count_lv2": 3,
		"armor_damage_reduction": 2,
		"thorn_damage": 2,
		"curse_damage": 1
	},
	"drop_table": {
		"rarity_weights_early": {"common": 65, "uncommon": 30, "rare": 5, "epic": 0, "legend": 0, "god": 0},
		"rarity_weights_mid": {"common": 40, "uncommon": 40, "rare": 17, "epic": 3, "legend": 0, "god": 0},
		"rarity_weights_late": {"common": 20, "uncommon": 36, "rare": 30, "epic": 12, "legend": 2, "god": 0},
		"stage_early_max_depth": 3,
		"stage_mid_max_depth": 7
	},
	"rewards": {
		"battle_gold_base": 30,
		"battle_gold_variance": 20,
		"battle_sp": 1,
		"boss_gold": 200,
		"boss_sp": 2
	},
	"shop": {
		"rarity_price": {
			"common": 50,
			"uncommon": 100,
			"rare": 200,
			"epic": 400,
			"legend": 800
		},
		"reroll_cost": 10
	},
	"map_generation": {
		"node_weights": {
			"battle": 50,
			"elite": 15,
			"gather": 15,
			"shop": 10,
			"event": 10
		},
		"rest_node_chance": 0.2,
		"rest_node_depths": [4, 5, 6]
	}
}

var _config: Dictionary = {}
var _loaded: bool = false
# ランタイム値上書き（ゲーム起動中の一時変更・デバッグUI用）
var _runtime_overrides: Dictionary = {}

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			var error = json.parse(json_string)
			if error == OK:
				_config = json.data
				_loaded = true
				print("[ConfigLoader] balance.json 読み込み成功")
			else:
				print("[ConfigLoader] JSON parse error: %s" % json.get_error_message())
				_config = DEFAULT_CONFIG.duplicate(true)
		else:
			print("[ConfigLoader] balance.json 読み込み失敗")
			_config = DEFAULT_CONFIG.duplicate(true)
	else:
		print("[ConfigLoader] balance.json 未検出 -> デフォルト値使用")
		_config = DEFAULT_CONFIG.duplicate(true)

# ランタイム値上書き設定（デバッグUI専用）
func set_runtime_value(section: String, key: String, value) -> void:
	if not _runtime_overrides.has(section):
		_runtime_overrides[section] = {}
	_runtime_overrides[section][key] = value
	print("[ConfigLoader] ランタイム上書き: %s.%s = %s" % [section, key, str(value)])

# ランタイム値上書きクリア
func clear_runtime_overrides() -> void:
	_runtime_overrides.clear()
	print("[ConfigLoader] ランタイム上書き全クリア")

# 設定値取得（階層指定）ランタイム上書きを優先
func get_value(section: String, key: String, default = null):
	# ランタイム上書きを最優先
	if _runtime_overrides.has(section) and _runtime_overrides[section].has(key):
		return _runtime_overrides[section][key]
	# balance.json の値
	if _config.has(section) and _config[section].has(key):
		return _config[section][key]
	# デフォルト値
	if DEFAULT_CONFIG.has(section) and DEFAULT_CONFIG[section].has(key):
		return DEFAULT_CONFIG[section][key]
	return default

# 特定セクションを丸ごと取得
func get_section(section: String) -> Dictionary:
	if _config.has(section):
		return _config[section].duplicate(true)
	if DEFAULT_CONFIG.has(section):
		return DEFAULT_CONFIG[section].duplicate(true)
	return {}

# balance.json再読み込み
func reload_config() -> void:
	_runtime_overrides.clear()
	_load_config()
	print("[ConfigLoader] balance.json 再読み込み完了")
