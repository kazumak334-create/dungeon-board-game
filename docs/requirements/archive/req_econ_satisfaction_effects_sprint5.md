STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# Sprint 5: 建物効率（発動間隔補正方式）要件定義書（更新版 2026-05-03）

ステータス: 実装リソース（一時）
対応Sprint: Sprint 5
参照Final企画書: 建物効率Final企画書（SSoT）
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 5 セクション）
更新日: 2026-05-03

---

## 対応状況
- Final企画書準拠：✅

---

## ⚠️ 重大変更

**建物効率は出力量補正ではなく、発動間隔補正に置き換える（実装方式の根本変更）。**

| 項目 | 旧（参考設計） | 新（Final企画書） |
|---|---|---|
| 補正対象 | 出力量（`× 倍率`） | **発動間隔**（タイマー閾値の短縮/延長） |
| 補正式 | `output × efficiency_modifier` | **`補正後発動間隔 = 基礎発動間隔 / (1 + 建物効率補正)`** |
| 適用対象 | 全資源生産・食料・兵力 | **採取・加工・食料値・兵力獲得施設のみ** |
| 非適用対象 | （明確化なし） | **住宅・常時補正施設は非適用**（明示） |
| 段階変化時の挙動 | 出力倍率のみ変動 | **タイマー進捗率を維持して発動間隔を再計算**（Final企画書で明記） |

---

## 実装対象

### 拡張対象クラス
- `scripts/econ_mvp/EconEconomy.gd`
  - `get_building_efficiency_modifier()` 新規追加（補正値そのもの）
  - `get_military_gain_modifier()` 新規追加（兵力獲得量補正）
  - `get_military_effect_modifier()` 新規追加（兵力効果補正）
  - 既存 `get_happiness_production_modifier()` を後方互換ラッパー化

- `scripts/econ_mvp/EconBuilding.gd`
  - 各 `_update_xxx` の発動間隔タイマーを「補正後発動間隔」に対応させる
  - 段階変化検知時にタイマー進捗率を維持しつつ閾値を再計算するロジックを追加

---

## 実装詳細

### 1. 満足度段階別効果テーブル

| 段階キー | 兵力獲得量 | 兵力効果 | **建物効率補正** |
|---|---:|---:|---:|
| decline（衰退） | -100% | -20% | **-0.30**（発動間隔 1.43倍） |
| dissatisfied（不満） | -20% | -10% | **-0.10**（発動間隔 1.11倍） |
| stable（安定） | ±0% | ±0% | **+0.00**（基礎値） |
| satisfied（満足） | +10% | ±0% | **+0.05**（発動間隔 0.95倍） |
| prosperity（繁栄） | +20% | +10% | **+0.10**（発動間隔 0.91倍） |

### 2. 建物効率補正ゲッター

```gdscript
func get_building_efficiency_modifier() -> float:
    var stage: String = get_satisfaction_stage()
    match stage:
        "decline":      return -0.30
        "dissatisfied": return -0.10
        "stable":       return 0.0
        "satisfied":    return 0.05
        "prosperity":   return 0.10
        _: return 0.0
```

注意：旧仕様（倍率 0.7〜1.1）から **加算値（-0.30〜+0.10）** に意味が変わっている。

### 3. 発動間隔の補正式

```text
補正後発動間隔 = 基礎発動間隔 / (1 + 建物効率補正)
```

| 段階 | 補正値 | 1 + 補正 | 補正後発動間隔（基礎10秒の例） |
|---|---:|---:|---:|
| decline | -0.30 | 0.70 | 10 / 0.70 ≈ 14.29秒 |
| dissatisfied | -0.10 | 0.90 | 10 / 0.90 ≈ 11.11秒 |
| stable | 0.00 | 1.00 | 10秒 |
| satisfied | +0.05 | 1.05 | 10 / 1.05 ≈ 9.52秒 |
| prosperity | +0.10 | 1.10 | 10 / 1.10 ≈ 9.09秒 |

### 4. 適用対象

#### 適用対象（発動間隔が補正される）
| 建物 | 基礎発動間隔 | 出力 |
|---|---|---|
| SAWMILL（森小屋） | 既存値 | 木 |
| MINE（採掘所） | 既存値 | 石 |
| WORKSHOP（加工場） | 既存値 | 硫黄 |
| MILL（製粉所） | 既存値 | 小麦+ |
| VILLAGE（農村） | 既存値 | 食料 |
| DINER（食堂） | 既存値 | 食料値 |
| BARRACKS（兵舎） | 既存値 | 兵力 |

#### 非適用対象（補正なし・固定挙動）
| 建物 | 理由 |
|---|---|
| HOUSE（住宅） | 人口上限提供は常時効果。発動間隔がない |
| PLAZA（広場） | 満足度供給は常時補正。発動間隔がない |
| TRADE_POST（交換所/市場） | 常時補正施設として扱う |

### 5. 段階変化時のタイマー進捗率維持

満足度段階が変化したタイミングで、各建物のタイマーは「進捗率」を維持して新しい閾値に再マッピングする。

