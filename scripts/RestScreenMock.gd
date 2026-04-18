# RestScreenMock.gd
# RestScreen静的モック（レイアウト確認用）
extends Control

const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var _taskbar: RefCounted = null

func _ready() -> void:
	_build_mock_ui()

func _build_mock_ui() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 共通タスクバー（最上部36px）
	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, "rest_screen_mock")

	# ステータスバー（Y=0～88）
	_build_status_bar()

	# 盤面エリア（Y=88～373）
	_build_board_area()

	# 呪文デッキ編集エリア（Y=88～373・敵陣エリアに被せ）
	_build_spell_deck_editor()

	# 呪文キュー（Y=373付近・参考表示）
	_build_spell_queue()

	# 手持ちカードトレイ（Y=373～573）
	_build_card_tray()

	# カード合成UI（Y=573～653）
	_build_card_synthesis()

	# 戻るボタン
	_build_back_button()

func _build_status_bar() -> void:
	var bar = ColorRect.new()
	bar.color = Color(0.12, 0.12, 0.18)
	bar.position = Vector2(0, 36)
	bar.size = Vector2(1280, 52)
	add_child(bar)

	# Gold
	var gold_label = Label.new()
	gold_label.text = "💰 Gold: 450"
	gold_label.position = Vector2(20, 46)
	gold_label.size = Vector2(150, 30)
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	add_child(gold_label)

	# Wave
	var wave_label = Label.new()
	wave_label.text = "📊 Wave: 2/4 BW"
	wave_label.position = Vector2(190, 46)
	wave_label.size = Vector2(180, 30)
	wave_label.add_theme_font_size_override("font_size", 16)
	wave_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	add_child(wave_label)

	# Synergy
	var synergy_label = Label.new()
	synergy_label.text = "🎯 Synergy: Beast×3 (+15% ATK)"
	synergy_label.position = Vector2(390, 46)
	synergy_label.size = Vector2(350, 30)
	synergy_label.add_theme_font_size_override("font_size", 16)
	synergy_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	add_child(synergy_label)

	# ボタン類（右側に配置）
	var start_btn = Button.new()
	start_btn.text = "Wave開始"
	start_btn.position = Vector2(1110, 46)
	start_btn.size = Vector2(150, 35)
	start_btn.add_theme_font_size_override("font_size", 14)
	add_child(start_btn)

	var shop_btn = Button.new()
	shop_btn.text = "ショップ"
	shop_btn.position = Vector2(950, 46)
	shop_btn.size = Vector2(140, 35)
	shop_btn.add_theme_font_size_override("font_size", 14)
	add_child(shop_btn)

