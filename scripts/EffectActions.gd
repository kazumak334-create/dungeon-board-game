# EffectActions.gd
# 効果type実行モジュール（EffectExecutorから分離）
# ctx: {bm, dm, ai, eq, side, row, col, source, target, damage, enemy_side}
extends RefCounted

var targets: RefCounted = null  # EffectTargets（EffectExecutorから注入）
var _EffectDB = null            # EffectDB（EffectExecutorから注入）

func do_buff_apply(merged: Dictionary, ctx: Dictionary) -> void:
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
	var tgt = targets.resolve(merged, context, true)
	var stacks: int = merged.get("stacks", 1)
	var duration: float = merged.get("duration", 0.0)
	match merged.get("buff", ""):
		"penetrate":
			for t in tgt:
				t._has_penetrate = true
		"armor":
			for t in tgt:
				t._damage_reduction += stacks
		"regen":
			for t in tgt:
				t.regen_stacks += stacks
		"thorn":
			for t in tgt:
				t.thorn_stacks += stacks
		"boots":
			for t in tgt:
				t.boots_stacks += stacks
		"sense":
			for t in tgt:
				t.sense_stacks += stacks
		"power":
			for t in tgt:
				t.power_stacks += stacks
		"spring":
			for t in tgt:
				t.spring_stacks += stacks
		"atk":
			if duration > 0.0:
				for t in tgt:
					t._temp_atk_bonus = stacks
					t._temp_atk_timer = duration
			else:
				for t in tgt:
					t._atk_bonus += stacks
		"spd":
			if duration > 0.0:
				for t in tgt:
					t._temp_spd_bonus = t.get_attack_interval() * 0.3 * stacks
					t._temp_spd_timer = duration
			else:
				for t in tgt:
					t._interval_bonus += 0.3 * stacks

func do_buff_apply_chance(merged: Dictionary, ctx: Dictionary) -> void:
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
	var tgt = targets.resolve(merged, context, true)
	var chance: float = merged.get("chance", 0.5)
	var stacks: int = merged.get("stacks", 1)
	if randf() <= chance:
		match merged.get("buff", ""):
			"armor":
				for t in tgt:
					t._damage_reduction += stacks

