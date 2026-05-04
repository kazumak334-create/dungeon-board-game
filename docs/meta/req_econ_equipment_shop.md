# 要件定義書: EconMVP 装備屋（Equipment Shop）

更新日: 2026-05-01
STATUS: 廃止（→ req_econ_equipment_shop_mvp.md）

⚠️ このファイルは新ファイル req_econ_equipment_shop_mvp.md に統合されました。
参考資料のみで使用してください。

企画書: Planning出力 2026-05-01 / Designer出力 2026-05-01

---

## 0. スコープ

EconMVP に新規建物群「装備屋（Equipment Shop）」を 4 バリアント追加する。
装備屋は隣接した生産建物（兵舎・要塞・工房）から生産されるユニットに対し、
**異種加算（種類が違えば独立加算）** と **融合ランク（同種隣接でランク上昇）** の 2 軸で能力修正を与える。

### 核となる体験との整合性

- 「設計して観戦する」体験を強化: 建物配置の組み合わせが戦況に直結
- 「配分の答え合わせ」体験: バトル前に隣接関係を設計し、戦闘で結果を観戦
- KISS原則: 装備屋は 4 種固定・効果は加算と Lv3 定性のみ・隣接判定は既存 hex_distance を流用

### スコープ外（次回MVP以降）

- 装備屋の建設条件分化（資源タイル隣接など）
- 5 種以上のバリアント追加
- 装備屋同士の異種ランク（光剣 + 重盾 = 特殊効果など）
- ユニット個別の装備変更 UI（自動接続のみ）

---

## 1. 概要

### 1.1 4 バリアント定義

| # | バリアント名 | 加算効果（数値） | Lv3 定性効果 | 適用対象ユニット |
|---|-------------|----------------|-------------|----------------|
| A | 軽装備屋（LIGHT_EQUIP） | move_spd +20%（乗算） | 開幕突進: バトル開始時に最も近い敵まで瞬間移動 | ATTACKER / TANK / BREAKER（全ユニット） |
| B | 重装備屋（HEAVY_EQUIP） | max_hp +30%（乗算） | 初回被弾無効: 1 度だけダメージを 0 にする | ATTACKER / TANK / BREAKER（全ユニット） |
| C | 遠射装備屋（RANGED_EQUIP） | attack_range +1（加算） | +2 射程: attack_range にさらに +2 加算 | BREAKER 優先・他ユニットも適用可 |
| D | 特攻装備屋（KAMIKAZE_EQUIP） | 自爆能力付与（HP 0 時に隣接マスに 30 ダメージ AOE） | 爆風範囲拡大: AOE 半径 1 → 半径 2（隣接 → 2 ヘックス内全体） |

### 1.2 メカニクス概要

#### 異種加算（Cross-type Addition）

- **異なる種類**の装備屋が同じ生産建物に隣接すると、各装備屋の効果が独立に加算される
- 例: 兵舎が「軽装備屋 + 重装備屋」に隣接 → ATTACKER に move_spd +20% かつ max_hp +30%
- 装備屋同士の隣接関係ではなく、**装備屋 → 生産建物の隣接** で判定

#### 融合ランク（Fusion Rank）

- **同種**の装備屋が隣接（装備屋 ↔ 装備屋の hex_distance == 1）するとクラスタ形成
- クラスタ内の装備屋数で Lv 決定:
  - 1 棟: Lv1（基本効果のみ）
  - 2 棟: Lv2（基本効果のみ・効果量は変わらず）
  - 3 棟以上: Lv3（**定性効果が発動**）
- Lv2 は中間段階として効果量変化を持たない（KISS: Lv1↔Lv3 の 2 段階モデル）
- クラスタは Union-Find ではなく BFS で計算（後述§3.2）

### 1.3 配置ルール

| 項目 | 値 |
|------|----|
| 配置可能エリア | 自陣領土内（既存 highlight_cells と同じ条件） |
| 必須隣接 | なし（生産建物が隣接していなくても建設可能・ただし効果は出ない） |
| 配置上限 | なし |
| 同種隣接の制約 | なし（クラスタを大きくして Lv3 化を狙うのが正しいプレイ） |

