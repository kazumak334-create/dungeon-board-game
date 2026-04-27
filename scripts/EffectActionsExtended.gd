# EffectActionsExtended.gd
# 30個の新規effect_id実装（EffectActions.gdに追加する内容）

# 以下の関数をEffectActions.gdの末尾に追加してください

func do_damage_by_x(merged: Dictionary, ctx: Dictionary) -> void:
	# X値÷divisor分の追加ダメージ
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var target: Object = ctx.get("target", null)
	var divisor: int   = merged.get("divisor", 5)
	if source == null or target == null or eq == null:
		return
	var extra_dmg: int = source.x_stacks / divisor
	if extra_dmg > 0:
		var t_side: int = targets.get_unit_side(target, bm)
		var t_row: int = targets.get_unit_row(target, bm)
		var t_col: int = targets.get_unit_col(target, bm)
		eq.push(1, source, target, "damage", float(extra_dmg), {"enemy_side": t_side, "row": t_row, "col": t_col})

func do_curse_multiply(merged: Dictionary, ctx: Dictionary) -> void:
	# 命中した敵の呪いスタックを倍率増幅
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var target: Object = ctx.get("target", null)
	var damage: int    = ctx.get("damage", 0)
	var context: Dictionary = {
		"board_manager": bm, "side": side, "row": row, "col": col,
		"source": source, "target": target, "damage": damage
	}
	var tgt = targets.resolve(merged, context, false)
	var factor: float = merged.get("factor", 2.5)
	for t in tgt:
		if t.curse_stacks > 0:
			t.curse_stacks = int(float(t.curse_stacks) * factor)

func do_curse_multiply_all_cursed(merged: Dictionary, ctx: Dictionary) -> void:
	# 呪い持ち敵全体の呪いスタックを倍率増幅
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var factor: float  = merged.get("factor", 1.5)
	if bm == null:
		return
	var enemy_side: int = 1 - side
	for r in range(3):
		for c in range(3):
			var enemy = bm.board[enemy_side][r][c]
			if enemy != null and enemy.curse_stacks > 0:
				enemy.curse_stacks = int(float(enemy.curse_stacks) * factor)

func do_buff_steal_all(merged: Dictionary, ctx: Dictionary) -> void:
	# 全バフ奪取
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var target: Object = ctx.get("target", null)
	var damage: int    = ctx.get("damage", 0)
	var context: Dictionary = {
		"board_manager": bm, "side": side, "row": row, "col": col,
		"source": source, "target": target, "damage": damage
	}
	var tgt = targets.resolve(merged, context, false)
	if source == null:
		return
	for t in tgt:
		# 全バフを奪取
		source._stolen_armor += t._damage_reduction
		source.boots_stacks += t.boots_stacks
		source.sense_stacks += t.sense_stacks
		source.power_stacks += t.power_stacks
		source.spring_stacks += t.spring_stacks
		source._stolen_regen += t.regen_stacks
		# 対象のバフをクリア
		t._damage_reduction = 0
		t.boots_stacks = 0
		t.sense_stacks = 0
		t.power_stacks = 0
		t.spring_stacks = 0
		t.regen_stacks = 0

func do_burn_by_status_count(merged: Dictionary, ctx: Dictionary) -> void:
	# 異常状態の種類数×N火傷付与
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var stacks_per_status: int = merged.get("stacks_per_status", 5)
	if bm == null:
		return
	var enemy_side: int = 1 - side
	for r in range(3):
		for c in range(3):
			var enemy = bm.board[enemy_side][r][c]
			if enemy != null:
				var status_count: int = 0
				if enemy.poison_stacks > 0: status_count += 1
				if enemy.frozen_turns > 0: status_count += 1
				if enemy.burn_turns > 0: status_count += 1
				if enemy.curse_stacks > 0: status_count += 1
				if enemy.brand_stacks > 0: status_count += 1
				if status_count > 0:
					enemy.burn_turns += status_count * stacks_per_status

func do_freeze_by_status_count(merged: Dictionary, ctx: Dictionary) -> void:
	# 異常状態の種類数×N凍結付与
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var stacks_per_status: int = merged.get("stacks_per_status", 5)
	if bm == null:
		return
	var enemy_side: int = 1 - side
	for r in range(3):
		for c in range(3):
			var enemy = bm.board[enemy_side][r][c]
			if enemy != null:
				var status_count: int = 0
				if enemy.poison_stacks > 0: status_count += 1
				if enemy.frozen_turns > 0: status_count += 1
				if enemy.burn_turns > 0: status_count += 1
				if enemy.curse_stacks > 0: status_count += 1
				if enemy.brand_stacks > 0: status_count += 1
				if status_count > 0:
					enemy.frozen_turns += status_count * stacks_per_status

