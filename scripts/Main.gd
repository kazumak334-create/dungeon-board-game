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
const CELL_W    := 130
const CELL_H    := 95
const BOARD_TOP := 88    # 盤面上端Y（速度ボタン+環境表示の下、セル半分下げ）

# 中央GAP: 自陣前列と敵陣前列の間隔
const CENTER_X  := 640
const GAP       := 20

# ---- ノード ----
var board_manager: Node
var deck_manager: Node
var enemy_ai: Node
var spell_slot_system: RefCounted = null  # v2設計: 呪文3スロットシステム

var base_hp: Array = [30, 30]
var row_breached: Array = [
	[false, false, false],  # 自陣: 各行の突破状態
	[false, false, false]   # 敵陣: 各行の突破状態
]

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

# ---- バトルタイマー ----
var _battle_timer: float = 60.0  # _apply_battle_configで上書き
var _battle_timer_active: bool = false  # 通常モードのみtrue（dev_modeはfalse）

# ---- 初期化 ----
func _ready() -> void:
	# 自動テストモード
	if OS.has_feature("autotest") or OS.get_cmdline_args().has("--autotest") or OS.get_environment("DUNGEON_AUTOTEST") == "1":
		_run_autotest()
		return

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

	# v2設計: SpellSlotSystem 初期化
	var SpellSlotScript = load("res://scripts/SpellSlotSystem.gd")
	spell_slot_system = SpellSlotScript.new()
	spell_slot_system.setup(board_manager, deck_manager, enemy_ai, spell_executor, self)
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
	player_data.skills = class_def["skills"].duplicate(true)
	# DeckManager に反映（マナ上限3固定）
	deck_manager.mana = 0.0
	deck_manager.MANA_MAX = 3.0

	# アーティファクト効果適用（バトル開始時）
	_apply_artifact_effects_battle_start()
	# MANA_REGEN削除: v2設計でユニット生成マナに変更
	# BoardManager に設定
	board_manager.player_data = player_data
	# 装備効果の適用（初期装備なし）
	_apply_equipment_effects(player_data)

	_EDB = load("res://scripts/EffectDB.gd")
	_build_synthesis_registry()
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
	var GameUIScript = load("res://scripts/GameUI.gd")
	game_ui = GameUIScript.new()
	game_ui.setup(self)
	game_ui.build_ui()
	_build_mode_select()
	_add_log("=== Dungeon Board Game 起動 ===")

func _run_autotest() -> void:
	print("[Main] 自動テストモード起動")
	var AutoTestScript = load("res://scripts/AutoTest.gd")
	var autotest = Node.new()
	autotest.set_script(AutoTestScript)
	add_child(autotest)
	# 通常の初期化は継続（テストに必要なため）
	var event_queue = Node.new()
	event_queue.set_script(EventQueueScript)
	add_child(event_queue)

# ---- 盤面合成レジストリ ----
func _build_synthesis_registry() -> void:
	var UnitDataScript = preload("res://scripts/UnitData.gd")
	for recipe in CardDB.SYNTHESIS:
		var r = CardDB.UNITS[recipe["result"]]
		var u = UnitDataScript.new()
		u.unit_name = recipe["result"]
		u.max_hp = r["hp"]; u.current_hp = r["hp"]
		u.attack = r["atk"]; u.attack_interval = r["interval"]
		u.mana = r["mana"]; u.assigned_col = r["col"]
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
		# アーティファクト効果フラグ初期化
		board_manager.artifact_revive_used = false
		# 警戒システム: エリート混入フラグリセット
		GameSession.elite_injected_in_battle = false
		_apply_battle_config()
		deck_manager.ensure_shuffle_card()
		enemy_ai.ensure_shuffle_card()
		# v2設計: 初期配置ユニットを盤面に展開
		_place_initial_units()
		# 警戒システム: 配置前に敵デッキ加工・盤面効果付与
		_apply_alert_modifiers()
		_place_enemy_initial_units()
		# v2設計: マナ上限をユニット総コストで初期化
		deck_manager.initialize_mana_from_deck()
		enemy_ai.initialize_mana_from_deck()
		_apply_environment()
		# アーティファクト効果適用（ユニット配置後）
		_apply_artifact_effects_on_units()
		_add_log("=== バトル開始 (seed: %d) ===" % GameSession.battle_seed)

