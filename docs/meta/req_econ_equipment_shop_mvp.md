# 要件定義書: EconMVP 装備屋 MVP（突 / 守 / 崩 ・ 異種加算 + 融合ランク）

更新日: 2026-05-01
STATUS: 企画確定（Planning 2026-05-01）・MVP実装対象

参考（旧版・統合元）:
- docs/meta/req_econ_equipment_shop.md（4バリアント・複雑効果版・本文書で再構成）

---

## 0. スコープ

EconMVP に新規建物群「装備屋（Equipment Shop）」を **3種** 追加する。

- 異種加算（Lv1）: 種類が違えば独立加算（ATK/HP/SPD のいずれか +20%）
- 融合ランク Lv3（同種3棟以上隣接）: 種類別の定性強化

### 核となる体験との整合性

- 「設計して観戦する」: 配置の組み合わせがバトル前に決まり、戦闘で答え合わせ
- 「配分の答え合わせ」: 装備屋種別と隣接設計が戦況を作る
- KISS原則: 3種固定・効果は加算+Lv3定性のみ・隣接判定は既存 hex_distance を流用

### スコープ外（将来）

- 軽/特攻装備屋（旧版 4 種設計）の復活
- 5種以上のバリアント追加
- 装備屋同士の異種ランク（複合効果）
- ユニット個別の装備変更 UI（自動接続のみ）

---

## 1. 概要

### 1.1 3バリアント定義

| # | バリアント名 | 異種加算（Lv1） | オーラ色 | 融合ランク Lv3 効果 | 適用対象ユニット |
|---|-------------|----------------|---------|---------------------|----------------|
| A | 突装備屋（ATK_EQUIP） | atk +20%（乗算） | 赤（#D03030） | 射程 +1 + min_range = 0 化 | ATTACKER / TANK / BREAKER（全ユニット） |
| B | 守装備屋（DEF_EQUIP） | max_hp +20%（乗算） | 青（#3060D0） | max_hp が +50% に強化（Lv1の +20% を置換）+ move_spd ×0.7 | ATTACKER / TANK / BREAKER（全ユニット） |
| C | 崩装備屋（SPD_EQUIP） | move_spd +20%（乗算） | 緑（#30C050） | move_spd が +50% に強化（Lv1の +20% を置換）+ max_hp ×0.7 | ATTACKER / TANK / BREAKER（全ユニット） |

#### Lv1↔Lv3 の効果遷移ルール

| バリアント | Lv1 | Lv3 |
|-----------|-----|-----|
| 突 | atk ×1.20 | atk ×1.20 + 射程 +1 + min_range = 0 |
| 守 | max_hp ×1.20 | max_hp ×1.50 + move_spd ×0.7 |
| 崩 | move_spd ×1.20 | move_spd ×1.50 + max_hp ×0.7 |

- 守・崩の Lv3 は **Lv1 の倍率を置き換える**（×1.20 と ×1.50 の二重適用はしない）
- 突は加算（射程 +1）が追加されるが atk 倍率は変わらない

### 1.2 メカニクス概要

#### 異種加算（Cross-type Addition）

- **異なる種類**の装備屋が同じ生産建物に隣接すると、各装備屋の効果が独立に加算される
- 例: 兵舎が「突 + 守」に隣接 → ATTACKER に atk ×1.20 かつ max_hp ×1.20
- 装備屋同士の隣接関係ではなく、**装備屋 → 生産建物の隣接** で判定

#### 融合ランク（Fusion Rank）

- **同種**の装備屋が隣接（装備屋↔装備屋の hex_distance == 1）するとクラスタ形成
- クラスタ内の装備屋数で Lv 決定:
  - 1 棟: Lv1（基本効果のみ）
  - 2 棟: Lv2（基本効果のみ・効果量は変わらず）
  - 3 棟以上: Lv3（**定性効果が発動・倍率も置換**）
- Lv2 は中間段階として効果量変化を持たない（KISS: Lv1↔Lv3 の 2 段階モデル）
- クラスタ計算は BFS（後述§3.2）

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
# enum BuildingType に 3 種追加（並び維持・末尾追加）
enum BuildingType {
    BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE,
    ATK_EQUIP, DEF_EQUIP, SPD_EQUIP   # 本要件
}

