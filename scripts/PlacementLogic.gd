# PlacementLogic.gd
# 配置ロジック：制約導出・デフォルト生成・配置先解決
# 3×3盤面ベース（side 0=自陣, side 1=敵陣）
extends RefCounted

# ---- 制約導出 ----

# このカードは自陣に配置できるか？
static func can_place_ally(card_entry: Dictionary) -> bool:
	var card_name: String = card_entry.get("name", "")
	# ユニットは自陣のみ
	if CardDB.UNITS.has(card_name):
		return true
	# 味方対象/全体呪文
	if CardDB.SPELLS.has(card_name):
		var d = CardDB.SPELLS[card_name]
		var target = d.get("target", "")
		return target != "enemy" and target != "all_enemies"
	if CardDB.STATUS_SPELLS.has(card_name):
		return true
	return true

# このカードは敵陣に配置できるか？
static func can_place_enemy(card_entry: Dictionary) -> bool:
	var card_name: String = card_entry.get("name", "")
	# ユニットは将来の敵陣配置スキル以外は不可
	if CardDB.UNITS.has(card_name):
		# 将来: 敵陣配置スキル持ちユニットはtrueを返す
		return false
	# 敵対象呪文
	if CardDB.SPELLS.has(card_name):
		var d = CardDB.SPELLS[card_name]
		var target = d.get("target", "")
		if target in ["enemy", "all_enemies", "enemy_random_col", "enemy_front_one"]:
			return true
		# 全体効果はどちらにも置ける
		if target in ["all_front", ""]:
			return true
	return false

# このカードの効果範囲タイプを返す（セル色分け用）
# "cell" = 単セル, "row" = 行全体, "col" = 列全体, "all" = 全体, "normal" = 通常配置
static func get_effect_scope(card_entry: Dictionary) -> String:
	var card_name: String = card_entry.get("name", "")
	if CardDB.UNITS.has(card_name):
		return "normal"
	# 呪文のskillsからtargetを判定
	var skills: Array = []
	if CardDB.SPELLS.has(card_name):
		skills = CardDB.SPELLS[card_name].get("skills", [])
	elif CardDB.STATUS_SPELLS.has(card_name):
		skills = CardDB.STATUS_SPELLS[card_name].get("skills", [])
	for skill in skills:
		var target = skill.get("target", "")
		if target in ["all_allies", "all_enemies", "all_front"]:
			return "all"
		if target in ["same_row", "same_row_beast"]:
			return "row"
		if target in ["same_col", "same_col_ally", "enemy_random_col"]:
			return "col"
	return "cell"

# ---- 効果範囲ハイライト計算 ----

