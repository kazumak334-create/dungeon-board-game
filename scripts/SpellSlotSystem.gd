# SpellSlotSystem.gd
# v2設計: 呪文3スロット並列監視システム
extends RefCounted

# モード列挙（BATTLE=通常呪文スロット / PHASE_ACTION=フェーズアクション）
enum SlotMode { BATTLE, PHASE_ACTION }
var mode: SlotMode = SlotMode.BATTLE

# フェーズアクションモード時のフェーズ名（ヘッダー色制御用）
var current_phase_name: String = ""

# スロット構造: {spell, condition, mana_cost, enabled, synth_level, base_card_name, range_variant, value_mult, duration_mult}
var slots: Array = []

# フェーズアクション: スロット押下時のシグナル
signal slot_action_triggered(slot_index: int, action_id: String)

# 合成強化テーブル
const SYNTH_VALUE_MULT:    Dictionary = {1: 1.0, 2: 1.8, 3: 3.0}
const SYNTH_DURATION_MULT: Dictionary = {1: 1.0, 2: 1.5, 3: 2.5}
const RANGE_DISPLAY: Dictionary = {
	"default": "", "row": "【行】", "col": "【列】",
	"all_enemy": "【全敵】", "all_ally": "【自陣全体】"
}
# キャストゲージ（グローバルクールダウン、全スロット共有）
var cast_timer: float = 0.0
var cast_interval: float = 1.0
var board_manager: Node = null
var _saved_slots: Array = []  # Rest画面前のスロット状態保存（spell_name, condition）
var deck_manager: Node = null
var enemy_ai: Node = null
var spell_executor: RefCounted = null
var main_ref: Node = null  # Main.gdへの参照（ログ出力用）

# 自然言語マッピング（参照先×条件のパターン定義）
# Phase 3/4で段階的に解放する
const CONDITION_DISPLAY_NAMES: Dictionary = {
	# === Phase 3: 基本6パターン ===

	# 自陣前列
	"ally_front:avg_hp < 50": "前列ピンチ",
	"ally_front:on_enemy_attack": "前列被弾時",

	# 自陣全体
	"ally_all:avg_hp < 50": "味方ピンチ",
	"ally_all:on_enemy_attack": "被弾時",

	# 敵全体
	"enemy_all:avg_hp < 50": "追い打ち",
	"enemy_all:on_enemy_attack": "敵攻撃時",  # 実装未定

	# === Phase 4: 拡張パターン ===

	# 自陣後列
	"ally_back:avg_hp < 50": "後列ピンチ",
	"ally_back:on_enemy_attack": "後列被弾時",
	"ally_back:empty_ratio > 70": "後列空き",

	# 敵前列
	"enemy_front:avg_hp < 50": "敵前列瀕死",
	"enemy_front:on_enemy_attack": "敵前列攻撃時",
	"enemy_front:empty_ratio > 70": "敵前列空き",

	# 全体: 空きマス条件
	"ally_all:empty_ratio > 70": "盤面空き",
	"enemy_all:empty_ratio > 70": "敵陣空き",

	# 常時発動
	"always": "常時",
	"": "常時",
}

func setup(bm: Node, dm: Node, ai: Node, se: RefCounted, main: Node = null) -> void:
	board_manager = bm
	deck_manager = dm
	enemy_ai = ai
	spell_executor = se
	main_ref = main

	# 3スロット初期化
	slots.clear()
	for i in range(3):
		slots.append(_make_empty_slot())

func _make_empty_slot() -> Dictionary:
	return {
		"spell": null, "condition": "", "mana_cost": 0, "enabled": false,
		"synth_level": 1, "base_card_name": "", "range_variant": "default",
		"value_mult": 1.0, "duration_mult": 1.0,
	}

func set_slot(index: int, spell: Object, condition: String) -> void:
	if index < 0 or index >= 3:
		return

	slots[index]["spell"] = spell
	slots[index]["condition"] = condition
	slots[index]["mana_cost"] = spell.mana if spell != null else 0
	slots[index]["enabled"] = spell != null
	# 新規装填時は合成データをリセット（通常Lv1）
	slots[index]["synth_level"] = 1
	slots[index]["base_card_name"] = ""
	slots[index]["range_variant"] = "default"
	slots[index]["value_mult"] = 1.0
	slots[index]["duration_mult"] = 1.0
	print("[SpellSlot] スロット%d設定: %s (条件:%s, コスト:%d)" % [
		index,
		spell.unit_name if spell != null else "なし",
		get_condition_display_name(condition),
		slots[index]["mana_cost"]
	])

