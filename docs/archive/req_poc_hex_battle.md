# 要件定義書：PoCヘクスバトルシステム

作成日: 2026-04-28
ステータス: 新規
対象ディレクトリ: `res://scenes/poc/`, `res://scripts/poc/`

---

## 1. 目的・スコープ

### 1.1 検証目的
1. **突・守・崩の3すくみカウンター**が機能するか（カウンター倍率で勝敗が逆転するか）
2. **ランチェスター則**（集中配置が強い）が成立するか（分散配置 vs 集中配置で差が出るか）

### 1.2 制約
- 既存ファイルは**一切変更しない**
- `res://scenes/poc/`と`res://scripts/poc/`以下のみ新規作成
- Godot 4.x（GDScript 4）

---

## 2. グリッド仕様

### 2.1 六角形グリッド（pointy-top オフセット方式）

| 行 | マス数 | col インデックス |
|----|--------|----------------|
| 偶数行（0,2,4,6,8） | 6マス | 0〜5 |
| 奇数行（1,3,5,7,9） | 5マス | 0〜4 |

- 合計10行（row 0〜9）
- 左右対称配置

### 2.2 ゾーン定義

| ゾーン | 行範囲 | 用途 |
|--------|--------|------|
| プレイヤー配置ゾーン | row 0〜2 | 自軍ユニット配置可 |
| 移動領域 | row 3〜6 | 配置不可・移動のみ |
| 敵配置ゾーン | row 7〜9 | 敵ユニット配置可 |

### 2.3 座標変換（画面座標 ↔ グリッド座標）

pointy-top六角形のオフセット座標変換：
```
hex_size = 40  # 六角形の外接円半径（ピクセル）
hex_width = hex_size * sqrt(3)   # ≈ 69.28px
hex_height = hex_size * 2        # 80px

# グリッド座標 → 画面座標
pixel_x = hex_width * col + (hex_width / 2 if row % 2 == 1 else 0)
pixel_y = hex_height * 0.75 * row

# オフセット原点は画面中央に設定
```

### 2.4 隣接セル定義（オフセット方式）

偶数行からの6方向：
```
[(-1, 0), (1, 0), (-1, -1), (0, -1), (-1, 1), (0, 1)]
```
奇数行からの6方向：
```
[(-1, 0), (1, 0), (0, -1), (1, -1), (0, 1), (1, 1)]
```

---

## 3. ユニット仕様

### 3.1 ユニットパラメータ

| 種別 | 表示色 | HP | ATK | 移動SPD（行/秒） | 攻撃間隔（秒） | 射程（セル） | 攻撃範囲 |
|------|--------|----|----|-----------------|----------------|-------------|---------|
| 突（アタッカー） | 赤 (Color.RED) | 60 | 30 | 2.0 | 0.67（1/1.5） | 1 | 単体 |
| 守（タンク） | 青 (Color.BLUE) | 200 | 10 | 0.5 | 1.25（1/0.8） | 1 | 単体 |
| 崩（ブレイカー） | 緑 (Color.GREEN) | 40 | 20 | 0.8 | 1.67（1/0.6） | 2 | 半径1セル |

### 3.2 3すくみカウンター倍率

攻撃側（行）が防御側（列）に与えるダメージ倍率：

| 攻撃 \ 防御 | 突 | 守 | 崩 |
|------------|----|----|-----|
| 突 | 1.0 | 1.0 | 2.0 |
| 守 | 0.5 | 1.0 | 1.0 |
| 崩 | 1.0 | 2.0 | 1.0 |

- 突 → 崩：突が崩に×2.0（崩は突に弱い）
- 守 → 突：守が突に×0.5（守は突への攻撃が弱い＝突は守に強い）
- 崩 → 守：崩が守に×2.0（守は崩に弱い）

---

## 4. 移動・攻撃ロジック

### 4.1 ターゲット選択
1. 自ユニットから全敵ユニットの**六角グリッド距離**を計算
2. `距離 / 移動SPD` が最小の敵をターゲットに選択
3. ターゲットが死亡したら再評価

### 4.2 移動フェーズ
1. ターゲットへの最短経路を探索（BFS）
2. `移動SPD` に従い1ステップずつ隣接セルへ移動
3. ターゲットが**射程内**に入ったら移動停止

