# TileSystem.gd
# 盤面効果の管理・処理
extends RefCounted

var board_manager: Node = null  # BoardManagerへの参照

func setup(bm: Node) -> void:
	board_manager = bm

func _is_protected_by_artifact(side: int, row: int, col: int) -> bool:
	# 周囲8マス＋自マスにprotect_tiles=trueのアーティファクトがあるか確認
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var r2: int = row + dr
			var c2: int = col + dc
			if r2 < 0 or r2 >= 3 or c2 < 0 or c2 >= 3:
				continue
			var art = board_manager.board_artifacts[side][r2][c2]
			if art != null and art.get("protect_tiles", false):
				return true
	return false

func set_tile_effect(side: int, row: int, col: int, effect_id: String, duration: float = -1.0) -> void:
	var _EDB = load("res://scripts/EffectDB.gd")
	if not _EDB.EFFECTS.has(effect_id):
		return
	# protect_tilesチェック: 隣接アーティファクトがprotect_tiles=trueならブロック
	if _is_protected_by_artifact(side, row, col):
		print("[TileSystem] protect_tilesにより盤面効果設置ブロック: %s side=%d row=%d col=%d" % [effect_id, side, row, col])
		return
	var def = _EDB.EFFECTS[effect_id]
	board_manager.board_effects[side][row][col] = {
		"effect_id": effect_id,
		"remaining": duration,
		"tick_timer": 0.0,
		"tick_interval": def.get("tick_interval", 1.0),
	}
	print("[TileSystem] 盤面効果設置: %s side=%d row=%d col=%d remaining=%s" % [effect_id, side, row, col, str(duration)])

func clear_tile_effect(side: int, row: int, col: int) -> void:
	board_manager.board_effects[side][row][col] = null

func check_tile_on_enter(side: int, row: int, col: int, unit: Object) -> void:
	var te = board_manager.board_effects[side][row][col]
	if te == null:
		return
	if unit.get("_is_flying") == true:
		return
	var _EDB = load("res://scripts/EffectDB.gd")
	var def = _EDB.EFFECTS.get(te["effect_id"], {})
	# 鉄壁の地: 鎧付与
	if def.get("armor_stacks", 0) > 0:
		unit._damage_reduction += def["armor_stacks"]
		print("[TileSystem] 鉄壁の地: 鎧+%d → %s" % [def["armor_stacks"], unit.unit_name])
	# 棘: 配置/復活時にダメージ
	if def.has("damage") and def.get("trigger", "") == "on_enter":
		var dmg: int = def["damage"]
		unit.take_damage(dmg)
		print("[TileSystem] 棘ダメージ: %s -%d" % [unit.unit_name, dmg])

func check_tile_on_leave(side: int, row: int, col: int, unit: Object) -> void:
	var te = board_manager.board_effects[side][row][col]
	if te == null:
		return
	if unit.get("_is_flying") == true:
		return
	var _EDB = load("res://scripts/EffectDB.gd")
	var def = _EDB.EFFECTS.get(te["effect_id"], {})
	# ヒビ→穴に変形
	if def.has("transform_to"):
		var next_id: String = def["transform_to"]
		var next_def = _EDB.EFFECTS.get(next_id, {})
		var duration: float = next_def.get("duration", 5.0)
		set_tile_effect(side, row, col, next_id, duration)
		print("[TileSystem] ヒビ→穴に変形: side=%d row=%d col=%d" % [side, row, col])

func process_tile_effects() -> void:
	var _EDB = load("res://scripts/EffectDB.gd")
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var te = board_manager.board_effects[s][r][c]
				if te == null:
					continue
				# 持続時間の管理
				if te["remaining"] > 0:
					te["remaining"] -= 1.0
					if te["remaining"] <= 0:
						board_manager.board_effects[s][r][c] = null
						continue
				var def = _EDB.EFFECTS.get(te["effect_id"], {})
				var trigger = def.get("trigger", "")
				var unit = board_manager.board[s][r][c]
				# 飛行ユニットは盤面効果を無視
				if unit != null and unit.get("_is_flying") == true:
					continue
				# on_tick: N秒ごとに発動
				if trigger == "on_tick":
					te["tick_timer"] -= 1.0
					if te["tick_timer"] <= 0:
						te["tick_timer"] = te["tick_interval"]
						# 墓地: ランダム空きマスにユニット召喚（summon_unitフィールドから取得）
						if def.has("summon_unit"):
							var sum_unit_id: String = def["summon_unit"]
							board_manager._summon_unit_to_random_empty(s, sum_unit_id)
						if unit != null and unit.is_alive():
							# 炎床: ダメージ
							if def.has("damage"):
								board_manager.event_queue.push(1, null, unit, "damage",  # 1 = EventQueue.PRIORITY_IMMEDIATE
									float(def["damage"]), {"enemy_side": s, "row": r, "col": c})
							# 毒沼: 毒スタック付与
							if def.has("status") and def["status"] == "poison":
								unit.poison_stacks += def.get("stacks", 1)
