STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# Sprint 4: 満足度システム 要件定義書（更新版 2026-05-03）

ステータス: 実装リソース（一時）
対応Sprint: Sprint 4
参照Final企画書: 満足度システムFinal企画書（SSoT）
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 4 セクション）
更新日: 2026-05-03

---

## 対応状況
- Final企画書準拠：✅

---

## ⚠️ 重大変更

Final企画書を SSoT として、以下の項目が変更・新規追加された。

| 項目 | 旧（参考設計） | 新（Final企画書） |
|---|---|---|
| 初期満足値 | 50% | **60%** |
| 基礎満足傾き | 0.0%/秒 | **+0.03%/秒** |
| 人口規模影響 | 1〜10人台のテーブル | **内部人口スケール（10〜100）に対応した新テーブル** |
| 人口変化量影響 | `-1.0 × max(0, 増加-減少)` | **`max(0, 人口増加速度) × -0.2`** |
| 食料不足ペナルティ | カウント × 0.20%/秒 | **カウント × 0.50%/秒** |
| 建築物影響 | PLAZA/TRADE_POST 等の固定値 | **建築物影響は受け口のみ用意し、具体値は建物側から注入** |

---

## 実装対象

### 拡張対象クラス
- `scripts/econ_mvp/EconEconomy.gd`
  - `update_satisfaction(delta)` 新規追加（毎フレーム満足値更新）
  - `_calculate_satisfaction_slope()` 新規追加（傾き合算）
  - `_get_population_scale_influence()` 新規追加
  - `_get_population_growth_influence()` 新規追加
  - `_get_building_satisfaction_influence(buildings)` 新規追加（受け口のみ）
  - `_get_food_shortage_penalty()` 新規追加
  - `_get_satisfaction_slope_breakdown()` 新規追加（ログ用辞書）
  - 既存 `satisfaction_value` 初期値を 60.0 に変更
  - `update()` の毎フレーム部に `update_satisfaction(delta)` を追加

---

## 実装詳細

### 1. 初期値

```gdscript
var satisfaction_value: float = 60.0     # 初期満足値 60%
var satisfaction_slope: float = 0.0
var satisfaction_stage: String = "satisfied"  # 60%は satisfied 段階
```

### 2. 満足値の更新式

```text
satisfaction_value = clamp(satisfaction_value + satisfaction_slope * delta, 0.0, 100.0)
```

### 3. 満足値傾きの計算式

```text
satisfaction_slope =
    base_slope
  + population_scale_influence
  + population_growth_influence
  + building_influence
  - food_shortage_penalty
```

### 4. 基礎傾き（base_slope）

```text
base_slope = +0.03 %/秒  ← Final企画書で確定
```

### 5. 人口規模影響（内部人口スケール対応）

`floor(population_float)` の値で判定。Sprint 3 の新スケール（10〜100）に合わせて再定義する。

| 現在人口 | 影響値（%/秒） |
|---:|---:|
| 10〜20 | +0.02 |
| 21〜40 | 0.00 |
| 41〜60 | -0.03 |
| 61〜80 | -0.06 |
| 81〜100 | -0.10 |

```gdscript
func _get_population_scale_influence() -> float:
    var pop: int = int(floor(population_float))
    if pop <= 20: return 0.02
    if pop <= 40: return 0.0
    if pop <= 60: return -0.03
    if pop <= 80: return -0.06
    return -0.10
```

### 6. 人口変化量影響（Final企画書の新式）

```text
人口変化量影響 = max(0, 人口増加速度) × -0.2
```

人口増加速度は Sprint 3 の `_calculate_population_growth_rate() × population_float`（人/秒換算）を用いる。

```gdscript
func _get_population_growth_influence() -> float:
    var growth_rate: float = _calculate_population_growth_rate()
    var growth_per_sec: float = population_float * growth_rate
    if growth_per_sec <= 0.0:
        return 0.0
    return -0.2 * growth_per_sec
```

例：人口50・繁栄段階（増加0.05人/秒） → 影響 -0.01%/秒

### 7. 建築物影響（受け口のみ）

Final企画書では「建築物影響は受け口のみ」と明記された。具体値は建物側から注入する形に変更する。

```gdscript
# 受け口：建物側から呼び出す累積バッファ
var _building_satisfaction_buffer: float = 0.0

# 建物側からの注入API（Sprint 5以降で具体的な建物が呼ぶ）
func add_building_satisfaction_influence(value: float) -> void:
    _building_satisfaction_buffer += value

func _get_building_satisfaction_influence(buildings: Array) -> float:
    return _building_satisfaction_buffer
```