func _apply_battle_config() -> void:
	var cfg: Dictionary = GameSession.battle_config
	base_hp[0] = cfg.get("player_base_hp", 30)
	base_hp[1] = cfg.get("enemy_base_hp", 30)
	# MANA_REGEN削除: v2設計でユニット生成マナに変更
	deck_manager.check_interval = cfg.get("card_play_interval", 1.0)
	# enemy_ai.MANA_REGEN削除: v2設計で敵も初期配置に変更
	enemy_ai.check_interval   = cfg.get("enemy_check_interval", 1.0)
	var tl: float = cfg.get("time_limit", 60.0)
	_battle_timer = tl
	_battle_timer_active = (tl > 0.0) and not dev_mode
	# enemy_atk_scale, enemy_hp_scale: place_unit時にBoardManagerで適用（将来）
	# mana_max_override: 将来実装
	# initial_units, summon_race_filter, placement_restriction: 将来実装
	print("[Main] battle_config適用: hp=[%d,%d] timer=%.1f active=%s" % [base_hp[0], base_hp[1], tl, str(_battle_timer_active)])

func _place_initial_units() -> void:
	# v2設計: GameSession.initial_unitsを盤面に配置
	if GameSession.initial_units.is_empty():
		print("[Main] 初期配置ユニットなし")
		return

	var UnitDataScript = load("res://scripts/UnitData.gd")
	for unit_info in GameSession.initial_units:
		if unit_info == null:
			continue

		var unit_name = unit_info.get("name", "")
		var row = unit_info.get("row", -1)
		var col = unit_info.get("col", -1)

		if not CardDB.UNITS.has(unit_name):
			print("[Main] 初期配置エラー: %s はユニットDBに存在しない" % unit_name)
			continue

		if row < 0 or row > 2 or col < 0 or col > 2:
			print("[Main] 初期配置エラー: %s の座標が不正 (row=%d, col=%d)" % [unit_name, row, col])
			continue

		var unit_data = CardDB.UNITS[unit_name]
		var unit = UnitDataScript.new()
		unit.unit_name = unit_name
		unit.max_hp = unit_data["hp"]
		unit.current_hp = unit_data["hp"]
		unit.attack = unit_data["atk"]
		unit.attack_interval = unit_data["interval"]
		unit.mana = unit_data["mana"]
		unit.race = unit_data["race"]
		unit.attack_range = unit_data["range"]
		unit.skills = unit_data.get("skills", []).duplicate(true)
		unit.card_type = "unit"

		board_manager.place_unit(0, unit, {"row": row, "col": col})
		print("[Main] 初期配置: %s → (%d, %d)" % [unit_name, row, col])

func _place_enemy_initial_units() -> void:
	# v2設計: 敵のenemy_deckから全ユニットを初期配置として盤面に展開
	if enemy_ai.enemy_deck.is_empty():
		print("[Main] 敵デッキが空です")
		return

	var units_to_place: Array = []
	var remaining_cards: Array = []

	# デッキからユニットと非ユニットを分離
	for card in enemy_ai.enemy_deck:
		if card.card_type == "unit":
			units_to_place.append(card)
		else:
			remaining_cards.append(card)

	# ユニットを盤面に配置
	var placed_count = 0
	var total_cost = 0.0
	for unit in units_to_place:
		var col = unit.assigned_col
		col = clampi(col, 0, 2)

		# 配置可能な行を探す
		var row = -1
		for r in range(3):
			if board_manager.board[1][r][col] == null:
				row = r
				break

		# その列が埋まっていたら他の列を探す
		if row == -1:
			for c in range(3):
				for r in range(3):
					if board_manager.board[1][r][c] == null:
						row = r
						col = c
						break
				if row != -1:
					break

		# 配置実行
		if row != -1:
			board_manager.place_unit(1, unit, {"row": row, "col": col})
			print("[Main] 敵初期配置: %s → (%d, %d)" % [unit.unit_name, row, col])
			placed_count += 1
			total_cost += float(unit.mana)
		else:
			print("[Main] 敵初期配置失敗: %s（盤面が満杯）" % unit.unit_name)
			remaining_cards.append(unit)

	# デッキを非ユニットのみに更新
	enemy_ai.enemy_deck = remaining_cards
	# MANA_MAXを初期配置ユニット総コストに設定
	enemy_ai.MANA_MAX = total_cost
	enemy_ai.mana = 0.0
	print("[Main] 敵初期配置完了: %d体配置、総コスト%.1f、デッキ残り%d枚" % [placed_count, total_cost, remaining_cards.size()])

