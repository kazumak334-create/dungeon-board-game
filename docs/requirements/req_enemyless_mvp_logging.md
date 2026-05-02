# 要件定義書：敵なしMVP ログシステム

更新日: 2026-05-02  
ステータス: DRAFT  
根拠: enemyless_mvp_logging_spec.md（GoogleDrive v0.2_MVP用）

---

## 1. 目的

敵なしMVPにおいて、都市成長・カード循環・建設キュー・人口配分・兵力生成の挙動を**定量的に分析**するためのログ基盤を実装する。

感覚頼りの評価を排除し、後からPythonやスプレッドシートで振り返れるようにする。

### 検証したいこと（5分間）

| 検証軸 | 問い |
|--------|------|
| 都市成長 | 5分で建物が何個建ったか、人口がどこまで伸びたか |
| カード循環 | カードが詰まらず回ったか |
| 建設キュー | キューが気持ちよく進んだか |
| 人口配分 | 配分バーが意味を持っていたか |
| 兵力蓄積 | 5分で突撃したくなる兵力になっているか |
| 詰まり | どこで資源・手札・キューが詰まったか |

---

## 2. スコープ

### MVP実装対象（必須）

- LogManager（JSONL出力基盤）
- ログレベル制御（BASIC / DEBUG / VERBOSE）
- SNAPSHOTログ（5秒ごと）
- BATTLE_SUMMARYログ（バトル終了時）
- ANALYSIS_METRICSログ（バトル終了時）
- 主要イベントログ API（接続は段階的）

### MVP除外

- 外部分析ツール・グラフ表示
- クラウド保存・CSV変換
- 全イベントの完全接続（段階的に行う）

---

## 3. ログ基盤仕様（LogManager）

### 3.1 出力形式

**推奨: JSONL（1行1イベント）**

```jsonl
{"type":"SNAPSHOT","time":120,"turn":4,"population":24,...}
{"type":"DRAW","time":130,"reason":"turn_start","card":"Barracks",...}
```

初期許容: 文字列ログ（後からJSONL対応）

### 3.2 保存先

```
user://logs/run_YYYYMMDD_HHMMSS.jsonl
例: user://logs/run_20260502_183000.jsonl
```

### 3.3 ログレベル

| レベル | 対象ログ |
|--------|---------|
| BASIC | SNAPSHOT / BATTLE_SUMMARY / ANALYSIS_METRICS |
| DEBUG | BASIC + 主要イベント全種（カード・建設・兵力・詰まり）|
| VERBOSE | DEBUG + 内部tick・UI操作 |

**MVP推奨: DEBUG**

### 3.4 設定値

```gdscript
var log_enabled: bool = true
var log_level: String = "DEBUG"  # "BASIC" / "DEBUG" / "VERBOSE"
```

### 3.5 ファイル操作

- バトル開始時にログファイルを開く
- バトル終了時にフラッシュして閉じる
- ログOFF時（`log_enabled=false`）はファイル出力しない

---

## 4. スナップショットログ（SNAPSHOT）

### 4.1 出力タイミング

5秒ごと（5秒ティックに同期）

### 4.2 必須フィールド

| フィールド | 型 | 説明 |
|-----------|-----|------|
| type | string | "SNAPSHOT" |
| time | int | 経過秒数 |
| turn | int | 現在ターン番号 |
| population | int | 現在人口 |
| population_cap | int | 人口上限 |
| happiness | int | 幸福度（0-100）|
| wood | int | 木材 |
| stone | int | 石材 |
| food | int | 食料 |
| gold | int | 通貨 |
| total_force | float | 総兵力 |
| buildings_total | int | 建物総数 |
| active_buildings | int | 稼働中建物数 |
| inactive_buildings | int | 非稼働建物数 |
| construction_queue_count | int | 建設キュー数 |
| hand_count | int | 手札枚数 |
| deck_count | int | 山札枚数 |
| discard_count | int | 捨て札枚数 |
| battle_removed_count | int | バトル中除外枚数 |

---

