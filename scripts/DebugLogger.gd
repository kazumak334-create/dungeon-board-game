extends Node

const LOG_DIR = "user://debug/logs/"
const LOG_FILE = "user://debug/logs/latest.log"

var _file: FileAccess

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/debug/logs")
	_file = FileAccess.open(ProjectSettings.globalize_path(LOG_FILE), FileAccess.WRITE)
	_write("[STATE] DebugLogger initialized")

func _write(msg: String) -> void:
	if _file == null:
		return
	var ts := Time.get_datetime_string_from_system(false, true)
	_file.store_line("[%s] %s" % [ts, msg])
	_file.flush()

func state(key: String, value: Variant) -> void:
	_write("[STATE] %s=%s" % [key, str(value)])

func event(name: String, data: Dictionary = {}) -> void:
	_write("[EVENT] %s %s" % [name, JSON.stringify(data)])

func error(msg: String, context: Dictionary = {}) -> void:
	_write("[ERROR] %s %s" % [msg, JSON.stringify(context)])

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _file != null:
			_write("[STATE] DebugLogger shutdown")
			_file.close()