func _build_board_area() -> void:
	# 自陣盤面（3列×3行、130×95px）
	# X座標: 後列=370, 中列=500, 前列=630
	# Y座標: 上行=88, 中行=183, 下行=278
	var cell_positions = [
		# 後列
		Vector2(370, 88), Vector2(370, 183), Vector2(370, 278),
		# 中列
		Vector2(500, 88), Vector2(500, 183), Vector2(500, 278),
		# 前列
		Vector2(630, 88), Vector2(630, 183), Vector2(630, 278),
	]
	var cell_labels = [
		"[U]\nHP120\nATK40", "[U]\nHP100", "空",
		"[U]\nHP80", "空", "[U]\nHP90",
		"[U]\nHP60", "[U]\nHP70", "[U]\nHP50"
	]

	for i in range(9):
		var cell = PanelContainer.new()
		cell.position = cell_positions[i]
		cell.size = Vector2(130, 95)

		var style = StyleBoxFlat.new()
		if cell_labels[i] == "空":
			style.bg_color = Color(0.1, 0.1, 0.15, 0.5)
			style.border_color = Color(0.3, 0.3, 0.4)
			style.set_border_width_all(1)
		else:
			style.bg_color = Color(0.15, 0.2, 0.25)
			style.border_color = Color(0.4, 0.5, 0.6)
			style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		cell.add_theme_stylebox_override("panel", style)

		var label = Label.new()
		label.text = cell_labels[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		cell.add_child(label)

		add_child(cell)

func _build_spell_deck_editor() -> void:
	# 敵陣エリア（X=0～240）に配置
	var editor_bg = PanelContainer.new()
	editor_bg.position = Vector2(10, 88)
	editor_bg.size = Vector2(220, 285)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.2)
	style.border_color = Color(0.4, 0.6, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	editor_bg.add_theme_stylebox_override("panel", style)
	add_child(editor_bg)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	editor_bg.add_child(vbox)

	# タイトル
	var title = Label.new()
	title.text = "呪文デッキ編集"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	vbox.add_child(title)

	# 呪文リスト（例）
	var spells = ["×3 🔥ファイア", "×2 ⚡サンダー", "×5 💧ヒール", "×4 🌪️竜巻"]
	for spell in spells:
		var spell_label = Label.new()
		spell_label.text = spell
		spell_label.add_theme_font_size_override("font_size", 12)
		spell_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
		vbox.add_child(spell_label)

func _build_spell_queue() -> void:
	# 呪文キュー（参考表示）Y=373付近
	var queue_label = Label.new()
	queue_label.text = "呪文キュー（参考）："
	queue_label.position = Vector2(20, 378)
	queue_label.size = Vector2(200, 20)
	queue_label.add_theme_font_size_override("font_size", 12)
	queue_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	add_child(queue_label)

	var queue_slots = ["🔥ファイア", "⚡サンダー", "💧ヒール"]
	for i in range(3):
		var slot = PanelContainer.new()
		slot.position = Vector2(20 + i * 150, 400)
		slot.size = Vector2(140, 60)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.2)
		style.border_color = Color(0.5, 0.5, 0.6)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", style)

		var label = Label.new()
		label.text = queue_slots[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		slot.add_child(label)

		add_child(slot)

func _build_card_tray() -> void:
	# 手持ちカードトレイ（Y=480～680）
	var tray_bg = PanelContainer.new()
	tray_bg.position = Vector2(10, 480)
	tray_bg.size = Vector2(1260, 200)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16)
	style.border_color = Color(0.3, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	tray_bg.add_theme_stylebox_override("panel", style)
	add_child(tray_bg)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	tray_bg.add_child(vbox)

	# タブボタン
	var tab_container = HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 10)
	vbox.add_child(tab_container)

	var unit_tab = Button.new()
	unit_tab.text = "ユニット"
	unit_tab.custom_minimum_size = Vector2(120, 30)
	tab_container.add_child(unit_tab)

	var spell_tab = Button.new()
	spell_tab.text = "呪文"
	spell_tab.custom_minimum_size = Vector2(120, 30)
	tab_container.add_child(spell_tab)

	# カード一覧（例）
	var card_container = HBoxContainer.new()
	card_container.add_theme_constant_override("separation", 10)
	vbox.add_child(card_container)

	var cards = [
		"Common\nHP100\nATK15",
		"Rare 💀\nHP0\n💰80G復帰",
		"Uncommon\nHP80\nATK25"
	]

	for card_text in cards:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(110, 140)

		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.15, 0.18, 0.22)
		card_style.border_color = Color(0.4, 0.5, 0.6)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(4)
		card.add_theme_stylebox_override("panel", card_style)

		var label = Label.new()
		label.text = card_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
		card.add_child(label)

		card_container.add_child(card)

func _build_card_synthesis() -> void:
	# カード合成UI（Y=690～720の30px）
	var synthesis_bg = ColorRect.new()
	synthesis_bg.color = Color(0.12, 0.14, 0.18)
	synthesis_bg.position = Vector2(0, 690)
	synthesis_bg.size = Vector2(1280, 30)
	add_child(synthesis_bg)

	var label = Label.new()
	label.text = "カード合成：[選択1] + [選択2] → [合成実行]（未選択）"
	label.position = Vector2(20, 690)
	label.size = Vector2(1000, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	add_child(label)

func _build_back_button() -> void:
	var back_btn = Button.new()
	back_btn.text = "← タイトルに戻る"
	back_btn.position = Vector2(1080, 5)
	back_btn.size = Vector2(190, 30)
	back_btn.add_theme_font_size_override("font_size", 12)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

func _on_back_pressed() -> void:
	SceneManager.go_to(SceneManager.TITLE)