func _apply_alert_modifiers() -> void:
	# 警戒システム: 敵デッキ加工・盤面効果付与
	if GameSession.alert_level < 1:
		return

	# エリート混入・配置強化
	var EnemyPlacementHelperScript = load("res://scripts/EnemyPlacementHelper.gd")
	var placement_helper = EnemyPlacementHelperScript.new()
	placement_helper.apply_alert_modifiers(enemy_ai.enemy_deck, GameSession.alert_level, GameSession.current_act)

	# 盤面効果付与
	var TileEffectManagerScript = load("res://scripts/TileEffectManager.gd")
	var tile_manager = TileEffectManagerScript.new()
	tile_manager.apply_alert_tile_effects(GameSession.alert_level, board_manager)

func _apply_environment() -> void:
	var env_id = GameSession.base_environment
	if env_id == "" or env_id == "env_none":
		return
	var env_def = CardDB.ENVIRONMENTS.get(env_id, {})
	var tile_id = env_def.get("tile_id", "")
	if tile_id == "":
		return
	var min_tiles = env_def.get("min_tiles", 1)
	var max_tiles = env_def.get("max_tiles", 6)
	var count = randi_range(min_tiles, max_tiles)

	# 両陣営のランダムなマスに盤面効果を配置
	var all_cells: Array = []
	for s in range(2):
		for r in range(3):
			for c in range(3):
				all_cells.append([s, r, c])
	all_cells.shuffle()

	var placed = 0
	for cell in all_cells:
		if placed >= count:
			break
		var s = cell[0]
		var r = cell[1]
		var c = cell[2]
		if board_manager.board_effects[s][r][c] == null:
			board_manager.tile_system.set_tile_effect(s, r, c, tile_id)
			placed += 1

	# 環境変化（上書き）の適用
	for side_str in GameSession.environment_override:
		var side = int(side_str)
		var override_tile = GameSession.environment_override[side_str]
		for r in range(3):
			for c in range(3):
				if board_manager.board_effects[side][r][c] != null:
					board_manager.tile_system.clear_tile_effect(side, r, c)
				board_manager.tile_system.set_tile_effect(side, r, c, override_tile)

	_add_log("[環境] %s: %s ×%d" % [env_def.get("display", env_id), tile_id, placed])

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
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		game_ui.toggle_log()

func _process(delta: float) -> void:
	# ダメージフロート+フキダシ更新
	if game_ui != null:
		game_ui.update_damage_floats(delta)
		game_ui.update_bubble(delta)
	# ドラッグ中のラベル追従
	if dev_mode:
		_dev_update_drag()
	# フラッシュタイマー更新（game_over中も継続）
	if skill_flash_timers.size() > 0:
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
		# バトルタイマー（リアル経過時間、speed_scale非適用）
		if _battle_timer_active:
			_battle_timer -= delta
			if game_ui != null:
				game_ui.update_battle_timer(_battle_timer, delta)
			if _battle_timer <= 0.0:
				_battle_timer = 0.0
				_battle_timer_active = false
				_on_battle_timeout()
				return
		var effective_delta: float = delta * game_speed
		deck_manager.process_deck(effective_delta, board_manager)
		enemy_ai.process_ai(effective_delta, board_manager)
		board_manager.process_combat(effective_delta, base_hp)
		# v2設計: 呪文3スロット並列監視
		if spell_slot_system != null:
			spell_slot_system.process_slots(effective_delta)
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

	if game_ui != null:
		game_ui.update_ui()

