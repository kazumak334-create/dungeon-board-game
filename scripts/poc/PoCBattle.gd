class_name PoCBattle
extends Node

enum Phase { SETUP, BATTLE, END }
enum Pattern { BALANCED, ATTACKER_VS_TANK, TANK_VS_BREAKER, BREAKER_VS_ATTACKER, FOCUS_VS_SPREAD }

signal battle_ended(player_won: bool)
signal unit_died(unit: Node2D)
signal attack_logged(attacker_type: int, defender_type: int, damage: float, multiplier: float)
signal kill_logged(unit_type: int, side: int, pos: Vector2i)

var phase: Phase = Phase.SETUP
var player_units: Array = []
var enemy_units: Array = []
var hex_grid: Node  # HexGrid
var current_pattern: Pattern = Pattern.BALANCED

func setup(hg: Node) -> void:
	hex_grid = hg

func setup_units_for_pattern(pattern: int) -> void:
	current_pattern = pattern
	player_units.clear()
	enemy_units.clear()
	match pattern:
		Pattern.BALANCED:
			_setup_balanced()
		Pattern.ATTACKER_VS_TANK:
			_setup_attacker_vs_tank()
		Pattern.TANK_VS_BREAKER:
			_setup_tank_vs_breaker()
		Pattern.BREAKER_VS_ATTACKER:
			_setup_breaker_vs_attacker()
		Pattern.FOCUS_VS_SPREAD:
			_setup_focus_vs_spread()
	print("[PoCBattle] pattern=", pattern, " player=", player_units.size(), " enemy=", enemy_units.size())

func setup_default_units() -> void:
	setup_units_for_pattern(Pattern.BALANCED)

func _setup_balanced() -> void:
	# プレイヤー row2（偶数）: 突2守2崩2
	_add_player_unit(PoCUnit.UnitType.ATTACKER, 1, 2)
	_add_player_unit(PoCUnit.UnitType.ATTACKER, 4, 2)
	_add_player_unit(PoCUnit.UnitType.TANK, 2, 2)
	_add_player_unit(PoCUnit.UnitType.TANK, 3, 2)
	_add_player_unit(PoCUnit.UnitType.BREAKER, 0, 2)
	_add_player_unit(PoCUnit.UnitType.BREAKER, 5, 2)
	# 敵 row10（偶数）: 突2守2崩2
	_add_enemy_unit(PoCUnit.UnitType.ATTACKER, 1, 10)
	_add_enemy_unit(PoCUnit.UnitType.ATTACKER, 4, 10)
	_add_enemy_unit(PoCUnit.UnitType.TANK, 2, 10)
	_add_enemy_unit(PoCUnit.UnitType.TANK, 3, 10)
	_add_enemy_unit(PoCUnit.UnitType.BREAKER, 0, 10)
	_add_enemy_unit(PoCUnit.UnitType.BREAKER, 5, 10)

func _setup_attacker_vs_tank() -> void:
	# プレイヤー row2（偶数）: 突6
	for c in range(6):
		_add_player_unit(PoCUnit.UnitType.ATTACKER, c, 2)
	# 敵 row10（偶数）: 守6
	for c in range(6):
		_add_enemy_unit(PoCUnit.UnitType.TANK, c, 10)

func _setup_tank_vs_breaker() -> void:
	# プレイヤー row2（偶数）: 守6
	for c in range(6):
		_add_player_unit(PoCUnit.UnitType.TANK, c, 2)
	# 敵 row10（偶数）: 崩6
	for c in range(6):
		_add_enemy_unit(PoCUnit.UnitType.BREAKER, c, 10)

func _setup_breaker_vs_attacker() -> void:
	# プレイヤー row2（偶数）: 崩6
	for c in range(6):
		_add_player_unit(PoCUnit.UnitType.BREAKER, c, 2)
	# 敵 row10（偶数）: 突6
	for c in range(6):
		_add_enemy_unit(PoCUnit.UnitType.ATTACKER, c, 10)

func _setup_focus_vs_spread() -> void:
	# プレイヤー: 突6 集中（col1,2,3 row0 + col1,2,3 row2）
	for c in [1, 2, 3]:
		_add_player_unit(PoCUnit.UnitType.ATTACKER, c, 0)
	for c in [1, 2, 3]:
		_add_player_unit(PoCUnit.UnitType.ATTACKER, c, 2)
	# 敵: 突2守2崩2 均等（row10）
	_add_enemy_unit(PoCUnit.UnitType.ATTACKER, 1, 10)
	_add_enemy_unit(PoCUnit.UnitType.ATTACKER, 4, 10)
	_add_enemy_unit(PoCUnit.UnitType.TANK, 2, 10)
	_add_enemy_unit(PoCUnit.UnitType.TANK, 3, 10)
	_add_enemy_unit(PoCUnit.UnitType.BREAKER, 0, 10)
	_add_enemy_unit(PoCUnit.UnitType.BREAKER, 5, 10)

func _connect_unit_signals(unit: PoCUnit) -> void:
	unit.attack_dealt.connect(func(at, dt, dmg, mult): attack_logged.emit(at, dt, dmg, mult))
	unit.unit_killed.connect(func(ut, s, pos): kill_logged.emit(ut, s, pos))

func _add_player_unit(type: int, col: int, row: int) -> void:
	var unit := PoCUnit.create(type, PoCUnit.Side.PLAYER, col, row)
	unit.position = hex_grid.hex_to_pixel(col, row)
	_connect_unit_signals(unit)
	player_units.append(unit)

func _add_enemy_unit(type: int, col: int, row: int) -> void:
	var unit := PoCUnit.create(type, PoCUnit.Side.ENEMY, col, row)
	unit.position = hex_grid.hex_to_pixel(col, row)
	_connect_unit_signals(unit)
	enemy_units.append(unit)

func start_battle() -> void:
	if phase != Phase.SETUP:
		return
	phase = Phase.BATTLE
	print("[PoCBattle] battle started")

func update(delta: float) -> void:
	if phase != Phase.BATTLE:
		return
	var all_units: Array = player_units + enemy_units
	for u in player_units:
		if u.is_alive:
			u.update(delta, enemy_units, hex_grid, all_units)
	for u in enemy_units:
		if u.is_alive:
			u.update(delta, player_units, hex_grid, all_units)
	_remove_dead_units()
	check_victory()

func _remove_dead_units() -> void:
	for u in player_units:
		if not u.is_alive and not u.is_queued_for_deletion():
			unit_died.emit(u)
	for u in enemy_units:
		if not u.is_alive and not u.is_queued_for_deletion():
			unit_died.emit(u)
	player_units = player_units.filter(func(u): return u.is_alive)
	enemy_units = enemy_units.filter(func(u): return u.is_alive)

func check_victory() -> void:
	if phase != Phase.BATTLE:
		return
	if enemy_units.size() == 0:
		phase = Phase.END
		battle_ended.emit(true)
		print("[PoCBattle] PLAYER WIN: all enemies defeated")
		return
	if player_units.size() == 0:
		phase = Phase.END
		battle_ended.emit(false)
		print("[PoCBattle] PLAYER LOSE: all player units defeated")
		return
	for u in player_units:
		if u.grid_pos.y >= 11:
			phase = Phase.END
			battle_ended.emit(true)
			print("[PoCBattle] PLAYER WIN: reached enemy base")
			return
	for u in enemy_units:
		if u.grid_pos.y <= 0:
			phase = Phase.END
			battle_ended.emit(false)
			print("[PoCBattle] PLAYER LOSE: enemy reached player base")
			return

func get_player_units() -> Array:
	return player_units

func get_enemy_units() -> Array:
	return enemy_units
