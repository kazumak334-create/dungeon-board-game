# Main.gd
# メインシーン制御・UI描画・ゲームループ
extends Node

const BoardManagerScript   = preload("res://scripts/BoardManager.gd")
const DeckManagerScript    = preload("res://scripts/DeckManager.gd")
const EnemyAIScript        = preload("res://scripts/EnemyAI.gd")
const EventQueueScript     = preload("res://scripts/EventQueue.gd")
const SpellExecutorScript  = preload("res://scripts/SpellExecutor.gd")
var EffectExecutorScript = null  # 遅延ロード（preloadだとコンパイル時にフリーズ）

# ---- レイアウト定数 ----
const CELL_W    := 105
const CELL_H    := 85
const BOARD_TOP := 110   # 盤面上端Y

# 中央GAP: 自陣前列と敵陣前列の間隔
const CENTER_X  := 640
const GAP       := 20

# ---- ノード ----
var board_manager: Node
var deck_manager: Node
var enemy_ai: Node

var base_hp: Array = [30, 30]

var cell_rects:  Array = []
var cell_labels: Array = []
var _cell_tooltip_panel: PanelContainer = null
var _cell_tooltip_label: Label = null

var mana_bar_cells: Array = []  # マナバー格子
var mana_value_label: Label
var next_card_panel: ColorRect
var next_card_name_label: Label
var next_card_detail_label: Label
var next_card_cost_label: Label
var next_card_timer_label: Label
var enemy_next_label: Label

var player_base_label: Label
var enemy_base_label:  Label
var log_label:         Label
var game_over_label:   Label
var restart_button:    Button
var deck_count_label:  Label
var discard_count_label: Label
var enemy_deck_count_label: Label

var _equip_slots: Array = []         # 装備スロットラベル（GameUIが設定）
var _equip_tooltip_panel: PanelContainer = null
var _equip_tooltip_label: Label = null

var game_ui: RefCounted = null  # GameUI インスタンス
var _EDB = null  # EffectDBキャッシュ

var dev_mode: bool = false
var dev_ui: RefCounted = null  # DevUI インスタンス
var game_started: bool = false
var game_paused: bool = false

var game_over: bool = false
var log_lines: Array  = []
var game_speed: float = 1.0

var skill_flash_timers: Array = []  # [side][row][col] -> float
var skill_flash_names:  Array = []  # [side][row][col] -> String
var _cell_dirty:        Array = []  # [side][row][col] -> bool（UI更新フラグ）
var _support_log_timer: float = 5.0

