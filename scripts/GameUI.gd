# GameUI.gd
# UI描画・更新処理（Main.gdから分離）
extends Control

const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")

var main: Node = null
var _EDB = null  # EffectDBキャッシュ
var _queue: Node = null   # GameUIQueue
var _overlay: Node = null  # GameUIOverlay
var _taskbar: Node = null

var _log_bg: ColorRect = null              # ログ背景
var _log_title: Label = null               # ログタイトル
var _cell_hp_bars: Array = []             # [side][r][c] -> ColorRect（セル内HPバー）
var _cell_hp_labels: Array = []           # [side][r][c] -> Label（セル内HP数値）
var _pause_button: Button = null          # 一時停止ボタン
var _speed_buttons: Array = []            # 速度ボタン配列（ハイライト用）
var _env_label: Label = null              # 環境表示ラベル
var _active_drop_effects: Array = []
const MAX_DROP_EFFECTS = 3
var _cell_status_icons: Array = []  # [side][r][c] -> Array[Node]（バフ/デバフアイコン）
func setup(p_main: Node) -> void:
	add_to_group("game_ui")
	main = p_main
	_EDB = load("res://scripts/EffectDB.gd")
	var OverlayClass = load("res://scripts/GameUIOverlay.gd")
	_overlay = OverlayClass.new()
	_overlay.main = main
	_overlay._EDB = _EDB
	var QueueClass = load("res://scripts/GameUIQueue.gd")
	_queue = QueueClass.new()
	_queue.main = main
	_queue._EDB = _EDB
	_queue._overlay = _overlay

	# WaveManagerシグナル接続
	if main.wave_manager != null:
		main.wave_manager.wave_started.connect(_on_wave_started)
		main.wave_manager.intermission_requested.connect(_on_intermission_requested)

