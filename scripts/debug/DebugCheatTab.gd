# DebugCheatTab.gd
# デバッグUIのチートタブ（Godモード・リソース操作・GameSession操作）
class_name DebugCheatTab
extends ScrollContainer

# UI要素保持用
var _god_invincible: CheckButton
var _god_infinite_mana: CheckButton
var _god_infinite_time: CheckButton
var _god_auto_win: CheckButton

var _hp_label: Label
var _gold_label: Label
var _sp_label: Label
var _alert_label: Label
var _run_depth_label: Label
var _act_label: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(vbox)
	
	# Godモード
	_add_section_label(vbox, "Godモード")
	_god_invincible = _add_checkbox(vbox, "無敵モード", false, _on_god_invincible_toggled)
	_god_infinite_mana = _add_checkbox(vbox, "マナ無限", false, _on_god_infinite_mana_toggled)
	_god_infinite_time = _add_checkbox(vbox, "時間無限", false, _on_god_infinite_time_toggled)
	_god_auto_win = _add_checkbox(vbox, "必ず勝利", false, _on_god_auto_win_toggled)
	
	# リソース操作
	_add_section_label(vbox, "リソース操作")
	
	var hp_hbox = HBoxContainer.new()
	vbox.add_child(hp_hbox)
	_add_button(hp_hbox, "HP+10", func(): _add_resource("hp", 10))
	_add_button(hp_hbox, "HP+50", func(): _add_resource("hp", 50))
	_add_button(hp_hbox, "HP MAX", func(): _add_resource("hp", 9999))
	_hp_label = Label.new()
	_hp_label.text = "[現在: N/A]"
	hp_hbox.add_child(_hp_label)
	
	var gold_hbox = HBoxContainer.new()
	vbox.add_child(gold_hbox)
	_add_button(gold_hbox, "Gold +100", func(): _add_resource("gold", 100))
	_add_button(gold_hbox, "Gold +500", func(): _add_resource("gold", 500))
	_add_button(gold_hbox, "Gold +1000", func(): _add_resource("gold", 1000))
	_gold_label = Label.new()
	_gold_label.text = "[現在: %dG]" % GameSession.gold
	gold_hbox.add_child(_gold_label)
	
	var sp_hbox = HBoxContainer.new()
	vbox.add_child(sp_hbox)
	_add_button(sp_hbox, "SP +5", func(): _add_resource("sp", 5))
	_add_button(sp_hbox, "SP +20", func(): _add_resource("sp", 20))
	_add_button(sp_hbox, "SP +50", func(): _add_resource("sp", 50))
	_sp_label = Label.new()
	_sp_label.text = "[現在: %dSP]" % GameSession.skill_points
	sp_hbox.add_child(_sp_label)
	
	# 警戒レベル
	_add_section_label(vbox, "警戒レベル")
	var alert_hbox = HBoxContainer.new()
	vbox.add_child(alert_hbox)
	_add_button(alert_hbox, "-1", func(): _change_alert(-1))
	_add_button(alert_hbox, "+1", func(): _change_alert(1))
	_add_button(alert_hbox, "=0", func(): _set_alert(0))
	_add_button(alert_hbox, "=5", func(): _set_alert(5))
	_alert_label = Label.new()
	_alert_label.text = "[現在: Lv.%d]" % GameSession.alert_level
	alert_hbox.add_child(_alert_label)
	
	# ゲーム状態
	_add_section_label(vbox, "ゲーム状態")
	var run_depth_hbox = HBoxContainer.new()
	vbox.add_child(run_depth_hbox)
	_add_button(run_depth_hbox, "run_depth -1", func(): _change_run_depth(-1))
	_add_button(run_depth_hbox, "run_depth +1", func(): _change_run_depth(1))
	_run_depth_label = Label.new()
	_run_depth_label.text = "[現在: %d]" % GameSession.run_depth
	run_depth_hbox.add_child(_run_depth_label)
	
	var act_hbox = HBoxContainer.new()
	vbox.add_child(act_hbox)
	_add_button(act_hbox, "Act -1", func(): _change_act(-1))
	_add_button(act_hbox, "Act +1", func(): _change_act(1))
	_act_label = Label.new()
	_act_label.text = "[現在: Act %d]" % GameSession.current_act
	act_hbox.add_child(_act_label)
	
	_add_button(vbox, "次バトルスキップ", _on_skip_next_battle)
	_add_button(vbox, "ボス戦強制開始", _on_force_boss_battle)
	
	# カード・アーティファクト追加（未実装・レイアウトのみ）
	_add_section_label(vbox, "カード・アーティファクト追加（未実装）")
	var card_hbox = HBoxContainer.new()
	vbox.add_child(card_hbox)
	var card_input = LineEdit.new()
	card_input.placeholder_text = "カード名/アーティファクト名"
	card_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_hbox.add_child(card_input)
	_add_button(card_hbox, "カードを追加", func(): print("[チート] カード追加（未実装）"))
	_add_button(card_hbox, "アーティファクトを追加", func(): print("[チート] アーティファクト追加（未実装）"))
	
	# ユニット操作（バトル中のみ・未実装）
	_add_section_label(vbox, "ユニット操作（バトル中のみ・未実装）")
	_add_button(vbox, "選択ユニット編集（未実装）", func(): print("[チート] ユニット編集（未実装）"))
	
	# 敵操作（未実装）
	_add_section_label(vbox, "敵操作（未実装）")
	_add_button(vbox, "敵全削除", func(): print("[チート] 敵全削除（未実装）"))
	_add_button(vbox, "敵HP半減", func(): print("[チート] 敵HP半減（未実装）"))

