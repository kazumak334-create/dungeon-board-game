# ADR-002: TileType と ResourceType の分離

**ステータス:** 採択  
**日付:** 2026-04-29  
**対象:** scripts/econ_mvp/EconGrid.gd

---

## 背景

マップセルには「何の資源があるか（ResourceType）」と「地形はどうか（TileType）」の
2つの属性が独立して存在する。

## 決定

- `resource_cells: Dictionary` — セルの ResourceType（NONE/WOOD/STONE/SULFUR/WHEAT）
- `tile_cells: Dictionary` — セルの TileType（PLAIN/MOUNTAIN/DESERT）
- 資源タイルの地形は常に PLAIN

## 効果

- 「山岳の上に資源がある」という矛盾状態を構造的に排除
- 地形生成と資源配置のロジックが独立して変更可能

## 見直しタイミング

- 「山岳に鉄鉱石が埋まっている」等の特殊タイルを追加する場合
