# GameUIQueue.gd
# キュー+デッキ情報UI（GameUI.gdから分離）
extends RefCounted

var main: Node = null
var _EDB = null

var _queue_card_self: Control = null      # 自分のキューカード
var _queue_card_enemy: Control = null     # 敵のキューカード
var _last_self_card_name: String = ""     # 前回の自カード名（変化検出用）
var _last_enemy_card_name: String = ""    # 前回の敵カード名
var _queue_self_deck_label: Label = null  # 自デッキ山ラベル
var _queue_enemy_deck_label: Label = null # 敵デッキ山ラベル
var _queue_mana_bar: ColorRect = null     # キューエリア内マナゲージ
var _queue_mana_label: Label = null       # キューエリア内マナ数値
var _queue_card_parent_self: Control = null  # 自カード配置親コンテナ
var _queue_card_parent_enemy: Control = null # 敵カード配置親コンテナ

func build() -> void:
	_build_next_card_panel()
	_build_card_queue_ui()

func _build_next_card_panel() -> void:
	var panel_w: int = 360
	var panel_h: int = 110
	var panel_x: int = main.CENTER_X - panel_w / 2
	var panel_y: int = main.BOARD_TOP + 3 * main.CELL_H + 36

	# ---- 既存パネル（互換のため維持・非表示） ----
	main.next_card_panel = ColorRect.new()
	main.next_card_panel.position = Vector2(panel_x, panel_y)
	main.next_card_panel.size     = Vector2(panel_w, panel_h)
	main.next_card_panel.color    = Color(0.08, 0.10, 0.17)
	main.next_card_panel.visible  = false
	main.add_child(main.next_card_panel)

	var border := ColorRect.new()
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.size     = Vector2(panel_w + 4, panel_h + 4)
	border.color    = Color(0.3, 0.5, 0.8, 0.6)
	border.z_index  = -1
	border.visible  = false
	main.add_child(border)

	var title_lbl := Label.new()
	title_lbl.text     = "─── NEXT CARD ───"
	title_lbl.position = Vector2(panel_x + 85, panel_y + 4)
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.modulate = Color(0.5, 0.7, 1.0)
	title_lbl.visible  = false
	main.add_child(title_lbl)

	main.next_card_name_label = Label.new()
	main.next_card_name_label.position = Vector2(panel_x + 10, panel_y + 22)
	main.next_card_name_label.add_theme_font_size_override("font_size", 28)
	main.next_card_name_label.modulate = Color(1.0, 1.0, 0.85)
	main.next_card_name_label.visible  = false
	main.add_child(main.next_card_name_label)

	main.next_card_cost_label = Label.new()
	main.next_card_cost_label.position = Vector2(panel_x + panel_w - 70, panel_y + 16)
	main.next_card_cost_label.add_theme_font_size_override("font_size", 32)
	main.next_card_cost_label.modulate = Color(1.0, 0.85, 0.1)
	main.next_card_cost_label.visible  = false
	main.add_child(main.next_card_cost_label)

	main.next_card_detail_label = Label.new()
	main.next_card_detail_label.position = Vector2(panel_x + 10, panel_y + 60)
	main.next_card_detail_label.add_theme_font_size_override("font_size", 13)
	main.next_card_detail_label.modulate = Color(0.75, 0.85, 0.75)
	main.next_card_detail_label.visible  = false
	main.add_child(main.next_card_detail_label)

	main.next_card_timer_label = Label.new()
	main.next_card_timer_label.position = Vector2(panel_x + 10, panel_y + 88)
	main.next_card_timer_label.add_theme_font_size_override("font_size", 11)
	main.next_card_timer_label.modulate = Color(0.55, 0.55, 0.7)
	main.next_card_timer_label.visible  = false
	main.add_child(main.next_card_timer_label)

	main.enemy_next_label = Label.new()
	main.enemy_next_label.position = Vector2(panel_x + panel_w + 8, panel_y + 20)
	main.enemy_next_label.add_theme_font_size_override("font_size", 13)
	main.enemy_next_label.modulate = Color(1.0, 0.5, 0.5)
	main.enemy_next_label.visible  = false
	main.add_child(main.enemy_next_label)

	var deck_y: int = panel_y + panel_h + 6
	main.deck_count_label = Label.new()
	main.deck_count_label.position = Vector2(panel_x, deck_y)
	main.deck_count_label.add_theme_font_size_override("font_size", 12)
	main.deck_count_label.modulate = Color(0.6, 0.8, 1.0)
	main.deck_count_label.visible  = false
	main.add_child(main.deck_count_label)

	main.discard_count_label = Label.new()
	main.discard_count_label.position = Vector2(panel_x + 130, deck_y)
	main.discard_count_label.add_theme_font_size_override("font_size", 12)
	main.discard_count_label.modulate = Color(0.5, 0.5, 0.7)
	main.discard_count_label.visible  = false
	main.add_child(main.discard_count_label)

	main.enemy_deck_count_label = Label.new()
	main.enemy_deck_count_label.position = Vector2(panel_x + panel_w + 8, panel_y + 60)
	main.enemy_deck_count_label.add_theme_font_size_override("font_size", 12)
	main.enemy_deck_count_label.modulate = Color(1.0, 0.5, 0.5)
	main.enemy_deck_count_label.visible  = false
	main.add_child(main.enemy_deck_count_label)

	# ---- 新カードキューUI ----
	_build_card_queue_ui()

