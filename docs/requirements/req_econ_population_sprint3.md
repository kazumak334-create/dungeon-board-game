# Sprint 3: 人口システムの実装

ステータス: 実装リソース（一時）
対応Sprint: Sprint 3
参照設計書:
- docs/econ/population_satisfaction_food_system_design.md §4
- docs/econ/sprint_plan_population_satisfaction_food.md §7
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 3 セクション）
更新日: 2026-05-03

---

## 目的

人口を「リアルタイムに小数で増減する都市ステータス」として実装する。
人口変化量を増加要因・減少要因の合算で算出し、整数到達時に食料値を消費する。

満足度段階を主な人口増加要因として参照する（Sprint 4で本格的な満足度更新が入るが、本Sprintではスタブとして`get_satisfaction_stage()`を使用）。

---

## 実装対象クラス・関数

### 拡張対象
- `scripts/econ_mvp/EconEconomy.gd`
  - `update_population(delta)` 新規追加（リアルタイム人口増減）
  - `_calculate_population_growth_rate()` 新規追加（増加要因合計）
  - `_calculate_population_decline_rate()` 新規追加（減少要因合計）
  - `_try_confirm_population_growth()` 新規追加（整数到達時の食料値消費）
  - `_get_population_growth_log()` 新規追加（ログ用内訳辞書を返す）
  - `update()` 内に上記呼び出しを追加（Step 7 として）

---

## 仕様

### 1. 人口の表示・範囲

```text
表示人口 = max(1, floor(population_float))
範囲: 1.0 <= population_float <= float(population_cap)
```

### 2. 人口変化量

毎フレーム（または1秒tickで集約）以下を計算する。MVPでは`update_population(delta)`を毎フレーム呼ぶ。

```text
増加要因合計 = 満足度段階による加算 + その他将来要因
減少要因合計 = 食料値不足による減算 + 不満段階減算 + 衰退段階減算
人口変化量 = 増加要因合計 - 減少要因合計
population_float = clamp(population_float + 人口変化量 * delta, 1.0, float(population_cap))
```

### 3. 人口増加要因（満足度段階別）

| 満足度段階 | 増加速度（人/秒） |
|---|---:|
| decline（衰退） | +0.00 |
| dissatisfied（不満） | +0.00 |
| stable（安定） | +0.02 |
| satisfied（満足） | +0.04 |
| prosperity（繁栄） | +0.05 |

#### 増加0扱い条件

- `population_float >= float(population_cap)`
- 直前の整数到達確定で食料値不足だった場合（`_growth_blocked_by_food: bool`フラグで管理）

```gdscript
func _calculate_population_growth_rate() -> float:
    if population_float >= float(population_cap):
        return 0.0
    if _growth_blocked_by_food:
        return 0.0
    var stage: String = get_satisfaction_stage()
    match stage:
        "decline", "dissatisfied": return 0.0
        "stable": return 0.02
        "satisfied": return 0.04
        "prosperity": return 0.05
        _: return 0.0
```

### 4. 人口減少要因

| 要因 | 減少速度（人/秒） | 条件 |
|---|---:|---|
| 食料値不足 | 0.04 | 直前の人口維持処理で`food_shortage_count > 0`時 |
| 不満段階 | 0.04 | `get_satisfaction_stage() == "dissatisfied"` |
| 衰退段階 | 0.10 | `get_satisfaction_stage() == "decline"` |

複数要因は加算される（例: 衰退かつ食料値不足 → -0.14/秒）。

```gdscript
func _calculate_population_decline_rate() -> float:
    var rate: float = 0.0
    if food_shortage_count > 0:
        rate += 0.04
    var stage: String = get_satisfaction_stage()
    if stage == "dissatisfied":
        rate += 0.04
    elif stage == "decline":
        rate += 0.10
    return rate
```

### 5. 人口増加確定処理（整数到達時の食料値消費）

`update_population` 内で、`floor`値が前tickから増加した場合に確定処理を実行：

```text
old_floor = floor(population_float_before)
new_floor = floor(population_float_after)

if new_floor > old_floor:
    必要食料値 = max(1, old_floor)  # ※繁栄時は max(1, old_floor - 1)
    if food_value >= 必要食料値:
        food_value -= 必要食料値
        _growth_blocked_by_food = false
        print("[EconEconomy] 人口増加確定: %d → %d (食料値-%d)" % [old_floor, new_floor, 必要食料値])
    else:
        # ロールバック：next整数手前で停止
        population_float = float(new_floor) - 0.001
        _growth_blocked_by_food = true
        print("[EconEconomy] 人口増加停止：食料値不足 (必要:%d 現在:%d)" % [必要食料値, food_value])
```

