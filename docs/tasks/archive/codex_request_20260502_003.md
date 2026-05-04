STATUS: 廃止（→ docs/tasks/archive/）
最終更新: 2026-05-04

# Codex 実装依頼: 敵なしMVP LogManager基盤（Phase 1-2）

作成日: 2026-05-02
依頼元: ClaudeCode
担当想定: Codex

## 目的

GodotプロジェクトにJSONL形式のログ基盤（LogManager）を追加する。
5秒ごとのSNAPSHOT、バトル終了のBATTLE_SUMMARY / ANALYSIS_METRICSを出力できるようにする。

## 背景

敵なしMVPで都市成長・カード循環・兵力蓄積を定量的に検証するためにログが必要。
感覚評価を排除し、後からPythonで分析可能なJSONLログを出す。

## 根拠

- `docs/requirements/req_enemyless_mvp_logging.md` §3〜§6（LogManager・SNAPSHOT・SUMMARY仕様）
- `docs/GAME_DESIGN_V0_2_MVP.md` §2.2（5秒ティック）

## 変更範囲

触ってよいファイル:
- `scripts/econ_mvp/LogManager.gd`（新規作成）
- `project.godot`（Autoload追加のみ）
- `scripts/econ_mvp/EconEconomy.gd`（SNAPSHOT呼び出し追加のみ）
- `scripts/econ_mvp/EconBattle.gd`（BATTLE_SUMMARY / ANALYSIS_METRICS呼び出し追加のみ）

触らないファイル:
- `data/cards_econ.json`
- `scripts/econ_mvp/EconDeckManager.gd`
- `scripts/econ_mvp/EconMain.gd`
- `scripts/econ_mvp/EconBuilding.gd`

## 仕様

### LogManager.gd（新規作成・Autoload登録）

```gdscript
extends Node

var log_enabled: bool = true
var log_level: String = "DEBUG"  # "BASIC" / "DEBUG" / "VERBOSE"
var _file: FileAccess = null
var _battle_id: String = ""

# 累積カウンタ
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

#### 主要メソッド

- `start_battle(battle_id: String)`: ログファイルを開く（user://logs/run_YYYYMMDD_HHMMSS.jsonl）
- `end_battle()`: ファイルをフラッシュして閉じる
- `log_event(data: Dictionary)`: 1行JSONとして書き込む（ログレベルチェック付き）
- `log_snapshot(data: Dictionary)`: SNAPSHOTを書き込む（常にBASIC以上で出力）
- `log_battle_summary(data: Dictionary)`: BATTLE_SUMMARYを書き込む
- `log_analysis_metrics()`: 累積カウンタからANALYSIS_METRICSを生成して書き込む

#### ログレベル判定

```gdscript
func _should_log(event_type: String) -> bool:
    if not log_enabled: return false
    var basic_types = ["SNAPSHOT", "BATTLE_SUMMARY", "ANALYSIS_METRICS"]
    if log_level == "BASIC": return event_type in basic_types
    var verbose_types = ["RESOURCE_TICK", "HAPPINESS_TICK", "BUILDING_OPERATION", "SMITHY_EFFECT", "UI_ACTION"]
    if log_level == "DEBUG": return event_type not in verbose_types
    return true  # VERBOSE
```

### EconEconomy.gd への接続

`update(tick_index)` の末尾にSNAPSHOT呼び出しを追加：

```gdscript
# update() 末尾
LogManager.log_snapshot({
    "type": "SNAPSHOT",
    "time": int(elapsed_time),  # EconBattle から受け取る or 内部カウンタ
    "turn": current_turn,
    "population": population_used,
    "population_cap": population_cap,
    "happiness": satisfaction,
    "wood": resources.get("wood", 0),
    "stone": resources.get("stone", 0),
    "food": resources.get("food", 0),
    "gold": resources.get("gold", 0),
    "total_force": total_force,
    # 以下はEconBoardから取得
    "buildings_total": 0,  # TODO: board連携
    "active_buildings": 0,
    "inactive_buildings": 0,
    "construction_queue_count": 0,
    # 以下はEconDeckManagerから取得
    "hand_count": 0,
    "deck_count": 0,
    "discard_count": 0,
    "battle_removed_count": 0
})
```

buildings/deck系は`0`でよい。後で接続する（今は基盤のみ）。

### EconBattle.gd への接続

バトル開始・終了時に呼び出し：

```gdscript
func _start_battle():
    LogManager.start_battle("001")

func _end_battle():
    LogManager.log_battle_summary({
        "type": "BATTLE_SUMMARY",
        "battle_id": LogManager._battle_id,
        "duration": int(elapsed_time),
        "turn": current_turn,
        # 以下はEconEconomy / EconBoard から取得
        "buildings_total": 0,
        "population": economy.population_used,
        "population_cap": economy.population_cap,
        "happiness": economy.satisfaction,
        "wood": economy.resources.get("wood", 0),
        "stone": economy.resources.get("stone", 0),
        "food": economy.resources.get("food", 0),
        "gold": economy.resources.get("gold", 0),
        "total_force": economy.total_force,
        "estimated_units": int(economy.total_force / 10),
        "estimated_dps": (economy.total_force / 10) * 0.2,
        "draw_count": LogManager._draw_count,
        "reload_count": LogManager._reload_count,
        "cards_played": LogManager._cards_played,
        "build_completed": LogManager._build_completed,
        "instant_build_count": LogManager._instant_build_count,
        "queue_max_length": LogManager._queue_max_length
    })
    LogManager.log_analysis_metrics()
    LogManager.end_battle()
```

## 禁止事項

- 全イベントの接続を一度に行わない（Phase 1-2のみ）
- 既存ロジックを変更しない（呼び出し追加のみ）
- ログ出力のために既存の処理順序を変えない
- 検証なしに完了扱いしない

## 検証

必須:
```bash
bash check_syntax.sh
```

動作確認:
```bash
# JSONLパース確認（Godot実行後）
python -c "
import json
import glob
for f in glob.glob('logs/run_*.jsonl'):
    for line in open(f):
        json.loads(line)
    print('OK:', f)
"
```

成功条件:
- check_syntax.sh エラー0件
- Godot起動後にuser://logs/にファイルが生成される
- 5秒ごとにSNAPSHOTログが出る
- バトル終了時にBATTLE_SUMMARY・ANALYSIS_METRICSが出る
- 全行がJSONとしてパースできる

## Codex は完了時に docs/tasks/codex_result_20260502_003.md に報告すること

- 変更ファイル・変更行番号
- 変更概要
- 実行した検証・検証結果
- 未検証項目・残リスク
- PMO更新候補