func do_mark_if_poison_gte(merged: Dictionary, ctx: Dictionary) -> void:
	# 毒閾値以上で烙印付与
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var target: Object = ctx.get("target", null)
	var damage: int    = ctx.get("damage", 0)
	var context: Dictionary = {
		"board_manager": bm, "side": side, "row": row, "col": col,
		"source": source, "target": target, "damage": damage
	}
	var tgt = targets.resolve(merged, context, false)
	var poison_threshold: int = merged.get("poison_threshold", 10)
	var mark_stacks: int = merged.get("mark_stacks", 2)
	for t in tgt:
		if t.poison_stacks >= poison_threshold:
			t.brand_stacks += mark_stacks

func do_poison_if_marked(merged: Dictionary, ctx: Dictionary) -> void:
	# 烙印持ちに毒付与
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var stacks: int    = merged.get("stacks", 5)
	if bm == null:
		return
	var enemy_side: int = 1 - side
	for r in range(3):
		for c in range(3):
			var enemy = bm.board[enemy_side][r][c]
			if enemy != null and enemy.brand_stacks > 0:
				enemy.poison_stacks += stacks

func do_curse_burst_on_death(merged: Dictionary, ctx: Dictionary) -> void:
	# 死亡時に呪いスタックを周辺敵に波及
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var threshold: int = merged.get("threshold", 20)
	if bm == null or source == null:
		return
	if source.curse_stacks >= threshold:
		var burst_curse: int = source.curse_stacks
		var enemy_side: int = 1 - side
		for r in range(3):
			for c in range(3):
				var enemy = bm.board[enemy_side][r][c]
				if enemy != null:
					enemy.curse_stacks += burst_curse

func do_poison_total_to_x(merged: Dictionary, ctx: Dictionary) -> void:
	# 盤面毒スタック総数をX値に加算（x_stack_add_from_fieldと同じ）
	do_x_stack_add_from_field(merged, ctx)

func do_sense_consume_damage(merged: Dictionary, ctx: Dictionary) -> void:
	# センス全消費→センス×ATK%追加ダメージ
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var target: Object = ctx.get("target", null)
	if source == null or target == null or eq == null:
		return
	if source.sense_stacks > 0:
		var extra_dmg: int = int(float(source.attack) * float(source.sense_stacks) * 0.01)
		if extra_dmg > 0:
			var t_side: int = targets.get_unit_side(target, bm)
			var t_row: int = targets.get_unit_row(target, bm)
			var t_col: int = targets.get_unit_col(target, bm)
			eq.push(1, source, target, "damage", float(extra_dmg), {"enemy_side": t_side, "row": t_row, "col": t_col})
		source.sense_stacks = 0

func do_thorn_damage(merged: Dictionary, ctx: Dictionary) -> void:
	# 棘スタック×ダメージ
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var target: Object = ctx.get("target", null)
	var multiplier: int = merged.get("multiplier", 1)
	if source == null or target == null or eq == null:
		return
	var thorn_dmg: int = source.thorn_stacks * multiplier
	if thorn_dmg > 0:
		var t_side: int = targets.get_unit_side(target, bm)
		var t_row: int = targets.get_unit_row(target, bm)
		var t_col: int = targets.get_unit_col(target, bm)
		eq.push(1, source, target, "damage", float(thorn_dmg), {"enemy_side": t_side, "row": t_row, "col": t_col})

func do_mana_generation_trigger(merged: Dictionary, ctx: Dictionary) -> void:
	# 召喚時にマナ生成1回分即時発動
	var dm: RefCounted = ctx.get("dm", null)
	var ai: RefCounted = ctx.get("ai", null)
	var side: int      = ctx.get("side", 0)
	var source: Object = ctx.get("source", null)
	if source == null:
		return
	var mana_gain: float = float(source.mana) if source.mana >= 0 else 0.0
	# springバフ適用
	if source.spring_stacks > 0:
		mana_gain += mana_gain * source.spring_stacks * 0.01
	if side == 0 and dm != null:
		dm.mana += mana_gain
	elif side == 1 and ai != null:
		ai.mana += mana_gain

