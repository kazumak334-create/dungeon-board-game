class_name EconUnit
extends Node2D

enum UnitType { ATTACKER, TANK, BREAKER }
enum Side { PLAYER, ENEMY }
enum OrderType { ATTACK_UNITS, ATTACK_HARVESTERS, GUARD }

signal unit_killed(unit_type: int, side: int, pos: Vector2i)

var unit_type: UnitType
var side: Side
var grid_pos: Vector2i
var hp: float
var max_hp: float
var atk: float
var spd: float
var attack_range: int
var min_range: int
var move_spd: float
var target_node: Node = null
var attack_timer: float = 0.0
var move_timer: float = 0.0
const ATTACK_FLASH_DURATION := 0.25
var _attack_flash_timer: float = 0.0
var is_alive: bool = true
var order: OrderType = OrderType.ATTACK_UNITS
var guard_target: Node = null

# 空腹システム
var hunger: float = 10.0
var hunger_max: float = 10.0
const HUNGER_CONSUME_INTERVAL: float = 5.0
const HP_DECREASE_RATE: float = 2.0
var _hunger_timer: float = 0.0

var stack_count: int = 1
var is_selected: bool = false

var _unit_color: Color
var _grid_ref: EconGrid = null

# スムーズ移動アニメーション
const MOVE_ANIM_DURATION := 0.4
var _anim_from: Vector2 = Vector2.ZERO
var _anim_to: Vector2 = Vector2.ZERO
var _anim_t: float = 1.0

# 要件定義書の数値（SPD=攻撃速度1/秒）
static var UNIT_STATS: Dictionary = {
	"ATTACKER": {"hp": 80.0,  "atk": 20.0, "spd": 1.0, "move_spd": 0.15, "range": 1, "min_range": 0, "color": Color.RED},
	"TANK":     {"hp": 200.0, "atk": 25.0, "spd": 0.5, "move_spd": 0.10, "range": 1, "min_range": 0, "color": Color.CORNFLOWER_BLUE},
	"BREAKER":  {"hp": 70.0,  "atk": 35.0, "spd": 0.25, "move_spd": 0.12, "range": 3, "min_range": 2, "color": Color.LIME_GREEN},
}

static func create(utype: int, s: int, col: int, row: int) -> EconUnit:
	var unit := EconUnit.new()
	unit.unit_type = utype
	unit.side = s
	unit.grid_pos = Vector2i(col, row)
	var key: String = ["ATTACKER", "TANK", "BREAKER"][int(utype)]
	var stats: Dictionary = UNIT_STATS[key]
	unit.hp = stats["hp"]
	unit.max_hp = stats["hp"]
	unit.atk = stats["atk"]
	unit.spd = stats["spd"]
	unit.move_spd = stats["move_spd"]
	unit.attack_range = stats["range"]
	unit.min_range = stats["min_range"]
	unit._unit_color = stats["color"]
	return unit

func update(delta: float, enemies: Array, enemy_buildings: Array, enemy_harvesters: Array, grid: EconGrid, all_units: Array, economy: EconEconomy = null) -> void:
	if not is_alive:
		return
	_grid_ref = grid
	# 空腹システム
	if economy != null:
		_hunger_timer += delta
		if _hunger_timer >= HUNGER_CONSUME_INTERVAL:
			_hunger_timer = 0.0
			if economy.wheat >= 1:
				economy.spend({"wheat": 1})
				hunger = hunger_max
			else:
				hunger = maxf(0.0, hunger - 1.0)
		if hunger <= 0.0:
			hp -= HP_DECREASE_RATE * delta
			if hp <= 0.0:
				hp = 0.0
				is_alive = false
				unit_killed.emit(int(unit_type), int(side), grid_pos)
			queue_redraw()
	# スムーズ移動アニメーション
	if _anim_t < 1.0:
		_anim_t = minf(1.0, _anim_t + delta / MOVE_ANIM_DURATION)
		position = _anim_from.lerp(_anim_to, _anim_t)
		queue_redraw()
	if _attack_flash_timer > 0.0:
		_attack_flash_timer -= delta
		queue_redraw()
	if target_node == null or not _is_target_alive(target_node):
		_select_target(enemies, enemy_harvesters, enemy_buildings, grid)
	# GUARDモード: guard_targetへ移動（近くにいれば通常攻撃AI）
	if order == OrderType.GUARD and guard_target != null and _is_target_alive(guard_target):
		if guard_target.get("grid_pos") != null:
			var gdist: int = grid.hex_distance(grid_pos, guard_target.grid_pos)
			if gdist > 1:
				_try_move_toward(delta, grid, all_units, guard_target.grid_pos)
				return
			# 隣接時はデフォルト敵優先AIで攻撃
	if target_node == null:
		return
	if target_node.get("grid_pos") == null:
		target_node = null
		return
	var target_pos: Vector2i = target_node.grid_pos
	var dist: int = grid.hex_distance(grid_pos, target_pos)
	if dist < min_range:
		_try_flee(delta, grid, all_units)
	elif dist > attack_range:
		_try_move_toward(delta, grid, all_units, target_pos)
	else:
		_try_attack(delta)

