# EventQueue.gd
# 優先度付きチェーンイベントキュー
# Main.gd でインスタンス化し board_manager.event_queue に設定して使用
class_name EventQueue
extends Node

const PRIORITY_IMMEDIATE = 1  # ダメージ・回復・HP変動
const PRIORITY_STATUS    = 2  # 状態異常付与・解除・スタック変動
const PRIORITY_SUPPORT   = 3  # サポート効果
const PRIORITY_PASSIVE   = 4  # パッシブスキル
const PRIORITY_ACTIVE    = PRIORITY_PASSIVE  # 後方互換エイリアス
const PRIORITY_ARTIFACT  = 5  # アーティファクト効果
const PRIORITY_BOARD     = 6  # 盤面条件チェック
const PRIORITY_MERGE     = 7  # 合体判定・位置変化

var _queue: Array = []
var _deferred: Array = []
var _deferred_pending: bool = false
var _damaged_ids: Array = []

func push(priority: int, source: Object, target: Object,
		effect_type: String, value: float, extra: Dictionary = {}) -> void:
	var event: Dictionary = {
		"priority":    priority,
		"source":      source,
		"target":      target,
		"effect_type": effect_type,
		"value":       value,
		"extra":       extra,
		"timestamp":   Time.get_ticks_msec() * 0.001,
	}
	if priority >= PRIORITY_BOARD:
		_deferred.append(event)
	else:
		_queue.append(event)

