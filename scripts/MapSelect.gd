# MapSelect.gd
# マップ選択画面（StS風横方向分岐ツリー）
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")
const MapGenerator = preload("res://scripts/MapGenerator.gd")

var _taskbar: RefCounted = null
var _node_buttons: Dictionary = {}  # node_id -> Button

# ルートメモ機能
var _route_memo: Array = []  # [node_id, node_id, ...]
var _is_drawing_route: bool = false
var _route_lines: Array = []  # Line2D配列
var _route_info_panel: PanelContainer = null

# ノード種別色定義
const NODE_COLORS = {
	"battle": Color(0.8, 0.3, 0.3),
	"elite": Color(0.9, 0.5, 0.2),
	"gather": Color(0.3, 0.7, 0.4),
	"shop": Color(0.9, 0.8, 0.3),
	"event": Color(0.5, 0.5, 0.9),
	"boss": Color(0.9, 0.2, 0.5),
	"rest": Color(0.3, 0.9, 0.5),
}

# ノード種別記号
const NODE_SYMBOLS = {
	"battle": "⚔",
	"elite": "★",
	"gather": "⛏",
	"shop": "$",
	"event": "?",
	"boss": "☠",
	"rest": "♥",
}

func _ready() -> void:
	_build_ui()
	# ルートメモ用のマウス入力処理
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# 右クリック開始: ルート描画モード
				_is_drawing_route = true
				_clear_route()
			else:
				# 右クリック終了: ルート確定
				_is_drawing_route = false
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 左クリック: ルートクリア
			if not _route_memo.is_empty():
				_clear_route()

func _process(_delta: float) -> void:
	if _is_drawing_route:
		# ドラッグ中: マウス位置のノードをルートに追加
		_update_route_from_mouse()

func _build_ui() -> void:
	UIF.add_bg(self)

	# 共通タスクバー（最上部36px）
	_taskbar = TaskbarClass.new()
	_taskbar.attach(self, SceneManager.MAP_SELECT)

	# マップデータ確保
	_ensure_map_data()

	# 環境が未設定ならランダム選択
	if GameSession.base_environment == "" or GameSession.base_environment == "env_none":
		_randomize_environment()

	# タイトル表示（上余白の中央に固定）
	var env_def = CardDB.ENVIRONMENTS.get(GameSession.base_environment, {})
	var env_display = env_def.get("display", "平原")
	var title_text = "Act %d - %s" % [GameSession.current_act, env_display]
	const MARGIN_Y = 60
	UIF.add_title(self, title_text, int(MARGIN_Y / 2))

	# マップ描画
	_draw_map()

func _randomize_environment() -> void:
	var env_ids = CardDB.ENVIRONMENTS.keys()
	if env_ids.size() > 0:
		env_ids.shuffle()
		GameSession.base_environment = env_ids[0]

func _ensure_map_data() -> void:
	"""マップデータが存在しない場合は新規生成"""
	if GameSession.map_data.is_empty():
		var gen = MapGenerator.new()
		if GameSession.map_seed == 0:
			GameSession.map_seed = randi()
		if GameSession.race_theme == "":
			var themes = ["slime", "beast", "undead"]
			GameSession.race_theme = themes[randi() % themes.size()]
		GameSession.map_data = gen.generate(GameSession.map_seed, GameSession.race_theme)
		print("[MapSelect] マップ生成完了 seed:%d theme:%s" % [GameSession.map_seed, GameSession.race_theme])

func grid_to_screen(col: int, row: int) -> Vector2:
	"""グリッド座標を画面座標に変換"""
	var vp = get_viewport_rect().size

	const GRID_COLS = 10
	const GRID_ROWS = 10
	const MARGIN_X = 80.0
	const MARGIN_Y = 60.0
	const TITLE_HEIGHT = 50.0

	var usable_w = vp.x - MARGIN_X * 2.0
	var usable_h = vp.y - MARGIN_Y * 2.0 - TITLE_HEIGHT
	var x = MARGIN_X + float(col) * (usable_w / float(GRID_COLS - 1))
	var y = MARGIN_Y + TITLE_HEIGHT + float(row) * (usable_h / float(GRID_ROWS - 1))
	return Vector2(x, y)

func _get_current_act_data() -> Dictionary:
	"""現在のActデータを取得"""
	var acts = GameSession.map_data.get("acts", [])
	if acts.size() >= GameSession.current_act:
		return acts[GameSession.current_act - 1]
	return {}