# ---- 初期化 ----
func _ready() -> void:
	var event_queue = Node.new()
	event_queue.set_script(EventQueueScript)
	add_child(event_queue)

	board_manager = Node.new()
	board_manager.set_script(BoardManagerScript)
	add_child(board_manager)
	board_manager.event_queue = event_queue
	board_manager.base_hp_ref = base_hp
	board_manager.unit_placed.connect(_on_unit_placed)
	board_manager.unit_died.connect(_on_unit_died)
	board_manager.unit_revived.connect(_on_unit_revived)
	board_manager.unit_damaged.connect(_on_unit_damaged)
	board_manager.base_damaged.connect(_on_base_damaged)
	board_manager.skill_triggered.connect(_on_skill_triggered)
	board_manager.status_damage.connect(_on_status_damage)
	board_manager.status_cleared.connect(_on_status_cleared)
	board_manager.draw_cards_requested.connect(_on_draw_cards_requested)
	board_manager.spell_cast.connect(_on_spell_cast)
	board_manager.synthesis_done.connect(_on_synthesis_done)

	deck_manager = Node.new()
	deck_manager.set_script(DeckManagerScript)
	add_child(deck_manager)

	enemy_ai = Node.new()
	enemy_ai.set_script(EnemyAIScript)
	add_child(enemy_ai)

	# SpellExecutor 初期化・注入
	var spell_executor = SpellExecutorScript.new()
	deck_manager.spell_executor = spell_executor
	deck_manager.enemy_ai_ref = enemy_ai
	enemy_ai.spell_executor = spell_executor
	enemy_ai.deck_manager_ref = deck_manager

	# EffectExecutor 初期化・注入（遅延ロード）
	EffectExecutorScript = load("res://scripts/EffectExecutor.gd")
	var effect_executor = EffectExecutorScript.new()
	board_manager.effect_executor = effect_executor
	board_manager.deck_manager_ref = deck_manager
	board_manager.enemy_ai_ref = enemy_ai
	spell_executor.effect_executor = effect_executor

	# PlayerData 生成（GameSessionから取得）
	var PlayerDataScript = load("res://scripts/PlayerData.gd")
	var player_data = PlayerDataScript.new()
	var _class_id = GameSession.class_id if GameSession.class_id != "" else "berserker"
	var class_def = CardDB.CLASSES.get(_class_id, CardDB.CLASSES["berserker"])
	player_data.class_id = _class_id
	player_data.class_name_jp = class_def["display"]
	player_data.initial_mana = class_def["initial_mana"]
	player_data.mana_max = class_def["mana_max"]
	player_data.mana_regen = class_def["mana_regen"]
	player_data.skills = class_def["skills"].duplicate(true)
	# DeckManager に反映
	deck_manager.mana = player_data.initial_mana
	deck_manager.MANA_MAX = player_data.mana_max
	deck_manager.MANA_REGEN = player_data.mana_regen
	# BoardManager に設定
	board_manager.player_data = player_data
	# 装備効果の適用（初期装備なし）
	_apply_equipment_effects(player_data)

	_EDB = load("res://scripts/EffectDB.gd")
	_build_synthesis_registry()
	var GameUIScript = load("res://scripts/GameUI.gd")
	game_ui = GameUIScript.new()
	game_ui.setup(self)
	game_ui.build_ui()
	_build_mode_select()
	skill_flash_timers = [
		[[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]],
		[[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	]
	skill_flash_names = [
		[["", "", ""], ["", "", ""], ["", "", ""]],
		[["", "", ""], ["", "", ""], ["", "", ""]]
	]
	_cell_dirty = [
		[[true, true, true], [true, true, true], [true, true, true]],
		[[true, true, true], [true, true, true], [true, true, true]]
	]
	_add_log("=== Dungeon Board Game 起動 ===")

# ---- 盤面合成レジストリ ----
func _build_synthesis_registry() -> void:
	var UnitDataScript = preload("res://scripts/UnitData.gd")
	for recipe in CardDB.SYNTHESIS:
		var r = CardDB.UNITS[recipe["result"]]
		var u = UnitDataScript.new()
		u.unit_name = recipe["result"]
		u.max_hp = r["hp"]; u.current_hp = r["hp"]
		u.attack = r["atk"]; u.attack_interval = r["interval"]
		u.cost = r["cost"]; u.assigned_col = r["col"]
		u.race = r.get("race", "スライム")
		u.attack_range = r.get("range", "1行")
		u.support_effect = ""; u.passive_skill = ""
		u.skills = r.get("skills", []).duplicate(true)
		board_manager.synthesis_registry.append({
			"base": recipe["base"],
			"card": recipe["card"],
			"result": u,
		})


func _build_mode_select() -> void:
	if GameSession.dev_mode:
		# 開発者モード: Title画面から直接遷移
		dev_mode = true
		game_started = true
		game_paused = true
		deck_manager.deck.clear()
		deck_manager.discard.clear()
		deck_manager.ensure_shuffle_card()
		var DevUIScript = load("res://scripts/DevUI.gd")
		dev_ui = DevUIScript.new()
		dev_ui.setup(self, board_manager, deck_manager, enemy_ai)
		_add_log("=== 開発者モード開始（一時停止・デッキ空）===")
	else:
		# 通常モード: 即座にバトル開始（モード選択パネル不要）
		# リプレイ用シード設定
		GameSession.battle_seed = randi()
		GameSession.battle_log.clear()
		seed(GameSession.battle_seed)
		game_started = true
		deck_manager.ensure_shuffle_card()
		enemy_ai.ensure_shuffle_card()
		_add_log("=== バトル開始 (seed: %d) ===" % GameSession.battle_seed)

# ---- UI委譲ラッパー ----
func _add_log(text: String) -> void: game_ui.add_log(text)
func _update_ui() -> void: game_ui.update_ui()
func _update_base_hp() -> void: game_ui.update_base_hp()
func _mark_all_cells_dirty() -> void: game_ui.mark_all_cells_dirty()
func _render_cell(s: int, r: int, c: int) -> void: game_ui.render_cell(s, r, c)
func _refresh_equipment_ui() -> void: game_ui._refresh_equipment_ui()


# ---- 入力処理（開発者モード用） ----
func _input(event: InputEvent) -> void:
	if not dev_mode or dev_ui == null:
		return
	# 盤面効果設置モード：クリックでセルに効果設置
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dev_ui._pending_tile_effect != "":
			var pos: Vector2 = event.position
			for side in range(2):
				for r in range(3):
					for c in range(3):
						var rect: ColorRect = cell_rects[side][r][c]
						if Rect2(rect.position, rect.size).has_point(pos):
							dev_ui.on_drop(side, r, c)
							return
	# ドラッグ中のマウスリリース → セル判定
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dev_ui._dragging:
			var pos: Vector2 = event.position
			var dropped: bool = false
			# デッキエリアにドロップ → デッキに追加
			if pos.x <= 155:
				dev_ui.on_drop_to_deck()
				dropped = true
			else:
				for side in range(2):
					for r in range(3):
						for c in range(3):
							var rect: ColorRect = cell_rects[side][r][c]
							if Rect2(rect.position, rect.size).has_point(pos):
								dev_ui.on_drop(side, r, c)
								dropped = true
			if not dropped:
				dev_ui.on_drop_outside()
			dev_ui._stop_drag()

func _dev_update_drag() -> void:
	if dev_ui != null and dev_ui._dragging and dev_ui._drag_label != null:
		dev_ui._drag_label.position = get_viewport().get_mouse_position() + Vector2(12, -8)

# ---- ゲームループ ----
func _process(delta: float) -> void:
	# ドラッグ中のラベル追従
	if dev_mode:
		_dev_update_drag()
	# フラッシュタイマー更新（game_over中も継続）
	for s in range(2):
		for r in range(3):
			for c in range(3):
				if skill_flash_timers[s][r][c] > 0.0:
					skill_flash_timers[s][r][c] = max(0.0, skill_flash_timers[s][r][c] - delta)
					if skill_flash_timers[s][r][c] == 0.0:
						_cell_dirty[s][r][c] = true  # フラッシュ終了→通常色に戻す

	if not game_started or game_over:
		return
	if not game_paused:
		var effective_delta: float = delta * game_speed
		deck_manager.process_deck(effective_delta, board_manager)
		enemy_ai.process_ai(effective_delta, board_manager)
		board_manager.process_combat(effective_delta, base_hp)
		if not dev_mode:
			_check_game_over()
		# 開発者モード: デッキ表示を更新（サイズ変化時のみ）
		if dev_mode and dev_ui != null:
			dev_ui._refresh_deck_list(false)

	# サポート効果ログ（5秒ごと）
	_support_log_timer -= delta
	if _support_log_timer <= 0.0:
		_support_log_timer = 5.0
		_log_support_effects()

	game_ui.update_ui()

func _check_game_over() -> void:
	if base_hp[0] <= 0:
		game_over = true
		game_over_label.text     = "GAME OVER"
		game_over_label.modulate = Color(1.0, 0.3, 0.3)
		game_over_label.visible  = true
		restart_button.visible   = true
		GameSession.last_result = {"win": false, "player_hp_remaining": base_hp[0], "turns": 0}
		_transition_to_result_timer()
	elif base_hp[1] <= 0:
		game_over = true
		game_over_label.text     = "YOU WIN!"
		game_over_label.modulate = Color(0.3, 1.0, 0.5)
		game_over_label.visible  = true
		restart_button.visible   = true
		GameSession.last_result = {"win": true, "player_hp_remaining": base_hp[0], "turns": 0}
		_transition_to_result_timer()

func _transition_to_result_timer() -> void:
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): SceneManager.go_to(SceneManager.RESULT))

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

