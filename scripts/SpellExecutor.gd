# SpellExecutor.gd
# 呪文効果の実行ロジック
class_name SpellExecutor
extends RefCounted

# 呪文を実行する。戻り値: true=捨て札へ, false=消滅
func execute(spell: Object, side: int, board_manager: Node,
		deck_manager: Node, enemy_ai: Node) -> bool:
	var enemy_side: int = 1 - side
	var event_queue: Node = board_manager.event_queue

	match spell.spell_id:
		# ---- 自己強化系 ----
		"召喚加速":
			deck_manager.mana = min(deck_manager.MANA_MAX, deck_manager.mana + 3.0)

		"血の契約":
			var target = _pick_ally_by(side, board_manager, "max_atk")
			if target != null:
				target._has_lifesteal = true

		"戦場の鼓動":
			for u in _get_all_units(side, board_manager):
				u._temp_spd_bonus = u.attack_interval * 0.5
				u._temp_spd_timer = 5.0

		"急召":
			if side == 0:
				deck_manager.force_play_card(board_manager)
			else:
				enemy_ai.force_play_card(board_manager)

		"連鎖の触媒":
			deck_manager._cost_reduction_remaining = 3

		"強化の儀式":
			var target = _pick_ally_by(side, board_manager, "max_hp")
			if target != null:
				target.attack += 5
				target.max_hp += 10
				target.current_hp += 10

		"盤面強化":
			for u in _get_all_units(side, board_manager):
				u.max_hp += 10
				u.current_hp += 10
				u.attack += 2

		"圧縮の書":
			_remove_status_card(deck_manager)

		"再召喚":
			_execute_resummon(side, spell, board_manager, deck_manager)

		"先読みの書":
			if side == 0:
				for i in range(2):
					deck_manager.force_play_card(board_manager)
			else:
				for i in range(2):
					enemy_ai.force_play_card(board_manager)

		"召喚の呼び声":
			_move_lowest_cost_to_front(deck_manager)

		"怒涛の展開":
			if side == 0:
				for i in range(3):
					deck_manager.force_play_card(board_manager)
			else:
				for i in range(3):
					enemy_ai.force_play_card(board_manager)

		"生命の雫":
			var target = _pick_ally_by(side, board_manager, "min_hp_ratio")
			if target != null:
				var heal: int = max(1, target.max_hp * 15 / 100)
				target.current_hp = min(target.max_hp, target.current_hp + heal)

		# ---- 相手弱体・環境操作系 ----
		"泥の鎧":
			var target = _pick_ally_by(side, board_manager, "random")
			if target != null:
				target._damage_reduction += 1

		"結晶化":
			var target = _pick_ally_by(side, board_manager, "random")
			if target != null:
				target._invincible_timer = 999.0  # 呪文1回分の無敵（呪文ヒット時に解除）

		"毒霧":
			var col: int = randi() % 3
			for r in range(3):
				var target = board_manager.board[enemy_side][r][col]
				if target != null and target.is_alive():
					event_queue.push(EventQueue.PRIORITY_ACTIVE, null, target, "status_apply", 0.0,
						{"status": "毒", "stacks": 5, "side": enemy_side, "row": r, "col": col,
						 "src_side": side, "src_row": -1, "src_col": -1, "skill_name": "毒霧"})
			_inject_status_card(deck_manager, "毒カード")

		"寒波":
			_apply_front_status(side, board_manager, event_queue, "凍結", 2)
			_inject_status_card(deck_manager, "凍結カード")
			_inject_status_card(_get_opponent_deck(side, deck_manager, enemy_ai), "凍結カード")

		"山火事":
			_apply_front_status(side, board_manager, event_queue, "火傷", 2)
			_inject_status_card(deck_manager, "火傷カード")
			_inject_status_card(_get_opponent_deck(side, deck_manager, enemy_ai), "火傷カード")

		"落雷":
			_apply_front_damage_and_status(side, board_manager, event_queue, 10, "麻痺", 2)
			_inject_status_card(deck_manager, "麻痺カード")
			_inject_status_card(_get_opponent_deck(side, deck_manager, enemy_ai), "麻痺カード")

		"烈風斬":
			for u_info in _get_all_units_with_pos(enemy_side, board_manager):
				event_queue.push(EventQueue.PRIORITY_IMMEDIATE, null, u_info["unit"], "damage", 8.0,
					{"enemy_side": enemy_side, "row": u_info["row"], "col": u_info["col"]})

		"弱体の呪詛":
			for u in _get_all_units(enemy_side, board_manager):
				u.burn_turns += 3

		"盤面凍結":
			for u in _get_all_units(enemy_side, board_manager):
				u.frozen_turns += 8

		# ---- 位置変化系 ----
		"混沌の手":
			_move_random_enemy(enemy_side, board_manager)

		"反転の波":
			_swap_front_back(enemy_side, board_manager)

		"押し込み":
			_push_front_to_back(enemy_side, board_manager)

		# ---- キュー干渉系 ----
		"召喚妨害":
			if side == 0:
				enemy_ai._check_timer += 3.0
			else:
				deck_manager._check_timer += 3.0

		"配置崩し":
			var opponent = enemy_ai if side == 0 else deck_manager
			var next = opponent.get_next_card()
			if next != null:
				next.assigned_col = randi() % 3

		"魔力断絶":
			pass  # 将来実装：マナ回復速度低下

		"残響の波":
			pass  # 将来実装：直前呪文再発動

		# ---- 異常状態カード ----
		"毒カード":
			_apply_self_status(side, board_manager, event_queue, "毒", 2)
		"凍結カード":
			_apply_self_status(side, board_manager, event_queue, "凍結", 2)
		"火傷カード":
			_apply_self_status(side, board_manager, event_queue, "火傷", 2)
		"麻痺カード":
			_apply_self_status(side, board_manager, event_queue, "麻痺", 2)

	board_manager.spell_cast.emit(side, spell.spell_id)
	return not spell.is_consumable  # true=捨て札, false=消滅

