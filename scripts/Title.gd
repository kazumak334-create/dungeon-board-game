# Title.gd
# TOP画面: クラス選択 + 出発
extends Control

const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null
var _selected_class_id: String = ""
var _class_buttons: Dictionary = {}
var _description_label: Label
var _skill_label: Label
var _start_button: Button
var _is_first_show: bool = true  # アニメーション制御用

# フェードイン対象ノード
var _title_node: Control = null
var _subtitle_node: Label = null
var _class_container: Control = null

func _ready() -> void:
	_build_ui()
	# デフォルト選択
	var class_ids = CardDB.CLASSES.keys()
	if class_ids.size() > 0:
		_select_class(class_ids[0])
	# フェードインアニメーション
	_play_intro_animation()

func _build_ui() -> void:
	_build_background()

	# 共通タスクバー（最上部36px）
	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.TITLE)

	_build_title_area()
	_build_class_cards()
	_build_description_area()
	_build_start_button()
	_build_footer()

# ===== UIビルダー関数 =====

func _build_background() -> void:
	# 背景色
	var bg_color = ColorRect.new()
	bg_color.color = UIColors.COLOR_BG
	bg_color.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_color)

	# 背景画像（オプション）
	var bg_image_path = "res://assets/ui/title_bg.png"
	if FileAccess.file_exists(bg_image_path):
		var bg_image = TextureRect.new()
		bg_image.texture = load(bg_image_path)
		bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_image.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg_image)

	# オーバーレイ
	var bg_overlay = ColorRect.new()
	bg_overlay.color = UIColors.COLOR_OVERLAY
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_overlay)

func _build_title_area() -> void:
	# ロゴ画像（オプション）
	var logo_path = "res://assets/ui/title_logo.png"
	if FileAccess.file_exists(logo_path):
		_title_node = TextureRect.new()
		_title_node.texture = load(logo_path)
		_title_node.position = Vector2(340, 60)
		_title_node.size = Vector2(600, 120)
		add_child(_title_node)
	else:
		# 代替ラベル
		var title_label = Label.new()
		title_label.text = "DUNGEON BOARD GAME"
		title_label.position = Vector2(0, 70)
		title_label.size = Vector2(1280, 80)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 42)
		title_label.add_theme_color_override("font_color", UIColors.COLOR_TITLE)
		var font_path = "res://assets/fonts/trajan.ttf"
		if FileAccess.file_exists(font_path):
			var font = load(font_path)
			title_label.add_theme_font_override("font", font)
		add_child(title_label)
		_title_node = title_label

	# サブタイトル
	_subtitle_node = Label.new()
	_subtitle_node.text = "盤面を設計し、観戦せよ"
	_subtitle_node.position = Vector2(0, 185)
	_subtitle_node.size = Vector2(1280, 30)
	_subtitle_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_node.add_theme_font_size_override("font_size", 16)
	_subtitle_node.add_theme_color_override("font_color", UIColors.COLOR_SUBTITLE)
	var pixel_font_path = "res://assets/fonts/PixelMplus10-Regular.ttf"
	if FileAccess.file_exists(pixel_font_path):
		var pixel_font = load(pixel_font_path)
		_subtitle_node.add_theme_font_override("font", pixel_font)
	add_child(_subtitle_node)

func _build_class_cards() -> void:
	_class_container = HBoxContainer.new()
	_class_container.position = Vector2(165, 240)
	_class_container.size = Vector2(950, 220)
	_class_container.add_theme_constant_override("separation", 30)
	add_child(_class_container)

	for class_id in CardDB.CLASSES:
		var cls = CardDB.CLASSES[class_id]
		var card = _create_class_card(class_id, cls)
		_class_container.add_child(card)
		_class_buttons[class_id] = card