func flush(board_manager: Node, base_hp: Array) -> void:
	_damaged_ids.clear()
	var pass_count: int = 0

	while not _queue.is_empty() and pass_count < 20:
		pass_count += 1
		_queue.sort_custom(func(a, b): return a["priority"] < b["priority"])
		var batch: Array = _queue.duplicate()
		_queue.clear()

		var death_events: Array = []
		var support_applied: bool = false

		for event in batch:
			match event["effect_type"]:

				"damage":
					var tgt = event["target"]
					if tgt == null or not tgt.is_alive():
						continue
					var tid: int = tgt.get_instance_id()
					if tid in _damaged_ids:
						continue
					_damaged_ids.append(tid)
					var dmg_value: int = int(event["value"])
					tgt.take_damage(dmg_value)
					for skill in tgt.skills:
						if skill.get("effect_id", "") == "damage_accumulate":
							tgt._accumulated_damage += dmg_value
							break
					var ex: Dictionary = event["extra"]
					board_manager.unit_damaged.emit(
						ex.get("enemy_side", -1), ex.get("row", -1), ex.get("col", -1), dmg_value
					)
					# on_damaged トリガー発火
					if dmg_value > 0 and board_manager.effect_executor != null:
						for skill_od in tgt.skills:
							if skill_od.get("trigger", "") == "on_damaged":
								var merged_od: Dictionary = skill_od.get("params", {}).duplicate()
								if skill_od.has("target"):
									merged_od["target"] = skill_od["target"]
								var t_side_od: int = ex.get("enemy_side", 0)
								var t_row_od: int = ex.get("row", 0)
								var t_col_od: int = ex.get("col", 0)
								board_manager.effect_executor.execute(skill_od["effect_id"], merged_od, {
									"trigger": "on_damaged", "side": t_side_od, "row": t_row_od, "col": t_col_od,
									"source": event["source"], "target": tgt, "damage": dmg_value,
									"board_manager": board_manager, "deck_manager": board_manager.deck_manager_ref,
									"enemy_ai": board_manager.enemy_ai_ref, "event_queue": self
								})
					if not tgt.is_alive():
						death_events.append({"pos": ex, "killer": event["source"]})

				"poison_damage":
					var tgt = event["target"]
					if tgt == null or not tgt.is_alive():
						continue
					var dmg: int = int(event["value"])
					tgt.take_damage(dmg)
					var ex: Dictionary = event["extra"]
					board_manager.unit_damaged.emit(
						ex.get("enemy_side", -1), ex.get("row", -1), ex.get("col", -1), dmg
					)
					board_manager.status_damage.emit(
						ex.get("unit_name", "?"), "毒", dmg, tgt.poison_stacks
					)
					if not tgt.is_alive():
						death_events.append({"pos": ex, "killer": null})

				"heal":
					var tgt = event["target"]
					if tgt != null and tgt.is_alive():
						tgt.current_hp = min(tgt.max_hp, tgt.current_hp + int(event["value"]))
						var ex: Dictionary = event["extra"]
						if ex.has("skill_name"):
							board_manager.skill_triggered.emit(
								int(ex["src_side"]), int(ex["src_row"]), int(ex["src_col"]),
								ex["skill_name"]
							)
						board_manager.unit_damaged.emit(
							ex.get("src_side", -1), ex.get("src_row", -1), ex.get("src_col", -1), 0
						)

				"base_damage":
					var side: int = event["extra"].get("side", -1)
					if side >= 0:
						var raw_dmg: int = int(event["value"])
						var reduce_pct: float = 0.0
						var artifact_list: Array = board_manager.player_artifacts if side == 0 else board_manager.enemy_artifacts
						var _EDB_ev = load("res://scripts/EffectDB.gd")
						for art_entry in artifact_list:
							if not (art_entry is Dictionary):
								continue
							for sk in art_entry.get("skills", []):
								var _eid_ev: String = sk.get("effect_id", "")
								var _edef_ev: Dictionary = _EDB_ev.EFFECTS.get(_eid_ev, {})
								if _edef_ev.get("type", "") == "base_damage_reduce":
									reduce_pct += sk.get("params", {}).get("pct", _edef_ev.get("pct", 0.1))
						var actual_dmg: int = max(0, int(float(raw_dmg) * (1.0 - reduce_pct)))
						base_hp[side] = max(0, base_hp[side] - actual_dmg)
						board_manager.base_damaged.emit(side, actual_dmg)

				"status_apply":
					var tgt = event["target"]
					if tgt == null or not tgt.is_alive():
						continue
					var ex: Dictionary = event["extra"]
					var status: String = ex.get("status", "")
					var stacks: int = 0
					match status:
						"火傷":
							tgt.burn_turns += ex.get("stacks", 2)
							stacks = tgt.burn_turns
						"毒":
							tgt.poison_stacks += ex.get("stacks", 1)
							stacks = tgt.poison_stacks
						"凍結":
							tgt.frozen_turns += ex.get("stacks", 2)
							stacks = tgt.frozen_turns
						"麻痺":
							pass
					if stacks > 0:
						board_manager.status_applied.emit(tgt.unit_name, status, stacks)
						if ex.has("skill_name"):
							board_manager.skill_triggered.emit(
								int(ex["src_side"]), int(ex["src_row"]), int(ex["src_col"]),
								ex["skill_name"]
							)

				"status_clear":
					var ex: Dictionary = event["extra"]
					board_manager.status_cleared.emit(
						ex.get("unit_name", "?"), ex.get("status", "")
					)

				"extra_summon":
					var src = event["source"]
					var ex: Dictionary = event["extra"]
					var s: int = ex.get("side", -1)
					var sr: int = ex.get("row", -1)
					var sc: int = ex.get("col", -1)
					if src == null or s < 0:
						continue
					var adj: Array = []
					for c2 in range(3):
						if c2 != sc and board_manager.board[s][sr][c2] == null:
							adj.append([sr, c2])
					if not adj.is_empty():
						adj.shuffle()
						var pos = adj[0]
						var clone = src.clone()
						clone.passive_skill = ""
						board_manager.board[s][pos[0]][pos[1]] = clone
						board_manager.attack_timers[s][pos[0]][pos[1]] = clone.get_attack_interval()
						board_manager.emit_signal("unit_placed", s, pos[0], pos[1], clone)
						board_manager.on_board_changed()
					board_manager.skill_triggered.emit(s, sr, sc, "追加召喚")

				"draw_cards":
					var ex: Dictionary = event["extra"]
					var s: int = ex.get("side", -1)
					var count: int = int(event["value"])
					if s >= 0 and count > 0:
						board_manager.draw_cards_requested.emit(s, count)
					if ex.has("skill_name"):
						board_manager.skill_triggered.emit(
							ex.get("src_side", -1), ex.get("src_row", -1),
							ex.get("src_col", -1), ex["skill_name"])

				"force_move_front":
					var ex: Dictionary = event["extra"]
					var s: int = ex.get("side", -1)
					var sr: int = ex.get("row", -1)
					var sc: int = ex.get("col", -1)
					var front: int = 2 if s == 0 else 0
					if sc == front:
						continue
					var unit = board_manager.board[s][sr][sc] if s >= 0 else null
					if unit == null:
						continue
					if board_manager.board[s][sr][front] != null:
						continue
					board_manager.board[s][sr][front] = unit
					board_manager.attack_timers[s][sr][front] = unit.get_attack_interval()
					board_manager.board[s][sr][sc] = null
					board_manager.attack_timers[s][sr][sc] = 0.0
					board_manager.on_board_changed()
					if ex.has("skill_name"):
						board_manager.skill_triggered.emit(s, sr, front, ex["skill_name"])

				"support_apply":
					if not support_applied:
						support_applied = true
						board_manager._apply_support_effects()

				"promote_check":
					var ex: Dictionary = event["extra"]
					board_manager._try_promote(
						ex.get("side", -1), ex.get("row", -1), ex.get("col", -1)
					)

		# 死亡後処理
		for death in death_events:
			var pos: Dictionary = death["pos"]
			var s: int = pos.get("enemy_side", -1)
			var r: int = pos.get("row", -1)
			var c: int = pos.get("col", -1)
			if s >= 0 and r >= 0 and c >= 0:
				var victim = board_manager.board[s][r][c]
				board_manager.remove_unit(s, r, c)
				# 素材ドロップ処理（敵側ユニットのみ）
				if s == 1 and victim != null:
					_drop_materials_from_unit(victim, s, r, c, board_manager)
				if board_manager.effect_executor != null:
					for r2 in range(3):
						for c2 in range(3):
							var ally = board_manager.board[s][r2][c2]
							if ally != null and ally.is_alive():
								for skill in ally.skills:
									if skill.get("trigger", "") == "on_ally_death":
										var _mp_ad: Dictionary = skill.get("params", {}).duplicate()
										if skill.has("target"): _mp_ad["target"] = skill["target"]
										board_manager.effect_executor.execute(skill["effect_id"], _mp_ad, {
											"trigger": "on_ally_death", "side": s, "row": r2, "col": c2,
											"source": ally, "target": null, "damage": 0,
											"board_manager": board_manager, "deck_manager": board_manager.deck_manager_ref,
											"enemy_ai": board_manager.enemy_ai_ref, "event_queue": self
										})
				var killer = death.get("killer")
				if killer != null and killer.is_alive():
					board_manager._process_on_kill(killer)
					var has_debuff_spread: bool = false
					for skill in killer.skills:
						if skill.get("effect_id", "") == "debuff_spread":
							has_debuff_spread = true
							break
					if victim != null and has_debuff_spread:
						board_manager._process_debuff_spread(killer, victim, s, r, c)

	# 遅延キュー（priority 6–7）
	if _deferred_pending:
		_deferred_pending = false
		for event in _deferred:
			if event["effect_type"] == "promote_check":
				var ex: Dictionary = event["extra"]
				board_manager._try_promote(
					ex.get("side", -1), ex.get("row", -1), ex.get("col", -1)
				)
		_deferred.clear()
	elif not _deferred.is_empty():
		_deferred_pending = true

	_damaged_ids.clear()