func build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.11)
	bg.size  = Vector2(1280, 720)
	main.add_child(bg)

	# 共通タスクバー（最上部36px）
	_taskbar = TaskbarClass.new()
	_taskbar.attach(main, SceneManager.BATTLE)

	# タイトル（非表示）
	# var title := Label.new()  # ② タイトル削除

	# 環境表示
	_env_label = Label.new()
	var env_id: String = GameSession.base_environment
	var env_display: String = ""
	if env_id != "" and env_id != "env_none":
		var env_def: Dictionary = CardDB.ENVIRONMENTS.get(env_id, {})
		env_display = env_def.get("display", env_id)
	_env_label.text = env_display if env_display != "" else ""
	_env_label.position = Vector2(20, 46)
	_env_label.size = Vector2(220, 24)
	_env_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_env_label.add_theme_font_size_override("font_size", 13)
	_env_label.modulate = Color(0.7, 0.9, 0.7)
	main.add_child(_env_label)

	# 中央ライン
	var line := ColorRect.new()
	line.color    = Color(0.4, 0.4, 0.5, 0.5)
	line.size     = Vector2(2, 3 * main.CELL_H + 10)
	line.position = Vector2(main.CENTER_X - 1, main.BOARD_TOP - 5)
	main.add_child(line)

	# 列アイコンヘッダー（自陣）
	var player_col_icons := ["🏹", "🚩", "⚔"]
	var x: int
	var lbl: Label
	for c in range(3):
		x = _cell_x(0, c)
		lbl = Label.new()
		lbl.text = player_col_icons[c]
		lbl.position = Vector2(x, main.BOARD_TOP - 18)
		lbl.size = Vector2(main.CELL_W, 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		main.add_child(lbl)

	# 列アイコンヘッダー（敵陣）
	var enemy_col_icons := ["⚔", "🚩", "🏹"]
	for c in range(3):
		x = _cell_x(1, c)
		lbl = Label.new()
		lbl.text = enemy_col_icons[c]
		lbl.position = Vector2(x, main.BOARD_TOP - 18)
		lbl.size = Vector2(main.CELL_W, 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		main.add_child(lbl)

	# セル生成
	main.cell_rects  = [[], []]
	main.cell_labels = [[], []]
	_cell_hp_bars  = [[], []]
	_cell_hp_labels = [[], []]
	_cell_status_icons = [[], []]
	var cell_y: int
	var rect: ColorRect
	for side in range(2):
		for r in range(3):
			main.cell_rects[side].append([])
			main.cell_labels[side].append([])
			_cell_hp_bars[side].append([])
			_cell_hp_labels[side].append([])
			_cell_status_icons[side].append([])
			for c in range(3):
				x = _cell_x(side, c)
				cell_y = main.BOARD_TOP + r * main.CELL_H
				rect = ColorRect.new()
				rect.size     = Vector2(main.CELL_W - 4, main.CELL_H - 4)
				rect.position = Vector2(x + 2, cell_y + 2)
				rect.color    = Color(0.13, 0.13, 0.2)
				rect.mouse_entered.connect(on_cell_hover.bind(side, r, c))
				rect.mouse_exited.connect(on_cell_hover_end)
				main.add_child(rect)
				main.cell_rects[side][r].append(rect)

				lbl = Label.new()
				lbl.position  = rect.position + Vector2(2, 2)
				lbl.size      = Vector2(rect.size.x - 4, rect.size.y - 4)
				lbl.add_theme_font_size_override("font_size", 12)
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				main.add_child(lbl)
				main.cell_labels[side][r].append(lbl)

				# HPバー背景
				var hp_bar_bg := ColorRect.new()
				hp_bar_bg.size     = Vector2(rect.size.x - 10, 7)
				hp_bar_bg.position = Vector2(x + 7, cell_y + 36)
				hp_bar_bg.color    = Color(0.2, 0.2, 0.2)
				hp_bar_bg.visible  = true
				main.add_child(hp_bar_bg)

				# HPバー前景
				var hp_bar := ColorRect.new()
				hp_bar.size     = Vector2(rect.size.x - 10, 7)
				hp_bar.position = Vector2(x + 7, cell_y + 36)
				hp_bar.color    = Color(0.2, 0.8, 0.3)
				hp_bar.visible  = true
				main.add_child(hp_bar)
				_cell_hp_bars[side][r].append({"bg": hp_bar_bg, "bar": hp_bar})

				# HP数値ラベル
				var hp_lbl := Label.new()
				hp_lbl.position = Vector2(x + 7, cell_y + 45)
				hp_lbl.size     = Vector2(rect.size.x - 10, 14)
				hp_lbl.add_theme_font_size_override("font_size", 10)
				hp_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
				hp_lbl.visible  = true
				main.add_child(hp_lbl)
				_cell_hp_labels[side][r].append(hp_lbl)
				_cell_status_icons[side][r].append([])

	# ---- プレイヤー/敵キャラ立絵+HPバー ----

	# 本体HP表示は廃止（REQ-A）

	# 盤面セルホバー用ツールチップ
	main._cell_tooltip_panel = PanelContainer.new()
	main._cell_tooltip_panel.position = Vector2(10, 10)
	main._cell_tooltip_panel.visible = false
	main._cell_tooltip_panel.z_index = 90
	var tt_style := StyleBoxFlat.new()
	tt_style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	tt_style.border_color = Color(0.4, 0.5, 0.7)
	tt_style.set_border_width_all(1)
	tt_style.set_content_margin_all(8)
	main._cell_tooltip_panel.add_theme_stylebox_override("panel", tt_style)
	main._cell_tooltip_label = Label.new()
	main._cell_tooltip_label.add_theme_font_size_override("font_size", 11)
	main._cell_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main._cell_tooltip_label.custom_minimum_size = Vector2(250, 0)
	main._cell_tooltip_panel.add_child(main._cell_tooltip_label)
	main.add_child(main._cell_tooltip_panel)

	# ---- マナバー ----
	_build_mana_bar()

	# ---- キャラパネル+装備+フキダシ ----
	_overlay.build()

	# ---- 次カードパネル+キューUI+マナバー ----
	_queue.build()

	# Wave進行バー（上部中央）
	var progress_bar = preload("res://scripts/ProgressBar.gd").new()
	progress_bar.position = Vector2(300, 10)
	main.add_child(progress_bar)
	main._progress_bar = progress_bar

	# ---- ログ（デフォルト非表示・Lキーでトグル） ----
	_log_bg = ColorRect.new()
	_log_bg.position = Vector2(1020, main.BOARD_TOP - 10)
	_log_bg.size     = Vector2(245, 3 * main.CELL_H + 30)
	_log_bg.color    = Color(0.04, 0.04, 0.07)
	_log_bg.visible = false
	main.add_child(_log_bg)

	_log_title = Label.new()
	_log_title.text     = "ログ（Lキーで表示）"
	_log_title.position = Vector2(1028, main.BOARD_TOP - 6)
	_log_title.modulate = Color(0.7, 0.7, 0.5)
	_log_title.visible = false
	main.add_child(_log_title)

	main.log_label = Label.new()
	main.log_label.position       = Vector2(1025, main.BOARD_TOP + 14)
	main.log_label.size           = Vector2(235, 3 * main.CELL_H)
	main.log_label.add_theme_font_size_override("font_size", 11)
	main.log_label.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	main.log_label.modulate       = Color(0.78, 0.78, 0.78)
	main.log_label.visible = false
	main.add_child(main.log_label)


	# ---- ゲームオーバー ----
	main.game_over_label = Label.new()
	main.game_over_label.position = Vector2(0, 270)
	main.game_over_label.size = Vector2(1280, 100)
	main.game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.game_over_label.add_theme_font_size_override("font_size", 72)
	main.game_over_label.visible  = false
	main.add_child(main.game_over_label)

	# WAVE表示ラベル（バトル開始・SW遷移時に使用）
	main.wave_label = Label.new()
	main.wave_label.position = Vector2(0, 230)
	main.wave_label.size = Vector2(1280, 60)
	main.wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main.wave_label.add_theme_font_size_override("font_size", 48)
	main.wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))  # ゴールド系
	main.wave_label.modulate = Color(1, 1, 1, 0)
	main.wave_label.visible = false
	main.add_child(main.wave_label)

