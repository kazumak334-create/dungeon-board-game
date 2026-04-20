# SkillTree.gd
# スキルツリー画面（6階層ランダム生成・横ツリー表示）
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")
const SkillTreeGeneratorClass = preload("res://scripts/SkillTreeGenerator.gd")

var _taskbar: Node = null
var _tree_data: Dictionary = {}
var _node_panels: Dictionary = {}  # id -> PanelContainer
var _sp_label: Label

func _ready() -> void:
	_generate_or_load_tree()
	_build_ui()

func _generate_or_load_tree() -> void:
	# GameSessionにツリーデータがあればロード、なければ生成
	if GameSession.skill_tree_data.size() > 0:
		_tree_data = GameSession.skill_tree_data
	else:
		var generator = SkillTreeGeneratorClass.new()
		var seed_value = randi()
		_tree_data = generator.generate(seed_value, GameSession.class_id)
		GameSession.skill_tree_data = _tree_data

func _build_ui() -> void:
	UIF.add_bg(self)

	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.SKILL_TREE)

	# タイトル
	var title = Label.new()
	title.text = "スキルツリー"
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(title)

	# SP表示
	_sp_label = Label.new()
	_sp_label.text = "SP: %d" % GameSession.skill_points
	_sp_label.position = Vector2(20, 75)
	_sp_label.size = Vector2(200, 25)
	_sp_label.add_theme_font_size_override("font_size", 18)
	_sp_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	add_child(_sp_label)

	# ツリー表示エリア（スクロール）
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 105)
	scroll.size = Vector2(1240, 540)
	add_child(scroll)

	var tree_container = Control.new()
	tree_container.custom_minimum_size = Vector2(1400, 600)
	scroll.add_child(tree_container)

	# ノードを配置
	_draw_tree(tree_container)

	# 戻るボタン
	var back_btn = Button.new()
	back_btn.text = "戻る"
	back_btn.position = Vector2(590, 655)
	back_btn.size = Vector2(100, 36)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _draw_tree(container: Control) -> void:
	var nodes = _tree_data.get("nodes", [])

	# ノードをパネル化して配置
	for node in nodes:
		var panel = _create_node_panel(node)
		var pos = node.get("position", {"x": 0, "y": 0})
		panel.position = Vector2(pos["x"], pos["y"])
		container.add_child(panel)
		_node_panels[node["id"]] = panel

	# 前提スキルとの線を描画（簡易版：省略してもよい）
	# TODO: 線を引く場合はLine2Dなどで実装

func _create_node_panel(node: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 120)

	var is_unlocked = node["id"] in GameSession.unlocked_skills
	var can_unlock = _can_unlock(node)
	var is_card = node.get("reward_type", "stat") == "card"

	# スタイル
	var style = StyleBoxFlat.new()
	if is_unlocked:
		style.bg_color = Color(0.2, 0.4, 0.2)
		style.border_color = Color(0.4, 0.8, 0.4)
	elif can_unlock:
		style.bg_color = Color(0.15, 0.15, 0.22)
		style.border_color = Color(0.9, 0.75, 0.3) if is_card else Color(0.5, 0.5, 0.7)
	else:
		style.bg_color = Color(0.1, 0.1, 0.15)
		style.border_color = Color(0.3, 0.3, 0.4)

	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# 階層+コスト
	var tier_label = Label.new()
	tier_label.text = "T%d (SP:%d)" % [node["tier"], node["cost"]]
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(tier_label)

	# 名前
	var name_label = Label.new()
	name_label.text = node["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(name_label)

	# 説明
	var desc_label = Label.new()
	desc_label.text = node["description"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(desc_label)

	# カード報酬表示
	if is_card:
		var card_label = Label.new()
		card_label.text = "報酬: %s" % node.get("reward_card", "???")
		card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_label.add_theme_font_size_override("font_size", 11)
		card_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		vbox.add_child(card_label)

	# 解放ボタン
	if can_unlock and not is_unlocked:
		var unlock_btn = Button.new()
		unlock_btn.text = "解放"
		unlock_btn.add_theme_font_size_override("font_size", 12)
		var node_id = node["id"]
		unlock_btn.pressed.connect(func(): _unlock_skill(node_id))
		vbox.add_child(unlock_btn)
	elif is_unlocked:
		var status_label = Label.new()
		status_label.text = "解放済み"
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 11)
		status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		vbox.add_child(status_label)

	panel.add_child(vbox)
	return panel

func _can_unlock(node: Dictionary) -> bool:
	# 前提スキルが全て解放済みか確認
	var prereqs = node.get("prerequisites", [])
	for prereq_id in prereqs:
		if prereq_id not in GameSession.unlocked_skills:
			return false
	# SPが足りるか確認
	if GameSession.skill_points < node["cost"]:
		return false
	return true

func _unlock_skill(node_id: String) -> void:
	var nodes = _tree_data.get("nodes", [])
	var target_node = null
	for node in nodes:
		if node["id"] == node_id:
			target_node = node
			break

	if target_node == null:
		return

	# SP消費
	GameSession.skill_points -= target_node["cost"]
	# 解放済みリストに追加
	GameSession.unlocked_skills.append(node_id)

	# カード報酬の場合、デッキに追加
	if target_node.get("reward_type", "") == "card":
		var card_name = target_node.get("reward_card", "")
		if card_name != "":
			GameSession.selected_deck.append({"name": card_name, "col": 1})

	# UI再構築
	_rebuild_ui()

func _rebuild_ui() -> void:
	# 子ノードを全削除して再構築
	for child in get_children():
		child.queue_free()
	_build_ui()

func _on_back() -> void:
	var prev = GameSession.last_scene
	if prev == "":
		prev = SceneManager.MAP_SELECT
	SceneManager.go_to(prev)