func get_condition_display_name(condition: String) -> String:
	"""条件文字列を自然言語表記に変換"""
	if CONDITION_DISPLAY_NAMES.has(condition):
		return CONDITION_DISPLAY_NAMES[condition]

	# マッピングにない場合は条件文字列をそのまま返す（将来の拡張用）
	return condition if condition != "" else "常時"

func clear_slot(index: int) -> void:
	"""内部用クリア（合成消費処理なし）。外部からは release_slot を使うこと"""
	if index < 0 or index >= 3:
		return
	slots[index] = _make_empty_slot()

func release_slot(index: int) -> void:
	"""スロット解放（合成カードはスロット離脱時に必ず消費）"""
	if index < 0 or index >= 3:
		return
	var slot = slots[index]
	if slot["spell"] == null:
		return
	if slot["synth_level"] > 1:
		# 合成カード: base_cardを捨て札、合成カード自体は消費（除外）
		var base_name: String = slot["base_card_name"]
		if base_name != "":
			GameSession.spell_discard.append(base_name)
			GameSession.spell_hand.erase(base_name)
			print("[SpellSlot] 合成カード解放: base=%s 捨て札" % base_name)
	else:
		# 通常カード: 捨て札に送る
		GameSession.spell_discard.append(slot["spell"].unit_name)
		GameSession.spell_hand.erase(slot["spell"].unit_name)
	slots[index] = _make_empty_slot()

func process_slots(delta: float) -> void:
	# キャストタイマー減算（0で下限クランプ）
	if cast_timer > 0.0:
		cast_timer = max(0.0, cast_timer - delta)

func _check_condition(condition: String) -> bool:
	# v2設計: 発動条件チェック
	# Phase 3: 基本6パターンの実装
	if condition == "" or condition == "always":
		return true

	# 条件文字列をパース: "参照先:条件タイプ 引数"
	var parts = condition.split(":")
	if parts.size() < 2:
		return false

	var target_area = parts[0]  # ally_front, ally_all, enemy_all
	var condition_expr = parts[1]  # avg_hp < 50, on_enemy_attack

	# 参照先のユニットを取得
	var units = _get_units_in_area(target_area)

	# 条件タイプ別にチェック
	if condition_expr.begins_with("avg_hp"):
		# avg_hp < 50 のパース
		var threshold = _parse_threshold(condition_expr)
		return _check_avg_hp(units, threshold)

	elif condition_expr == "on_enemy_attack":
		# TODO: イベントトリガー型は別途実装
		# 現状はタイマーベースのため未実装
		return false

	elif condition_expr.begins_with("empty_ratio"):
		# empty_ratio > 70 のパース（Phase 4）
		var threshold = _parse_threshold(condition_expr)
		return _check_empty_ratio(target_area, threshold)

	return false

func _get_units_in_area(area: String) -> Array:
	"""参照先のユニット配列を取得"""
	if board_manager == null:
		return []

	var units: Array = []
	var board = board_manager.board

	match area:
		"ally_front":
			# 自陣前列（side=0, col=2）
			for row in range(3):
				if board[0][row][2] != null:
					units.append(board[0][row][2])

		"ally_all":
			# 自陣全体（side=0）
			for row in range(3):
				for col in range(3):
					if board[0][row][col] != null:
						units.append(board[0][row][col])

		"enemy_all":
			# 敵陣全体（side=1）
			for row in range(3):
				for col in range(3):
					if board[1][row][col] != null:
						units.append(board[1][row][col])

		"ally_back":
			# Phase 4: 自陣後列（side=0, col=0）
			for row in range(3):
				if board[0][row][0] != null:
					units.append(board[0][row][0])

		"enemy_front":
			# Phase 4: 敵前列（side=1, col=0）
			for row in range(3):
				if board[1][row][0] != null:
					units.append(board[1][row][0])

	return units

