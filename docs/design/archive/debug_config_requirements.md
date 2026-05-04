STATUS: 廃止（→ docs/GAME_DESIGN_V0_2_MVP.md）
最終更新: 2026-05-04

# デバッグコンフィグシステム 要件定義書

## 1. 概要

バランス調整用パラメータを外部設定ファイル化し、コード変更なしで値を調整可能にする。開発モードでのみ有効化し、リリース時は既存の定数値にフォールバックする。

**企画意図**
- balance_adjustment_plan.md の9スプリント（A-I）で調整する全パラメータを外部ファイルで管理
- GDScriptの定数を都度編集・再起動する手間を削減
- バランステストの高速イテレーション実現

## 2. 実装対象

### 新規作成ファイル
- `scripts/ConfigLoader.gd`: AutoLoad設定ファイル読み込みシステム
- `config/balance.json`: パラメータ定義JSON（gitignore対象外・開発用）
- `config/balance.json.example`: デフォルト値サンプル（git管理）

### 変更対象ファイル
- `project.godot`: AutoLoad登録（ConfigLoader）
- `scripts/GameSession.gd`: DEFAULT_BATTLE_CONFIG をConfigLoader経由に変更
- `scripts/RewardTable.gd`: RARITY_WEIGHTS_* 定数を動的ロードに変更
- `scripts/TileEffectManager.gd`: 警戒システム盤面効果マス数・効果値を動的ロードに変更
- `scripts/MapGenerator.gd`: NODE_WEIGHTS, REST_NODE_CHANCE を動的ロードに変更
- `scripts/Shop.gd`: 価格計算式のレアリティ倍率を動的ロードに変更
- `data/cards.json`: bosses セクションの hp_multiplier/atk_multiplier は**変更不要**（JSONのまま参照）

## 3. データ構造

### balance.json フォーマット

```json
{
  "_comment": "バランス調整パラメータ（開発モード専用）",
  "mana_economy": {
    "initial_mana": 3,
    "mana_max": 3,
    "mana_regen_rate": 1.0
  },
  "battle_config": {
    "time_limit": 60.0,
    "player_base_hp": 30,
    "enemy_base_hp": 30
  },
  "alert_system": {
    "tile_effect_count_lv1": 3,
    "tile_effect_count_lv2": 3,
    "armor_damage_reduction": 2,
    "thorn_damage": 2,
    "curse_damage": 1
  },
  "drop_table": {
    "rarity_weights_early": {"common": 65, "uncommon": 30, "rare": 5, "epic": 0, "legend": 0, "god": 0},
    "rarity_weights_mid": {"common": 40, "uncommon": 40, "rare": 17, "epic": 3, "legend": 0, "god": 0},
    "rarity_weights_late": {"common": 20, "uncommon": 36, "rare": 30, "epic": 12, "legend": 2, "god": 0},
    "stage_early_max_depth": 3,
    "stage_mid_max_depth": 7
  },
  "rewards": {
    "battle_gold_base": 30,
    "battle_gold_variance": 20,
    "battle_sp": 1,
    "boss_gold": 200,
    "boss_sp": 2
  },
  "shop": {
    "rarity_price": {
      "common": 50,
      "uncommon": 100,
      "rare": 200,
      "epic": 400,
      "legend": 800
    },
    "reroll_cost": 10
  },
  "map_generation": {
    "node_weights": {
      "battle": 50,
      "elite": 15,
      "gather": 15,
      "shop": 10,
      "event": 10
    },
    "rest_node_chance": 0.2,
    "rest_node_depths": [4, 5, 6]
  }
}
```

## 4. 実装手順

### Sprint 0: 基盤構築
1. `scripts/ConfigLoader.gd` 新規作成
2. `config/balance.json.example` 新規作成
3. `project.godot` に AutoLoad 登録
4. `.gitignore` に `config/balance.json` 追加

### Sprint 1: 各ファイル修正
5. GameSession.gd 修正（DEFAULT_BATTLE_CONFIG）
6. RewardTable.gd 修正（RARITY_WEIGHTS_* 関数化）
7. TileEffectManager.gd 修正（マス数・効果値）
8. MapGenerator.gd 修正（NODE_WEIGHTS, REST_NODE_CHANCE）
9. Shop.gd 修正（_calculate_price 追加）

### Sprint 2: 呼び出し元修正
10. RewardTable を呼び出している全ファイルを検索・修正
11. GameSession.DEFAULT_BATTLE_CONFIG を参照している全ファイル確認

### Sprint 3: テスト
12. `config/balance.json` を手動作成
13. 開発モードで起動・パラメータ読み込み確認
14. balance.json の値を変更→再起動→反映確認
15. リリースビルドでデフォルト値動作確認

## 5. 完了定義

- ConfigLoader.gd が balance.json を読み込み、各パラメータを提供できる
- 開発モードで balance.json の値が反映される
- リリースビルドでデフォルト値にフォールバックする
- roadmap.md Phase 4 #11 備考欄に「デバッグコンフィグシステム実装完了」記載
