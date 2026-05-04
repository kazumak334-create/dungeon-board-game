# Sprint 8: UI・ログ・デバッグ 要件定義書（更新版 2026-05-03）

STATUS: 廃止（→ docs/requirements/REQUIREMENTS_SPRINT_8.md）
対応Sprint: Sprint 8
参照Final企画書: UI・ログ・デバッグFinal企画書（SSoT）
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 8 セクション）
更新日: 2026-05-03

---

## 対応状況
- Final企画書準拠：✅

---

## ⚠️ 重大変更

| 項目 | 旧（参考設計） | 新（Final企画書） |
|---|---|---|
| 常時UI表示項目 | 人口・食料値・満足値%・傾き・段階・兵力・建物効率の8項目 | **人口・食料値・満足度段階・兵力・兵数・ユニット数のみ**（6項目） |
| 満足値%・満足値傾き | 常時表示 | **常時UIで非表示**（詳細値はポップアップのみ） |
| 詳細値の表示方法 | 常時HUDに表示 | **小型ポップアップで表示**（必要時のみ） |
| 右側パネル / ボトムシート | 使用想定 | **右側パネル・ボトムシートは使用禁止** |
| 建物進捗UI | 不明 | **下から上へ進むハイライト/マスク方式** |

---

## 実装対象

### 新規作成
- `scripts/econ_mvp/EconUI.gd`
  - 常時都市ステータスHUD（左上 or 右上の固定位置）
  - 表示項目：人口・食料値・満足度段階・兵力・兵数・ユニット数
  - サイズ：幅240px × 高さ160px程度（小型化）

- `scripts/econ_mvp/EconUIPopup.gd`
  - 詳細値表示用 小型ポップアップ
  - クリック・ホバー時に表示、表示中の項目に対応する詳細を表示
  - 右側パネル・ボトムシートは使用しない

- `scripts/econ_mvp/EconBuildingProgressUI.gd`
  - 各建物の発動進捗を「下から上へ進むハイライト/マスク」で視覚化
  - Sprint 5 の発動間隔タイマーと連動

### 拡張対象
- `scripts/econ_mvp/LogManager.gd`
  - イベントタイプ追加：`POP_CHANGE`, `SAT_SLOPE`, `POP_LOSS`, `LAND_PANEL_GEN`, `LAND_CARD_REWARD`, `LAND_CARD_PLACED`
  - `_should_log` の許可リストに追加

- `scripts/econ_mvp/EconEconomy.gd`
  - 5秒tickで `LogManager.log_event` を呼ぶ（POP_CHANGE / SAT_SLOPE）
  - `apply_defense_breakthrough_loss` で POP_LOSS をログ出力

- `scripts/econ_mvp/EconMain.gd`
  - `EconUI` をシーンに追加
  - `EconBuildingProgressUI` を各建物に紐付け

---

## 実装詳細

### 1. 常時UI（EconUI）

#### 表示項目（6項目のみ）

```text
─────────────────────────
都市ステータス
─────────────────────────
人口         : 50 / 100
食料値       : 18
満足度段階   : satisfied
─────────────────────────
兵力         : 12.0
兵数         : 5
ユニット数   : 3
─────────────────────────
```

#### 非表示項目（常時UIに出さない）

- 満足値%（数値）
- 満足値傾き（%/秒）
- 食料不足カウント
- 建物効率倍率
- 内部 population_float

これらは詳細ポップアップでのみ表示する。

#### 配置・サイズ

- 画面左上 or 右上の固定位置
- サイズ：幅240px × 高さ160px程度（旧仕様の280×200 から小型化）
- 背景：半透明黒

#### 更新頻度

- 0.5秒ごとに `update_status_display()` を呼ぶ

#### 実装スケルトン

```gdscript
class_name EconUI
extends Control

@export var economy: EconEconomy

@onready var label_pop: Label = $VBox/LabelPop
@onready var label_food: Label = $VBox/LabelFood
@onready var label_stage: Label = $VBox/LabelStage
@onready var label_mil: Label = $VBox/LabelMil
@onready var label_soldier: Label = $VBox/LabelSoldier
@onready var label_unit: Label = $VBox/LabelUnit

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
    label_pop.text     = "人口: %d / %d" % [economy.get_display_population(), economy.population_cap]
    label_food.text    = "食料値: %d" % economy.food_value
    label_stage.text   = "段階: %s" % economy.get_satisfaction_stage()
    label_mil.text     = "兵力: %.1f" % economy.military_power
    label_soldier.text = "兵数: %d" % economy.get_soldier_count()
    label_unit.text    = "ユニット: %d" % economy.get_unit_count()
```