```text
進捗率 = current_timer / old_interval
new_timer = 進捗率 × new_interval
```

#### EconBuilding 側の実装イメージ

```gdscript
# 各建物の _update_xxx 内
var base_interval: float = BUILDING_BASE_INTERVAL[building_type]
var efficiency: float = economy.get_building_efficiency_modifier()
var current_interval: float = base_interval / (1.0 + efficiency)

# 段階変化検知
if abs(current_interval - _last_interval) > 0.001:
    var progress: float = _timer / _last_interval if _last_interval > 0.0 else 0.0
    _timer = progress * current_interval
    _last_interval = current_interval

_timer += delta
if _timer >= current_interval:
    _timer -= current_interval
    _emit_output()
```

各建物に `_last_interval: float` フィールドを追加して直前の発動間隔を保持する。

### 6. 兵力獲得量補正（出力量補正・別軸）

兵力獲得は発動間隔補正とは別に、出力量倍率も持つ。

```gdscript
func get_military_gain_modifier() -> float:
    var stage: String = get_satisfaction_stage()
    match stage:
        "decline":      return 0.0   # -100%（兵力獲得なし）
        "dissatisfied": return 0.8   # -20%
        "stable":       return 1.0
        "satisfied":    return 1.1   # +10%
        "prosperity":   return 1.2   # +20%
        _: return 1.0
```

BARRACKS は発動間隔補正＋兵力獲得量補正の両方を受ける。

### 7. 兵力効果補正

```gdscript
func get_military_effect_modifier() -> float:
    var stage: String = get_satisfaction_stage()
    match stage:
        "decline":      return 0.8
        "dissatisfied": return 0.9
        "stable":       return 1.0
        "satisfied":    return 1.0
        "prosperity":   return 1.1
        _: return 1.0
```

戦闘時に `military_power × get_military_effect_modifier()` で適用。Sprint 6 で接続。

### 8. 既存 `get_happiness_*_modifier` の扱い

旧仕様の倍率(0.7〜1.1)を返していたゲッターは、Sprint 5 の方式変更により**役割が変わる**。

```gdscript
# 旧 happiness_production_modifier（倍率方式）→ 廃止予定
# 既存呼び出し元は発動間隔方式に置き換える
func get_happiness_production_modifier() -> float:
    push_warning("[EconEconomy] get_happiness_production_modifier は廃止予定。発動間隔方式へ移行")
    # 既存呼び出し元保護のため、概算倍率を返す（出力量補正としての意味は薄い）
    return 1.0 + get_building_efficiency_modifier()

func get_happiness_military_modifier() -> float:
    return get_military_gain_modifier()
```

呼び出し元（`EconEconomy.gd` のSAWMILL/MINE/WORKSHOP出力）は **roundi乗算ではなく発動間隔ベース** に書き換える。

---

## 完了条件

- [ ] `get_building_efficiency_modifier()` が5段階で正しい値を返す（-0.30/-0.10/0/+0.05/+0.10）
- [ ] `get_military_gain_modifier()` が5段階で正しい値を返す（0.0/0.8/1.0/1.1/1.2）
- [ ] `get_military_effect_modifier()` が5段階で正しい値を返す（0.8/0.9/1.0/1.0/1.1）
- [ ] 採取・加工・食料・兵力獲得建物の発動間隔が `基礎間隔 / (1+補正)` で算出される
- [ ] HOUSE/PLAZA/TRADE_POST には発動間隔補正が適用されない
- [ ] 満足度段階変化時にタイマー進捗率が維持される（出力タイミングが急変しない）
- [ ] BARRACKS は発動間隔補正と兵力獲得量補正の両方を受ける
- [ ] check_syntax.sh エラー0件

---

## 確定仕様（Final企画書 SSoT）

| 仕様 | 値 |
|---|---|
| 補正方式 | 発動間隔補正（出力量補正ではない） |
| 補正式 | `補正後発動間隔 = 基礎発動間隔 / (1 + 建物効率補正)` |
| 補正値（5段階） | -0.30 / -0.10 / 0 / +0.05 / +0.10 |
| 適用対象 | 採取・加工・食料値・兵力獲得施設 |
| 非適用対象 | 住宅・常時補正施設 |
| 段階変化時 | タイマー進捗率を維持して再計算 |

---

## 非対象（MVP対象外）

- 建物個別の補正値カスタマイズ（全建物共通の段階補正のみ）
- 建物効率の上下限値（-0.30 / +0.10 が現状の最大幅）
- 建物アップグレードによる発動間隔短縮（既存 lv_bonus とは別概念）

---

## 関連する既存コード

- `EconEconomy.gd:230-252` 既存 `get_happiness_*_modifier`
- `EconEconomy.gd:80-94` SAWMILL/MINE/WORKSHOP 生産処理（発動間隔方式へ書き換え）
- `EconEconomy.gd:101-115` BARRACKS 生成処理（発動間隔＋出力量の二重補正）
- `EconBuilding.gd` 各 `_update_xxx`（_last_interval 追加・進捗率維持実装）
- Sprint 4 で実装した `update_satisfaction(delta)`
