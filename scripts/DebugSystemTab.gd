# DebugSystemTab.gd
# デバッグUIのシステムタブ（速度制御・表示切替・状態ダンプ・ConfigLoader再読込）
class_name DebugSystemTab
extends ScrollContainer

# 速度制御用
var _current_speed: float = 1.0

# 表示切替用（フラグのみ・実装はMain.gd等で参照）
var show_log: bool = false
var show_fps: bool = false
var show_attack_range: bool = false
var show_mana_flow: bool = false
var show_path: bool = false

var _config_load_time_label: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(vbox)
	
	# 速度制御
	_add_section_label(vbox, "速度制御")
	var speed_hbox = HBoxContainer.new()
	vbox.add_child(speed_hbox)
	_add_button(speed_hbox, "x0.5", func(): _set_speed(0.5))
	_add_button(speed_hbox, "x1", func(): _set_speed(1.0))
	_add_button(speed_hbox, "x2", func(): _set_speed(2.0))
	_add_button(speed_hbox, "x4", func(): _set_speed(4.0))
	_add_button(speed_hbox, "x8", func(): _set_speed(8.0))
	
	# 表示切替
	_add_section_label(vbox, "表示切替（未実装）")
	_add_checkbox(vbox, "ログ表示", false, func(v): show_log = v; print("[システム] ログ表示: ", v))
	_add_checkbox(vbox, "FPS表示", false, func(v): show_fps = v; print("[システム] FPS表示: ", v))
	_add_checkbox(vbox, "攻撃範囲可視化", false, func(v): show_attack_range = v; print("[システム] 攻撃範囲可視化: ", v))
	_add_checkbox(vbox, "マナフロー可視化", false, func(v): show_mana_flow = v; print("[システム] マナフロー可視化: ", v))
	_add_checkbox(vbox, "パス表示", false, func(v): show_path = v; print("[システム] パス表示: ", v))
	
	# 状態ダンプ
	_add_section_label(vbox, "状態ダンプ")
	_add_button(vbox, "GameSession出力", _on_dump_game_session)
	_add_button(vbox, "CardDB出力", _on_dump_card_db)
	_add_button(vbox, "balance.json保存（未実装）", func(): print("[システム] balance.json保存（未実装）"))
	
	# ConfigLoader
	_add_section_label(vbox, "ConfigLoader")
	_add_button(vbox, "balance.json再読込", _on_reload_config)
	_config_load_time_label = Label.new()
	_config_load_time_label.text = "[最終読込: 起動時]"
	vbox.add_child(_config_load_time_label)
	
	# シーン操作
	_add_section_label(vbox, "シーン操作")
	_add_button(vbox, "バトル再開始（未実装）", func(): print("[システム] バトル再開始（未実装）"))
	_add_button(vbox, "タイトルに戻る", _on_goto_title)
	_add_button(vbox, "マップに戻る（未実装）", func(): print("[システム] マップに戻る（未実装）"))

func _add_section_label(parent: VBoxContainer, title: String) -> void:
	var label = Label.new()
	label.text = "── " + title + " ──"
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)

func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _add_checkbox(parent: VBoxContainer, text: String, initial: bool, callback: Callable) -> CheckButton:
	var checkbox = CheckButton.new()
	checkbox.text = text
	checkbox.button_pressed = initial
	checkbox.toggled.connect(callback)
	parent.add_child(checkbox)
	return checkbox

# 速度制御
func _set_speed(speed: float) -> void:
	_current_speed = speed
	Engine.time_scale = speed
	print("[システム] ゲーム速度: x%.1f" % speed)

# 状態ダンプ
func _on_dump_game_session() -> void:
	print("[システム] === GameSession ダンプ ===")
	print("  class_id: ", GameSession.class_id)
	print("  gold: ", GameSession.gold)
	print("  skill_points: ", GameSession.skill_points)
	print("  run_depth: ", GameSession.run_depth)
	print("  alert_level: ", GameSession.alert_level)
	print("  current_act: ", GameSession.current_act)
	print("  battle_type: ", GameSession.battle_type)
	print("  selected_deck.size(): ", GameSession.selected_deck.size())
	print("  artifacts.size(): ", GameSession.artifacts.size())
	print("  Godモード: invincible=%s, infinite_mana=%s, infinite_time=%s, auto_win=%s" % [
		GameSession.god_mode_invincible,
		GameSession.god_mode_infinite_mana,
		GameSession.god_mode_infinite_time,
		GameSession.god_mode_auto_win
	])
	print("=================================")

func _on_dump_card_db() -> void:
	print("[システム] === CardDB ダンプ ===")
	print("  loaded: ", CardDB._loaded)
	print("  units.size(): ", CardDB.units.size())
	print("  spells.size(): ", CardDB.spells.size())
	print("  artifacts.size(): ", CardDB.artifacts.size())
	print("  bosses.size(): ", CardDB.bosses.size())
	print("=================================")

# ConfigLoader再読込
func _on_reload_config() -> void:
	ConfigLoader.reload_config()
	var time = Time.get_datetime_string_from_system()
	_config_load_time_label.text = "[最終読込: %s]" % time
	print("[システム] ConfigLoader再読込完了: ", time)

# シーン操作
func _on_goto_title() -> void:
	GameSession.reset()
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
	print("[システム] タイトルに戻る")