func _check_game_over() -> void:
	# v2設計: 本体HP0 OR 全滅で負け
	var player_all_dead = _check_all_units_dead(0)
	var enemy_all_dead = _check_all_units_dead(1)

	if base_hp[0] <= 0 or player_all_dead:
		game_over = true
		game_over_label.text     = "GAME OVER"
		game_over_label.modulate = Color(1.0, 0.3, 0.3)
		game_over_label.visible  = true
		var reason = "本体HP0" if base_hp[0] <= 0 else "全滅"
		_add_log("=== 敗北（%s）===" % reason)
		GameSession.last_result = {"win": false, "player_hp_remaining": base_hp[0], "turns": 0, "battle_gold": GameSession.current_battle_gold}
		_transition_to_result_timer()
	elif base_hp[1] <= 0 or enemy_all_dead:
		# ボス連戦判定: 第1戦勝利 & 警戒Lv4以上
		if GameSession.battle_type == "boss" and GameSession.boss_phase == 1 and GameSession.alert_level >= 4:
			_start_boss_phase2()
			return

		game_over = true
		game_over_label.text     = "YOU WIN!"
		game_over_label.modulate = Color(0.3, 1.0, 0.5)
		game_over_label.visible  = true
		var reason = "本体HP0" if base_hp[1] <= 0 else "全滅"
		_add_log("=== 勝利（%s）===" % reason)
		GameSession.last_result = {"win": true, "player_hp_remaining": base_hp[0], "turns": 0, "battle_gold": GameSession.current_battle_gold}
		_transition_to_result_timer()

func _check_all_units_dead(side: int) -> bool:
	"""指定陣営のユニットが全滅しているか判定"""
	for r in range(3):
		for c in range(3):
			if board_manager.board[side][r][c] != null:
				return false
	return true

func _start_boss_phase2() -> void:
	"""ボス連戦: 第2戦開始"""
	_add_log("=== PHASE 2 開始 ===")

	# フェーズ2に移行
	GameSession.boss_phase = 2

	# 第1戦クリア報酬: マナ+5
	deck_manager.mana += 5.0
	_add_log("第1戦クリア報酬: マナ+5")

	# 敵側の状態リセット
	base_hp[1] = GameSession.battle_config.get("enemy_base_hp", 30)

	# 敵の盤面クリア
	for r in range(3):
		for c in range(3):
			if board_manager.board[1][r][c] != null:
				board_manager.remove_unit(1, r, c)

	# 敵デッキ再構築（第2戦用）
	enemy_ai.enemy_deck.clear()
	enemy_ai.enemy_discard.clear()
	enemy_ai._build_enemy_deck()
	enemy_ai.ensure_shuffle_card()

	# 敵の初期配置（全マス埋め）
	_place_enemy_initial_units()

	# マナ初期化
	enemy_ai.initialize_mana_from_deck()

	_add_log("=== PHASE 2 バトル開始 ===")

func _on_battle_timeout() -> void:
	var result: String = GameSession.battle_config.get("time_up_result", "lose")
	game_over = true
	if result == "win":
		game_over_label.text     = "TIME UP - VICTORY"
		game_over_label.modulate = Color(0.3, 1.0, 0.5)
		GameSession.last_result = {"win": true, "player_hp_remaining": base_hp[0], "turns": 0, "battle_gold": GameSession.current_battle_gold}
	elif result == "draw":
		game_over_label.text     = "TIME UP - DRAW"
		game_over_label.modulate = Color(0.7, 0.7, 0.3)
		GameSession.last_result = {"win": false, "player_hp_remaining": base_hp[0], "turns": 0, "battle_gold": GameSession.current_battle_gold}
	else:  # "lose"（デフォルト）
		game_over_label.text     = "TIME UP - DEFEAT"
		game_over_label.modulate = Color(1.0, 0.5, 0.1)
		GameSession.last_result = {"win": false, "player_hp_remaining": base_hp[0], "turns": 0, "battle_gold": GameSession.current_battle_gold}
	game_over_label.visible = true
	_add_log("=== 時間切れ：%s ===" % result)
	_transition_to_result_timer()

func _transition_to_result_timer() -> void:
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): SceneManager.go_to(SceneManager.RESULT))

