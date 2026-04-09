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
		"lifesteal":
			for t in tgt:
				t.lifesteal_stacks += stacks
		"penetrate":
			for t in tgt:
				t._has_penetrate = true
		"armor":
			for t in tgt:
				t._damage_reduction += stacks
		"regen":
			for t in tgt:
				t._regen_stacks += stacks
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
					t._temp_spd_bonus = t.attack_interval * 0.3 * stacks
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
				slime.attack_interval = 4.0
				slime.cost = 1
				slime.assigned_col = 2 - c2 if side == 0 else c2
				slime.race = "スライム"
				slime.attack_range = "1行"
				slime.skills = []
				bm.board[side][row][c2] = slime
				bm.attack_timers[side][row][c2] = slime.attack_interval
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
			new_unit.attack = ud["atk"]; new_unit.attack_interval = ud["interval"]
			new_unit.cost = ud["cost"]; new_unit.race = ud.get("race", "")
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
				if u.lifesteal_stacks > 0: cnt += 1
				if u._has_penetrate: cnt += 1
				if u._regen_stacks > 0: cnt += 1
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
			bm.attack_timers[side][row][front_col] = source.attack_interval
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
						u._temp_spd_bonus = u.attack_interval * factor
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
	var status: String = merged.get("status", "paralysis")
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
						"paralysis": u.paralysis_turns += stacks

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
				bm.attack_timers[enemy_side][new_row][pick["col"]] = pick["unit"].attack_interval
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
				bm.attack_timers[enemy_side][r2][back] = u.attack_interval
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
			match scope:
				"all":   sides_to_set = [0, 1]
				"enemy": sides_to_set = [enemy_side]
				"ally":  sides_to_set = [side]
			for s2 in sides_to_set:
				for r2 in range(3):
					for c2 in range(3):
						bm.set_tile_effect(s2, r2, c2, tile_id, tile_dur)

func do_summon_to_empty(merged: Dictionary, ctx: Dictionary) -> void:
	var bm: Node  = ctx.get("bm", null)
	var side: int = ctx.get("side", 0)
	var unit_id_se: String = merged.get("unit_id", "ゴブリン")
	if bm != null:
		bm._summon_unit_to_random_empty(side, unit_id_se)

# ---- ユーティリティ ----

func _inject_status_card_internal(deck_mgr: Node, card_name: String, _side: int) -> void:
	if deck_mgr == null:
		return
	var UnitDataScript = load("res://scripts/UnitData.gd")
	var card = UnitDataScript.new()
	card.unit_name = card_name
	card.card_type = "status_spell"
	card.spell_id = card_name
	card.cost = 0
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
			card.skills = [{"trigger": "on_play", "effect_id": "paralysis_apply", "params": {"target": "random_ally", "stacks": 2}}]
	var deck_arr: Array = deck_mgr.deck
	var pos: int = randi() % max(1, deck_arr.size() + 1)
	deck_arr.insert(pos, card)

func _status_to_jp(status: String) -> String:
	match status:
		"burn":      return "火傷"
		"freeze":    return "凍結"
		"poison":    return "毒"
		"paralysis": return "麻痺"
	return status
