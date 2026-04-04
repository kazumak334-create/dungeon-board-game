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
#   effect_type: String,     # "damage" / "heal" / "base_damage"
#   value:       float,
#   extra:       Dictionary, # 追加情報（位置など）
#   timestamp:   float,
# }

var _queue: Array = []         # 即時処理（priority 1–5）
var _deferred: Array = []      # 遅延処理（priority 6–7）
var _deferred_pending: bool = false  # true = 次フレームで _deferred を処理

# ループ防止：同フレーム内に "damage" を受けたユニットのインスタンスIDセット
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
	# 優先度順ソート（同優先度は積まれた順を保持）
	_queue.sort_custom(func(a, b): return a["priority"] < b["priority"])

	var death_events: Array = []  # damage 処理後にまとめて remove_unit する

	for event in _queue:
		match event["effect_type"]:

			"damage":
				var tgt = event["target"]
				if tgt == null or not tgt.is_alive():
					continue
				# ループ防止：同フレームに既に damage を受けたユニットはスキップ
				var tid: int = tgt.get_instance_id()
				if tid in _damaged_ids:
					continue
				_damaged_ids.append(tid)
				tgt.take_damage(int(event["value"]))
				if not tgt.is_alive():
					death_events.append(event["extra"])

			"poison_damage":
				var tgt = event["target"]
				if tgt == null or not tgt.is_alive():
					continue
				var dmg: int = int(event["value"])
				tgt.take_damage(dmg)
				var ex: Dictionary = event["extra"]
				board_manager.status_damage.emit(
					ex.get("unit_name", "?"), "毒", dmg, tgt.poison_stacks
				)
				if not tgt.is_alive():
					death_events.append(ex)

			"heal":
				var tgt = event["target"]
				if tgt != null and tgt.is_alive():
					tgt.current_hp = min(tgt.max_hp, tgt.current_hp + int(event["value"]))
					# 吸血など active_skill 由来のヒールはシグナルを通知
					var ex: Dictionary = event["extra"]
					if ex.has("skill_name"):
						board_manager.active_skill_used.emit(
							int(ex["src_side"]), int(ex["src_row"]), int(ex["src_col"]),
							ex["skill_name"]
						)

			"base_damage":
				var side: int = event["extra"].get("side", -1)
				if side >= 0:
					base_hp[side] = max(0, base_hp[side] - int(event["value"]))
					board_manager.base_damaged.emit(side, int(event["value"]))

	_queue.clear()

	# ダメージ適用後の死亡後処理（revival チェック含む）
	for ex in death_events:
		var s: int = ex.get("enemy_side", -1)
		var r: int = ex.get("row", -1)
		var c: int = ex.get("col", -1)
		if s >= 0 and r >= 0 and c >= 0:
			board_manager.remove_unit(s, r, c)

	# 遅延キュー（priority 6–7）：1フレーム（≈0.016s）待ち後に処理
	if _deferred_pending:
		_deferred_pending = false
		# 将来実装：遅延イベントの処理フック（現在は予約のみ）
		_deferred.clear()
	elif not _deferred.is_empty():
		_deferred_pending = true  # 次回 flush で処理

	_damaged_ids.clear()