### 2. 詳細ポップアップ（EconUIPopup）

#### 表示トリガー

- 常時UIの各項目をクリック or 長押しで対応するポップアップを表示
- 1個のみ同時表示（前のポップアップは閉じる）
- 画面外クリックで閉じる

#### 配置ルール

- ポップアップサイズ：幅220px × 高さ最大140px
- 表示位置：クリックした項目の隣接位置（マウス追従 or 項目近傍）
- **右側パネル・ボトムシートは使用禁止**

#### ポップアップ内容（項目別）

| 項目 | ポップアップ内容 |
|---|---|
| 人口 | 内部値（population_float）/ 増加率 / 減少率 / growth_blocked / 維持必要食料 |
| 食料値 | 食料不足カウント / 5秒前との差分 |
| 満足度段階 | 満足値%（数値）/ 満足値傾き / 内訳5要因 |
| 兵力 | 兵力効果倍率 / 最大値 |
| 兵数 | 動員率 / 最大突撃可能数 |
| ユニット数 | 種類別内訳（必要に応じて） |

#### 実装スケルトン

```gdscript
class_name EconUIPopup
extends PanelContainer

func show_population_detail(economy: EconEconomy, anchor: Vector2) -> void:
    var text: String = ""
    text += "内部人口: %.2f\n" % economy.population_float
    text += "増加率: +%.4f /秒\n" % economy._calculate_population_growth_rate()
    text += "減少率: -%.4f /秒\n" % economy._calculate_population_decline_rate()
    text += "成長停止: %s\n" % str(economy.growth_blocked)
    text += "維持必要食料: %d" % int(ceil(economy.population_float / 50.0))
    $VBox/Content.text = text
    position = anchor
    visible = true

func show_satisfaction_detail(economy: EconEconomy, anchor: Vector2) -> void:
    var b: Dictionary = economy._get_satisfaction_slope_breakdown(economy.buildings)
    var text: String = ""
    text += "満足値: %.1f%%\n" % economy.satisfaction_value
    text += "傾き: %+.3f%%/秒\n" % b["total"]
    text += "  基礎: +0.03\n"
    text += "  人口規模: %+.2f\n" % b["population_scale"]
    text += "  人口変化量: %+.2f\n" % b["population_growth"]
    text += "  建築物: %+.2f\n" % b["building"]
    text += "  食料不足: -%.2f" % b["food_shortage_penalty"]
    $VBox/Content.text = text
    position = anchor
    visible = true
```

### 3. 建物進捗UI（下から上へ進むハイライト/マスク）

#### 仕様

```text
- 各建物のスプライト or アイコンに進捗マスクを重ねる
- マスクは下から上へ進む
- 進捗 = current_timer / current_interval
- マスク色：半透明緑（カスタマイズ可）
- 発動タイミング（progress=1.0）で一瞬フラッシュ → 0.0 へリセット
```

#### 実装イメージ

```gdscript
class_name EconBuildingProgressUI
extends Control

@export var building: EconBuilding
@onready var mask_rect: ColorRect = $MaskRect

func _process(_delta: float) -> void:
    if building == null or not building.is_alive:
        mask_rect.visible = false
        return
    var progress: float = building.get_timer_progress()  # 0.0〜1.0
    mask_rect.size.y = size.y * progress
    mask_rect.position.y = size.y - mask_rect.size.y  # 下から上へ
```

EconBuilding 側に `get_timer_progress() -> float` を追加し、Sprint 5 の `_timer / _last_interval` を返す。

### 4. ログイベント追加

#### POP_CHANGE（5秒tickごと）

```gdscript
LogManager.log_event({
    "type": "POP_CHANGE",
    "time": get_battle_time(),
    "population": population_float,
    "stage": get_satisfaction_stage(),
    "growth_rate": _calculate_population_growth_rate(),
    "decline_rate": _calculate_population_decline_rate(),
    "growth_blocked": growth_blocked,
    "food_required": int(ceil(population_float / 50.0)),
})
```

#### SAT_SLOPE（5秒tickごと）

