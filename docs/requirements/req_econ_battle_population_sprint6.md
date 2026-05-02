# Sprint 6: 戦闘連動（突撃・防衛による人口減少）

ステータス: 実装リソース（一時）
対応Sprint: Sprint 6
参照設計書:
- docs/econ/population_satisfaction_food_system_design.md §5
- docs/econ/sprint_plan_population_satisfaction_food.md §10
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 6 セクション）
更新日: 2026-05-03

---

## 目的

戦闘行動・防衛失敗が都市人口に直接影響するようにする。

- 突撃：送り出したユニット数ぶん人口を即時減少
- 防衛突破：防衛を突破した敵ユニット数ぶん人口を即時減少

人口変化量（リアルタイム増減）とは別枠の「即時処理」として実装する。

---

## 実装対象クラス・関数

### 拡張対象
- `scripts/econ_mvp/EconEconomy.gd`
  - `apply_charge_population_loss(unit_count: int)` 新規追加（突撃時の即時減少）
  - `apply_defense_breakthrough_loss(enemy_count: int)` 新規追加（防衛突破時の即時減少）
  - `get_max_chargeable_units()` 新規追加（突撃可能ユニット数の上限取得）

- `scripts/econ_mvp/EconBattle.gd`
  - 突撃発火箇所で `economy.apply_charge_population_loss(unit_count)` を呼ぶ
  - 防衛突破判定箇所で `economy.apply_defense_breakthrough_loss(enemy_count)` を呼ぶ
  - 突撃判定で `economy.get_max_chargeable_units()` を上限として使用

---

## 仕様

### 1. 突撃による人口消費

```text
- 突撃ユニット1体につき人口-1
- 人口は最低1を下回らない
- 突撃可能ユニット数は floor(population_float) - 1 を上限とする
- 即時処理（人口変化量とは別枠）
```

#### apply_charge_population_loss

```gdscript
func apply_charge_population_loss(unit_count: int) -> void:
    if unit_count <= 0:
        return
    var loss: int = unit_count
    var before: float = population_float
    population_float = max(1.0, population_float - float(loss))
    var actual: float = before - population_float
    print("[EconEconomy] 突撃人口消費: -%.1f (要求:%d, before:%.2f → after:%.2f)" % [actual, loss, before, population_float])
```

#### get_max_chargeable_units

```gdscript
func get_max_chargeable_units() -> int:
    return max(0, int(floor(population_float)) - 1)
```

### 2. 防衛突破による人口被害

```text
- 防衛突破した敵ユニット1体につき人口-1
- 人口は最低1を下回らない
- 即時処理（人口変化量とは別枠）
```

#### apply_defense_breakthrough_loss

```gdscript
func apply_defense_breakthrough_loss(enemy_count: int) -> void:
    if enemy_count <= 0:
        return
    var loss: int = enemy_count
    var before: float = population_float
    population_float = max(1.0, population_float - float(loss))
    var actual: float = before - population_float
    print("[EconEconomy] 防衛突破人口被害: -%.1f (敵:%d, before:%.2f → after:%.2f)" % [actual, loss, before, population_float])
```

### 3. EconBattle 側の接続

#### 3.1 突撃発火箇所

EconBattle で「突撃」処理が発生する関数を特定し、ユニット数を集計後に呼び出す：

```gdscript
# 例：突撃処理関数内
func _execute_charge(unit_count: int) -> void:
    var max_chargeable: int = economy.get_max_chargeable_units()
    var actual_count: int = min(unit_count, max_chargeable)
    if actual_count <= 0:
        print("[EconBattle] 突撃不可：人口不足（pop=%d）" % int(floor(economy.population_float)))
        return
    # 既存の突撃ロジック...
    economy.apply_charge_population_loss(actual_count)
```

注：現状 EconBattle に「突撃」概念があるか要確認。なければ Sprint 6 で「突撃トリガー」を追加する必要あり。MVPでは以下のいずれか：
- 既に存在するなら呼び出しのみ追加
- 存在しないなら：「military_power が一定以上に達したときに自動突撃」等の最小トリガーを追加（仕様要確認・別タスク）

#### 3.2 防衛突破判定箇所

