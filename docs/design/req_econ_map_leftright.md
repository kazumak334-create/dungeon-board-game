# 要件定義書: Econ MVP 左右対峙マップへの移行

更新日: 2026-05-01
ステータス: ACTIVE

## 概要
現在の上下対峙マップ（プレイヤー row 0、敵 row 11）を
左右対峙マップ（プレイヤー cols 0-7、中立combatゾーン cols 8-17、敵 cols 18-25）に変更する。
併せてユニット移動速度を「現在と同じ拠点到達時間」になるよう調整する。

## 移動速度の計算根拠
- 現在の拠点間距離: 11マス（row 0 → row 11）
- 新マップ拠点間距離: 23マス（col 1 → col 24）
- 到達時間維持のための新 move_spd = 現在値 × (23/11)

| ユニット   | 現在   | 新値 |
|-----------|--------|------|
| ATTACKER  | 0.15   | 0.31 |
| TANK      | 0.08   | 0.17 |
| BREAKER   | 0.12   | 0.25 |

## 変更仕様

### EconGrid.gd

#### 1. `_init_resource_cells()`
- 自陣セル収集: `row 0-3`（全col） → `col 0-7`（全row）
- 敵陣セル収集: `row 9-12`（全col） → `col 18-25`（全row）

#### 2. `generate_terrain()`
- 中央ゾーン: `row 4-8`（全col） → `col 8-17`（全row）

#### 3. `_ensure_passable_path()` と `_bfs_can_reach_row()`
- 縦方向（row 3 → row 9）チェック → 横方向（col 7 → col 18）チェックに変更
- `_bfs_can_reach_row` を削除し `_bfs_can_reach_col(start, target_col)` に置き換え

### EconMain.gd

#### 4. `_setup_initial_entities()`
- 敵BASE:  `Vector2i(6, 11)` → `Vector2i(24, 6)`
- 敵初期ハーベスター: `Vector2i(4, 10)`, `Vector2i(6, 10)` → `Vector2i(23, 5)`, `Vector2i(23, 7)`
- プレイヤーBASE: `Vector2i(6, 0)` → `Vector2i(1, 6)`
- プレイヤー初期ハーベスター: `Vector2i(5, 0)`, `Vector2i(7, 0)` → `Vector2i(2, 5)`, `Vector2i(2, 7)`

#### 5. `_place_initial_village()`
- is_player側: `zone_rows = range(0,3)` の row×col ループ → `col 0-7` の全 row を探索（col→rowの二重ループ）
- enemy側: `zone_rows = range(9,12)` → `col 18-25` の全 row を探索（col→rowの二重ループ）

#### 6. `_update_build_highlight()`
- fill_cells フィルタ: `for row in range(0, 3)` → `for col in range(0, 8)` に変更（列フィルタ）

### EconAI.gd

#### 7. `_build_plan` の固定座標を列ベースに変更
- `Vector2i(3, 10)` → `Vector2i(22, 6)`
- `Vector2i(7, 10)` → `Vector2i(22, 7)`
- `Vector2i(3, 9)` → `Vector2i(21, 6)`
- `Vector2i(7, 9)` → `Vector2i(21, 7)`
- `Vector2i(5, 10)` → `Vector2i(22, 5)`

#### 8. AI再配置探索
- `for row in range(8, 12)` → `for col in range(18, 26)` に変更
- 内側ループも col→row の順に変更

### EconUnit.gd

#### 9. `UNIT_STATS` の move_spd を更新
- ATTACKER: 0.15 → 0.31
- TANK: 0.08 → 0.17
- BREAKER: 0.12 → 0.25

## 制約・注意事項
- `enemy_territory_cells` / `highlight_cells` は変更不要（動的計算のため）
- `_bfs_can_reach_row` は `_bfs_can_reach_col` に**完全置き換え**（削除+新規）
- `_place_initial_village()` はcol→rowの二重ループ構造になる（現在はrow→col）
- 変更は指示された箇所のみ。足し算禁止
