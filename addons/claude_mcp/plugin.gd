@tool
extends EditorPlugin

# Claude MCP Bridge プラグイン
# Claude CodeがGodot Editorを操作するためのHTTPサーバーを提供

const HTTP_PORT = 6789
const HTTPHandlerScript = preload("res://addons/claude_mcp/http_handler.gd")

var http_handler: RefCounted = null
var server: TCPServer = null
var connections: Array = []

func _enter_tree():
	print("[Claude MCP] プラグイン初期化中...")

	# HTTPサーバー起動
	server = TCPServer.new()
	var err = server.listen(HTTP_PORT)

	if err != OK:
		push_error("[Claude MCP] ポート %d でサーバー起動失敗: %s" % [HTTP_PORT, error_string(err)])
		return

	# HTTPハンドラー初期化
	http_handler = HTTPHandlerScript.new()
	http_handler.editor_interface = get_editor_interface()

	print("[Claude MCP] HTTPサーバー起動成功: http://localhost:%d" % HTTP_PORT)
	print("[Claude MCP] 利用可能なエンドポイント:")
	print("  GET  /health          - ヘルスチェック")
	print("  GET  /screenshot      - スクリーンショット取得")
	print("  GET  /scene           - シーン構造取得")
	print("  GET  /node?path={path} - ノード情報取得")
	print("  POST /property        - ノードプロパティ変更")

func _exit_tree():
	print("[Claude MCP] プラグイン終了中...")

	# 全接続をクローズ
	for conn in connections:
		if conn.is_connected_to_host():
			conn.disconnect_from_host()
	connections.clear()

	# サーバー停止
	if server != null:
		server.stop()
		server = null

	http_handler = null
	print("[Claude MCP] プラグイン終了完了")

func _process(_delta):
	if server == null or not server.is_listening():
		return

	# 新規接続を受け入れ
	if server.is_connection_available():
		var conn = server.take_connection()
		connections.append(conn)
		print("[Claude MCP] 新規接続を受け入れました")

	# 既存接続からリクエストを処理
	var i = 0
	while i < connections.size():
		var conn = connections[i]

		# 切断された接続を削除
		if not conn.is_connected_to_host():
			connections.remove_at(i)
			continue

		# データが利用可能か確認
		if conn.get_available_bytes() > 0:
			var request_data = conn.get_string(conn.get_available_bytes())
			_handle_request(conn, request_data)
			# レスポンス送信後に接続をクローズ（HTTP/1.0スタイル）
			conn.disconnect_from_host()
			connections.remove_at(i)
			continue

		i += 1

func _handle_request(conn: StreamPeerTCP, request_data: String):
	"""HTTPリクエストを解析して処理"""
	if http_handler == null:
		_send_error_response(conn, 500, "Server not initialized")
		return

	# リクエストラインをパース（例: "GET /health HTTP/1.1"）
	var lines = request_data.split("\r\n")
	if lines.size() == 0:
		_send_error_response(conn, 400, "Invalid request")
		return

	var request_line = lines[0]
	var parts = request_line.split(" ")
	if parts.size() < 2:
		_send_error_response(conn, 400, "Invalid request line")
		return

	var method = parts[0]
	var path_with_query = parts[1]

	# クエリパラメータを分離
	var path = path_with_query
	var query_params = {}
	if "?" in path_with_query:
		var split_result = path_with_query.split("?", true, 1)
		path = split_result[0]
		if split_result.size() > 1:
			query_params = _parse_query_string(split_result[1])

	# POSTボディをパース
	var body = ""
	if method == "POST":
		var header_end = request_data.find("\r\n\r\n")
		if header_end != -1:
			body = request_data.substr(header_end + 4)

	print("[Claude MCP] リクエスト: %s %s" % [method, path])

	# ハンドラーに処理を委譲
	var response = http_handler.handle_request(method, path, query_params, body)
	_send_response(conn, response)

func _parse_query_string(query: String) -> Dictionary:
	"""クエリ文字列をパースしてDictionaryに変換"""
	var params = {}
	var pairs = query.split("&")
	for pair in pairs:
		var kv = pair.split("=", true, 1)
		if kv.size() == 2:
			params[kv[0]] = kv[1].uri_decode()
		elif kv.size() == 1:
			params[kv[0]] = ""
	return params

func _send_response(conn: StreamPeerTCP, response: Dictionary):
	"""HTTPレスポンスを送信"""
	var status_code = response.get("status", 200)
	var status_text = _get_status_text(status_code)
	var content_type = response.get("content_type", "application/json")
	var body = response.get("body", "")

	# ヘッダー構築
	var headers = "HTTP/1.1 %d %s\r\n" % [status_code, status_text]
	headers += "Content-Type: %s\r\n" % content_type
	headers += "Content-Length: %d\r\n" % body.length()
	headers += "Access-Control-Allow-Origin: *\r\n"
	headers += "Connection: close\r\n"
	headers += "\r\n"

	# レスポンス送信
	conn.put_data(headers.to_utf8_buffer())
	conn.put_data(body.to_utf8_buffer())

func _send_error_response(conn: StreamPeerTCP, status_code: int, message: String):
	"""エラーレスポンスを送信"""
	var response = {
		"status": status_code,
		"content_type": "application/json",
		"body": JSON.stringify({"error": message})
	}
	_send_response(conn, response)

func _get_status_text(code: int) -> String:
	"""HTTPステータスコードに対応するテキストを返す"""
	match code:
		200: return "OK"
		400: return "Bad Request"
		404: return "Not Found"
		500: return "Internal Server Error"
		_: return "Unknown"
