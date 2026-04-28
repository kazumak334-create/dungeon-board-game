class_name WaveConfig
extends RefCounted

# 各Waveの敵構成候補（バリエーション対応）
# wave_configs[wave_index][variant_index] = [{unit_type, count}, ...]
const WAVE_CONFIGS: Array = [
	# Wave 1: 弱め（合計5体）
	[
		[{"unit_type": 0, "count": 2}, {"unit_type": 1, "count": 2}, {"unit_type": 2, "count": 1}],
		[{"unit_type": 0, "count": 3}, {"unit_type": 1, "count": 1}, {"unit_type": 2, "count": 1}],
		[{"unit_type": 0, "count": 1}, {"unit_type": 1, "count": 2}, {"unit_type": 2, "count": 2}],
	],
	# Wave 2: 中（合計6体）
	[
		[{"unit_type": 0, "count": 2}, {"unit_type": 1, "count": 2}, {"unit_type": 2, "count": 2}],
		[{"unit_type": 0, "count": 3}, {"unit_type": 1, "count": 2}, {"unit_type": 2, "count": 1}],
		[{"unit_type": 0, "count": 2}, {"unit_type": 1, "count": 1}, {"unit_type": 2, "count": 3}],
	],
	# Wave 3: 強め（合計8体）
	[
		[{"unit_type": 0, "count": 3}, {"unit_type": 1, "count": 3}, {"unit_type": 2, "count": 2}],
		[{"unit_type": 0, "count": 4}, {"unit_type": 1, "count": 2}, {"unit_type": 2, "count": 2}],
		[{"unit_type": 0, "count": 2}, {"unit_type": 1, "count": 3}, {"unit_type": 2, "count": 3}],
	],
]

# Wave構成を取得（バリエーションランダム選択）
static func get_wave_composition(wave_index: int, rng: RandomNumberGenerator) -> Array:
	print("[WaveConfig] get_wave_composition wave_index=", wave_index)
	var variants: Array = WAVE_CONFIGS[wave_index]
	var vi: int = rng.randi_range(0, variants.size() - 1)
	print("[WaveConfig] selected variant=", vi)
	return variants[vi]

# 敵ゾーン（row 8-10）にランダム配置を生成
# composition: [{unit_type: int, count: int}, ...]
# hex_grid: HexGrid
# 戻り値: [{unit_type: int, col: int, row: int}, ...]
static func generate_enemy_placement(composition: Array, hex_grid: Node, rng: RandomNumberGenerator) -> Array:
	print("[WaveConfig] generate_enemy_placement composition=", composition)
	# 敵ゾーンの有効セルをすべて列挙
	var valid_cells: Array = []
	for row in range(8, 11):
		var col_count: int = hex_grid.get_col_count(row)
		for col in range(col_count):
			valid_cells.append(Vector2i(col, row))

	# セルごとのスタック数
	var cell_stack: Dictionary = {}

	# 配置結果
	var placements: Array = []

	for entry in composition:
		var unit_type: int = entry["unit_type"]
		var count: int = entry["count"]
		var placed: int = 0
		var attempts: int = 0
		while placed < count and attempts < 200:
			attempts += 1
			var idx: int = rng.randi_range(0, valid_cells.size() - 1)
			var cell: Vector2i = valid_cells[idx]
			var stack: int = cell_stack.get(cell, 0)
			if stack < 3:
				cell_stack[cell] = stack + 1
				placements.append({"unit_type": unit_type, "col": cell.x, "row": cell.y})
				placed += 1
		print("[WaveConfig] placed unit_type=", unit_type, " count=", placed)

	print("[WaveConfig] total placements=", placements.size())
	return placements
