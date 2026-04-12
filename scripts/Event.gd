# Event.gd
# イベント画面: ランダムイベント選択肢
extends Control

const UIF = preload("res://scripts/UIFactory.gd")

var _event_data: Dictionary = {}
var _result_panel: Control = null

func _ready() -> void:
	# ランダムイベント選択
	_select_random_event()
	_build_ui()

func _select_random_event() -> void:
	# 現在のActに対応するイベントプールを取得
	var event_pool: Array = []
	for event_id in CardDB.EVENTS:
		var event = CardDB.EVENTS[event_id]
		var acts = event.get("act", [])
		# 既に訪問済みのイベントは除外
		if event_id in GameSession.visited_events:
			continue
		# 現在のActに対応するイベントのみ
		if GameSession.current_act in acts:
			event_pool.append(event_id)

	if event_pool.is_empty():
		print("[Event] WARNING: イベントプールが空（全て訪問済み or Act対応なし）")
		# フォールバック: 全イベントから選択
		for event_id in CardDB.EVENTS:
			event_pool.append(event_id)

	if event_pool.is_empty():
		print("[Event] ERROR: イベントが1つも定義されていません")
		return

	# ランダム選択
	var selected_id = event_pool[randi() % event_pool.size()]
	GameSession.current_event_id = selected_id
	GameSession.visited_events.append(selected_id)
	_event_data = CardDB.EVENTS[selected_id].duplicate(true)
	_event_data["id"] = selected_id

	print("[Event] イベント選択: %s (Act %d)" % [_event_data.get("display", ""), GameSession.current_act])

func _build_ui() -> void:
	UIF.add_bg(self)

	# 共通タスクバー（最上部36px）
	var TaskbarClass = load("res://scripts/CommonTaskbar.gd")
	var taskbar = TaskbarClass.new()
	taskbar.attach(self, SceneManager.EVENT)
	taskbar.set_title("イベント")

	# イベントタイトル
	var title = Label.new()
	title.text = _event_data.get("display", "???")
	title.position = Vector2(340, 80)
	title.size = Vector2(600, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	add_child(title)

	# イベントテキストパネル
	var panel = UIF.create_panel(Vector2(340, 120), Vector2(600, 180), Color(0.12, 0.12, 0.18), Color(0.3, 0.3, 0.4))
	add_child(panel)

	var text = Label.new()
	text.text = _event_data.get("text", "...")
	text.position = Vector2(360, 140)
	text.size = Vector2(560, 140)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 15)
	text.add_theme_color_override("font_color", UIF.TEXT_COLOR)
	add_child(text)

	# 選択肢ボタン
	var choices = _event_data.get("choices", [])
	var y_offset = 320
	for i in range(choices.size()):
		var choice = choices[i]
		var label = choice.get("label", "選択肢")
		var btn = UIF.add_button(self, label, Vector2(440, y_offset), Vector2(400, 50), 16, func(): _on_choice_selected(i))
		# リスク（HP/Gold消費）がある選択肢は色を変える
		var cost = choice.get("cost", {})
		if cost.size() > 0:
			btn.modulate = Color(1.2, 0.9, 0.8)  # 暖色系
		y_offset += 60

func _on_choice_selected(choice_index: int) -> void:
	var choices = _event_data.get("choices", [])
	if choice_index >= choices.size():
		return

	var choice = choices[choice_index]

	# コスト支払い
	var cost = choice.get("cost", {})
	if not _pay_cost(cost):
		return

	# 結果適用
	var results = choice.get("results", [])
	_apply_results(results)

	# 結果表示に切り替え
	_show_results(choice.get("label", ""), results)

func _pay_cost(cost: Dictionary) -> bool:
	if cost.is_empty():
		return true

	var cost_type = cost.get("type", "")
	var value = cost.get("value", 0)

	match cost_type:
		"hp":
			# TODO: 本体HPシステムが実装されたら対応
			print("[Event] HP消費: %d（未実装）" % value)
			return true
		"gold":
			if GameSession.gold < value:
				print("[Event] Gold不足")
				return false
			GameSession.gold -= value
			return true
		_:
			return true

