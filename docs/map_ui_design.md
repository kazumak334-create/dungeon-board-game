# マップUI設計（StS風ツリー表示）

## 目的
縦リスト式の仮実装を、Slay the Spire風の横方向分岐ツリー表示に改修する

## レイアウト

```
┌────────────────────────────────────────────────────────────┐
│ タスクバー（36px）                                          │
├────────────────────────────────────────────────────────────┤
│ タイトル：Act 1 - 平原（50px）                              │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  depth:0   depth:1   depth:2  ...  depth:9                │
│    ●───┬────●───┬────●              ●                     │
│        │         │                  ▲ BOSS                │
│    ●───┼────●───┴────●              │                     │
│        │                            │                     │
│    ●───┴────●────────●              │                     │
│                                                            │
│  ← 前のシーンへ                                            │
└────────────────────────────────────────────────────────────┘
```

## 座標計算

### グリッド配置
- 横軸（depth）: 10ノード（0-9）
- 縦軸（lane）: 最大3レーン（0-2）
- ノード間隔:
  - 横: 110px（depth間）
  - 縦: 80px（lane間）
- 開始座標: (100, 150)

### ノードサイズ
- 直径: 50px
- クリック判定: 60px（余裕を持たせる）

### 接続線
- Line2Dで描画
- 太さ: 3px
- 色: グレー（未訪問）、黄色（到達可能）、緑（訪問済み）

## ノード状態

| 状態 | 条件 | 色 | クリック可否 |
|-----|-----|---|------------|
| 現在地 | current_node == node.id | 青グロー | × |
| 訪問済み | node.id in completed_nodes | 灰色 | × |
| 到達可能 | 前ノードが訪問済み | 種別色 | ○ |
| 未到達 | その他 | 暗灰色 | × |

## ノード種別色

| 種別 | 色 | 記号 |
|-----|---|-----|
| battle | 赤 | ⚔ |
| elite | オレンジ | ★ |
| gather | 緑 | ⛏ |
| shop | 黄 | $ |
| event | 青 | ? |
| boss | 紫 | ☠ |

## 実装ステップ

### Phase 1: データ取得・配置計算
1. GameSession.map_data確認、空なら生成
2. 現在Act のノードデータ取得
3. 各ノードの(x, y)座標計算

### Phase 2: 接続線描画
1. 各ノードのconnectionsを走査
2. Line2Dで線を描画（接続元→接続先）
3. 状態に応じて色変更

### Phase 3: ノード描画
1. PanelContainer + Label でノード作成
2. 種別色・状態色を適用
3. ホバー時にツールチップ表示

### Phase 4: クリック処理
1. 到達可能ノードのみButton化
2. クリック時にGameSession.current_node更新
3. シーン遷移（ノード種別に応じて）

## コード構造

```gdscript
# MapSelect.gd
func _build_map_ui() -> void:
    _ensure_map_data()
    var act_data = _get_current_act_data()
    var node_positions = _calculate_node_positions(act_data)
    _draw_connections(act_data, node_positions)
    _draw_nodes(act_data, node_positions)

func _ensure_map_data() -> void:
    if GameSession.map_data.is_empty():
        var gen = MapGenerator.new()
        GameSession.map_seed = randi()
        GameSession.map_data = gen.generate(GameSession.map_seed, GameSession.race_theme)

func _get_current_act_data() -> Dictionary:
    var acts = GameSession.map_data.get("acts", [])
    if acts.size() >= GameSession.current_act:
        return acts[GameSession.current_act - 1]
    return {}

func _calculate_node_positions(act_data: Dictionary) -> Dictionary:
    var positions = {}
    var nodes = act_data.get("nodes", [])
    for node in nodes:
        var depth = node.get("depth", 0)
        var lane = node.get("lane", 0)
        var x = 100 + depth * 110
        var y = 150 + lane * 80
        positions[node.get("id", "")] = Vector2(x, y)
    return positions

func _is_reachable(node_id: String) -> bool:
    # 現在地から直接繋がっているか確認
    var current = GameSession.current_node
    var act_data = _get_current_act_data()
    for node in act_data.get("nodes", []):
        if node.get("id", "") == node_id:
            var conns = node.get("connections", [])
            if current in conns or current == "":
                return true
    return false
```

## テスト項目

- [ ] マップデータが正しく生成される
- [ ] ノードが横方向に配置される
- [ ] 接続線が正しく描画される
- [ ] 到達可能ノードのみクリック可能
- [ ] クリック後にcurrent_node更新
- [ ] ボスノード選択で次Actへ遷移
