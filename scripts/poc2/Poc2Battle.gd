class_name Poc2Battle
extends Node

signal wave_spawned(wave_num: int)
signal battle_ended(player_won: bool)
signal log_message(text: String)

const WAVE_INTERVAL := 30.0
const MAX_WAVES := 5
const ENEMY_SPAWN_ROW := 10

var player_units: Array = []   # PoCUnit (戦闘)
var harvesters: Array = []     # Poc2Harvester
var buildings: Array = []      # Poc2Building
var enemy_units: Array = []    # PoCUnit

var grid: Node  # Poc2Grid
var economy: Node  # Poc2Economy

var _wave_timer: float = 0.0
var _waves_spawned: int = 0
var _waves_defeated: int = 0
var is_running: bool = false

func setup(g: Node, eco: Node) -> void:
	grid = g
	economy = eco

func start() -> void:
	is_running = true
	_wave_timer = 0.0
	log_message.emit("バトル開始！ウェーブ待機中...")

func update(delta: float) -> void:
	if not is_running:
		return
	# 経済更新
	var total_units: int = player_units.size() + harvesters.size() + enemy_units.size()
	economy.update(delta, total_units)
	# ハーベスター更新
	var all_movable: Array = player_units + harvesters + enemy_units
	for h in harvesters:
		if h.is_alive:
			h.update(delta, grid, all_movable)
	# 建造物更新
	for b in buildings:
		b.update(delta, economy)
	# 戦闘ユニット更新
	var all_units: Array = player_units + enemy_units
	for u in player_units:
		if u.is_alive:
			u.update(delta, enemy_units, grid, all_units)
	for u in enemy_units:
		if u.is_alive:
			u.update(delta, player_units, grid, all_units)
	# 死亡処理
	_remove_dead()
	# ウェーブスポーン
	_wave_timer += delta
	if _wave_timer >= WAVE_INTERVAL and _waves_spawned < MAX_WAVES:
		_wave_timer = 0.0
		_spawn_wave()
	# 勝敗チェック
	_check_victory()

func _spawn_wave() -> void:
	_waves_spawned += 1
	log_message.emit("ウェーブ %d 開始！" % _waves_spawned)
	wave_spawned.emit(_waves_spawned)
	# 敵3体をランダムなrow10マスにスポーン
	var spawn_cols: Array = [0, 2, 4]
	spawn_cols.shuffle()
	for i in range(3):
		var col: int = spawn_cols[i]
		var row: int = ENEMY_SPAWN_ROW
		if not grid.is_valid_cell(col, row):
			col = 0
		var unit := PoCUnit.create(PoCUnit.UnitType.ATTACKER, PoCUnit.Side.ENEMY, col, row)
		unit.position = grid.hex_to_pixel(col, row)
		enemy_units.append(unit)
		get_parent().add_child(unit)

func _remove_dead() -> void:
	var before_enemy := enemy_units.size()
	player_units = player_units.filter(func(u): return u.is_alive)
	harvesters = harvesters.filter(func(h): return h.is_alive)
	enemy_units = enemy_units.filter(func(u): return u.is_alive)
	var after_enemy := enemy_units.size()
	if after_enemy < before_enemy and enemy_units.is_empty() and _waves_spawned > 0:
		_waves_defeated += 1
		if _waves_defeated >= MAX_WAVES:
			is_running = false
			battle_ended.emit(true)

func _check_victory() -> void:
	# 敗北: 敵がrow2以下に到達
	for u in enemy_units:
		if u.grid_pos.y <= 2:
			is_running = false
			battle_ended.emit(false)
			log_message.emit("敗北...敵が防衛ラインを突破しました")
			return

func spawn_player_unit(col: int, row: int) -> void:
	# 兵舎が呼び出す：プレイヤー側突ユニット生産
	var unit := PoCUnit.create(PoCUnit.UnitType.ATTACKER, PoCUnit.Side.PLAYER, col, row)
	unit.position = grid.hex_to_pixel(col, row)
	player_units.append(unit)
	get_parent().add_child(unit)
	log_message.emit("兵舎がユニットを生産 at (%d,%d)" % [col, row])
