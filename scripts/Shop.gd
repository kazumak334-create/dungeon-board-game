# Shop.gd
# ショップ画面: ユニット・呪文・素材をゴールドで購入
extends Control

const UIF = preload("res://scripts/UIFactory.gd")

# 色定義（MaterialSelect.gdのスタイルを踏襲）
const COLOR_BG         := Color(0.08, 0.08, 0.12)
const COLOR_PANEL      := Color(0.13, 0.13, 0.2)
const COLOR_BORDER     := Color(0.3, 0.3, 0.4)
const COLOR_SELECTED   := Color(0.9, 0.75, 0.3)
const COLOR_TITLE      := Color(0.9, 0.85, 0.6)
const COLOR_TEXT       := Color(0.8, 0.8, 0.8)
const COLOR_PRICE      := Color(0.9, 0.8, 0.3)
const COLOR_SOLDOUT    := Color(0.4, 0.1, 0.1)

static func get_reroll_cost() -> int:
	return ConfigLoader.get_value("shop", "reroll_cost", 50)

var _goods: Array = []           # 現在表示中の商品配列
var _purchased: Array = []       # 購入済みインデックス
var _gold_label: Label           # 所持金表示
var _goods_panels: Array = []    # 商品パネル配列
var _cards_container: HBoxContainer  # 商品カードコンテナ
var _reroll_btn: Button          # リロールボタン

func _ready() -> void:
	_generate_goods()
	_build_ui()

# 商品をランダム生成（ユニット・呪文・素材から3〜5個）
func _generate_goods() -> void:
	_goods = []
	_purchased = []
	var count = randi() % 3 + 3  # 3-5個

	var all_cards: Array = []
	# ユニット
	for uid in CardDB.UNITS.keys():
		var u = CardDB.UNITS[uid]
		all_cards.append({"type": "unit", "id": uid, "data": u})
	# 呪文
	for sid in CardDB.SPELLS.keys():
		var s = CardDB.SPELLS[sid]
		all_cards.append({"type": "spell", "id": sid, "data": s})
	# 素材
	for mat in CardDB.MATERIALS:
		all_cards.append({"type": "material", "id": mat.get("id", ""), "data": mat})

	all_cards.shuffle()
	for i in range(min(count, all_cards.size())):
		_goods.append(all_cards[i])

# 商品の価格計算（レアリティベース）
func _get_price(item: Dictionary) -> int:
	var t = item.get("type", "")
	var data = item.get("data", {})
	var rarity = data.get("rarity", "common")
	var rarity_price = ConfigLoader.get_value("shop", "rarity_price", {
		"common": 50,
		"uncommon": 100,
		"rare": 200,
		"epic": 400,
		"legend": 800
	})
	return rarity_price.get(rarity, 50)

func _build_ui() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# タイトル
	var title = Label.new()
	title.text = "ショップ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	add_child(title)

	# 所持金表示
	_gold_label = Label.new()
	_gold_label.text = "所持金: %dG" % GameSession.gold
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.position = Vector2(0, 72)
	_gold_label.size = Vector2(1280, 30)
	_gold_label.add_theme_font_size_override("font_size", 20)
	_gold_label.add_theme_color_override("font_color", COLOR_PRICE)
	add_child(_gold_label)

	# 商品カードコンテナ
	_cards_container = HBoxContainer.new()
	_cards_container.position = Vector2(80, 120)
	_cards_container.size = Vector2(1120, 320)
	_cards_container.add_theme_constant_override("separation", 20)
	add_child(_cards_container)

	_goods_panels = []
	for i in range(_goods.size()):
		var panel = _create_good_panel(i, _goods[i])
		_cards_container.add_child(panel)
		_goods_panels.append(panel)

	# リロールボタン
	_reroll_btn = Button.new()
	_reroll_btn.text = "商品入れ替え: %dG" % get_reroll_cost()
	_reroll_btn.position = Vector2(490, 460)
	_reroll_btn.size = Vector2(300, 50)
	_reroll_btn.add_theme_font_size_override("font_size", 18)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	add_child(_reroll_btn)

	# 戻るボタン
	var back_button = Button.new()
	back_button.text = "← マップへ"
	back_button.position = Vector2(40, 530)
	back_button.size = Vector2(180, 45)
	back_button.add_theme_font_size_override("font_size", 16)
	back_button.pressed.connect(func(): SceneManager.go_to(SceneManager.MAP_SELECT))
	add_child(back_button)