# ゲームスピード調整
	_build_speed_buttons()


func _build_speed_buttons() -> void:
	var speeds = [1.0, 2.0, 4.0]
	var labels = ["x1", "x2", "x4"]
	# 右端から20px余白で配置（env_label左端20pxと線対称）
	# 速度btn群: base_x..base_x+258、ラベル"速度:"はbase_x-40
	var base_x = 1002  # 右端1260, 右余白20px
	var base_y = 42

	var speed_title = Label.new()
	speed_title.text = "速度:"
	speed_title.position = Vector2(base_x - 40, base_y + 5)
	speed_title.add_theme_font_size_override("font_size", 13)
	speed_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main.add_child(speed_title)

	_speed_buttons.clear()
	for i in range(speeds.size()):
		var btn = Button.new()
		btn.text = labels[i]
		btn.position = Vector2(base_x + i * 50, base_y)
		btn.size = Vector2(45, 30)
		btn.add_theme_font_size_override("font_size", 13)
		var spd = speeds[i]
		btn.pressed.connect(func():
			main.game_speed = spd
			_update_speed_highlight()
		)
		main.add_child(btn)
		_speed_buttons.append({"btn": btn, "spd": spd})

	# 一時停止/再生トグルボタン（③）
	_pause_button = Button.new()
	_pause_button.text = "⏸ 一時停止"
	_pause_button.position = Vector2(base_x + speeds.size() * 50 + 8, base_y)
	_pause_button.size = Vector2(100, 30)
	_pause_button.add_theme_font_size_override("font_size", 12)
	_pause_button.pressed.connect(_on_pause_pressed)
	main.add_child(_pause_button)
	_update_speed_highlight()

func _update_speed_highlight() -> void:
	for entry in _speed_buttons:
		var btn: Button = entry["btn"]
		var spd: float = entry["spd"]
		if abs(spd - main.game_speed) < 0.01:
			btn.modulate = Color(1.0, 1.0, 0.4)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)

func _on_pause_pressed() -> void:
	main.game_paused = not main.game_paused
	if _pause_button != null:
		_pause_button.text = "▶ 再開" if main.game_paused else "⏸ 一時停止"

func _build_mana_bar() -> void:
	# マナゲージはGameUIQueueのスロット行に統合
	main.mana_value_label = null

# ---- セルのX座標計算 ----
func _cell_x(side: int, col: int) -> int:
	if side == 0:
		return main.CENTER_X - main.GAP / 2 - (3 - col) * main.CELL_W
	else:
		return main.CENTER_X + main.GAP / 2 + col * main.CELL_W