### 4.3 攻撃フェーズ
1. 射程内にターゲットがいる場合、`攻撃間隔` に従い攻撃
2. ダメージ計算：`ATK * カウンター倍率`
3. 崩の場合：ターゲットセルの**半径1セル以内の全敵ユニット**にダメージ

### 4.4 六角グリッド距離計算
オフセット座標をキューブ座標に変換して距離計算：
```
# オフセット(col, row) → キューブ(x, y, z)
x = col - (row - (row & 1)) / 2
z = row
y = -x - z
# 距離 = max(|x1-x2|, |y1-y2|, |z1-z2|)
```

---

## 5. バトル進行管理

### 5.1 バトルフェーズ
```
SETUP     # ユニット配置中
BATTLE    # バトル進行中（_process で毎フレーム更新）
END       # 勝敗確定
```

### 5.2 勝利条件
- **プレイヤー勝利**：敵ユニット全滅 OR プレイヤーユニットが row 9 以上到達
- **プレイヤー敗北**：プレイヤーユニット全滅 OR 敵ユニットが row 0 以下到達

### 5.3 バトル更新ループ（_process delta 使用）
各フレーム全ユニットを更新：
1. 移動フェーズ処理
2. 攻撃フェーズ処理
3. 死亡ユニット削除
4. 勝利条件チェック

---

## 6. ファイル仕様

### 6.1 HexGrid.gd（`res://scripts/poc/HexGrid.gd`）

**クラス名：** `HexGrid`（`Node2D` 継承）

**定数：**
```gdscript
const HEX_SIZE := 40.0
const ROWS := 10
```

**メソッド：**
| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `get_col_count(row: int) -> int` | int | 偶数行=6、奇数行=5 |
| `hex_to_pixel(col: int, row: int) -> Vector2` | Vector2 | グリッド→画面座標 |
| `get_neighbors(col: int, row: int) -> Array` | Array[Vector2i] | 隣接セルリスト |
| `hex_distance(a: Vector2i, b: Vector2i) -> int` | int | 六角グリッド距離 |
| `bfs_path(start: Vector2i, goal: Vector2i) -> Array` | Array[Vector2i] | BFS最短経路 |
| `is_valid_cell(col: int, row: int) -> bool` | bool | 有効セル判定 |
| `_draw()` | void | グリッド描画（queue_redraw用） |

**描画仕様（_draw）：**
- 全セルの六角形アウトラインを描画（`draw_colored_polygon` または `draw_polyline`）
- 配置ゾーン（row 0-2）を薄青で塗りつぶし
- 敵ゾーン（row 7-9）を薄赤で塗りつぶし
- グリッド線は白（透明度50%）

---

### 6.2 PoCUnit.gd（`res://scripts/poc/PoCUnit.gd`）

**クラス名：** `PoCUnit`（`Node2D` 継承）

**enum：**
```gdscript
enum UnitType { ATTACKER, TANK, BREAKER }
enum Side { PLAYER, ENEMY }
```

**プロパティ：**
```gdscript
var unit_type: UnitType
var side: Side
var grid_pos: Vector2i  # (col, row)
var hp: float
var max_hp: float
var atk: float
var move_spd: float     # 行/秒
var attack_interval: float  # 秒
var attack_range: int   # セル数
var target: PoCUnit     # 現在のターゲット
var attack_timer: float # 攻撃タイマー
var move_timer: float   # 移動タイマー
var is_alive: bool = true
```

**静的初期化メソッド：**
```gdscript
static func create(type: UnitType, side: Side, col: int, row: int) -> PoCUnit
```

**メソッド：**
| メソッド | 説明 |
|---------|------|
| `update(delta: float, enemies: Array, hex_grid: HexGrid) -> void` | 毎フレーム更新（移動+攻撃） |
| `select_target(enemies: Array, hex_grid: HexGrid) -> void` | ターゲット選択 |
| `try_move(delta: float, hex_grid: HexGrid) -> void` | 移動処理 |
| `try_attack(delta: float, hex_grid: HexGrid) -> void` | 攻撃処理 |
| `take_damage(amount: float) -> void` | ダメージ受け |
| `get_counter_multiplier(attacker_type: UnitType, defender_type: UnitType) -> float` | カウンター倍率取得 |
| `_draw() -> void` | 円＋HPバー描画 |

**描画仕様（_draw）：**
- 色付き円（半径18px）でユニット表示
- HPバー：円の上部(-25px)に幅36px、高さ5pxの矩形
  - 背景：グレー
  - 前景：緑（HP割合に応じて幅変化）