func do_debuff_apply(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
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
	var stacks: int = merged.get("stacks", 1)
	var status_str: String = merged.get("status", "")
	var status_jp: String = _status_to_jp(status_str)
	for t in tgt:
		var t_row: int = targets.get_unit_row(t, bm)
		var t_col: int = targets.get_unit_col(t, bm)
		var t_side: int = targets.get_unit_side(t, bm)
		if eq != null:
			eq.push(4, source, t, "status_apply", 0.0,
				{"status": status_jp, "stacks": stacks, "side": t_side,
				 "row": t_row, "col": t_col,
				 "src_side": side, "src_row": row, "src_col": col, "skill_name": status_str + "_apply"})

func do_damage(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node        = ctx.get("bm", null)
	var eq: Node        = ctx.get("eq", null)
	var side: int       = ctx.get("side", 0)
	var row: int        = ctx.get("row", 0)
	var source: Object  = ctx.get("source", null)
	var damage: int     = ctx.get("damage", 0)
	var enemy_side: int = ctx.get("enemy_side", 1 - side)
	var factor: float = merged.get("factor", 1.0)
	var tgt_type: String = merged.get("target", "")
	if tgt_type == "enemy_max_hp" and source != null:
		var best: Object = null
		var best_info: Dictionary = {}
		for r2 in range(3):
			for c2 in range(3):
				var u = bm.board[enemy_side][r2][c2]
				if u != null and u.is_alive():
					if best == null or u.current_hp > best.current_hp:
						best = u
						best_info = {"enemy_side": enemy_side, "row": r2, "col": c2}
		if best != null and eq != null:
			var dmg: int = int(source.attack * factor)
			eq.push(1, source, best, "damage", float(dmg), best_info)
	elif tgt_type == "adjacent_rows":
		var t_row: int = ctx.get("target_row", row)
		var chain_dmg: int = max(1, int(float(damage) / 2.0))
		for adj_row in targets.get_adjacent_rows(t_row):
			var adj_col: int = bm._get_frontmost_col(enemy_side, adj_row)
			if adj_col != -1 and eq != null:
				var adj_t = bm.board[enemy_side][adj_row][adj_col]
				eq.push(4, source, adj_t, "damage", float(chain_dmg),
					{"enemy_side": enemy_side, "row": adj_row, "col": adj_col})

func do_self_damage(merged: Dictionary, ctx: Dictionary) -> void:
	var source: Object = ctx.get("source", null)
	if source != null:
		var factor: float = merged.get("factor", 0.30)
		var min_hp: int   = merged.get("min_hp", 1)
		var hp_cost: int  = max(min_hp, int(source.max_hp * factor))
		source.current_hp = max(min_hp, source.current_hp - hp_cost)

func do_heal(merged: Dictionary, ctx: Dictionary) -> void:
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
	var factor: float = merged.get("factor", 0.15)
	var tgt = targets.resolve(merged, context, true)
	for t in tgt:
		var heal: int = max(1, int(t.max_hp * factor))
		t.current_hp = min(t.max_hp, t.current_hp + heal)

func do_atk_permanent(merged: Dictionary, ctx: Dictionary) -> void:
	var source: Object = ctx.get("source", null)
	if source != null:
		var amount: int = merged.get("amount", 2)
		var cap: int    = merged.get("cap", 10)
		if source._kill_atk_bonus < cap:
			var prev: int = source._kill_atk_bonus
			source._kill_atk_bonus = min(source._kill_atk_bonus + amount, cap)
			source.attack += source._kill_atk_bonus - prev

func do_summon(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node   = ctx.get("bm", null)
	var side: int  = ctx.get("side", 0)
	var row: int   = ctx.get("row", 0)
	var col: int   = ctx.get("col", 0)
	var _unit_id: String = merged.get("unit_id", "スライム")
	var range_type: String = merged.get("range", "same_row")
	var _chain: bool = merged.get("chain", false)
	if range_type == "same_row" and bm != null:
		var UnitDataScript = load("res://scripts/UnitData.gd")
		for c2 in range(3):
			if c2 == col:
				continue
			if bm.board[side][row][c2] == null:
				var slime = UnitDataScript.new()
				slime.unit_name = "スライム"
				slime.max_hp = 15
				slime.current_hp = 15
				slime.attack = 1
				slime.spd = UnitDataScript.SPD_SCALE / 4.0  # 攻撃間隔4.0秒 → SPD 2.5
				slime.mana = 1
				slime.assigned_col = 2 - c2 if side == 0 else c2
				slime.race = "スライム"
				slime.attack_range = "1行"
				slime.skills = []
				bm.board[side][row][c2] = slime
				bm.attack_timers[side][row][c2] = slime.get_attack_interval()
				bm.unit_placed.emit(side, row, c2, slime)
				bm.on_board_changed()
				bm._init_skill_timers(slime)
				break

func do_shuffle_deck(merged: Dictionary, ctx: Dictionary) -> void:
	var dm: Node  = ctx.get("dm", null)
	var ai: Node  = ctx.get("ai", null)
	var side: int = ctx.get("side", 0)
	var deck_mgr = dm if side == 0 else ai
	if deck_mgr != null:
		for card in deck_mgr.discard:
			deck_mgr.deck.append(card)
		deck_mgr.discard.clear()
		deck_mgr.deck.shuffle()
		print("[呪文回収] 山札をシャッフルしました")

func do_summon_low_cost(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node  = ctx.get("bm", null)
	var dm: Node  = ctx.get("dm", null)
	var ai: Node  = ctx.get("ai", null)
	var side: int = ctx.get("side", 0)
	if side == 0 and dm != null:
		dm.force_play_card(bm)
	elif side == 1 and ai != null:
		ai.force_play_card(bm)

func do_summon_on_death(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var source: Object = ctx.get("source", null)
	if source != null and bm != null:
		var base_name: String = ""
		for recipe in CardDB.SYNTHESIS:
			if recipe["result"] == source.unit_name:
				base_name = recipe["base"]
				break
		if base_name != "" and CardDB.UNITS.has(base_name):
			var ud = CardDB.UNITS[base_name]
			var UDS = load("res://scripts/UnitData.gd")
			var new_unit = UDS.new()
			new_unit.unit_name = base_name
			new_unit.max_hp = ud["hp"]; new_unit.current_hp = ud["hp"]
			new_unit.attack = ud["atk"]; new_unit.spd = ud["spd"]
			new_unit.mana = ud["mana"]; new_unit.race = ud.get("race", "")
			new_unit.attack_range = ud.get("range", "1行")
			new_unit.skills = ud.get("skills", []).duplicate(true)
			bm._pending_revives.append({"timer": 0.0, "side": side, "row": row, "unit": new_unit, "hp": ud["hp"]})

func do_deck_add(merged: Dictionary, ctx: Dictionary) -> void:
	var dm: Node       = ctx.get("dm", null)
	var ai: Node       = ctx.get("ai", null)
	var side: int      = ctx.get("side", 0)
	var source: Object = ctx.get("source", null)
	var unit_id: String = merged.get("unit_id", "self")
	var count: int      = merged.get("count", 1)
	var position: String = merged.get("position", "random")
	if unit_id == "self" and source != null:
		var deck_mgr = dm if side == 0 else ai
		if deck_mgr != null:
			for _i in range(count):
				var card = source.clone()
				card.current_hp = card.max_hp
				card.persistence = "battle"  # バトル中追加カードはバトル後消滅
				var deck_arr: Array = deck_mgr.deck
				match position:
					"bottom":
						deck_arr.append(card)
					"top":
						deck_arr.insert(0, card)
					_:
						var pos: int = randi() % max(1, deck_arr.size() + 1)
						deck_arr.insert(pos, card)

func do_draw(merged: Dictionary, ctx: Dictionary) -> void:
	var eq: Node       = ctx.get("eq", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var count: int = merged.get("count", 2)
	if eq != null:
		eq.push(4, source, null, "draw_cards", float(count),
			{"side": side, "src_side": side, "src_row": row, "src_col": col, "skill_name": "draw_cards"})

func do_mana_add(merged: Dictionary, ctx: Dictionary) -> void:
	var dm: Node  = ctx.get("dm", null)
	var ai: Node  = ctx.get("ai", null)
	var side: int = ctx.get("side", 0)
	var amount: float = merged.get("amount", 3)
	if dm != null:
		dm.mana = min(dm.MANA_MAX, dm.mana + amount)
	elif ai != null and side == 1:
		ai.mana = min(ai.MANA_MAX, ai.mana + amount)

func do_steal_buffs(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var source: Object = ctx.get("source", null)
	var target: Object = ctx.get("target", null)
	if source != null and target != null and bm != null:
		var factor: float = merged.get("factor", 1.5)
		bm._steal_buffs(source, target, factor)

func do_steal_all_buffs(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node        = ctx.get("bm", null)
	var side: int       = ctx.get("side", 0)
	var source: Object  = ctx.get("source", null)
	var enemy_side: int = ctx.get("enemy_side", 1 - side)
	if source != null and bm != null:
		var factor: float = merged.get("factor", 1.5)
		var best: Object = null
		var best_count: int = 0
		for r2 in range(3):
			for c2 in range(3):
				var u = bm.board[enemy_side][r2][c2]
				if u == null or not u.is_alive():
					continue
				var cnt: int = 0
				if u._atk_bonus > 0: cnt += 1
				if u._interval_bonus > 0.0: cnt += 1
				if u._has_penetrate: cnt += 1
				if u.regen_stacks > 0: cnt += 1
				if u._damage_reduction > 0: cnt += 1
				if cnt > best_count:
					best_count = cnt
					best = u
		if best != null:
			bm._steal_buffs(source, best, factor)

func do_move(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var dest: String = merged.get("dest", "front")
	if dest == "front" and bm != null:
		var front_col: int = 2 if side == 0 else 0
		if col != front_col and bm.board[side][row][front_col] == null:
			bm.board[side][row][front_col] = source
			bm.attack_timers[side][row][front_col] = source.get_attack_interval()
			bm.board[side][row][col] = null
			bm.attack_timers[side][row][col] = 0.0
			bm.on_board_changed()

func do_skill_flag(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var source: Object = ctx.get("source", null)
	if source != null:
		var flags: Dictionary = merged.get("flags", {})
		var tgt_str: String = merged.get("target", "")
		if tgt_str == "same_row" and bm != null:
			for c2 in range(3):
				var ally = bm.board[side][row][c2]
				if ally != null and ally != source:
					for flag_key in flags:
						if flag_key == "_support_revive":
							if not ally._support_revive_used:
								ally.set(flag_key, flags[flag_key])
						else:
							ally.set(flag_key, flags[flag_key])
		else:
			for flag_key in flags:
				source.set(flag_key, flags[flag_key])
			if merged.has("atk_factor"):
				source._back_atk_factor = merged["atk_factor"]

func do_inject_status(merged: Dictionary, ctx: Dictionary) -> void:
	var dm: Node  = ctx.get("dm", null)
	var ai: Node  = ctx.get("ai", null)
	var side: int = ctx.get("side", 0)
	var card_id: String = merged.get("card_id", "")
	var tgt_deck: String = merged.get("target", "self_deck")
	if card_id != "":
		var deck_target: Node = null
		if tgt_deck == "self_deck":
			deck_target = dm if side == 0 else ai
		elif tgt_deck == "enemy_deck":
			deck_target = ai if side == 0 else dm
		else:
			deck_target = dm
		_inject_status_card_internal(deck_target, card_id, side)

func do_cost_reduce(merged: Dictionary, ctx: Dictionary) -> void:
	var dm: Node = ctx.get("dm", null)
	var count: int = merged.get("count", 3)
	if dm != null:
		dm._cost_reduction_remaining = count

func do_temp_buff_all(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node  = ctx.get("bm", null)
	var side: int = ctx.get("side", 0)
	var buff: String    = merged.get("buff", "spd")
	var factor: float   = merged.get("factor", 0.5)
	var duration: float = merged.get("duration", 5.0)
	if bm != null:
		for r2 in range(3):
			for c2 in range(3):
				var u = bm.board[side][r2][c2]
				if u != null and u.is_alive():
					if buff == "spd":
						u._temp_spd_bonus = u.get_attack_interval() * factor
						u._temp_spd_timer = duration

func do_stat_boost(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node  = ctx.get("bm", null)
	var side: int = ctx.get("side", 0)
	var atk_add: int = merged.get("atk", 0)
	var hp_add: int  = merged.get("hp", 0)
	var tgt_type: String = merged.get("target", "all_allies")
	if tgt_type == "single_ally":
		var tgt = targets.pick_ally_by_strategy(side, bm, "max_hp")
		if tgt != null:
			tgt.attack += atk_add
			tgt.max_hp += hp_add
			tgt.current_hp = min(tgt.max_hp, tgt.current_hp + hp_add)
	else:
		if bm != null:
			for r2 in range(3):
				for c2 in range(3):
					var u = bm.board[side][r2][c2]
					if u != null and u.is_alive():
						u.attack += atk_add
						u.max_hp += hp_add
						u.current_hp = min(u.max_hp, u.current_hp + hp_add)

func do_deck_remove_status(merged: Dictionary, ctx: Dictionary) -> void:
	var dm: Node = ctx.get("dm", null)
	if dm != null:
		for i in range(dm.deck.size()):
			if dm.deck[i].card_type == "status_spell":
				dm.deck.remove_at(i)
				return

func do_front_status(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node        = ctx.get("bm", null)
	var eq: Node        = ctx.get("eq", null)
	var side: int       = ctx.get("side", 0)
	var row: int        = ctx.get("row", 0)
	var col: int        = ctx.get("col", 0)
	var enemy_side: int = ctx.get("enemy_side", 1 - side)
	var status: String = merged.get("status", "")
	var stacks: int    = merged.get("stacks", 2)
	var both: bool     = merged.get("both_sides", false)
	if bm != null and eq != null:
		var sides_to_apply: Array = [0, 1] if both else [enemy_side]
		for s2 in sides_to_apply:
			var front: int = 2 if s2 == 0 else 0
			for r2 in range(3):
				var u = bm.board[s2][r2][front]
				if u != null and u.is_alive():
					var status_jp: String = _status_to_jp(status)
					eq.push(4, null, u, "status_apply", 0.0,
						{"status": status_jp, "stacks": stacks, "side": s2, "row": r2, "col": front,
						 "src_side": side, "src_row": row, "src_col": col, "skill_name": status})

func do_front_damage_status(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node  = ctx.get("bm", null)
	var eq: Node  = ctx.get("eq", null)
	var side: int = ctx.get("side", 0)
	var row: int  = ctx.get("row", 0)
	var col: int  = ctx.get("col", 0)
	var dmg: int       = merged.get("damage", 10)
	var status: String = merged.get("status", "")
	var stacks: int    = merged.get("stacks", 2)
	if bm != null and eq != null:
		for s2 in range(2):
			var front: int = 2 if s2 == 0 else 0
			for r2 in range(3):
				var u = bm.board[s2][r2][front]
				if u != null and u.is_alive():
					eq.push(1, null, u, "damage", float(dmg),
						{"enemy_side": s2, "row": r2, "col": front})
					var status_jp: String = _status_to_jp(status)
					eq.push(4, null, u, "status_apply", 0.0,
						{"status": status_jp, "stacks": stacks, "side": s2, "row": r2, "col": front,
						 "src_side": side, "src_row": row, "src_col": col, "skill_name": status})

func do_all_enemy_damage(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node        = ctx.get("bm", null)
	var eq: Node        = ctx.get("eq", null)
	var enemy_side: int = ctx.get("enemy_side", 1)
	var dmg: int = merged.get("damage", 8)
	if bm != null and eq != null:
		for r2 in range(3):
			for c2 in range(3):
				var u = bm.board[enemy_side][r2][c2]
				if u != null and u.is_alive():
					eq.push(1, null, u, "damage", float(dmg),
						{"enemy_side": enemy_side, "row": r2, "col": c2})

func do_all_enemy_debuff(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node        = ctx.get("bm", null)
	var enemy_side: int = ctx.get("enemy_side", 1)
	var status: String = merged.get("status", "burn")
	var stacks: int    = merged.get("stacks", 2)
	if bm != null:
		for r2 in range(3):
			for c2 in range(3):
				var u = bm.board[enemy_side][r2][c2]
				if u != null and u.is_alive():
					match status:
						"burn":      u.burn_turns += stacks
						"freeze":    u.frozen_turns += stacks
						"poison":    u.poison_stacks += stacks

func do_move_enemy_random(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node        = ctx.get("bm", null)
	var enemy_side: int = ctx.get("enemy_side", 1)
	if bm != null:
		var units: Array = []
		for r2 in range(3):
			for c2 in range(3):
				var u = bm.board[enemy_side][r2][c2]
				if u != null and u.is_alive():
					units.append({"unit": u, "row": r2, "col": c2})
		if not units.is_empty():
			var pick = units[randi() % units.size()]
			var new_row: int = randi() % 3
			if new_row != pick["row"] and bm.board[enemy_side][new_row][pick["col"]] == null:
				bm.board[enemy_side][new_row][pick["col"]] = pick["unit"]
				bm.attack_timers[enemy_side][new_row][pick["col"]] = pick["unit"].get_attack_interval()
				bm.board[enemy_side][pick["row"]][pick["col"]] = null
				bm.attack_timers[enemy_side][pick["row"]][pick["col"]] = 0.0
				bm.on_board_changed()

func do_swap_front_back(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node        = ctx.get("bm", null)
	var enemy_side: int = ctx.get("enemy_side", 1)
	if bm != null:
		var front: int = 0 if enemy_side == 1 else 2
		var back: int  = 2 if enemy_side == 1 else 0
		for r2 in range(3):
			var f_u = bm.board[enemy_side][r2][front]
			var b_u = bm.board[enemy_side][r2][back]
			bm.board[enemy_side][r2][front] = b_u
			bm.board[enemy_side][r2][back] = f_u
			var f_t = bm.attack_timers[enemy_side][r2][front]
			bm.attack_timers[enemy_side][r2][front] = bm.attack_timers[enemy_side][r2][back]
			bm.attack_timers[enemy_side][r2][back] = f_t
		bm.on_board_changed()

func do_push_to_back(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node        = ctx.get("bm", null)
	var enemy_side: int = ctx.get("enemy_side", 1)
	if bm != null:
		var front: int = 0 if enemy_side == 1 else 2
		var back: int  = 2 if enemy_side == 1 else 0
		for r2 in range(3):
			var u = bm.board[enemy_side][r2][front]
			if u != null and bm.board[enemy_side][r2][back] == null:
				bm.board[enemy_side][r2][back] = u
				bm.attack_timers[enemy_side][r2][back] = u.get_attack_interval()
				bm.board[enemy_side][r2][front] = null
				bm.attack_timers[enemy_side][r2][front] = 0.0
				bm.on_board_changed()
				return

func do_delay_spawn(merged: Dictionary, ctx: Dictionary) -> void:
	var dm: Node  = ctx.get("dm", null)
	var ai: Node  = ctx.get("ai", null)
	var side: int = ctx.get("side", 0)
	var seconds: float = merged.get("seconds", 3)
	if side == 0 and ai != null:
		ai._check_timer += seconds
	elif side == 1 and dm != null:
		dm._check_timer += seconds

func do_randomize_col(merged: Dictionary, ctx: Dictionary) -> void:
	var dm: Node  = ctx.get("dm", null)
	var ai: Node  = ctx.get("ai", null)
	var side: int = ctx.get("side", 0)
	var deck_mgr = ai if side == 0 else dm
	if deck_mgr != null:
		var next_c = deck_mgr.get_next_card()
		if next_c != null:
			next_c.assigned_col = randi() % 3

func do_revive(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var source: Object = ctx.get("source", null)
	if source != null and bm != null and not source._has_revived:
		source._has_revived = true
		var hp_val: int = merged.get("hp", 5)
		var delay: float = merged.get("delay", 3.0)
		bm._pending_revives.append({"timer": delay, "side": side, "row": row, "unit": source, "hp": hp_val})

func do_revive_ally(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var source: Object = ctx.get("source", null)
	if bm != null:
		var race_filter: String = merged.get("race", "アンデッド")
		var hp_val = merged.get("hp", "full")
		var best: Object = null
		var best_ratio: float = 1.0
		for r2 in range(3):
			for c2 in range(3):
				var ally = bm.board[side][r2][c2]
				if ally == null or not ally.is_alive():
					continue
				if ally.race != race_filter:
					continue
				if ally == source:
					continue
				var ratio: float = float(ally.current_hp) / float(ally.max_hp)
				if ratio < best_ratio:
					best_ratio = ratio
					best = ally
		if best != null and best_ratio < 1.0:
			if hp_val == "full":
				best.current_hp = best.max_hp
			else:
				best.current_hp = min(best.max_hp, best.current_hp + int(hp_val))

func do_crystallize(merged: Dictionary, ctx: Dictionary) -> void:
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
	var tgt = targets.resolve(merged, context, true)
	for t in tgt:
		t._invincible_timer = 999.0

func do_race_buff(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var source: Object = ctx.get("source", null)
	var race_filter: String = merged.get("race", "")
	var atk_pct: float = merged.get("atk_pct", 0.5)
	if bm != null:
		for r2 in range(3):
			for c2 in range(3):
				var u = bm.board[side][r2][c2]
				if u != null and u.is_alive() and u != source:
					if race_filter == "" or u.race == race_filter:
						u._atk_bonus += max(1, int(float(u.attack) * atk_pct))

func do_tile_set(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node        = ctx.get("bm", null)
	var side: int       = ctx.get("side", 0)
	var row: int        = ctx.get("row", 0)
	var col: int        = ctx.get("col", 0)
	var enemy_side: int = ctx.get("enemy_side", 1 - side)
	var tile_id: String = merged.get("tile_id", "")
	var scope: String   = merged.get("scope", "all")
	var tgt_tile: String = merged.get("target", "")
	if bm != null and tile_id != "":
		var _EDB_tile = load("res://scripts/EffectDB.gd")
		var tile_def = _EDB_tile.EFFECTS.get(tile_id, {})
		var tile_dur: float = tile_def.get("duration", -1.0)
		if tgt_tile == "adjacent_8":
			for dr in range(-1, 2):
				for dc in range(-1, 2):
					if dr == 0 and dc == 0:
						continue
					var r2: int = row + dr
					var c2: int = col + dc
					if r2 >= 0 and r2 < 3 and c2 >= 0 and c2 < 3:
						bm.set_tile_effect(side, r2, c2, tile_id, tile_dur)
		else:
			var sides_to_set: Array = []
			var cols_to_set: Array = [0, 1, 2]  # デフォルトは全列
			match scope:
				"all":   sides_to_set = [0, 1]
				"enemy": sides_to_set = [enemy_side]
				"ally":  sides_to_set = [side]
				"front_columns":
					sides_to_set = [0, 1]
					cols_to_set = [0]  # 前列のみ
			for s2 in sides_to_set:
				for r2 in range(3):
					for c2 in cols_to_set:
						bm.set_tile_effect(s2, r2, c2, tile_id, tile_dur)

# ---- ユーティリティ ----

func _inject_status_card_internal(deck_mgr: Node, card_name: String, _side: int) -> void:
	if deck_mgr == null:
		return
	var UnitDataScript = load("res://scripts/UnitData.gd")
	var card = UnitDataScript.new()
	card.unit_name = card_name
	card.card_type = "status_spell"
	card.spell_id = card_name
	card.mana = 0
	card.is_consumable = true
	card.persistence = "battle"  # バトル終了後にデッキから除去
	card.spell_target = "single_ally"
	match card_name:
		"毒カード":
			card.spell_effect = "味方ランダム1体に毒2付与"
			card.skills = [{"trigger": "on_play", "effect_id": "poison_apply", "params": {"target": "random_ally", "stacks": 2}}]
		"凍結カード":
			card.spell_effect = "味方ランダム1体に凍結2付与"
			card.skills = [{"trigger": "on_play", "effect_id": "freeze_apply", "params": {"target": "random_ally", "stacks": 2}}]
		"火傷カード":
			card.spell_effect = "味方ランダム1体に火傷2付与"
			card.skills = [{"trigger": "on_play", "effect_id": "burn_apply", "params": {"target": "random_ally", "stacks": 2}}]
		"麻痺カード":
			card.spell_effect = "味方ランダム1体に麻痺2付与"
	var deck_arr: Array = deck_mgr.deck
	var pos: int = randi() % max(1, deck_arr.size() + 1)
	deck_arr.insert(pos, card)

func _status_to_jp(status: String) -> String:
	match status:
		"burn":      return "火傷"
		"freeze":    return "凍結"
		"poison":    return "毒"
		"curse":     return "呪い"
		"brand":     return "烙印"
		_:           return status

# ---- Phase 5-2: 新規type実装 ----

func do_debuff_amplify(merged: Dictionary, ctx: Dictionary) -> void:
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
	var factor: float = merged.get("factor", 2.0)
	for t in tgt:
		t.poison_stacks = int(t.poison_stacks * factor)
		t.frozen_turns = int(t.frozen_turns * factor)
		t.burn_turns = int(t.burn_turns * factor)
		t.curse_stacks = int(t.curse_stacks * factor)
		t.brand_stacks = int(t.brand_stacks * factor)

func do_execute_threshold(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
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
	var threshold: int = merged.get("threshold", 50)
	for t in tgt:
		var total_stacks: int = t.poison_stacks + t.frozen_turns + t.burn_turns + t.curse_stacks + t.brand_stacks
		if total_stacks >= threshold:
			t.current_hp = 0
			if eq != null:
				var t_side: int = targets.get_unit_side(t, bm)
				var t_row: int = targets.get_unit_row(t, bm)
				var t_col: int = targets.get_unit_col(t, bm)
				eq.push(3, source, t, "execute", 0.0, {"side": t_side, "row": t_row, "col": t_col})

func do_hp_percent_damage(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
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
	var percent: float = merged.get("percent", 0.1)
	for t in tgt:
		var extra_dmg: int = int(t.current_hp * percent)
		if extra_dmg > 0:
			t.current_hp = max(0, t.current_hp - extra_dmg)
			if eq != null:
				var t_side: int = targets.get_unit_side(t, bm)
				var t_row: int = targets.get_unit_row(t, bm)
				var t_col: int = targets.get_unit_col(t, bm)
				eq.push(3, source, t, "damage", 0.0, {"damage": extra_dmg, "side": t_side, "row": t_row, "col": t_col})

func do_skill_disable(merged: Dictionary, ctx: Dictionary) -> void:
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
	var duration: float = merged.get("duration", 5.0)
	for t in tgt:
		if not t.has("_skill_timers"):
			continue
		t._skill_timers["skill_disable"] = duration

func do_position_swap(merged: Dictionary, ctx: Dictionary) -> void:
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
	if bm == null or tgt.size() == 0:
		return
	var enemy_side: int = 1 - side
	var back_col: int = 0 if enemy_side == 0 else 2
	for t in tgt:
		var t_side: int = targets.get_unit_side(t, bm)
		var t_row: int = targets.get_unit_row(t, bm)
		var t_col: int = targets.get_unit_col(t, bm)
		if t_side == enemy_side:
			var back_unit = bm.board[enemy_side][t_row][back_col]
			bm.board[enemy_side][t_row][t_col] = back_unit
			bm.board[enemy_side][t_row][back_col] = t
			if back_unit != null:
				back_unit.assigned_col = t_col
			t.assigned_col = back_col

func do_support_disable(merged: Dictionary, ctx: Dictionary) -> void:
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
	for t in tgt:
		if not t.has("_skill_timers"):
			continue
		t._skill_timers["support_disable"] = 999.0

func do_position_shuffle(merged: Dictionary, ctx: Dictionary) -> void:
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
	var threshold: int = merged.get("threshold", 5)
	if bm == null:
		return
	for t in tgt:
		if t.curse_stacks >= threshold:
			var t_side: int = targets.get_unit_side(t, bm)
			if t_side == -1:
				continue
			var positions: Array = []
			for r2 in range(3):
				for c2 in range(3):
					if bm.board[t_side][r2][c2] != null:
						positions.append({"r": r2, "c": c2, "unit": bm.board[t_side][r2][c2]})
			positions.shuffle()
			for i in range(positions.size()):
				var pos = positions[i]
				var u = pos["unit"]
				bm.board[t_side][pos["r"]][pos["c"]] = null
			for i in range(positions.size()):
				var pos = positions[i]
				var u = pos["unit"]
				bm.board[t_side][pos["r"]][pos["c"]] = u
				u.assigned_col = pos["c"]

func do_initial_swap(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	if bm == null or source == null:
		return
	var front_col: int = 2 if side == 0 else 0
	var mid_col: int = 1
	if col == mid_col:
		var front_unit = bm.board[side][row][front_col]
		bm.board[side][row][front_col] = source
		bm.board[side][row][mid_col] = front_unit
		source.assigned_col = front_col
		if front_unit != null:
			front_unit.assigned_col = mid_col

func do_heal_percent(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
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
	var tgt = targets.resolve(merged, context, true)
	var percent: float = merged.get("percent", 0.1)
	for t in tgt:
		var heal_amt: int = int(t.max_hp * percent)
		t.current_hp = min(t.max_hp, t.current_hp + heal_amt)
		if eq != null:
			var t_side: int = targets.get_unit_side(t, bm)
			var t_row: int = targets.get_unit_row(t, bm)
			var t_col: int = targets.get_unit_col(t, bm)
			eq.push(2, source, t, "heal", 0.0, {"heal": heal_amt, "side": t_side, "row": t_row, "col": t_col})

func do_heal_front_percent(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	if bm == null:
		return
	var front_col: int = 2 if side == 0 else 0
	var front_unit = bm.board[side][row][front_col]
	if front_unit == null:
		return
	var percent: float = merged.get("percent", 0.25)
	var heal_amt: int = int(front_unit.max_hp * percent)
	front_unit.current_hp = min(front_unit.max_hp, front_unit.current_hp + heal_amt)
	if eq != null:
		eq.push(2, source, front_unit, "heal", 0.0, {"heal": heal_amt, "side": side, "row": row, "col": front_col})

func do_full_hp_defense(merged: Dictionary, ctx: Dictionary) -> void:
	pass  # このeffectはalwaysトリガーでBoardManager側で処理される

func do_damage_accumulate(merged: Dictionary, ctx: Dictionary) -> void:
	pass  # このeffectはalwaysトリガーでBoardManager側で処理される

func do_hp_equalize(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	if bm == null:
		return
	var units: Array = []
	var total_hp: int = 0
	for r in range(3):
		for c in range(3):
			var u = bm.board[side][r][c]
			if u != null:
				units.append(u)
				total_hp += u.current_hp
	if units.size() == 0:
		return
	var avg_hp: int = int(total_hp / units.size())
	for u in units:
		u.current_hp = min(u.max_hp, avg_hp)

func do_front_spd_reduce(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	if bm == null:
		return
	var front_col: int = 2 if side == 0 else 0
	var factor: float = merged.get("factor", 0.2)
	for r in range(3):
		var u = bm.board[side][r][front_col]
		if u != null:
			u._interval_bonus -= u.spd * factor

func do_self_damage_attack(merged: Dictionary, ctx: Dictionary) -> void:
	var source: Object = ctx.get("source", null)
	if source == null:
		return
	var hp_percent: float = merged.get("hp_percent", 0.025)
	var atk_percent: float = merged.get("atk_percent", 0.01)
	var spd_percent: float = merged.get("spd_percent", 0.01)
	# HP減少
	var hp_loss: int = max(1, int(source.max_hp * hp_percent))
	source.current_hp = max(1, source.current_hp - hp_loss)
	# ATK低下（永続）
	var atk_loss: int = max(1, int(source.attack * atk_percent))
	source.attack = max(1, source.attack - atk_loss)
	# SPD低下（永続）
	var spd_loss: float = source.spd * spd_percent
	source.spd = max(0.1, source.spd - spd_loss)

func do_ally_death_penalty(merged: Dictionary, ctx: Dictionary) -> void:
	var source: Object = ctx.get("source", null)
	if source == null:
		return
	var atk_percent: float = merged.get("atk_percent", 0.1)
	var spd_percent: float = merged.get("spd_percent", 0.1)
	var hp_percent: float = merged.get("hp_percent", 0.2)
	# ATK低下（永続）
	var atk_loss: int = max(1, int(source.attack * atk_percent))
	source.attack = max(1, source.attack - atk_loss)
	# SPD低下（永続）
	var spd_loss: float = source.spd * spd_percent
	source.spd = max(0.1, source.spd - spd_loss)
	# 最大HP低下（永続）
	var hp_loss: int = max(1, int(source.max_hp * hp_percent))
	source.max_hp = max(1, source.max_hp - hp_loss)
	source.current_hp = min(source.current_hp, source.max_hp)

func do_heal_to_damage(merged: Dictionary, ctx: Dictionary) -> void:
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
	var duration: float = merged.get("duration", 3.0)
	for t in tgt:
		if not t.has("_skill_timers"):
			continue
		t._skill_timers["heal_to_damage"] = duration

func do_curse_heal_reduce(merged: Dictionary, ctx: Dictionary) -> void:
	pass  # このeffectはalwaysトリガーでTickSystem側で処理される

func do_buff_to_curse(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
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
	var percent: float = merged.get("percent", 0.3)
	for t in tgt:
		var total_buff: int = t.boots_stacks + t.sense_stacks + t.power_stacks + t.spring_stacks + t.regen_stacks
		var curse_amt: int = int(total_buff * percent)
		if curse_amt > 0:
			t.curse_stacks += curse_amt
			t.boots_stacks = int(t.boots_stacks * (1.0 - percent))
			t.sense_stacks = int(t.sense_stacks * (1.0 - percent))
			t.power_stacks = int(t.power_stacks * (1.0 - percent))
			t.spring_stacks = int(t.spring_stacks * (1.0 - percent))
			t.regen_stacks = int(t.regen_stacks * (1.0 - percent))
			if eq != null:
				var t_side: int = targets.get_unit_side(t, bm)
				var t_row: int = targets.get_unit_row(t, bm)
				var t_col: int = targets.get_unit_col(t, bm)
				eq.push(4, source, t, "status_apply", 0.0,
					{"status": "呪い", "stacks": curse_amt, "side": t_side, "row": t_row, "col": t_col})

func do_extended_range(merged: Dictionary, ctx: Dictionary) -> void:
	pass  # このeffectはalwaysトリガーでCombatSystem側で処理される

func do_mana_gen_trigger(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var dm: Node       = ctx.get("dm", null)
	var side: int      = ctx.get("side", 0)
	if bm == null or dm == null:
		return
	for r in range(3):
		for c in range(3):
			var u = bm.board[side][r][c]
			if u != null and u.mana > 0:
				dm.add_mana(u.mana)

func do_thorn_damage_all(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
	var side: int      = ctx.get("side", 0)
	var source: Object = ctx.get("source", null)
	if bm == null:
		return
	var enemy_side: int = 1 - side
	for r in range(3):
		for c in range(3):
			var t = bm.board[enemy_side][r][c]
			if t != null:
				var thorn_stacks: int = 0
				if t.has("thorn_stacks"):
					thorn_stacks = t.get("thorn_stacks", 0)
				if thorn_stacks > 0:
					var dmg: int = thorn_stacks
					t.current_hp = max(0, t.current_hp - dmg)
					if eq != null:
						eq.push(3, source, t, "damage", 0.0, {"damage": dmg, "side": enemy_side, "row": r, "col": c})

func do_mana_flare_damage(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node       = ctx.get("bm", null)
	var dm: Node       = ctx.get("dm", null)
	var eq: Node       = ctx.get("eq", null)
	var side: int      = ctx.get("side", 0)
	var source: Object = ctx.get("source", null)
	if bm == null or dm == null:
		return
	var current_mana: int = dm.current_mana
	if current_mana <= 0:
		return
	dm.current_mana = 0
	var enemy_side: int = 1 - side
	for r in range(3):
		for c in range(3):
			var t = bm.board[enemy_side][r][c]
			if t != null:
				t.current_hp = max(0, t.current_hp - current_mana)
				if eq != null:
					eq.push(3, source, t, "damage", 0.0, {"damage": current_mana, "side": enemy_side, "row": r, "col": c})

# ---- Phase 3-1: 毒系スライム用エフェクト ----

func do_poison_amplify(merged: Dictionary, ctx: Dictionary) -> void:
	# 単体毒増幅
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
	var factor: float = merged.get("factor", 2.0)
	for t in tgt:
		if t.has("poison_stacks"):
			t.poison_stacks = int(t.poison_stacks * factor)

func do_poison_amplify_all(merged: Dictionary, ctx: Dictionary) -> void:
	# 全体毒増幅
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
	var factor: float = merged.get("factor", 1.5)
	for t in tgt:
		if t.has("poison_stacks") and t.poison_stacks > 0:
			t.poison_stacks = int(t.poison_stacks * factor)

func do_poison_add_conditional(merged: Dictionary, ctx: Dictionary) -> void:
	# 条件付き毒追加（対象が毒を持っている場合のみ追加）
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
	var stacks: int = merged.get("stacks", 5)
	for t in tgt:
		if t.has("poison_stacks") and t.poison_stacks > 0:
			t.poison_stacks += stacks

func do_poison_damage(merged: Dictionary, ctx: Dictionary) -> void:
	# 毒スタック数に応じたダメージ
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
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
	var consume: bool = merged.get("consume", false)
	for t in tgt:
		if t.has("poison_stacks"):
			var dmg: int = t.poison_stacks
			if dmg > 0:
				t.current_hp = max(0, t.current_hp - dmg)
				if eq != null:
					var t_side: int = targets.get_unit_side(t, bm)
					var t_row: int = targets.get_unit_row(t, bm)
					var t_col: int = targets.get_unit_col(t, bm)
					eq.push(3, source, t, "damage", 0.0, {"damage": dmg, "side": t_side, "row": t_row, "col": t_col})
				if consume:
					t.poison_stacks = 0

func do_armor_damage(merged: Dictionary, ctx: Dictionary) -> void:
	# 盾スタック数×multiplierダメージ（消費なし）
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
	var armor_dmg: int = source._damage_reduction * multiplier
	if armor_dmg > 0:
		var context: Dictionary = {
			"board_manager": bm, "side": side, "row": row, "col": col,
			"source": source, "target": target, "damage": 0
		}
		var t_side: int = targets.get_unit_side(target, bm)
		var t_row: int = targets.get_unit_row(target, bm)
		var t_col: int = targets.get_unit_col(target, bm)
		eq.push(1, source, target, "damage", float(armor_dmg), {"enemy_side": t_side, "row": t_row, "col": t_col})

func do_armor_damage_consume(merged: Dictionary, ctx: Dictionary) -> void:
	# 盾スタック数×multiplierダメージ（全消費）
	var bm: Node       = ctx.get("bm", null)
	var eq: Node       = ctx.get("eq", null)
	var side: int      = ctx.get("side", 0)
	var row: int       = ctx.get("row", 0)
	var col: int       = ctx.get("col", 0)
	var source: Object = ctx.get("source", null)
	var target: Object = ctx.get("target", null)
	var multiplier: int = merged.get("multiplier", 2)
	if source == null or target == null or eq == null:
		return
	var armor_dmg: int = source._damage_reduction * multiplier
	if armor_dmg > 0:
		var t_side: int = targets.get_unit_side(target, bm)
		var t_row: int = targets.get_unit_row(target, bm)
		var t_col: int = targets.get_unit_col(target, bm)
		eq.push(1, source, target, "damage", float(armor_dmg), {"enemy_side": t_side, "row": t_row, "col": t_col})
		source._damage_reduction = 0

func do_mana_steal(merged: Dictionary, ctx: Dictionary) -> void:
	# 敵マナ吸収（ATK×factor）
	var dm: RefCounted = ctx.get("dm", null)
	var ai: RefCounted = ctx.get("ai", null)
	var side: int      = ctx.get("side", 0)
	var source: Object = ctx.get("source", null)
	var factor: float  = merged.get("factor", 0.1)
	if source == null:
		return
	var steal_amount: float = float(source.attack) * factor
	if side == 0 and dm != null and ai != null:
		ai.mana = max(0.0, ai.mana - steal_amount)
		dm.mana = min(dm.mana + steal_amount, dm.MANA_MAX)
	elif side == 1 and dm != null and ai != null:
		dm.mana = max(0.0, dm.mana - steal_amount)
		ai.mana = min(ai.mana + steal_amount, ai.MANA_MAX)

func do_mana_steal_shield(merged: Dictionary, ctx: Dictionary) -> void:
	# 敵マナ吸収→全味方に盾付与
	var bm: Node       = ctx.get("bm", null)
	var dm: RefCounted = ctx.get("dm", null)
	var ai: RefCounted = ctx.get("ai", null)
	var side: int      = ctx.get("side", 0)
	var source: Object = ctx.get("source", null)
	var factor: float  = merged.get("factor", 0.1)
	var armor_mult: int = merged.get("armor_mult", 2)
	if source == null or bm == null:
		return
	var steal_amount: float = float(source.attack) * factor
	if side == 0 and dm != null and ai != null:
		ai.mana = max(0.0, ai.mana - steal_amount)
	elif side == 1 and dm != null and ai != null:
		dm.mana = max(0.0, dm.mana - steal_amount)
	var armor_stacks: int = int(steal_amount * float(armor_mult))
	if armor_stacks > 0:
		for r in range(3):
			for c in range(3):
				var ally = bm.board[side][r][c]
				if ally != null:
					ally._damage_reduction += armor_stacks

func do_poison_by_x(merged: Dictionary, ctx: Dictionary) -> void:
	# X値×multiplier分の毒付与
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
	var multiplier: int = merged.get("multiplier", 1)
	if source == null:
		return
	var poison_amount: int = source.x_stacks * multiplier
	for t in tgt:
		if poison_amount > 0:
			t.poison_stacks += poison_amount

func do_x_stack_add(merged: Dictionary, ctx: Dictionary) -> void:
	# X値にstacks加算
	var source: Object = ctx.get("source", null)
	var stacks: int = merged.get("stacks", 1)
	if source == null:
		return
	source.x_stacks += stacks

func do_x_stack_add_from_field(merged: Dictionary, ctx: Dictionary) -> void:
	# 盤面毒スタック総数をX値に加算
	var bm: Node       = ctx.get("bm", null)
	var source: Object = ctx.get("source", null)
	if source == null or bm == null:
		return
	var total_poison: int = 0
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = bm.board[s][r][c]
				if u != null:
					total_poison += u.poison_stacks
	source.x_stacks += total_poison

func do_curse_amplify_all(merged: Dictionary, ctx: Dictionary) -> void:
	# 条件を満たした敵全体の呪いスタックを増幅
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var factor: float  = merged.get("factor", 1.5)
	var min_curse: int = merged.get("min_curse", 5)
	if bm == null:
		return
	var enemy_side: int = 1 - side
	for r in range(3):
		for c in range(3):
			var enemy = bm.board[enemy_side][r][c]
			if enemy != null and enemy.curse_stacks >= min_curse:
				enemy.curse_stacks = int(float(enemy.curse_stacks) * factor)

func do_buff_steal(merged: Dictionary, ctx: Dictionary) -> void:
	# バフ奪取（固定数 or 全て）
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
	var count: int = merged.get("count", 2)
	if source == null:
		return
	for t in tgt:
		var stolen: int = 0
		# 全バフ種別から奪取
		var buff_types: Array = [
			{"field": "_damage_reduction", "min": 1},
			{"field": "boots_stacks", "min": 1},
			{"field": "sense_stacks", "min": 1},
			{"field": "power_stacks", "min": 1},
			{"field": "spring_stacks", "min": 1},
			{"field": "regen_stacks", "min": 1}
		]
		for buff in buff_types:
			if stolen >= count:
				break
			var field: String = buff["field"]
			var min_val: int = buff["min"]
			if t.get(field, 0) >= min_val:
				var steal_amt: int = min(count - stolen, t.get(field, 0))
				t.set(field, t.get(field, 0) - steal_amt)
				if field == "_damage_reduction":
					source._stolen_armor += steal_amt
				elif field == "boots_stacks":
					source.boots_stacks += steal_amt
				elif field == "sense_stacks":
					source.sense_stacks += steal_amt
				elif field == "power_stacks":
					source.power_stacks += steal_amt
				elif field == "spring_stacks":
					source.spring_stacks += steal_amt
				elif field == "regen_stacks":
					source._stolen_regen += steal_amt
				stolen += steal_amt

func do_buff_to_curse(merged: Dictionary, ctx: Dictionary) -> void:
	# バフを呪いに変換（percent指定で部分変換、なしで全変換）
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
	var percent: float = merged.get("percent", 1.0)  # デフォルト100%（全変換）
	for t in tgt:
		var total_buffs: int = 0
		total_buffs += t.get("_damage_reduction", 0)
		total_buffs += t.get("boots_stacks", 0)
		total_buffs += t.get("sense_stacks", 0)
		total_buffs += t.get("power_stacks", 0)
		total_buffs += t.get("spring_stacks", 0)
		total_buffs += t.get("regen_stacks", 0)
		if total_buffs > 0:
			var convert_amount: int = int(float(total_buffs) * percent)
			if percent >= 1.0:
				# 全変換
				t._damage_reduction = 0
				t.boots_stacks = 0
				t.sense_stacks = 0
				t.power_stacks = 0
				t.spring_stacks = 0
				t.regen_stacks = 0
			else:
				# 部分変換（各バフから比例配分で減算）
				var reduction_factor: float = 1.0 - percent
				t._damage_reduction = int(float(t._damage_reduction) * reduction_factor)
				t.boots_stacks = int(float(t.boots_stacks) * reduction_factor)
				t.sense_stacks = int(float(t.sense_stacks) * reduction_factor)
				t.power_stacks = int(float(t.power_stacks) * reduction_factor)
				t.spring_stacks = int(float(t.spring_stacks) * reduction_factor)
				t.regen_stacks = int(float(t.regen_stacks) * reduction_factor)
			t.curse_stacks += convert_amount

func do_buff_to_curse_amplify(merged: Dictionary, ctx: Dictionary) -> void:
	# バフ→呪い変換＋追加呪い付与
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
	var amplify_factor: int = merged.get("amplify_factor", 2)
	for t in tgt:
		var total_buffs: int = 0
		total_buffs += t.get("_damage_reduction", 0)
		total_buffs += t.get("boots_stacks", 0)
		total_buffs += t.get("sense_stacks", 0)
		total_buffs += t.get("power_stacks", 0)
		total_buffs += t.get("spring_stacks", 0)
		total_buffs += t.get("regen_stacks", 0)
		if total_buffs > 0:
			t._damage_reduction = 0
			t.boots_stacks = 0
			t.sense_stacks = 0
			t.power_stacks = 0
			t.spring_stacks = 0
			t.regen_stacks = 0
			t.curse_stacks += total_buffs + (total_buffs * amplify_factor)
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
	# 棘スタック×ダメージ（味方死亡数で倍率上昇）
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
	var base_dmg: int = source.thorn_stacks * multiplier
	var death_mult: float = 1.0 + float(source._ally_death_count) * 0.1
	var thorn_dmg: int = int(float(base_dmg) * death_mult)
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
		dm.mana = min(dm.mana + mana_gain, dm.MANA_MAX)
	elif side == 1 and ai != null:
		ai.mana = min(ai.mana + mana_gain, ai.MANA_MAX)

func do_position_swap_front_back(merged: Dictionary, ctx: Dictionary) -> void:
	# 呪い閾値以上の敵前列1体を後列と入れ替え（呪い最大優先）
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var min_curse: int = merged.get("min_curse", 20)
	if bm == null:
		return
	var enemy_side: int = 1 - side
	var front_col: int = 0 if enemy_side == 0 else 2
	var back_col: int = 2 if enemy_side == 0 else 0
	# 呪いスタック最大の前列ユニットを選択
	var max_curse: int = 0
	var target_row: int = -1
	for r in range(3):
		var front_unit = bm.board[enemy_side][r][front_col]
		if front_unit != null and front_unit.curse_stacks >= min_curse:
			if front_unit.curse_stacks > max_curse:
				max_curse = front_unit.curse_stacks
				target_row = r
	if target_row >= 0:
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
	# 味方死亡時に自陣全員に棘スタック+1 & 死亡カウント+1
	var bm: Node       = ctx.get("bm", null)
	var side: int      = ctx.get("side", 0)
	var thorn_stacks: int = merged.get("thorn_stacks", 1)
	if bm == null:
		return
	for r in range(3):
		for c in range(3):
			var u = bm.board[side][r][c]
			if u != null:
				u.thorn_stacks += thorn_stacks
				u._ally_death_count += 1

func do_heal_reduction_cursed(merged: Dictionary, ctx: Dictionary) -> void:
	# 呪い持ち敵の回復量減少（常時効果・実装は回復処理側で対応）
	pass

func do_crit_mult_boost(merged: Dictionary, ctx: Dictionary) -> void:
	# クリティカル倍率上昇（センス÷10・常時効果・実装はクリティカル判定側で対応）
	pass