# 商品パネル作成
func _create_good_panel(index: int, item: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 320)

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var data = item.get("data", {})
	var t = item.get("type", "")

	# タイプ表示
	var type_label = Label.new()
	if t == "unit":
		type_label.text = "ユニット"
		type_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	elif t == "spell":
		type_label.text = "呪文"
		type_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
	elif t == "material":
		type_label.text = "素材"
		type_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(type_label)

	# 名前
	var name_label = Label.new()
	name_label.text = data.get("display", item.get("id", "???"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", COLOR_TITLE)
	vbox.add_child(name_label)

	# 説明
	var desc_label = Label.new()
	var desc_text = ""
	if t == "unit":
		var atk = data.get("atk", 0)
		var hp = data.get("hp", 0)
		var spd = data.get("spd", 1.0)
		desc_text = "ATK:%d HP:%d\nSPD:%.1f" % [atk, hp, spd]
		var skill = data.get("skill", "")
		if skill != "":
			desc_text += "\n%s" % skill
	elif t == "spell":
		desc_text = data.get("effect_text", "")
	elif t == "material":
		desc_text = data.get("description", "")

	desc_label.text = desc_text
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(desc_label)

	# 価格
	var price = _get_price(item)
	var price_label = Label.new()
	price_label.text = "価格: %dG" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.add_theme_color_override("font_color", COLOR_PRICE)
	vbox.add_child(price_label)

	# 購入ボタン
	var buy_btn = Button.new()
	buy_btn.text = "購入"
	buy_btn.add_theme_font_size_override("font_size", 16)
	buy_btn.pressed.connect(func(): _on_buy_pressed(index))
	vbox.add_child(buy_btn)

	panel.add_child(vbox)
	return panel

# 購入ボタン押下
func _on_buy_pressed(index: int) -> void:
	if index in _purchased:
		return

	var item = _goods[index]
	var price = _get_price(item)

	if GameSession.gold < price:
		print("[Shop] 所持金不足")
		return

	# 購入処理
	GameSession.gold -= price
	_purchased.append(index)

	# デッキに追加
	var t = item.get("type", "")
	var id = item.get("id", "")
	if t == "unit":
		GameSession.selected_deck.append({"name": id, "col": 1})
	elif t == "spell":
		GameSession.selected_deck.append({"name": id, "col": -1})
	# 素材購入は廃止（装備・素材システム廃止により削除）

	_update_ui()

# リロールボタン押下
func _on_reroll_pressed() -> void:
	var reroll_cost = get_reroll_cost()
	if GameSession.gold < reroll_cost:
		print("[Shop] リロール費用不足")
		return

	GameSession.gold -= reroll_cost
	_generate_goods()
	_rebuild_goods_ui()
	_update_ui()

# UI更新
func _update_ui() -> void:
	_gold_label.text = "所持金: %dG" % GameSession.gold

	# 購入済み商品の表示更新 & 購入ボタンのdisabled状態更新
	for i in range(_goods_panels.size()):
		var panel = _goods_panels[i] as PanelContainer
		var vbox = panel.get_child(0) as VBoxContainer
		var price = _get_price(_goods[i])

		if i in _purchased:
			var style = StyleBoxFlat.new()
			style.bg_color = COLOR_SOLDOUT
			style.border_color = COLOR_BORDER
			style.set_border_width_all(2)
			style.set_corner_radius_all(8)
			panel.add_theme_stylebox_override("panel", style)

			# ボタンを無効化
			for child in vbox.get_children():
				if child is Button:
					child.disabled = true
					child.text = "売り切れ"
		else:
			# 所持金不足の場合はボタンをdisabled化
			for child in vbox.get_children():
				if child is Button:
					child.disabled = GameSession.gold < price

	# リロールボタンのdisabled状態更新
	_reroll_btn.disabled = GameSession.gold < get_reroll_cost()

# 商品UI再構築
func _rebuild_goods_ui() -> void:
	# 既存の商品パネルを削除
	for panel in _goods_panels:
		panel.queue_free()
	_goods_panels.clear()

	# 新しい商品パネルを追加
	for i in range(_goods.size()):
		var panel = _create_good_panel(i, _goods[i])
		_cards_container.add_child(panel)
		_goods_panels.append(panel)