func _parse_threshold(expr: String) -> float:
	"""条件式から閾値を抽出（avg_hp < 50 → 50.0）"""
	var parts = expr.split(" ")
	if parts.size() >= 3:
		return float(parts[2])
	return 0.0

func _check_avg_hp(units: Array, threshold: float) -> bool:
	"""平均HP率が閾値未満か判定"""
	if units.is_empty():
		return false

	var total_hp_ratio: float = 0.0
	for unit in units:
		if unit == null:
			continue
		var hp_ratio = (float(unit.hp) / float(unit.max_hp)) * 100.0
		total_hp_ratio += hp_ratio

	var avg_hp_ratio = total_hp_ratio / float(units.size())
	return avg_hp_ratio < threshold

func _check_empty_ratio(area: String, threshold: float) -> bool:
	"""空きマス比率が閾値以上か判定（Phase 4実装）"""
	if board_manager == null:
		return false

	var board = board_manager.board
	var total_cells = 0
	var empty_cells = 0

	# エリア別に空きマスをカウント
	match area:
		"ally_all":
			total_cells = 9
			for row in range(3):
				for col in range(3):
					if board[0][row][col] == null:
						empty_cells += 1

		"enemy_all":
			total_cells = 9
			for row in range(3):
				for col in range(3):
					if board[1][row][col] == null:
						empty_cells += 1

		"ally_back":
			total_cells = 3
			for row in range(3):
				if board[0][row][0] == null:
					empty_cells += 1

		"enemy_front":
			total_cells = 3
			for row in range(3):
				if board[1][row][0] == null:
					empty_cells += 1

	if total_cells == 0:
		return false

	var empty_ratio = (float(empty_cells) / float(total_cells)) * 100.0
	return empty_ratio > threshold

func can_cast(index: int) -> bool:
	"""発動可否判定（UI表示・発動前チェック兼用）"""
	if index < 0 or index >= 3:
		return false
	var slot = slots[index]
	if not slot["enabled"] or slot["spell"] == null:
		return false
	if deck_manager == null or deck_manager.mana < slot["mana_cost"]:
		return false
	# 条件チェック（既存 _check_condition を流用）
	if not _check_condition(slot["condition"]):
		return false
	# キャストゲージチェック（クールダウン中は発動不可）
	if cast_timer > 0.0:
		return false
	return true

func get_cast_block_reason(index: int) -> String:
	"""発動不可理由取得（エラー表示用）"""
	if index < 0 or index >= 3:
		return "empty"
	var slot = slots[index]
	if not slot["enabled"] or slot["spell"] == null:
		return "empty"
	if deck_manager == null or deck_manager.mana < slot["mana_cost"]:
		return "mana"
	if not _check_condition(slot["condition"]):
		return "condition"
	if cast_timer > 0.0:
		return "cooldown"
	return ""

func cast_spell(index: int) -> bool:
	"""手動発動API"""
	if not can_cast(index):
		return false
	_trigger_spell(index, slots[index])
	return true

func _trigger_spell(index: int, slot: Dictionary) -> void:
	var spell = slot["spell"]
	var condition = slot["condition"]
	var display_name = get_condition_display_name(condition)
	var synth_level: int = slot.get("synth_level", 1)
	var is_synth: bool   = synth_level > 1

	# マナ消費（合成カードはbase_cardのコスト）
	deck_manager.mana = max(0.0, deck_manager.mana - slot["mana_cost"])
	cast_timer = cast_interval

	# 呪文実行（合成強化コンテキストを渡す）
	var synth_ctx: Dictionary = {}
	if is_synth:
		synth_ctx = {
			"synth_level":    synth_level,
			"range_variant":  slot.get("range_variant", "default"),
			"value_mult":     slot.get("value_mult", 1.0),
			"duration_mult":  slot.get("duration_mult", 1.0),
		}
	spell_executor.execute(spell, 0, board_manager, deck_manager, enemy_ai, synth_ctx)

	# ログ
	var log_text = _build_activation_log(spell.unit_name, condition, display_name)
	if is_synth:
		log_text += " [Lv%d合成 %s]" % [synth_level, RANGE_DISPLAY.get(slot.get("range_variant", ""), "")]
	if main_ref != null and main_ref.has_method("_add_log"):
		main_ref._add_log(log_text)
	else:
		print("[SpellSlot] " + log_text)

	# 消費処理
	if is_synth:
		# 合成カード: base_cardを捨て札・合成カード自体は消費（除外）
		var base_name: String = slot.get("base_card_name", spell.unit_name)
		GameSession.spell_discard.append(base_name)
		GameSession.spell_hand.erase(base_name)
		clear_slot(index)
		draw_to_fill_slots()
	elif spell.is_consumable:
		GameSession.spell_discard.append(spell.unit_name)
		GameSession.spell_hand.erase(spell.unit_name)
		clear_slot(index)
		draw_to_fill_slots()