# ---- ヘルパー ----

func _get_all_units(side: int, bm: Node) -> Array:
	var units: Array = []
	for r in range(3):
		for c in range(3):
			var u = bm.board[side][r][c]
			if u != null and u.is_alive():
				units.append(u)
	return units

func _get_all_units_with_pos(side: int, bm: Node) -> Array:
	var result: Array = []
	for r in range(3):
		for c in range(3):
			var u = bm.board[side][r][c]
			if u != null and u.is_alive():
				result.append({"unit": u, "row": r, "col": c})
	return result

func _pick_ally_by(side: int, bm: Node, strategy: String) -> Object:
	var units: Array = _get_all_units(side, bm)
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

func _apply_front_status(side: int, bm: Node, eq: Node, status: String, stacks: int) -> void:
	for s in range(2):
		var front: int = 2 if s == 0 else 0
		for r in range(3):
			var u = bm.board[s][r][front]
			if u != null and u.is_alive():
				eq.push(EventQueue.PRIORITY_ACTIVE, null, u, "status_apply", 0.0,
					{"status": status, "stacks": stacks, "side": s, "row": r, "col": front,
					 "src_side": side, "src_row": -1, "src_col": -1, "skill_name": status})

func _apply_front_damage_and_status(side: int, bm: Node, eq: Node, dmg: int, status: String, stacks: int) -> void:
	for s in range(2):
		var front: int = 2 if s == 0 else 0
		for r in range(3):
			var u = bm.board[s][r][front]
			if u != null and u.is_alive():
				eq.push(EventQueue.PRIORITY_IMMEDIATE, null, u, "damage", float(dmg),
					{"enemy_side": s, "row": r, "col": front})
				eq.push(EventQueue.PRIORITY_ACTIVE, null, u, "status_apply", 0.0,
					{"status": status, "stacks": stacks, "side": s, "row": r, "col": front,
					 "src_side": side, "src_row": -1, "src_col": -1, "skill_name": status})

func _apply_self_status(side: int, bm: Node, eq: Node, status: String, stacks: int) -> void:
	var units = _get_all_units_with_pos(side, bm)
	if units.is_empty():
		return
	var pick = units[randi() % units.size()]
	eq.push(EventQueue.PRIORITY_ACTIVE, null, pick["unit"], "status_apply", 0.0,
		{"status": status, "stacks": stacks, "side": side, "row": pick["row"], "col": pick["col"],
		 "src_side": side, "src_row": -1, "src_col": -1, "skill_name": status + "カード"})

