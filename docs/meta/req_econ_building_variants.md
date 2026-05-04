# 要件定義書: EconMVP 建物バリアント実装

更新日: 2026-05-01
STATUS: Draft

企画書: docs/design/econ_building_system.md ## 12

---

## 0. スコープ

本書は以下6件の実装仕様を定める。

1. 全生産建物のベース生産間隔を20秒に変更
2. 農村/鉱山隣接チェックロジック（配置ボーナス）
3. 配置ボーナス適用時: コスト半減・時間半減
4. 全ユニット移動速度2倍（UNIT_STATSの数値変更）
5. 採取建物クラスタリングボーナス（EconHarvesterの_harvest_bonus計算拡張）
6. 徴兵兵舎の生産間隔5秒（農村隣接時）・Wheat2消費

対象ファイル:
- scripts/econ_mvp/EconBuilding.gd （172行）
- scripts/econ_mvp/EconUnit.gd （362行）
- scripts/econ_mvp/EconHarvester.gd （285行）

---

## 1. 全生産建物のベース生産間隔を20秒に変更

### 変更対象（EconBuilding.gd）

現在値:
```
const BARRACKS_PRODUCE_INTERVAL := 8.0
const FORTRESS_PRODUCE_INTERVAL := 10.0
const WORKSHOP_PRODUCE_INTERVAL := 12.0
```

変更後:
```
const BARRACKS_PRODUCE_INTERVAL := 20.0
const FORTRESS_PRODUCE_INTERVAL := 20.0
const WORKSHOP_PRODUCE_INTERVAL := 20.0
```

### 根拠（企画書 ## 12 設計方針より引用）
> 全生産建物のベース生産間隔：20秒（隣接ボーナスなしは実質機能しない重さ）

---

## 2. 農村/鉱山隣接チェックロジック（EconBuilding.gd）

### 新規フィールド追加

EconBuilding クラスに以下を追加する:

```gdscript
var _placement_bonus_active: bool = false
```

### 新規メソッド追加

```gdscript
func check_placement_bonus(buildings: Array, grid: EconGrid) -> void:
    # 配置ボーナス条件チェック（生産タイミングで毎回呼ぶ）
    # 条件: 農村隣接（BARRACKS/WORKSHOP/基本FORTRESS系）
    # 条件: 鉱山隣接（採掘守備要塞バリアント・砲塔要塞バリアント → 現状は基本FORTRESSに適用）
    _placement_bonus_active = false
    for b in buildings:
        if not b.is_alive or not b.is_built:
            continue
        var dist: int = grid.hex_distance(grid_pos, b.grid_pos)
        if dist != 1:
            continue
        match building_type:
            BuildingType.BARRACKS, BuildingType.WORKSHOP:
                if b.building_type == BuildingType.VILLAGE:
                    _placement_bonus_active = true
                    return
            BuildingType.FORTRESS:
                if b.building_type == BuildingType.VILLAGE or b.building_type == BuildingType.MINE:
                    _placement_bonus_active = true
                    return
```

### check_placement_bonus の呼び出し箇所

_update_barracks / _update_fortress / _update_workshop の生産タイマーが閾値を超えたとき（`if _produce_timer >= interval` の直前）に呼ぶ。

呼び出し元への buildings / grid 引数追加が必要なので、 `update(delta, economy)` のシグネチャを以下に変更する:

```gdscript
func update(delta: float, economy: EconEconomy, buildings: Array = [], grid: EconGrid = null) -> void:
```

---

## 3. 配置ボーナス適用時: コスト半減・時間半減（EconBuilding.gd）

### ボーナス適用ロジック

_placement_bonus_active が true のとき:
- 生産間隔: `XXXXX_PRODUCE_INTERVAL / 2.0`
- 生産コスト: `ceil(XXXXX_PRODUCE_COST / 2.0)` （端数は切り上げ）

実装パターン（_update_barracks を例として）:

```gdscript
func _update_barracks(delta: float, economy: EconEconomy, buildings: Array, grid: EconGrid) -> void:
    var interval := BARRACKS_PRODUCE_INTERVAL / 2.0 if _placement_bonus_active else BARRACKS_PRODUCE_INTERVAL
    var cost := ceili(BARRACKS_PRODUCE_COST / 2.0) if _placement_bonus_active else BARRACKS_PRODUCE_COST
    _resource_ready = economy.can_afford({"wood": cost})
    _produce_timer += delta
    if _produce_timer >= interval:
        if _resource_ready:
            if buildings.size() > 0 and grid != null:
                check_placement_bonus(buildings, grid)
            economy.spend({"wood": cost})
            _produce_timer = 0.0
            unit_produced.emit(grid_pos, 0)
```

同様のパターンを _update_fortress / _update_workshop にも適用する。

### 根拠（企画書 ## 12 設計方針より引用）
> 配置ボーナス条件を満たすと：生産時間・コスト 半減

---

## 4. 全ユニット移動速度2倍（EconUnit.gd）

### 変更対象（EconUnit.gd の UNIT_STATS）

現在値:
```
"ATTACKER": {"move_spd": 0.31, ...}
"TANK":     {"move_spd": 0.17, ...}
"BREAKER":  {"move_spd": 0.25, ...}
```

