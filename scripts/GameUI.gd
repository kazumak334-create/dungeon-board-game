# GameUI.gd
# UI描画・更新処理（Main.gdから分離）
extends RefCounted

var main: Node = null
var _EDB = null  # EffectDBキャッシュ
var _queue: RefCounted = null   # GameUIQueue
var _overlay: RefCounted = null  # GameUIOverlay

var _log_bg: ColorRect = null              # ログ背景
var _log_title: Label = null               # ログタイトル
var _cell_hp_bars: Array = []             # [side][r][c] -> ColorRect（セル内HPバー）
var _cell_hp_labels: Array = []           # [side][r][c] -> Label（セル内HP数値）
var _mana_gauge_bar: ColorRect = null     # マナゲージバー
var _mana_gauge_label: Label = null       # マナ数値ラベル
var _pause_button: Button = null          # 一時停止ボタン
var _env_label: Label = null              # 環境表示ラベル

func setup(p_main: Node) -> void:
	main = p_main
	_EDB = load("res://scripts/EffectDB.gd")
	var QueueClass = load("res://scripts/GameUIQueue.gd")
	_queue = QueueClass.new()
	_queue.main = main
	_queue._EDB = _EDB
	var OverlayClass = load("res://scripts/GameUIOverlay.gd")
	_overlay = OverlayClass.new()
	_overlay.main = main
	_overlay._EDB = _EDB