func _is_target_alive(t: Node) -> bool:
	if t == null:
		return false
	if t.get("is_alive") == null:
		return false
	return t.is_alive

func _select_target(enemies: Array, harvesters: Array, buildings: Array, grid: EconGrid) -> void:
	# GUARDモード: guard_target が生きていればターゲットなし（移動のみ）
	if order == OrderType.GUARD:
		if guard_target != null and _is_target_alive(guard_target):
			target_node = null  # guard_targetへ移動は update()で別途処理
			return
		else:
			# guard_target消滅 → デフォルトに戻す
			order = OrderType.ATTACK_UNITS
			guard_target = null
	# ATTACK_HARVESTERS: ハーベスター優先
	if order == OrderType.ATTACK_HARVESTERS:
		target_node = null
		var best_dist := INF
		for h in harvesters:
			if not _is_target_alive(h) or h.get("grid_pos") == null:
				continue
			var d: float = grid.hex_distance(grid_pos, h.grid_pos)
			if d < best_dist:
				best_dist = d
				target_node = h
		if target_node != null:
			return
		# ハーベスターなければ通常ロジックにフォールスルー
	# ATTACK_UNITS (デフォルト) + フォールスルー
	target_node = null
	var best_node: Node = null
	var best_priority: int = 999
	var best_dist: float = INF
	for e in enemies:
		if not _is_target_alive(e) or e.get("grid_pos") == null:
			continue
		var d: float = grid.hex_distance(grid_pos, e.grid_pos)
		if 0 < best_priority or (0 == best_priority and d < best_dist):
			best_priority = 0
			best_dist = d
			best_node = e
	for h in harvesters:
		if not _is_target_alive(h) or h.get("grid_pos") == null:
			continue
		var d: float = grid.hex_distance(grid_pos, h.grid_pos)
		if 1 < best_priority or (1 == best_priority and d < best_dist):
			best_priority = 1
			best_dist = d
			best_node = h
	for b in buildings:
		if not _is_target_alive(b) or b.get("grid_pos") == null:
			continue
		var prio: int = 2
		if b.get("building_type") != null and b.building_type == EconBuilding.BuildingType.BASE:
			prio = 0  # BASEは最優先（敵ユニットと同等）
		var d: float = grid.hex_distance(grid_pos, b.grid_pos)
		if prio < best_priority or (prio == best_priority and d < best_dist):
			best_priority = prio
			best_dist = d
			best_node = b
	target_node = best_node

func _try_move_toward(delta: float, grid: EconGrid, all_units: Array, goal: Vector2i) -> void:
	move_timer += delta
	var move_interval: float = 1.0 / move_spd
	if move_timer < move_interval:
		return
	move_timer = 0.0
	var blocked: Dictionary = {}
	for u in all_units:
		if u.get("is_alive") == null or not u.is_alive:
			continue
		if u == self:
			continue
		if u.get("grid_pos") == null:
			continue
		if u.get("side") != null and u.side != side:
			blocked[u.grid_pos] = EconGrid.MAX_STACK
		else:
			var cnt: int = blocked.get(u.grid_pos, 0)
			blocked[u.grid_pos] = cnt + 1
	var path: Array = grid.bfs_path(grid_pos, goal, blocked)
	if path.size() >= 2:
		_anim_from = position
		grid_pos = path[1]
		_anim_to = grid.hex_to_pixel(grid_pos.x, grid_pos.y)
		_anim_t = 0.0