敵ユニットが BASE に接触したタイミングで、接触した敵ユニット数ぶん人口を消費する処理を実装する。

現在 EconBattle.gd には敵到達カウント処理が未実装のため、以下のいずれかの実装パターンで対応：

- **パターンA（推奨）**：`EconBattle.register_enemy_reach_base()` メソッドを新規作成し、敵が BASE に接触した時点で呼び出す
- **パターンB**：`CombatSystem.gd` など別モジュールから敵到達通知を受け取る形にする

Sprint 6 実装時に接続箇所を確定する。

```gdscript
# 例：敵到達カウント（パターンA）
var breakthrough_count: int = 0
for enemy in enemies_reached_base:
    breakthrough_count += 1
if breakthrough_count > 0:
    economy.apply_defense_breakthrough_loss(breakthrough_count)
```

### 4. ログ出力

両処理ともprint出力。Sprint 8 で `LogManager.log_event({"type": "POP_LOSS", ...})` に接続。

```text
[EconEconomy] 突撃人口消費: -3 (人口 8 → 5)
[EconEconomy] 防衛突破人口被害: -2 (人口 7 → 5)
```

---

## 実装手順

1. `EconEconomy` に `apply_charge_population_loss(unit_count: int)` を実装
2. `EconEconomy` に `apply_defense_breakthrough_loss(enemy_count: int)` を実装
3. `EconEconomy` に `get_max_chargeable_units()` を実装
4. `EconBattle` の突撃処理箇所を特定し、`apply_charge_population_loss` を呼ぶ
   - 突撃処理が未実装の場合：仕様確認後、最小トリガーを追加（別チケットでもよい）
5. **敵到達通知の接続箇所を確定する**（パターンA / パターンB の選択）
   - パターンA：`EconBattle.register_enemy_reach_base()` 新規メソッド作成、敵が BASE 接触時に呼ぶ
   - パターンB：`CombatSystem.gd` 等の別モジュールから通知を受け取る形を設計
6. 確定した接続箇所で `apply_defense_breakthrough_loss` を呼ぶ
7. printログを追加
8. `bash check_syntax.sh` 実行

---

## 完了条件

- [ ] 突撃時に `apply_charge_population_loss(n)` が呼ばれ、`population_float` が n 減少する
- [ ] 突撃で `population_float` が 1.0 未満にならない
- [ ] `get_max_chargeable_units()` が `floor(population_float) - 1`（最低0）を返す
- [ ] 突撃ユニット数が上限を超えてリクエストされたとき、上限内に丸められる
- [ ] 防衛突破時に `apply_defense_breakthrough_loss(n)` が呼ばれ、`population_float` が n 減少する
- [ ] 防衛突破で `population_float` が 1.0 未満にならない
- [ ] 即時減少が `update_population` のリアルタイム処理とは独立して動作する（diff計算から除外される）
- [ ] 突撃・防衛人口減少ログが print 出力される
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- 即時減少は `population_float` への直接代入で行う。`_try_confirm_population_growth()` の整数到達判定とは独立処理
- 即時減少時は食料値消費はしない（人口維持処理／人口増加確定処理のみが食料値を使う）
- 突撃ユニット数と兵力（`military_power`）の関係は MVP対象外（設計書 §14.4 残論点）。本Sprintでは「ユニット数」を引数として受け取るのみ
- 防衛突破による満足値傾きペナルティは MVP対象外（設計書 §6.4 「将来拡張枠」）
- EconBattle に「突撃」処理が現状存在しない場合、Sprint 6 範囲外として要件再確認をCEOに依頼する
- 突撃で生還したユニットを人口へ戻すかは MVP対象外（設計書 §14.2 残論点）

---

## 関連する既存コード

- `EconBattle.gd:193-218` BARRACKS関連処理（兵力生成）
- `EconBattle.gd` BASE 関連処理（`_check_victory()` 等は BASE 破壊判定であり、敵到達カウント処理は未実装。Sprint 6 で接続箇所を新規追加する）
- `EconEconomy.gd:362-379` `initialize_v0_2`（`population_float` 初期化）
- Sprint 1 で追加した `population_float`
- Sprint 3 の `update_population(delta)`（即時減少と並行動作）