func _drop_materials_from_unit(unit: Object, side: int, row: int, col: int, board_manager: Node) -> void:
	"""敵ユニット死亡時の素材自動取得（全量・選択不要）"""
	# 素材テーブル参照（別設計書 drop_table_system.md で定義）
	# 当面はスタブ: ユニット名から素材ID推定（暫定実装）
	var material_id: String = _resolve_material_id(unit)
	if material_id == "":
		return  # 素材定義なし
	var count: int = 1  # 暫定: 全敵から1個。テーブル定義時に拡張
	GameSession.materials[material_id] = GameSession.materials.get(material_id, 0) + count
	board_manager.material_dropped.emit(material_id, count, side, row, col)
	print("[Drop] 素材獲得: %s x%d (累計:%d)" % [material_id, count, GameSession.materials[material_id]])
	# 通貨ドロップ
	var gold_amount: int = _resolve_gold_drop(unit)
	if gold_amount > 0:
		GameSession.current_battle_gold += gold_amount
		board_manager.gold_dropped.emit(gold_amount, side, row, col)
		print("[Drop] ゴールド獲得: %d (累計:%d)" % [gold_amount, GameSession.current_battle_gold])

func _resolve_material_id(unit: Object) -> String:
	"""ユニットから素材IDを解決（種族ベースマッピング）"""
	if unit == null:
		return ""
	match unit.race:
		"スライム":
			return "slime_core"
		"獣":
			return "beast_fang"
		"アンデッド":
			return "old_bone"
		_:
			return "magic_stone"

func _resolve_gold_drop(unit: Object) -> int:
	"""ユニットのgold_dropをcards.jsonから解決（レアリティ別デフォルト付き）"""
	if unit == null:
		return 0
	var cards_res = load("res://data/cards.json")
	if cards_res == null:
		return 2
	var unit_data: Dictionary = cards_res.data.get("units", {}).get(unit.unit_name, {})
	return unit_data.get("gold_drop", 2)
