STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# Sprint 3: 人口システム 要件定義書（更新版 2026-05-03）

ステータス: 実装リソース（一時）
対応Sprint: Sprint 3
参照Final企画書: 人口システムFinal企画書（SSoT）
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 3 セクション）
更新日: 2026-05-03

---

## 対応状況
- Final企画書準拠：✅

---

## ⚠️ 重大変更

Final企画書を SSoT として、以下の項目が変更・新規追加された。

| 項目 | 旧（参考設計） | 新（Final企画書） |
|---|---|---|
| 内部人口スケール | `population_float` を 1.0 起点で管理 | **初期人口 50（内部値）/ 上限 100 / 下限 10** で管理 |
| 増減方式 | 固定速度（+0.02 〜 +0.05 / 秒等） | **割合ベース計算**（現在人口 × 増減率） |
| 人口維持必要食料値 | `max(1, floor(population_float))`（人口=食料値1単位） | **`ceil(現在人口 / 50)`**（50人ごとに食料値1単位） |
| 人口増加確定単位 | 1人ごとに整数到達確定処理 | **10人到達ごとに確定処理**（増加確定単位 = 10） |
| growth_blocked フラグ | `_growth_blocked_by_food` | **`growth_blocked` を正式フラグ名として明記** |

---

## 実装対象

### 拡張対象クラス
- `scripts/econ_mvp/EconEconomy.gd`
  - `update_population(delta)` 新規追加（リアルタイム人口増減）
  - `_calculate_population_growth_rate()` 新規追加（増加率算出）
  - `_calculate_population_decline_rate()` 新規追加（減少率算出）
  - `_try_confirm_population_growth()` 新規追加（10人到達ごとの食料値消費）
  - `_get_population_change_breakdown()` 新規追加（ログ用内訳辞書）
  - `update()` の毎フレーム部に `update_population(delta)` を追加
  - `growth_blocked: bool` フィールド新規追加

### 内部人口スケール定数
```gdscript
const POPULATION_INITIAL: int = 50
const POPULATION_CAP_INITIAL: int = 100
const POPULATION_FLOOR: int = 10
const POPULATION_GROWTH_CONFIRM_UNIT: int = 10  # 10人ごとに確定処理
```

---

## 実装詳細

### 1. 人口の表示・範囲

```text
表示人口 = max(POPULATION_FLOOR, floor(population_float))
範囲: float(POPULATION_FLOOR) <= population_float <= float(population_cap)

初期値:
- population_float = 50.0
- population_cap   = 100
```

### 2. 人口変化量（割合ベース）

毎フレーム delta 積算で更新する。

```text
増加率（割合/秒）= 段階別増加率係数（後述）
減少率（割合/秒）= 段階別減少率係数 + 食料不足係数

人口変化量 = 現在人口 × (増加率 - 減少率)
population_float = clamp(
    population_float + 人口変化量 * delta,
    float(POPULATION_FLOOR),
    float(population_cap)
)
```

### 3. 人口増加率（割合ベース・満足度段階別）

| 満足度段階 | 増加率（割合/秒） |
|---|---:|
| decline（衰退） | +0.000 |
| dissatisfied（不満） | +0.000 |
| stable（安定） | +0.0004 |
| satisfied（満足） | +0.0008 |
| prosperity（繁栄） | +0.0010 |

例：人口50・繁栄段階 → 50 × 0.0010 = +0.05 人/秒

#### 増加0扱い条件
- `population_float >= float(population_cap)`
- `growth_blocked == true`（直前の確定処理で食料値不足だった）

```gdscript
func _calculate_population_growth_rate() -> float:
    if population_float >= float(population_cap):
        return 0.0
    if growth_blocked:
        return 0.0
    var stage: String = get_satisfaction_stage()
    match stage:
        "decline", "dissatisfied": return 0.0
        "stable":     return 0.0004
        "satisfied":  return 0.0008
        "prosperity": return 0.0010
        _: return 0.0
```

### 4. 人口減少率（割合ベース）

| 要因 | 減少率（割合/秒） | 条件 |
|---|---:|---|
| 食料値不足 | 0.0008 | 直前の人口維持処理で `food_shortage_count > 0` |
| 不満段階 | 0.0008 | `get_satisfaction_stage() == "dissatisfied"` |
| 衰退段階 | 0.0020 | `get_satisfaction_stage() == "decline"` |

複数要因は加算される。下限は `POPULATION_FLOOR (=10)`。