```gdscript
var b: Dictionary = _get_satisfaction_slope_breakdown(buildings)
LogManager.log_event({
    "type": "SAT_SLOPE",
    "time": get_battle_time(),
    "satisfaction": satisfaction_value,
    "stage": get_satisfaction_stage(),
    "slope_total": satisfaction_slope,
    "base": 0.03,
    "population_scale": b["population_scale"],
    "population_growth": b["population_growth"],
    "building": b["building"],
    "food_shortage_penalty": b["food_shortage_penalty"],
})
```

#### POP_LOSS（防衛突破時のみ）

```gdscript
LogManager.log_event({
    "type": "POP_LOSS",
    "time": get_battle_time(),
    "cause": "defense_breakthrough",
    "loss": int(actual),
    "before": before,
    "after": population_float,
})
```

注：突撃時は人口減少しないため、`cause: "charge"` のログは **発火しない**（Sprint 6 の方針変更による）。

#### LAND_PANEL_GEN（起動時・Sprint 1 連動）

各土地パネル生成完了時に1件ずつ出力。

#### LAND_CARD_REWARD（毎戦闘後）

3候補・選択結果・配置座標をログ。

#### LAND_CARD_PLACED（土地カード配置時）

```gdscript
LogManager.log_event({
    "type": "LAND_CARD_PLACED",
    "pos": [target_pos.x, target_pos.y],
    "panel_data": card.get("panel_data", {}),
})
```

### 5. LogManager の追加

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

`POP_CHANGE / SAT_SLOPE / POP_LOSS / LAND_PANEL_GEN / LAND_CARD_REWARD / LAND_CARD_PLACED` は `verbose_types` に含めず、DEBUGレベルで出力されるようにする。

### 6. 土地パネル詳細UI（クリック時のみ）

```text
土地パネルクリック → 詳細ポップアップ
  - 座標 (col, row)
  - 距離 / 距離帯
  - カテゴリ (single/composite)
  - 資源値内訳
  - 特殊タグ
  - 地形タイプ
  - 配置中の建物
```

サイズ：幅240px × 高さ最大200px。マウス追従 or パネル隣接配置。**右側パネル禁止**。

---

## 完了条件

- [ ] 常時UIが画面に表示され、6項目（人口/食料値/満足度段階/兵力/兵数/ユニット数）のみが表示される
- [ ] 常時UIに満足値%・満足値傾きが表示されないことを確認
- [ ] 0.5秒ごとに常時UIが更新される
- [ ] 各項目クリックで詳細ポップアップが表示される
- [ ] 右側パネル・ボトムシートは使用していない
- [ ] 詳細ポップアップに対応する詳細値が表示される
- [ ] 建物進捗UIが下から上へ進むハイライト/マスク方式で動作する
- [ ] 5秒tickで POP_CHANGE / SAT_SLOPE がログ出力される
- [ ] 防衛突破時に POP_LOSS（cause=defense_breakthrough）がログ出力される
- [ ] 突撃時に POP_LOSS（cause=charge）はログ出力されない（Sprint 6 方針）
- [ ] 起動時に LAND_PANEL_GEN がログ出力される
- [ ] 毎戦闘後に LAND_CARD_REWARD がログ出力される
- [ ] 土地カード配置時に LAND_CARD_PLACED がログ出力される
- [ ] check_syntax.sh エラー0件

---

## 確定仕様（Final企画書 SSoT）

| 仕様 | 値 |
|---|---|
| 常時UI表示項目 | 人口/食料値/満足度段階/兵力/兵数/ユニット数（6項目） |
| 満足値% / 満足値傾き | 常時UI非表示 |
| 詳細値の表示方法 | 小型ポップアップ |
| 右側パネル | 使用禁止 |
| ボトムシート | 使用禁止 |
| 建物進捗UI | 下から上へ進むハイライト/マスク方式 |

---

## 非対象（MVP対象外）

- 詳細ポップアップの装飾・アニメーション
- ヒートマップ・グラフ表示
- 設定画面でのUI項目カスタマイズ
- 突撃時の POP_LOSS ログ（Sprint 6 で人口減少しないため）

---

## 関連する既存コード

- `scripts/econ_mvp/LogManager.gd:42-65` `log_event` / `log_snapshot`
- `scripts/econ_mvp/LogManager.gd:90-99` `_should_log`
- `scripts/econ_mvp/EconMain.gd` （UI追加箇所）
- Sprint 1〜7 で追加した全フィールド・ゲッター
- Sprint 5 の `EconBuilding._timer` / `_last_interval`（建物進捗UI で参照）