func _build_description_area() -> void:
	# パネル背景
	var desc_panel = PanelContainer.new()
	desc_panel.position = Vector2(290, 475)
	desc_panel.size = Vector2(700, 60)
	add_child(desc_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = UIColors.COLOR_PANEL_DARK
	panel_style.border_color = UIColors.COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	desc_panel.add_theme_stylebox_override("panel", panel_style)

	# VBoxコンテナ
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	desc_panel.add_child(vbox)

	# クラス説明
	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_description_label.add_theme_font_size_override("font_size", 14)
	_description_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT)
	vbox.add_child(_description_label)

	# パッシブスキル
	_skill_label = Label.new()
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_skill_label.add_theme_font_size_override("font_size", 13)
	_skill_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	vbox.add_child(_skill_label)

func _build_start_button() -> void:
	_start_button = Button.new()
	_start_button.text = "出  発"
	_start_button.position = Vector2(465, 555)
	_start_button.size = Vector2(350, 60)
	_start_button.disabled = true  # 初期状態はdisabled
	_start_button.modulate = Color(0.5, 0.5, 0.5)  # 初期状態は半透明
	_start_button.add_theme_font_size_override("font_size", 26)
	_start_button.pressed.connect(_on_start_pressed)
	add_child(_start_button)

	# フォント読み込み
	var font_path = "res://assets/fonts/trajan.ttf"
	if FileAccess.file_exists(font_path):
		var font = load(font_path)
		_start_button.add_theme_font_override("font", font)

	# normal スタイル
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = UIColors.COLOR_BTN_BG
	normal_style.border_color = UIColors.COLOR_SELECTED
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(6)
	_start_button.add_theme_stylebox_override("normal", normal_style)

	# hover スタイル
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = UIColors.COLOR_BTN_HOVER
	hover_style.border_color = UIColors.COLOR_SELECTED
	hover_style.set_border_width_all(3)
	hover_style.set_corner_radius_all(6)
	_start_button.add_theme_stylebox_override("hover", hover_style)

func _build_footer() -> void:
	# バージョン表記
	var version_label = Label.new()
	version_label.text = "ver 0.x.x"
	version_label.position = Vector2(20, 690)
	version_label.size = Vector2(200, 25)
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", UIColors.COLOR_DIM)
	add_child(version_label)

	# 開発者モードボタン
	var dev_button = Button.new()
	dev_button.text = "開発者モード"
	dev_button.position = Vector2(1080, 685)
	dev_button.size = Vector2(180, 30)
	dev_button.modulate = Color(1, 1, 1, 0.4)
	dev_button.add_theme_font_size_override("font_size", 12)
	dev_button.pressed.connect(_on_dev_mode_pressed)
	add_child(dev_button)

# ===== クラスカード生成 =====

func _create_class_card(class_id: String, cls: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 220)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = UIColors.COLOR_PANEL
	style_normal.border_color = UIColors.COLOR_BORDER
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style_normal)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# クラスアイコン（プレースホルダ）
	var icon_path = "res://assets/ui/class_icon_%s.png" % class_id
	var icon_container = Control.new()
	icon_container.custom_minimum_size = Vector2(280, 80)

	if FileAccess.file_exists(icon_path):
		var icon = TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(80, 80)
		icon.position = Vector2(100, 0)  # 中央揃え（280/2 - 80/2）
		icon_container.add_child(icon)
	else:
		# プレースホルダ
		var placeholder = ColorRect.new()
		placeholder.color = Color(0.12, 0.12, 0.18)
		placeholder.custom_minimum_size = Vector2(80, 80)
		placeholder.position = Vector2(100, 0)
		icon_container.add_child(placeholder)

	vbox.add_child(icon_container)

	# クラス名
	var name_label = Label.new()
	name_label.text = cls.get("display", class_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", UIColors.COLOR_DIM)  # 非選択時は暗く
	var font_path = "res://assets/fonts/trajan.ttf"
	if FileAccess.file_exists(font_path):
		var font = load(font_path)
		name_label.add_theme_font_override("font", font)
	vbox.add_child(name_label)

	# セパレータ
	var separator = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.25, 0.28, 0.35)
	separator.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(separator)

	# 一行説明
	var desc = Label.new()
	desc.text = cls.get("description", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.max_lines_visible = 2
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", UIColors.COLOR_TEXT)
	vbox.add_child(desc)

	panel.add_child(vbox)

	# ホバー処理
	panel.mouse_entered.connect(func():
		var hover_style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		hover_style.bg_color = Color(0.16, 0.16, 0.24)
	)
	panel.mouse_exited.connect(func():
		var normal_style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		normal_style.bg_color = UIColors.COLOR_PANEL
	)

	# クリック検出
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_class(class_id)
	)

	return panel

