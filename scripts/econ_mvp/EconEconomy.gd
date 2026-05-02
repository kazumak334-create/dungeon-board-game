class_name EconEconomy
extends Node

const ROLE_BUILD := 10
const ROLE_TRADE := 11

# v0.2 定数（§13.6 パラメータ化）
const BASE_POPULATION_CAP: int = 50  # 拠点効果（§7.4）
const HOUSE_POP_CAP_LV1: int = 10  # §2.7.1: 住居Lv1の人口上限供給量
const BARRACKS_POWER_PER_SEC: float = 0.2  # 仮値（§4.7.2）
const INITIAL_FOOD: int = 30              # §7.3
const INITIAL_CURRENCY: int = 100        # §7.3

var wood: int = 0
var stone: int = 0
var sulfur: int = 0
var wheat: int = 10
var iron: int = 0
var cotton: int = 0

# v0.2 追加フィールド（§7.3）
var resources: Dictionary = {"wood": 5, "stone": 5, "sulfur": 5, "food": 30, "iron": 5, "cotton": 5}  # food初期値§2.4.1
var food: int = INITIAL_FOOD
var satisfaction: int = 60    # §2.4.3: 幸福度初期値60
var military_power: float = 0.0  # 兵力（§4.7.2）

# 要件定義書 req_econ_draw_hand_circulation.md §7.4
var currency: int = INITIAL_CURRENCY
var population_used: int = 0
var population_cap: int = BASE_POPULATION_CAP  # 拠点効果+50

# §2.4.2 人口配分比率：0.0 ~ 1.0 (スナップ: 0.25 / 0.50 / 0.75)
# alloc_work_ratio = 0.25 → 稼働75%, 作業25%（初期値）
var alloc_work_ratio: float = 0.25

# ハーベスター割り当て人数（直接人数指定）
var target_count: Dictionary = {
	EconGrid.ResourceType.WOOD: 1,
	EconGrid.ResourceType.STONE: 1,
	EconGrid.ResourceType.SULFUR: 1,
	EconGrid.ResourceType.WHEAT: 0,
	EconGrid.ResourceType.IRON: 0,
	EconGrid.ResourceType.COTTON: 0,
	EconEconomy.ROLE_BUILD: 0,
	EconEconomy.ROLE_TRADE: 0,
}

const WHEAT_CONSUME_INTERVAL := 5.0
const WHEAT_PER_UNIT := 0.5

var _wheat_timer: float = 0.0

# §6.2 5秒ティック処理（REQUIREMENTS_V0_2_MVP.md §6.2）
# 呼び出し元：EconBattle.update() → economy.update(delta, total_units)
# 5秒ごとにEconBattle側でtickを発火する想定。本メソッドは毎フレーム呼ばれるが
# 内部タイマーで5秒ごとに処理する（既存の_wheat_timerと同構造）
var _tick_timer: float = 0.0
const TICK_INTERVAL: float = 5.0
var _tick_index: int = 0

# 外部から建物リストを受け取るためのフィールド（EconBattleがセットする）
var buildings: Array = []

