# EffectExecutor.gd
# 効果実行エンジン
# context構造: {trigger, side, row, col, source, target, damage, board_manager, deck_manager, enemy_ai, event_queue}
# class_name を使わない（Main.gdからpreload()で参照）
extends RefCounted

var _EffectDB = null  # EffectDB スクリプト参照（循環参照回避）

func _init() -> void:
	_EffectDB = load("res://scripts/EffectDB.gd")

# 効果を実行する
func execute(effect_id: String, params: Dictionary, context: Dictionary) -> void:
	# デフォルト値取得
	var defaults: Dictionary = {}
	if _EffectDB != null and _EffectDB.EFFECTS.has(effect_id):
		defaults = _EffectDB.EFFECTS[effect_id].duplicate()
	else:
		print("[EffectExecutor] 未知のeffect_id: %s" % effect_id)
		return
	# paramsで上書き
	var merged: Dictionary = defaults.duplicate()
	for k in params:
		merged[k] = params[k]

	var bm: Node       = context.get("board_manager", null)
	var dm: Node       = context.get("deck_manager", null)
	var ai: Node       = context.get("enemy_ai", null)
	var eq: Node       = context.get("event_queue", null)
	var side: int      = context.get("side", 0)
	var row: int       = context.get("row", 0)
	var col: int       = context.get("col", 0)
	var source: Object = context.get("source", null)
	var target: Object = context.get("target", null)
	var damage: int    = context.get("damage", 0)
	var enemy_side: int = 1 - side

	match merged["type"]:
		# ---- バフ付与 ----
		"buff_apply":
			var tgt = _resolve_target(merged, context, true)
			var stacks: int = merged.get("stacks", 1)
			var duration: float = merged.get("duration", 0.0)
			match merged.get("buff", ""):
				"lifesteal":
					for t in tgt:
						t.lifesteal_stacks += stacks
				"penetrate":
					for t in tgt:
						t._has_penetrate = true  # スキル方式（ON/OFF）
				"armor":
					for t in tgt:
						t._damage_reduction += stacks
				"regen":
					for t in tgt:
						t._regen_stacks += stacks
				"atk":
					if duration > 0.0:
						# 一時バフ（timer経由でdurationあり）
						for t in tgt:
							t._temp_atk_bonus = stacks
							t._temp_atk_timer = duration
					else:
						# 永続バフ（サポート効果・毎フレームリセット後再計算）
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

		# ---- バフ付与（確率） ----
		"buff_apply_chance":
			var tgt = _resolve_target(merged, context, true)
			var chance: float = merged.get("chance", 0.5)
			var stacks: int = merged.get("stacks", 1)
			if randf() <= chance:
				match merged.get("buff", ""):
					"armor":
						for t in tgt:
							t._damage_reduction += stacks

		# ---- デバフ付与 ----
		"debuff_apply":
			var tgt = _resolve_target(merged, context, false)
			var stacks: int = merged.get("stacks", 1)
			var status_str: String = merged.get("status", "")
			var status_jp: String = _status_to_jp(status_str)
			for t in tgt:
				var t_row: int = _get_unit_row(t, bm)
				var t_col: int = _get_unit_col(t, bm)
				var t_side: int = _get_unit_side(t, bm)
				if eq != null:
					eq.push(4, source, t, "status_apply", 0.0,
						{"status": status_jp, "stacks": stacks, "side": t_side,
						 "row": t_row, "col": t_col,
						 "src_side": side, "src_row": row, "src_col": col, "skill_name": status_str + "_apply"})

		# ---- ダメージ ----
		"damage":
			var factor: float = merged.get("factor", 1.0)
			var tgt_type: String = merged.get("target", "")
			if tgt_type == "enemy_max_hp" and source != null:
				# 最大HP敵1体にATK×factor
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
				# 隣接行の敵に50%ダメージ（連鎖）
				var t_row: int = context.get("target_row", row)
				var chain_dmg: int = max(1, int(float(damage) / 2.0))
				for adj_row in _get_adjacent_rows(t_row):
					var adj_col: int = bm._get_frontmost_col(enemy_side, adj_row)
					if adj_col != -1 and eq != null:
						var adj_t = bm.board[enemy_side][adj_row][adj_col]
						eq.push(4, source, adj_t, "damage", float(chain_dmg),
							{"enemy_side": enemy_side, "row": adj_row, "col": adj_col})

		# ---- 自ダメージ ----
		"self_damage":
			if source != null:
				var factor: float = merged.get("factor", 0.30)
				var min_hp: int   = merged.get("min_hp", 1)
				var hp_cost: int  = max(min_hp, int(source.max_hp * factor))
				source.current_hp = max(min_hp, source.current_hp - hp_cost)

		# ---- HP回復 ----
		"heal":
			var factor: float = merged.get("factor", 0.15)
			var tgt = _resolve_target(merged, context, true)
			for t in tgt:
				var heal: int = max(1, int(t.max_hp * factor))
				t.current_hp = min(t.max_hp, t.current_hp + heal)

		# ---- ATK永続強化 ----
		"atk_permanent":
			if source != null:
				var amount: int = merged.get("amount", 2)
				var cap: int    = merged.get("cap", 10)
				if source._kill_atk_bonus < cap:
					var prev: int = source._kill_atk_bonus
					source._kill_atk_bonus = min(source._kill_atk_bonus + amount, cap)
					source.attack += source._kill_atk_bonus - prev

		# ---- 召喚 ----
		"summon":
			var unit_id: String = merged.get("unit_id", "スライム")
			var range_type: String = merged.get("range", "same_row")
			var _chain: bool = merged.get("chain", false)  # 将来使用（連鎖召喚制御）
			if range_type == "same_row" and bm != null:
				# 同行の空きマスにスライムを召喚
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

		"shuffle_deck":
			# 捨て札をデッキに統合してからシャッフル（再挿入はdeck_add_selfで別途行う）
			var deck_mgr = dm if side == 0 else ai
			if deck_mgr != null:
				# 捨て札をデッキに戻す
				for card in deck_mgr.discard:
					deck_mgr.deck.append(card)
				deck_mgr.discard.clear()
				deck_mgr.deck.shuffle()

		"summon_low_cost":
			# 急召：低コストユニットを即時召喚
			if side == 0 and dm != null:
				dm.force_play_card(bm)
			elif side == 1 and ai != null:
				ai.force_play_card(bm)

		"summon_on_death":
			# 分裂：死亡時に合成元ユニットを同段に復活（SYNTHESIS定義から自動参照）
			if source != null and bm != null:
				var _CDB = load("res://scripts/CardDB.gd")
				var base_name: String = ""
				for recipe in _CDB.SYNTHESIS:
					if recipe["result"] == source.unit_name:
						base_name = recipe["base"]
						break
				if base_name != "" and _CDB.UNITS.has(base_name):
					var ud = _CDB.UNITS[base_name]
					var UDS = load("res://scripts/UnitData.gd")
					var new_unit = UDS.new()
					new_unit.unit_name = base_name
					new_unit.max_hp = ud["hp"]; new_unit.current_hp = ud["hp"]
					new_unit.attack = ud["atk"]; new_unit.attack_interval = ud["interval"]
					new_unit.cost = ud["cost"]; new_unit.race = ud.get("race", "")
					new_unit.attack_range = ud.get("range", "1行")
					new_unit.skills = ud.get("skills", []).duplicate(true)
					bm._pending_revives.append({"timer": 0.0, "side": side, "row": row, "unit": new_unit, "hp": ud["hp"]})

		# ---- デッキ追加 ----
		"deck_add":
			var unit_id: String = merged.get("unit_id", "self")
			var count: int      = merged.get("count", 1)
			var position: String = merged.get("position", "random")  # "random" | "bottom" | "top"
			if unit_id == "self" and source != null:
				var deck_mgr = dm if side == 0 else ai
				if deck_mgr != null:
					for _i in range(count):
						var card = source.clone()
						card.current_hp = card.max_hp
						var deck_arr: Array = deck_mgr.deck
						match position:
							"bottom":
								deck_arr.append(card)
							"top":
								deck_arr.insert(0, card)
							_:
								var pos: int = randi() % max(1, deck_arr.size() + 1)
								deck_arr.insert(pos, card)

		# ---- ドロー ----
		"draw":
			var count: int = merged.get("count", 2)
			if eq != null:
				eq.push(4, source, null, "draw_cards", float(count),
					{"side": side, "src_side": side, "src_row": row, "src_col": col, "skill_name": "draw_cards"})

		# ---- マナ回復 ----
		"mana_add":
			var amount: float = merged.get("amount", 3)
			if dm != null:
				dm.mana = min(dm.MANA_MAX, dm.mana + amount)
			elif ai != null and side == 1:
				ai.mana = min(ai.MANA_MAX, ai.mana + amount)

		# ---- バフ奪取 ----
		"steal_buffs":
			if source != null and target != null and bm != null:
				var factor: float = merged.get("factor", 1.5)
				bm._steal_buffs(source, target, factor)

		"steal_all_buffs":
			if source != null and bm != null:
				var factor: float = merged.get("factor", 1.5)
				# 最多バフ保持の敵を選んで奪取
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

		# ---- 位置移動 ----
		"move":
			var dest: String = merged.get("dest", "front")
			if dest == "front" and bm != null:
				var front_col: int = 2 if side == 0 else 0
				if col != front_col and bm.board[side][row][front_col] == null:
					bm.board[side][row][front_col] = source
					bm.attack_timers[side][row][front_col] = source.attack_interval
					bm.board[side][row][col] = null
					bm.attack_timers[side][row][col] = 0.0
					bm.on_board_changed()

		# ---- スキルフラグ ----
		"skill_flag":
			if source != null:
				var flags: Dictionary = merged.get("flags", {})
				var tgt_str: String = merged.get("target", "")
				if tgt_str == "same_row" and bm != null:
					# 同行の味方にフラグ付与（リッチのsupport_reviveなど）
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
					# atk_factorパラメータがある場合は_back_atk_factorも設定
					if merged.has("atk_factor"):
						source._back_atk_factor = merged["atk_factor"]

		# ---- マナ妨害 ----
		"mana_drain":
			# process_deck側でcount_units_by_nameで処理するため、ここは何もしない（常時フラグ不要）
			pass

		# ---- デバフ波及 ----
		"debuff_spread":
			# 撃破時に_process_debuff_spreadで処理するため、常時フラグ不要
			pass

		# ---- 異常状態カード注入 ----
		"inject_status":
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

		# ---- コスト軽減 ----
		"cost_reduce":
			var count: int = merged.get("count", 3)
			if dm != null:
				dm._cost_reduction_remaining = count

		# ---- 全体SPDバフ（一時） ----
		"temp_buff_all":
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

		# ---- ステータスブースト ----
		"stat_boost":
			var atk_add: int = merged.get("atk", 0)
			var hp_add: int  = merged.get("hp", 0)
			var tgt_type: String = merged.get("target", "all_allies")
			if tgt_type == "single_ally":
				var tgt = _pick_ally_by_strategy(side, bm, "max_hp")
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

		# ---- デッキから異常状態カード除去 ----
		"deck_remove_status":
			if dm != null:
				for i in range(dm.deck.size()):
					if dm.deck[i].card_type == "status_spell":
						dm.deck.remove_at(i)
						return

		# ---- 前列状態付与（両陣営） ----
		"front_status":
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

		# ---- 前列ダメージ＋状態付与 ----
		"front_damage_status":
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

		# ---- 全敵ダメージ ----
		"all_enemy_damage":
			var dmg: int = merged.get("damage", 8)
			if bm != null and eq != null:
				for r2 in range(3):
					for c2 in range(3):
						var u = bm.board[enemy_side][r2][c2]
						if u != null and u.is_alive():
							eq.push(1, null, u, "damage", float(dmg),
								{"enemy_side": enemy_side, "row": r2, "col": c2})

		# ---- 全敵デバフ ----
		"all_enemy_debuff":
			var status: String = merged.get("status", "burn")
			var stacks: int    = merged.get("stacks", 2)
			if bm != null:
				for r2 in range(3):
					for c2 in range(3):
						var u = bm.board[enemy_side][r2][c2]
						if u != null and u.is_alive():
							match status:
								"burn":     u.burn_turns += stacks
								"freeze":   u.frozen_turns += stacks
								"poison":   u.poison_stacks += stacks
								"paralysis": u.paralysis_turns += stacks

		# ---- 敵ランダム移動 ----
		"move_enemy_random":
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

		# ---- 前後入れ替え ----
		"swap_front_back":
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

		# ---- 前列→後列押し込み ----
		"push_to_back":
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

		# ---- 召喚遅延 ----
		"delay_spawn":
			var seconds: float = merged.get("seconds", 3)
			if side == 0 and ai != null:
				ai._check_timer += seconds
			elif side == 1 and dm != null:
				dm._check_timer += seconds

		# ---- 列ランダム化 ----
		"randomize_col":
			var deck_mgr = ai if side == 0 else dm
			if deck_mgr != null:
				var next_c = deck_mgr.get_next_card()
				if next_c != null:
					next_c.assigned_col = randi() % 3

		# ---- 復活 ----
		"revive":
			if source != null and bm != null and not source._has_revived:
				source._has_revived = true
				var hp_val: int = merged.get("hp", 5)
				var delay: float = merged.get("delay", 3.0)
				bm._pending_revives.append({"timer": delay, "side": side, "row": row, "unit": source, "hp": hp_val})

		# ---- 味方復活 ----
		"revive_ally":
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

		# ---- 結晶化 ----
		"crystallize":
			var tgt = _resolve_target(merged, context, true)
			for t in tgt:
				t._invincible_timer = 999.0

		# ---- クリティカル（フラグ付き） ----
		"critical":
			# クリティカルは_do_attack内で処理するため、ここでは何もしない
			pass

		# ---- 種族バフ（スライム全体強化など） ----
		"race_buff":
			var race_filter: String = merged.get("race", "")
			var atk_pct: float = merged.get("atk_pct", 0.5)
			if bm != null:
				for r2 in range(3):
					for c2 in range(3):
						var u = bm.board[side][r2][c2]
						if u != null and u.is_alive() and u != source:
							if race_filter == "" or u.race == race_filter:
								u._atk_bonus += max(1, int(float(u.attack) * atk_pct))
								print("[EffectExecutor] race_buff: %s ATK+%d" % [u.unit_name, max(1, int(float(u.attack) * atk_pct))])

		# ---- 盤面効果設置 ----
		"tile_set":
			var tile_id: String = merged.get("tile_id", "")
			var scope: String = merged.get("scope", "all")
			var tgt_tile: String = merged.get("target", "")
			if bm != null and tile_id != "":
				var _EDB_tile = load("res://scripts/EffectDB.gd")
				var tile_def = _EDB_tile.EFFECTS.get(tile_id, {})
				var tile_dur: float = tile_def.get("duration", -1.0)
				# target="adjacent_8": 自陣の周囲8マスのみに設置（アーティファクト用）
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

		# ---- プレイヤークラススキル（呼び出し側で処理・ここはpass） ----
		# cost_modifier: DeckManager.process_deck で処理
		"cost_modifier":
			pass
		# spd_pct_buff: SupportSystem._apply_class_skills で処理
		"spd_pct_buff":
			pass
		# conditional_buff: SupportSystem._apply_class_skills で処理
		"conditional_buff":
			pass
		# hp_pct_buff: BoardManager.place_unit で処理
		"hp_pct_buff":
			pass

		# ---- マナ回復倍率変更（永久効果型アーティファクト・DeckManagerで処理） ----
		"mana_regen_modify":
			# DeckManager.process_deck()でplayer_artifactsを走査して計算するため、ここは何もしない
			pass

		# ---- 本体ダメージ軽減（永久効果型アーティファクト・EventQueueで処理） ----
		"base_damage_reduce":
			# EventQueue.base_damage処理でartifact_listを走査して計算するため、ここは何もしない
			pass

		# ---- 空きマスへの召喚（アーティファクト用） ----
		"summon_to_empty":
			var unit_id_se: String = merged.get("unit_id", "ゴブリン")
			if bm != null:
				bm._summon_unit_to_random_empty(side, unit_id_se)

		_:
			print("[EffectExecutor] 未実装type: %s (effect_id: %s)" % [merged.get("type", "?"), effect_id])

