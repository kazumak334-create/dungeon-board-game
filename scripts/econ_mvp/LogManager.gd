extends Node

signal event_logged(text: String)

var log_enabled: bool = true
var log_level: String = "DEBUG"
var _file: FileAccess = null
var _battle_id: String = ""
var recent_logs: Array[String] = []
const MAX_RECENT_LOGS: int = 50

var _draw_count: int = 0
var _reload_count: int = 0
var _cards_played: int = 0
var _build_completed: int = 0
var _instant_build_count: int = 0
var _queue_max_length: int = 0
var _resource_starved_seconds: int = 0
var _hand_full_seconds: int = 0
var _inactive_building_seconds: int = 0
var _queue_length_sum: int = 0
var _queue_sample_count: int = 0
var _last_total_force: float = 0.0
var _last_duration: int = 0

func start_battle(battle_id: String) -> void:
	if not log_enabled:
		return
	end_battle()
	_battle_id = battle_id
	_reset_counters()
	var logs_dir := "user://logs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(logs_dir))
	var path := "%s/run_%s.jsonl" % [logs_dir, _get_timestamp()]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("[LogManager] failed to open log file: %s" % path)

func end_battle() -> void:
	if _file == null:
		return
	_file.flush()
	_file.close()
	_file = null

func log_event(data: Dictionary) -> void:
	var event_type: String = str(data.get("type", ""))
	if not _should_log(event_type):
		return
	var row := data.duplicate(true)
	if not row.has("battle_id"):
		row["battle_id"] = _battle_id
	_update_counters(row)
	if _file != null:
		_file.store_line(JSON.stringify(row))
		_file.flush()
	var text := _format_event_text(row)
	if text != "":
		recent_logs.append(text)
		if recent_logs.size() > MAX_RECENT_LOGS:
			recent_logs.pop_front()
		print("[LogManager] %s" % text)
		event_logged.emit(text)

func log_snapshot(data: Dictionary) -> void:
	var row := data.duplicate(true)
	row["type"] = "SNAPSHOT"
	log_event(row)

func log_battle_summary(data: Dictionary) -> void:
	var row := data.duplicate(true)
	row["type"] = "BATTLE_SUMMARY"
	_last_total_force = float(row.get("total_force", _last_total_force))
	_last_duration = int(row.get("duration", _last_duration))
	log_event(row)

func log_analysis_metrics() -> void:
	var avg_queue_length: float = 0.0
	if _queue_sample_count > 0:
		avg_queue_length = float(_queue_length_sum) / float(_queue_sample_count)
	var force_per_minute: float = 0.0
	if _last_duration > 0:
		force_per_minute = _last_total_force / (float(_last_duration) / 60.0)
	log_event({
		"type": "ANALYSIS_METRICS",
		"battle_id": _battle_id,
		"draw_count": _draw_count,
		"reload_count": _reload_count,
		"cards_played": _cards_played,
		"buildings_completed": _build_completed,
		"avg_queue_length": avg_queue_length,
		"max_queue_length": _queue_max_length,
		"resource_starved_time": _resource_starved_seconds,
		"hand_full_time": _hand_full_seconds,
		"inactive_building_time": _inactive_building_seconds,
		"total_force": _last_total_force,
		"force_per_minute": force_per_minute,
	})

func _should_log(event_type: String) -> bool:
	if not log_enabled:
		return false
	var basic_types := ["SNAPSHOT", "BATTLE_SUMMARY", "ANALYSIS_METRICS"]
	if log_level == "BASIC":
		return event_type in basic_types
	var verbose_types := ["RESOURCE_TICK", "HAPPINESS_TICK", "BUILDING_OPERATION", "SMITHY_EFFECT", "UI_ACTION"]
	if log_level == "DEBUG":
		return not (event_type in verbose_types)
	return true

func _reset_counters() -> void:
	_draw_count = 0
	_reload_count = 0
	_cards_played = 0
	_build_completed = 0
	_instant_build_count = 0
	_queue_max_length = 0
	_resource_starved_seconds = 0
	_hand_full_seconds = 0
	_inactive_building_seconds = 0
	_queue_length_sum = 0
	_queue_sample_count = 0
	_last_total_force = 0.0
	_last_duration = 0

func _update_counters(row: Dictionary) -> void:
	match str(row.get("type", "")):
		"DRAW":
			_draw_count += 1
		"RELOAD":
			_reload_count += 1
		"CARD_PLAY":
			_cards_played += 1
		"BUILD_COMPLETE":
			_build_completed += 1
		"INSTANT_BUILD":
			_instant_build_count += 1
	var queue_count: int = int(row.get("construction_queue_count", row.get("queue_count", -1)))
	if queue_count >= 0:
		_queue_length_sum += queue_count
		_queue_sample_count += 1
		_queue_max_length = maxi(_queue_max_length, queue_count)
	if row.get("type", "") == "SNAPSHOT":
		_last_total_force = float(row.get("total_force", _last_total_force))
		_last_duration = int(row.get("time", _last_duration))

func _format_event_text(row: Dictionary) -> String:
	var prefix := "[%s] " % _format_event_time(row)
	match str(row.get("type", "")):
		"POP_MILESTONE":
			return prefix + "Population confirmed: %dk -> %dk" % [int(row.get("old_population", 0)), int(row.get("new_population", 0))]
		"SAT_STAGE_CHANGE":
			return prefix + "Satisfaction changed: %s -> %s" % [str(row.get("old_stage", "")), str(row.get("new_stage", ""))]
		"POP_LOSS":
			return prefix + "Population loss: %d (%s)" % [int(row.get("loss", 0)), str(row.get("reason", row.get("cause", "")))]
		"LAND_PANEL_GEN":
			var pos: Array = row.get("pos", [])
			return prefix + "Land panel generated at %s" % str(pos)
		"LAND_CARD_REWARD":
			return prefix + "Land card reward generated: %s" % str(row.get("land_subtype", ""))
		"LAND_CARD_PLACED":
			var placed: Array = row.get("pos", row.get("placed_pos", []))
			return prefix + "Land card placed at %s" % str(placed)
		"BUILD_PLACED", "BUILD_COMPLETE":
			return prefix + "Building placed: %s at %s" % [str(row.get("building_type", "")), str(row.get("pos", []))]
		"POP_CHANGE", "SAT_SLOPE":
			return ""
		_:
			return ""

func _format_event_time(row: Dictionary) -> String:
	if row.has("clock"):
		return str(row["clock"])
	if row.has("time"):
		var sec := int(float(row.get("time", 0.0)))
		return "%02d:%02d:%02d" % [int(sec / 3600), int(sec / 60) % 60, sec % 60]
	var now := Time.get_datetime_dict_from_system()
	return "%02d:%02d:%02d" % [int(now["hour"]), int(now["minute"]), int(now["second"])]

func _get_timestamp() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(now["year"]),
		int(now["month"]),
		int(now["day"]),
		int(now["hour"]),
		int(now["minute"]),
		int(now["second"]),
	]