func build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.11)
	bg.size  = Vector2(1280, 720)
	main.add_child(bg)

	# タイトル
	var title := Label.new()
	title.text = "Dungeon Board Game  Phase 1 Prototype"
	title.position = Vector2(20, 8)
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color(0.9, 0.85, 0.55)
	main.add_child(title)

	# 環境表示
	_env_label = Label.new()
	var env_id: String = GameSession.base_environment
	var env_display: String = ""
	if env_id != "" and env_id != "env_none":
		var env_def: Dictionary = CardDB.ENVIRONMENTS.get(env_id, {})
		env_display = env_def.get("display", env_id)
	_env_label.text = "環境: %s" % env_display if env_display != "" else ""
	_env_label.position = Vector2(20, 32)
	_env_label.add_theme_font_size_override("font_size", 13)
	_env_label.modulate = Color(0.7, 0.9, 0.7)
	main.add_child(_env_label)

	# 中央ライン
	var line := ColorRect.new()
	line.color    = Color(0.4, 0.4, 0.5, 0.5)
	line.size     = Vector2(2, 3 * main.CELL_H + 10)
	line.position = Vector2(main.CENTER_X - 1, main.BOARD_TOP - 5)
	main.add_child(line)

	# 行ラベル（左端）
	var row_names := ["上", "中", "下"]
	for r in range(3):
		var lbl := Label.new()
		lbl.text     = row_names[r]
		lbl.position = Vector2(_cell_x(0, 0) - 22, main.BOARD_TOP + r * main.CELL_H + 35)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.modulate = Color(0.6, 0.6, 0.6)
		main.add_child(lbl)

	# 列ラベル
	var player_col_labels := ["後列", "中列", "前列"]
	for c in range(3):
		var x: int = _cell_x(0, c)
		var lbl := Label.new()
		lbl.text     = player_col_labels[c]
		lbl.position = Vector2(x + 28, main.BOARD_TOP - 20)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.5, 0.75, 1.0)
		main.add_child(lbl)

	var enemy_col_labels := ["前列", "中列", "後列"]
	for c in range(3):
		var x: int = _cell_x(1, c)
		var lbl := Label.new()
		lbl.text     = enemy_col_labels[c]
		lbl.position = Vector2(x + 28, main.BOARD_TOP - 20)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(1.0, 0.5, 0.5)
		main.add_child(lbl)

	# 自陣・敵陣ラベル
	var pl := Label.new()
	pl.text     = "自  陣"
	pl.position = Vector2(_cell_x(0, 0) + 60, main.BOARD_TOP - 40)
	pl.add_theme_font_size_override("font_size", 15)
	pl.modulate = Color(0.4, 0.8, 1.0)
	main.add_child(pl)

	var el := Label.new()
	el.text     = "敵  陣"
	el.position = Vector2(_cell_x(1, 0) + 60, main.BOARD_TOP - 40)
	el.add_theme_font_size_override("font_size", 15)
	el.modulate = Color(1.0, 0.45, 0.45)
	main.add_child(el)

	# セル生成
	main.cell_rects  = [[], []]
	main.cell_labels = [[], []]
	_cell_hp_bars  = [[], []]
	_cell_hp_labels = [[], []]
	for side in range(2):
		for r in range(3):
			main.cell_rects[side].append([])
			main.cell_labels[side].append([])
			_cell_hp_bars[side].append([])
			_cell_hp_labels[side].append([])
			for c in range(3):
				var x: int = _cell_x(side, c)
				var cell_y: int = main.BOARD_TOP + r * main.CELL_H
				var rect := ColorRect.new()
				rect.size     = Vector2(main.CELL_W - 4, main.CELL_H - 4)
				rect.position = Vector2(x + 2, cell_y + 2)
				rect.color    = Color(0.13, 0.13, 0.2)
				rect.mouse_entered.connect(on_cell_hover.bind(side, r, c))
				rect.mouse_exited.connect(on_cell_hover_end)
				main.add_child(rect)
				main.cell_rects[side][r].append(rect)

				var lbl := Label.new()
				lbl.position  = rect.position + Vector2(5, 4)
				lbl.size      = Vector2(rect.size.x - 6, 28)
				lbl.add_theme_font_size_override("font_size", 12)
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				main.add_child(lbl)
				main.cell_labels[side][r].append(lbl)

				# HPバー背景
				var hp_bar_bg := ColorRect.new()
				hp_bar_bg.size     = Vector2(rect.size.x - 10, 7)
				hp_bar_bg.position = Vector2(x + 7, cell_y + 36)
				hp_bar_bg.color    = Color(0.2, 0.2, 0.2)
				hp_bar_bg.visible  = false
				main.add_child(hp_bar_bg)

				# HPバー前景
				var hp_bar := ColorRect.new()
				hp_bar.size     = Vector2(rect.size.x - 10, 7)
				hp_bar.position = Vector2(x + 7, cell_y + 36)
				hp_bar.color    = Color(0.2, 0.8, 0.3)
				hp_bar.visible  = false
				main.add_child(hp_bar)
				_cell_hp_bars[side][r].append({"bg": hp_bar_bg, "bar": hp_bar})

				# HP数値ラベル
				var hp_lbl := Label.new()
				hp_lbl.position = Vector2(x + 7, cell_y + 45)
				hp_lbl.size     = Vector2(rect.size.x - 10, 14)
				hp_lbl.add_theme_font_size_override("font_size", 10)
				hp_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
				hp_lbl.visible  = false
				main.add_child(hp_lbl)
				_cell_hp_labels[side][r].append(hp_lbl)

	# ---- プレイヤー/敵キャラ立絵+HPバー ----

	# 旧HP表示（互換）
	var base_y: int = main.BOARD_TOP + 3 * main.CELL_H + 12
	main.player_base_label = Label.new()
	main.player_base_label.position = Vector2(_cell_x(0, 0), base_y)
	main.player_base_label.add_theme_font_size_override("font_size", 14)
	main.player_base_label.modulate = Color(0.4, 0.9, 0.4)
	main.player_base_label.visible = false  # 立絵+HPバーに移行
	main.add_child(main.player_base_label)

	main.enemy_base_label = Label.new()
	main.enemy_base_label.position = Vector2(_cell_x(1, 0), base_y)
	main.enemy_base_label.add_theme_font_size_override("font_size", 14)
	main.enemy_base_label.modulate = Color(1.0, 0.45, 0.45)
	main.enemy_base_label.visible = false
	main.add_child(main.enemy_base_label)

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
	main.game_over_label.position = Vector2(340, 270)
	main.game_over_label.add_theme_font_size_override("font_size", 72)
	main.game_over_label.visible  = false
	main.add_child(main.game_over_label)

	main.restart_button = Button.new()
	main.restart_button.text     = "もう一度"
	main.restart_button.position = Vector2(540, 380)
	main.restart_button.size     = Vector2(200, 56)
	main.restart_button.add_theme_font_size_override("font_size", 26)
	main.restart_button.visible  = false
	main.restart_button.pressed.connect(main._on_restart_pressed)
	main.add_child(main.restart_button)

	# ゲームスピード調整
	_build_speed_buttons()