# カードの効果範囲マスを返す [{side, row, col, color}]
# placed_side/row/col: そのカードの配置先
static func get_highlight_cells(card_entry: Dictionary, placed_side: int, placed_row: int, placed_col: int) -> Array:
	var card_name: String = card_entry.get("name", "")
	var result: Array = []

	# スキル一覧を取得
	var skills: Array = []
	if CardDB.UNITS.has(card_name):
		skills = CardDB.UNITS[card_name].get("skills", [])
	elif CardDB.SPELLS.has(card_name):
		skills = CardDB.SPELLS[card_name].get("skills", [])
	elif CardDB.STATUS_SPELLS.has(card_name):
		skills = CardDB.STATUS_SPELLS[card_name].get("skills", [])

	if skills.size() == 0:
		# スキルなし→ハイライトなし
		return result

	for skill in skills:
		var target = skill.get("target", "")
		var trigger = skill.get("trigger", "")

		# サポート効果（always / timer+target≠self）のみハイライト
		# 攻撃時効果（on_hit/on_kill）→ ハイライトしない（命中相手or自分に発動）
		# パッシブ（on_summon/on_death等）→ ハイライトしない（自身に影響）
		if trigger in ["on_hit", "on_kill", "on_summon", "on_death", "on_hp_threshold"]:
			continue
		if trigger == "timer" and target == "self":
			continue
		if trigger != "always" and trigger != "timer":
			continue

		# サポート効果のみ到達：デフォルト緑、敵対象は赤
		var color: String = "green"
		if target in ["all_enemies", "enemy_random_col", "enemy_front_one", "random_front_enemy", "front_enemy"]:
			color = "red"

		match target:
			"self":
				continue  # 自己対象→ハイライトしない
			"front_one":
				var fc = placed_col + 1 if placed_side == 0 else placed_col - 1
				if fc >= 0 and fc <= 2:
					result.append({"side": placed_side, "row": placed_row, "col": fc, "color": color})
			"adjacent":
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						if abs(dr) + abs(dc) == 1:
							var nr = placed_row + dr
							var nc = placed_col + dc
							if nr >= 0 and nr <= 2 and nc >= 0 and nc <= 2:
								result.append({"side": placed_side, "row": nr, "col": nc, "color": color})
			"same_row", "same_row_beast":
				for c in range(3):
					result.append({"side": placed_side, "row": placed_row, "col": c, "color": color})
			"same_col", "same_col_ally":
				for r in range(3):
					result.append({"side": placed_side, "row": r, "col": placed_col, "color": color})
			"all_allies":
				for r in range(3):
					for c in range(3):
						result.append({"side": placed_side, "row": r, "col": c, "color": color})
			"all_enemies":
				var enemy = 1 - placed_side
				for r in range(3):
					for c in range(3):
						result.append({"side": enemy, "row": r, "col": c, "color": "red"})
			"all_front":
				for r in range(3):
					result.append({"side": 0, "row": r, "col": 2, "color": color})
					result.append({"side": 1, "row": r, "col": 0, "color": "red"})
			"enemy_random_col":
				var enemy = 1 - placed_side
				for r in range(3):
					result.append({"side": enemy, "row": r, "col": placed_col, "color": "red"})
			"random_ally", "single_ally", "random_front_ally", "ally_max_atk":
				# 味方のどこか→全体を薄くハイライト
				for r in range(3):
					for c in range(3):
						result.append({"side": placed_side, "row": r, "col": c, "color": color})
			"front_ally_all":
				var fc = 2 if placed_side == 0 else 0
				for r in range(3):
					result.append({"side": placed_side, "row": r, "col": fc, "color": color})
			"enemy_front_one", "random_front_enemy":
				var enemy = 1 - placed_side
				var efc = 0 if placed_side == 0 else 2
				result.append({"side": enemy, "row": placed_row, "col": efc, "color": "red"})

	return result

# ---- デフォルト配置config生成 ----

# 新データ構造: {side, row, col, fallback_same_col}
static func generate_default_config(deck: Array) -> Array:
	var config: Array = []
	var name_row_counter: Dictionary = {}  # カード名→次の行番号（0,1,2をラウンドロビン）
	for entry in deck:
		var card_name: String = entry.get("name", "") if entry is Dictionary else str(entry)

		if CardDB.UNITS.has(card_name):
			var assigned_col: int = entry.get("col", 1) if entry is Dictionary else 1
			var col: int = clampi(assigned_col, 0, 2)
			# 同名カードは行をばらけさせる（上段→中段→下段→上段...）
			var row_idx: int = name_row_counter.get(card_name, 0)
			name_row_counter[card_name] = (row_idx + 1) % 3
			config.append({
				"side": 0,
				"row": row_idx,
				"col": col,
				"fallback_same_col": true,
			})
		elif CardDB.SPELLS.has(card_name):
			var d = CardDB.SPELLS[card_name]
			var target = d.get("target", "")
			var side = 1 if target in ["enemy", "all_enemies", "enemy_random_col", "enemy_front_one"] else 0
			config.append({
				"side": side,
				"row": -1,
				"col": -1,   # -1 = 列おまかせ
				"fallback_same_col": true,
			})
		else:
			# STATUS_SPELLS, SYSTEM_SPELLS等
			config.append({
				"side": 0,
				"row": -1,
				"col": -1,
				"fallback_same_col": true,
			})
	return config

# ---- 配置先解決（バトル時に使用） ----

static func resolve_placement(config_entry: Dictionary, board: Array, enemy_board: Array) -> Array:
	var side: int = config_entry.get("side", 0)
	var pref_row: int = config_entry.get("row", -1)
	var pref_col: int = config_entry.get("col", -1)
	var fallback: bool = config_entry.get("fallback_same_col", true)

	# 列候補
	var col_candidates: Array
	if pref_col >= 0 and pref_col <= 2:
		if fallback:
			col_candidates = [pref_col]
			# 同列優先、他列フォールバック
			for c in range(3):
				if c != pref_col:
					col_candidates.append(c)
		else:
			col_candidates = [pref_col]
	else:
		col_candidates = [0, 1, 2]
		col_candidates.shuffle()

	# 行候補
	var row_candidates: Array
	if pref_row >= 0 and pref_row <= 2:
		row_candidates = [pref_row]
		if fallback:
			for r in range(3):
				if r != pref_row:
					row_candidates.append(r)
	elif pref_row == -1:
		# 空きマス優先: 敵前列にユニットがいる行を優先
		var enemy_side = 1 - side
		var enemy_front_col: int = 0 if side == 0 else 2
		var priority_rows: Array = []
		var other_rows: Array = []
		for r in range(3):
			if board[enemy_side][r][enemy_front_col] != null:
				priority_rows.append(r)
			else:
				other_rows.append(r)
		priority_rows.shuffle()
		other_rows.shuffle()
		row_candidates = priority_rows + other_rows
	else:
		row_candidates = [0, 1, 2]
		row_candidates.shuffle()

	# 候補マスから空きを探す（同列の他行を優先）
	for c in col_candidates:
		for r in row_candidates:
			if board[side][r][c] == null:
				return [r, c]

	return [-1, -1]  # 配置不可

