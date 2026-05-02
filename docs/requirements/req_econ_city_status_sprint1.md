# Sprint 1: 都市ステータス基盤

ステータス: 実装リソース（一時）
対応Sprint: Sprint 1
参照設計書:
- docs/econ/population_satisfaction_food_system_design.md
- docs/econ/panel_resource_system_design.md
- docs/econ/sprint_plan_population_satisfaction_food.md §5
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 1 セクション）
更新日: 2026-05-03

---

## 目的

人口・食料値・満足度を通常資源とは別に管理できる「都市ステータス」基盤を構築する。
小麦と食料値を分離し、後続Sprintで使用するデータ構造・ゲッター・初期化処理を整える。

本Sprintはデータ構造のみ（実処理はSprint 2以降で追加）。

---

## 実装対象クラス・関数

### 拡張対象
- `scripts/econ_mvp/EconEconomy.gd`
  - 都市ステータス用フィールドの追加
  - 初期化処理 `initialize_v0_2()` への都市ステータス初期化追加
  - 満足度段階算出ゲッター `get_satisfaction_stage()` 新規追加
  - 表示人口ゲッター `get_display_population()` 新規追加

### 追加フィールド（EconEconomyに追加）

| フィールド名 | 型 | 初期値 | 用途 |
|---|---|---|---|
| `population_float` | float | 1.0 | 内部小数人口（既存`population_used: int`は維持して併存） |
| `population_cap` | int | 既存維持 | 人口上限（住宅で増加） |
| `food_value` | int | 0 | 食料値（小麦とは別管理） |
| `satisfaction_value` | float | 60.0 | 満足値（0〜100%） |
| `satisfaction_slope` | float | 0.0 | 満足値傾き（%/秒） |
| `satisfaction_stage` | String | "satisfied" | 満足度段階文字列キャッシュ |
| `military_power` | float | 既存維持 | 兵力 |
| `building_efficiency_modifier` | float | 1.0 | 建物効率補正（Sprint 5で使用） |
| `food_shortage_count` | int | 0 | 食料不足カウント |

### 既存フィールドとの関係

| 既存 | 扱い |
|---|---|
| `food: int` | 既存維持（後方互換）。Sprint 2で`food_value`へ移行を検討 |
| `wheat: int` | 既存維持（通常資源としての小麦） |
| `satisfaction: int` | 既存維持。`satisfaction_value: float`を新規追加し並存。Sprint 4で完全移行 |
| `population_used: int` | 既存維持。`population_float`を新規追加し並存。Sprint 3で同期処理追加 |

---

## 仕様

### 1. 人口の小数管理

- 内部値：`population_float: float`（小数）
- 表示値：`floor(population_float)`（整数）
- 下限：`max(1, floor(population_float))`
- 上限：`min(population_float, float(population_cap))`

### 2. 食料値

- 型：`int`
- 初期値：0
- 上限なし（MVPでは食料値最大保有上限は設けない／設計書 §14.1 残論点）
- 下限：0

### 3. 満足値

- 型：`float`
- 初期値：60.0
- 範囲：0.0 〜 100.0（クランプ）
- リアルタイム更新：`satisfaction_value = clamp(satisfaction_value + satisfaction_slope * delta, 0.0, 100.0)`
- 本Sprintでは更新処理は実装しない。フィールドのみ用意。

### 4. 満足度段階の算出（5段階）

| 満足値 | 段階キー | 表示名 |
|---:|---|---|
| 0〜19% | `decline` | 衰退 |
| 20〜39% | `dissatisfied` | 不満 |
| 40〜59% | `stable` | 安定 |
| 60〜79% | `satisfied` | 満足 |
| 80〜100% | `prosperity` | 繁栄 |

```gdscript
func get_satisfaction_stage() -> String:
    var v: float = satisfaction_value
    if v < 20.0: return "decline"
    if v < 40.0: return "dissatisfied"
    if v < 60.0: return "stable"
    if v < 80.0: return "satisfied"
    return "prosperity"
```

### 5. 表示人口ゲッター

```gdscript
func get_display_population() -> int:
    return max(1, int(floor(population_float)))
```

### 6. 初期化処理

`initialize_v0_2()` の末尾に以下を追加：

```gdscript
population_float = 1.0
food_value = 0
satisfaction_value = 60.0
satisfaction_slope = 0.0
satisfaction_stage = "satisfied"
building_efficiency_modifier = 1.0
food_shortage_count = 0
```

---

## 実装手順

1. `EconEconomy.gd` に上記フィールドを追加（既存フィールドの直下に追加し、コメントで「Sprint 1: 都市ステータス基盤（§5）」と明示）
2. `get_satisfaction_stage()` を追加
3. `get_display_population()` を追加
4. `initialize_v0_2()` に都市ステータス初期化を追加
5. デバッグ用 print を追加
   ```
   print("[EconEconomy] CityStatus init: pop=%.2f food=%d sat=%.1f stage=%s" % [population_float, food_value, satisfaction_value, get_satisfaction_stage()])
   ```
6. `bash check_syntax.sh` を実行してエラー0件を確認

---

## 完了条件

- [ ] 都市ステータスが通常資源とは別フィールドとして保持されている
- [ ] `population_float`が小数で保持されている
- [ ] `get_display_population()`が`floor`値（最低1）を返す
- [ ] `food_value`, `satisfaction_value`, `satisfaction_slope`, `food_shortage_count` が独立して保持されている
- [ ] `get_satisfaction_stage()` が満足値から正しい段階キーを返す（5段階）
- [ ] `initialize_v0_2()` で全フィールドが初期化される
- [ ] check_syntax.sh エラー0件
- [ ] 起動時にデバッグprintで都市ステータスが表示される

---

## 制約・注意事項

- 既存フィールド（`food`, `wheat`, `satisfaction`, `population_used`）は削除しない。後方互換のため並存させる
- 本Sprintでは「データ構造のみ」を実装。リアルタイム更新処理（人口増減・満足値傾き計算等）はSprint 2-4で実装する
- 用語統一ルール（CLAUDE.md）に従い、フィールド名は設計書（population/food_value/satisfaction_value/satisfaction_slope）と一致させる
- `building_efficiency_modifier` は Sprint 5 で使用するためフィールドのみ用意

---

## 関連する既存コード

- `EconEconomy.gd:1-380` 全体構造
- `EconEconomy.gd:22-25` 既存の`resources/food/satisfaction/military_power`定義
- `EconEconomy.gd:193-201` 既存の`get_happiness_state()`（4段階）
  - Sprint 4 完了後に5段階の `get_satisfaction_stage()` へ統一する想定（本Sprintでは並存）
- `EconEconomy.gd:362-379` 既存`initialize_v0_2()`