func _build_speed_buttons() -> void:
	var speeds = [1.0, 2.0, 4.0]
	var labels = ["x1", "x2", "x4"]
	var base_x = 1020
	var base_y = 8

	var speed_title = Label.new()
	speed_title.text = "速度:"
	speed_title.position = Vector2(base_x - 40, base_y + 5)
	speed_title.add_theme_font_size_override("font_size", 13)
	speed_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main.add_child(speed_title)

	for i in range(speeds.size()):
		var btn = Button.new()
		btn.text = labels[i]
		btn.position = Vector2(base_x + i * 50, base_y)
		btn.size = Vector2(45, 28)
		btn.add_theme_font_size_override("font_size", 13)
		var spd = speeds[i]
		btn.pressed.connect(func(): main.game_speed = spd)
		main.add_child(btn)

	# 一時停止ボタン
	_pause_button = Button.new()
	_pause_button.text = "⏸"
	_pause_button.position = Vector2(base_x + speeds.size() * 50 + 8, base_y)
	_pause_button.size = Vector2(45, 28)
	_pause_button.add_theme_font_size_override("font_size", 14)
	_pause_button.pressed.connect(_on_pause_pressed)
	main.add_child(_pause_button)

func _on_pause_pressed() -> void:
	main.game_paused = not main.game_paused
	if _pause_button != null:
		_pause_button.text = "▶" if main.game_paused else "⏸"

func _build_mana_bar() -> void:
	var bar_y: int = main.BOARD_TOP + 3 * main.CELL_H + 42
	var bar_x: int = _cell_x(0, 0)
	var bar_w: int = 220
	var bar_h: int = 16

	var bar_title := Label.new()
	bar_title.text     = "Mana"
	bar_title.position = Vector2(bar_x, bar_y - 18)
	bar_title.add_theme_font_size_override("font_size", 12)
	bar_title.modulate = Color(1.0, 0.85, 0.2)
	bar_title.visible = false  # キューエリアに移動
	main.add_child(bar_title)

	# ゲージ背景
	var gauge_bg := ColorRect.new()
	gauge_bg.size     = Vector2(bar_w, bar_h)
	gauge_bg.position = Vector2(bar_x, bar_y)
	gauge_bg.color    = Color(0.1, 0.1, 0.07)
	gauge_bg.visible = false  # キューエリアに移動
	main.add_child(gauge_bg)

	# ゲージ前景（互換のため参照は維持するが非表示）
	_mana_gauge_bar = ColorRect.new()
	_mana_gauge_bar.size     = Vector2(0, bar_h)
	_mana_gauge_bar.position = Vector2(bar_x, bar_y)
	_mana_gauge_bar.color    = Color(0.2, 0.5, 1.0)
	_mana_gauge_bar.visible = false  # キューエリアに移動
	main.add_child(_mana_gauge_bar)

	# 数値ラベル（互換のため参照は維持するが非表示）
	_mana_gauge_label = Label.new()
	_mana_gauge_label.position = Vector2(bar_x + bar_w + 8, bar_y - 1)
	_mana_gauge_label.add_theme_font_size_override("font_size", 13)
	_mana_gauge_label.modulate = Color(1.0, 0.9, 0.3)
	_mana_gauge_label.visible = false  # キューエリアに移動
	main.add_child(_mana_gauge_label)

	# 互換用（参照先が壊れないよう空配列を設定）
	main.mana_bar_cells = []
	main.mana_value_label = _mana_gauge_label

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
	if artifact != null and unit == null:
		if main.skill_flash_timers[side][r][c] > 0.0:
			var f: float = main.skill_flash_timers[side][r][c]
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
			var f: float = main.skill_flash_timers[side][r][c]
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

		# デバフ残ターン集約表示
		var debuffs: Array = []
		if unit.burn_turns > 0:         debuffs.append("火%d" % unit.burn_turns)
		if unit.frozen_turns > 0:       debuffs.append("凍%d" % unit.frozen_turns)
		if unit.paralysis_turns > 0:    debuffs.append("痺%d" % unit.paralysis_turns)
		if unit.poison_stacks > 0:      debuffs.append("毒%d" % unit.poison_stacks)
		var debuff_line = " ".join(debuffs) if debuffs.size() > 0 else ""

		# バフ表示（デバフは分離したので除外）
		var buff_only: Array = []
		if unit._atk_bonus > 0:        buff_only.append("ATK+%d" % unit._atk_bonus)
		if unit._interval_bonus > 0.0:  buff_only.append("SPD+")
		if unit._damage_reduction > 0:  buff_only.append("鎧%d" % unit._damage_reduction)
		if unit.lifesteal_stacks > 0:   buff_only.append("吸血%d" % unit.lifesteal_stacks)
		if unit._regen_stacks > 0:      buff_only.append("再生%d" % unit._regen_stacks)
		if unit._invincible_timer > 0.0: buff_only.append("無敵")
		var buff_only_line = " ".join(buff_only) if buff_only.size() > 0 else ""

		var lines: Array = [
			unit.unit_name,
			"ATK%d" % unit.attack,
		]
		if buff_only_line != "": lines.append(buff_only_line)
		if debuff_line != "": lines.append(debuff_line)
		if flash_line != "": lines.append(flash_line)
		lbl.text = "\n".join(lines)
		# ColorRect HPバー更新
		if _cell_hp_bars.size() > side and _cell_hp_bars[side].size() > r and _cell_hp_bars[side][r].size() > c:
			var hp_dict = _cell_hp_bars[side][r][c]
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
			var hp_dict = _cell_hp_bars[side][r][c]
			hp_dict["bg"].visible = false
			hp_dict["bar"].visible = false
		if _cell_hp_labels.size() > side and _cell_hp_labels[side].size() > r and _cell_hp_labels[side][r].size() > c:
			_cell_hp_labels[side][r][c].visible = false
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
	main.player_base_label.text = "自陣 本体HP: %d / 30" % main.base_hp[0]
	main.enemy_base_label.text  = "敵陣 本体HP: %d / 30" % main.base_hp[1]
	# HPバー更新
	for side in range(2):
		if _overlay._char_hp_bars[side] != null:
			var ratio = float(main.base_hp[side]) / 30.0
			_overlay._char_hp_bars[side].size.x = int(70.0 * max(0.0, ratio))
			var color = Color(0.3, 0.9, 0.4) if side == 0 else Color(0.9, 0.3, 0.3)
			if ratio < 0.3:
				color = Color(0.9, 0.2, 0.2)
			_overlay._char_hp_bars[side].color = color
		if _overlay._char_hp_labels[side] != null:
			_overlay._char_hp_labels[side].text = "%d" % main.base_hp[side]