# ---- UI更新 ----
func update_ui() -> void:
	_update_cells()
	update_base_hp()
	_update_mana()
	_queue.update()

func update_queue_only() -> void:
	"""game_started=falseでも呼べるQスロット単独更新"""
	_queue.update_spell_slots()

func _update_cells() -> void:
	for side in range(2):
		for r in range(3):
			for c in range(3):
				var has_flash: bool = main.skill_flash_timers[side][r][c] > 0.0
				var has_tile_effect: bool = main.board_manager.board_effects[side][r][c] != null
				var has_artifact: bool = main.board_manager.board_artifacts[side][r][c] != null
				var has_unit: bool = main.board_manager.board[side][r][c] != null
				# ユニットがいるセルはチャージアニメーションのため常時再描画
				if not main._cell_dirty[side][r][c] and not has_flash and not has_tile_effect and not has_artifact and not has_unit:
					continue
				render_cell(side, r, c)
				if not has_flash:
					main._cell_dirty[side][r][c] = false

func render_cell(side: int, r: int, c: int) -> void:
	var unit   = main.board_manager.get_unit(side, r, c)
	var artifact = main.board_manager.board_artifacts[side][r][c]
	var rect: ColorRect = main.cell_rects[side][r][c]
	var lbl:  Label     = main.cell_labels[side][r][c]
	var f: float
	var hp_dict: Dictionary
	if artifact != null and unit == null:
		if main.skill_flash_timers[side][r][c] > 0.0:
			f = main.skill_flash_timers[side][r][c]
			rect.color = Color(0.9, 0.75 * f + 0.1, 0.0)
		else:
			rect.color = Color(0.11, 0.11, 0.17)
		var art_hp: int = artifact.get("hp", 0)
		var art_max_hp: int = artifact.get("max_hp", 1)
		var art_hp_ratio: float = float(art_hp) / float(max(1, art_max_hp))
		var art_bar_filled: int = int(art_hp_ratio * 6)
		var art_hp_bar: String = "█".repeat(art_bar_filled) + "░".repeat(6 - art_bar_filled)
		lbl.text = "【%s】\n%s HP%d/%d" % [artifact.get("name", "?"), art_hp_bar, art_hp, art_max_hp]
		return
	if unit != null:
		var hp_ratio: float = float(unit.current_hp) / float(unit.max_hp)
		# 背景色: スキル発動 > 攻撃チャージ > 通常
		var base_color = Color(0.11, 0.11, 0.17)
		if main.skill_flash_timers[side][r][c] > 0.0:
			f = main.skill_flash_timers[side][r][c]
			base_color = Color(0.9, 0.75 * f + 0.1, 0.0)
		else:
			# 攻撃チャージアニメーション（残り1秒以下で光り始める）
			var atk_timer = main.board_manager.attack_timers[side][r][c]
			if atk_timer < 1.0 and atk_timer >= 0.0:
				var charge = 1.0 - atk_timer  # 0→1に増加
				var is_ally = (side == 0)
				if is_ally:
					base_color = Color(0.11 + 0.15 * charge, 0.11 + 0.2 * charge, 0.17 + 0.1 * charge)
				else:
					base_color = Color(0.11 + 0.2 * charge, 0.11 + 0.1 * charge, 0.17 + 0.05 * charge)
		rect.color = base_color
		var flash_line: String = ""
		if main.skill_flash_timers[side][r][c] > 0.0:
			flash_line = "★" + main.skill_flash_names[side][r][c] + "!"

		# セル内表示：ユニット名 + スキルフラッシュのみ（バフ/デバフはアイコンで別描画）
		var lines: Array = [unit.unit_name]
		if flash_line != "": lines.append(flash_line)
		lbl.text = "
