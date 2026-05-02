# Sprint 4: 満足度システムの実装

ステータス: 実装リソース（一時）
対応Sprint: Sprint 4
参照設計書:
- docs/econ/population_satisfaction_food_system_design.md §6, §7
- docs/econ/sprint_plan_population_satisfaction_food.md §8
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 4 セクション）
更新日: 2026-05-03

---

## 目的

満足値（0〜100%）と満足値傾き（%/秒）をリアルタイム更新し、5段階の満足度段階を算出するシステムを実装する。

満足値傾きは複数要因（基礎・人口規模・人口変化量・建築物・食料不足ペナルティ）の合算で算出する。

---

## 実装対象クラス・関数

### 拡張対象
- `scripts/econ_mvp/EconEconomy.gd`
  - `update_satisfaction(delta)` 新規追加（毎フレーム満足値更新）
  - `_calculate_satisfaction_slope()` 新規追加（傾き合算）
  - `_get_population_scale_influence()` 新規追加
  - `_get_population_growth_influence()` 新規追加
  - `_get_building_satisfaction_influence(buildings: Array)` 新規追加
  - `_get_food_shortage_penalty()` 新規追加
  - `_get_satisfaction_slope_breakdown()` 新規追加（ログ用辞書）
  - `update()` 内に `update_satisfaction(delta)` を追加（毎フレーム部分）

---

## 仕様

### 1. 満足値の更新式

```text
satisfaction_value = clamp(satisfaction_value + satisfaction_slope * delta, 0.0, 100.0)
```

毎フレーム delta 積算で更新する。

### 2. 満足値傾きの計算式

```text
satisfaction_slope =
  base_slope
  + population_scale_influence
  + population_growth_influence
  + building_influence
  - food_shortage_penalty
```

### 3. 基礎傾き

```text
base_slope = 0.0 %/秒
```

（MVP固定値）

### 4. 人口規模影響

`floor(population_float)` の値で判定：

| 現在人口 | 影響値（%/秒） |
|---:|---:|
| 1〜2 | +0.02 |
| 3〜4 | 0.00 |
| 5〜6 | -0.03 |
| 7〜9 | -0.06 |
| 10以上 | -0.10 |

```gdscript
func _get_population_scale_influence() -> float:
    var pop: int = int(floor(population_float))
    if pop <= 2: return 0.02
    if pop <= 4: return 0.0
    if pop <= 6: return -0.03
    if pop <= 9: return -0.06
    return -0.10
```

### 5. 人口変化量影響

```text
人口変化量影響 = -1.0 × max(0, 人口増加要因合計 - 人口減少要因合計)
```

- 人口変化量が正（増加中）の場合のみマイナス影響
- 人口減少中はMVP補正なし（0.0）

```gdscript
func _get_population_growth_influence() -> float:
    var growth: float = _calculate_population_growth_rate()
    var decline: float = _calculate_population_decline_rate()
    var net: float = growth - decline
    if net <= 0.0:
        return 0.0
    return -1.0 * net
```

例：人口変化量+0.04 → 影響 -0.04%/秒

### 6. 建築物影響

| 建物 | 影響値（%/秒） | 条件 |
|---|---:|---|
| 広場（PLAZA） | +0.05 | 稼働中（`is_built && is_alive`） |
| レストラン（RESTAURANT） | +0.10 | 稼働中。MVPで未実装の場合スキップ |
| 市場（TRADE_POST） | +0.05 | 稼働中 |
| 香辛料市場（SPICE_MARKET） | +0.15 | 香辛料タグ付きパネル上のみ。MVPで未実装の場合スキップ |

食堂（DINER）は満足値傾きに直接影響しない。

```gdscript
func _get_building_satisfaction_influence(buildings: Array) -> float:
    var total: float = 0.0
    for b in buildings:
        if not b.is_alive or not b.is_built:
            continue
        match b.building_type:
            EconBuilding.BuildingType.PLAZA:
                total += 0.05
            EconBuilding.BuildingType.TRADE_POST:
                total += 0.05
            # RESTAURANT / SPICE_MARKET は将来拡張
    return total
```

### 7. 食料不足ペナルティ

```text
食料不足ペナルティ = food_shortage_count × 0.20 %/秒
```

満足値傾きの式ではマイナス項目として減算。

```gdscript
func _get_food_shortage_penalty() -> float:
    return float(food_shortage_count) * 0.20
```

例：食料不足カウント2 → ペナルティ0.40 → 満足値傾き-0.40%/秒

### 8. 満足度段階

Sprint 1 で実装済み `get_satisfaction_stage()` をそのまま利用。

| 満足値 | 段階キー |
|---:|---|
| 0〜19% | decline |
| 20〜39% | dissatisfied |
| 40〜59% | stable |
| 60〜79% | satisfied |
| 80〜100% | prosperity |

### 9. 満足値傾きログ用内訳