# ---- シグナルハンドラ ----
func _on_unit_placed(side: int, row: int, col: int, _unit: Object) -> void:
	_mark_all_cells_dirty()

func _on_unit_died(side: int, row: int, col: int) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	var display_col: int = (2 - col) if side == 0 else col
	var col_names: Array  = ["前列", "中列", "後列"]
	_add_log("倒 %s %d行%s" % [side_name, row + 1, col_names[display_col]])
	if side == 0 and board_manager.player_data != null:
		for skill in board_manager.player_data.skills:
			if skill.get("trigger", "") == "on_unit_died_ally":
				var max_count = skill.get("params", {}).get("max_count", 10)
				if board_manager.player_data._death_mana_count < max_count:
					board_manager.player_data._death_mana_count += 1
					var amount = skill.get("params", {}).get("amount", 1)
					deck_manager.mana = min(deck_manager.MANA_MAX, deck_manager.mana + amount)
					_add_log("[死霊術師] 味方死亡: マナ+%d (累計%d/%d)" % [amount, board_manager.player_data._death_mana_count, max_count])
	_mark_all_cells_dirty()

func _on_unit_damaged(side: int, row: int, col: int) -> void:
	if side >= 0 and row >= 0 and col >= 0:
		_cell_dirty[side][row][col] = true