```gdscript
func _calculate_population_decline_rate() -> float:
    var rate: float = 0.0
    if food_shortage_count > 0:
        rate += 0.0008
    var stage: String = get_satisfaction_stage()
    if stage == "dissatisfied":
        rate += 0.0008
    elif stage == "decline":
        rate += 0.0020
    return rate
```

### 5. 人口増加確定処理（10人到達ごとの食料値消費）

`update_population` 内で、`floor(population_float / 10)` の値が前tickから増加した場合に確定処理を実行する。

```text
old_unit = floor(population_float_before / 10)
new_unit = floor(population_float_after / 10)

if new_unit > old_unit:
    必要食料値 = ceil(population_float_after / 50)
    if food_value >= 必要食料値:
        food_value -= 必要食料値
        growth_blocked = false
        print("[EconEconomy] 人口増加確定: %d → %d (10人単位 食料値-%d)" % [...])
    else:
        # ロールバック：次の10人手前で停止
        population_float = float(new_unit * 10) - 0.001
        growth_blocked = true
        print("[EconEconomy] 人口増加停止：食料値不足 (必要:%d 現在:%d)" % [...])
```

### 6. 人口維持必要食料値（毎tick消費）

人口を維持するために必要な食料値量：

```text
必要食料値 = ceil(現在人口 / 50)
```

| 現在人口 | 必要食料値 |
|---:|---:|
| 1〜50 | 1 |
| 51〜100 | 2 |

人口維持処理は5秒tick内で `consume_food_for_maintenance()` として行う（Sprint 2 既実装関数を本式に合わせ更新）。

### 7. 食料値が補充されたら再開

```gdscript
if growth_blocked:
    var need: int = int(ceil(population_float / 50.0))
    if food_value >= need:
        growth_blocked = false
```

### 8. 人口変化量ログ用内訳

```gdscript
func _get_population_change_breakdown() -> Dictionary:
    return {
        "population": population_float,
        "growth_rate": _calculate_population_growth_rate(),
        "decline_rate": _calculate_population_decline_rate(),
        "growth_per_sec": population_float * _calculate_population_growth_rate(),
        "decline_per_sec": population_float * _calculate_population_decline_rate(),
        "stage": get_satisfaction_stage(),
        "growth_blocked": growth_blocked,
        "food_required_for_maintain": int(ceil(population_float / 50.0)),
    }
```

### 9. update()への統合

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

## 完了条件

- [ ] `population_float` 初期値が 50.0、上限が 100、下限が 10 に設定される
- [ ] `update_population(delta)` で人口が割合ベースで増減する
- [ ] 人口上限（`population_cap`）で増加が止まる
- [ ] 人口下限（`POPULATION_FLOOR=10`）で減少が止まる
- [ ] 食料値不足時に減少率 +0.0008 が加算される
- [ ] 不満段階で減少率 +0.0008 が加算される
- [ ] 衰退段階で減少率 +0.0020 が加算される
- [ ] 増加・減少率が正しく合算される
- [ ] 10人到達ごとに `ceil(population_float / 50)` 食料値が消費される
- [ ] 食料値不足時に `growth_blocked = true` になり増加が止まる
- [ ] 食料値補充時に `growth_blocked = false` になり増加が再開する
- [ ] 人口変化量の内訳が print ログに出る
- [ ] check_syntax.sh エラー0件

---

## 確定仕様（Final企画書 SSoT）

| 仕様 | 値 |
|---|---|
| 初期人口（内部値） | 50 |
| 初期人口上限 | 100 |
| 人口下限 | 10 |
| 増減方式 | 割合ベース（現在人口 × 増減率） |
| 人口維持必要食料値 | `ceil(現在人口 / 50)` |
| 人口増加確定単位 | 10人 |
| growth_blocked フラグ | 正式フィールド名 |

---

## 非対象（MVP対象外）

- 突撃時の人口減少 → **Sprint 6 で「突撃時に人口は直接減少しない」と再定義**
- 防衛突破による満足値傾きペナルティ
- 突撃で生還したユニットを人口へ戻す処理
- ユニット数 ⇔ 人口 の直接換算

---

## 関連する既存コード

- `EconEconomy.gd:64-164` 既存`update()`構造
- `EconEconomy.gd:166-167` `get_working_population()`
- Sprint 1 で追加した `population_float`, `food_value`, `food_shortage_count`
- Sprint 2 で追加した `consume_food_for_maintenance()`
