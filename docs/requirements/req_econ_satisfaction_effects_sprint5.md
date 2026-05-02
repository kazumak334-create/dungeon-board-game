# Sprint 5: 満足度段階効果の実装

ステータス: 実装リソース（一時）
対応Sprint: Sprint 5
参照設計書:
- docs/econ/population_satisfaction_food_system_design.md §8, §9, §10
- docs/econ/sprint_plan_population_satisfaction_food.md §9
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 5 セクション）
更新日: 2026-05-03

---

## 目的

満足度段階（5段階）が、人口・兵力・建物効率の3軸に補正をかける効果を実装する。

Sprint 3 で既に人口増加/減少速度には満足度段階が反映されているため、本Sprintでは「兵力獲得量・兵力効果・建物効率補正」を満足度段階別に拡張する。

---

## 実装対象クラス・関数

### 拡張対象
- `scripts/econ_mvp/EconEconomy.gd`
  - `get_military_gain_modifier()` 新規追加（兵力獲得量補正）
  - `get_military_effect_modifier()` 新規追加（兵力効果補正）
  - `get_building_efficiency_modifier()` 新規追加（建物効率補正）
  - `building_efficiency_modifier: float` の動的更新
  - 既存 `get_happiness_production_modifier()` を5段階対応へ拡張（後方互換維持）
  - 既存 `get_happiness_military_modifier()` を5段階対応へ拡張（または兵力獲得補正側へ統合）
  - Sprint 3 の `_calculate_population_growth_rate()` に「繁栄時 +0.05」「衰退・不満時 0」反映済み
  - Sprint 3 の `_calculate_population_decline_rate()` に「衰退時 -0.10」「不満時 -0.04」反映済み

---

## 仕様

### 1. 満足度段階別効果テーブル

| 段階キー | 人口増加 | 人口減少 | 兵力獲得量 | 兵力効果 | 建物効率 |
|---|---:|---:|---:|---:|---:|
| decline（衰退） | +0.00 | -0.10 | -100% | -20% | -30% |
| dissatisfied（不満） | +0.00 | -0.04 | -20% | -10% | -10% |
| stable（安定） | +0.02 | 0 | ±0% | ±0% | ±0% |
| satisfied（満足） | +0.04 | 0 | +10% | ±0% | +5% |
| prosperity（繁栄） | +0.05 | 0 | +20% | +10% | +10% |

備考：繁栄時は人口増加必要食料値も -1（最低1）→ Sprint 3 で実装済み。

### 2. 兵力獲得量補正（get_military_gain_modifier）

兵舎・訓練所・徴兵所が新たに得る兵力の量にかける倍率。

```gdscript
func get_military_gain_modifier() -> float:
    var stage: String = get_satisfaction_stage()
    match stage:
        "decline": return 0.0       # -100%（兵力獲得なし）
        "dissatisfied": return 0.8  # -20%
        "stable": return 1.0
        "satisfied": return 1.1     # +10%
        "prosperity": return 1.2    # +20%
        _: return 1.0
```

### 3. 兵力効果補正（get_military_effect_modifier）

保有兵力が戦闘・防衛・攻撃力に変換されるときの有効倍率。

```gdscript
func get_military_effect_modifier() -> float:
    var stage: String = get_satisfaction_stage()
    match stage:
        "decline": return 0.8       # -20%
        "dissatisfied": return 0.9  # -10%
        "stable": return 1.0
        "satisfied": return 1.0
        "prosperity": return 1.1    # +10%
        _: return 1.0
```

### 4. 建物効率補正（get_building_efficiency_modifier）

建物出力にかかる全体補正。MVPでは「資源生産（SAWMILL/MINE/WORKSHOP/VILLAGE/MILL）」と「食料値生成（DINER）」と「兵力獲得（BARRACKS）」に適用する。

```gdscript
func get_building_efficiency_modifier() -> float:
    var stage: String = get_satisfaction_stage()
    match stage:
        "decline": return 0.7       # -30%
        "dissatisfied": return 0.9  # -10%
        "stable": return 1.0
        "satisfied": return 1.05    # +5%
        "prosperity": return 1.1    # +10%
        _: return 1.0
```

`building_efficiency_modifier` フィールドはキャッシュ用。`update_satisfaction()` の最後で更新：

```gdscript
building_efficiency_modifier = get_building_efficiency_modifier()
```

### 5. 既存`get_happiness_*_modifier`の扱い

#### get_happiness_production_modifier (既存)

→ 後方互換ラッパーとして `get_building_efficiency_modifier()` を返す。

```gdscript
func get_happiness_production_modifier() -> float:
    return get_building_efficiency_modifier()
```

#### get_happiness_military_modifier (既存)

→ 後方互換ラッパーとして `get_military_gain_modifier()` を返す。

