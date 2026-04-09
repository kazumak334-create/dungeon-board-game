extends RefCounted

# HTTPリクエスト処理ハンドラー
# 各エンドポイントの処理を実装

var editor_interface: EditorInterface = null

func handle_request(method: String, path: String, query_params: Dictionary, body: String) -> Dictionary:
	"""リクエストをルーティングして処理"""

	# ヘルスチェック
	if method == "GET" and path == "/health":
		return _handle_health()

	# スクリーンショット取得
	elif method == "GET" and path == "/screenshot":
		return _handle_screenshot()

	# シーン構造取得
	elif method == "GET" and path == "/scene":
		return _handle_get_scene()

	# ノード情報取得
	elif method == "GET" and path == "/node":
		var node_path = query_params.get("path", "")
		return _handle_get_node(node_path)

	# ノードプロパティ変更
	elif method == "POST" and path == "/property":
		return _handle_set_property(body)

	# 未対応のエンドポイント
	else:
		return {
			"status": 404,
			"content_type": "application/json",
			"body": JSON.stringify({"error": "Endpoint not found"})
		}

func _handle_health() -> Dictionary:
	"""ヘルスチェック"""
	return {
		"status": 200,
		"content_type": "application/json",
		"body": JSON.stringify({
			"status": "ok",
			"message": "Claude MCP Server is running",
			"version": "1.0.0"
		})
	}

func _handle_screenshot() -> Dictionary:
	"""現在のEditorViewportのスクリーンショットをPNG形式で返す"""
	if editor_interface == null:
		return _error_response(500, "EditorInterface not available")

	# 現在編集中のシーンのルートノードを取得
	var edited_scene = editor_interface.get_edited_scene_root()
	if edited_scene == null:
		return _error_response(404, "No scene is currently open")

	# 2Dエディタのビューポートを取得
	# 注: Godot 4.xでは get_editor_viewport_2d() は非推奨
	# 代わりに get_editor_main_screen() を使用
	var viewport: Viewport = null

	# まず編集中のシーンからビューポートを探す
	if edited_scene.get_viewport():
		viewport = edited_scene.get_viewport()

	if viewport == null:
		return _error_response(500, "Could not access viewport")

	# ビューポートのテクスチャを取得
	var viewport_texture = viewport.get_texture()
	if viewport_texture == null:
		return _error_response(500, "Could not get viewport texture")

	# テクスチャを画像に変換
	var image = viewport_texture.get_image()
	if image == null:
		return _error_response(500, "Could not convert texture to image")

	# PNG形式にエンコード
	var png_data = image.save_png_to_buffer()
	if png_data.size() == 0:
		return _error_response(500, "Failed to encode PNG")

	# Base64エンコード
	var base64_data = Marshalls.raw_to_base64(png_data)

	return {
		"status": 200,
		"content_type": "application/json",
		"body": JSON.stringify({
			"success": true,
			"format": "png",
			"encoding": "base64",
			"data": base64_data,
			"width": image.get_width(),
			"height": image.get_height()
		})
	}

func _handle_get_scene() -> Dictionary:
	"""現在開いているシーンのノードツリー構造をJSON形式で返す"""
	if editor_interface == null:
		return _error_response(500, "EditorInterface not available")

	var edited_scene = editor_interface.get_edited_scene_root()
	if edited_scene == null:
		return _error_response(404, "No scene is currently open")

	# ノードツリーを再帰的にトラバース
	var scene_data = _serialize_node_tree(edited_scene)

	return {
		"status": 200,
		"content_type": "application/json",
		"body": JSON.stringify({
			"success": true,
			"scene": scene_data
		})
	}

func _serialize_node_tree(node: Node) -> Dictionary:
	"""ノードツリーをDictionaryに変換（再帰）"""
	var node_data = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"children": []
	}

	# 子ノードを再帰的にシリアライズ
	for child in node.get_children():
		node_data["children"].append(_serialize_node_tree(child))

	return node_data

func _handle_get_node(node_path: String) -> Dictionary:
	"""指定ノードのプロパティ一覧をJSON形式で返す"""
	if editor_interface == null:
		return _error_response(500, "EditorInterface not available")

	if node_path == "":
		return _error_response(400, "node_path parameter is required")

	var edited_scene = editor_interface.get_edited_scene_root()
	if edited_scene == null:
		return _error_response(404, "No scene is currently open")

	# NodePathからノードを取得
	var node = edited_scene.get_node_or_null(NodePath(node_path))
	if node == null:
		return _error_response(404, "Node not found: %s" % node_path)

	# プロパティ一覧を取得
	var properties = {}
	var property_list = node.get_property_list()

	for prop_info in property_list:
		var prop_name = prop_info["name"]
		# プライベートプロパティをスキップ
		if prop_name.begins_with("_"):
			continue

		var value = node.get(prop_name)
		properties[prop_name] = _serialize_value(value)

	return {
		"status": 200,
		"content_type": "application/json",
		"body": JSON.stringify({
			"success": true,
			"node": {
				"name": node.name,
				"type": node.get_class(),
				"path": str(node.get_path()),
				"properties": properties
			}
		})
	}

func _serialize_value(value) -> Variant:
	"""プロパティ値をJSON互換形式に変換"""
	if value is Vector2 or value is Vector3:
		return str(value)
	elif value is Color:
		return str(value)
	elif value is Object:
		return "<Object>"
	elif value is Array:
		return "<Array[%d]>" % value.size()
	elif value is Dictionary:
		return "<Dictionary[%d]>" % value.size()
	else:
		return value

func _handle_set_property(body: String) -> Dictionary:
	"""指定ノードのプロパティを変更する"""
	if editor_interface == null:
		return _error_response(500, "EditorInterface not available")

	# JSONボディをパース
	var json = JSON.new()
	var parse_result = json.parse(body)
	if parse_result != OK:
		return _error_response(400, "Invalid JSON body")

	var data = json.data
	if not data is Dictionary:
		return _error_response(400, "Body must be a JSON object")

	var node_path = data.get("path", "")
	var property = data.get("property", "")
	var value = data.get("value")

	if node_path == "" or property == "":
		return _error_response(400, "path and property are required")

	var edited_scene = editor_interface.get_edited_scene_root()
	if edited_scene == null:
		return _error_response(404, "No scene is currently open")

	# NodePathからノードを取得
	var node = edited_scene.get_node_or_null(NodePath(node_path))
	if node == null:
		return _error_response(404, "Node not found: %s" % node_path)

	# プロパティを設定
	if not property in node:
		return _error_response(400, "Property not found: %s" % property)

	node.set(property, value)

	return {
		"status": 200,
		"content_type": "application/json",
		"body": JSON.stringify({
			"success": true,
			"message": "Property updated successfully"
		})
	}

func _error_response(status_code: int, message: String) -> Dictionary:
	"""エラーレスポンスを生成"""
	return {
		"status": status_code,
		"content_type": "application/json",
		"body": JSON.stringify({"error": message})
	}