func _on_unit_revived(side: int, row: int, col: int) -> void:
	var unit = board_manager.get_unit(side, row, col)
	var name: String = unit.unit_name if unit != null else "?"
	_add_log("[スキル] %s の 自己再起 発動（撃破時）HP5で復活" % name)
	skill_flash_timers[side][row][col] = 1.0
	skill_flash_names[side][row][col]  = "再起"
	_cell_dirty[side][row][col] = true

func _on_base_damaged(side: int, amount: int) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	_add_log("! %s本体 -%d (残:%d)" % [side_name, amount, base_hp[side]])

func _on_skill_triggered(side: int, row: int, col: int, skill_name: String) -> void:
	var unit = board_manager.get_unit(side, row, col)
	var name: String = unit.unit_name if unit != null else "?"
	_add_log("[スキル] %s の %s 発動" % [name, skill_name])
	skill_flash_timers[side][row][col] = 0.6
	skill_flash_names[side][row][col]  = skill_name
	_cell_dirty[side][row][col] = true

func _log_support_effects() -> void:
	pass  # skills配列ベースのサポートはEffectExecutor経由で動作

func _on_status_damage(unit_name: String, status: String, damage: int, stacks: int) -> void:
	_add_log("[状態異常] %s: %s -%d (スタック:%d)" % [unit_name, status, damage, stacks])

func _on_status_cleared(unit_name: String, status: String) -> void:
	_add_log("[状態解除] %s の %s が解除" % [unit_name, status])

func _on_synthesis_done(side: int, row: int, col: int, base_name: String, result_name: String) -> void:
	if side == 0 and board_manager.player_data != null:
		for skill in board_manager.player_data.skills:
			if skill.get("trigger", "") == "on_synthesis":
				var eid: String = skill.get("effect_id", "")
				var edef: Dictionary = _EDB.EFFECTS.get(eid, {})
				if edef.get("type", "") == "mana_add":
					var amount: int = skill.get("params", {}).get("amount", edef.get("amount", 2))
					deck_manager.mana = min(deck_manager.MANA_MAX, deck_manager.mana + amount)
					_add_log("[合成スキル] マナ+%d" % amount)
	var side_name: String = "自陣" if side == 0 else "敵陣"
	_add_log("[合成] %s %s → %s" % [side_name, base_name, result_name])
	skill_flash_timers[side][row][col] = 1.0
	skill_flash_names[side][row][col] = "合成"
	_cell_dirty[side][row][col] = true

func _apply_equipment_effects(pdata: RefCounted) -> void:
	if pdata == null:
		return
	board_manager.player_artifacts.clear()
	var total_mana_regen_pct: float = 0.0
	for eq in pdata.equipment:
		board_manager.player_artifacts.append({"name": eq.get("display", ""), "skills": eq.get("skills", []).duplicate(true)})
		for skill in eq.get("skills", []):
			var eid: String = skill.get("effect_id", "")
			if eid == "mana_regen_boost":
				total_mana_regen_pct += skill.get("params", {}).get("pct", 0.2)
	var base_regen: float = pdata.mana_regen
	deck_manager.MANA_REGEN = base_regen * (1.0 + total_mana_regen_pct)
	print("[Main] 装備効果適用: MANA_REGEN=%.2f player_artifacts=%d件" % [deck_manager.MANA_REGEN, board_manager.player_artifacts.size()])

func _on_spell_cast(side: int, spell_name: String) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	_add_log("[呪文] %s %s 発動" % [side_name, spell_name])
	_mark_all_cells_dirty()

func _on_draw_cards_requested(side: int, count: int) -> void:
	for i in range(count):
		if side == 0:
			deck_manager.force_play_card(board_manager)
		else:
			enemy_ai.force_play_card(board_manager)
