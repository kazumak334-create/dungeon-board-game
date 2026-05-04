STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# Sprint 6: 兵数・ユニット変換 要件定義書（更新版 2026-05-03）

ステータス: 実装リソース（一時）
対応Sprint: Sprint 6
参照Final企画書: 兵数・ユニット変換Final企画書（SSoT）
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 6 セクション）
更新日: 2026-05-03

---

## 対応状況
- Final企画書準拠：✅

---

## ⚠️ 重大変更（設計の根本転換）

| 項目 | 旧（参考設計） | 新（Final企画書） |
|---|---|---|
| 突撃時の人口減少 | 突撃ユニット数ぶん人口を即時減少 | **突撃時に人口は直接減少しない** |
| 防衛突破時の人口減少 | 防衛突破した敵ユニット数ぶん減少 | **突破した敵ユニット数ぶん人口が即時減少**（こちらは継続） |
| ユニットと人口の関係 | 1ユニット = 1人口 で換算 | **ユニットと人口を直接換算しない設計** |
| 動員率 | 未定義 | **基礎動員率 8%** |
| 満足度補正 | 未定義 | **0.50〜1.25**（5段階） |

---

## 実装対象

### 拡張対象クラス
- `scripts/econ_mvp/EconEconomy.gd`
  - `apply_defense_breakthrough_loss(enemy_count: int)` 新規追加（防衛突破時のみ）
  - `get_mobilization_rate()` 新規追加（基礎動員率 × 満足度補正）
  - `get_mobilization_modifier()` 新規追加（満足度補正値）
  - `get_max_chargeable_units()` 新規追加（動員率ベースで算出）

- `scripts/econ_mvp/EconBattle.gd`
  - 突撃発火箇所で `economy.get_max_chargeable_units()` を上限として使用
  - **突撃時に `apply_charge_population_loss` を呼ばない**（人口は直接減らない）
  - 防衛突破判定箇所で `economy.apply_defense_breakthrough_loss(enemy_count)` を呼ぶ

### 削除（旧設計）
- `apply_charge_population_loss(unit_count: int)` は **新規追加しない**（旧設計案を破棄）

---

## 実装詳細

### 1. 突撃と人口の関係（ユニット⇔人口は非換算）

```text
- 突撃時に人口は直接減少しない
- 突撃可能ユニット数は「動員率 × 現在人口」で算出
- 突撃後も人口は変化しない
- ユニットと人口は別概念として扱う
```

#### 設計意図

ユニットと人口を直接換算しない理由：
- 都市の人口（市民）と戦闘ユニット（兵士・徴兵兵）を分離
- 突撃で住人が減る違和感を解消
- 動員率を介して「都市規模に応じた動員可能数」を表現

### 2. 基礎動員率と満足度補正

```text
基礎動員率 = 8%
満足度補正 = 0.50〜1.25（5段階）
動員率 = 基礎動員率 × 満足度補正
最大突撃可能ユニット数 = floor(現在人口 × 動員率)
```

#### 満足度補正テーブル

| 段階 | 補正値 | 動員率（8%基礎） |
|---|---:|---:|
| decline（衰退） | 0.50 | 4.0% |
| dissatisfied（不満） | 0.75 | 6.0% |
| stable（安定） | 1.00 | 8.0% |
| satisfied（満足） | 1.10 | 8.8% |
| prosperity（繁栄） | 1.25 | 10.0% |

```gdscript
const MOBILIZATION_BASE_RATE: float = 0.08

func get_mobilization_modifier() -> float:
    var stage: String = get_satisfaction_stage()
    match stage:
        "decline":      return 0.50
        "dissatisfied": return 0.75
        "stable":       return 1.00
        "satisfied":    return 1.10
        "prosperity":   return 1.25
        _: return 1.00

func get_mobilization_rate() -> float:
    return MOBILIZATION_BASE_RATE * get_mobilization_modifier()

func get_max_chargeable_units() -> int:
    var rate: float = get_mobilization_rate()
    return max(0, int(floor(population_float * rate)))
```

例：人口 50・繁栄 → 50 × 0.08 × 1.25 = 5 ユニット可能
例：人口100・衰退 → 100 × 0.08 × 0.50 = 4 ユニット可能