# ---- シグナルハンドラ ----
func _on_unit_placed(side: int, row: int, col: int, _unit: Object) -> void:
	_mark_all_cells_dirty()

func _on_unit_died(side: int, row: int, col: int, died_unit: Object) -> void:
	var side_name: String = "自陣" if side == 0 else "敵陣"
	var display_col: int = (2 - col) if side == 0 else col
	var col_names: Array  = ["前列", "中列", "後列"]
	_add_log("倒 %s %d行%s" % [side_name, row + 1, col_names[display_col]])

	# v2設計: 行突破判定（その行が全滅したら本体HPを削る）
	_check_row_breach(side, row)

	# 敵ユニット撃破時: cost × 5G を累積（reward_multiplierで倍率調整可能）
	if side == 1 and died_unit != null:
		var unit_cost: int = died_unit.mana if "cost" in died_unit else 1
		var reward_mult: float = GameSession.battle_config.get("reward_multiplier", 1.0)
		var gold_gained: int = max(1, int(unit_cost * 5 * reward_mult))
		GameSession.current_battle_gold += gold_gained
		print("[Drop] 敵撃破 gold+%d (cost:%d, 累計:%d)" % [gold_gained, unit_cost, GameSession.current_battle_gold])
		if game_ui != null and game_ui._overlay != null:
			game_ui._overlay.update_battle_gold_label(GameSession.current_battle_gold)
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

func _check_row_breach(side: int, row: int) -> void:
	"""行突破判定: 指定行が全滅したら本体HPを削る"""
	# 既に突破済みならスキップ
	if row_breached[side][row]:
		return

	# その行の全セルをチェック
	var row_units_alive = false
	for c in range(3):
		if board_manager.board[side][row][c] != null:
			row_units_alive = true
			break

	# 全滅していたら行突破
	if not row_units_alive:
		row_breached[side][row] = true
		var damage = 10
		base_hp[side] = max(0, base_hp[side] - damage)
		var side_name = "自陣" if side == 0 else "敵陣"
		var row_name = ["上段", "中段", "下段"][row]
		_add_log("! %s %s突破！本体 -%d (残:%d)" % [side_name, row_name, damage, base_hp[side]])
		if game_ui != null:
			game_ui.spawn_base_damage_float(side, damage)
		_update_base_hp()

func _on_unit_damaged(side: int, row: int, col: int) -> void:
	if side >= 0 and row >= 0 and col >= 0:
		_cell_dirty[side][row][col] = true
		# ダメージフロート（ダメージ量はunitのHP差分から取れないのでシグナル拡張が必要。仮で表示）
		var unit = board_manager.get_unit(side, row, col)
		if unit != null and game_ui != null:
			game_ui.spawn_damage_float(side, row, col, 0, false)  # 仮：量は後で対応

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
	if game_ui != null:
		game_ui.spawn_base_damage_float(side, amount)

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
	for eq in pdata.equipment:
		board_manager.player_artifacts.append({"name": eq.get("display", ""), "skills": eq.get("skills", []).duplicate(true)})
	print("[Main] 装備効果適用: player_artifacts=%d件" % [board_manager.player_artifacts.size()])

func _apply_artifact_effects_battle_start() -> void:
	# バトル開始時に適用可能なアーティファクト効果
	# NOTE: stat_buff, timed_buffはユニット配置後に別関数で適用
	for artifact_id in GameSession.artifacts:
		if not CardDB.ARTIFACTS.has(artifact_id):
			continue
		var artifact = CardDB.ARTIFACTS[artifact_id]
		var effect = artifact.get("effect", {})
		var effect_type = effect.get("type", "")

		match effect_type:
			"battle_start_mana":
				var mana_value = effect.get("value", 0)
				deck_manager.mana += mana_value
				print("[Main] アーティファクト効果: %s → マナ+%d (現在: %.1f)" % [artifact.get("display", ""), mana_value, deck_manager.mana])

			"battle_start_tiles":
				var tile_type = effect.get("tile_type", "")
				var positions = effect.get("positions", "")
				var level = effect.get("level", 1)
				_apply_battle_start_tiles(artifact.get("display", ""), tile_type, positions, level)