繁栄時の軽減：
```text
if get_satisfaction_stage() == "prosperity":
    必要食料値 = max(1, old_floor - 1)
```

### 6. 食料値が補充されたら再開

`food_value` が必要量に到達したら次フレームで `_growth_blocked_by_food` を解除：

```gdscript
if _growth_blocked_by_food:
    var stage: String = get_satisfaction_stage()
    var need: int = max(1, int(floor(population_float)))
    if stage == "prosperity":
        need = max(1, int(floor(population_float)) - 1)
    if food_value >= need:
        _growth_blocked_by_food = false
```

### 7. 人口変化量ログ用内訳

```gdscript
func _get_population_change_breakdown() -> Dictionary:
    return {
        "growth_total": _calculate_population_growth_rate(),
        "decline_total": _calculate_population_decline_rate(),
        "decline_food_shortage": 0.04 if food_shortage_count > 0 else 0.0,
        "decline_dissatisfied": 0.04 if get_satisfaction_stage() == "dissatisfied" else 0.0,
        "decline_decline_stage": 0.10 if get_satisfaction_stage() == "decline" else 0.0,
        "stage": get_satisfaction_stage(),
        "blocked_by_food": _growth_blocked_by_food,
    }
```

ログ出力はSprint 8で `LogManager` に接続。本Sprintでは`print`ログのみ。

### 8. update()への統合

`EconEconomy.update(delta, total_units)` 内、Step 6の後に以下を追加：

```gdscript
# ---- Step 7: リアルタイム人口更新（Sprint 3） ----
update_population(delta)
```

注：`update_population` は5秒tickの内側ではなく、毎フレームdelta積算で呼ぶ。
そのため、tickチェックの`_tick_timer < TICK_INTERVAL: return`より前に配置する必要がある。

#### 構造変更案

```gdscript
func update(delta: float, total_unit_count: int) -> void:
    # 毎フレーム処理（Sprint 3）
    update_population(delta)

    # 5秒tick処理（既存）
    _tick_timer += delta
    if _tick_timer < TICK_INTERVAL:
        return
    _tick_timer -= TICK_INTERVAL
    # ... 以下既存
```

---

## 実装手順

1. `EconEconomy` に新規フィールド追加
   - `_growth_blocked_by_food: bool = false`
2. `_calculate_population_growth_rate()` 実装
3. `_calculate_population_decline_rate()` 実装
4. `update_population(delta)` 実装（差分計算 + clamp + 整数到達確定処理）
5. `_try_confirm_population_growth(old_floor, new_floor)` 実装
6. `_get_population_change_breakdown()` 実装（ログ用）
7. `update()` の構造を変更し、毎フレーム部分と5秒tick部分を分離
8. デバッグprintで人口変化量・内訳を出力
9. `bash check_syntax.sh` 実行

---

## 完了条件

- [ ] `population_float` が`update_population(delta)`で増減する
- [ ] 人口上限（`population_cap`）で増加が止まる
- [ ] 食料値不足時（`food_shortage_count > 0`）に減少要因0.04/秒が加算される
- [ ] 不満段階で減少要因0.04/秒が加算される
- [ ] 衰退段階で減少要因0.10/秒が加算される
- [ ] 増加・減少要因が同時発生時に正しく合算される
- [ ] 整数人口到達時に`max(1, floor(population_float))`ぶんの食料値が消費される
- [ ] 繁栄段階では`max(1, floor(population_float) - 1)`に軽減される
- [ ] 食料値不足で人口増加確定が止まる（次の整数に到達しない）
- [ ] 食料値が補充されたら人口増加が再開する
- [ ] 人口変化量の内訳がprintログに出る
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- `population_used`（既存int）は別概念（稼働人口数）として残す。本Sprintで触らない
- 表示用の`get_display_population()`はSprint 1で実装済み。本Sprintでは利用のみ
- `update_population`は毎フレーム呼ばれるため、過剰なログを避ける（5秒に1回サマリprintで十分）
- `_growth_blocked_by_food` は内部状態。UIには直接出さない（Sprint 8で表示検討）
- 突撃・防衛突破による即時人口減少は Sprint 6 で別途実装（人口変化量とは別枠）

---

## 関連する既存コード

- `EconEconomy.gd:64-164` 既存`update()`構造（毎フレーム/5秒tick混在を整理）
- `EconEconomy.gd:166-167` `get_working_population()`（人口関連既存ロジック）
- Sprint 1 で追加した `population_float`, `food_value`, `food_shortage_count`
- Sprint 2 で追加した `consume_food_for_maintenance()` （`food_shortage_count`の増減元）