```gdscript
func get_happiness_military_modifier() -> float:
    return get_military_gain_modifier()
```

呼び出し元（`EconEconomy.gd` の Step 1, Step 2）はそのまま動作する。

### 6. 兵力効果補正の適用箇所

`military_power` を「戦闘上の有効値」として参照する箇所で `× get_military_effect_modifier()` を適用する。

MVPで明確な適用ポイント：
- `EconBattle` 内、突撃／防衛で `military_power` を参照する箇所（Sprint 6 で実装される突撃処理と連動）
- 本Sprintでは「ゲッターを用意する」のみで十分。実適用は Sprint 6 / 後続で接続

呼び出し例（参考）：
```gdscript
var effective_power: float = economy.military_power * economy.get_military_effect_modifier()
```

### 7. 建物効率補正の適用範囲

| 建物 | 対象出力 | 適用方法 |
|---|---|---|
| SAWMILL | 木材生産量 | `roundi(2.0 * lv_bonus * get_building_efficiency_modifier())` |
| MINE | 石材生産量 | 同上 |
| WORKSHOP | 硫黄生産量 | 同上 |
| VILLAGE | 食料生産量 | EconBuilding._update_village 内で適用 |
| DINER | 食料値+量 | EconBuilding._update_diner 内で適用 |
| MILL | 小麦+量 | EconBuilding._update_mill 内で適用 |
| BARRACKS | 兵力生成量 | 既存の `mil_mod` を `get_military_gain_modifier()` に統一 |

VILLAGE/DINER/MILL は EconBuilding 側でゲッター呼び出しを追加する。

---

## 実装手順

1. `EconEconomy` に `get_military_gain_modifier()` を追加
2. `EconEconomy` に `get_military_effect_modifier()` を追加
3. `EconEconomy` に `get_building_efficiency_modifier()` を追加
4. 既存 `get_happiness_production_modifier()` をラッパー化
5. 既存 `get_happiness_military_modifier()` をラッパー化
6. `update_satisfaction()` の末尾で `building_efficiency_modifier = get_building_efficiency_modifier()` を更新
7. `EconBuilding._update_village()` の食料生産量に `economy.get_building_efficiency_modifier()` を乗算
8. `EconBuilding._update_diner()`, `_update_mill()` の出力に `economy.get_building_efficiency_modifier()` を乗算
9. 5秒tickで段階別の補正値を print
   ```
   print("[EconEconomy] stage=%s mil_gain=%.2f mil_effect=%.2f bld_eff=%.2f" % [...])
   ```
10. `bash check_syntax.sh` 実行

---

## 完了条件

- [ ] `get_military_gain_modifier()` が5段階で正しい値を返す（0.0/0.8/1.0/1.1/1.2）
- [ ] `get_military_effect_modifier()` が5段階で正しい値を返す（0.8/0.9/1.0/1.0/1.1）
- [ ] `get_building_efficiency_modifier()` が5段階で正しい値を返す（0.7/0.9/1.0/1.05/1.1）
- [ ] `building_efficiency_modifier` フィールドが `update_satisfaction` で更新される
- [ ] BARRACKS 兵力生成量が `get_military_gain_modifier()` の影響を受ける
- [ ] SAWMILL/MINE/WORKSHOP の資源生産量が `get_building_efficiency_modifier()` の影響を受ける
- [ ] VILLAGE/DINER/MILL の出力が `get_building_efficiency_modifier()` の影響を受ける
- [ ] 既存の `get_happiness_production_modifier()` / `get_happiness_military_modifier()` が後方互換ラッパーとして動く
- [ ] 5段階別補正値がデバッグprintで確認できる
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- Sprint 3 で人口増加/減少の段階別効果は実装済み。本Sprintでは触らない
- 兵力効果補正の戦闘適用は Sprint 6 と連動。本Sprintではゲッターのみ用意でも完了扱い
- 建物効率補正は roundi の前に乗算する（小数誤差対策）
- 食堂は満足値傾きに影響しないが、出力（食料値+2）には建物効率補正をかける（仕様の差異に注意）
- 衰退時の兵力獲得量「-100%（兵力獲得なし）」は 0.0倍として実装。負値にしない

---

## 関連する既存コード

- `EconEconomy.gd:230-252` 既存 `get_happiness_*_modifier`（ラッパー化対象）
- `EconEconomy.gd:101-115` BARRACKS生成処理（mil_mod適用箇所）
- `EconEconomy.gd:80-94` SAWMILL/MINE/WORKSHOP生産処理（prod_mod適用箇所）
- `EconBuilding.gd:255-262` `_update_village`（建物効率補正追加箇所）
- Sprint 2 で実装した `_update_diner` / `_update_mill`
- Sprint 4 で実装した `update_satisfaction(delta)`
