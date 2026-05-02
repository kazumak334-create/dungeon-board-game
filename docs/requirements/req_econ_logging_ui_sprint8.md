# Sprint 8: ログ・UI・デバッグ表示

ステータス: 実装リソース（一時）
対応Sprint: Sprint 8
参照設計書:
- docs/econ/population_satisfaction_food_system_design.md §4.6, §6.10
- docs/econ/sprint_plan_population_satisfaction_food.md §12
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 8 セクション）
更新日: 2026-05-03

---

## 目的

人口・満足度・食料値の状態変化を、UI表示とログ出力で確認できるようにする。

- 都市ステータスをUIに常時表示
- 人口変化量・満足値傾きの内訳ログを LogManager に流す
- 突撃・防衛突破による即時人口減少を視覚化

---

## 実装対象クラス・関数

### 新規作成
- `scripts/econ_mvp/EconUI.gd`
  - 都市ステータスHUD用Node（Control派生）
  - フィールド：`economy: EconEconomy` 参照
  - 関数：`update_status_display()` （毎フレーム or 0.5秒tick）
  - 子要素：Label群（人口・食料値・満足値・段階・兵力・建物効率）

### 拡張対象
- `scripts/econ_mvp/LogManager.gd`
  - イベントタイプ追加：`POP_CHANGE`, `SAT_SLOPE`, `POP_LOSS`
  - `_should_log` の許可リストに追加

- `scripts/econ_mvp/EconEconomy.gd`
  - 5秒tickで `LogManager.log_event({"type": "POP_CHANGE", ...})` を呼ぶ
  - 5秒tickで `LogManager.log_event({"type": "SAT_SLOPE", ...})` を呼ぶ
  - `apply_charge_population_loss` / `apply_defense_breakthrough_loss` で `LogManager.log_event({"type": "POP_LOSS", ...})` を呼ぶ

- `scripts/econ_mvp/EconMain.gd`
  - `EconUI` をシーンに追加
  - `EconUI.economy = economy` を接続

---

## 仕様

### 1. 都市ステータスUI（EconUI）

#### 表示項目

```text
─────────────────────────
都市ステータス
─────────────────────────
人口         : 5 / 10  (内部 4.83)
食料値       : 18
食料不足     : 0
満足値       : 62.5%
傾き         : +0.05%/秒
段階         : satisfied
─────────────────────────
兵力         : 12.0
建物効率     : ×1.05
─────────────────────────
```

#### 配置

- 画面右上または左上の固定位置
- サイズ：幅280px × 高さ200px程度
- 背景：半透明黒（既存UI基準に合わせる）
- フォント：既存EconMVPのデフォルトを流用

#### 更新頻度

- 0.5秒ごとに `update_status_display()` を呼ぶ（毎フレームは過剰）
- Timer または `_process` 内のtimer変数で制御

#### 実装スケルトン

```gdscript
class_name EconUI
extends Control

@export var economy: EconEconomy

@onready var label_pop: Label = $VBox/LabelPop
@onready var label_food: Label = $VBox/LabelFood
@onready var label_shortage: Label = $VBox/LabelShortage
@onready var label_sat: Label = $VBox/LabelSat
@onready var label_slope: Label = $VBox/LabelSlope
@onready var label_stage: Label = $VBox/LabelStage
@onready var label_mil: Label = $VBox/LabelMil
@onready var label_eff: Label = $VBox/LabelEff

var _refresh_timer: float = 0.0
const REFRESH_INTERVAL: float = 0.5

func _process(delta: float) -> void:
    _refresh_timer += delta
    if _refresh_timer < REFRESH_INTERVAL:
        return
    _refresh_timer = 0.0
    update_status_display()

func update_status_display() -> void:
    if economy == null:
        return
    label_pop.text = "人口: %d / %d (内部 %.2f)" % [economy.get_display_population(), economy.population_cap, economy.population_float]
    label_food.text = "食料値: %d" % economy.food_value
    label_shortage.text = "食料不足: %d" % economy.food_shortage_count
    label_sat.text = "満足値: %.1f%%" % economy.satisfaction_value
    label_slope.text = "傾き: %+.2f%%/秒" % economy.satisfaction_slope
    label_stage.text = "段階: %s" % economy.get_satisfaction_stage()
    label_mil.text = "兵力: %.1f" % economy.military_power
    label_eff.text = "建物効率: ×%.2f" % economy.building_efficiency_modifier
```