func _update_mana() -> void:
	var mana: float = main.deck_manager.mana
	var mana_max: float = main.deck_manager.MANA_MAX
	var ratio: float = clamp(mana / max(1.0, mana_max), 0.0, 1.0)
	var bar_w: int = 220
	if _mana_gauge_bar != null:
		_mana_gauge_bar.size.x = int(bar_w * ratio)
		var gauge_color: Color = Color(0.2, 0.5, 1.0).lerp(Color(1.0, 0.85, 0.1), ratio)
		_mana_gauge_bar.color = gauge_color
	if _mana_gauge_label != null:
		_mana_gauge_label.text = "%.1f / %d（上限%d）" % [mana, int(mana_max), int(mana_max)]

	# ---- overlayの立絵パネル内マナバー更新 ----
	var bar_inner_w: float = 70.0  # パネル幅(80) - 余白10
	# 自分側マナ
	if _overlay._char_mana_bars[0] != null:
		_overlay._char_mana_bars[0].size.x = int(bar_inner_w * ratio)
		var color0: Color = Color(0.2, 0.5, 1.0).lerp(Color(1.0, 0.85, 0.1), ratio)
		_overlay._char_mana_bars[0].color = color0
	if _overlay._char_mana_labels[0] != null:
		_overlay._char_mana_labels[0].text = "%.1f / %d" % [mana, int(mana_max)]
	# 敵側マナ
	var e_mana: float = main.enemy_ai.mana
	var e_mana_max: float = main.enemy_ai.MANA_MAX
	var e_ratio: float = clamp(e_mana / max(1.0, e_mana_max), 0.0, 1.0)
	if _overlay._char_mana_bars[1] != null:
		_overlay._char_mana_bars[1].size.x = int(bar_inner_w * e_ratio)
		var color1: Color = Color(1.0, 0.3, 0.2).lerp(Color(1.0, 0.7, 0.1), e_ratio)
		_overlay._char_mana_bars[1].color = color1
	if _overlay._char_mana_labels[1] != null:
		_overlay._char_mana_labels[1].text = "%.1f / %d" % [e_mana, int(e_mana_max)]

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

func update_damage_floats(delta: float) -> void:
	_overlay.update_damage_floats(delta)

func update_bubble(delta: float) -> void:
	_overlay.update_bubble(delta)

func on_cell_hover(side: int, r: int, c: int) -> void:
	_overlay.on_cell_hover(side, r, c)

func on_cell_hover_end() -> void:
	_overlay.on_cell_hover_end()

func _refresh_equipment_ui() -> void:
	_overlay._refresh_equipment_ui()