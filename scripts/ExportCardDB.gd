# ExportCardDB.gd
# CardDB.gdのconstデータをdata/cards.jsonにエクスポートするユーティリティ
# Main.gdの_readyから1回だけ呼ぶ→JSONファイル生成後に削除
extends RefCounted

static func export() -> void:
	var _CDB = load("res://scripts/CardDB.gd")
	var data: Dictionary = {
		"units": _CDB.UNITS,
		"spells": _CDB.SPELLS,
		"status_spells": _CDB.STATUS_SPELLS,
		"system_spells": _CDB.SYSTEM_SPELLS,
		"artifacts": _CDB.ARTIFACTS,
		"equipment": _CDB.EQUIPMENT,
		"classes": _CDB.CLASSES,
		"synthesis": _CDB.SYNTHESIS,
		"player_deck": _CDB.PLAYER_DECK,
		"player_spells": _CDB.PLAYER_SPELLS,
		"enemy_deck": _CDB.ENEMY_DECK,
	}
	var json_text: String = JSON.stringify(data, "\t")
	var file = FileAccess.open("res://data/cards.json", FileAccess.WRITE)
	if file != null:
		file.store_string(json_text)
		file.close()
		print("[ExportCardDB] cards.json exported successfully (%d bytes)" % json_text.length())
	else:
		print("[ExportCardDB] ERROR: cannot write cards.json")
