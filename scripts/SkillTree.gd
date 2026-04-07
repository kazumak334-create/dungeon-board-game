# SkillTree.gd
# スキルツリー画面（タスクバー📖から遷移）
# synthesis_tree_draft.md のT1-T4スキル体系
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)

	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.SKILL_TREE)

	var title = Label.new()
	title.text = "スキルツリー"
	title.position = Vector2(0, 50)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIF.TITLE_COLOR)
	add_child(title)

	# TODO: T1-T4スキルツリー表示（Phase 3実装）
	var placeholder = Label.new()
	placeholder.text = "（スキルツリー T1-T4: Phase 3で実装予定）"
	placeholder.position = Vector2(0, 300)
	placeholder.size = Vector2(1280, 40)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.add_theme_font_size_override("font_size", 16)
	placeholder.add_theme_color_override("font_color", UIF.DIM_COLOR)
	add_child(placeholder)

	var back_btn = Button.new()
	back_btn.text = "戻る"
	back_btn.position = Vector2(590, 650)
	back_btn.size = Vector2(100, 36)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _on_back() -> void:
	var prev = GameSession.last_scene
	if prev == "":
		prev = SceneManager.MAP_SELECT
	SceneManager.go_to(prev)