func _build_card_queue_ui() -> void:
	var queue_y: int = main.BOARD_TOP + 3 * main.CELL_H + 20 + 40
	var card_w: float = 160.0
	var card_h: float = 220.0

	# ---- 自分側（左半分） ----
	# デッキ山パネル
	var self_deck_panel := ColorRect.new()
	self_deck_panel.position = Vector2(20, queue_y)
	self_deck_panel.size = Vector2(80, 60)
	self_deck_panel.color = Color(0.08, 0.10, 0.17)
	main.add_child(self_deck_panel)
	var self_deck_border := ColorRect.new()
	self_deck_border.position = Vector2(19, queue_y - 1)
	self_deck_border.size = Vector2(82, 62)
	self_deck_border.color = Color(0.3, 0.5, 0.7, 0.5)
	self_deck_border.z_index = -1
	main.add_child(self_deck_border)
	_queue_self_deck_label = Label.new()
	_queue_self_deck_label.position = Vector2(24, queue_y + 6)
	_queue_self_deck_label.size = Vector2(72, 50)
	_queue_self_deck_label.add_theme_font_size_override("font_size", 11)
	_queue_self_deck_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_queue_self_deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(_queue_self_deck_label)

	# マナ表示
	var self_mana_panel := ColorRect.new()
	self_mana_panel.position = Vector2(110, queue_y)
	self_mana_panel.size = Vector2(130, 60)
	self_mana_panel.color = Color(0.06, 0.08, 0.14)
	main.add_child(self_mana_panel)
	var mana_title := Label.new()
	mana_title.text = "マナ"
	mana_title.position = Vector2(114, queue_y + 4)
	mana_title.add_theme_font_size_override("font_size", 11)
	mana_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	main.add_child(mana_title)
	_queue_mana_label = Label.new()
	_queue_mana_label.position = Vector2(114, queue_y + 20)
	_queue_mana_label.size = Vector2(122, 18)
	_queue_mana_label.add_theme_font_size_override("font_size", 11)
	_queue_mana_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	main.add_child(_queue_mana_label)
	var mana_bar_bg := ColorRect.new()
	mana_bar_bg.position = Vector2(114, queue_y + 40)
	mana_bar_bg.size = Vector2(122, 12)
	mana_bar_bg.color = Color(0.1, 0.1, 0.07)
	main.add_child(mana_bar_bg)
	_queue_mana_bar = ColorRect.new()
	_queue_mana_bar.position = Vector2(114, queue_y + 40)
	_queue_mana_bar.size = Vector2(0, 12)
	_queue_mana_bar.color = Color(0.2, 0.5, 1.0)
	main.add_child(_queue_mana_bar)

	# 自分カード配置親（160x220）
	var self_card_holder := Control.new()
	self_card_holder.position = Vector2(250, queue_y)
	self_card_holder.custom_minimum_size = Vector2(card_w, card_h)
	self_card_holder.size = Vector2(card_w, card_h)
	main.add_child(self_card_holder)
	_queue_card_parent_self = self_card_holder

	# ---- 敵側（右半分・ミラー） ----
	# 敵カード配置親
	var enemy_card_holder := Control.new()
	enemy_card_holder.position = Vector2(1280 - 250 - card_w, queue_y)
	enemy_card_holder.custom_minimum_size = Vector2(card_w, card_h)
	enemy_card_holder.size = Vector2(card_w, card_h)
	main.add_child(enemy_card_holder)
	_queue_card_parent_enemy = enemy_card_holder

	# 敵デッキ山パネル
	var enemy_deck_panel := ColorRect.new()
	enemy_deck_panel.position = Vector2(1280 - 20 - 80, queue_y)
	enemy_deck_panel.size = Vector2(80, 60)
	enemy_deck_panel.color = Color(0.14, 0.08, 0.08)
	main.add_child(enemy_deck_panel)
	var enemy_deck_border := ColorRect.new()
	enemy_deck_border.position = Vector2(1280 - 21 - 80, queue_y - 1)
	enemy_deck_border.size = Vector2(82, 62)
	enemy_deck_border.color = Color(0.7, 0.3, 0.3, 0.5)
	enemy_deck_border.z_index = -1
	main.add_child(enemy_deck_border)
	_queue_enemy_deck_label = Label.new()
	_queue_enemy_deck_label.position = Vector2(1280 - 16 - 80, queue_y + 6)
	_queue_enemy_deck_label.size = Vector2(72, 50)
	_queue_enemy_deck_label.add_theme_font_size_override("font_size", 11)
	_queue_enemy_deck_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_queue_enemy_deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(_queue_enemy_deck_label)


