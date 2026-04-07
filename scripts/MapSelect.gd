# MapSelect.gd
# マップ選択画面（Phase 3 MVP版）: 各ノード種別への遷移
# TODO Phase 3本実装: MapGenerator.gd と連携した横StS風分岐ツリー
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	# 共通タスクバー（最上部36px）
	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.MAP_SELECT)

	UIF.add_title(self, "マップ", 50)

	# 環境が未設定ならランダム選択（ボス区間開始時）
	if GameSession.base_environment == "" or GameSession.base_environment == "env_none":
		_randomize_environment()

	# 環境表示
	var env_def = CardDB.ENVIRONMENTS.get(GameSession.base_environment, {})
	var env_display = env_def.get("display", "平原")
	var env_desc = env_def.get("description", "")
	var env_label = Label.new()
	env_label.text = "環境: %s ─ %s" % [env_display, env_desc]
	env_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	env_label.position = Vector2(0, 85)
	env_label.size = Vector2(1280, 25)
	env_label.add_theme_font_size_override("font_size", 14)
	env_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	add_child(env_label)

	# 仮マップ表示
	var map_label = Label.new()
	map_label.text = "[ 戦闘 ] ─ [ 素材 ] ─ [ イベント ] ─ [ ショップ ] ─ [ エリート ] ─ [ ボス ]"
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.position = Vector2(0, 110)
	map_label.size = Vector2(1280, 25)
	map_label.add_theme_font_size_override("font_size", 14)
	map_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(map_label)

	# ノードボタン群
	var nodes = [
		{"text": "戦闘", "scene": "battle", "color": Color(0.8, 0.3, 0.3), "desc": "通常の敵と戦う"},
		{"text": "エリート", "scene": "battle_elite", "color": Color(0.9, 0.5, 0.2), "desc": "強敵+良報酬"},
		{"text": "素材採集", "scene": "gather", "color": Color(0.3, 0.7, 0.4), "desc": "素材を入手"},
		{"text": "ショップ", "scene": "shop", "color": Color(0.9, 0.8, 0.3), "desc": "素材やカードを売買"},
		{"text": "イベント", "scene": "event", "color": Color(0.5, 0.5, 0.9), "desc": "ランダムな出来事"},
		{"text": "ボス", "scene": "battle_boss", "color": Color(0.9, 0.2, 0.5), "desc": "エリアボスと戦う"},
	]

	var start_y = 170
	for i in range(nodes.size()):
		var node = nodes[i]
		var panel = PanelContainer.new()
		panel.position = Vector2(290, start_y + i * 80)
		panel.size = Vector2(700, 65)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.18)
		style.set_corner_radius_all(6)
		style.set_border_width_all(2)
		style.border_color = node["color"] * 0.6
		panel.add_theme_stylebox_override("panel", style)
		add_child(panel)

		var node_label = Label.new()
		node_label.text = node["text"]
		node_label.position = Vector2(310, start_y + i * 80 + 8)
		node_label.add_theme_font_size_override("font_size", 20)
		node_label.add_theme_color_override("font_color", node["color"])
		add_child(node_label)

		var desc_label = Label.new()
		desc_label.text = node["desc"]
		desc_label.position = Vector2(310, start_y + i * 80 + 35)
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		add_child(desc_label)

		var btn = Button.new()
		btn.text = "→"
		btn.position = Vector2(900, start_y + i * 80 + 12)
		btn.size = Vector2(60, 40)
		btn.add_theme_font_size_override("font_size", 20)
		var scene_id = node["scene"]
		btn.pressed.connect(func(): _go_to_node(scene_id))
		add_child(btn)

	UIF.add_back_button(self, "← デッキ準備", func(): SceneManager.go_to(SceneManager.DECK_PREP), 640)

func _randomize_environment() -> void:
	var env_ids = CardDB.ENVIRONMENTS.keys()
	if env_ids.size() > 0:
		env_ids.shuffle()
		GameSession.base_environment = env_ids[0]

func _go_to_node(scene_id: String) -> void:
	match scene_id:
		"battle":
			GameSession.battle_type = "normal"
			SceneManager.go_to(SceneManager.BATTLE)
		"battle_elite":
			GameSession.battle_type = "elite"
			SceneManager.go_to(SceneManager.BATTLE)
		"battle_boss":
			GameSession.battle_type = "boss"
			SceneManager.go_to(SceneManager.BATTLE)
		_:
			SceneManager.go_to(scene_id)
