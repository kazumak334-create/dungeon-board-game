class_name PoCUnit
extends Node2D

signal attack_dealt(attacker_type: int, defender_type: int, damage: float, multiplier: float)
signal unit_killed(unit_type: int, side: int, pos: Vector2i)

enum UnitType { ATTACKER, TANK, BREAKER }
enum Side { PLAYER, ENEMY }

var unit_type: UnitType
var side: Side
var grid_pos: Vector2i
var hp: float
var max_hp: float
var atk: float
var move_spd: float
var attack_interval: float
var attack_range: int
var target: PoCUnit
var attack_timer: float = 0.0
var move_timer: float = 0.0
var is_alive: bool = true

var _hex_grid: Node  # HexGrid reference (weak)
var _unit_color: Color

static func create(type: int, side: int, col: int, row: int) -> PoCUnit:
	var unit := PoCUnit.new()
	unit.unit_type = type
	unit.side = side
	unit.grid_pos = Vector2i(col, row)
	match type:
		UnitType.ATTACKER:
			unit.hp = 60.0
			unit.max_hp = 60.0
			unit.atk = 30.0
			unit.move_spd = 2.0
			unit.attack_interval = 1.0 / 1.5
			unit.attack_range = 1
			unit._unit_color = Color.RED
		UnitType.TANK:
			unit.hp = 200.0
			unit.max_hp = 200.0
			unit.atk = 10.0
			unit.move_spd = 0.5
			unit.attack_interval = 1.0 / 0.8
			unit.attack_range = 1
			unit._unit_color = Color.BLUE
		UnitType.BREAKER:
			unit.hp = 40.0
			unit.max_hp = 40.0
			unit.atk = 20.0
			unit.move_spd = 0.8
			unit.attack_interval = 1.0 / 0.6
			unit.attack_range = 2
			unit._unit_color = Color.GREEN
	return unit

static func get_counter_multiplier(attacker_type: UnitType, defender_type: UnitType) -> float:
	# 突→崩: x2.0, 守→突: x2.0, 崩→守: x2.0
	if attacker_type == UnitType.ATTACKER and defender_type == UnitType.BREAKER:
		return 2.0
	if attacker_type == UnitType.TANK and defender_type == UnitType.ATTACKER:
		return 2.0
	if attacker_type == UnitType.BREAKER and defender_type == UnitType.TANK:
		return 2.0
	return 1.0

func setup_hex_grid(hex_grid: Node) -> void:
	_hex_grid = hex_grid

func update(delta: float, enemies: Array, hex_grid: Node, all_units: Array) -> void:
	if not is_alive:
		return
	_hex_grid = hex_grid
	# ターゲット再選択（死亡または未設定）
	if target == null or not target.is_alive:
		select_target(enemies, hex_grid)
	if target == null:
		return
	var dist: int = hex_grid.hex_distance(grid_pos, target.grid_pos)
	if dist > attack_range:
		try_move(delta, hex_grid, all_units)
	else:
		try_attack(delta, enemies, hex_grid)

func select_target(enemies: Array, hex_grid: Node) -> void:
	target = null
	var best_time := INF
	for e in enemies:
		if not e.is_alive:
			continue
		var dist: float = hex_grid.hex_distance(grid_pos, e.grid_pos)
		var t := dist / move_spd
		if t < best_time:
			best_time = t
			target = e

func try_move(delta: float, hex_grid: Node, all_units: Array) -> void:
	move_timer += delta
	var move_interval: float = 1.0 / move_spd
	if move_timer < move_interval:
		return
	move_timer = 0.0
	if target == null:
		return
	# ブロックセル辞書を構築（自分以外の全ユニット）
	var blocked: Dictionary = {}
	for u in all_units:
		if u.is_alive and u != self:
			var cnt: int = blocked.get(u.grid_pos, 0)
			blocked[u.grid_pos] = cnt + 1
	var path: Array = hex_grid.bfs_path(grid_pos, target.grid_pos, blocked)
	if path.size() < 2:
		return
	var next_cell: Vector2i = path[1]
	grid_pos = next_cell
	position = hex_grid.hex_to_pixel(grid_pos.x, grid_pos.y)
	queue_redraw()
	print("[PoCUnit] moved to ", grid_pos)

func try_attack(delta: float, enemies: Array, hex_grid: Node) -> void:
	attack_timer += delta
	if attack_timer < attack_interval:
		return
	attack_timer = 0.0
	if target == null or not target.is_alive:
		return
	var multiplier := get_counter_multiplier(unit_type, target.unit_type)
	var damage := atk * multiplier
	if unit_type == UnitType.BREAKER:
		# 範囲攻撃：ターゲット半径1以内の全敵
		for e in enemies:
			if not e.is_alive:
				continue
			if hex_grid.hex_distance(target.grid_pos, e.grid_pos) <= 1:
				var splash_mult := get_counter_multiplier(unit_type, e.unit_type)
				var splash_dmg := atk * splash_mult
				e.take_damage(splash_dmg)
				attack_dealt.emit(int(unit_type), int(e.unit_type), splash_dmg, splash_mult)
				print("[PoCUnit] BREAKER splash damage ", splash_dmg, " to ", e.grid_pos)
	else:
		# ターゲットセルの全ユニットにダメージ
		var target_pos: Vector2i = target.grid_pos
		var count_hits: int = 0
		for e in enemies:
			if not e.is_alive:
				continue
			if e.grid_pos == target_pos:
				var mult: float = get_counter_multiplier(unit_type, e.unit_type)
				var dmg: float = atk * mult
				e.take_damage(dmg)
				attack_dealt.emit(int(unit_type), int(e.unit_type), dmg, mult)
				count_hits += 1
		print("[PoCUnit] attack to pos ", target_pos, " x", count_hits, " hits")

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		is_alive = false
		unit_killed.emit(int(unit_type), int(side), grid_pos)
		print("[PoCUnit] died at ", grid_pos)
	queue_redraw()

func _draw() -> void:
	var radius := 18.0
	draw_circle(Vector2.ZERO, radius, _unit_color)
	if side == Side.ENEMY:
		# 黒縁取り
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.BLACK, 2.0)
	# HPバー
	var bar_width := 36.0
	var bar_height := 5.0
	var bar_y := -25.0
	var hp_ratio: float = hp / max_hp if max_hp > 0 else 0.0
	# 背景
	draw_rect(Rect2(Vector2(-bar_width * 0.5, bar_y), Vector2(bar_width, bar_height)), Color.DARK_GRAY)
	# 前景
	draw_rect(Rect2(Vector2(-bar_width * 0.5, bar_y), Vector2(bar_width * hp_ratio, bar_height)), Color.GREEN)