func update() -> void:
	_update_next_card()
	_update_deck_counts()

func _update_next_card() -> void:
	# ---- キューカード更新（変化時のみ再生成） ----
	var next = main.deck_manager.get_next_card()
	var self_card_name: String = next.unit_name if next != null else ""
	if self_card_name != _last_self_card_name:
		_last_self_card_name = self_card_name
		_rebuild_queue_card_self(next)

	var enemy_next = main.enemy_ai.get_next_card()
	var enemy_card_name: String = enemy_next.unit_name if enemy_next != null else ""
	if enemy_card_name != _last_enemy_card_name:
		_last_enemy_card_name = enemy_card_name
		_rebuild_queue_card_enemy(enemy_next)

	# ---- マナゲージ更新（毎フレーム） ----
	var mana: float = main.deck_manager.mana
	var mana_max: float = main.deck_manager.MANA_MAX
	var mana_ratio: float = clamp(mana / max(1.0, mana_max), 0.0, 1.0)
	if _queue_mana_label != null:
		_queue_mana_label.text = "%.1f / %d" % [mana, int(mana_max)]
	if _queue_mana_bar != null:
		_queue_mana_bar.size.x = int(122.0 * mana_ratio)
		var gauge_color: Color = Color(0.2, 0.5, 1.0).lerp(Color(1.0, 0.85, 0.1), mana_ratio)
		_queue_mana_bar.color = gauge_color

func _rebuild_queue_card_self(next) -> void:
	if _queue_card_parent_self == null:
		return
	if _queue_card_self != null and is_instance_valid(_queue_card_self):
		_queue_card_self.queue_free()
		_queue_card_self = null
	if next == null:
		return
	var CardUI = load("res://scripts/CardUIComponent.gd")
	if next.card_type == "unit":
		var unit_def: Dictionary = CardDB.UNITS.get(next.unit_name, {})
		_queue_card_self = CardUI.create_unit_card(next.unit_name, unit_def, 160.0, 220.0)
	else:
		var spell_def: Dictionary = CardDB.SPELLS.get(next.unit_name, {})
		if spell_def.is_empty():
			spell_def = CardDB.STATUS_SPELLS.get(next.unit_name, {})
		if spell_def.is_empty():
			spell_def = CardDB.SYSTEM_SPELLS.get(next.unit_name, {})
		_queue_card_self = CardUI.create_spell_card(next.unit_name, spell_def, 160.0, 220.0)
	_queue_card_self.position = Vector2(0, 0)
	_queue_card_parent_self.add_child(_queue_card_self)

func _rebuild_queue_card_enemy(enemy_next) -> void:
	if _queue_card_parent_enemy == null:
		return
	if _queue_card_enemy != null and is_instance_valid(_queue_card_enemy):
		_queue_card_enemy.queue_free()
		_queue_card_enemy = null
	if enemy_next == null:
		return
	var CardUI = load("res://scripts/CardUIComponent.gd")
	if enemy_next.card_type == "unit":
		var unit_def: Dictionary = CardDB.UNITS.get(enemy_next.unit_name, {})
		_queue_card_enemy = CardUI.create_unit_card(enemy_next.unit_name, unit_def, 160.0, 220.0)
	else:
		var spell_def: Dictionary = CardDB.SPELLS.get(enemy_next.unit_name, {})
		if spell_def.is_empty():
			spell_def = CardDB.STATUS_SPELLS.get(enemy_next.unit_name, {})
		if spell_def.is_empty():
			spell_def = CardDB.SYSTEM_SPELLS.get(enemy_next.unit_name, {})
		_queue_card_enemy = CardUI.create_spell_card(enemy_next.unit_name, spell_def, 160.0, 220.0)
	_queue_card_enemy.position = Vector2(0, 0)
	_queue_card_parent_enemy.add_child(_queue_card_enemy)

func _update_deck_counts() -> void:
	main.deck_count_label.text    = "自デッキ: %d枚" % main.deck_manager.deck.size()
	main.discard_count_label.text = "捨て札: %d枚" % main.deck_manager.discard.size()
	main.enemy_deck_count_label.text = "敵デッキ: %d枚\n敵捨て札: %d枚" % [
		main.enemy_ai.enemy_deck.size(), main.enemy_ai.enemy_discard.size()
	]
	# キューエリアのデッキ山ラベル更新
	if _queue_self_deck_label != null:
		_queue_self_deck_label.text = "デッキ\n%d枚\n捨て %d枚" % [
			main.deck_manager.deck.size(), main.deck_manager.discard.size()
		]
	if _queue_enemy_deck_label != null:
		_queue_enemy_deck_label.text = "デッキ\n%d枚\n捨て %d枚" % [
			main.enemy_ai.enemy_deck.size(), main.enemy_ai.enemy_discard.size()
		]