シーンノード構造（コードで動的生成、または .tscn 作成）：

```
EconUI (Control)
└── VBox (VBoxContainer)
    ├── LabelPop (Label)
    ├── LabelFood (Label)
    ├── LabelShortage (Label)
    ├── LabelSat (Label)
    ├── LabelSlope (Label)
    ├── LabelStage (Label)
    ├── LabelMil (Label)
    └── LabelEff (Label)
```

MVPでは .tscn を作らず、コード内で `_ready()` でラベルを動的生成してもよい（KISS）。

### 2. 人口変化量ログ（POP_CHANGE）

5秒tickで以下を `LogManager.log_event` に流す：

```gdscript
LogManager.log_event({
    "type": "POP_CHANGE",
    "time": get_battle_time(),
    "population": population_float,
    "stage": get_satisfaction_stage(),
    "growth": _calculate_population_growth_rate(),
    "decline": _calculate_population_decline_rate(),
    "decline_food_shortage": 0.04 if food_shortage_count > 0 else 0.0,
    "decline_dissatisfied": 0.04 if get_satisfaction_stage() == "dissatisfied" else 0.0,
    "decline_decline_stage": 0.10 if get_satisfaction_stage() == "decline" else 0.0,
    "blocked_by_food": _growth_blocked_by_food,
})
```

#### 出力例（jsonl）

```json
{"type":"POP_CHANGE","time":15,"population":4.32,"stage":"dissatisfied","growth":0.0,"decline":0.08,"decline_food_shortage":0.04,"decline_dissatisfied":0.04,"decline_decline_stage":0.0,"blocked_by_food":false}
```

### 3. 満足値傾きログ（SAT_SLOPE）

5秒tickで以下を流す：

```gdscript
var breakdown: Dictionary = _get_satisfaction_slope_breakdown(buildings)
LogManager.log_event({
    "type": "SAT_SLOPE",
    "time": get_battle_time(),
    "satisfaction": satisfaction_value,
    "stage": get_satisfaction_stage(),
    "slope_total": satisfaction_slope,
    "base": breakdown["base"],
    "population_scale": breakdown["population_scale"],
    "population_growth": breakdown["population_growth"],
    "building": breakdown["building"],
    "food_shortage_penalty": breakdown["food_shortage_penalty"],
})
```

#### 出力例

```json
{"type":"SAT_SLOPE","time":15,"satisfaction":58.3,"stage":"stable","slope_total":-0.11,"base":0.0,"population_scale":-0.06,"population_growth":-0.04,"building":0.05,"food_shortage_penalty":0.16}
```

### 4. 即時人口減少ログ（POP_LOSS）

`apply_charge_population_loss` / `apply_defense_breakthrough_loss` 内で呼び出し：

```gdscript
LogManager.log_event({
    "type": "POP_LOSS",
    "time": get_battle_time(),
    "cause": "charge",  # or "defense_breakthrough"
    "loss": int(actual),
    "before": before,
    "after": population_float,
})
```

#### 出力例

```json
{"type":"POP_LOSS","time":42,"cause":"charge","loss":3,"before":8.21,"after":5.21}
{"type":"POP_LOSS","time":51,"cause":"defense_breakthrough","loss":2,"before":7.10,"after":5.10}
```

### 5. LogManager の追加

`LogManager._should_log()` 内、許可リストに `POP_CHANGE`, `SAT_SLOPE`, `POP_LOSS` を追加：

```gdscript
func _should_log(event_type: String) -> bool:
    if not log_enabled:
        return false
    var basic_types := ["SNAPSHOT", "BATTLE_SUMMARY", "ANALYSIS_METRICS"]
    if log_level == "BASIC":
        return event_type in basic_types
    var verbose_types := ["RESOURCE_TICK", "HAPPINESS_TICK", "BUILDING_OPERATION", "SMITHY_EFFECT", "UI_ACTION"]
    if log_level == "DEBUG":
        return not (event_type in verbose_types)
    return true
```