".join(lines)
		_render_status_icons(side, r, c, unit)
		# ColorRect HPバー更新
		if _cell_hp_bars.size() > side and _cell_hp_bars[side].size() > r and _cell_hp_bars[side][r].size() > c:
			hp_dict = _cell_hp_bars[side][r][c]
			var bar_max_w: float = rect.size.x - 10.0
			hp_dict["bg"].visible = true
			hp_dict["bar"].visible = true
			hp_dict["bar"].size.x = int(bar_max_w * clamp(hp_ratio, 0.0, 1.0))
			if hp_ratio > 0.5:
				hp_dict["bar"].color = Color(0.2, 0.8, 0.3)
			elif hp_ratio > 0.2:
				hp_dict["bar"].color = Color(0.85, 0.75, 0.1)
			else:
				hp_dict["bar"].color = Color(0.9, 0.2, 0.2)
		if _cell_hp_labels.size() > side and _cell_hp_labels[side].size() > r and _cell_hp_labels[side][r].size() > c:
			var hp_lbl = _cell_hp_labels[side][r][c]
			hp_lbl.visible = true
			hp_lbl.text = "%d/%d" % [unit.current_hp, unit.max_hp]
	else:
		rect.color = Color(0.11, 0.11, 0.17)
		lbl.text   = ""
		# HPバー非表示
		if _cell_hp_bars.size() > side and _cell_hp_bars[side].size() > r and _cell_hp_bars[side][r].size() > c:
			hp_dict = _cell_hp_bars[side][r][c]
			hp_dict["bg"].visible = false
			hp_dict["bar"].visible = false
		if _cell_hp_labels.size() > side and _cell_hp_labels[side].size() > r and _cell_hp_labels[side][r].size() > c:
			_cell_hp_labels[side][r][c].visible = false
		_clear_status_icons(side, r, c)
	# 盤面効果の可視化
	var te_vis = main.board_manager.board_effects[side][r][c]
	if te_vis != null:
		var tile_id: String = te_vis["effect_id"]
		var tile_def = _EDB.EFFECTS.get(tile_id, {})
		var tile_display: String = tile_def.get("display", tile_id)
		var tile_color: Array = tile_def.get("color", [])
		if tile_color.size() == 4:
			rect.color = rect.color.lerp(Color(tile_color[0], tile_color[1], tile_color[2]), tile_color[3])
		var unit_label: String = tile_def.get("unit_label", "")
		var race_filter: String = tile_def.get("race", "")
		if lbl.text == "":
			lbl.text = tile_display
		else:
			if unit != null and unit.get("_is_flying") == true:
				pass
			elif race_filter != "" and (unit == null or unit.race != race_filter):
				pass
			elif unit_label != "":
				lbl.text = lbl.text + "\n[%s]" % unit_label


func update_base_hp() -> void:
	pass  # REQ-A: 本体HP廃止

func _update_mana() -> void:
	var mana: float = main.deck_manager.mana
	# マナバー: 上限なしのため比率表示廃止。数値のみ表示
	if main.mana_gauge_fill != null:
		var fill_max_w: float = main.mana_gauge_fill_max_w if "mana_gauge_fill_max_w" in main else 110.0
		main.mana_gauge_fill.size.x = fill_max_w  # 常に最大幅（バー非表示相当）
	if main.mana_value_label != null:
		main.mana_value_label.text = "%.0f" % mana

func mark_all_cells_dirty() -> void:
	for s in range(2):
		for r in range(3):
			for c in range(3):
				main._cell_dirty[s][r][c] = true

func toggle_log() -> void:
	var visible = not main.log_label.visible
	main.log_label.visible = visible
	if _log_bg != null: _log_bg.visible = visible
	if _log_title != null: _log_title.visible = visible

func add_log(text: String) -> void:
	var ms: float = float(Time.get_ticks_msec()) * 0.001
	main.log_lines.append("[%.1fs] %s" % [ms, text])
	if main.log_lines.size() > 22:
		main.log_lines.pop_front()
	main.log_label.text = "\n".join(main.log_lines)
	# 重要イベントはフキダシに表示
	if _overlay._is_important_event(text):
		_overlay._show_bubble(text)

# ---- Main.gdからの呼び出しデリゲート ----
func spawn_damage_float(side: int, row: int, col: int, amount: int, is_heal: bool = false) -> void:
	_overlay.spawn_damage_float(side, row, col, amount, is_heal)

func spawn_base_damage_float(side: int, amount: int) -> void:
	_overlay.spawn_base_damage_float(side, amount)

func spawn_attack_line(src_side: int, src_row: int, src_col: int, dst_side: int, dst_row: int, dst_col: int) -> void:
	_overlay.spawn_attack_line(src_side, src_row, src_col, dst_side, dst_row, dst_col)

