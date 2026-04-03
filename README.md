# Dungeon Board Game

リアルタイム盤面カードゲーム — Godot 4.x (GDScript) プロトタイプ

## Phase 1 実装内容

- 自陣 3×3 / 敵陣 3×3 の対面盤面
- 前列のみ攻撃・自動巡回デッキ・エネルギーシステム
- シンプルな敵AI（一定間隔でユニット召喚）
- デバッグUI（HP・エネルギー・ログ表示）

## 動作確認

```bash
godot4 --path . 
```

## ファイル構成

```
scripts/
  UnitData.gd      # ユニットデータ (RefCounted)
  BoardManager.gd  # 盤面ロジック
  DeckManager.gd   # デッキ＋エネルギー管理
  EnemyAI.gd       # 敵AI
  Main.gd          # メインシーン
scenes/
  Main.tscn        # メインシーン
assets/
  x_promo.png      # X投稿用プロモ画像
```
