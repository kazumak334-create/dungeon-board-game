# EffectTargets.gd
# ターゲット解決モジュール（EffectExecutorから分離）
extends RefCounted

func resolve(merged: Dictionary, context: Dictionary, ally_side: bool) -> Array:
	var bm: Node    = context.get("board_manager", null)
	var side: int   = context.get("side", 0)
	var row: int    = context.get("row", 0)
	var col: int    = context.get("col", 0)
	var source: Object = context.get("source", null)
	var target: Object = context.get("target", null)
	var enemy_side: int = 1 - side
	var _tgt_side: int = side if ally_side else enemy_side  # 将来使用（範囲指定拡張）

	var tgt_str: String = merged.get("target", "")
	if tgt_str == "":
		# デフォルト：sourceまたはtarget
		if ally_side:
			return [source] if source != null else []
		else:
			return [target] if target != null else []

	if bm == null:
		return []

	match tgt_str:
		"target_unit":
			# 対象選択呪文: ctx["target"]で渡されたユニットをそのまま返す
			return [target] if target != null else []
		"self":
			return [source] if source != null else []
		"random_front_ally":
			var front: int = 2 if side == 0 else 0
			var cands: Array = []
			for r2 in range(3):
				var u = bm.board[side][r2][front]
				if u != null and u.is_alive():
					cands.append(u)
			if cands.is_empty():
				return []
			return [cands[randi() % cands.size()]]
		"same_col_ally":
			var result: Array = []
			for r2 in range(3):
				var u = bm.board[side][r2][col]
				if u != null and u.is_alive() and u != source:
					result.append(u)
			return result
		"same_row_beast":
			var result: Array = []
			for c2 in range(3):
				var u = bm.board[side][row][c2]
				if u != null and u.is_alive() and u.race == "獣":
					result.append(u)
			return result
		"adjacent_beast":
			var result: Array = []
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var r2: int = row + d[0]
				var c2: int = col + d[1]
				if r2 >= 0 and r2 < 3 and c2 >= 0 and c2 < 3:
					var u = bm.board[side][r2][c2]
					if u != null and u.is_alive() and u.race == "獣":
						result.append(u)
			return result
		"all_allies":
			var result: Array = []
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[side][r2][c2]
					if u != null and u.is_alive():
						result.append(u)
			return result
		"all_enemies":
			var result: Array = []
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[enemy_side][r2][c2]
					if u != null and u.is_alive():
						result.append(u)
			return result
		"single_ally":
			var u = pick_ally_by_strategy(side, bm, "max_hp")
			return [u] if u != null else []
		"random_ally":
			var cands: Array = []
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[side][r2][c2]
					if u != null and u.is_alive():
						cands.append(u)
			if cands.is_empty():
				return []
			return [cands[randi() % cands.size()]]
		"enemy_random_col":
			var ecol: int = randi() % 3
			var result: Array = []
			for r2 in range(3):
				var u = bm.board[enemy_side][r2][ecol]
				if u != null and u.is_alive():
					result.append(u)
			return result
		"ally_max_atk":
			var u = pick_ally_by_strategy(side, bm, "max_atk")
			return [u] if u != null else []
		"self_deck":
			return []  # デッキ操作はinject_status側で処理
		"enemy_deck":
			return []
		"enemy_front_one":
			var front: int = 0 if enemy_side == 1 else 2
			for r2 in range(3):
				var u = bm.board[enemy_side][r2][front]
				if u != null and u.is_alive():
					return [u]
			return []
		"front_one":
			# 自分の前のマス1体（side0: col+1方向、side1: col-1方向）
			var front_c: int = col + 1 if side == 0 else col - 1
			if front_c >= 0 and front_c < 3:
				var u = bm.board[side][row][front_c]
				if u != null and u.is_alive():
					return [u]
			return []
		"front_beast":
			# 前列の獣ユニット全体
			var front_col_fb: int = 2 if side == 0 else 0
			var result_fb: Array = []
			for r2 in range(3):
				var u = bm.board[side][r2][front_col_fb]
				if u != null and u.is_alive() and u.race == "獣":
					result_fb.append(u)
			return result_fb
		"adjacent_8":
			# 周囲8マス（上下左右＋斜め）の味方ユニット
			var result_a8: Array = []
			for dr in range(-1, 2):
				for dc in range(-1, 2):
					if dr == 0 and dc == 0:
						continue
					var r2: int = row + dr
					var c2: int = col + dc
					if r2 < 0 or r2 >= 3 or c2 < 0 or c2 >= 3:
						continue
					var u = bm.board[side][r2][c2]
					if u != null and u.is_alive():
						result_a8.append(u)
			return result_a8
		"front_ally_all":
			# 前列味方全員
			var front_fa: int = 2 if side == 0 else 0
			var result_fa: Array = []
			for r2 in range(3):
				var u = bm.board[side][r2][front_fa]
				if u != null and u.is_alive():
					result_fa.append(u)
			return result_fa
		"random_empty_ally":
			# 味方ランダム空きマス（召喚用）: ここではユニットリストは返さない（_resolve_target想定外）
			return []
		"ally_undead_lowest":
			# HP割合が最も低いアンデッド味方
			var best: Object = null
			var best_ratio: float = 1.0
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[side][r2][c2]
					if u != null and u.is_alive() and u.race == "アンデッド" and u != source:
						var ratio: float = float(u.current_hp) / float(u.max_hp)
						if ratio < best_ratio:
							best_ratio = ratio
							best = u
			return [best] if best != null else []
		"enemy_most_buffs":
			# バフが最も多い敵
			var best: Object = null
			var best_count: int = 0
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[enemy_side][r2][c2]
					if u != null and u.is_alive():
						var cnt: int = 0
						if u._atk_bonus > 0: cnt += 1
						if u._interval_bonus > 0.0: cnt += 1
						if u.regen_stacks > 0: cnt += 1
						if u._damage_reduction > 0: cnt += 1
						if cnt > best_count:
							best_count = cnt
							best = u
			return [best] if best != null else []
		"front_enemy":
			# 前列の敵全員
			var front_fe: int = 0 if enemy_side == 1 else 2
			var result_fe: Array = []
			for r2 in range(3):
				var u = bm.board[enemy_side][r2][front_fe]
				if u != null and u.is_alive():
					result_fe.append(u)
			return result_fe
		"random_front_enemy":
			# 前列の敵ランダム1体
			var front_rfe: int = 0 if enemy_side == 1 else 2
			var cands_rfe: Array = []
			for r2 in range(3):
				var u = bm.board[enemy_side][r2][front_rfe]
				if u != null and u.is_alive():
					cands_rfe.append(u)
			if cands_rfe.is_empty():
				return []
			return [cands_rfe[randi() % cands_rfe.size()]]
		"adjacent_enemy":
			# 隣接の敵ユニット（上下左右）
			var result_ae: Array = []
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var r2: int = row + d[0]
				var c2: int = col + d[1]
				if r2 >= 0 and r2 < 3 and c2 >= 0 and c2 < 3:
					var u = bm.board[enemy_side][r2][c2]
					if u != null and u.is_alive():
						result_ae.append(u)
			return result_ae
		"enemy_max_poison":
			# 毒スタック最多の敵1体
			var best: Object = null
			var best_stacks: int = 0
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[enemy_side][r2][c2]
					if u != null and u.is_alive():
						var stacks: int = u.poison_stacks if "poison_stacks" in u else 0
						if stacks > best_stacks:
							best_stacks = stacks
							best = u
			return [best] if best != null else []
		"enemy_front_random_poisoned":
			# 前列の毒持ち敵ランダム1体
			var front_efrp: int = 0 if enemy_side == 1 else 2
			var cands_efrp: Array = []
			for r2 in range(3):
				var u = bm.board[enemy_side][r2][front_efrp]
				if u != null and u.is_alive():
					var stacks: int = u.poison_stacks if "poison_stacks" in u else 0
					if stacks > 0:
						cands_efrp.append(u)
			if cands_efrp.is_empty():
				return []
			return [cands_efrp[randi() % cands_efrp.size()]]
		"hit_target":
			# 攻撃で命中した対象ユニット（on_front_attack コンテキストの target）
			return [target] if target != null else []
		"enemy_front_random":
			# 前列の敵ランダム1体（random_front_enemy の別名）
			var front_efr: int = 0 if enemy_side == 1 else 2
			var cands_efr: Array = []
			for r2 in range(3):
				var u = bm.board[enemy_side][r2][front_efr]
				if u != null and u.is_alive():
					cands_efr.append(u)
			if cands_efr.is_empty():
				return []
			return [cands_efr[randi() % cands_efr.size()]]
		"enemies_with_poison":
			# 毒スタックを持つ敵全員
			var result_ewp: Array = []
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[enemy_side][r2][c2]
					if u != null and u.is_alive() and u.poison_stacks > 0:
						result_ewp.append(u)
			return result_ewp
		"random_enemy":
			# 敵全体からランダム1体
			var cands_re: Array = []
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[enemy_side][r2][c2]
					if u != null and u.is_alive():
						cands_re.append(u)
			if cands_re.is_empty():
				return []
			return [cands_re[randi() % cands_re.size()]]
		"enemy_front_lowest_hp":
			# 前列の最低HP敝1体
			var front_eflo: int = 0 if enemy_side == 1 else 2
			var best_eflo: Object = null
			var best_hp_eflo: int = 999999
			for r2 in range(3):
				var u = bm.board[enemy_side][r2][front_eflo]
				if u != null and u.is_alive():
					if u.current_hp < best_hp_eflo:
						best_hp_eflo = u.current_hp
						best_eflo = u
			return [best_eflo] if best_eflo != null else []
		"same_row_allies":
			# sourceと同じ行の味方全員（source自身を除く）
			var result_sra: Array = []
			for c2 in range(3):
				var u = bm.board[side][row][c2]
				if u != null and u.is_alive() and u != source:
					result_sra.append(u)
			return result_sra
		"enemies_with_curse", "cursed_enemies":
			# curse_stacks > 0 の敝全員
			var result_ewc: Array = []
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[enemy_side][r2][c2]
					if u != null and u.is_alive():
						var cs: int = u.curse_stacks if "curse_stacks" in u else 0
						if cs > 0:
							result_ewc.append(u)
			return result_ewc
		"enemy_highest_curse":
			# curse_stacks最大の敝1体
			var best_ehc: Object = null
			var best_curse_ehc: int = 0
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[enemy_side][r2][c2]
					if u != null and u.is_alive():
						var cs: int = u.curse_stacks if "curse_stacks" in u else 0
						if cs > best_curse_ehc:
							best_curse_ehc = cs
							best_ehc = u
			return [best_ehc] if best_ehc != null else []
		"adjacent_enemies":
			# source位置の隣接マス（上下左右）の敝
			var result_aen: Array = []
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var r2: int = row + d[0]
				var c2: int = col + d[1]
				if r2 >= 0 and r2 < 3 and c2 >= 0 and c2 < 3:
					var u = bm.board[enemy_side][r2][c2]
					if u != null and u.is_alive():
						result_aen.append(u)
			return result_aen
		"attacker":
			# コンテキストのsourceを返す（被ダメージ時の攻撃者）
			return [source] if source != null else []
		"enemy_back":
			# 後列の敝全員
			var back_col_eb: int = 2 if enemy_side == 1 else 0
			var result_eb: Array = []
			for r2 in range(3):
				var u = bm.board[enemy_side][r2][back_col_eb]
				if u != null and u.is_alive():
					result_eb.append(u)
			return result_eb
		"all_units_random":
			# 全ユニット（味方+敝）からランダムmax_targets体
			var cands_aur: Array = []
			for s2 in range(2):
				for r2 in range(3):
					for c2 in range(3):
						var u = bm.board[s2][r2][c2]
						if u != null and u.is_alive():
							cands_aur.append(u)
			cands_aur.shuffle()
			var max_n: int = merged.get("max_targets", 5)
			return cands_aur.slice(0, min(max_n, cands_aur.size()))
	return []