---

## 2. データ構造

### 2.1 EconBuilding への追加

```gdscript
# enum BuildingType に 4 種追加（並び維持・末尾追加）
enum BuildingType {
    BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE,
    TRADE_POST, WALL,             # req_econ_trade_post.md
    LIGHT_EQUIP, HEAVY_EQUIP, RANGED_EQUIP, KAMIKAZE_EQUIP   # 本要件
}

# BUILD_COSTS / BUILD_HP / REQUIRED_CONSTRUCTION
# 9: LIGHT_EQUIP   {"wood": 6, "stone": 4}, HP 80, 構築 6.0 秒
# 10: HEAVY_EQUIP  {"stone": 8, "iron": 2}, HP 120, 構築 8.0 秒
# 11: RANGED_EQUIP {"wood": 5, "sulfur": 4}, HP 80, 構築 6.0 秒
# 12: KAMIKAZE_EQUIP {"sulfur": 6, "wheat": 2}, HP 60, 構築 5.0 秒
```

#### 装備屋専用フィールド

```gdscript
# 装備屋のみ使用（他建物は -1 のまま）
var fusion_rank: int = 1            # 1=Lv1, 2=Lv2, 3=Lv3
var fusion_cluster_id: int = -1     # 同種クラスタの ID（-1=未計算）
```

### 2.2 EconUnit への追加（バフ反映用）

```gdscript
# scripts/econ_mvp/EconUnit.gd

# 装備屋から付与されるバフフラグ・倍率
var _equip_speed_mult: float = 1.0       # LIGHT_EQUIP の移動速度乗算（基本 1.2 / Lv3=同じ）
var _equip_hp_mult: float = 1.0          # HEAVY_EQUIP の HP 乗算（基本 1.3）
var _equip_range_bonus: int = 0          # RANGED_EQUIP の射程加算（基本 +1 / Lv3 で +3）
var _equip_kamikaze: bool = false        # KAMIKAZE_EQUIP 適用フラグ
var _equip_kamikaze_radius: int = 1      # AOE 半径（基本 1 / Lv3 で 2）

# Lv3 専用フラグ
var _equip_dash_pending: bool = false    # 軽 Lv3 開幕突進フラグ（spawn 時に true）
var _equip_first_hit_shield: bool = false  # 重 Lv3 初回被弾無効フラグ
```

### 2.3 EconBuilding.update のシグネチャ既存維持

`update(delta, economy, buildings, grid)` は既に確定済み（req_econ_building_variants.md §2 参照）。
装備屋効果は **生産建物がユニットを生成する瞬間** に同 buildings 配列を走査して反映する。
よってシグネチャの追加変更は不要。

---

## 3. 実装仕様

### 3.1 装備屋効果の適用タイミング

ユニット生成時（`unit_produced.emit(grid_pos, utype)` の直後）に EconBattle が以下を実行する。

```gdscript
# EconBattle.gd の register_player_unit_spawn 系メソッド内、または
# 既存の unit_produced ハンドラ内で生成直後の EconUnit に対して呼ぶ

func _apply_equipment_buffs(unit: EconUnit, source_building_pos: Vector2i) -> void:
    var grid: EconGrid = self.grid
    for b in player_buildings:
        if not b.is_alive or not b.is_built:
            continue
        if grid.hex_distance(source_building_pos, b.grid_pos) != 1:
            continue
        match b.building_type:
            EconBuilding.BuildingType.LIGHT_EQUIP:
                unit._equip_speed_mult *= 1.2
                if b.fusion_rank >= 3:
                    unit._equip_dash_pending = true
            EconBuilding.BuildingType.HEAVY_EQUIP:
                unit._equip_hp_mult *= 1.3
                if b.fusion_rank >= 3:
                    unit._equip_first_hit_shield = true
            EconBuilding.BuildingType.RANGED_EQUIP:
                unit._equip_range_bonus += 1
                if b.fusion_rank >= 3:
                    unit._equip_range_bonus += 2
            EconBuilding.BuildingType.KAMIKAZE_EQUIP:
                unit._equip_kamikaze = true
                if b.fusion_rank >= 3:
                    unit._equip_kamikaze_radius = 2
    # 反映: ステータスへ
    unit.move_spd *= unit._equip_speed_mult
    unit.max_hp *= unit._equip_hp_mult
    unit.hp = unit.max_hp
    unit.attack_range += unit._equip_range_bonus
```