# ---- ターゲット解決 ----

func _resolve_target(merged: Dictionary, context: Dictionary, ally_side: bool) -> Array:
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
			var u = _pick_ally_by_strategy(side, bm, "max_hp")
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
			var u = _pick_ally_by_strategy(side, bm, "max_atk")
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
						if u.lifesteal_stacks > 0: cnt += 1
						if u._regen_stacks > 0: cnt += 1
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
	return []

func _pick_ally_by_strategy(side: int, bm: Node, strategy: String) -> Object:
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

func _get_unit_row(unit: Object, bm: Node) -> int:
	if bm == null:
		return 0
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if bm.board[s][r][c] == unit:
					return r
	return 0

func _get_unit_col(unit: Object, bm: Node) -> int:
	if bm == null:
		return 0
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if bm.board[s][r][c] == unit:
					return c
	return 0

func _get_unit_side(unit: Object, bm: Node) -> int:
	if bm == null:
		return 0
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if bm.board[s][r][c] == unit:
					return s
	return 0

func _get_adjacent_rows(row: int) -> Array:
	var rows: Array = []
	if row > 0: rows.append(row - 1)
	if row < 2: rows.append(row + 1)
	return rows

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
	# ai.deck は enemy_deck のエイリアスなので .deck でアクセス可能
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