func spawn_effect_text(side: int, row: int, col: int, text: String, color: Color = Color(0.9, 0.9, 0.3)) -> void:
	_overlay.spawn_effect_text(side, row, col, text, color)

func update_damage_floats(delta: float) -> void:
	_overlay.update_damage_floats(delta)

func update_attack_lines(delta: float) -> void:
	_overlay.update_attack_lines(delta)

func update_effect_floats(delta: float) -> void:
	_overlay.update_effect_floats(delta)

func update_bubble(delta: float) -> void:
	_overlay.update_bubble(delta)

func on_cell_hover(side: int, r: int, c: int) -> void:
	_overlay.on_cell_hover(side, r, c)

func on_cell_hover_end() -> void:
	_overlay.on_cell_hover_end()

func _refresh_equipment_ui() -> void:
	_overlay._refresh_equipment_ui()

func update_battle_timer(remaining: float, delta: float = 0.016) -> void:
	_overlay.update_battle_timer(remaining, delta)

func _on_wave_started(big_wave: int, small_wave: int, scale: float) -> void:
	if main._progress_bar != null:
		main._progress_bar.update_progress(big_wave, small_wave)
	if main.spell_slot_system != null:
		main.spell_slot_system.draw_to_fill_slots()
		_queue.update_spell_slots()

func _on_intermission_requested(shop_config: Dictionary) -> void:
	if main._progress_bar != null:
		main._progress_bar.on_intermission(shop_config)

func spawn_material_drop(material_id: String, _count: int, side: int, row: int, col: int) -> void:
	if _active_drop_effects.size() >= MAX_DROP_EFFECTS:
		return
	var cell_x = _cell_x(side, col) + 59
	var cell_y = 80 + row * 108 + 52
	var icon_node = TextureRect.new()
	icon_node.size = Vector2(16, 16)
	icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_node.custom_minimum_size = Vector2(16, 16)
	var path = "res://assets/materials/%s.png" % material_id
	if ResourceLoader.exists(path):
		icon_node.texture = load(path)
	icon_node.position = Vector2(cell_x - 8, cell_y - 8)
	main.add_child(icon_node)
	_active_drop_effects.append({
		"node": icon_node,
		"timer": 1.0,
		"start_x": float(cell_x - 8),
		"start_y": float(cell_y - 8),
		"vel_x": randf_range(-60.0, 60.0),
		"vel_y": randf_range(-120.0, -60.0),
		"bounce_count": 0,
	})

func spawn_gold_drop(_amount: int, side: int, row: int, col: int) -> void:
	if _active_drop_effects.size() >= MAX_DROP_EFFECTS:
		return
	var cell_x = _cell_x(side, col) + 59
	var cell_y = 80 + row * 108 + 52
	var icon_node = TextureRect.new()
	icon_node.size = Vector2(16, 16)
	icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_node.custom_minimum_size = Vector2(16, 16)
	var path = "res://assets/materials/gold_coin.png"
	if ResourceLoader.exists(path):
		icon_node.texture = load(path)
	icon_node.position = Vector2(cell_x - 8, cell_y - 8)
	main.add_child(icon_node)
	_active_drop_effects.append({
		"node": icon_node,
		"timer": 1.0,
		"start_x": float(cell_x - 8),
		"start_y": float(cell_y - 8),
		"vel_x": randf_range(-60.0, 60.0),
		"vel_y": randf_range(-120.0, -60.0),
		"bounce_count": 0,
	})

func update_drop_effects(delta: float) -> void:
	var finished: Array = []
	for effect in _active_drop_effects:
		effect["timer"] -= delta
		var node = effect["node"]
		if not is_instance_valid(node):
			finished.append(effect)
			continue
		# 重力加速
		effect["vel_y"] += 300.0 * delta
		# 位置更新
		node.position.x += effect["vel_x"] * delta
		node.position.y += effect["vel_y"] * delta
		# バウンド: 上昇から下降に転じてstart_yを超えたら跳ね返り（最大2回）
		if effect["vel_y"] > 0.0 and node.position.y > effect["start_y"] and effect["bounce_count"] < 2:
			effect["vel_y"] *= -0.4
			effect["bounce_count"] += 1
			node.position.y = effect["start_y"]
		# 後半0.4秒でフェードアウト
		var elapsed = 1.0 - effect["timer"]
		if elapsed > 0.6:
			node.modulate.a = 1.0 - (elapsed - 0.6) / 0.4
		if effect["timer"] <= 0.0:
			node.queue_free()
			finished.append(effect)
	for done in finished:
		_active_drop_effects.erase(done)