#### 重要

- 異種加算 = 各 case 文が独立に発火するため、ループ 1 周で自動的に複数効果が積算される
- 生産建物 1 個 + 装備屋複数個の隣接で複数バフが付与される
- 同種 2 個隣接（Lv1 同士）の場合は乗算が 2 回かかる仕様にしない（**1 種類 1 回適用**）

#### 同種重複適用の防止

```gdscript
# _apply_equipment_buffs 冒頭に「種別ごとの最大 fusion_rank 装備屋」を抽出
var best_per_type: Dictionary = {}  # BuildingType -> EconBuilding
for b in player_buildings:
    if not b.is_alive or not b.is_built: continue
    if grid.hex_distance(source_building_pos, b.grid_pos) != 1: continue
    if b.building_type not in [LIGHT_EQUIP, HEAVY_EQUIP, RANGED_EQUIP, KAMIKAZE_EQUIP]:
        continue
    var prev = best_per_type.get(b.building_type, null)
    if prev == null or b.fusion_rank > prev.fusion_rank:
        best_per_type[b.building_type] = b
# best_per_type の値（最大 4 個）でバフ適用
```

これにより「同種 2 個が隣接していても効果は 1 度・ただし高い fusion_rank が選ばれる」ルールが成立する。

### 3.2 融合ランク計算（クラスタ BFS）

#### 計算タイミング

- 装備屋の **建設完了時**（is_built が false→true に変化した瞬間）
- 装備屋の **死亡時**（is_alive が true→false に変化した瞬間）
- EconBattle に `_recalc_fusion_clusters()` メソッドを追加し、上記イベントで呼ぶ

#### アルゴリズム

```gdscript
# EconBattle.gd

func _recalc_fusion_clusters() -> void:
    var equip_types: Array = [
        EconBuilding.BuildingType.LIGHT_EQUIP,
        EconBuilding.BuildingType.HEAVY_EQUIP,
        EconBuilding.BuildingType.RANGED_EQUIP,
        EconBuilding.BuildingType.KAMIKAZE_EQUIP,
    ]
    var visited: Dictionary = {}  # EconBuilding -> true
    var next_cluster_id: int = 0
    for b0 in player_buildings:
        if visited.has(b0): continue
        if not b0.is_alive or not b0.is_built: continue
        if b0.building_type not in equip_types: continue
        # BFS: 同種かつ hex_distance==1 で連結
        var cluster: Array = []
        var queue: Array = [b0]
        visited[b0] = true
        while queue.size() > 0:
            var cur: EconBuilding = queue.pop_front()
            cluster.append(cur)
            for b1 in player_buildings:
                if visited.has(b1): continue
                if not b1.is_alive or not b1.is_built: continue
                if b1.building_type != b0.building_type: continue
                if grid.hex_distance(cur.grid_pos, b1.grid_pos) != 1: continue
                visited[b1] = true
                queue.append(b1)
        # ランク決定
        var rank: int = clampi(cluster.size(), 1, 3)
        for b in cluster:
            b.fusion_rank = rank
            b.fusion_cluster_id = next_cluster_id
            b.queue_redraw()
        next_cluster_id += 1
```

- 計算量: O(N²) （建物数は MVP では数十程度のため許容範囲）
- 実装注意: クラスタの最大サイズが 3 を超えても fusion_rank は 3 にクランプ（クラスタ内全員が Lv3 になる）

### 3.3 Lv3 定性効果の発動・終了条件

#### A. 軽装備屋 Lv3「開幕突進」

