# UIFactory.gd
# 画面共通UIパーツ生成ユーティリティ
extends Control

# 共通色定義
const BG_COLOR       := Color(0.08, 0.08, 0.12)
const TITLE_COLOR    := Color(0.9, 0.85, 0.6)
const SUBTITLE_COLOR := Color(0.6, 0.7, 0.9)
const TEXT_COLOR     := Color(0.8, 0.8, 0.8)
const DIM_COLOR      := Color(0.5, 0.5, 0.5)
const BENEFIT_COLOR  := Color(0.4, 0.85, 0.5)
const DEMERIT_COLOR  := Color(0.9, 0.35, 0.35)
const GOLD_COLOR     := Color(0.9, 0.8, 0.3)
const PANEL_BG       := Color(0.1, 0.1, 0.15)
const PANEL_BORDER   := Color(0.25, 0.25, 0.35)

# 全画面共通の背景
static func add_bg(parent: Control, color: Color = BG_COLOR) -> ColorRect:
	var bg = ColorRect.new()
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	return bg

# 画面タイトル（中央上部）
static func add_title(parent: Control, text: String, y: int = 40, font_size: int = 28, color: Color = TITLE_COLOR) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, y)
	label.size = Vector2(1280, 40)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

# サブタイトル / 補足テキスト
static func add_subtitle(parent: Control, text: String, y: int, color: Color = SUBTITLE_COLOR) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, y)
	label.size = Vector2(1280, 25)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

# パネル（角丸+枠線）
static func create_panel(pos: Vector2, sz: Vector2, bg_color: Color = PANEL_BG, border_color: Color = PANEL_BORDER, border_width: int = 1, corner_radius: int = 6) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = pos
	panel.size = sz
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(corner_radius)
	style.set_border_width_all(border_width)
	style.border_color = border_color
	panel.add_theme_stylebox_override("panel", style)
	return panel

# ボタン
static func add_button(parent: Control, text: String, pos: Vector2, sz: Vector2, font_size: int = 22, callback: Callable = Callable()) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = sz
	btn.add_theme_font_size_override("font_size", font_size)
	if callback.is_valid():
		btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

# 「← 戻る」ボタン（左下固定）
static func add_back_button(parent: Control, text: String, callback: Callable, y: int = 550) -> Button:
	return add_button(parent, text, Vector2(40, y), Vector2(180, 45), 16, callback)