注意：
- MVP 本Sprintでは建物側から具体的な値を注入しない（受け口のみ）
- Sprint 5 以降で各建物（PLAZA/TRADE_POST 等）が個別に注入する設計に切り替える
- `_building_satisfaction_buffer` は毎tick冒頭でリセット、または建物update内で再計算する仕組みは Sprint 5 で詳細化

### 8. 食料不足ペナルティ（強化）

```text
食料不足ペナルティ = food_shortage_count × 0.50 %/秒
```

```gdscript
func _get_food_shortage_penalty() -> float:
    return float(food_shortage_count) * 0.50
```

例：食料不足カウント2 → ペナルティ1.00 → 満足値傾き-1.00%/秒

### 9. 満足度段階

Sprint 1 で実装済み `get_satisfaction_stage()` をそのまま利用。

| 満足値 | 段階キー |
|---:|---|
| 0〜19% | decline |
| 20〜39% | dissatisfied |
| 40〜59% | stable |
| 60〜79% | satisfied |
| 80〜100% | prosperity |

### 10. 満足値傾きログ用内訳

```gdscript
func _get_satisfaction_slope_breakdown(buildings: Array) -> Dictionary:
    return {
        "base": 0.03,
        "population_scale": _get_population_scale_influence(),
        "population_growth": _get_population_growth_influence(),
        "building": _get_building_satisfaction_influence(buildings),
        "food_shortage_penalty": _get_food_shortage_penalty(),
        "total": _calculate_satisfaction_slope(buildings),
    }
```

### 11. update_satisfaction の構造

```gdscript
func update_satisfaction(delta: float) -> void:
    satisfaction_slope = _calculate_satisfaction_slope(buildings)
    satisfaction_value = clamp(satisfaction_value + satisfaction_slope * delta, 0.0, 100.0)
    satisfaction_stage = get_satisfaction_stage()
```

### 12. update()への統合

```gdscript
func update(delta: float, total_unit_count: int) -> void:
    # 毎フレーム処理
    update_satisfaction(delta)  # 先に満足度更新
    update_population(delta)    # 人口更新（満足度段階を参照）
    # ...
```

### 13. 既存`get_happiness_state()`との後方互換

```gdscript
func get_happiness_state() -> String:
    var s: String = get_satisfaction_stage()
    match s:
        "prosperity", "satisfied": return "high"
        "stable": return "normal"
        "dissatisfied": return "dissatisfied"
        "decline": return "danger"
    return "normal"
```

---

## 完了条件

- [ ] `satisfaction_value` 初期値が 60.0 になっている
- [ ] `satisfaction_value` がリアルタイムに変化する
- [ ] `satisfaction_slope` が複数要因の合算で算出される
- [ ] 基礎傾き +0.03%/秒 が常時加算される
- [ ] 人口規模影響が新スケール（10〜100）の5段階で正しく反映される
- [ ] 人口変化量影響が `max(0, 増加速度) × -0.2` で算出される
- [ ] 建築物影響の受け口（`add_building_satisfaction_influence`）が用意されている
- [ ] 食料不足ペナルティが `food_shortage_count × 0.50` で減算される
- [ ] `satisfaction_value` が 0〜100 にクランプされる
- [ ] `get_satisfaction_stage()` が5段階を返す
- [ ] 満足値傾きの内訳が print ログに出る
- [ ] check_syntax.sh エラー0件

---

## 確定仕様（Final企画書 SSoT）

| 仕様 | 値 |
|---|---|
| 初期満足値 | 60% |
| 基礎満足傾き | +0.03%/秒 |
| 人口規模影響テーブル | 10-20:+0.02 / 21-40:0 / 41-60:-0.03 / 61-80:-0.06 / 81-100:-0.10 |
| 人口変化量影響 | max(0, 人口増加速度) × -0.2 |
| 食料不足ペナルティ係数 | 0.50%/秒（カウント1あたり） |
| 建築物影響 | 受け口のみ（建物側注入） |

---

## 非対象（MVP対象外）

- 建物側からの満足度注入の具体実装（Sprint 5 以降）
- レストラン（RESTAURANT）／香辛料市場（SPICE_MARKET）の満足度貢献
- 突撃・防衛突破による満足値傾きペナルティ

---

## 関連する既存コード

- `EconEconomy.gd:193-201` 既存 `get_happiness_state()`（後方互換ラッパー化）
- `EconEconomy.gd:230-252` 既存 `get_happiness_*_modifier`（Sprint 5 で5段階対応）
- Sprint 1 で追加した `satisfaction_value`, `satisfaction_slope`, `satisfaction_stage`, `food_shortage_count`
- Sprint 3 の `_calculate_population_growth_rate()`（人口変化量影響で参照）