# BUILD_COSTS / BUILD_HP / REQUIRED_CONSTRUCTION
# 7: ATK_EQUIP {"wood": 5, "sulfur": 3}, HP 80,  構築 6.0 秒
# 8: DEF_EQUIP {"wood": 4, "stone": 5},  HP 120, 構築 8.0 秒
# 9: SPD_EQUIP {"wood": 5, "sulfur": 3}, HP 80,  構築 6.0 秒
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

# 装備屋から付与されるバフ倍率・加算値（生成時に EconBattle が初期化）
var _equip_atk_mult: float = 1.0          # 突: atk 乗算
var _equip_hp_mult: float = 1.0           # 守: max_hp 乗算
var _equip_speed_mult: float = 1.0        # 崩: move_spd 乗算
var _equip_range_bonus: int = 0           # 突 Lv3: 射程 +1
var _equip_min_range_zero: bool = false   # 突 Lv3: min_range = 0
```

### 2.3 EconBuilding.update のシグネチャ既存維持

`update(delta, economy, buildings, grid)` は既存のまま。装備屋自体は生産しないため `_update_equipment()` は **no-op**（パッシブ建物）。

---

## 3. 実装仕様

### 3.1 装備屋効果の適用タイミング

ユニット生成時（`unit_produced.emit(grid_pos, utype)` の直後）に EconBattle が以下を実行する。

#### 同種重複適用の防止（best_per_type）

```gdscript
# EconBattle.gd
func _apply_equipment_buffs(unit: EconUnit, source_building_pos: Vector2i) -> void:
    var grid: EconGrid = self.grid
    var equip_types: Array = [
        EconBuilding.BuildingType.ATK_EQUIP,
        EconBuilding.BuildingType.DEF_EQUIP,
        EconBuilding.BuildingType.SPD_EQUIP,
    ]
    # 種別ごとに「最大 fusion_rank の装備屋」を選定（同種 2 棟隣接時の二重適用回避）
    var best_per_type: Dictionary = {}  # BuildingType -> EconBuilding
    for b in player_buildings:
        if not b.is_alive or not b.is_built: continue
        if grid.hex_distance(source_building_pos, b.grid_pos) != 1: continue
        if not (b.building_type in equip_types): continue
        var prev = best_per_type.get(b.building_type, null)
        if prev == null or b.fusion_rank > prev.fusion_rank:
            best_per_type[b.building_type] = b
    # 適用（疎結合: メソッド経由）
    for btype in best_per_type.keys():
        var b: EconBuilding = best_per_type[btype]
        unit.apply_equipment_buff(btype, b.fusion_rank)
```

#### EconUnit.apply_equipment_buff（疎結合・メソッド経由）

```gdscript
# EconUnit.gd
func apply_equipment_buff(equip_type: int, rank: int) -> void:
    match equip_type:
        EconBuilding.BuildingType.ATK_EQUIP:
            _equip_atk_mult *= 1.20
            atk *= 1.20
            if rank >= 3:
                _equip_range_bonus += 1
                attack_range += 1
                _equip_min_range_zero = true
                # min_range フィールドが存在する場合のみ反映
                if "min_range" in self:
                    min_range = 0
        EconBuilding.BuildingType.DEF_EQUIP:
            if rank >= 3:
                _equip_hp_mult *= 1.50
                max_hp *= 1.50
                hp = max_hp
                _equip_speed_mult *= 0.70
                move_spd *= 0.70
            else:
                _equip_hp_mult *= 1.20
                max_hp *= 1.20
                hp = max_hp
        EconBuilding.BuildingType.SPD_EQUIP:
            if rank >= 3:
                _equip_speed_mult *= 1.50
                move_spd *= 1.50
                _equip_hp_mult *= 0.70
                max_hp *= 0.70
                hp = max_hp
            else:
                _equip_speed_mult *= 1.20
                move_spd *= 1.20