func _add_section_label(parent: VBoxContainer, title: String) -> void:
	var label = Label.new()
	label.text = "── " + title + " ──"
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)

func _add_checkbox(parent: VBoxContainer, text: String, initial: bool, callback: Callable) -> CheckButton:
	var checkbox = CheckButton.new()
	checkbox.text = text
	checkbox.button_pressed = initial
	checkbox.toggled.connect(callback)
	parent.add_child(checkbox)
	return checkbox

func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

# Godモードコールバック
func _on_god_invincible_toggled(value: bool) -> void:
	GameSession.god_mode_invincible = value
	print("[チート] 無敵モード: ", value)

func _on_god_infinite_mana_toggled(value: bool) -> void:
	GameSession.god_mode_infinite_mana = value
	print("[チート] マナ無限: ", value)

func _on_god_infinite_time_toggled(value: bool) -> void:
	GameSession.god_mode_infinite_time = value
	print("[チート] 時間無限: ", value)

func _on_god_auto_win_toggled(value: bool) -> void:
	GameSession.god_mode_auto_win = value
	print("[チート] 必ず勝利: ", value)

# リソース操作
func _add_resource(type: String, amount: int) -> void:
	match type:
		"hp":
			print("[チート] HP+%d（バトル中のみ有効・未実装）" % amount)
		"gold":
			GameSession.gold += amount
			_gold_label.text = "[現在: %dG]" % GameSession.gold
			print("[チート] Gold +%d -> 合計 %dG" % [amount, GameSession.gold])
		"sp":
			GameSession.skill_points += amount
			_sp_label.text = "[現在: %dSP]" % GameSession.skill_points
			print("[チート] SP +%d -> 合計 %dSP" % [amount, GameSession.skill_points])

# 警戒レベル操作
func _change_alert(delta: int) -> void:
	GameSession.alert_level = max(0, GameSession.alert_level + delta)
	_alert_label.text = "[現在: Lv.%d]" % GameSession.alert_level
	print("[チート] 警戒レベル %+d -> Lv.%d" % [delta, GameSession.alert_level])

func _set_alert(value: int) -> void:
	GameSession.alert_level = max(0, value)
	_alert_label.text = "[現在: Lv.%d]" % GameSession.alert_level
	print("[チート] 警戒レベル = Lv.%d" % GameSession.alert_level)

# ゲーム状態操作
func _change_run_depth(delta: int) -> void:
	GameSession.run_depth = max(0, GameSession.run_depth + delta)
	_run_depth_label.text = "[現在: %d]" % GameSession.run_depth
	print("[チート] run_depth %+d -> %d" % [delta, GameSession.run_depth])

func _change_act(delta: int) -> void:
	GameSession.current_act = clamp(GameSession.current_act + delta, 1, 3)
	_act_label.text = "[現在: Act %d]" % GameSession.current_act
	print("[チート] Act %+d -> Act %d" % [delta, GameSession.current_act])

func _on_skip_next_battle() -> void:
	print("[チート] 次バトルスキップ（未実装）")

func _on_force_boss_battle() -> void:
	print("[チート] ボス戦強制開始（未実装）")