func update(delta: float, _total_unit_count: int) -> void:
	_tick_timer += delta
	if _tick_timer < TICK_INTERVAL:
		return
	_tick_timer -= TICK_INTERVAL
	_tick_index += 1
	print("[EconEconomy] tick: ", _tick_index, " pop=", population_used, " food=", food, " sat=", satisfaction, " mil=", military_power)

	# ---- Step 1: 資源生産（アクティブ建物の生産）§6.2-1 ----
	var prod_mod: float = get_happiness_production_modifier()
	for b in buildings:
		if not b.is_alive or not b.is_built:
			continue
		var lv: int = b.fusion_rank  # fusion_rank が Lv1/2/3 に対応
		var lv_bonus: float = 1.0 + (lv - 1) * 0.25  # Lv1=1.0, Lv2=1.25, Lv3=1.5
		match b.building_type:
			EconBuilding.BuildingType.SAWMILL:
				var gain: int = roundi(2.0 * lv_bonus * prod_mod)
				wood += gain
				resources["wood"] = wood
				print("[EconEconomy] SAWMILL Lv%d 木材+%d" % [lv, gain])
			EconBuilding.BuildingType.MINE:
				var gain: int = roundi(2.0 * lv_bonus * prod_mod)
				stone += gain
				resources["stone"] = stone
				print("[EconEconomy] MINE Lv%d 石材+%d" % [lv, gain])
			EconBuilding.BuildingType.WORKSHOP:
				var gain: int = roundi(1.0 * lv_bonus * prod_mod)
				sulfur += gain
				resources["sulfur"] = sulfur
				print("[EconEconomy] WORKSHOP Lv%d 硫黄+%d" % [lv, gain])
			EconBuilding.BuildingType.VILLAGE:
				# VILLAGEの食料生産はEconBuilding._update_village()側で処理済み
				# ここでは二重計上しない
				pass

	# ---- Step 2: 兵舎生成（§6.2-2 / §2.5.2）----
	var mil_mod: float = get_happiness_military_modifier()
	for b in buildings:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.BARRACKS:
			continue
		# 稼働人口=1のチェック（簡略: population_usedが1以上あれば稼働可とする）
		if population_used < 1:
			print("[EconEconomy] 兵舎: 稼働人口不足 pop_used=%d, 生成スキップ" % population_used)
			continue
		var lv: int = b.fusion_rank
		var base_gain: int = lv + 1  # Lv1=+2, Lv2=+3, Lv3=+4
		var actual_gain: float = float(base_gain) * mil_mod
		military_power += actual_gain
		print("[EconEconomy] BARRACKS Lv%d 兵力+%.1f (mil_mod=%.2f)" % [lv, actual_gain, mil_mod])

	# ---- Step 3: 食料消費（§6.2-3 / §6.1）----
	# 暫定方針：人口10人あたり5秒ごと食料-1
	var food_consume: int = population_used / 10
	if food_consume > 0:
		food -= food_consume
		resources["food"] = food
		wheat = food  # 後方互換
		print("[EconEconomy] 食料消費 -%d (food=%d)" % [food_consume, food])
		if food < 0:
			food = 0
			resources["food"] = 0
			wheat = 0
			# 食料不足時：幸福度-10ペナルティ（§2.4.3）
			satisfaction = maxi(satisfaction - 10, 0)
			print("[EconEconomy] 食料不足！幸福度-10 sat=%d" % satisfaction)

	# ---- Step 4: 幸福度更新（§6.2-4 / §2.4.3）----
	# 4-1: 広場(PLAZA)による幸福供給
	var plaza_supply: int = 0
	for b in buildings:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.PLAZA:
			continue
		var lv: int = b.fusion_rank  # Lv1=+1, Lv2=+2, Lv3=+3
		var base_supply: int = lv  # Lv1→1, Lv2→2, Lv3→3（§2.7.1）
		# 隣接住居ボーナス：隣接HOUSEを数えて+1/件
		var adj_houses: int = _count_adjacent_houses(b, buildings)
		plaza_supply += base_supply + adj_houses
		print("[EconEconomy] PLAZA Lv%d 幸福供給+%d（隣接住居×%d）" % [lv, base_supply + adj_houses, adj_houses])

	# 4-2: 人口負荷：人口10人ごとに幸福度-1（§2.4.3）
	var pop_load: int = population_used / 10

	# 4-3: 幸福度更新
	satisfaction += plaza_supply - pop_load
	satisfaction = clampi(satisfaction, 0, 100)
	print("[EconEconomy] 幸福度更新 plaza_supply=+%d pop_load=-%d sat=%d state=%s" % [plaza_supply, pop_load, satisfaction, get_happiness_state()])

	# ---- Step 5: 防衛拠点回復（§6.2-5）----
	# WATCHTOWER は現在EconBuilding enumに存在しないためスキップ
	# TODO: WATCHTOWER実装時に防壁HP回復処理を追加

	# ---- Step 6: 人口配分再計算（§6.2-6 / §2.4.2）----
	# alloc_work_ratio = 作業人口の割合（0.25/0.50/0.75）
	population_used = get_working_population()
	print("[EconEconomy] 人口配分再計算 alloc_work_ratio=%.2f working=%d building=%d cap=%d" % [alloc_work_ratio, get_working_population(), get_building_population(), population_cap])

# §2.4.2 稼働人口 = population_cap × (1 - alloc_work_ratio)
func get_working_population() -> int:
	return int(population_cap * (1.0 - alloc_work_ratio))

# §2.4.2 作業人口 = population_cap × alloc_work_ratio
func get_building_population() -> int:
	return int(population_cap * alloc_work_ratio)