# ---- DeckPrep操作（データ層・UIなし） ----

# カード1枚を移動。成功=true, 制約違反=false
static func move_card(idx: int, new_side: int, new_row: int, new_col: int,
		deck: Array, config: Array) -> bool:
	if idx < 0 or idx >= deck.size() or idx >= config.size():
		return false
	var entry = deck[idx]
	if new_side == 0 and not can_place_ally(entry):
		return false
	if new_side == 1 and not can_place_enemy(entry):
		return false
	config[idx]["side"] = new_side
	config[idx]["row"] = new_row
	config[idx]["col"] = new_col
	return true

# カードグループを一括移動。全て同じセルへ。1枚でも制約違反ならfalse（全て移動しない）
static func move_group(indices: Array, new_side: int, new_row: int, new_col: int,
		deck: Array, config: Array) -> bool:
	# 事前チェック
	for idx in indices:
		if idx < 0 or idx >= deck.size() or idx >= config.size():
			return false
		var entry = deck[idx]
		if new_side == 0 and not can_place_ally(entry):
			return false
		if new_side == 1 and not can_place_enemy(entry):
			return false
	# 全カード移動
	for idx in indices:
		config[idx]["side"] = new_side
		config[idx]["row"] = new_row
		config[idx]["col"] = new_col
	return true

# 同一セル内の同名カードのインデックス一覧を返す
static func get_same_name_group_in_cell(idx: int, deck: Array, config: Array) -> Array:
	if idx < 0 or idx >= deck.size() or idx >= config.size():
		return []
	var entry = deck[idx]
	var card_name = entry.get("name", "") if entry is Dictionary else str(entry)
	var src = config[idx]
	var ss = src.get("side", 0)
	var sr = src.get("row", 0)
	var sc = src.get("col", 0)
	if sr < 0: sr = 0
	if sc < 0: sc = 2

	var group: Array = []
	for i in range(deck.size()):
		if i >= config.size():
			break
		var e = deck[i]
		var n = e.get("name", "") if e is Dictionary else str(e)
		if n != card_name:
			continue
		var cfg = config[i]
		var cs = cfg.get("side", 0)
		var cr = cfg.get("row", 0)
		var cc = cfg.get("col", 0)
		if cr < 0: cr = 0
		if cc < 0: cc = 2
		if cs == ss and cr == sr and cc == sc:
			group.append(i)
	return group

# セル内の全カードのインデックス一覧を返す
static func get_cell_group(side: int, row: int, col: int, config: Array) -> Array:
	var group: Array = []
	for i in range(config.size()):
		var cfg = config[i]
		var cs = cfg.get("side", 0)
		var cr = cfg.get("row", 0)
		var cc = cfg.get("col", 0)
		if cr < 0: cr = 0
		if cc < 0: cc = 2
		if cs == side and cr == row and cc == col:
			group.append(i)
	return group

# 行内の全カードのインデックス一覧を返す（陣営指定）
static func get_row_group(side: int, row: int, config: Array) -> Array:
	var group: Array = []
	for i in range(config.size()):
		var cfg = config[i]
		var cs = cfg.get("side", 0)
		var cr = cfg.get("row", 0)
		if cr < 0: cr = 0
		if cs == side and cr == row:
			group.append(i)
	return group

# 列内の全カードのインデックス一覧を返す（陣営指定）
static func get_col_group(side: int, col: int, config: Array) -> Array:
	var group: Array = []
	for i in range(config.size()):
		var cfg = config[i]
		var cs = cfg.get("side", 0)
		var cc = cfg.get("col", 0)
		if cc < 0: cc = 2
		if cs == side and cc == col:
			group.append(i)
	return group
