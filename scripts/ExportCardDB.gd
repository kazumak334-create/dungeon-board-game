# ExportCardDB.gd
# CardDB.gdのconstデータをdata/cards.jsonにエクスポートするユーティリティ
# Main.gdの_readyから1回だけ呼ぶ→JSONファイル生成後に削除
extends RefCounted

static func export() -> void:
	var data: Dictionary = {
		"units": CardDB.UNITS,
		"spells": CardDB.SPELLS,
		"status_spells": CardDB.STATUS_SPELLS,
		"system_spells": CardDB.SYSTEM_SPELLS,
		"artifacts": CardDB.ARTIFACTS,
		"equipment": CardDB.EQUIPMENT,
		"classes": CardDB.CLASSES,
		"synthesis": CardDB.SYNTHESIS,
		"player_deck": CardDB.PLAYER_DECK,
		"player_spells": CardDB.PLAYER_SPELLS,
		"enemy_deck": CardDB.ENEMY_DECK,
	}
	var json_text: String = JSON.stringify(data, "\t")
	var file = FileAccess.open("res://data/cards.json", FileAccess.WRITE)
	if file != null:
		file.store_string(json_text)
		file.close()
		print("[ExportCardDB] cards.json exported successfully (%d bytes)" % json_text.length())
	else:
		print("[ExportCardDB] ERROR: cannot write cards.json")