- 敵ユニットは円の輪郭を黒縁取り（2px）

---

### 6.3 PoCBattle.gd（`res://scripts/poc/PoCBattle.gd`）

**クラス名：** `PoCBattle`（`Node` 継承）

**enum：**
```gdscript
enum Phase { SETUP, BATTLE, END }
```

**プロパティ：**
```gdscript
var phase: Phase = Phase.SETUP
var player_units: Array[PoCUnit] = []
var enemy_units: Array[PoCUnit] = []
var hex_grid: HexGrid
```

**シグナル：**
```gdscript
signal battle_ended(player_won: bool)
signal unit_died(unit: PoCUnit)
```

**メソッド：**
| メソッド | 説明 |
|---------|------|
| `setup_default_units() -> void` | デフォルト配置（各3種×2体）設定 |
| `start_battle() -> void` | Phase.BATTLE に移行 |
| `update(delta: float) -> void` | 毎フレーム全ユニット更新・勝敗チェック |
| `check_victory() -> void` | 勝利条件チェック・シグナル発行 |
| `get_player_units() -> Array` | プレイヤーユニット取得 |
| `get_enemy_units() -> Array` | 敵ユニット取得 |

**デフォルト配置：**
```
# プレイヤー（row 1）
突×2: (1,1), (4,1)
守×2: (2,1), (3,1)
崩×2: (0,1), (5,1)

# 敵（row 8）
突×2: (1,8), (4,8)
守×2: (2,8), (3,8)
崩×2: (0,8), (5,8)
```

---

### 6.4 PoCMain.gd（`res://scripts/poc/PoCMain.gd`）

**クラス名：** `PoCMain`（`Node2D` 継承）

**ノード構成（コード内で動的生成）：**
```
PoCMain (Node2D)
├── HexGrid (HexGrid)      # グリッド描画
├── UnitsLayer (Node2D)    # ユニット表示レイヤー
├── UILayer (CanvasLayer)
│   ├── StartButton (Button)  # 「バトル開始」
│   └── ResultLabel (Label)   # 勝利/敗北テキスト
└── PoCBattle (PoCBattle)     # バトル管理
```

**動作フロー：**
1. `_ready`：グリッド・デフォルトユニット生成・UI設定
2. StartButton 押下 → `PoCBattle.start_battle()` 呼び出し
3. `_process(delta)` → `PoCBattle.update(delta)` 呼び出し
4. `battle_ended` シグナル受信 → ResultLabel 表示

---

### 6.5 PoCMain.tscn（`res://scenes/poc/PoCMain.tscn`）

最小限の.tscnファイル：
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/poc/PoCMain.gd" id="1"]

[node name="PoCMain" type="Node2D"]
script = ExtResource("1")
```

PoCMain.gd の `_ready()` でノードを動的生成する。

---

## 7. 実装上の注意事項

### 7.1 _process でのユニット更新
PoCMain.gd の `_process(delta)` からのみ `PoCBattle.update(delta)` を呼ぶ。
PoCUnit の `update()` はPoCBattle経由で呼ばれる（PoCUnit自身は`_process`を持たない）。

### 7.2 ユニット画面座標の同期
PoCUnit の `grid_pos` が変わるたびに `position = hex_grid.hex_to_pixel(grid_pos.x, grid_pos.y)` で画面座標を更新し、`queue_redraw()` を呼ぶ。

### 7.3 既存コードとの分離
- `res://scripts/poc/` 内のスクリプトは既存の `autoload` や `singleton` を一切使わない
- 必要なデータはすべてローカルで定義する

### 7.4 構文チェック
実装後は `bash /c/Users/kazum/dungeon-board-game/check_syntax.sh` を実行し、エラー0件を確認する。

---

## 8. 受け入れ条件

1. `res://scenes/poc/PoCMain.tscn` をGodotで開けてエラーなし
2. シーン実行時に六角グリッドが画面中央に描画される
3. 「バトル開始」ボタンでユニットが移動を開始する
4. ユニットが射程内の敵を攻撃し、HPが減少する
5. 全ユニット撃破または敵ベース到達で勝利/敗北テキストが表示される
6. 3すくみカウンターが有効（崩 vs 守は×2.0のダメージ）
7. 既存ファイルへの変更なし（git diff で確認）