func _build_activation_log(spell_name: String, condition: String, display_name: String) -> String:
	"""発動ログを構築（条件達成時の詳細情報を含む）"""
	var context = ""

	# 条件別に詳細情報を追加
	if condition.contains("avg_hp"):
		var units = _get_units_in_area(condition.split(":")[0])
		if not units.is_empty():
			var total_hp_ratio = 0.0
			for unit in units:
				if unit != null:
					total_hp_ratio += (float(unit.hp) / float(unit.max_hp)) * 100.0
			var avg_hp = int(total_hp_ratio / float(units.size()))
			context = "（HP %d%%）" % avg_hp

	elif condition.contains("empty_ratio"):
		# Phase 4実装時に追加
		pass

	return "%s！%s発動%s" % [display_name, spell_name, context]

# ---- 呪文合成 ----

func _synth_key(a: String, b: String) -> String:
	var arr = [a, b]
	arr.sort()
	return "+".join(arr)

func _get_base_name(slot: Dictionary) -> String:
	return slot["base_card_name"] if slot["base_card_name"] != "" else (slot["spell"].unit_name if slot["spell"] != null else "")

func can_synthesize(slot_from: int, slot_to: int) -> bool:
	return get_synth_reason(slot_from, slot_to) == ""

func get_synth_reason(slot_from: int, slot_to: int) -> String:
	if slot_from == slot_to or slot_from < 0 or slot_to < 0 or slot_from >= 3 or slot_to >= 3:
		return "invalid"
	var sf = slots[slot_from]
	var st = slots[slot_to]
	if sf["spell"] == null: return "empty_source"
	if st["spell"] == null: return "empty_target"
	if st["synth_level"] >= 3:  return "max_level"
	if deck_manager == null or deck_manager.mana < sf["mana_cost"]: return "mana"
	var from_name: String = _get_base_name(sf)
	var to_name:   String = _get_base_name(st)
	if from_name == to_name:
		return ""
	# 異名合成テーブルチェック
	var cdb = load("res://scripts/CardDB.gd")
	var key: String = _synth_key(from_name, to_name)
	if cdb.SPELL_SYNTHESIS.has(key):
		return ""
	return "no_recipe"

func synthesize(slot_from: int, slot_to: int) -> bool:
	if not can_synthesize(slot_from, slot_to):
		return false
	var sf = slots[slot_from]
	var st = slots[slot_to]
	var from_name: String = _get_base_name(sf)
	var to_name:   String = _get_base_name(st)

	# マナ消費（ドラッグ元コスト）
	deck_manager.mana = max(0.0, deck_manager.mana - sf["mana_cost"])

	# ドラッグ元カードを捨て札（合成元カードはスロット離脱 → 消費ルール適用）
	if sf["synth_level"] > 1:
		# 合成カードが合成元の場合: base_cardを捨て札、合成カード除外
		if sf["base_card_name"] != "":
			GameSession.spell_discard.append(sf["base_card_name"])
			GameSession.spell_hand.erase(sf["base_card_name"])
	else:
		GameSession.spell_discard.append(from_name)
		GameSession.spell_hand.erase(from_name)

	# 新レベル計算: min(from_level + to_level, 3)
	var new_level: int = min(sf["synth_level"] + st["synth_level"], 3)

	# 異名合成: 結果スペル名を解決
	var result_base_name: String = to_name
	if from_name != to_name:
		var cdb = load("res://scripts/CardDB.gd")
		var key: String = _synth_key(from_name, to_name)
		result_base_name = cdb.SPELL_SYNTHESIS.get(key, {}).get("result", to_name)

	# range_variant決定
	var range_var: String = _determine_range_variant(new_level, result_base_name)

	# ターゲットスロット更新
	st["synth_level"]    = new_level
	st["base_card_name"] = to_name       # 発動時に捨て札に送るカード（ターゲット元）
	st["range_variant"]  = range_var
	st["value_mult"]     = SYNTH_VALUE_MULT.get(new_level, 1.0)
	st["duration_mult"]  = SYNTH_DURATION_MULT.get(new_level, 1.0)
	# mana_cost はターゲット元のコストを維持

	# ドラッグ元スロットをクリア → 次のカードをドロー
	slots[slot_from] = _make_empty_slot()
	draw_to_fill_slots()

	print("[SpellSlot] 合成完了: Lv%d %s (range:%s ×%.1f)" % [new_level, result_base_name, range_var, st["value_mult"]])
	return true