DEBUGレベルで POP_CHANGE / SAT_SLOPE / POP_LOSS が出力されるよう、verbose_types に含めない（DEBUGで出る）。

### 6. EconEconomy.update() への統合

5秒tickの末尾で：

```gdscript
# Sprint 8: ログ出力
LogManager.log_event({
    "type": "POP_CHANGE",
    ...（上記仕様通り）
})
LogManager.log_event({
    "type": "SAT_SLOPE",
    ...（上記仕様通り）
})
```

### 7. EconMain への EconUI 接続

```gdscript
# EconMain._ready() 内
var ui: EconUI = preload("res://scripts/econ_mvp/EconUI.gd").new()
ui.economy = economy
add_child(ui)
ui.position = Vector2(20, 20)  # 左上に配置
```

または .tscn 内で配置する場合、エディタで `economy` をスクリプト側で接続する。

---

## 実装手順

1. `EconUI.gd` を新規作成（コード内ラベル動的生成方式 推奨）
2. `EconUI._process()` で 0.5秒tickの更新ループを実装
3. `EconUI.update_status_display()` で全Label更新
4. `LogManager._should_log` に新イベントタイプ対応（変更不要、verbose_typesに含めなければOK）
5. `EconEconomy.update()` 5秒tick末尾で `LogManager.log_event` を 2回呼ぶ（POP_CHANGE / SAT_SLOPE）
6. `EconEconomy.apply_charge_population_loss` で POP_LOSS をログ出力
7. `EconEconomy.apply_defense_breakthrough_loss` で POP_LOSS をログ出力
8. `EconMain._ready()` で `EconUI` をシーンに追加
9. ゲーム起動して画面右上に都市ステータスが表示されることを確認
10. `user://logs/run_*.jsonl` を開いて POP_CHANGE / SAT_SLOPE / POP_LOSS が記録されることを確認
11. `bash check_syntax.sh` 実行

---

## 完了条件

- [ ] ゲーム起動時、画面に都市ステータスHUDが表示される
- [ ] 0.5秒ごとにHUD表示が更新される
- [ ] 人口（表示/上限/内部値）・食料値・食料不足カウント・満足値・傾き・段階・兵力・建物効率がHUDに表示される
- [ ] 5秒tickで POP_CHANGE イベントがログファイルに記録される
- [ ] POP_CHANGE に増加要因・減少要因の内訳が含まれる
- [ ] 5秒tickで SAT_SLOPE イベントがログファイルに記録される
- [ ] SAT_SLOPE に5要因（base/scale/growth/building/penalty）の内訳が含まれる
- [ ] 突撃発生時に POP_LOSS（cause=charge）がログ出力される
- [ ] 防衛突破時に POP_LOSS（cause=defense_breakthrough）がログ出力される
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- 画面確認はユーザーに委ねる（CLAUDE.md ルール）。実装側は print + ログファイル確認まで
- HUD配置・サイズ・色は暫定値。最終調整は Designer に委ねる
- LogManager は既存の `_file = FileAccess.open(...)` 構造を流用。新規ファイル作成は不要
- `get_battle_time()` が EconEconomy に未存在の場合、`_tick_index * TICK_INTERVAL` で代用
- POP_CHANGE / SAT_SLOPE は5秒tick内で2件のJSON行を出力する。1tickあたり最大3-5行のログ増加で許容範囲
- EconUI は MVPでは .tscn を作らず動的生成でよい（KISS原則）
- 既存の `LogManager` Autoloadであることを前提（`project.godot` で確認）

---

## 関連する既存コード

- `scripts/econ_mvp/LogManager.gd:42-65` `log_event` / `log_snapshot`
- `scripts/econ_mvp/LogManager.gd:90-99` `_should_log`
- `scripts/econ_mvp/EconMain.gd` （UI追加箇所）
- Sprint 1〜6 で追加した全フィールド・ゲッター