## 5. バトル終了サマリー（BATTLE_SUMMARY）

### 5.1 出力タイミング

バトル終了時（5分終了 / 最終突撃移行直前）

### 5.2 必須フィールド

| フィールド | 型 | 説明 |
|-----------|-----|------|
| type | string | "BATTLE_SUMMARY" |
| battle_id | string | バトルID |
| duration | int | 経過秒数 |
| turn | int | 最終ターン |
| buildings_total | int | 建物総数 |
| population | int | 最終人口 |
| population_cap | int | 人口上限 |
| happiness | int | 最終幸福度 |
| wood / stone / food / gold | int | 最終資源 |
| total_force | float | 総兵力 |
| estimated_units | int | 推定ユニット数（兵力÷10）|
| estimated_dps | float | 推定DPS（ユニット×0.2）|
| draw_count | int | ドロー総数 |
| reload_count | int | リロード総数 |
| cards_played | int | カード使用数 |
| build_completed | int | 建設完了数 |
| instant_build_count | int | 即時建設数 |
| queue_max_length | int | キュー最大長 |

---

## 6. 分析メトリクスログ（ANALYSIS_METRICS）

### 6.1 出力タイミング

バトル終了時

### 6.2 必須フィールド

| フィールド | 型 | 説明 |
|-----------|-----|------|
| type | string | "ANALYSIS_METRICS" |
| battle_id | string | バトルID |
| draw_count | int | ドロー総数 |
| reload_count | int | リロード総数 |
| cards_played | int | カード使用数 |
| buildings_completed | int | 建設完了数 |
| avg_queue_length | float | 平均キュー長 |
| max_queue_length | int | 最大キュー長 |
| resource_starved_time | int | 資源不足累計秒 |
| hand_full_time | int | 手札上限累計秒 |
| inactive_building_time | int | 非稼働建物累計秒 |
| total_force | float | 最終総兵力 |
| force_per_minute | float | 分あたり兵力 |

---

## 7. 主要イベントログ一覧

### 7.1 カード・デッキ系（DEBUGレベル）

| type | トリガー | 主要フィールド |
|------|---------|---------------|
| HAND_INIT | バトル開始・初期手札確定 | time, cards[], deck_count |
| DRAW | ドロー発生 | time, reason, card, hand_count, deck_count, discard_count |
| RELOAD | リロード実行 | time, discarded, drawn, hand_count, deck_count, cooldown |
| DECK_SHUFFLE | 山札切れ・再構築 | time, reason, discard_count, new_deck_count |
| CARD_PLAY | カード使用成功 | time, card, card_type, result, destination |
| CARD_PLAY_FAIL | カード使用失敗 | time, card, reason, missing |

**reason値（DRAW）**: `turn_start` / `resource_draw` / `treasure_reward` / `debug`  
**reason値（CARD_PLAY_FAIL）**: `insufficient_resource` / `no_valid_panel` / `condition_not_met` / `hand_locked`

### 7.2 建設キュー系（DEBUGレベル）

| type | トリガー | 主要フィールド |
|------|---------|---------------|
| BUILD_QUEUE_ADD | キューに追加 | time, task_id, task, source_card, cost{}, work_required, queue_count |
| BUILD_START | 建設開始 | time, task_id, task, assigned_workers, remaining_work |
| BUILD_COMPLETE | 建設完了 | time, task_id, building, elapsed, panel, queue_count |
| INSTANT_BUILD | 即時建設 | time, task_id, task, remaining_work, gold_cost, gold_after |
| BUILD_BLOCKED | 建設ブロック | time, task_id, task, reason, missing |

### 7.3 人口・配分系（DEBUGレベル）

| type | トリガー | 主要フィールド |
|------|---------|---------------|
| POPULATION_ALLOCATION_CHANGE | 配分バー変更 | time, active_ratio, worker_ratio, population, active_workers, construction_workers |

### 7.4 兵力系（DEBUGレベル）