# §2.4.2 スナップ機構：最も近い 0.25 / 0.50 / 0.75 に丸める
func snap_alloc_ratio(target_ratio: float) -> float:
	var snap_values: Array = [0.25, 0.5, 0.75]
	var closest: float = snap_values[0]
	var min_diff: float = abs(target_ratio - closest)
	for snap_val in snap_values:
		var diff: float = abs(target_ratio - snap_val)
		if diff < min_diff:
			min_diff = diff
			closest = snap_val
	return closest

# §2.4.2 配分変更メソッド（変更CT: なし / いつでも変更可）
# 次の5秒tickで population_used に反映される
func set_alloc_work_ratio(ratio: float) -> void:
	alloc_work_ratio = snap_alloc_ratio(ratio)
	print("[EconEconomy] alloc_ratio: %.2f working: %d building: %d" % [alloc_work_ratio, get_working_population(), get_building_population()])

# 幸福度状態を返す（§2.4.3）
# 戻り値: "high" / "normal" / "dissatisfied" / "danger"
func get_happiness_state() -> String:
	if satisfaction >= 70:
		return "high"
	elif satisfaction >= 40:
		return "normal"
	elif satisfaction >= 20:
		return "dissatisfied"
	else:
		return "danger"

# 広場の隣接HOUSEをカウントする（§2.7.1 広場Lv別効果・隣接住居+1/件）
# 呼び出し元：update() Step 4
func _count_adjacent_houses(plaza: EconBuilding, all_buildings: Array) -> int:
	var count: int = 0
	for b in all_buildings:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.HOUSE:
			continue
		# ヘックスグリッド隣接（距離=1）チェック
		var pos_plaza: Vector2i = plaza.grid_pos
		var pos_house: Vector2i = b.grid_pos
		var dist: int = _hex_distance(pos_plaza, pos_house)
		if dist == 1:
			count += 1
	return count

# ヘックス距離計算（offset座標系）（EconGrid.hex_distanceと同等ロジック）
func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ax := a.x - (a.y - (a.y & 1)) / 2
	var az := a.y
	var ay := -ax - az
	var bx := b.x - (b.y - (b.y & 1)) / 2
	var bz := b.y
	var by_ := -bx - bz
	return maxi(maxi(absi(ax - bx), absi(ay - by_)), absi(az - bz))

# 幸福度による生産補正係数（§2.4.3）
# "high"/"normal": 1.0 / "dissatisfied": 0.9 / "danger": 0.75
func get_happiness_production_modifier() -> float:
	var state: String = get_happiness_state()
	match state:
		"dissatisfied":
			return 0.9
		"danger":
			return 0.75
		_:
			return 1.0

# 幸福度による兵力生成補正係数（§2.5.3）
# "high": 1.1 / "normal"/"dissatisfied": 1.0 / "danger": 0.8
func get_happiness_military_modifier() -> float:
	var state: String = get_happiness_state()
	match state:
		"high":
			return 1.1
		"danger":
			return 0.8
		_:
			return 1.0

func add_resource(rtype: int, amount: int = 1) -> void:
	match rtype:
		EconGrid.ResourceType.WOOD: wood += amount
		EconGrid.ResourceType.STONE: stone += amount
		EconGrid.ResourceType.SULFUR: sulfur += amount
		EconGrid.ResourceType.WHEAT: wheat += amount
		EconGrid.ResourceType.IRON: iron += amount
		EconGrid.ResourceType.COTTON: cotton += amount

func can_afford(costs: Dictionary) -> bool:
	if costs.get("wood", 0) > wood:
		return false
	if costs.get("stone", 0) > stone:
		return false
	if costs.get("sulfur", 0) > sulfur:
		return false
	if costs.get("wheat", 0) > wheat:
		return false
	return true

func spend(costs: Dictionary) -> void:
	wood -= costs.get("wood", 0)
	stone -= costs.get("stone", 0)
	sulfur -= costs.get("sulfur", 0)
	wheat -= costs.get("wheat", 0)

func add_wheat(amount: int) -> void:
	wheat += amount

