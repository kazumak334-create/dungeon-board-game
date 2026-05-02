# Sprint 2: 食料値システムの実装

ステータス: 実装リソース（一時）
対応Sprint: Sprint 2
参照設計書:
- docs/econ/population_satisfaction_food_system_design.md §3
- docs/econ/sprint_plan_population_satisfaction_food.md §6
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 2 セクション）
更新日: 2026-05-03

---

## 目的

小麦を直接人口に接続せず、「食料値」を経由して人口維持・人口定着に接続する。
食堂・製粉所の建物効果と、人口維持処理（5秒周期）を実装する。

---

## 実装対象クラス・関数

### 拡張対象
- `scripts/econ_mvp/EconEconomy.gd`
  - `consume_food_for_maintenance()` 新規追加（人口維持処理）
  - `add_food(amount: int)` 新規追加
- `scripts/econ_mvp/EconBuilding.gd`
  - `BuildingType` enum に `DINER`（食堂）, `MILL`（製粉所）を追加
  - `BUILD_COSTS`, `BUILD_HP` に追加
  - `_update_diner(delta, economy)` 新規追加
  - `_update_mill(delta, economy)` 新規追加
  - `update()` 内 match に DINER/MILL 分岐追加
- `data/cards_econ.json`
  - `card_diner` を新規追加
  - `card_mill` を新規追加（Sprint 7 で初期デッキ／序盤プールに割り当てる）

---

## 仕様

### 1. 食堂（DINER）

| 項目 | 内容 |
|---|---|
| 分類 | 建物 / 都市ステータス生成施設 |
| 発動トリガー | 周期発動 |
| 発動間隔 | 5.0秒 |
| 通常効果 | 小麦1を消費して食料値+2 |
| 香辛料タグ効果 | 足元パネルに香辛料タグがある場合、食料値+3 |
| 小麦不足時 | 発動しない（ログのみ） |
| HP | 60 |
| コスト | wood:4, stone:2 |

#### 処理フロー（_update_diner）

```text
_diner_timer += delta
if _diner_timer < 5.0: return
_diner_timer -= 5.0

if economy.wheat < 1:
    print("[EconBuilding] DINER: 小麦不足、発動スキップ")
    return

economy.wheat -= 1
economy.resources["wheat"] = economy.wheat

var gain: int = 2
if has_spice_tag(grid_pos):  # 香辛料タグ判定（既存タグシステム不在ならMVPでは常にfalse）
    gain = 3

economy.food_value += gain
print("[EconBuilding] DINER: 小麦-1 食料値+%d (food_value=%d)" % [gain, economy.food_value])
```

香辛料タグ判定について：
- 現状の`EconGrid`に「特殊タグ」フィールドが存在しない場合、MVPでは常に通常効果（+2）とする
- タグシステム実装は別Sprint／別タスク（panel_resource_system_design.md 参照）

### 2. 製粉所（MILL）

| 項目 | 内容 |
|---|---|
| 分類 | 建物 / 加工施設 |
| 発動トリガー | 周期発動 |
| 発動間隔 | 5.0秒 |
| 通常効果 | 小麦1を消費して小麦+2（差し引き+1） |
| 小麦パネル効果 | 足元パネルの小麦値が3以上なら追加で小麦+1（差し引き+2） |
| 小麦不足時 | 発動しない（ログのみ） |
| HP | 60 |
| コスト | wood:3, stone:2 |

#### 処理フロー（_update_mill）

```text
_mill_timer += delta
if _mill_timer < 5.0: return
_mill_timer -= 5.0

if economy.wheat < 1:
    print("[EconBuilding] MILL: 小麦不足、発動スキップ")
    return

economy.wheat -= 1
var gain: int = 2
if get_panel_wheat_value(grid_pos) >= 3:
    gain = 3
economy.wheat += gain
economy.resources["wheat"] = economy.wheat
print("[EconBuilding] MILL: 小麦-1 小麦+%d (wheat=%d)" % [gain, economy.wheat])
```

`get_panel_wheat_value` について：
- 現状EconGridに「パネル小麦値」が存在しない場合、MVPでは常に通常効果（+2）
- 後続でパネルリソースシステム実装時に拡張

### 3. 人口維持処理（5秒周期）

EconEconomy.update() の Step 3 を「食料値消費」へ移行：

```text
維持必要食料値 = max(1, floor(population_float))

if food_value >= 維持必要食料値:
    food_value -= 維持必要食料値
    food_shortage_count = max(0, food_shortage_count - 1)
    print("[EconEconomy] 食料値維持: -%d (food_value=%d, shortage=%d)" % [...])
else:
    var consumed: int = food_value
    food_value = 0
    food_shortage_count += 1
    print("[EconEconomy] 食料値不足！残全消費 -%d shortage_count=%d" % [consumed, food_shortage_count])
```