func _select_class(class_id: String) -> void:
	_selected_class_id = class_id
	var cls = CardDB.CLASSES.get(class_id, {})

	_description_label.text = cls.get("description", "")

	# スキル表示
	var skill_texts: Array = []
	var _edb = load("res://scripts/EffectDB.gd")
	for skill in cls.get("skills", []):
		var eid = skill.get("effect_id", "")
		var edef = _edb.EFFECTS.get(eid, {})
		skill_texts.append("▸ %s" % edef.get("display", eid))
	_skill_label.text = "パッシブスキル:\n" + "\n".join(skill_texts) if skill_texts.size() > 0 else ""

	# 出発ボタンを有効化
	_start_button.disabled = false
	_start_button.modulate = Color(1, 1, 1)

	# 選択枠とクラス名色の更新
	for cid in _class_buttons:
		var panel = _class_buttons[cid] as PanelContainer
		var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		var vbox = panel.get_child(0) as VBoxContainer
		# クラス名ラベルは2番目の子（icon_container, name_label, separator, desc）
		var name_label = vbox.get_child(1) as Label
		if cid == class_id:
			style.border_color = UIColors.COLOR_SELECTED
			style.set_border_width_all(3)
			name_label.add_theme_color_override("font_color", UIColors.COLOR_TITLE)
		else:
			style.border_color = UIColors.COLOR_BORDER
			style.set_border_width_all(2)
			name_label.add_theme_color_override("font_color", UIColors.COLOR_DIM)

func _on_start_pressed() -> void:
	if _selected_class_id == "":
		return
	GameSession.class_id = _selected_class_id
	SceneManager.go_to(SceneManager.MATERIAL_SELECT)

func _on_dev_mode_pressed() -> void:
	if _selected_class_id == "":
		return
	GameSession.class_id = _selected_class_id
	GameSession.dev_mode = true
	SceneManager.go_to(SceneManager.BATTLE)

# ===== アニメーション =====

func _play_intro_animation() -> void:
	if not _is_first_show:
		return
	_is_first_show = false

	# 初期状態設定
	if _title_node:
		_title_node.modulate.a = 0
	if _subtitle_node:
		_subtitle_node.modulate.a = 0
	if _class_container:
		_class_container.modulate.a = 0
		_class_container.position.y += 30
	if _start_button:
		_start_button.modulate.a = 0

	# Tween生成
	var tween = create_tween()
	tween.set_parallel(true)

	# タイトルロゴ/ラベル（0.8秒）
	if _title_node:
		tween.tween_property(_title_node, "modulate:a", 1.0, 0.8)

	# サブタイトル（0.5秒、delay=0.5秒）
	if _subtitle_node:
		tween.tween_property(_subtitle_node, "modulate:a", 1.0, 0.5).set_delay(0.5)

	# クラスカード群（0.4秒、delay=0.8秒）
	if _class_container:
		tween.tween_property(_class_container, "modulate:a", 1.0, 0.4).set_delay(0.8)
		var original_y = _class_container.position.y - 30
		tween.tween_property(_class_container, "position:y", original_y, 0.4).set_delay(0.8)

	# 出発ボタン（0.3秒、delay=1.2秒）
	# 注: クラス未選択時はdisabledなので半透明のまま。選択時に不透明化される
	if _start_button:
		var target_alpha = 0.5 if _start_button.disabled else 1.0
		tween.tween_property(_start_button, "modulate:a", target_alpha, 0.3).set_delay(1.2)
