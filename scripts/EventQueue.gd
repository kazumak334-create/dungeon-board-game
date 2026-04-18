# EventQueue.gd
# 優先度付きチェーンイベントキュー
class_name EventQueue
extends Node

const PRIORITY_IMMEDIATE = 1
const PRIORITY_STATUS    = 2
const PRIORITY_SUPPORT   = 3
const PRIORITY_PASSIVE   = 4
const PRIORITY_ACTIVE    = 4
const PRIORITY_ARTIFACT  = 5
const PRIORITY_BOARD     = 6
const PRIORITY_MERGE     = 7

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

	while _queue.size() > 0:
		_queue.sort_custom(func(a, b): return a["priority"] < b["priority"])
		var event = _queue.pop_front()
		_process_event(event, board_manager, base_hp)

	if _deferred.size() > 0 and not _deferred_pending:
		_deferred_pending = true
		call_deferred("_process_deferred", board_manager, base_hp)

func _process_event(event: Dictionary, board_manager: Node, base_hp: Array) -> void:
	# イベント処理の最小実装
	pass

func _process_deferred(board_manager: Node, base_hp: Array) -> void:
	_deferred_pending = false
	while _deferred.size() > 0:
		_deferred.sort_custom(func(a, b): return a["priority"] < b["priority"])
		var event = _deferred.pop_front()
		_process_event(event, board_manager, base_hp)