func _calculate_node_positions(act_data: Dictionary) -> Dictionary:
	"""ノードの座標を計算（グリッドベース・Python版準拠）"""
	var positions = {}
	var nodes = act_data.get("nodes", [])
	if nodes.is_empty():
		return positions

	# 各ノードのグリッド座標を画面座標に変換
	for node in nodes:
		var col = node.get("col", 0)
		var row = node.get("row", 0)
		positions[node.get("id", "")] = grid_to_screen(col, row)

	return positions

func _draw_map() -> void:
	"""マップ全体を描画"""
	var act_data = _get_current_act_data()
	if act_data.is_empty():
		print("[MapSelect] Actデータが空です")
		return

	var node_positions = _calculate_node_positions(act_data)
	_draw_connections(act_data, node_positions)
	_draw_nodes(act_data, node_positions)

func _draw_connections(act_data: Dictionary, positions: Dictionary) -> void:
	"""ノード間の接続線を描画"""
	var nodes = act_data.get("nodes", [])
	for node in nodes:
		var node_id = node.get("id", "")
		var conns = node.get("connections", [])
		var node_pos = positions.get(node_id, Vector2.ZERO)

		for conn_id in conns:
			var conn_pos = positions.get(conn_id, Vector2.ZERO)
			if conn_pos == Vector2.ZERO:
				continue

			var line = Line2D.new()
			line.add_point(conn_pos + Vector2(25, 25))  # ノード中心からスタート
			line.add_point(node_pos + Vector2(25, 25))  # ノード中心へ
			line.width = 3

			# 接続線の色（状態により変化）
			if _is_node_completed(node_id):
				line.default_color = Color(0.4, 0.7, 0.4)  # 訪問済み: 緑
			elif _is_node_reachable(node_id):
				line.default_color = Color(0.9, 0.8, 0.3)  # 到達可能: 黄
			else:
				line.default_color = Color(0.3, 0.3, 0.3)  # 未到達: 暗灰

			add_child(line)

func _draw_nodes(act_data: Dictionary, positions: Dictionary) -> void:
	"""ノードを描画"""
	var nodes = act_data.get("nodes", [])
	for node in nodes:
		var node_id = node.get("id", "")
		var node_type = node.get("type", "battle")
		var pos = positions.get(node_id, Vector2.ZERO)

		var panel = PanelContainer.new()
		panel.position = pos
		panel.size = Vector2(50, 50)

		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(25)  # 円形

		# ノード状態による色分け
		if GameSession.current_node == node_id:
			# 現在地: 青グロー
			style.bg_color = Color(0.2, 0.4, 0.9)
			style.set_border_width_all(3)
			style.border_color = Color(0.4, 0.6, 1.0)
		elif _is_node_completed(node_id):
			# 訪問済み: 灰色
			style.bg_color = Color(0.3, 0.3, 0.3)
		elif _is_node_reachable(node_id):
			# 到達可能: 種別色
			style.bg_color = NODE_COLORS.get(node_type, Color(0.5, 0.5, 0.5))
		else:
			# 未到達: 暗灰色
			style.bg_color = Color(0.15, 0.15, 0.15)

		panel.add_theme_stylebox_override("panel", style)
		add_child(panel)

		# ノード記号
		var label = Label.new()
		label.text = NODE_SYMBOLS.get(node_type, "●")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = pos + Vector2(0, 0)
		label.size = Vector2(50, 50)
		label.add_theme_font_size_override("font_size", 24)
		add_child(label)

		# 警告マーク（戦闘ノードのみ）
		if node_type in ["battle", "elite"]:
			_add_alert_marker(pos, GameSession.alert_level)

		# クリック可能なノードにボタン追加
		if _is_node_reachable(node_id) and GameSession.current_node != node_id:
			var btn = Button.new()
			btn.position = pos
			btn.size = Vector2(50, 50)
			btn.text = ""
			btn.tooltip_text = _get_node_tooltip(node)
			btn.modulate = Color(1, 1, 1, 0)  # 透明ボタン
			btn.pressed.connect(func(): _on_node_clicked(node_id, node_type))
			add_child(btn)
			_node_buttons[node_id] = btn

func _is_node_completed(node_id: String) -> bool:
	"""ノードが訪問済みか判定"""
	return node_id in GameSession.completed_nodes

