# MapSelect.gd
# マップ選択画面（StS風横方向分岐ツリー）
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")
const MapGenerator = preload("res://scripts/MapGenerator.gd")

var _taskbar: RefCounted = null
var _node_buttons: Dictionary = {}  # node_id -> Button

# ノード種別色定義
const NODE_COLORS = {
	"battle": Color(0.8, 0.3, 0.3),
	"elite": Color(0.9, 0.5, 0.2),
	"gather": Color(0.3, 0.7, 0.4),
	"shop": Color(0.9, 0.8, 0.3),
	"event": Color(0.5, 0.5, 0.9),
	"boss": Color(0.9, 0.2, 0.5),
}

# ノード種別記号
const NODE_SYMBOLS = {
	"battle": "⚔",
	"elite": "★",
	"gather": "⛏",
	"shop": "$",
	"event": "?",
	"boss": "☠",
}

func _ready() -> void:
	_build_ui()

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

	# タイトル表示
	var env_def = CardDB.ENVIRONMENTS.get(GameSession.base_environment, {})
	var env_display = env_def.get("display", "平原")
	var title_text = "Act %d - %s" % [GameSession.current_act, env_display]
	UIF.add_title(self, title_text, 50)

	# マップ描画
	_draw_map()

	UIF.add_back_button(self, "← 素材選択", func(): SceneManager.go_to(SceneManager.MATERIAL_SELECT), 640)

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

func _get_current_act_data() -> Dictionary:
	"""現在のActデータを取得"""
	var acts = GameSession.map_data.get("acts", [])
	if acts.size() >= GameSession.current_act:
		return acts[GameSession.current_act - 1]
	return {}

func _calculate_node_positions(act_data: Dictionary) -> Dictionary:
	"""ノードの座標を計算"""
	var positions = {}
	var nodes = act_data.get("nodes", [])

	# depth別にlane数をカウントして中央配置用オフセット計算
	var depth_lanes = {}
	for node in nodes:
		var depth = node.get("depth", 0)
		if not depth_lanes.has(depth):
			depth_lanes[depth] = []
		depth_lanes[depth].append(node.get("lane", 0))

	for node in nodes:
		var depth = node.get("depth", 0)
		var lane = node.get("lane", 0)
		var lanes_at_depth = depth_lanes.get(depth, [])
		var lane_count = lanes_at_depth.size()

		# 中央配置のためのオフセット
		var center_offset = (3 - lane_count) * 40

		var x = 60 + depth * 120
		var y = 140 + lane * 90 + center_offset
		positions[node.get("id", "")] = Vector2(x, y)

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
	# 初回（current_nodeが空）ならdepth 0のノードが到達可能
	if GameSession.current_node == "":
		var act_data = _get_current_act_data()
		for node in act_data.get("nodes", []):
			if node.get("id", "") == node_id and node.get("depth", -1) == 0:
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
			GameSession.battle_type = "normal"
			SceneManager.go_to(SceneManager.DECK_PREP)
		"elite":
			GameSession.battle_type = "elite"
			SceneManager.go_to(SceneManager.DECK_PREP)
		"boss":
			GameSession.battle_type = "boss"
			SceneManager.go_to(SceneManager.DECK_PREP)
		"shop":
			SceneManager.go_to("shop")
		"event":
			SceneManager.go_to("event")
		"gather":
			# 仮: 素材を1つ追加してマップに戻る
			GameSession.materials.append("iron_ore")
			print("[MapSelect] 素材採集完了: iron_ore")
			SceneManager.go_to(SceneManager.MAP_SELECT)
