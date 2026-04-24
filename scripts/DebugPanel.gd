# DebugPanel.gd
# AutoLoad: F12トグルで表示・非表示を切り替えるデバッグパネル
extends CanvasLayer

const DebugParamTabScript = preload("res://scripts/debug/DebugParamTab.gd")
const DebugCheatTabScript = preload("res://scripts/debug/DebugCheatTab.gd")
const DebugSystemTabScript = preload("res://scripts/debug/DebugSystemTab.gd")

# UI要素
var _panel: Panel
var _tab_container: TabContainer
var _param_tab: DebugParamTabScript
var _cheat_tab: DebugCheatTabScript
var _system_tab: DebugSystemTabScript

var _visible: bool = false

func _ready() -> void:
	_build_ui()
	hide()  # 初期状態は非表示
	print("[DebugPanel] 初期化完了（F12でトグル）")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			toggle()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	_visible = not _visible
	if _visible:
		show()
		print("[DebugPanel] 表示")
	else:
		hide()
		print("[DebugPanel] 非表示")

func _build_ui() -> void:
	# CanvasLayer は layer=100 で最前面に表示
	layer = 100
	
	# 背景パネル（右寄せ）
	_panel = Panel.new()
	_panel.position = Vector2(880, 20)
	_panel.size = Vector2(380, 680)
	add_child(_panel)
	
	# タイトルバー
	var title_bar = HBoxContainer.new()
	title_bar.position = Vector2(10, 5)
	title_bar.size = Vector2(360, 30)
	_panel.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "Debug Panel"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_label)
	
	var close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.pressed.connect(_on_close_pressed)
	title_bar.add_child(close_button)
	
	# タブコンテナ
	_tab_container = TabContainer.new()
	_tab_container.position = Vector2(10, 40)
	_tab_container.size = Vector2(360, 630)
	_panel.add_child(_tab_container)
	
	# タブ作成
	_param_tab = DebugParamTabScript.new()
	_param_tab.name = "パラメータ"
	_tab_container.add_child(_param_tab)
	
	_cheat_tab = DebugCheatTabScript.new()
	_cheat_tab.name = "チート"
	_tab_container.add_child(_cheat_tab)
	
	_system_tab = DebugSystemTabScript.new()
	_system_tab.name = "システム"
	_tab_container.add_child(_system_tab)

func _on_close_pressed() -> void:
	toggle()