```

#### 重要

- 異種加算 = 各 case 文が独立に発火するため、ループ 1 周で複数効果が積算される
- 同種 2 個隣接（Lv1 同士）は best_per_type で 1 回しか加算されない
- 守・崩の Lv3 は Lv1 倍率と排他（×1.20 と ×1.50 の二重適用なし・rank で分岐）

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
        EconBuilding.BuildingType.ATK_EQUIP,
        EconBuilding.BuildingType.DEF_EQUIP,
        EconBuilding.BuildingType.SPD_EQUIP,
    ]
    var visited: Dictionary = {}
    var next_cluster_id: int = 0
    for b0 in player_buildings:
        if visited.has(b0): continue
        if not b0.is_alive or not b0.is_built: continue
        if not (b0.building_type in equip_types): continue
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
        var rank: int = clampi(cluster.size(), 1, 3)
        for b in cluster:
            b.fusion_rank = rank
            b.fusion_cluster_id = next_cluster_id
            b.queue_redraw()
        next_cluster_id += 1
```

- 計算量: O(N²)（建物数は MVP では数十程度のため許容範囲）
- クラスタサイズ 4 以上でも fusion_rank は 3 にクランプ

---

## 4. 配置・接続ロジック

### 4.1 配置可能セルの計算

- `_update_build_highlight()` 内で 3 装備屋 PlaceMode について fill_cells を計算
- 既存の自陣領土ルール（半径3・敵領土除外・占有除外）を継承
- 装備屋は資源タイル隣接が不要（KISS）

### 4.2 自動接続の判定

- 装備屋が建設完了 → `_recalc_fusion_clusters()` を呼ぶ
- 隣接する生産建物（BARRACKS / FORTRESS / WORKSHOP）への効果適用は、ユニット生成時に動的判定
- 「接続」は永続的なリンクではなく、毎回の hex_distance チェック（KISS: 状態を持たない）

### 4.3 EconRallyFlag システムとの統合

- ラリーフラグは「ユニット集合点指定」、装備屋は「ユニット強化」と責務が独立
- **装備屋はラリー接続対象外**: 装備屋 ↔ ラリーフラグ間の接続線・効果は描画しない
- ラリーフラグの既存ロジック（connected_flag_id）には触れない
- 装備屋から生まれたバフユニットは、生産建物のラリーフラグ設定に従って移動する

---

## 5. UI/UX 要件

### 5.1 建物パネル

- 既存パネルに 3 ボタン追加（突 / 守 / 崩）
- 配置順は WORKSHOP の右隣以降（既存の並び維持）
- 選択時の枠色:
  - 突: 赤（#D03030）
  - 守: 青（#3060D0）
  - 崩: 緑（#30C050）

### 5.2 装備屋の描画（オーラ + アイコン）

| バリアント | 本体色 | アイコン | オーラ色（半透明円） |
|-----------|-------|--------|---------------------|
| ATK_EQUIP | 赤系（#A03030） | "突" | Color(0.82, 0.18, 0.18, 0.35) |
| DEF_EQUIP | 青系（#304080） | "守" | Color(0.18, 0.38, 0.82, 0.35) |
| SPD_EQUIP | 緑系（#306030） | "崩" | Color(0.18, 0.75, 0.31, 0.35) |

#### 描画仕様

```gdscript
# EconBuilding._draw() に追加
const EQUIP_TYPES = [BuildingType.ATK_EQUIP, BuildingType.DEF_EQUIP, BuildingType.SPD_EQUIP]
if building_type in EQUIP_TYPES and is_built:
    # オーラ（半透明の大きな円）
    var aura_color: Color = _get_aura_color(building_type)
    draw_circle(Vector2.ZERO, 28.0, aura_color)
    # 本体（既存 draw_rect の色に上書き）
    # 文字（突/守/崩）
    var icon_text: String = _get_icon_text(building_type)
    draw_string(ThemeDB.fallback_font, Vector2(-7, 5), icon_text,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
```

### 5.3 ランクバッジ

- 装備屋の右下に Lv バッジを描画
- 位置: Vector2(15, 15)
- サイズ: 半径 7px
- 背景色: 黒（Color(0.1, 0.1, 0.1, 0.85)）
- 文字: "1" / "2" / "3"
- 文字色: Color("#FFD700")（金色）