- **発動**: ユニット生成時 `_equip_dash_pending = true` がセット
- 突進処理: EconUnit.update() の最初のフレームで以下を実行:
  ```gdscript
  if _equip_dash_pending:
      _equip_dash_pending = false
      var nearest_enemy = _find_nearest_enemy(enemies)
      if nearest_enemy != null:
          var target_pos: Vector2i = nearest_enemy.grid_pos
          # 1 ヘックス手前まで瞬間移動
          var dist: int = grid.hex_distance(grid_pos, target_pos)
          if dist > attack_range:
              # 攻撃可能距離まで近づくよう grid_pos を更新
              # （簡易実装: 最短経路の中間地点へワープ）
              var path: Array = grid.bfs_path(grid_pos, target_pos)
              if path.size() > attack_range:
                  grid_pos = path[path.size() - 1 - attack_range]
                  position = grid.hex_to_pixel(grid_pos.x, grid_pos.y)
  ```
- **終了**: 1 度実行したら `_equip_dash_pending = false`（フラグ自体が終了条件）

#### B. 重装備屋 Lv3「初回被弾無効」

- **発動**: ユニット生成時 `_equip_first_hit_shield = true` がセット
- 適用処理: EconUnit.take_damage(amount) の冒頭:
  ```gdscript
  if _equip_first_hit_shield:
      _equip_first_hit_shield = false
      return  # ダメージを受けない
  ```
- **終了**: 1 度被弾したら `_equip_first_hit_shield = false`

#### C. 遠射装備屋 Lv3「+2 射程追加」

- **発動**: ユニット生成時 `_equip_range_bonus += 2` が追加加算（合計 +3）
- 効果: attack_range への加算で完結（特別な処理不要）
- **終了**: ユニット死亡まで持続

#### D. 特攻装備屋 Lv3「爆風範囲拡大」

- **発動**: ユニット生成時 `_equip_kamikaze_radius = 2`
- 適用処理: EconUnit.die() または HP 0 検知時:
  ```gdscript
  if _equip_kamikaze:
      var radius: int = _equip_kamikaze_radius
      var aoe_damage: float = 30.0
      for e in enemies:
          if grid.hex_distance(grid_pos, e.grid_pos) <= radius:
              e.take_damage(aoe_damage)
      for b in enemy_buildings:
          if grid.hex_distance(grid_pos, b.grid_pos) <= radius:
              b.take_damage(aoe_damage)
  ```
- **終了**: 自爆 1 回で発動・ユニット消滅

---

## 4. 配置・接続ロジック

### 4.1 配置可能セルの計算

- `_update_build_highlight()` 内で 4 装備屋 PlaceMode について fill_cells を計算
- 既存の自陣領土ルール（半径 3・敵領土除外・占有除外）を継承
- 装備屋は資源タイル隣接が不要（KISS）

### 4.2 自動接続の判定

- 装備屋が建設完了 → `_recalc_fusion_clusters()` を呼ぶ
- 隣接する生産建物（BARRACKS / FORTRESS / WORKSHOP）への効果適用は、ユニット生成時に動的に判定
- 「接続」は永続的なリンクではなく、毎回の hex_distance チェック（KISS: 状態を持たない）

### 4.3 装備屋ペア・トリオ形成のフィードバック

- 同種クラスタが Lv2/Lv3 に到達した瞬間に EconMain にログ通知:
  ```gdscript
  # _recalc_fusion_clusters 内、ランク決定時
  if rank == 3 and cluster.size() == 3:
      # 初回 Lv3 到達時のみログ
      log_message.emit("装備屋クラスタ Lv3 到達！")
  ```

---

## 5. UI/UX 要件

### 5.1 建物パネル（Designer 出力反映）

- 4×2 グリッドの **上段（軍事）4 スロット** に装備屋 4 種を配置
  - 上段: BARRACKS / FORTRESS / WORKSHOP / **EQUIPMENT_SHOP（メニュー型）**
