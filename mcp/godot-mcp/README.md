# Godot MCP Server

## 概要

GodotのEditorPluginと連携して、Claude CodeがGodot Editorを操作できるようにするMCPサーバーです。

## 機能

- **スクリーンショット取得**: 現在のEditorViewportのスクリーンショットをPNG形式で取得
- **シーン構造取得**: 開いているシーンのノードツリー構造をJSON形式で取得
- **ノード情報取得**: 指定ノードのプロパティ一覧を取得
- **ノードプロパティ変更**: 指定ノードのプロパティを変更

## セットアップ

### 1. 依存関係のインストール

```bash
npm install
```

### 2. Godot EditorPluginの有効化

1. Godot Editorを開く
2. `プロジェクト → プロジェクト設定 → プラグイン`
3. `Claude MCP Bridge` を有効化

### 3. Claude Code設定

`~/.claude/settings.json` に以下を追加：

```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": ["/absolute/path/to/mcp/godot-mcp/index.js"]
    }
  }
}
```

## 使用方法

Claude Codeのチャットで以下のツールを使用：

### godot_health_check

接続確認

```
godot_health_check ツールを使用してください
```

### godot_screenshot

スクリーンショット取得

```
godot_screenshot ツールを使用してください
```

### godot_get_scene

シーン構造取得

```
godot_get_scene ツールを使用してください
```

### godot_get_node

ノード情報取得

```
godot_get_node ツールを使用して、"UI/HealthBar" ノードの情報を取得してください
```

### godot_set_property

ノードプロパティ変更

```
godot_set_property ツールを使用して、"UI/HealthBar" ノードの "size" を Vector2(200, 20) に変更してください
```

## トラブルシューティング

詳細は `docs/meta/godot_mcp_setup_guide.md` を参照してください。

## ライセンス

MIT