func _apply_results(results: Array) -> void:
	for result in results:
		var result_type = result.get("type", "")

		match result_type:
			"gold":
				var value = result.get("value", 0)
				if typeof(value) == TYPE_ARRAY:
					# 範囲指定の場合
					value = randi_range(value[0], value[1])
				GameSession.gold += value
				print("[Event] Gold %+d → %d" % [value, GameSession.gold])

			"hp":
				var value = result.get("value", 0)
				# TODO: 本体HPシステムが実装されたら対応
				print("[Event] HP %+d（未実装）" % value)

			"relic":
				var relic_id = result.get("relic_id", "")
				if relic_id != "":
					GameSession.relics.append(relic_id)
					print("[Event] レリック獲得: %s" % relic_id)

			"relic_choice":
				# TODO: レリック選択UI実装
				var count = result.get("count", 1)
				var weights = result.get("rarity_weights", {})
				print("[Event] レリック選択: %d個（未実装）" % count)

			"card_choice":
				# TODO: カード選択UI実装
				var count = result.get("count", 1)
				var rarity = result.get("rarity", "common")
				print("[Event] カード選択: %d枚 rarity=%s（未実装）" % [count, rarity])

			"alert_level":
				var value = result.get("value", 0)
				GameSession.alert_level = max(0, GameSession.alert_level + value)
				print("[Event] 警戒レベル %+d → %d" % [value, GameSession.alert_level])

			"sp":
				var value = result.get("value", 0)
				GameSession.skill_points += value
				print("[Event] SP %+d → %d" % [value, GameSession.skill_points])

			"flavor":
				# フレーバーテキストは結果表示でのみ使用
				pass

func _show_results(choice_label: String, results: Array) -> void:
	# 既存のUI要素をクリア
	for child in get_children():
		child.queue_free()

	UIF.add_bg(self)

	# 共通タスクバー
	var TaskbarClass = load("res://scripts/CommonTaskbar.gd")
	var taskbar = TaskbarClass.new()
	taskbar.attach(self, SceneManager.EVENT)
	taskbar.set_title("イベント結果")

	# 結果パネル
	var panel = UIF.create_panel(Vector2(340, 120), Vector2(600, 400), Color(0.12, 0.12, 0.18), Color(0.3, 0.3, 0.4))
	add_child(panel)

	# 選択した行動
	var action_label = Label.new()
	action_label.text = "選択: %s" % choice_label
	action_label.position = Vector2(360, 140)
	action_label.size = Vector2(560, 30)
	action_label.add_theme_font_size_override("font_size", 16)
	action_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	add_child(action_label)

	# 結果テキスト
	var result_text = _build_result_text(results)
	var result_label = Label.new()
	result_label.text = result_text
	result_label.position = Vector2(380, 180)
	result_label.size = Vector2(520, 300)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 15)
	result_label.add_theme_color_override("font_color", UIF.TEXT_COLOR)
	add_child(result_label)

	# マップへ戻るボタン
	UIF.add_button(self, "マップへ戻る", Vector2(440, 540), Vector2(400, 50), 16, func(): SceneManager.go_to(SceneManager.MAP_SELECT))

func _build_result_text(results: Array) -> String:
	if results.is_empty():
		return "何も起こらなかった。"

	var lines: Array = []

	for result in results:
		var result_type = result.get("type", "")

		match result_type:
			"gold":
				var value = result.get("value", 0)
				if typeof(value) == TYPE_ARRAY:
					value = randi_range(value[0], value[1])
				if value > 0:
					lines.append("+ Gold %d" % value)
				else:
					lines.append("- Gold %d" % abs(value))

			"hp":
				var value = result.get("value", 0)
				if value > 0:
					lines.append("+ HP %d" % value)
				else:
					lines.append("- HP %d" % abs(value))

			"relic":
				var relic_id = result.get("relic_id", "")
				if CardDB.RELICS.has(relic_id):
					var relic_name = CardDB.RELICS[relic_id].get("display", relic_id)
					lines.append("+ レリック「%s」獲得" % relic_name)

			"alert_level":
				var value = result.get("value", 0)
				if value > 0:
					lines.append("警戒レベル +%d" % value)
				elif value < 0:
					lines.append("警戒レベル %d" % value)

			"sp":
				var value = result.get("value", 0)
				lines.append("+ SP %d" % value)

			"flavor":
				var flavor = result.get("text", "")
				if flavor != "":
					lines.append("\n" + flavor)

	return "\n".join(lines)