# ---- バフ/デバフアイコン表示 ----
const _STATUS_ICON_ORDER: Array = ["freeze", "burn", "poison", "curse", "brand", "shield", "regen", "power", "boots", "sense", "spring"]
const _STATUS_ICON_FIELDS: Dictionary = {
	"freeze": "frozen_turns",
	"burn": "burn_turns",
	"poison": "poison_stacks",
	"curse": "curse_stacks",
	"brand": "brand_stacks",
	"shield": "_damage_reduction",
	"regen": "regen_stacks",
	"power": "power_stacks",
	"boots": "boots_stacks",
	"sense": "sense_stacks",
	"spring": "spring_stacks",
}

func _clear_status_icons(side: int, r: int, c: int) -> void:
	if _cell_status_icons.size() <= side: return
	if _cell_status_icons[side].size() <= r: return
	if _cell_status_icons[side][r].size() <= c: return
	for node in _cell_status_icons[side][r][c]:
		if is_instance_valid(node):
			node.queue_free()
	_cell_status_icons[side][r][c] = []

func _render_status_icons(side: int, r: int, c: int, unit) -> void:
	_clear_status_icons(side, r, c)
	if unit == null: return
	if _cell_status_icons.size() <= side: return
	if _cell_status_icons[side].size() <= r: return
	if _cell_status_icons[side][r].size() <= c: return

	# アクティブアイコンリスト収集（優先順）
	var active: Array = []
	for key in _STATUS_ICON_ORDER:
		var field: String = _STATUS_ICON_FIELDS[key]
		var val = unit.get(field)
		if val != null and val > 0:
			active.append({"key": key, "val": val})

	if active.size() == 0: return

	var icon_x_base: int = _cell_x(side, c) + 5
	var icon_y: int = main.BOARD_TOP + r * main.CELL_H + 62
	var icon_size: int = 16
	var icon_step: int = 20
	var max_icons: int = 4
	var shown: int = min(active.size(), max_icons)
	var nodes: Array = []

	for i in range(shown):
		var entry: Dictionary = active[i]
		var ix: int = icon_x_base + i * icon_step

		# テクスチャアイコン
		var tex_rect := TextureRect.new()
		var tex_path: String = "res://assets/icons/status/%s.png" % entry["key"]
		var tex = load(tex_path) if ResourceLoader.exists(tex_path) else null
		if tex != null:
			tex_rect.texture = tex
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		tex_rect.size = Vector2(icon_size, icon_size)
		tex_rect.position = Vector2(ix, icon_y)
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		main.add_child(tex_rect)
		nodes.append(tex_rect)

		# スタック数（2以上のみ）
		var val: int = entry["val"]
		if val >= 2:
			var badge_size: int = 9
			var bx: int = ix + icon_size - badge_size
			var by: int = icon_y + icon_size - badge_size

			var badge_bg := ColorRect.new()
			badge_bg.color = Color(0, 0, 0, 0.6)
			badge_bg.size = Vector2(badge_size, badge_size)
			badge_bg.position = Vector2(bx, by)
			main.add_child(badge_bg)
			nodes.append(badge_bg)

			var badge_lbl := Label.new()
			badge_lbl.text = str(val)
			badge_lbl.add_theme_font_size_override("font_size", 8)
			badge_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
			badge_lbl.size = Vector2(badge_size, badge_size)
			badge_lbl.position = Vector2(bx, by)
			badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			main.add_child(badge_lbl)
			nodes.append(badge_lbl)

	# +N ラベル（超過分）
	if active.size() > max_icons:
		var remain: int = active.size() - max_icons
		var extra_lbl := Label.new()
		extra_lbl.text = "+%d" % remain
		extra_lbl.add_theme_font_size_override("font_size", 10)
		extra_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		extra_lbl.size = Vector2(20, icon_size)
		extra_lbl.position = Vector2(icon_x_base + shown * icon_step, icon_y)
		extra_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		main.add_child(extra_lbl)
		nodes.append(extra_lbl)

	_cell_status_icons[side][r][c] = nodes