func _try_flee(delta: float, grid: EconGrid, all_units: Array) -> void:
	move_timer += delta
	var move_interval: float = 1.0 / move_spd
	if move_timer < move_interval:
		return
	move_timer = 0.0
	if target_node == null or target_node.get("grid_pos") == null:
		return
	var blocked: Dictionary = {}
	for u in all_units:
		if u.get("is_alive") == null or not u.is_alive:
			continue
		if u == self:
			continue
		if u.get("grid_pos") == null:
			continue
		if u.get("side") != null and u.side != side:
			blocked[u.grid_pos] = EconGrid.MAX_STACK
		else:
			var cnt: int = blocked.get(u.grid_pos, 0)
			blocked[u.grid_pos] = cnt + 1
	var neighbors: Array = grid.get_neighbors(grid_pos.x, grid_pos.y)
	var best_cell := grid_pos
	var best_dist: int = grid.hex_distance(grid_pos, target_node.grid_pos)
	for nb in neighbors:
		if blocked.get(nb, 0) >= EconGrid.MAX_STACK:
			continue
		var d: int = grid.hex_distance(nb, target_node.grid_pos)
		if d > best_dist:
			best_dist = d
			best_cell = nb
	if best_cell != grid_pos:
		grid_pos = best_cell
		position = grid.hex_to_pixel(grid_pos.x, grid_pos.y)
		queue_redraw()

func _try_attack(delta: float) -> void:
	var attack_interval: float = 1.0 / spd
	attack_timer += delta
	if attack_timer < attack_interval:
		return
	attack_timer = 0.0
	if target_node == null or not _is_target_alive(target_node):
		return
	if target_node.has_method("take_damage"):
		target_node.take_damage(atk)
		_attack_flash_timer = ATTACK_FLASH_DURATION
		queue_redraw()

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		is_alive = false
		unit_killed.emit(int(unit_type), int(side), grid_pos)
	queue_redraw()

func _draw() -> void:
	if not is_alive:
		return
	# 選択時：射程リング
	if is_selected:
		const HEX_STEP := EconGrid.HEX_SIZE * 1.732
		if min_range > 0:
			draw_arc(Vector2.ZERO, min_range * HEX_STEP, 0, TAU, 48, Color(1.0, 0.4, 0.0, 0.55), 2.5)
		draw_arc(Vector2.ZERO, (attack_range + 0.4) * HEX_STEP, 0, TAU, 48, Color(0.3, 1.0, 0.3, 0.55), 2.5)
	draw_circle(Vector2.ZERO, 18.0, _unit_color)
	if side == Side.ENEMY:
		draw_arc(Vector2.ZERO, 18.0, 0, TAU, 32, Color.BLACK, 2.0)
	# 選択時：ユニット外周ハイライト
	if is_selected:
		draw_arc(Vector2.ZERO, 18.0, 0, TAU, 32, Color.YELLOW, 2.5)
	var bar_w := 36.0
	var bar_h := 5.0
	var bar_y := -26.0
	var hp_ratio := hp / max_hp if max_hp > 0 else 0.0
	draw_rect(Rect2(Vector2(-bar_w * 0.5, bar_y), Vector2(bar_w, bar_h)), Color.DARK_GRAY)
	draw_rect(Rect2(Vector2(-bar_w * 0.5, bar_y), Vector2(bar_w * hp_ratio, bar_h)), Color.GREEN)
	# 重なり表示
	if stack_count > 1:
		draw_string(ThemeDB.fallback_font, Vector2(-9, 9), "x%d" % stack_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# 空腹アイコン（ユニット上部）
	if hunger <= 0.0:
		draw_circle(Vector2(0, -38), 5.0, Color(1.0, 0.0, 0.0, 0.9))
	elif hunger <= 5.0:
		draw_circle(Vector2(0, -38), 5.0, Color(1.0, 1.0, 0.0, 0.9))
	# 攻撃射線（発火時フラッシュ・フェードアウト）
	if _attack_flash_timer > 0.0 and target_node != null and target_node.get("is_alive") != null and target_node.is_alive and target_node.get("position") != null:
		var fade: float = _attack_flash_timer / ATTACK_FLASH_DURATION
		var target_local: Vector2 = target_node.position - position
		draw_line(Vector2.ZERO, target_local, Color(1.0, 0.9, 0.1, 0.85 * fade), 2.0)