変更後:
```
"ATTACKER": {"move_spd": 0.62, ...}
"TANK":     {"move_spd": 0.34, ...}
"BREAKER":  {"move_spd": 0.50, ...}
```

### 根拠
ユーザー指示（ステップ4要件）による既存数値の2倍への変更。

---

## 5. 採取建物クラスタリングボーナス（EconHarvester.gd）

### 変更対象

EconHarvester.gd の以下のブロック（現在は1棟につき+1固定）:

```gdscript
# 隣接SAWMILL/MINEによるボーナス計算
_harvest_bonus = 0
for b in buildings:
    ...
    if dist == 1:
        if b.building_type == EconBuilding.BuildingType.SAWMILL:
            if rtype == EconGrid.ResourceType.WOOD:
                _harvest_bonus += 1
        elif b.building_type == EconBuilding.BuildingType.MINE:
            if rtype in [...]:
                _harvest_bonus += 1
```

### 変更後ロジック

資源タイルへの隣接棟数を集計し、棟数分のボーナスを加算する（現状の「1棟=+1」と実質同一だが、将来の拡張を考慮して棟数カウント式に明示化する）。

変更後:
```gdscript
_harvest_bonus = 0
var sawmill_count: int = 0
var mine_count: int = 0
for b in buildings:
    if not b.get("is_alive") or not b.is_alive:
        continue
    if not b.get("is_built") or not b.is_built:
        continue
    var dist: int = grid.hex_distance(grid_pos, b.grid_pos)
    if dist == 1:
        if b.building_type == EconBuilding.BuildingType.SAWMILL:
            sawmill_count += 1
        elif b.building_type == EconBuilding.BuildingType.MINE:
            mine_count += 1
if rtype == EconGrid.ResourceType.WOOD:
    _harvest_bonus = sawmill_count
elif rtype in [EconGrid.ResourceType.STONE, EconGrid.ResourceType.SULFUR, EconGrid.ResourceType.IRON]:
    _harvest_bonus = mine_count
```

### 根拠（企画書 ## 12 採取建物クラスタリングボーナスより引用）
> 資源タイル1個に対して隣接する同種採取建物の棟数 = そのタイルへの採取ボーナス量
> 1棟隣接：+1/trip、2棟：+2/trip、3棟：+3/trip

---

## 6. 徴兵兵舎の生産間隔5秒・Wheat2消費（EconBuilding.gd）

### 追加コンスタント

```gdscript
const BARRACKS_CONSCRIPT_INTERVAL := 5.0   # 農村隣接時の徴兵兵舎間隔（ボーナス適用後）
const BARRACKS_CONSCRIPT_WHEAT_COST := 2   # 徴兵兵舎のWheat消費
```

### 実装方針

現在の兵舎はバリアント選択システムがまだ存在しないため、今回の実装は「徴兵モード定数の定義と_update_barracksへのコスト分岐準備」にとどめる。

実際の切り替えロジック（Wheat2消費 / 農村隣接で5秒）は、バリアント選択UIが実装された後に有効化する。

定数の追加とコメントによるプレースホルダーを実装し、バリアントシステム実装時に接続しやすい構造にする。

### 根拠（企画書 ## 12 兵舎バリアント一覧より引用）
> 徴兵兵舎：Wood不要・Wheat2消費 / Wheat2/20秒 → 農村隣接で10秒（半減で10秒）

---

## 7. EconMainへの引数伝達変更

EconBuilding.update のシグネチャを変更するため、呼び出し元の EconBattle.gd（47行目）でも引数を追加する。

```gdscript
# 変更前
building.update(delta, economy)

# 変更後
building.update(delta, economy, buildings, grid)
```

buildings / grid は EconBattle が既に保持しているため、受け渡しのみ。

---

## 8. 変更必要（EconAI.gd も更新対象）

EconAI.gd 134行目にも同様の呼び出しがある:

```gdscript
# 変更前
b.update(delta, economy)

# 変更後
b.update(delta, economy, _battle.enemy_buildings, _grid)
```

- EconAI が保持する grid は `_grid` 変数
- enemy_buildings は `_battle.enemy_buildings`

（元の § 8 でスコープ外としたが、シグネチャ変更の影響で更新必須）
- EconGrid.gd: 変更なし
- EconEconomy.gd: 変更なし（Wheat消費は既存のspendで対応可能）

---

## 9. 完了定義（Checkerチェックリスト）

- [ ] BARRACKS/FORTRESS/WORKSHOP の PRODUCE_INTERVAL が 20.0 になっている
- [ ] EconBuilding.update のシグネチャが `(delta, economy, buildings, grid)` になっている
- [ ] check_placement_bonus メソッドが EconBuilding に追加されている
- [ ] _placement_bonus_active が true のとき間隔・コストが半減する
- [ ] UNIT_STATS の move_spd が ATTACKER:0.62 / TANK:0.34 / BREAKER:0.50 になっている
- [ ] EconHarvester の _harvest_bonus 計算が棟数カウント式になっている
- [ ] BARRACKS_CONSCRIPT_INTERVAL / BARRACKS_CONSCRIPT_WHEAT_COST 定数が追加されている
- [ ] EconMain.gd で building.update に buildings/grid が渡されている
- [ ] check_syntax.sh が通る