func _is_node_reachable(node_id: String) -> bool:
	"""ノードが到達可能か判定"""
	# 初回（current_nodeが空）なら col 0のノードが到達可能
	if GameSession.current_node == "":
		var act_data = _get_current_act_data()
		for node in act_data.get("nodes", []):
			if node.get("id", "") == node_id and node.get("col", -1) == 0:
				return true
		return false

	# 現在地から直接繋がっているノードが到達可能
	var act_data = _get_current_act_data()
	for node in act_data.get("nodes", []):
		if node.get("id", "") == node_id:
			var conns = node.get("connections", [])
			return GameSession.current_node in conns
	return false

func _get_node_tooltip(node: Dictionary) -> String:
	"""ノードのツールチップテキスト生成"""
	var node_type = node.get("type", "")
	var type_names = {
		"battle": "戦闘",
		"elite": "エリート戦",
		"gather": "素材採集",
		"shop": "ショップ",
		"event": "イベント",
		"boss": "ボス戦",
		"rest": "レスト（警戒-2）",
	}
	return type_names.get(node_type, "不明")

func _on_node_clicked(node_id: String, node_type: String) -> void:
	"""ノードクリック時の処理"""
	print("[MapSelect] ノードクリック: %s (type:%s)" % [node_id, node_type])

	# 現在地を更新
	if GameSession.current_node != "":
		GameSession.completed_nodes.append(GameSession.current_node)
	GameSession.current_node = node_id

	# ノード種別に応じてシーン遷移
	match node_type:
		"battle":
			GameSession.alert_level += 1
			GameSession.battle_type = "normal"
			SceneManager.go_to(SceneManager.DECK_PREP)
		"elite":
			GameSession.alert_level += 1
			GameSession.battle_type = "elite"
			SceneManager.go_to(SceneManager.DECK_PREP)
		"boss":
			GameSession.battle_type = "boss"
			SceneManager.go_to(SceneManager.DECK_PREP)
		"rest":
			GameSession.alert_level = max(0, GameSession.alert_level - 2)
			print("[MapSelect] レスト: 警戒レベル -2 → %d" % GameSession.alert_level)
			SceneManager.go_to(SceneManager.MAP_SELECT)
		"shop":
			GameSession.alert_level = max(0, GameSession.alert_level - 1)
			print("[MapSelect] ショップ: 警戒レベル -1 → %d" % GameSession.alert_level)
			SceneManager.go_to("shop")
		"event":
			GameSession.alert_level = max(0, GameSession.alert_level - 1)
			print("[MapSelect] イベント: 警戒レベル -1 → %d" % GameSession.alert_level)
			SceneManager.go_to("event")
		"gather":
			GameSession.alert_level = max(0, GameSession.alert_level - 1)
			print("[MapSelect] 素材採集: 警戒レベル -1 → %d" % GameSession.alert_level)
			# 素材採集ノードは廃止（装備・素材システム廃止により削除）
			print("[MapSelect] gatherノードは廃止されました")
			SceneManager.go_to(SceneManager.MAP_SELECT)

func _add_alert_marker(parent_pos: Vector2, alert: int) -> void:
	"""警告マークを追加（警戒レベルに応じた表示）"""
	if alert == 0:
		return

	var marker_label = Label.new()
	marker_label.position = parent_pos + Vector2(35, -5)
	marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	marker_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# alert_levelに応じた表示設定
	if alert >= 5:
		marker_label.text = "!!!"
		marker_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		marker_label.add_theme_font_size_override("font_size", 20)
	elif alert >= 3:
		marker_label.text = "!!"
		marker_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		marker_label.add_theme_font_size_override("font_size", 18)
	else:  # alert == 1-2
		marker_label.text = "!"
		marker_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		marker_label.add_theme_font_size_override("font_size", 16)

	add_child(marker_label)

# ===============================
# ルートメモ機能
# ===============================

func _update_route_from_mouse() -> void:
	"""マウス位置のノードをルートに追加"""
	var mouse_pos = get_viewport().get_mouse_position()
	var act_data = _get_current_act_data()
	var node_positions = _calculate_node_positions(act_data)

	# マウス位置に近いノードを探す
	for node in act_data.get("nodes", []):
		var node_id = node.get("id", "")
		var pos = node_positions.get(node_id, Vector2.ZERO)
		if pos == Vector2.ZERO:
			continue

		# ノード範囲内（50x50）にマウスがあるか
		var node_rect = Rect2(pos, Vector2(50, 50))
		if node_rect.has_point(mouse_pos):
			# ルートの最後のノードと異なる場合のみ追加
			if _route_memo.is_empty() or _route_memo[-1] != node_id:
				_route_memo.append(node_id)
				_draw_route()
				_update_route_info()
			break

