# RestScreenRevive.gd
# Phase 4: BW間休憩画面でHP=0となった死亡ユニットをゴールド消費で復帰させる機能
#
# 役割:
# - GameSession.wave_dead_units から死亡ユニット情報を取得
# - レアリティに応じた復帰コスト（rarity_price × 0.3）を算出
# - 復帰ボタンを生成し、クリックでゴールド減算 + selected_deck に追加
# - signal revive_completed で RestScreenManager に通知
#
# 連携:
# - RestScreenManager が初期化・クリーンアップを管理
# - GameSession の gold / selected_deck / wave_dead_units を直接操作
# - CardDB / ConfigLoader からデータ取得

extends Node

signal revive_completed(unit_name: String, new_gold: int)

const COLOR_REVIVE := Color(0.6, 0.3, 0.3)
const COLOR_REVIVE_HOVER := Color(0.7, 0.4, 0.4)
const COLOR_DIM := Color(0.5, 0.5, 0.5)

var game_session: Node = null
var ui_root: Control = null
var revivable_units: Array = []
var revive_buttons: Array = []

func initialize(session: Node, parent: Control) -> void:
	game_session = session
	ui_root = parent
	revivable_units = find_revivable_units()

func find_revivable_units() -> Array:
	var result: Array = []
	if not game_session:
		return result
	
	for dead_unit in game_session.wave_dead_units:
		var unit_name: String = dead_unit.get("unit_name", "")
		if unit_name.is_empty():
			continue
		
		var rarity: String = dead_unit.get("rarity", "common")
		var initial_slot: int = dead_unit.get("initial_slot", -1)
		var death_wave: int = dead_unit.get("death_wave", 0)
		
		var revive_cost: int = calculate_revive_cost(rarity)
		
		result.append({
			"unit_name": unit_name,
			"rarity": rarity,
			"initial_slot": initial_slot,
			"death_wave": death_wave,
			"revive_cost": revive_cost
		})
	
	return result

func calculate_revive_cost(rarity: String) -> int:
	var rarity_price: Dictionary = ConfigLoader.get_value("shop", "rarity_price", {
		"common": 50,
		"uncommon": 100,
		"rare": 200,
		"epic": 400,
		"legend": 800
	})
	var base_price: int = rarity_price.get(rarity, 50)
	return int(base_price * 0.3)

func create_revive_button(target_container: Control, unit_data: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(90, 20)
	button.text = "復帰 %dG" % unit_data.get("revive_cost", 0)
	
	var font_size: int = 10
	var label_settings := LabelSettings.new()
	label_settings.font_size = font_size
	button.add_theme_font_size_override("font_size", font_size)
	
	var current_gold: int = game_session.gold if game_session else 0
	var revive_cost: int = unit_data.get("revive_cost", 0)
	
	if current_gold >= revive_cost:
		button.modulate = COLOR_REVIVE
		button.disabled = false
	else:
		button.modulate = COLOR_DIM
		button.disabled = true
	
	var index: int = revivable_units.find(unit_data)
	if index >= 0:
		button.pressed.connect(func(): _on_revive_button_pressed(index))
	
	target_container.add_child(button)
	revive_buttons.append(button)
	
	return button

func _on_revive_button_pressed(index: int) -> void:
	if revive_unit(index):
		pass

func revive_unit(index: int) -> bool:
	if not game_session:
		return false
	
	if index < 0 or index >= revivable_units.size():
		return false
	
	var unit_data: Dictionary = revivable_units[index]
	var revive_cost: int = unit_data.get("revive_cost", 0)
	var unit_name: String = unit_data.get("unit_name", "")
	
	if game_session.gold < revive_cost:
		return false
	
	game_session.gold -= revive_cost
	
	game_session.selected_deck.append({"name": unit_name})
	
	var removed: bool = false
	for i in range(game_session.wave_dead_units.size() - 1, -1, -1):
		var dead_unit: Dictionary = game_session.wave_dead_units[i]
		if dead_unit.get("unit_name", "") == unit_name:
			game_session.wave_dead_units.remove_at(i)
			removed = true
			break
	
	if not removed:
		push_warning("RestScreenRevive: wave_dead_units から %s を削除できませんでした" % unit_name)
	
	revive_completed.emit(unit_name, game_session.gold)
	
	return true

func cleanup() -> void:
	for button in revive_buttons:
		if is_instance_valid(button):
			button.queue_free()
	revive_buttons.clear()
	revivable_units.clear()