| type | トリガー | 主要フィールド |
|------|---------|---------------|
| MILITARY_TICK | 5秒ティック・兵舎生成 | time, barracks_id, level, generated_force, force_total, active |
| MILITARY_SUMMARY | バトル終了時 | time, barracks_count, barracks_forces{}, total_force, estimated_units, estimated_dps |

### 7.5 詰まりログ（DEBUGレベル）

| type | 検知条件 | 主要フィールド |
|------|---------|---------------|
| HAND_STALLED | 手札に使えるカードがない | time, hand[], reason |
| RESOURCE_STARVED | 資源不足でタスクがブロック | time, resource, blocked_tasks[] |
| QUEUE_STALLED | キュー件数超過 or 作業人口不足で停滞 | time, queue_count, oldest_task_wait, worker_count, reason |

### 7.6 詳細ログ（VERBOSEレベル）

| type | トリガー |
|------|---------|
| RESOURCE_TICK | 5秒ティック・建物生産 |
| HAPPINESS_TICK | 5秒ティック・幸福度更新 |
| BUILDING_OPERATION | 建物稼働/停止状態変化 |
| SMITHY_EFFECT | 鍛冶屋DPS補正適用 |
| UI_ACTION | カードクリック・配分バー操作等 |

---

## 8. 実装フェーズ

| Phase | 内容 | 優先度 |
|-------|------|--------|
| 1 | LogManager基盤（JSONL出力・レベル制御・ファイル保存）| High |
| 2 | SNAPSHOT / BATTLE_SUMMARY / ANALYSIS_METRICS | High |
| 3 | 主要イベントログ（DRAW / RELOAD / CARD_PLAY / BUILD_* / MILITARY_TICK / POPULATION_ALLOCATION_CHANGE）| Medium |
| 4 | 詰まりログ（HAND_STALLED / RESOURCE_STARVED / QUEUE_STALLED）| Medium |
| 5 | 詳細ログ（RESOURCE_TICK / HAPPINESS_TICK / BUILDING_OPERATION / SMITHY_EFFECT / UI_ACTION）| Low |

---

## 9. 実装上の注意

### LogManager の配置

- Autoload に登録する（全スクリプトからアクセス可能）
- シグナル経由ではなく、直接メソッド呼び出し形式で実装

```gdscript
# 呼び出し例
LogManager.log_event({
    "type": "DRAW",
    "time": int(elapsed_time),
    "reason": "turn_start",
    "card": card_id,
    "hand_count": hand.size(),
    "deck_count": deck.size(),
    "discard_count": discard.size()
})
```

### 既存システムとの接続順序

1. Phase 1 で LogManager 単体を実装・動作確認
2. Phase 2 で EconEconomy.update() に SNAPSHOT 接続
3. Phase 3 で各システムに順次接続（一度に全接続しない）

### ANALYSIS_METRICS の集計

バトル中に以下を累積カウントするフィールドを LogManager 内に持つ：

```gdscript
var _draw_count: int = 0
var _reload_count: int = 0
var _cards_played: int = 0
var _build_completed: int = 0
var _instant_build_count: int = 0
var _queue_max_length: int = 0
var _resource_starved_seconds: int = 0
var _hand_full_seconds: int = 0
var _inactive_building_seconds: int = 0
```

---

## 10. 受け入れ条件

| 条件 | 確認方法 |
|------|---------|
| Godot起動中にJSONLログファイルが生成される | user://logs/ にファイルが存在する |
| 5秒ごとにSNAPSHOTが出る | ログファイルに "type":"SNAPSHOT" が60行（5分÷5秒）|
| バトル終了時にBATTLE_SUMMARYが出る | 最終行付近に "type":"BATTLE_SUMMARY" が存在 |
| バトル終了時にANALYSIS_METRICSが出る | "type":"ANALYSIS_METRICS" が存在 |
| ログレベルを切り替えられる | log_level="BASIC"でイベントログが出ない |
| ログOFF時にファイル出力されない | log_enabled=falseでファイル非生成 |
| 1行1JSONとしてパース可能 | `python -c "import json; [json.loads(l) for l in open('run_*.jsonl')]"` が通る |