func _clear_route() -> void:
	"""ルートをクリア"""
	_route_memo.clear()

	# 描画した線を削除
	for line in _route_lines:
		if is_instance_valid(line):
			line.queue_free()
	_route_lines.clear()

	# 情報パネルを非表示
	if _route_info_panel and is_instance_valid(_route_info_panel):
		_route_info_panel.visible = false

func _draw_route() -> void:
	"""ルート線を描画"""
	# 既存の線を削除
	for line in _route_lines:
		if is_instance_valid(line):
			line.queue_free()
	_route_lines.clear()

	if _route_memo.size() < 2:
		return

	var act_data = _get_current_act_data()
	var node_positions = _calculate_node_positions(act_data)

	# ルートの各ノード間に線を引く
	for i in range(_route_memo.size() - 1):
		var node_a_id = _route_memo[i]
		var node_b_id = _route_memo[i + 1]
		var pos_a = node_positions.get(node_a_id, Vector2.ZERO)
		var pos_b = node_positions.get(node_b_id, Vector2.ZERO)

		if pos_a == Vector2.ZERO or pos_b == Vector2.ZERO:
			continue

		var line = Line2D.new()
		line.add_point(pos_a + Vector2(25, 25))  # ノード中心
		line.add_point(pos_b + Vector2(25, 25))
		line.width = 5
		line.default_color = Color(1.0, 0.9, 0.3, 0.7)  # 黄色半透明
		add_child(line)
		_route_lines.append(line)

func _update_route_info() -> void:
	"""ルート情報パネルを更新"""
	if _route_memo.is_empty():
		return

	# 情報パネルがなければ作成
	if not _route_info_panel:
		_route_info_panel = PanelContainer.new()
		_route_info_panel.position = Vector2(get_viewport_rect().size.x - 220, 50)
		_route_info_panel.size = Vector2(200, 150)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		style.set_corner_radius_all(5)
		style.set_border_width_all(2)
		style.border_color = Color(1.0, 0.9, 0.3)
		_route_info_panel.add_theme_stylebox_override("panel", style)

		add_child(_route_info_panel)

	# 既存の子要素を削除
	for child in _route_info_panel.get_children():
		child.queue_free()

	# ルート分析
	var info = _analyze_route()

	# VBoxContainerで情報を縦に並べる
	var vbox = VBoxContainer.new()
	_route_info_panel.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "=== ルート計画 ==="
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(title_label)

	var labels = [
		"総マス数: %d" % info["total"],
		"最大警戒Lv: %d" % info["max_alert"],
		"戦闘: %d  エリート: %d" % [info["battle"], info["elite"]],
		"レスト: %d  ショップ: %d" % [info["rest"], info["shop"]],
		"イベント: %d  ボス: %d" % [info["event"], info["boss"]],
	]

	for text in labels:
		var label = Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		vbox.add_child(label)

	_route_info_panel.visible = true

func _analyze_route() -> Dictionary:
	"""ルートを分析して情報を返す"""
	var act_data = _get_current_act_data()
	var current_alert = GameSession.alert_level
	var max_alert = current_alert

	var counts = {
		"total": _route_memo.size(),
		"max_alert": 0,
		"battle": 0,
		"elite": 0,
		"rest": 0,
		"shop": 0,
		"event": 0,
		"boss": 0,
	}

	# 各ノードをシミュレート
	for node_id in _route_memo:
		for node in act_data.get("nodes", []):
			if node.get("id", "") == node_id:
				var node_type = node.get("type", "")
				counts[node_type] = counts.get(node_type, 0) + 1

				# 警戒レベルをシミュレート
				if node_type == "battle" or node_type == "elite":
					current_alert += 1
				elif node_type == "rest":
					current_alert = max(0, current_alert - 2)
				elif node_type in ["shop", "event"]:
					current_alert = max(0, current_alert - 1)

				max_alert = max(max_alert, current_alert)
				break

	counts["max_alert"] = max_alert
	return counts