func do_position_swap_front_back(merged: Dictionary, ctx: Dictionary) -> void:
	# 呪い閾値以上の敵前列1体を後列と入れ替え
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var min_curse: int = merged.get("min_curse", 20)
	if bm == null:
		return
	var enemy_side: int = 1 - side
	var front_col: int = 0 if enemy_side == 0 else 2
	var back_col: int = 2 if enemy_side == 0 else 0
	var candidates: Array = []
	for r in range(3):
		var front_unit = bm.board[enemy_side][r][front_col]
		if front_unit != null and front_unit.curse_stacks >= min_curse:
			candidates.append(r)
	if candidates.size() > 0:
		candidates.shuffle()
		var target_row: int = candidates[0]
		var front_unit = bm.board[enemy_side][target_row][front_col]
		var back_unit = bm.board[enemy_side][target_row][back_col]
		bm.board[enemy_side][target_row][front_col] = back_unit
		bm.board[enemy_side][target_row][back_col] = front_unit
		if front_unit != null:
			front_unit.assigned_col = back_col
		if back_unit != null:
			back_unit.assigned_col = front_col

func do_position_swap_random(merged: Dictionary, ctx: Dictionary) -> void:
	# 呪い閾値以上の敵2体をランダム入れ替え
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var min_curse: int = merged.get("min_curse", 10)
	var count: int     = merged.get("count", 2)
	if bm == null:
		return
	var enemy_side: int = 1 - side
	var candidates: Array = []
	for r in range(3):
		for c in range(3):
			var enemy = bm.board[enemy_side][r][c]
			if enemy != null and enemy.curse_stacks >= min_curse:
				candidates.append({"r": r, "c": c, "unit": enemy})
	if candidates.size() >= count:
		candidates.shuffle()
		var pos1 = candidates[0]
		var pos2 = candidates[1]
		bm.board[enemy_side][pos1["r"]][pos1["c"]] = pos2["unit"]
		bm.board[enemy_side][pos2["r"]][pos2["c"]] = pos1["unit"]
		pos1["unit"].assigned_col = pos2["c"]
		pos2["unit"].assigned_col = pos1["c"]

func do_swap_cursed_enemies(merged: Dictionary, ctx: Dictionary) -> void:
	# 呪い閾値以上の敵全体をランダムシャッフル（既存のdo_position_shuffleと同じ）
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var min_curse: int = merged.get("min_curse", 5)
	if bm == null:
		return
	var enemy_side: int = 1 - side
	var positions: Array = []
	for r in range(3):
		for c in range(3):
			var enemy = bm.board[enemy_side][r][c]
			if enemy != null and enemy.curse_stacks >= min_curse:
				positions.append({"r": r, "c": c, "unit": enemy})
	if positions.size() > 1:
		var units_only: Array = []
		for pos in positions:
			units_only.append(pos["unit"])
		units_only.shuffle()
		for i in range(positions.size()):
			var pos = positions[i]
			var new_unit = units_only[i]
			bm.board[enemy_side][pos["r"]][pos["c"]] = new_unit
			new_unit.assigned_col = pos["c"]

func do_spell_slot_seal(merged: Dictionary, ctx: Dictionary) -> void:
	# 呪文スロット封印（Phase 5実装予定・現状はスタブ）
	pass

func do_trait_resilient(merged: Dictionary, ctx: Dictionary) -> void:
	# 再生特性：死亡後5秒でHP10%復活（revive_on_deathと同じ）
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var hp_pct: float  = merged.get("hp_pct", 0.1)
	var delay: float   = merged.get("delay", 5.0)
	if source == null or eq == null:
		return
	var revive_hp: int = max(1, int(float(source.max_hp) * hp_pct))
	eq.push(5, source, null, "revive", float(revive_hp), {
		"side": side, "row": row, "col": col, "delay": delay
	})

func do_on_ally_death_thorn_boost(merged: Dictionary, ctx: Dictionary) -> void:
	# 味方死亡時に棘スタック増加
	var source: Object = ctx.get("source", null)
	var thorn_stacks: int = merged.get("thorn_stacks", 10)
	if source == null:
		return
	source.thorn_stacks += thorn_stacks

func do_heal_reduction_cursed(merged: Dictionary, ctx: Dictionary) -> void:
	# 呪い持ち敵の回復量減少（常時効果・実装は回復処理側で対応）
	pass

func do_crit_mult_boost(merged: Dictionary, ctx: Dictionary) -> void:
	# クリティカル倍率上昇（センス÷10・常時効果・実装はクリティカル判定側で対応）
	pass
