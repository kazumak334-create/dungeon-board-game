# DebugParamTab.gd
# デバッグUIのパラメータタブ（スライダー群・ConfigLoader連携）
class_name DebugParamTab
extends ScrollContainer

# UI要素保持用
var _sliders: Dictionary = {}  # key: "section.key", value: HSlider
var _labels: Dictionary = {}   # key: "section.key", value: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(vbox)
	
	# マナ経済
	_add_section_label(vbox, "マナ経済")
	_add_slider(vbox, "mana_economy", "initial_mana", "初期マナ", 1, 10, 1)
	_add_slider(vbox, "mana_economy", "mana_max", "マナ上限", 1, 20, 1)
	
	# 時間制限
	_add_section_label(vbox, "時間制限")
	_add_slider(vbox, "battle_config", "time_limit", "制限時間(秒)", 30, 180, 5)
	
	# 敵倍率（未実装予定だが企画書に記載）
	_add_section_label(vbox, "敵倍率")
	_add_slider(vbox, "battle_config", "enemy_hp_scale", "敵HP倍率", 0.5, 3.0, 0.1)
	_add_slider(vbox, "battle_config", "enemy_atk_scale", "敵ATK倍率", 0.5, 3.0, 0.1)
	
	# ドロップテーブル（Early/Mid/Late切替は後日実装）
	_add_section_label(vbox, "ドロップテーブル（Early）")
	_add_slider(vbox, "drop_table.rarity_weights_early", "common", "common", 0, 100, 5)
	_add_slider(vbox, "drop_table.rarity_weights_early", "uncommon", "uncommon", 0, 100, 5)
	_add_slider(vbox, "drop_table.rarity_weights_early", "rare", "rare", 0, 100, 1)
	_add_slider(vbox, "drop_table.rarity_weights_early", "epic", "epic", 0, 100, 1)
	_add_slider(vbox, "drop_table.rarity_weights_early", "legend", "legend", 0, 100, 1)
	
	# 警戒システム
	_add_section_label(vbox, "警戒システム")
	_add_slider(vbox, "alert_system", "tile_effect_count_lv1", "アーマー配置数", 0, 9, 1)
	_add_slider(vbox, "alert_system", "tile_effect_count_lv2", "棘配置数", 0, 9, 1)
	_add_slider(vbox, "alert_system", "armor_damage_reduction", "アーマー軽減量", 0, 10, 1)
	_add_slider(vbox, "alert_system", "thorn_damage", "棘ダメージ", 0, 10, 1)
	
	# デッキ準備遠近法
	_add_section_label(vbox, "デッキ準備: 遠近法")
	_add_perspective_slider(vbox, "perspective_depth_offset", "奥行きオフセット(px)", 0.0, 60.0, 1.0, 18.0)
	_add_perspective_slider(vbox, "perspective_height_scale", "高さ縮小率", 0.0, 0.4, 0.01, 0.12)

	# リセットボタン
	var reset_button = Button.new()
	reset_button.text = "リセット（全デフォルト）"
	reset_button.pressed.connect(_on_reset_pressed)
	vbox.add_child(reset_button)

func _add_section_label(parent: VBoxContainer, title: String) -> void:
	var label = Label.new()
	label.text = "── " + title + " ──"
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)

func _add_slider(parent: VBoxContainer, section: String, key: String, label_text: String, min_val: float, max_val: float, step: float) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(slider)
	
	var value_label = Label.new()
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value_label)
	
	# 初期値読み込み（ドロップテーブルは階層が深い）
	var current_value = _get_config_value(section, key)
	slider.value = current_value
	value_label.text = str(current_value)
	
	# スライダー変更時の処理
	slider.value_changed.connect(func(value: float):
		value_label.text = str(value)
		_set_config_value(section, key, value)
	)
	
	# 辞書に保存
	var dict_key = section + "." + key
	_sliders[dict_key] = slider
	_labels[dict_key] = value_label

func _add_perspective_slider(parent: VBoxContainer, key: String, label_text: String, min_val: float, max_val: float, step: float, default_val: float) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(label)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(150, 0)
	slider.value = default_val
	hbox.add_child(slider)

	var value_label = Label.new()
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = str(default_val)
	hbox.add_child(value_label)

	var p_key = key
	slider.value_changed.connect(func(value: float):
		value_label.text = str(snappedf(value, step))
		_apply_perspective_to_board(p_key, value)
	)

func _apply_perspective_to_board(changed_key: String, value: float) -> void:
	if get_tree() == null:
		return
	var boards = get_tree().get_nodes_in_group("deck_prep_board")
	for board in boards:
		if not board.has_method("apply_perspective"):
			continue
		var depth = board.perspective_depth_offset
		var scale_val = board.perspective_height_scale
		if changed_key == "perspective_depth_offset":
			depth = value
		elif changed_key == "perspective_height_scale":
			scale_val = value
		board.apply_perspective(depth, scale_val)

func _get_config_value(section: String, key: String) -> float:
	# ドロップテーブルは階層が深いので特別処理
	if section.begins_with("drop_table.rarity_weights_"):
		var stage = section.replace("drop_table.rarity_weights_", "")
		var weights = ConfigLoader.get_value("drop_table", "rarity_weights_" + stage, {})
		if weights.has(key):
			return float(weights[key])
		return 0.0
	else:
		return float(ConfigLoader.get_value(section, key, 0.0))

func _set_config_value(section: String, key: String, value: float) -> void:
	# ドロップテーブルは階層が深いので特別処理
	if section.begins_with("drop_table.rarity_weights_"):
		var stage = section.replace("drop_table.rarity_weights_", "")
		var weights = ConfigLoader.get_value("drop_table", "rarity_weights_" + stage, {})
		weights[key] = int(value) if value == floor(value) else value
		ConfigLoader.set_runtime_value("drop_table", "rarity_weights_" + stage, weights)
	else:
		var final_value = int(value) if value == floor(value) else value
		ConfigLoader.set_runtime_value(section, key, final_value)

func _on_reset_pressed() -> void:
	ConfigLoader.clear_runtime_overrides()
	# 全スライダーをデフォルト値にリセット
	for dict_key in _sliders.keys():
		var parts = dict_key.split(".")
		var section = parts[0]
		var key = parts[1] if parts.size() > 1 else ""
		
		# ドロップテーブル特別処理
		if section == "drop_table" and parts.size() == 3:
			section = "drop_table.rarity_weights_" + parts[1]
			key = parts[2]
		
		var default_value = _get_config_value(section, key)
		_sliders[dict_key].value = default_value
		_labels[dict_key].text = str(default_value)
	
	print("[DebugParamTab] 全パラメータをデフォルト値にリセット")