func _inject_status_card(deck_mgr: Node, card_name: String) -> void:
	var UnitDataScript = load("res://scripts/UnitData.gd")
	var card = UnitDataScript.new()
	card.unit_name = card_name
	card.card_type = "status_spell"
	card.spell_id = card_name
	card.cost = 0
	card.is_consumable = true
	card.spell_target = "single_ally"
	match card_name:
		"毒カード":   card.spell_effect = "味方ランダム1体に毒2付与"
		"凍結カード": card.spell_effect = "味方ランダム1体に凍結2付与"
		"火傷カード": card.spell_effect = "味方ランダム1体に火傷2付与"
		"麻痺カード": card.spell_effect = "味方ランダム1体に麻痺2付与"
	var pos: int = randi() % max(1, deck_mgr.deck.size() + 1)
	deck_mgr.deck.insert(pos, card)

func _get_opponent_deck(side: int, deck_mgr: Node, enemy_ai: Node) -> Node:
	return enemy_ai if side == 0 else deck_mgr

func _remove_status_card(deck_mgr: Node) -> void:
	for i in range(deck_mgr.deck.size()):
		if deck_mgr.deck[i].card_type == "status_spell":
			deck_mgr.deck.remove_at(i)
			return

func _execute_resummon(side: int, spell: Object, bm: Node, deck_mgr: Node) -> void:
	var x_cost: int = spell.cost  # process_deck側でマナ全額をcostに設定済み
	for i in range(deck_mgr.discard.size()):
		var card = deck_mgr.discard[i]
		if card.card_type == "unit" and card.cost == x_cost:
			deck_mgr.discard.remove_at(i)
			bm.place_unit(side, card)
			return

func _move_lowest_cost_to_front(deck_mgr: Node) -> void:
	var best_idx: int = -1
	var best_cost: int = 999
	for i in range(deck_mgr.deck.size()):
		if deck_mgr.deck[i].card_type == "unit" and deck_mgr.deck[i].cost < best_cost:
			best_cost = deck_mgr.deck[i].cost
			best_idx = i
	if best_idx > 0:
		var card = deck_mgr.deck[best_idx]
		deck_mgr.deck.remove_at(best_idx)
		deck_mgr.deck.insert(0, card)

func _move_random_enemy(enemy_side: int, bm: Node) -> void:
	var units = _get_all_units_with_pos(enemy_side, bm)
	if units.is_empty():
		return
	var pick = units[randi() % units.size()]
	var new_row: int = randi() % 3
	if new_row == pick["row"]:
		return
	if bm.board[enemy_side][new_row][pick["col"]] != null:
		return
	bm.board[enemy_side][new_row][pick["col"]] = pick["unit"]
	bm.attack_timers[enemy_side][new_row][pick["col"]] = pick["unit"].attack_interval
	bm.board[enemy_side][pick["row"]][pick["col"]] = null
	bm.attack_timers[enemy_side][pick["row"]][pick["col"]] = 0.0
	bm.on_board_changed()

func _swap_front_back(enemy_side: int, bm: Node) -> void:
	var front: int = 0 if enemy_side == 1 else 2
	var back: int = 2 if enemy_side == 1 else 0
	for r in range(3):
		var f_unit = bm.board[enemy_side][r][front]
		var b_unit = bm.board[enemy_side][r][back]
		bm.board[enemy_side][r][front] = b_unit
		bm.board[enemy_side][r][back] = f_unit
		var f_timer = bm.attack_timers[enemy_side][r][front]
		bm.attack_timers[enemy_side][r][front] = bm.attack_timers[enemy_side][r][back]
		bm.attack_timers[enemy_side][r][back] = f_timer
	bm.on_board_changed()

func _push_front_to_back(enemy_side: int, bm: Node) -> void:
	var front: int = 0 if enemy_side == 1 else 2
	var back: int = 2 if enemy_side == 1 else 0
	for r in range(3):
		var u = bm.board[enemy_side][r][front]
		if u != null and bm.board[enemy_side][r][back] == null:
			bm.board[enemy_side][r][back] = u
			bm.attack_timers[enemy_side][r][back] = u.attack_interval
			bm.board[enemy_side][r][front] = null
			bm.attack_timers[enemy_side][r][front] = 0.0
			bm.on_board_changed()
			return