func _determine_range_variant(level: int, base_card_name: String) -> String:
	if level == 2:
		return "row" if randf() < 0.5 else "col"
	elif level == 3:
		var cdb = load("res://scripts/CardDB.gd")
		var target: String = cdb.SPELLS.get(base_card_name, {}).get("target", "enemy")
		if target in ["self", "ally", "ally_all"]:
			return "all_ally"
		return "all_enemy"
	return "default"

func release_all_slots() -> void:
	"""全スロット解放（外部効果「全捨て札」等から呼ぶ）"""
	for i in range(3):
		release_slot(i)

func discard_slot(index: int) -> bool:
	"""指定スロットの呪文を捨て札に移動（右クリック破棄）。合成カードは消費。"""
	if index < 0 or index >= 3:
		return false
	if slots[index]["spell"] == null:
		return false
	var slot = slots[index]
	print("[SpellSlot] スロット%d破棄: %s (Lv%d)" % [index, slot["spell"].unit_name, slot["synth_level"]])
	release_slot(index)  # 合成カードはrelease_slot内で消費処理
	draw_to_fill_slots()
	return true

func draw_to_fill_slots() -> void:
	for i in range(3):
		if slots[i]["spell"] != null:
			continue
		if GameSession.spell_deck.is_empty():
			if GameSession.spell_discard.is_empty():
				continue
			GameSession.spell_deck = GameSession.spell_discard.duplicate()
			GameSession.spell_discard.clear()
			GameSession.spell_deck.shuffle()
			print("[SpellSlot] 捨て札%d枚をデッキに戻す" % GameSession.spell_deck.size())
		if GameSession.spell_deck.is_empty():
			continue
		var spell_name: String = GameSession.spell_deck.pop_front()
		GameSession.spell_hand.append(spell_name)
		if deck_manager != null:
			var spell_obj = deck_manager.get_spell_card_by_name(spell_name)
			if spell_obj != null:
				set_slot(i, spell_obj, "always")
				print("[SpellSlot] スロット%dドロー: %s" % [i, spell_name])

# ---- フェーズアクションモード ----

func clear_spell_display() -> void:
	"""バトル終了時の表示専用クリア。GameSession.spell_* には触らない。"""
	# 現在のスロット設定を保存（呪文名+条件）
	_saved_slots = []
	for i in range(3):
		var s = slots[i]
		if s["spell"] != null:
			_saved_slots.append({"spell_name": s["spell"].unit_name, "condition": s["condition"]})
		else:
			_saved_slots.append(null)
	# バトル中に手札・捨て札へ移動したカードをデッキに戻す（Rest画面のデッキ設定表示用）
	for sn in GameSession.spell_hand:
		GameSession.spell_deck.append(sn)
	GameSession.spell_hand.clear()
	for sn in GameSession.spell_discard:
		GameSession.spell_deck.append(sn)
	GameSession.spell_discard.clear()
	for i in range(3):
		slots[i]["spell"] = null
		slots[i]["condition"] = ""
		slots[i]["mana_cost"] = 0
		slots[i]["enabled"] = false
		slots[i]["synth_level"] = 1
		slots[i]["base_card_name"] = ""
		slots[i]["range_variant"] = "default"
		# フェーズアクションフィールドもクリア
		slots[i].erase("is_action")
		slots[i].erase("action_id")
		slots[i].erase("action_label")
		slots[i].erase("action_desc")
		slots[i].erase("action_cost_text")
	print("[SpellSlot] 表示クリア（デッキ未変更）")