- 装備屋は 4 種あるため、上段スロット 1 つに「装備屋メニュー」を 1 個配置し、クリックでサブメニュー（4 個から選択）
  - サブメニュー: PopupMenu または横展開 4 ボタン
- 選択時の枠色（_update_build_card_styles）: COLOR_EQUIP（#A04030・深赤・新規定数）

```gdscript
# 新規定数
const COLOR_EQUIP := Color("#A04030")
```

### 5.2 装備屋の描画

#### 建物本体（_draw）

| バリアント | 基本色 | アイコン | 色コード |
|-----------|-------|--------|---------|
| LIGHT_EQUIP | 銀色 | "L" | #C0C0C0 |
| HEAVY_EQUIP | 鉄色 | "H" | #4A4A4A |
| RANGED_EQUIP | 緑色 | "R" | #5A8A4A |
| KAMIKAZE_EQUIP | 朱色 | "K" | #D04A2A |

- 共通の枠線色: COLOR_EQUIP（#A04030・深赤）— Designer 出力反映
- 描画は既存の `draw_rect` パターンを踏襲

#### ランクバッジ

- 装備屋の右下に Lv バッジを描画
- 位置: Vector2(15, 15)
- サイズ: 半径 7px
- 背景色: 黒（Color(0.1, 0.1, 0.1, 0.85)）
- 文字: "1"/"2"/"3"
- 文字色: COLOR_ACCENT_GOLD（#B49448）

```gdscript
# EconBuilding._draw() に追加
if building_type in [LIGHT_EQUIP, HEAVY_EQUIP, RANGED_EQUIP, KAMIKAZE_EQUIP]:
    var badge_pos: Vector2 = Vector2(15, 15)
    draw_circle(badge_pos, 7.0, Color(0.1, 0.1, 0.1, 0.85))
    draw_string(ThemeDB.fallback_font, badge_pos + Vector2(-3, 4), str(fusion_rank),
        HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#B49448"))
```

### 5.3 接続線描画（Designer 出力反映「金色破線」）

#### 描画対象

- 装備屋 ↔ 隣接生産建物（BARRACKS/FORTRESS/WORKSHOP）の関係線
- 装備屋 ↔ 同種隣接装備屋（融合クラスタ）の関係線

#### 描画仕様

| 項目 | 値 |
|------|----|
| 線種 | 破線 |
| 線色 | 金色 #DAA520（Lv1） / #FFD700（Lv2） / #FFA500（Lv3 強調） |
| 線幅 | 2px（Lv1-2） / 3px（Lv3） |
| ダッシュ長 | 6px |
| アルファ | 0.7 |
| 描画関数 | draw_dashed_line(from_local, to_local, color, width, dash) |

#### 描画箇所

- EconBuilding._draw() 内に分岐を追加
- 描画前に EconMain から `buildings_ref` を渡しておく（EconRallyFlag と同パターン）
- ローカル座標変換: `from_local = b_px - my_px, to_local = Vector2.ZERO`

```gdscript
# EconBuilding._draw() に追加（装備屋専用ブロック）
if building_type in EQUIP_TYPES and buildings_ref != null:
    var my_px: Vector2 = ... # 自身のピクセル位置
    for b in buildings_ref:
        if not b.is_alive or not b.is_built: continue
        var dist: int = grid_ref.hex_distance(grid_pos, b.grid_pos)
        if dist != 1: continue
        # 生産建物との接続線（金色）
        if b.building_type in [BARRACKS, FORTRESS, WORKSHOP]:
            var b_px: Vector2 = ...
            var color: Color = _get_fusion_line_color(fusion_rank)
            draw_dashed_line(b_px - my_px, Vector2.ZERO, color, 2.0, 6.0)
        # 同種クラスタ線（より太く）
        elif b.building_type == building_type:
            var b_px2: Vector2 = ...
            draw_dashed_line(b_px2 - my_px, Vector2.ZERO, Color("#FFA500"), 3.0, 6.0)
```

#### 重複描画の回避

- A→B と B→A の両側から線を描くと重なるが、視覚的に問題なし（KISS: 重複許容）

### 5.4 アクティブ状態のハイライト