func pick_ally_by_strategy(side: int, bm: Node, strategy: String) -> Object:
	if bm == null:
		return null
	var units: Array = []
	for r in range(3):
		for c in range(3):
			var u = bm.board[side][r][c]
			if u != null and u.is_alive():
				units.append(u)
	if units.is_empty():
		return null
	match strategy:
		"max_atk":
			units.sort_custom(func(a, b): return a.attack > b.attack)
			return units[0]
		"max_hp":
			units.sort_custom(func(a, b): return a.max_hp > b.max_hp)
			return units[0]
		"min_hp_ratio":
			units.sort_custom(func(a, b):
				return float(a.current_hp) / float(a.max_hp) < float(b.current_hp) / float(b.max_hp))
			return units[0]
		_:
			return units[randi() % units.size()]

func get_unit_row(unit: Object, bm: Node) -> int:
	if bm == null:
		return 0
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if bm.board[s][r][c] == unit:
					return r
	return 0

func get_unit_col(unit: Object, bm: Node) -> int:
	if bm == null:
		return 0
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if bm.board[s][r][c] == unit:
					return c
	return 0

func get_unit_side(unit: Object, bm: Node) -> int:
	if bm == null:
		return 0
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if bm.board[s][r][c] == unit:
					return s
	return 0

func get_adjacent_rows(row: int) -> Array:
	var rows: Array = []
	if row > 0: rows.append(row - 1)
	if row < 2: rows.append(row + 1)
	return rows