```gdscript
if building_type in EQUIP_TYPES:
    var badge_pos: Vector2 = Vector2(15, 15)
    draw_circle(badge_pos, 7.0, Color(0.1, 0.1, 0.1, 0.85))
    draw_string(ThemeDB.fallback_font, badge_pos + Vector2(-3, 4), str(fusion_rank),
        HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#FFD700"))
```

### 5.4 接続線描画（金色破線）

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
| 描画関数 | `draw_dashed_line(from_local, to_local, color, width, dash)` |

#### 描画箇所

- EconBuilding._draw() 内の装備屋専用ブロックに追加
- 描画前に EconMain から `buildings_ref` を渡しておく（既存の他システム同パターン）
- ローカル座標変換: `from_local = b_px - my_px, to_local = Vector2.ZERO`
- 重複描画は許容（A→B、B→A の両側から線を描く）

### 5.5 アクティブ状態のハイライト（Lv3）

- Lv3 到達時の装備屋: 枠線を 2px → 3px に拡張・色を金色（#FFD700）に変更
- バトル中常時表示

```gdscript
if fusion_rank >= 3:
    draw_rect(Rect2(Vector2(-18, -18), Vector2(36, 36)), Color("#FFD700"), false, 3.0)
```

### 5.6 配置時のツールチップ

- 装備屋 PlaceMode 時、配置可能ヘックスにマウスホバー
- ツールチップ: 「[バリアント名]：[基本効果]（Lv3 で [Lv3 効果]）」
- 例:
  - "突装備屋: 隣接生産建物のユニットに ATK +20%（Lv3 で射程 +1・近接攻撃可）"
  - "守装備屋: 隣接生産建物のユニットに HP +20%（Lv3 で HP +50% / 移動速度 ×0.7）"
  - "崩装備屋: 隣接生産建物のユニットに SPD +20%（Lv3 で SPD +50% / HP ×0.7）"

---

## 6. 実装対象ファイル

| ファイル | 変更内容 | 規模目安 |
|---------|---------|---------|
| scripts/econ_mvp/EconBuilding.gd | enum 拡張・BUILD_COSTS/HP/CONSTRUCTION 拡張・fusion_rank フィールド・_draw 装備屋分岐・接続線描画・ランクバッジ・オーラ | +110 行 |
| scripts/econ_mvp/EconUnit.gd | _equip_* フィールド群・apply_equipment_buff(equip_type, rank) メソッド | +50 行 |
| scripts/econ_mvp/EconBattle.gd | _recalc_fusion_clusters() メソッド・_apply_equipment_buffs(unit, source_pos) メソッド・unit_produced ハンドラから呼び出し | +80 行 |
| scripts/econ_mvp/EconMain.gd | PlaceMode 拡張・建物パネル 3 ボタン追加・ハイライトロジックへの装備屋追加・ツールチップ | +80 行 |
| scripts/econ_mvp/EconAI.gd | （MVP では敵側装備屋なし・スタブのみ） | +0 行 |

### ファイルサイズ予防チェック

| ファイル | 現行行数 | 追加後予測 | 判定 |
|---------|---------|-----------|------|
| EconBuilding.gd | 約 220 行 | 約 330 行 | 500 行未満・許容 |
| EconUnit.gd | （要確認） | +50 行 | 500 行超なら別途対応 |
| EconBattle.gd | （要確認） | +80 行 | 500 行超なら別途対応 |
| EconMain.gd | 既存肥大傾向あり | +80 行 | **800 行超予測なら定数ファイル分離検討** |

実装着手時に Implementer が `wc -l` で確認すること。

---

## 7. 制約・注意事項

### 7.1 疎結合ルール（CLAUDE.md 準拠）

- EconBattle が EconUnit の `_equip_*` フィールドに直接代入しない
- 必ず `unit.apply_equipment_buff(equip_type, rank)` メソッド経由
- EconBuilding ↔ EconBattle 間も同様（fusion_rank の読み取りのみ・直接代入なし）

### 7.2 既存設計との整合性

