# SpellSlotSystem.gd
# v2設計: 呪文3スロット並列監視システム
extends RefCounted

# スロット構造: {spell: Object, condition: String, mana_cost: int, enabled: bool}
var slots: Array = []
var board_manager: Node = null
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
		slots.append({
			"spell": null,
			"condition": "",
			"mana_cost": 0,
			"enabled": false
		})

func set_slot(index: int, spell: Object, condition: String) -> void:
	if index < 0 or index >= 3:
		return

	slots[index]["spell"] = spell
	slots[index]["condition"] = condition
	slots[index]["mana_cost"] = spell.mana if spell != null else 0
	slots[index]["enabled"] = spell != null
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
	if index < 0 or index >= 3:
		return

	slots[index]["spell"] = null
	slots[index]["condition"] = ""
	slots[index]["mana_cost"] = 0
	slots[index]["enabled"] = false

func process_slots(delta: float) -> void:
	# Phase A: 自動発動を廃止。手動発動（cast_spell）のみ。
	# この関数は呼び出し元から削除される。
	pass

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

	# マナ消費
	deck_manager.mana -= slot["mana_cost"]
	deck_manager.mana = max(0.0, deck_manager.mana)

	# 呪文実行
	spell_executor.execute(spell, 0, board_manager, deck_manager, enemy_ai)

	# 詳細ログ出力（Main.gdのログシステムに統合）
	var log_text = _build_activation_log(spell.unit_name, condition, display_name)
	if main_ref != null and main_ref.has_method("_add_log"):
		main_ref._add_log(log_text)
	else:
		print("[SpellSlot] " + log_text)

	# 消費型呪文ならスロットをクリア
	if spell.get("is_consumable", false):
		clear_slot(index)

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

func discard_slot(index: int) -> bool:
	"""指定スロットの呪文を捨て札に移動（右クリック破棄機能）"""
	if index < 0 or index >= 3:
		return false
	if slots[index]["spell"] == null:
		return false

	var spell = slots[index]["spell"]
	deck_manager.discard.append(spell)
	print("[SpellSlot] スロット%d破棄: %s" % [index, spell.unit_name])
	clear_slot(index)
	return true
