STATUS: 廃止（→ docs/reference/archive/）
最終更新: 2026-05-04

# GameSession設計

## Autoload登録
```ini
[autoload]
SceneManager="*res://scripts/SceneManager.gd"
GameSession="*res://scripts/GameSession.gd"
```

## データ構造
- class_id: String — 選択クラス
- selected_deck: Array — デッキ
- last_result: Dictionary — バトル結果{win, player_hp_remaining, turns}
- run_depth: int — ダンジョン進行（将来）

## 利用パターン
- クラス選択→バトル: GameSession.class_id設定→SceneManager.go_to("battle")
- バトル→結果: GameSession.last_result設定→SceneManager.go_to("result")
- 結果→クラス選択: GameSession.reset()→SceneManager.go_to("class_select")