func set_phase_actions(actions: Array) -> void:
	"""フェーズアクションをスロットにセットしてPHASE_ACTIONモードに切替"""
	mode = SlotMode.PHASE_ACTION
	for i in range(min(3, actions.size())):
		var act: Dictionary = actions[i]
		slots[i] = {
			"spell": null,
			"condition": "",
			"mana_cost": 0,
			"enabled": act.get("enabled", false),
			"synth_level": 1,
			"base_card_name": "",
			"range_variant": "default",
			"value_mult": 1.0,
			"duration_mult": 1.0,
			"is_action": true,
			"action_id": act.get("action_id", ""),
			"action_label": act.get("action_label", ""),
			"action_desc": act.get("action_desc", ""),
			"action_cost_text": act.get("action_cost_text", ""),
		}
	# アクション数が3未満の場合は残スロットをクリア
	for i in range(actions.size(), 3):
		slots[i] = _make_empty_slot()
	if not actions.is_empty():
		current_phase_name = actions[0].get("phase_name", "")
	print("[SpellSlot] フェーズアクションセット: %d件" % actions.size())

func restore_battle_mode() -> void:
	"""BATTLEモードに戻す。保存スロットがあれば復元、なければ通常ドロー"""
	mode = SlotMode.BATTLE
	current_phase_name = ""
	if not _saved_slots.is_empty() and deck_manager != null:
		_restore_saved_slots()
	else:
		draw_to_fill_slots()
	_saved_slots = []
	print("[SpellSlot] BATTLEモード復帰")

func _restore_saved_slots() -> void:
	"""保存したスロット設定を復元する。入手済みでない呪文は通常ドローで補填"""
	# 利用可能な呪文名リスト（deck + discard + hand）
	var available: Array = GameSession.spell_deck.duplicate()
	for s in GameSession.spell_discard:
		if not available.has(s):
			available.append(s)
	for s in GameSession.spell_hand:
		if not available.has(s):
			available.append(s)

	for i in range(3):
		var saved = _saved_slots[i] if i < _saved_slots.size() else null
		if saved == null:
			continue
		var spell_name: String = saved["spell_name"]
		var condition: String = saved["condition"]
		# spell_deck/discard/hand に存在すれば復元
		if available.has(spell_name):
			# spell_deck から取り出してセット（deck→pop, discard/hand→erase）
			if GameSession.spell_deck.has(spell_name):
				GameSession.spell_deck.erase(spell_name)
			elif GameSession.spell_discard.has(spell_name):
				GameSession.spell_discard.erase(spell_name)
			GameSession.spell_hand.append(spell_name)
			var spell_obj = deck_manager.get_spell_card_by_name(spell_name)
			if spell_obj != null:
				set_slot(i, spell_obj, condition)
				print("[SpellSlot] スロット%d復元: %s [%s]" % [i, spell_name, condition])
			else:
				clear_slot(i)
		# 存在しない場合はそのままにして draw_to_fill_slots() が補填する
	# 空スロットを補填
	draw_to_fill_slots()

func cast_action(slot_index: int) -> bool:
	"""PHASE_ACTIONモードでスロット押下時に呼ぶ。slot_action_triggeredをemit。"""
	if mode != SlotMode.PHASE_ACTION:
		return false
	if slot_index < 0 or slot_index >= 3:
		return false
	var slot = slots[slot_index]
	if not slot.get("is_action", false):
		return false
	if not slot.get("enabled", false):
		print("[SpellSlot] アクション%d: 無効（押下不可）" % slot_index)
		return false
	var aid: String = slot.get("action_id", "")
	print("[SpellSlot] アクション%d実行: %s" % [slot_index, aid])
	slot_action_triggered.emit(slot_index, aid)
	return true
