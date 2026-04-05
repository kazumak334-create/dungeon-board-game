# EventQueue.gd
# 優先度付きチェーンイベントキュー
# Main.gd でインスタンス化し board_manager.event_queue に設定して使用
class_name EventQueue
extends Node

const PRIORITY_IMMEDIATE = 1  # ダメージ・回復・HP変動
const PRIORITY_STATUS    = 2  # 状態異常付与・解除・スタック変動
const PRIORITY_SUPPORT   = 3  # サポート効果
const PRIORITY_ACTIVE    = 4  # アクティブスキル
const PRIORITY_ARTIFACT  = 5  # アーティファクト効果
const PRIORITY_BOARD     = 6  # 盤面条件チェック
const PRIORITY_MERGE     = 7  # 合体判定・位置変化

# イベント構造:
# {
#   priority:    int,
#   source:      Object,     # 発生源ユニット（null 可）
#   target:      Object,     # 対象ユニット（null 可）
#   effect_type: String,     # "damage" / "poison_damage" / "heal" / "base_damage" /
#                            # "status_apply" / "status_clear" / "support_apply" / "promote_check" /
#                            # "extra_summon" / "draw_cards" / "force_move_front"
#   value:       float,
#   extra:       Dictionary, # 追加情報（位置など）
#   timestamp:   float,
# }

var _queue: Array = []         # 即時処理（priority 1–5）
var _deferred: Array = []      # 遅延処理（priority 6–7）
var _deferred_pending: bool = false  # true = 次フレームで _deferred を処理

# ループ防止：同フラッシュ内に "damage" を受けたユニットのインスタンスIDセット
var _damaged_ids: Array = []

# ---------------------------------------------------------------------------
# イベント登録
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# フラッシュ：フレーム末尾に BoardManager から呼ぶ
# ---------------------------------------------------------------------------

func flush(board_manager: Node, base_hp: Array) -> void:
	var pass_count: int = 0

	# チェーン処理：キューが空になるまで最大 20 パス
	while not _queue.is_empty() and pass_count < 20:
		pass_count += 1
		# 優先度順ソート（同優先度は積まれた順を保持）
		_queue.sort_custom(func(a, b): return a["priority"] < b["priority"])
		var batch: Array = _queue.duplicate()
		_queue.clear()

		var death_events: Array = []
		var support_applied: bool = false  # 同パス内の重複 _apply_support_effects 防止

		for event in batch:
			match event["effect_type"]:

				"damage":
					var tgt = event["target"]
					if tgt == null or not tgt.is_alive():
						continue
					# 無敵中はダメージ無効
					if tgt._invincible_timer > 0.0:
						continue
					# ループ防止：同フラッシュ内に既に damage を受けたユニットはスキップ
					var tid: int = tgt.get_instance_id()
					if tid in _damaged_ids:
						continue
					_damaged_ids.append(tid)
					tgt.take_damage(int(event["value"]))
					var ex: Dictionary = event["extra"]
					board_manager.unit_damaged.emit(
						ex.get("enemy_side", -1), ex.get("row", -1), ex.get("col", -1)
					)
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
						ex.get("enemy_side", -1), ex.get("row", -1), ex.get("col", -1)
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
							board_manager.active_skill_used.emit(
								int(ex["src_side"]), int(ex["src_row"]), int(ex["src_col"]),
								ex["skill_name"]
							)
						# ヒール元セルをダーティに（スキル・回復どちらも）
						board_manager.unit_damaged.emit(
							ex.get("src_side", -1), ex.get("src_row", -1), ex.get("src_col", -1)
						)

				"base_damage":
					var side: int = event["extra"].get("side", -1)
					if side >= 0:
						var raw_dmg: int = int(event["value"])
						# 永久効果型アーティファクト: base_damage_reduce反映
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
							tgt.paralysis_turns = min(3, tgt.paralysis_turns + ex.get("stacks", 1))
							stacks = tgt.paralysis_turns
					if stacks > 0:
						board_manager.status_applied.emit(tgt.unit_name, status, stacks)
						if ex.has("skill_name"):
							board_manager.active_skill_used.emit(
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
					# 同列（同じ行）の空きマスを探す
					var adj: Array = []
					for c2 in range(3):
						if c2 != sc and board_manager.board[s][sr][c2] == null:
							adj.append([sr, c2])
					if not adj.is_empty():
						adj.shuffle()
						var pos = adj[0]
						var clone = src.clone()
						clone.active_skill = ""  # 追加召喚の連鎖防止
						board_manager.board[s][pos[0]][pos[1]] = clone
						board_manager.attack_timers[s][pos[0]][pos[1]] = clone.attack_interval
						board_manager.emit_signal("unit_placed", s, pos[0], pos[1], clone)
						board_manager.on_board_changed()
					board_manager.active_skill_used.emit(s, sr, sc, "追加召喚")

				"draw_cards":
					var ex: Dictionary = event["extra"]
					var s: int = ex.get("side", -1)
					var count: int = int(event["value"])
					if s >= 0 and count > 0:
						board_manager.draw_cards_requested.emit(s, count)
					if ex.has("skill_name"):
						board_manager.active_skill_used.emit(
							ex.get("src_side", -1), ex.get("src_row", -1),
							ex.get("src_col", -1), ex["skill_name"])

				"force_move_front":
					var ex: Dictionary = event["extra"]
					var s: int = ex.get("side", -1)
					var sr: int = ex.get("row", -1)
					var sc: int = ex.get("col", -1)
					var front: int = 2 if s == 0 else 0
					if sc == front:
						continue  # 既に前列
					var unit = board_manager.board[s][sr][sc] if s >= 0 else null
					if unit == null:
						continue
					if board_manager.board[s][sr][front] != null:
						continue  # 前列が埋まっている
					board_manager.board[s][sr][front] = unit
					board_manager.attack_timers[s][sr][front] = unit.attack_interval
					board_manager.board[s][sr][sc] = null
					board_manager.attack_timers[s][sr][sc] = 0.0
					board_manager.on_board_changed()
					if ex.has("skill_name"):
						board_manager.active_skill_used.emit(s, sr, front, ex["skill_name"])

				"support_apply":
					# 同パス内で1回のみ実行（複数 board_change が重なる場合に重複防止）
					if not support_applied:
						support_applied = true
						board_manager._apply_support_effects()

		# 死亡後処理（while ループ内で実行：remove_unit がさらにイベントを push する場合に対応）
		for death in death_events:
			var pos: Dictionary = death["pos"]
			var s: int = pos.get("enemy_side", -1)
			var r: int = pos.get("row", -1)
			var c: int = pos.get("col", -1)
			if s >= 0 and r >= 0 and c >= 0:
				# 死亡ユニットのデバフ情報を保存（デバフ波及用）
				var victim = board_manager.board[s][r][c]
				board_manager.remove_unit(s, r, c)
				var killer = death.get("killer")
				if killer != null and killer.is_alive():
					board_manager._process_on_kill(killer)
					# デバフ波及チェック（旧方式: support_effect文字列 / 新方式: skills配列）
					var has_debuff_spread: bool = "デバフ波及" in killer.support_effect
					if not has_debuff_spread:
						for skill in killer.skills:
							if skill.get("effect_id", "") == "debuff_spread":
								has_debuff_spread = true
								break
					if victim != null and has_debuff_spread:
						board_manager._process_debuff_spread(killer, victim, s, r, c)

	# 遅延キュー（priority 6–7）：1フレーム（≈0.016s）待ち後に promote_check を実行
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