func _apply_battle_start_tiles(artifact_name: String, tile_type: String, positions: String, level: int) -> void:
	# tile_typeからeffect_idへのマッピング
	var tile_map = {
		"棘": "tile_thorn",
		"砦": "tile_fortress",
		"呪い": "tile_curse",
		"毒沼": "tile_poison",
	}
	var effect_id = tile_map.get(tile_type, "")
	if effect_id == "":
		print("[Main] アーティファクト効果: %s → 不明なタイルタイプ: %s" % [artifact_name, tile_type])
		return

	# positionsから配置座標リストを生成
	var coords: Array = []
	match positions:
		"ally_front_row":
			coords = [[0, 0, 0], [0, 0, 1], [0, 0, 2]]  # side=0, row=0, col=0-2
		"ally_middle_row":
			coords = [[0, 1, 0], [0, 1, 1], [0, 1, 2]]
		"ally_back_row":
			coords = [[0, 2, 0], [0, 2, 1], [0, 2, 2]]
		"enemy_front_row":
			coords = [[1, 0, 0], [1, 0, 1], [1, 0, 2]]
		"enemy_middle_row":
			coords = [[1, 1, 0], [1, 1, 1], [1, 1, 2]]
		"enemy_back_row":
			coords = [[1, 2, 0], [1, 2, 1], [1, 2, 2]]
		_:
			print("[Main] アーティファクト効果: %s → 未対応のpositions: %s" % [artifact_name, positions])
			return

	# タイル配置
	for coord in coords:
		var side = coord[0]
		var row = coord[1]
		var col = coord[2]
		board_manager.tile_system.set_tile_effect(side, row, col, effect_id, -1.0)

	print("[Main] アーティファクト効果: %s → %s を %s に配置" % [artifact_name, tile_type, positions])

func _apply_artifact_effects_on_units() -> void:
	# ユニット配置後に適用するアーティファクト効果（stat_buff, timed_buff）
	for artifact_id in GameSession.artifacts:
		if not CardDB.ARTIFACTS.has(artifact_id):
			continue
		var artifact = CardDB.ARTIFACTS[artifact_id]
		var effect = artifact.get("effect", {})
		var effect_type = effect.get("type", "")

		match effect_type:
			"stat_buff":
				var target = effect.get("target", "")
				var stat = effect.get("stat", "")
				var value = effect.get("value", 0)
				_apply_stat_buff_to_units(artifact.get("display", ""), target, stat, value)

			"timed_buff":
				var target = effect.get("target", "")
				var stat = effect.get("stat", "")
				var value = effect.get("value", 0)
				var duration = effect.get("duration", 0)
				_apply_timed_buff_to_units(artifact.get("display", ""), target, stat, value, duration)

func _apply_stat_buff_to_units(artifact_name: String, target: String, stat: String, value: int) -> void:
	var count = 0
	for side in range(2):
		for row in range(3):
			for col in range(3):
				var unit = board_manager.units[side][row][col]
				if unit == null:
					continue

				# ターゲット判定
				var should_apply = false
				match target:
					"all_units":
						should_apply = true
					"front_row":
						should_apply = (row == 0)
					"middle_row":
						should_apply = (row == 1)
					"back_row":
						should_apply = (row == 2)
					_:
						continue

				if not should_apply:
					continue

				# ステータス適用
				match stat:
					"hp":
						unit.max_hp += value
						unit.current_hp += value
					"atk":
						unit.attack += value
					"spd":
						unit.attack_interval = max(0.1, unit.attack_interval - value)

				count += 1

	if count > 0:
		print("[Main] アーティファクト効果: %s → %d体のユニットに %s+%d" % [artifact_name, count, stat.to_upper(), value])

func _apply_timed_buff_to_units(artifact_name: String, target: String, stat: String, value: int, duration: float) -> void:
	# 時間制限バフ（hourglassなど）
	# TODO: 実装予定（バフシステムと統合が必要）
	print("[Main] アーティファクト効果: %s → timed_buff実装予定（target=%s, stat=%s, value=%d, duration=%.1fs）" % [artifact_name, target, stat, value, duration])

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