# 採掘先の資源タイプを決定（target_count から割り当てリストを生成してラウンドロビン）
# ROLE_BUILD / ROLE_TRADE も含めたリストから返す
func get_harvest_target_for(idx: int, total: int) -> int:
	# target_count から割り当てリストを生成（資源 + 役割）
	var assignment: Array = []
	var all_keys: Array = [
		EconGrid.ResourceType.WOOD,
		EconGrid.ResourceType.STONE,
		EconGrid.ResourceType.SULFUR,
		EconGrid.ResourceType.WHEAT,
		EconGrid.ResourceType.IRON,
		EconGrid.ResourceType.COTTON,
		EconEconomy.ROLE_BUILD,
		EconEconomy.ROLE_TRADE,
	]
	for key in all_keys:
		var count: int = target_count.get(key, 0)
		for _i in range(count):
			assignment.append(key)
	# 全target_countが0の場合はWOODにフォールバック
	if assignment.is_empty():
		return EconGrid.ResourceType.WOOD
	# total を使った安全なインデックス
	var safe_total: int = total if total > 0 else 1
	return assignment[idx % min(assignment.size(), safe_total)]

func get_display_text() -> String:
	return "Wood:%d Stone:%d Sulfur:%d Wheat:%d Iron:%d Cotton:%d" % [wood, stone, sulfur, wheat, iron, cotton]

# v0.2 新規：カード配置時の資源消費（§8.3）
func consume_resources(card: Dictionary) -> void:
	var cost: Dictionary = card.get("cost", {})
	for resource_key in cost.keys():
		if resources.has(resource_key):
			resources[resource_key] -= cost[resource_key]
			# 後方互換：既存フィールドとresourcesを同期
			_sync_resource_field(resource_key)
	print("[EconEconomy] consume_resources: %s" % str(cost))

# v0.2 新規：資源充足チェック（§8.3）
func can_afford_card(card: Dictionary) -> bool:
	var cost: Dictionary = card.get("cost", {})
	for resource_key in cost.keys():
		if not resources.has(resource_key):
			return false
		if resources[resource_key] < cost[resource_key]:
			return false
	return true

# v0.2 新規：兵力蓄積（§4.7.2）
func accumulate_military_power(delta: float, active_barracks_count: int) -> void:
	military_power += BARRACKS_POWER_PER_SEC * float(active_barracks_count) * delta

# v0.2 新規：resources辞書とフィールドを同期する内部メソッド
func _sync_resource_field(resource_key: String) -> void:
	match resource_key:
		"wood": wood = resources.get("wood", 0)
		"stone": stone = resources.get("stone", 0)
		"sulfur": sulfur = resources.get("sulfur", 0)
		"food": food = resources.get("food", 0)
		"wheat": wheat = resources.get("wheat", 0)  # 後方互換（EconUnit.gd参照のため残存）
		"iron": iron = resources.get("iron", 0)
		"cotton": cotton = resources.get("cotton", 0)

# §2.7.1 住居(HOUSE)のLv別人口上限供給量（Lv1=+10, Lv2=+15, Lv3=+20）
# 建物リストを走査してBASEの50 + 各HOUSEのLv別効果を合算する
func calculate_population_cap() -> int:
	var cap: int = BASE_POPULATION_CAP
	for b in buildings:
		if not b.is_alive or not b.is_built:
			continue
		if b.building_type != EconBuilding.BuildingType.HOUSE:
			continue
		var lv_bonus: Array = [10, 15, 20]  # Lv1, Lv2, Lv3（§2.7.1）
		var rank: int = clampi(b.fusion_rank - 1, 0, 2)
		cap += lv_bonus[rank]
	print("[EconEconomy] calculate_population_cap: ", cap)
	return cap

# v0.2 新規：初期化（§9.1）
func initialize_v0_2() -> void:
	# HOUSE を含む初期建物を考慮して population_cap を再計算する（§2.7.1）
	population_cap = calculate_population_cap()
	population_used = 0
	satisfaction = 60  # §2.4.3
	military_power = 0.0
	currency = INITIAL_CURRENCY
	food = INITIAL_FOOD
	resources = {"wood": 5, "stone": 5, "sulfur": 5, "food": INITIAL_FOOD, "iron": 5, "cotton": 5}  # §2.4.1
	wood = 5
	stone = 5
	sulfur = 5
	wheat = INITIAL_FOOD  # 後方互換：EconUnit.gd が economy.wheat を参照するため food と同期
	food = INITIAL_FOOD
	iron = 5
	cotton = 5
	print("[EconEconomy] initialize_v0_2: resources=%s, currency=%d, food=%d, pop_cap=%d" % [str(resources), currency, food, population_cap])
