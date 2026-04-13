# SynergyDB.gd
# シナジー定義とチェック機能
extends RefCounted

const SYNERGY_PATH = "res://data/synergies.json"

var _synergies: Dictionary = {}

func _init() -> void:
	_load_synergies()

func _load_synergies() -> void:
	if not FileAccess.file_exists(SYNERGY_PATH):
		print("[SynergyDB] synergies.json が見つかりません")
		return

	var file = FileAccess.open(SYNERGY_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			_synergies = json.data
			print("[SynergyDB] シナジー定義読み込み: %d件" % _synergies.size())
		else:
			print("[SynergyDB] JSON parse error: %s" % json.get_error_message())

# カード配置時にシナジーをチェック
# new_card: 新しく配置したカードのデータ {name, skills, etc}
# placed_cards: 既に配置されているカードのデータ配列
# 戻り値: {synergy_id: String, affected_card_indices: Array[int]}の配列
func check_synergies(new_card: Dictionary, placed_cards: Array) -> Array:
	var result: Array = []

	# 新カードのeffect_idリストを取得
	var new_effects = _get_effect_ids(new_card)

	for synergy_id in _synergies.keys():
		var synergy = _synergies[synergy_id]
		var required_effects = synergy.get("effects", [])

		if required_effects.size() < 2:
			continue

		# 新カードがシナジーのいずれかのeffectを持っているか
		var new_card_has_synergy_effect = false
		for effect in required_effects:
			if effect in new_effects:
				new_card_has_synergy_effect = true
				break

		if not new_card_has_synergy_effect:
			continue

		# 既存カードで残りのeffectを持つカードを探す
		var affected_indices: Array = []
		for i in range(placed_cards.size()):
			var card = placed_cards[i]
			if card == null:
				continue
			var card_effects = _get_effect_ids(card)
			for effect in required_effects:
				if effect in card_effects and effect not in new_effects:
					affected_indices.append(i)
					break

		if affected_indices.size() > 0:
			result.append({
				"synergy_id": synergy_id,
				"affected_card_indices": affected_indices,
				"flash_duration": synergy.get("flash_duration", 1.0)
			})

	return result

# カードからeffect_idリストを取得
func _get_effect_ids(card_data: Dictionary) -> Array:
	var effects: Array = []
	var skills = card_data.get("skills", [])
	for skill in skills:
		var effect_id = skill.get("effect_id", "")
		if effect_id != "":
			effects.append(effect_id)
	return effects
