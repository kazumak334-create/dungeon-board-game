# Godot MCP シーン切り替え機能 要件定義書

## 1. 概要
GodotエディタでシーンをプログラムからClaude経由で開く機能を追加。UI/UX評価時に複数シーンのスクリーンショット撮影を自動化する。

## 2. 実装対象
- ファイル名: `addons/claude_mcp/http_handler.gd`
- 変更箇所: `handle_request()` 関数にルーティング追加、`_handle_open_scene()` 関数を新規追加
- ファイル名: `mcp/godot-mcp/index.js`
- 変更箇所: `ListToolsRequestSchema` にツール定義追加、`CallToolRequestSchema` にケース追加

## 3. データ構造
### リクエスト（POST /open_scene）
```json
{
  "scene_path": "res://scenes/Main.tscn"
}
```

### レスポンス（成功）
```json
{
  "success": true,
  "message": "Scene opened successfully",
  "scene_path": "res://scenes/Main.tscn"
}
```

### レスポンス（失敗）
```json
{
  "error": "Scene file not found: res://invalid.tscn"
}
```

## 4. 実装詳細

### 4.1 http_handler.gd への追加

#### 4.1.1 ルーティング追加
`handle_request()` 関数内に以下を追加（35行目付近、`/call_method` の後）:
```gdscript
# シーン切り替え
elif method == "POST" and path == "/open_scene":
    return _handle_open_scene(body)
```

#### 4.1.2 シーン切り替えハンドラー追加
ファイル末尾（309行目以降）に以下の関数を追加:
```gdscript
func _handle_open_scene(body: String) -> Dictionary:
	"""指定したシーンファイルをエディタで開く"""
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

	var scene_path = data.get("scene_path", "")
	if scene_path == "":
		return _error_response(400, "scene_path is required")

	# シーンファイルの存在確認
	if not FileAccess.file_exists(scene_path):
		return _error_response(404, "Scene file not found: %s" % scene_path)

	# シーンを開く
	var result = editor_interface.open_scene_from_path(scene_path)
	if result != OK:
		return _error_response(500, "Failed to open scene: error code %d" % result)

	return {
		"status": 200,
		"content_type": "application/json",
		"body": JSON.stringify({
			"success": true,
			"message": "Scene opened successfully",
			"scene_path": scene_path
		})
	}
```

### 4.2 index.js への追加

#### 4.2.1 ツール定義追加
`ListToolsRequestSchema` ハンドラー内の `tools` 配列に追加（146行目付近、`godot_call_method` の後）:
```javascript
{
  name: 'godot_open_scene',
  description: '指定したシーンファイルをGodot Editorで開きます。複数シーンの評価時に使用します。',
  inputSchema: {
    type: 'object',
    properties: {
      scene_path: {
        type: 'string',
        description: 'シーンファイルのパス（例: "res://scenes/Main.tscn"）',
      },
    },
    required: ['scene_path'],
  },
},
```

#### 4.2.2 ツール実行ハンドラー追加
`CallToolRequestSchema` ハンドラー内の `switch` 文に追加（286行目付近、`godot_call_method` の後）:
```javascript
case 'godot_open_scene': {
  const { scene_path } = args;

  if (!scene_path) {
    throw new Error('scene_path parameter is required');
  }

  const result = await httpRequest('POST', '/open_scene', {
    scene_path,
  });

  if (!result.success) {
    throw new Error(`Failed to open scene: ${result.error || 'Unknown error'}`);
  }

  return {
    content: [
      {
        type: 'text',
        text: `Scene "${scene_path}" has been opened in Godot Editor`,
      },
    ],
  };
}
```

## 5. 制約・注意事項

### 5.1 既存機能との整合性
- 既存のエンドポイント（`/health`, `/screenshot`, `/scene`, `/node`, `/property`, `/call_method`）には一切変更を加えない
- エラーレスポンス形式は既存の `_error_response()` を使用して統一
- HTTP ステータスコードは既存パターンに準拠（200=成功、400=パラメータ不正、404=リソースなし、500=サーバーエラー）

### 5.2 GAME_DESIGN.md との整合性
- この機能は開発ツールであり、ゲームプレイには影響しない
- UI/UX評価のワークフロー効率化が目的

### 5.3 エラーハンドリング
- シーンファイルが存在しない場合: 404エラー
- JSONパースエラー: 400エラー
- EditorInterface が利用不可: 500エラー
- `open_scene_from_path()` 失敗時: 500エラー（エラーコード含む）

### 5.4 セキュリティ
- ローカルホスト（localhost:6789）でのみ動作
- `scene_path` は `res://` プロトコルに限定（Godotリソースパスのみ）
- ファイル存在チェックを必ず実施

### 5.5 動作保証
- Godot 4.x 系（現行プロジェクトのバージョン）
- `EditorInterface.open_scene_from_path()` は Godot 公式APIで保証済み
- 戻り値: `OK` (0) = 成功、それ以外 = エラーコード

## 6. 使用例

### Claude Code からの呼び出し
```javascript
// MCPツールとして呼び出し
await callTool('godot_open_scene', {
  scene_path: 'res://scenes/Main.tscn'
});

// 成功時の出力
// "Scene "res://scenes/Main.tscn" has been opened in Godot Editor"
```

### 評価ワークフローでの利用
```javascript
// 1. Mainシーンを開く
await callTool('godot_open_scene', { scene_path: 'res://scenes/Main.tscn' });

// 2. スクリーンショット撮影
await callTool('godot_screenshot');

// 3. Homeシーンを開く
await callTool('godot_open_scene', { scene_path: 'res://scenes/Home.tscn' });

// 4. スクリーンショット撮影
await callTool('godot_screenshot');
```

## 7. 想定行数
- http_handler.gd 追加: 約35行（ルーティング4行 + ハンドラー31行）
- index.js 追加: 約35行（ツール定義13行 + ハンドラー22行）
- 合計: 約70行

## 8. 完了定義
- `addons/claude_mcp/http_handler.gd` に `/open_scene` エンドポイント実装
- `mcp/godot-mcp/index.js` に `godot_open_scene` ツール実装
- 構文チェック通過（`bash check_syntax.sh`）
- Claude Code から実行可能（MCP接続済み環境で検証）

---
作成日: 2026-04-21  
作成者: Architect Agent