### 4. 既存`食料消費(Step 3)`との関係

既存処理（EconEconomy.gd:117-131 `population_used / 10`）は本Sprintで置き換える。
`food` フィールドへの操作は`food_value`へ移行。`food`変数自体は後方互換で残す（同期書き込み）。

```text
food = food_value  # 後方互換のため同期
resources["food"] = food_value
```

### 5. EconBuildingへの追加

```gdscript
enum BuildingType {
    BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE,
    EQUIPMENT_SHOP, TRADE_POST, WALL, PLAZA, HOUSE, EXCHANGE,
    LIBRARY, LIBRARY_ADV, MUSEUM, ART_GALLERY, SMITHY, WATCHTOWER,
    DINER, MILL  # ← 追加
}

const DINER_INTERVAL := 5.0
const DINER_WHEAT_COST := 1
const DINER_FOOD_GAIN := 2
const DINER_FOOD_GAIN_SPICE := 3

const MILL_INTERVAL := 5.0
const MILL_WHEAT_COST := 1
const MILL_WHEAT_GAIN := 2
const MILL_WHEAT_GAIN_BOOST := 3
```

`BUILD_COSTS` / `BUILD_HP` にも `19: {"wood":4,"stone":2}` `20: {"wood":3,"stone":2}` を追加。

### 6. cards_econ.json への追加

```json
{
  "id": "card_diner",
  "name": "食堂",
  "type": "building",
  "building_type": "DINER",
  "draw_type": "BASIC",
  "cost": { "wood": 4, "stone": 2, "sulfur": 0 },
  "population_required": 1,
  "population_supply": 0,
  "required_work": 5.0,
  "hp": 60,
  "description": "5秒ごと小麦1消費・食料値+2（香辛料タグ上は+3）"
},
{
  "id": "card_mill",
  "name": "製粉所",
  "type": "building",
  "building_type": "MILL",
  "draw_type": "BASIC",
  "cost": { "wood": 3, "stone": 2, "sulfur": 0 },
  "population_required": 1,
  "population_supply": 0,
  "required_work": 5.0,
  "hp": 60,
  "description": "5秒ごと小麦1消費・小麦+2（小麦3以上パネル上は+3）"
}
```

`EconBattle._create_building_from_card` の `btype_str` マップに `"DINER"`, `"MILL"` を追加。

---

## 実装手順

1. `EconBuilding.BuildingType` enum に DINER, MILL を末尾追加
2. `BUILD_COSTS`, `BUILD_HP` に追加（番号 19, 20）
3. 定数 `DINER_*`, `MILL_*` を追加
4. `_update_diner()`, `_update_mill()` を新規実装
5. `EconBuilding.update()` の建物タイプ分岐に DINER/MILL を追加
6. `EconEconomy` に `add_food()`, `consume_food_for_maintenance()` を追加
7. `EconEconomy.update()` の Step 3 を新仕様へ置換
8. `cards_econ.json` に `card_diner`, `card_mill` を追加
9. `EconBattle._create_building_from_card` の建物タイプマップに DINER/MILL を追加
10. `bash check_syntax.sh` 実行

---

## 完了条件

- [ ] 食堂が5秒ごとに小麦-1・食料値+2を行う
- [ ] 食堂は小麦不足時に発動しない（ログ出力あり）
- [ ] 製粉所が5秒ごとに小麦-1・小麦+2を行う（差し引き+1）
- [ ] 製粉所は小麦不足時に発動しない
- [ ] 人口維持処理が5秒ごとに発動し、`floor(population_float)`ぶんの食料値を消費する
- [ ] 食料値が足りる場合、`food_shortage_count` が1減る（最低0）
- [ ] 食料値が不足する場合、`food_shortage_count` が1増える、残食料値はすべて消費
- [ ] 食料値不足状態がログ出力される
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- 香辛料タグ・小麦パネル値は現MVPでは未実装でよい（常に通常効果でフォールバック）。コメントで「TODO: パネルリソース実装時に有効化」を明記
- 既存`food`フィールドは後方互換のため`food_value`と同期書き込み
- 食堂・製粉所のコストは暫定値。設計書 §14.1 残論点に従いバランス調整は別Sprint
- `population_used`ベースの旧消費式（`/ 10`）は削除する

---

## 関連する既存コード

- `EconEconomy.gd:117-131` 既存の食料消費（置換対象）
- `EconBuilding.gd:67-71` `VILLAGE_WHEAT_*` 定数（参考実装）
- `EconBuilding.gd:255-262` `_update_village()`（周期処理パターン参考）
- `EconBattle.gd:99-121` `_create_building_from_card`（建物タイプマップ追加箇所）
- `data/cards_econ.json` 全体（カード追加箇所）