- Lv3 到達時の装備屋: 枠線を 2px → 3px に拡張・色を金色（#FFD700）に変更
- バトル中常時表示（Designer 出力「自動接続表示」反映）

```gdscript
# _draw() 内
if fusion_rank >= 3:
    draw_rect(Rect2(Vector2(-18, -18), Vector2(36, 36)), Color("#FFD700"), false, 3.0)
```

### 5.5 配置時のツールチップ

- 装備屋 PlaceMode 時、配置可能ヘックスにマウスホバー
- ツールチップ: 「[バリアント名]：[基本効果]（Lv3 で [定性効果]）」
- 現状の `_place_hint_label` を装備屋用テキストに切り替え
- 例: "軽装備屋: 隣接兵舎ユニットの移動速度+20%（Lv3 で開幕突進）"

---

## 6. 実装対象ファイル

| ファイル | 変更内容 | 規模目安 |
|---------|---------|---------|
| scripts/econ_mvp/EconBuilding.gd | enum 拡張・BUILD_COSTS/HP/CONSTRUCTION 拡張・fusion_rank フィールド・_draw 装備屋分岐・接続線描画・ランクバッジ | +120 行 |
| scripts/econ_mvp/EconUnit.gd | _equip_* フィールド群・take_damage の盾フラグ分岐・update の dash 分岐・die の自爆処理 | +80 行 |
| scripts/econ_mvp/EconBattle.gd | _recalc_fusion_clusters() メソッド・_apply_equipment_buffs(unit, source_pos) メソッド・unit_produced ハンドラから呼び出し | +90 行 |
| scripts/econ_mvp/EconMain.gd | PlaceMode 拡張・装備屋サブメニュー UI・建物パネル上段への配置・ハイライトロジックへの装備屋追加・ツールチップ | +180 行 |
| scripts/econ_mvp/EconAI.gd | AI 用 _recalc_fusion_clusters の呼び出し追加（敵側装備屋対応・将来拡張） | +20 行 |

### ファイルサイズ予防チェック

- EconMain.gd: 交易所要件と合計で +380 行 → 1480 行予測
  - **800 行を超える肥大化が確実なため、装備屋サブメニューは別クラス分離を推奨**
  - 新規: `scripts/econ_mvp/EconEquipmentMenu.gd`（PopupMenu 実装・約 80 行）
- EconBuilding.gd: +120 行で 340 行 → 500 行未満で許容範囲
- EconBattle.gd: +90 行で 250 行前後 → 許容範囲

### 推奨ファイル分離

| 新規ファイル | 役割 | 規模目安 |
|------------|------|---------|
| scripts/econ_mvp/EconEquipmentMenu.gd | 装備屋 4 バリアント選択 PopupMenu | +80 行 |

---

## 7. 制約・注意事項

### 7.1 疎結合ルール（CLAUDE.md 準拠）

- EconBattle が EconUnit の `_equip_*` フィールドに直接代入するのは唯一の例外として許容（unit 生成直後の初期化時のみ）
- 別案: `unit.apply_equipment_buff(building_type: int, rank: int)` メソッドを EconUnit に追加し、EconBattle はそれを呼ぶ
- **本要件では後者（メソッド経由）を採用**: 疎結合ルールを厳守

```gdscript
# EconUnit.gd に追加
func apply_equipment_buff(equip_type: int, rank: int) -> void:
    match equip_type:
        EconBuilding.BuildingType.LIGHT_EQUIP:
            _equip_speed_mult *= 1.2
            move_spd *= 1.2
            if rank >= 3: _equip_dash_pending = true
        EconBuilding.BuildingType.HEAVY_EQUIP:
            _equip_hp_mult *= 1.3
            max_hp *= 1.3
            hp = max_hp
            if rank >= 3: _equip_first_hit_shield = true
        # ... 同様
```

### 7.2 設計整合性