- 「廃止済み設計」（CLAUDE.md）への抵触なし
  - 盤面召喚復活ではない（生成は既存の生産建物・装備屋は能力修飾のみ）
  - アクティブスキル復活ではない（パッシブバフのみ）
  - 行範囲攻撃復活ではない（射程拡張は既存 attack_range への加算のみ）
- 3 秒ルール: 装備屋オーラ色（赤/青/緑）+ ランクバッジで Lv が 3 秒で伝わる
- ラリーフラグ（req_econ_rally_point.md）と独立: 装備屋はラリー接続対象外
- 配置ボーナス（req_econ_building_variants.md）と独立: 装備屋は生産しないため `_placement_bonus_active` の対象外

### 7.3 ユニット生産改修との整合

- 本要件と並行して「ユニット生産ハーベスター供給化（req_econ_unit_production_harvester.md）」が実施される
- 装備屋バフ適用は **ユニット生成時** の独立フェーズ（リソース消費とは別）
- ハーベスターからリソース受け取り → 生産トリガ → ユニット生成 → `_apply_equipment_buffs()` の順序を保つ

### 7.4 バランス調整余地

- 各倍率（1.20 / 1.50 / 0.70）は const として定義し、後で一括調整可能にする
- 建設コストは初期値・実プレイで微調整想定

```gdscript
# EconBuilding.gd または専用定数ファイル
const EQUIP_BUFF_LV1 := 1.20
const EQUIP_BUFF_LV3 := 1.50
const EQUIP_PENALTY_LV3 := 0.70
```

### 7.5 敵側 AI の装備屋対応

- 敵 AI は当面装備屋を建設しない（MVP スコープ外）
- 将来の AI 拡張余地として `EconAI._recalc_fusion_clusters()` のフックは用意するが、本要件では実装しない

---

## 8. 完了定義（Checker チェックリスト）

- [ ] EconBuilding.BuildingType に 3 装備屋（ATK / DEF / SPD_EQUIP）が追加されている
- [ ] BUILD_COSTS / BUILD_HP / REQUIRED_CONSTRUCTION に 3 エントリが追加されている
- [ ] EconBuilding に fusion_rank / fusion_cluster_id フィールドがある
- [ ] EconUnit に _equip_atk_mult / _equip_hp_mult / _equip_speed_mult / _equip_range_bonus / _equip_min_range_zero フィールドがある
- [ ] EconUnit.apply_equipment_buff(equip_type, rank) メソッドが追加されている（疎結合・メソッド経由）
- [ ] EconBattle._recalc_fusion_clusters() が建設完了・死亡で呼ばれる
- [ ] EconBattle._apply_equipment_buffs(unit, source_pos) がユニット生成時に呼ばれる
- [ ] 同種クラスタ 1 棟=Lv1 / 2 棟=Lv2 / 3 棟以上=Lv3 でランクが設定される
- [ ] 異種装備屋が同じ生産建物に隣接時、効果が独立加算される
- [ ] 同種隣接 2 個でも 1 種 1 回しか加算されない（best_per_type ロジック）
- [ ] 突 Lv1: atk ×1.20
- [ ] 突 Lv3: atk ×1.20 + attack_range +1 + min_range = 0
- [ ] 守 Lv1: max_hp ×1.20
- [ ] 守 Lv3: max_hp ×1.50 + move_spd ×0.70（Lv1の ×1.20 は適用しない）
- [ ] 崩 Lv1: move_spd ×1.20
- [ ] 崩 Lv3: move_spd ×1.50 + max_hp ×0.70（Lv1の ×1.20 は適用しない）
- [ ] 装備屋のオーラ色が赤/青/緑で描画される
- [ ] 装備屋の右下に Lv バッジ（金色文字）が表示される
- [ ] 装備屋 ↔ 生産建物の接続線が金色破線で描画される
- [ ] 装備屋 ↔ 同種装備屋のクラスタ線が太い金色破線で描画される
- [ ] Lv3 装備屋の枠線が 3px・金色（#FFD700）で強調される
- [ ] 配置時のツールチップに「[名前]：基本効果（Lv3 で 効果）」が表示される
- [ ] check_syntax.sh が通る
- [ ] CEO 承認済み
