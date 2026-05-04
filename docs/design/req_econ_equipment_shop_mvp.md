# 装備屋（Equipment Shop）要件定義書

更新日: 2026-05-01

## 1. 概要

装備屋は1種類の建物（BuildingType: EQUIPMENT_SHOP）。
3種類（ATK_EQUIP / DEF_EQUIP / SPD_EQUIP）に分けていた誤った実装を修正する。
ユニットのタイプ（unit_type: 0=Attacker / 1=Tank / 2=Breaker）に応じて
異なるパッシブバフを与える。3棟隣接で融合ランクLv3となり定性効果が強化される。

## 2. 実装対象

- `scripts/econ_mvp/EconBuilding.gd`: BuildingType enum, BUILD_COSTS, BUILD_HP, REQUIRED_CONSTRUCTION, _draw()
- `scripts/econ_mvp/EconUnit.gd`: apply_equipment_buff 関数シグネチャ・ロジック
- `scripts/econ_mvp/EconBattle.gd`: _recalc_fusion_clusters, _apply_equipment_buffs, _on_building_constructed, _on_building_destroyed
- `scripts/econ_mvp/EconMain.gd`: PlaceMode enum, build_data配列, build_modes_arr, _place_building, 名前テーブル（line 949付近）

## 3. データ構造

### 3.1 BuildingType の変更

削除: ATK_EQUIP(7), DEF_EQUIP(8), SPD_EQUIP(9)
追加: EQUIPMENT_SHOP(7)

最終 enum（8種類）:
```
enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE, EQUIPMENT_SHOP }
```

### 3.2 コスト・HP・建設時間

| index | 種別 | コスト | HP | 建設時間 |
|-------|------|--------|-----|----------|
| 7 | EQUIPMENT_SHOP | wood:5, sulfur:3 | 80.0 | 6.0 |

## 4. 実装詳細

### 4.1 バフ仕様（unit_type で判定）

`apply_equipment_buff` のシグネチャを変更:
```
func apply_equipment_buff(unit_type: int, rank: int) -> void:
```

match unit_type:
- 0 (Attacker): atk *= 1.20。rank >= 3: attack_range += 1, min_range = 0
- 1 (Tank):     max_hp *= 1.20, hp = max_hp。rank >= 3: max_hp *= 1.50, hp = max_hp, move_spd *= 0.70
- 2 (Breaker):  move_spd *= 1.20。rank >= 3: move_spd *= 1.50, max_hp *= 0.70, hp = max_hp

注意: _equip_atk_mult / _equip_hp_mult / _equip_speed_mult などの変数名はそのまま維持。

### 4.2 融合ランク再計算（EconBattle.gd）

`_recalc_fusion_clusters` の equip_types を1種類に変更:
```
var equip_types: Array = [EconBuilding.BuildingType.EQUIPMENT_SHOP]
```
BFS ロジック（同種かつ hex_distance==1 の連結）は変更しない。

### 4.3 _apply_equipment_buffs の変更（EconBattle.gd）

```
var equip_types: Array = [EconBuilding.BuildingType.EQUIPMENT_SHOP]
```
呼び出しを変更:
```
unit.apply_equipment_buff(int(unit.unit_type), b.fusion_rank)
```
（第1引数を BuildingType から unit.unit_type に変更）

### 4.4 _on_building_constructed / _on_building_destroyed の変更（EconBattle.gd）

equip_types を EQUIPMENT_SHOP 1件のみに変更。

### 4.5 PlaceMode の変更（EconMain.gd）

削除: ATK_EQUIP, DEF_EQUIP, SPD_EQUIP
追加: EQUIPMENT_SHOP

```
enum PlaceMode { NONE, BARRACKS, FORTRESS, WORKSHOP, VILLAGE, SAWMILL, MINE, EQUIPMENT_SHOP }
```

### 4.6 UI ボタン配置（2行4列）

GridContainer.columns = 4（現状維持）

build_data 配列を8件に変更（現状9件→8件）:
```
上段: BARRACKS / FORTRESS / WORKSHOP / SAWMILL
下段: VILLAGE / EQUIPMENT_SHOP / MINE / （空きスロット）
```

build_data 配列定義:
```
0: {mode: BARRACKS,        icon: "⚔",  name: "兵舎",   cost: "20W · 10S"}
1: {mode: FORTRESS,        icon: "🛡",  name: "要塞",   cost: "48S · 15W"}
2: {mode: WORKSHOP,        icon: "⚒",  name: "工房",   cost: "25W · 5S"}
3: {mode: SAWMILL,         icon: "🪚",  name: "製材所", cost: "8W·3S"}
4: {mode: VILLAGE,         icon: "⌂",  name: "農村",   cost: "15W · 5W"}
5: {mode: EQUIPMENT_SHOP,  icon: "⚙",  name: "装備屋", cost: "5W · 3Su"}
6: {mode: MINE,            icon: "⛏",  name: "鉱山",   cost: "10S·4Su"}
```
7番目（空きスロット）は disabled の Button として追加するか、単に7件のまま残す。
実装の簡略化のため、build_data は7件（空きスロットなし）でよい。

build_modes_arr も同様に7件に変更。

### 4.7 _place_building の変更（EconMain.gd）

btype_map から ATK_EQUIP/DEF_EQUIP/SPD_EQUIP を削除し、EQUIPMENT_SHOP を追加:
```
PlaceMode.EQUIPMENT_SHOP: EconBuilding.BuildingType.EQUIPMENT_SHOP,
```

### 4.8 名前テーブルの変更（EconMain.gd line 949付近）

```
var names := ["Barracks", "Fortress", "Workshop", "Village", "BASE", "Sawmill", "Mine", "Equipment_Shop"]
```
（ATK_EQUIP, DEF_EQUIP, SPD_EQUIP を削除）

### 4.9 _draw() の変更（EconBuilding.gd）

EQUIPMENT_SHOP の色を追加（ATK_EQUIP/DEF_EQUIP/SPD_EQUIP の色定義を削除）:
```
BuildingType.EQUIPMENT_SHOP: color = Color.DARK_OLIVE_GREEN
```

## 5. 制約・注意事項

- EconUnit の _equip_atk_mult / _equip_hp_mult / _equip_speed_mult は変数名変更なし
- EconBattle の _apply_equipment_buffs の btype（BuildingType）での match は unit_type での判定に変わる
- 既存の融合ランク BFS ロジックは変更しない（equip_types リストのみ変更）
- EconAI.gd が EQUIP 関連の BuildingType を参照している場合は同様に修正する