- 「廃止済み設計」（CLAUDE.md）への抵触なし
  - 盤面召喚復活ではない（生成は既存の生産建物・装備屋は能力修飾のみ）
  - アクティブスキル復活ではない（パッシブバフのみ）
  - 行範囲攻撃復活ではない（射程拡張は既存 attack_range への加算のみ）
- 3 秒ルール: 装備屋色・接続線色・ランクバッジで Lv が 3 秒で伝わる

### 7.3 既存システムとの整合性

- ラリーフラグ（req_econ_rally_point.md）と独立: 装備屋はラリー接続対象外
- 配置ボーナス（req_econ_building_variants.md）と独立: 装備屋は生産しないため `_placement_bonus_active` の対象外
- 集中建設モード（既存）の対象に含める: build_priority 継承
- ユニット移動速度 2 倍（既存・req_econ_building_variants.md §4）との掛け合わせ:
  - LIGHT_EQUIP +20% = 0.62 × 1.2 = 0.744（ATTACKER）
  - 上限なし（KISS: 加算ではなく乗算なので暴走しにくい）

### 7.4 バランス調整余地

- 各装備屋の倍率（1.2 / 1.3）は const として定義し、後で一括調整可能にする
- Lv3 定性効果の数値（爆風 30 ダメージ・盾 1 回・射程 +2）も const 化
- 建設コストは初期値・実プレイで微調整想定

### 7.5 敵側 AI の装備屋対応

- 敵 AI は当面装備屋を建設しない（Phase 1 スコープ外）
- 将来の AI 拡張余地として `EconAI._recalc_fusion_clusters()` のフックは用意するが、実装はスタブのみ

---

## 8. 完了定義（Checker チェックリスト）

- [ ] EconBuilding.BuildingType に 4 装備屋（LIGHT/HEAVY/RANGED/KAMIKAZE_EQUIP）が追加されている
- [ ] BUILD_COSTS / BUILD_HP / REQUIRED_CONSTRUCTION に 4 エントリが追加されている
- [ ] EconBuilding に fusion_rank / fusion_cluster_id フィールドがある
- [ ] EconUnit に _equip_speed_mult / _equip_hp_mult / _equip_range_bonus / _equip_kamikaze / _equip_kamikaze_radius / _equip_dash_pending / _equip_first_hit_shield フィールドがある
- [ ] EconUnit.apply_equipment_buff(equip_type, rank) メソッドが追加されている（メソッド経由・疎結合）
- [ ] EconBattle._recalc_fusion_clusters() が建設完了・死亡で呼ばれる
- [ ] EconBattle._apply_equipment_buffs(unit, source_pos) がユニット生成時に呼ばれる
- [ ] 同種クラスタ 1 棟=Lv1 / 2 棟=Lv2 / 3 棟以上=Lv3 でランクが設定される
- [ ] 異種装備屋が同じ生産建物に隣接時、効果が独立加算される
- [ ] 同種隣接 2 個でも 1 種 1 回しか加算されない（best_per_type ロジック）
- [ ] 軽 Lv3: spawn 直後に最寄り敵手前まで瞬間移動する
- [ ] 重 Lv3: 初回被弾でダメージが 0・以降は通常通り
- [ ] 遠射 Lv3: attack_range が +3 加算される
- [ ] 特攻 Lv3: 死亡時の自爆 AOE 半径が 2 になる
- [ ] 建物パネル上段 4 スロット目に装備屋メニュー（4 種選択）が配置されている
- [ ] 装備屋の枠色が COLOR_EQUIP（#A04030）になっている
- [ ] 装備屋の右下に Lv バッジ（金色文字）が表示される
- [ ] 装備屋 ↔ 生産建物の接続線が金色破線で描画される
- [ ] 装備屋 ↔ 同種装備屋のクラスタ線が太い金色破線で描画される
- [ ] Lv3 装備屋の枠線が 3px・金色（#FFD700）で強調される
- [ ] 配置時のツールチップに「[名前]：基本効果（Lv3 で 定性効果）」が表示される
- [ ] EconEquipmentMenu.gd が新規ファイルとして分離されている
- [ ] check_syntax.sh が通る
- [ ] CEO 承認済み
