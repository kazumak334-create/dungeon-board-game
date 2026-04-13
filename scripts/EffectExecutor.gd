# EffectExecutor.gd
# 効果実行エンジン（エントリポイント）
# context構造: {trigger, side, row, col, source, target, damage, board_manager, deck_manager, enemy_ai, event_queue}
# class_name を使わない（Main.gdからpreload()で参照）
extends RefCounted

var _EffectDB = null   # EffectDB スクリプト参照（循環参照回避）
var _actions = null    # EffectActions インスタンス
var _targets = null    # EffectTargets インスタンス

func _init() -> void:
	_EffectDB = load("res://scripts/EffectDB.gd")
	_targets = load("res://scripts/EffectTargets.gd").new()
	_actions = load("res://scripts/EffectActions.gd").new()
	_actions.targets = _targets
	_actions._EffectDB = _EffectDB

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

	# ctx_vars: EffectActionsの各関数に渡す共通引数Dictionary
	var ctx: Dictionary = {
		"bm": bm, "dm": dm, "ai": ai, "eq": eq,
		"side": side, "row": row, "col": col,
		"source": source, "target": target,
		"damage": damage, "enemy_side": enemy_side,
		"target_row": context.get("target_row", row)
	}

	match merged["type"]:
		"buff_apply":              _actions.do_buff_apply(merged, ctx)
		"buff_apply_chance":       _actions.do_buff_apply_chance(merged, ctx)
		"debuff_apply":            _actions.do_debuff_apply(merged, ctx)
		"damage":                  _actions.do_damage(merged, ctx)
		"self_damage":             _actions.do_self_damage(merged, ctx)
		"heal":                    _actions.do_heal(merged, ctx)
		"atk_permanent":           _actions.do_atk_permanent(merged, ctx)
		"summon":                  _actions.do_summon(merged, ctx)
		"shuffle_deck":            _actions.do_shuffle_deck(merged, ctx)
		"summon_low_cost":         _actions.do_summon_low_cost(merged, ctx)
		"summon_on_death":         _actions.do_summon_on_death(merged, ctx)
		"deck_add":                _actions.do_deck_add(merged, ctx)
		"draw":                    _actions.do_draw(merged, ctx)
		"mana_add":                _actions.do_mana_add(merged, ctx)
		"steal_buffs":             _actions.do_steal_buffs(merged, ctx)
		"steal_all_buffs":         _actions.do_steal_all_buffs(merged, ctx)
		"move":                    _actions.do_move(merged, ctx)
		"skill_flag":              _actions.do_skill_flag(merged, ctx)
		"inject_status":           _actions.do_inject_status(merged, ctx)
		"cost_reduce":             _actions.do_cost_reduce(merged, ctx)
		"temp_buff_all":           _actions.do_temp_buff_all(merged, ctx)
		"stat_boost":              _actions.do_stat_boost(merged, ctx)
		"deck_remove_status":      _actions.do_deck_remove_status(merged, ctx)
		"front_status":            _actions.do_front_status(merged, ctx)
		"front_damage_status":     _actions.do_front_damage_status(merged, ctx)
		"all_enemy_damage":        _actions.do_all_enemy_damage(merged, ctx)
		"all_enemy_debuff":        _actions.do_all_enemy_debuff(merged, ctx)
		"move_enemy_random":       _actions.do_move_enemy_random(merged, ctx)
		"swap_front_back":         _actions.do_swap_front_back(merged, ctx)
		"push_to_back":            _actions.do_push_to_back(merged, ctx)
		"delay_spawn":             _actions.do_delay_spawn(merged, ctx)
		"randomize_col":           _actions.do_randomize_col(merged, ctx)
		"revive":                  _actions.do_revive(merged, ctx)
		"revive_ally":             _actions.do_revive_ally(merged, ctx)
		"crystallize":             _actions.do_crystallize(merged, ctx)
		"race_buff":               _actions.do_race_buff(merged, ctx)
		"tile_set":                _actions.do_tile_set(merged, ctx)
		"summon_to_empty":         _actions.do_summon_to_empty(merged, ctx)
		# ---- 呼び出し側で処理するためここはpass ----
		"critical":         pass  # _do_attack内で処理
		"mana_drain":       pass  # DeckManager.process_deckで処理
		"debuff_spread":    pass  # _process_debuff_spreadで処理
		"cost_modifier":    pass  # DeckManager.process_deckで処理
		"spd_pct_buff":     pass  # SupportSystem._apply_class_skillsで処理
		"conditional_buff": pass  # SupportSystem._apply_class_skillsで処理
		"hp_pct_buff":      pass  # BoardManager.place_unitで処理
		"base_damage_reduce": pass  # EventQueue.base_damage処理で処理
		_:
			print("[EffectExecutor] 未実装type: %s (effect_id: %s)" % [merged.get("type", "?"), effect_id])