### 3. 防衛突破による人口被害（継続）

```text
- 防衛突破した敵ユニット1体につき人口-1
- 人口は最低 POPULATION_FLOOR(=10) を下回らない
- 即時処理（人口変化量とは別枠）
```

```gdscript
func apply_defense_breakthrough_loss(enemy_count: int) -> void:
    if enemy_count <= 0:
        return
    var loss: int = enemy_count
    var before: float = population_float
    population_float = max(float(POPULATION_FLOOR), population_float - float(loss))
    var actual: float = before - population_float
    print("[EconEconomy] 防衛突破人口被害: -%.1f (敵:%d, before:%.2f → after:%.2f)" % [actual, loss, before, population_float])
```

### 4. EconBattle 側の接続

#### 4.1 突撃発火箇所（人口減少なし）

```gdscript
func _execute_charge(requested_unit_count: int) -> void:
    var max_chargeable: int = economy.get_max_chargeable_units()
    var actual_count: int = min(requested_unit_count, max_chargeable)
    if actual_count <= 0:
        print("[EconBattle] 突撃不可：動員可能ユニット数 0")
        return
    # 突撃ロジック実行（人口は減らさない）
    _spawn_charge_units(actual_count)
    # economy.apply_charge_population_loss(actual_count)  ← 呼ばない
```

#### 4.2 防衛突破判定箇所

```gdscript
# 敵が BASE に到達した数を集計
var breakthrough_count: int = enemies_reached_base.size()
if breakthrough_count > 0:
    economy.apply_defense_breakthrough_loss(breakthrough_count)
```

### 5. ログ出力（Sprint 8 で LogManager に接続）

```text
[EconEconomy] 突撃ユニット送出: 5 (人口=50, 動員率=10.0%)  ← 人口は変わらない
[EconEconomy] 防衛突破人口被害: -2 (人口 50 → 48)
```

---

## 完了条件

- [ ] `apply_charge_population_loss` は実装しない（旧仕様の破棄を確認）
- [ ] 突撃発火時に人口（`population_float`）が変化しないことを確認
- [ ] `get_mobilization_rate()` が `0.08 × satisfaction_modifier` を返す
- [ ] `get_mobilization_modifier()` が5段階で正しい値を返す（0.50/0.75/1.00/1.10/1.25）
- [ ] `get_max_chargeable_units()` が `floor(population_float × mobilization_rate)` を返す
- [ ] 突撃ユニット数が動員上限を超えてリクエストされた場合、上限内に丸められる
- [ ] 防衛突破時に `apply_defense_breakthrough_loss(n)` が呼ばれ、`population_float` が n 減少する
- [ ] 防衛突破で `population_float` が `POPULATION_FLOOR(=10)` 未満にならない
- [ ] 即時減少が `update_population` のリアルタイム処理とは独立して動作する
- [ ] 防衛突破人口減少ログが print 出力される
- [ ] check_syntax.sh エラー0件

---

## 確定仕様（Final企画書 SSoT）

| 仕様 | 値 |
|---|---|
| 突撃時の人口減少 | なし（直接減少しない） |
| 防衛突破時の人口減少 | 突破敵ユニット数ぶん即時減少 |
| ユニット⇔人口換算 | 直接換算しない |
| 基礎動員率 | 8% |
| 満足度補正 | 0.50〜1.25（5段階） |
| 動員率計算式 | 基礎動員率 × 満足度補正 |
| 突撃可能上限 | `floor(population_float × 動員率)` |

---

## 非対象（MVP対象外）

- 突撃で生還したユニットを人口へ戻す処理
- 動員時の食料消費・兵力消費
- 防衛突破時の食料値・建物への被害
- 動員率の建物・カードによる強化

---

## 関連する既存コード

- `EconBattle.gd:193-218` BARRACKS 関連処理
- `EconBattle.gd` BASE 関連処理（敵到達カウント処理は新規追加）
- `EconEconomy.gd:362-379` `initialize_v0_2`（`population_float` 初期化）
- Sprint 1 で追加した `population_float`
- Sprint 3 の `update_population(delta)`（即時減少と並行動作）
- Sprint 4 の `get_satisfaction_stage()`（動員率補正で参照）