```gdscript
func _get_satisfaction_slope_breakdown(buildings: Array) -> Dictionary:
    return {
        "base": 0.0,
        "population_scale": _get_population_scale_influence(),
        "population_growth": _get_population_growth_influence(),
        "building": _get_building_satisfaction_influence(buildings),
        "food_shortage_penalty": _get_food_shortage_penalty(),
        "total": _calculate_satisfaction_slope(buildings),
    }
```

ログ出力はSprint 8で `LogManager` に接続。本Sprintでは`print`ログ。

### 10. update_satisfaction の構造

```gdscript
func update_satisfaction(delta: float) -> void:
    satisfaction_slope = _calculate_satisfaction_slope(buildings)
    satisfaction_value = clamp(satisfaction_value + satisfaction_slope * delta, 0.0, 100.0)
    satisfaction_stage = get_satisfaction_stage()
```

### 11. update()への統合

`EconEconomy.update(delta, total_units)` の毎フレーム部（Sprint 3で分離した部分）に追加：

```gdscript
func update(delta: float, total_unit_count: int) -> void:
    # 毎フレーム処理
    update_satisfaction(delta)  # ← 追加
    update_population(delta)

    # 5秒tick処理
    _tick_timer += delta
    if _tick_timer < TICK_INTERVAL:
        return
    # ... 以下既存
```

注：`update_satisfaction` を `update_population` より先に呼ぶ。理由：満足度段階が人口増加要因に影響するため、先に満足値を更新する。

### 12. 既存`satisfaction: int`との関係

- 既存`satisfaction: int`は廃止予定。本Sprintで`satisfaction_value: float`へ移行
- `get_happiness_state()`（4段階）も廃止予定。`get_satisfaction_stage()`（5段階）へ統一
- ただし他クラスからの呼び出しが残る場合は後方互換ラッパーを残す：

```gdscript
func get_happiness_state() -> String:
    # 後方互換：4段階 → 5段階マッピング
    var s: String = get_satisfaction_stage()
    match s:
        "prosperity", "satisfied": return "high"
        "stable": return "normal"
        "dissatisfied": return "dissatisfied"
        "decline": return "danger"
    return "normal"
```

`satisfaction = int(satisfaction_value)` も同期書き込みで残す。

---

## 実装手順

1. `_calculate_satisfaction_slope(buildings: Array) -> float` を実装
2. `_get_population_scale_influence()` を実装
3. `_get_population_growth_influence()` を実装
4. `_get_building_satisfaction_influence(buildings)` を実装
5. `_get_food_shortage_penalty()` を実装
6. `update_satisfaction(delta)` を実装
7. `update()` 毎フレーム部に `update_satisfaction(delta)` 追加（`update_population`より前）
8. 既存 `get_happiness_state()` を5段階ベースに書き直し（後方互換維持）
9. 5秒tickで `print("[EconEconomy] satisfaction=%.1f slope=%+.3f stage=%s breakdown=%s" % ...)`
10. `bash check_syntax.sh` 実行

---

## 完了条件

- [ ] `satisfaction_value` がリアルタイムに変化する
- [ ] `satisfaction_slope` が複数要因の合算で算出される
- [ ] 人口規模影響が人口値帯に応じて正しく反映される（5段階）
- [ ] 人口変化量影響が`-1.0 × max(0, 増加-減少)`で算出される
- [ ] 建築物影響（PLAZA/TRADE_POST）が稼働中の建物分加算される
- [ ] 食料不足ペナルティが`food_shortage_count × 0.20`で減算される
- [ ] `satisfaction_value` が0〜100にクランプされる
- [ ] `get_satisfaction_stage()` が5段階を返す
- [ ] `get_happiness_state()` 後方互換ラッパーが既存呼び出し元で正しく動く
- [ ] 満足値傾きの内訳がprintログに出る
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- 食堂（DINER）は満足値傾きに直接影響させない（設計書 §6.9）
- レストラン（RESTAURANT）／香辛料市場（SPICE_MARKET）はMVP未実装。建物enum追加されたときに有効化する
- `satisfaction_value` は float、UIや既存コード参照のため `satisfaction: int` も同期書き込み
- 5段階閾値は設計書通り：20/40/60/80（境界は下側に含める：例 20.0は dissatisfied）
- 突撃・防衛突破による満足値傾きペナルティはMVP対象外（設計書 §6.4 「将来拡張枠」）

---

## 関連する既存コード

- `EconEconomy.gd:193-201` 既存`get_happiness_state()`（4段階・置換対象）
- `EconEconomy.gd:230-252` 既存`get_happiness_*_modifier()`（Sprint 5で5段階対応へ拡張）
- Sprint 1 で追加した `satisfaction_value`, `satisfaction_slope`, `satisfaction_stage`, `food_shortage_count`
- Sprint 2 で `food_shortage_count` の増減
- Sprint 3 の `_calculate_population_growth_rate()` / `_calculate_population_decline_rate()`（人口変化量影響で参照）
