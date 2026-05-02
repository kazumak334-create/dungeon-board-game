# 鍛冶屋（SMITHY）建物 要件定義書

| 項目 | 内容 |
|------|------|
| プロジェクト | Econ MVP v0.2 |
| 上位設計（SSoT） | docs/GAME_DESIGN_V0_2_MVP.md（§3 建物、§4.4 建物一覧、§4.5 鍛冶屋詳細、§4.8 建物Lv強化） |
| 上位要件 | docs/requirements/REQUIREMENTS_V0_2_MVP.md（§2.5.9 隣接兵舎へのDPS強化、§2.6 戦闘、§2.7 建物一覧テーブル） |
| タスク | 「鍛冶屋（SMITHY）実装」 |
| 更新日 | 2026-05-02 |
| ステータス | DRAFT（CEO承認待ち） |
| 実装ディレクトリ | scripts/econ_mvp/ |

---

## 1. 概要・目的

### 1.1 目的
GAME_DESIGN §4.4 / §4.5 で定義された未実装建物「鍛冶屋（SMITHY）」を Econ MVP に追加する。隣接する兵舎から出撃するユニットの DPS を強化することで、「兵舎を中心とした軍事クラスタ設計」という配置パズル的な選択肢を成立させる。

### 1.2 核となる体験との整合
- 「盤面を設計する」：兵舎の隣に鍛冶屋を置くか、別の生産建物を置くかの配置選択
- 「介入を仕込む」：稼働人口1を鍛冶屋に割くか、他の生産建物に回すかの判断
- 「答え合わせを観戦する」：突撃時に強化済みユニットが出撃する（出撃時固定バフのため、戦闘画面でDPS差として可視化される）
- 3秒ルール：効果は「隣接兵舎のユニット火力を底上げ」のみ。視認性が高い

### 1.3 GAME_DESIGN §4.5 の該当記述（引用）
> **種別**：アクティブ型
> **必要稼働人口**：1
> **対象**：隣接する兵舎
> **効果**：隣接兵舎から出撃するユニットのDPS+X%
> **Lv別効果**：Lv1：+10% / Lv2：+15% / Lv3：+20%
> **適用タイミング**：ユニット化して出撃する時
> **対象出撃**：任意突撃・最終突撃・防衛拠点による防衛出撃
> **非稼働時**：効果なし
> **複数隣接時**：最も高いLvの効果のみ適用（重複しない）

### 1.4 REQUIREMENTS §2.5.9 の該当記述（引用）
> 鍛冶屋（アクティブ型・必要稼働人口1）が隣接兵舎のユニットDPSを強化
> Lv1: DPS +10% / Lv2: +15% / Lv3: +20%
> 適用タイミング：ユニット化して出撃する時
> 対象出撃：任意突撃・最終突撃・防衛拠点による防衛出撃
> 非稼働時：効果なし
> 複数隣接時：最も高いLvの効果のみ適用（重複しない）

---

## 2. 変更対象ファイル

### 2.1 触ってよいファイル
| ファイル | 変更内容 |
|---|---|
| scripts/econ_mvp/EconBuilding.gd | enum 値追加（SMITHY）・定数追加（DPS係数）・BUILD_COSTS/BUILD_HP/REQUIRED_CONSTRUCTION 追記・_update_smithy 関数追加・match 分岐追加・_draw 着色追加・隣接兵舎強化用ヘルパー追加 |
| scripts/econ_mvp/EconUnit.gd | `apply_smithy_buff(rank: int)` メソッド追加（既存 `apply_equipment_buff` パターンに倣う・疎結合のためメソッド経由でバフ適用） |
| scripts/econ_mvp/EconBattle.gd | ユニット生成（兵力 → ユニット変換）時に「生産元兵舎の隣接鍛冶屋Lv」を取得し `apply_smithy_buff` を呼ぶ統合点を追加（**MVPでの最小フック箇所のみ**） |
| data/cards_econ.json | SMITHY のカード定義を追加 |
| docs/CHANGELOG.md | 実装後に PMO が完了記録を追記 |
| docs/roadmap.md | 実装後に PMO がタスク状態を更新 |

### 2.2 触らないファイル（明示的な禁止）
| ファイル | 理由 |
|---|---|
| scripts/econ_mvp/EconEconomy.gd | 鍛冶屋自体は資源を生産・消費しないため改変不要 |
| scripts/econ_mvp/EconGrid.gd | hex_distance を読み取りのみで使用 |
| scripts/econ_mvp/EconRallyFlag.gd | 旗状態の読み取りのみ・改変なし |
| scripts/econ_mvp/EconHarvester.gd | 鍛冶屋はハーベスター系建物ではない |

### 2.3 関連 enum・命名規則
- enum 名：`BuildingType.SMITHY`（REQUIREMENTS §2.6 / GAME_DESIGN §4.4 に準拠）
- 用語：日本語表記「鍛冶屋」、英語コード上は `SMITHY`
- **重要**：既存 `EconBuilding.gd` enum には `FORGE` も `SMITHY` も未定義。本要件で **`SMITHY`** で確定する（要件定義書の正式英名と一致）

---

## 3. 仕様テーブル

### 3.1 建物基本仕様

| 項目 | 値 | 根拠 |
|---|---|---|
| 種別 | アクティブ型 | GAME_DESIGN §4.3, §4.4, §4.5 |
| 必要稼働人口 | 1 | GAME_DESIGN §4.5 |
| 建設コスト（Lv1） | 木材4 / 石材4 / 硫黄2 | **要確認**（GAME_DESIGN §12.3 で TBD。装備屋 EQUIPMENT_SHOP=木材5/硫黄3 と兵舎 BARRACKS=木材8 の中間として提案） |
| 必要作業量（Lv1） | 6.0 | **要確認**（装備屋=6.0 と同水準で提案） |
| 初期 HP | 80.0 | **要確認**（装備屋・市場と同じ生産系建物の標準値で提案） |
| パッシブ効果 | なし | アクティブ型のため・稼働人口1 必須 |

### 3.2 効果仕様（隣接兵舎DPS強化）

| 項目 | Lv1 | Lv2 | Lv3 | 根拠 |
|---|---:|---:|---:|---|
| DPS強化倍率 | ×1.10 | ×1.15 | ×1.20 | GAME_DESIGN §4.5, §4.8 |
| 稼働条件 | 必要稼働人口1を満たす | 同左 | 同左 | GAME_DESIGN §4.5 |
| 対象 | 隣接兵舎（hex_distance=1） | 同左 | 同左 | GAME_DESIGN §4.5 |
| 適用タイミング | ユニット化して出撃する時 | 同左 | 同左 | GAME_DESIGN §4.5 |
| 強化の継続 | 出撃済みユニットには再計算しない（出撃時固定） | 同左 | 同左 | 本要件 §4.4 で確定 |

> **方針（2026-05-02）**：本MVPでは **Lv1（+10%）のみ実装**。Lv2/Lv3 の効果値は方向性のみ記載し、具体実装は次期MVPで設計する（建物Lv強化システムが MVP 未実装のため）。

### 3.3 強化コスト（GAME_DESIGN §4.8 準拠・参考）

| Lv | 強化コスト | 効果差分 |
|---|---|---|
| Lv1→Lv2 | 建設コストの 50%（端数切り上げ） | DPS +10% → +15% |
| Lv2→Lv3 | 建設コストの 100% | DPS +15% → +20% |

**本MVPでは強化システム未実装のため、Lv1 固定で運用する**（要件 §6 検証条件）。

### 3.4 既存建物との比較（参考）

| 建物 | 木材 | 石材 | 硫黄 | 必要作業量 | 初期 HP |
|---|---:|---:|---:|---:|---:|
| BARRACKS（兵舎） | 8 | 0 | 0 | 5.0 | 100.0 |
| EQUIPMENT_SHOP（装備屋） | 5 | 0 | 3 | 6.0 | 80.0 |
| TRADE_POST（市場） | 5 | 5 | 0 | 5.0 | 80.0 |
| **SMITHY（鍛冶屋・本要件）** | **4** | **4** | **2** | **6.0** | **80.0** |

> 鍛冶屋は「兵舎を強化する補助建物」のため、兵舎本体より軽量・装備屋と同水準の難度を提案。

### 3.5 複数鍛冶屋隣接時の挙動（GAME_DESIGN §4.5 確定事項）

> 複数の鍛冶屋が同じ兵舎に隣接している場合、**最も高いLvの効果のみ適用**（重複しない）。

実装：兵舎ユニット出撃時に「隣接する稼働中鍛冶屋」を全列挙し、`max(rank)` を採用。

### 3.6 鍛冶屋稼働条件の詳細

| 条件 | 必須 | 備考 |
|---|---|---|
| `is_built == true` | YES | 建設完了済 |
| `is_alive == true` | YES | HP > 0 |
| 必要稼働人口1が割り当て済 | YES | EconEconomy 側で稼働判定（既存ロジックに準拠） |
| 建物Lv（exchange_level 相当の smithy_level）| YES | MVPは 1 固定 |

**いずれか一つでも欠けたら効果なし**（出撃時の隣接判定で対象外扱い）。

---

## 4. EconBuilding.gd への追加内容

### 4.1 enum BuildingType への追加
既存（EconBuilding.gd:4）：
```gdscript
enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE, EQUIPMENT_SHOP, TRADE_POST, WALL, PLAZA, HOUSE, EXCHANGE, LIBRARY, LIBRARY_ADV, MUSEUM, ART_GALLERY }
```

変更後：
```gdscript
enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE, EQUIPMENT_SHOP, TRADE_POST, WALL, PLAZA, HOUSE, EXCHANGE, LIBRARY, LIBRARY_ADV, MUSEUM, ART_GALLERY, SMITHY }
```

`SMITHY` を末尾に追加（インデックス 17）。**既存 enum 値の順序を変えない**（cards_econ.json などの既存データが破壊されないようにするため）。

### 4.2 BUILD_COSTS への追加
```gdscript
static var BUILD_COSTS: Dictionary = {
    ...既存のまま...
    16: {},                         # ART_GALLERY（既存・スタブ）
    17: {"wood": 4, "stone": 4, "sulfur": 2},  # SMITHY（要件 §3.1）
}
```

### 4.3 BUILD_HP への追加
```gdscript
static var BUILD_HP: Dictionary = {
    ...既存のまま...
    16: 60.0,  # ART_GALLERY（既存）
    17: 80.0,  # SMITHY（要件 §3.1）
}
```

### 4.4 REQUIRED_CONSTRUCTION への追加
```gdscript
static var REQUIRED_CONSTRUCTION: Dictionary = {
    ...既存のまま...
    16: 5.0,   # ART_GALLERY（既存）
    17: 6.0,   # SMITHY（要件 §3.1）
}
```

### 4.5 定数定義（class フィールド領域・既存 EXCHANGE_DRAW_* パターンに倣う）
```gdscript
# 鍛冶屋：隣接兵舎ユニットのDPS強化（要件 req_econ_smithy_building.md）
const SMITHY_DPS_MULT_LV1 := 1.10
const SMITHY_DPS_MULT_LV2 := 1.15  # 次期MVPで使用
const SMITHY_DPS_MULT_LV3 := 1.20  # 次期MVPで使用
```

### 4.6 インスタンス変数の追加
既存の `exchange_level: int = 1` 等に倣う：
```gdscript
var smithy_level: int = 1   # Lv1〜Lv3（強化システム連動・MVPでは 1 固定）
var _smithy_active: bool = false   # 必要稼働人口1割当時のみ true（5秒tick等で更新）
```

> 注：`_smithy_active` は EconEconomy の稼働人口割当ロジックと同期させる。既存 BARRACKS の稼働判定と同じ仕組みを流用する（**実装時に既存稼働判定の確認必須**）。

### 4.7 _update_smithy 関数の追加（既存 `_update_exchange` パターンに倣う）

```gdscript
func _update_smithy(delta: float, economy: EconEconomy) -> void:
    # 鍛冶屋自体は時間経過で何も生産・消費しない
    # 効果は「隣接兵舎のユニット出撃時」に EconBattle 経由で発火する（§5 連携仕様）
    # ここでは稼働状態フラグの更新のみ実施
    _smithy_active = _is_active(economy)
    # !マーク表示制御（必要稼働人口1未割当時に表示）
    _resource_ready = _smithy_active

func _is_active(economy: EconEconomy) -> bool:
    # 既存の稼働人口割当ロジックに準拠（EconEconomy 側で判定）
    # **実装時に既存 BARRACKS / EXCHANGE の稼働判定方式を確認し、同じ方式を採用**
    # 暫定：is_built == true && is_alive == true && 稼働人口1割当済
    if not is_built or not is_alive:
        return false
    # 稼働人口1割当の判定は EconEconomy 側に問い合わせる（メソッド経由・疎結合）
    # **要確認**：EconEconomy 側に `is_building_assigned(building) -> bool` 等の API があるか
    return true   # MVP暫定：is_built && is_alive のみで稼働扱い（次節 §9 Q1 で CEO 判断）
```

### 4.8 update 関数の match 分岐追加
既存（EconBuilding.gd:174-202）：
```gdscript
match building_type:
    BuildingType.BARRACKS:
        _update_barracks(delta, economy)
    ...
    BuildingType.LIBRARY, BuildingType.LIBRARY_ADV, BuildingType.MUSEUM, BuildingType.ART_GALLERY:
        pass
```

変更後：
```gdscript
match building_type:
    BuildingType.BARRACKS:
        _update_barracks(delta, economy)
    ...
    BuildingType.LIBRARY, BuildingType.LIBRARY_ADV, BuildingType.MUSEUM, BuildingType.ART_GALLERY:
        pass
    BuildingType.SMITHY:
        _update_smithy(delta, economy)
```

### 4.9 _draw 関数の着色追加
既存（EconBuilding.gd:314-328）：
```gdscript
match building_type:
    ...
    BuildingType.LIBRARY, BuildingType.LIBRARY_ADV, BuildingType.MUSEUM, BuildingType.ART_GALLERY: color = Color.LIGHT_GRAY
```

変更後：
```gdscript
match building_type:
    ...
    BuildingType.LIBRARY, BuildingType.LIBRARY_ADV, BuildingType.MUSEUM, BuildingType.ART_GALLERY: color = Color.LIGHT_GRAY
    BuildingType.SMITHY: color = Color.DARK_ORANGE   # 火・鉄を想起する暖色（兵舎=PERU と区別）
```

### 4.10 隣接兵舎用ヘルパー（公開 API）

EconBattle 側からユニット出撃時に呼ばれる「兵舎の隣接鍛冶屋Lv取得」処理は **EconBuilding 側でなく EconBattle 側で集約する**（§5 連携仕様）。
EconBuilding 側で公開する API は **`get_smithy_dps_mult() -> float`** のみ：

```gdscript
# 鍛冶屋として、現在の Lv に応じた DPS 倍率を返す（非稼働時は 1.0）
# 要件 req_econ_smithy_building.md §4.10
func get_smithy_dps_mult() -> float:
    if building_type != BuildingType.SMITHY:
        return 1.0
    if not _smithy_active:
        return 1.0
    match smithy_level:
        2: return SMITHY_DPS_MULT_LV2
        3: return SMITHY_DPS_MULT_LV3
        _: return SMITHY_DPS_MULT_LV1
```

> 疎結合ルール：EconBattle 側は `get_smithy_dps_mult()` を呼ぶだけで、`smithy_level` や `_smithy_active` への直接アクセスはしない。

---

## 5. EconUnit / EconBattle との連携仕様（疎結合設計）

### 5.1 設計方針：出撃時固定バフ
GAME_DESIGN §4.5「適用タイミング：ユニット化して出撃する時」に従い、**ユニットインスタンス生成直後に DPS 倍率を一度だけ適用**する。出撃済みユニットには鍛冶屋の状態変化（破壊・稼働停止・新設）の影響を **及ぼさない**。

### 5.2 EconUnit 側の追加（既存 `apply_equipment_buff` パターンに倣う）

```gdscript
# 鍛冶屋バフ適用（疎結合・メソッド経由）
# 要件定義書 req_econ_smithy_building.md § 5.2 より
# rank: 1=Lv1(+10%), 2=Lv2(+15%), 3=Lv3(+20%)
var _smithy_dps_mult: float = 1.0   # 鍛冶屋バフ倍率（既存 _equip_atk_mult と並列）

func apply_smithy_buff(rank: int) -> void:
    var mult: float = 1.0
    match rank:
        2: mult = 1.15
        3: mult = 1.20
        _: mult = 1.10
    _smithy_dps_mult = mult
    atk *= mult   # GAME_DESIGN §6.8 のユニットDPS = 残存兵力 × 0.2 を踏襲。MVP実装の `atk` を倍率乗算。
```

> 注：MVP の EconUnit は `atk`（攻撃力）を直接保持しているため、`atk *= mult` で実装する。GAME_DESIGN §6.8 の「ユニットDPS=残存兵力×基礎DPS係数(0.2)」モデルへの完全移行は別タスク。本要件では **既存 atk フィールドへの倍率乗算で代替**する。

### 5.3 EconBattle 側のフック（ユニット生成直後）

EconBattle.gd でユニットを生成している箇所（兵舎の `unit_produced` シグナル受信 → `EconUnit.create()` → スポーン）に、**生成直後**に以下のロジックを挿入：

```gdscript
# 兵舎の grid_pos から隣接する稼働中鍛冶屋を全探索
# 最も高い Lv の倍率を取得して unit に適用
# 要件定義書 req_econ_smithy_building.md § 5.3 より
func _get_max_smithy_rank_for_barracks(barracks_pos: Vector2i, is_player: bool) -> int:
    var best_rank: int = 0
    for b in buildings:   # buildings: 全建物配列（既存）
        if not b.is_alive or not b.is_built:
            continue
        if b.is_player_side != is_player:
            continue
        if b.building_type != EconBuilding.BuildingType.SMITHY:
            continue
        if grid.hex_distance(barracks_pos, b.grid_pos) != 1:
            continue
        var mult: float = b.get_smithy_dps_mult()   # 非稼働時は 1.0
        if mult <= 1.0:
            continue
        var rank: int = b.smithy_level
        if rank > best_rank:
            best_rank = rank
    return best_rank
```

ユニット生成直後：
```gdscript
var rank: int = _get_max_smithy_rank_for_barracks(barracks_pos, is_player_side)
if rank > 0:
    unit.apply_smithy_buff(rank)
```

### 5.4 適用対象出撃の網羅（GAME_DESIGN §4.5）

| 出撃元 | 鍛冶屋バフ適用 | 実装フック |
|---|---|---|
| 任意突撃（旗ON） | あり | 兵舎 `unit_produced` シグナル受信時の出撃ユニット生成箇所 |
| 最終突撃 | あり | 同上（最終突撃フェーズでも兵舎ユニットは同じ生成経路を通る） |
| 防衛拠点による防衛出撃 | あり | 防衛拠点（WATCHTOWER）が範囲内兵舎から兵力を引き出してユニット化する箇所 |

> **注**：MVP では防衛拠点が未実装のため、防衛出撃のフック追加は **防衛拠点実装時に同時対応**する。本要件では「任意突撃・最終突撃」の2経路のみ実装。防衛出撃は**スコープ外（§7.4）**として明記。

### 5.5 疎結合ルール準拠（CLAUDE.md より）

- ✅ EconBattle は `building.get_smithy_dps_mult()` を呼ぶ（メソッド経由）
- ✅ EconBattle は `unit.apply_smithy_buff(rank)` を呼ぶ（メソッド経由）
- ❌ EconBattle が `unit.atk *= 1.10` のような直接代入を行う ← **禁止**
- ❌ EconBattle が `building.smithy_level` を直接読み書きする ← **禁止**
- ❌ EconBuilding が EconUnit の内部フィールドを直接操作する ← **禁止**

---

## 6. 検証条件

### 6.1 機能検証
- [ ] SMITHY 建物がカードから建設できる（建設キュー → 完成 → 稼働）
- [ ] 鍛冶屋が稼働中（is_built && is_alive）で兵舎に隣接しているとき、その兵舎から出撃するユニットの atk が 1.10 倍になっている
- [ ] 鍛冶屋が **隣接していない** 兵舎のユニットには影響しない
- [ ] 鍛冶屋を破壊しても、すでに出撃済みのユニットの atk は元に戻らない（出撃時固定バフ）
- [ ] 鍛冶屋建設前に出撃したユニットには倍率が適用されない（出撃時の鍛冶屋状態のみ参照）
- [ ] 同じ兵舎に Lv1 鍛冶屋2つが隣接している場合、適用倍率は ×1.10（重複しない・最大Lvのみ）
- [ ] 必要稼働人口1が未割当の鍛冶屋は効果なし（**§9 Q1 で CEO 判断確定後**）
- [ ] 建設中（is_built=false）の鍛冶屋は効果なし

### 6.2 構文検証
- [ ] `bash check_syntax.sh` がエラー0件で通過
- [ ] enum 値追加による既存実装の破壊なし（`grep "BuildingType\."` で利用箇所を確認）
- [ ] 既存 enum インデックス（0〜16）が変わっていないことを確認

### 6.3 疎結合検証
- [ ] EconBattle 内で `unit.atk *= ...` のような直接代入がない（鍛冶屋バフ関連）
- [ ] EconBattle 内で `building.smithy_level` への直接代入がない
- [ ] EconBuilding 内で EconUnit のフィールドへの直接アクセスがない
- [ ] バフ適用は必ず `apply_smithy_buff(rank)` メソッド経由

### 6.4 GAME_DESIGN 整合性検証
- [ ] §4.5「アクティブ型・必要稼働人口1」が満たされている
- [ ] §4.5「適用タイミング：ユニット化して出撃する時」が守られている（出撃済みユニットへの再適用なし）
- [ ] §4.5「複数隣接時：最も高いLvの効果のみ適用」が守られている
- [ ] §4.5「非稼働時：効果なし」が守られている
- [ ] §11.3 ユニット関連パラメータ（基礎DPS係数 0.2 等）への副作用なし

### 6.5 ファイルサイズチェック（予防的品質管理）
- 現在の EconBuilding.gd 行数：347行（Read 結果より）
- 追加予定行数：約30〜40行（enum 1値・定数3個・インスタンス変数2個・関数2個・match 分岐2個・_draw 1行）
- 追加後予測：約380行 → **500行以下のため分割不要**
- EconUnit.gd 現在 419行 → 追加 6〜8行 → 約427行 → **500行以下のため分割不要**

---

## 7. MVP除外事項（実装しない）

### 7.1 建物 Lv 強化（Lv2/Lv3 の自動切替）
- Lv2/Lv3 の倍率定数（×1.15 / ×1.20）はコードに**定義のみ**
- 建物Lv強化システム自体が MVP 未実装のため、**`smithy_level = 1` 固定**で運用
- Lv2/Lv3 への動的切替は次期MVP

### 7.2 防衛拠点（WATCHTOWER）からの防衛出撃への適用
- GAME_DESIGN §4.5 では「防衛拠点による防衛出撃」も対象だが、防衛拠点自体が MVP 未実装
- 防衛拠点実装時に **同時対応**することとし、本要件では対応しない

### 7.3 出撃済みユニットへの動的再計算
- 鍛冶屋が破壊・新設されても、出撃済みユニットの atk は再計算しない
- GAME_DESIGN §4.5「適用タイミング：ユニット化して出撃する時」が確定仕様

### 7.4 鍛冶屋からの視覚エフェクト
- 鍛冶屋稼働中の煙・火花などの視覚演出は本要件のスコープ外
- 既存の `_resource_ready` フラグによる！マーク表示で稼働状態を示す

### 7.5 鍛冶屋による特定ユニット種別への差分強化
- ATTACKER/TANK/BREAKER 全種別に同じ倍率を適用（一律 ×1.10）
- ユニット種別ごとの倍率差分は次期MVP以降で検討

### 7.6 鍛冶屋同士の隣接によるシナジー
- 鍛冶屋が複数隣接していても重複しない（最大Lvのみ）
- 「鍛冶屋×N」のシナジーは本要件に含めない

---

## 8. 実装上の注意

### 8.1 既存パターンとの整合
- `_update_exchange` パターンに倣い、`_update_smithy` を追加
- `apply_equipment_buff` パターンに倣い、`apply_smithy_buff` を EconUnit に追加
- `_resource_ready` フラグの使い方を踏襲（必要稼働人口未割当時に false → !マーク表示）

### 8.2 cards_econ.json への追加
建物カードが cards_econ.json に定義されている場合、以下のエントリを追加：
```json
{
    "id": "smithy",
    "name": "鍛冶屋",
    "type": "building",
    "building_type": 17,
    "cost": {"wood": 4, "stone": 4, "sulfur": 2}
}
```
> 既存の cards_econ.json 構造を確認の上、整合する形式で追加すること。

### 8.3 用語統一（CLAUDE.md「用語統一ルール」）
- 設計文書：「鍛冶屋」（日本語）
- データ：`"smithy"` / `SMITHY`（英語コード）
- コード：`BuildingType.SMITHY`
- 旧 `EQUIPMENT_SHOP`（装備屋）と混同しないこと
  - 装備屋＝**ユニット種別ごとの個別バフ**（atk/hp/move_spd・unit_type で分岐）
  - 鍛冶屋＝**隣接兵舎の出撃ユニット一律 DPS バフ**（unit_type 不問）

### 8.4 出撃時タイミングの精密化
- 兵舎の `unit_produced.emit(grid_pos, unit_type)` シグナル受信時に隣接鍛冶屋を探索
- 探索結果に応じて生成済み EconUnit に `apply_smithy_buff(rank)` を適用
- **シグナル発火 → ユニット生成 → バフ適用 → スポーン位置設定** の順序を守る

### 8.5 既存 EconUnit.atk への副作用
- `atk *= 1.10` で実装するため、装備屋バフ適用後に鍛冶屋バフが乗算される（または逆）
- 装備屋バフ＋鍛冶屋バフ：例 ATTACKER（atk=20）→ 装備屋Lv1で ×1.20 → 鍛冶屋Lv1で ×1.10 → 最終 atk = 20 × 1.20 × 1.10 = 26.4
- **乗算順は問わない（可換）**ため、適用順を厳密に規定する必要はない。ただし「2回掛けない」ことだけ確認する

---

## 9. 想定される質問・要確認事項（CEO 判断待ち）

| # | 確認事項 | 推奨案 |
|---:|---|---|
| Q1 | 鍛冶屋の稼働判定（必要稼働人口1割当チェック）は EconEconomy 側のどの API で行うか？ | **要確認**：既存 BARRACKS / TRADE_POST / EXCHANGE の稼働判定方式を実装時に確認し、同じ方式を採用する。MVP暫定としては `is_built && is_alive` のみで稼働扱い（人口割当判定は後続フェーズ） |
| Q2 | 建設コスト（木材4/石材4/硫黄2）は妥当か？ | 案：そのまま採用。理由は §3.4 の比較表 |
| Q3 | 必要作業量 6.0 は妥当か？ | 案：そのまま採用（装備屋 EQUIPMENT_SHOP=6.0 と同水準） |
| Q4 | Lv2/Lv3 を MVP で実装するか？ | **確定：実装しない**。建物Lv強化システム自体が MVP 未実装のため、`smithy_level = 1` 固定 |
| Q5 | 建物色は DARK_ORANGE で良いか？ | デザイナー判断に委ねる（兵舎=PERU と区別できれば可） |
| Q6 | EconBattle のユニット生成箇所が複数ある場合（任意突撃・最終突撃の経路差異）、フック挿入箇所は？ | 推奨：兵舎の `unit_produced` シグナル受信ハンドラを単一の関数に集約し、そこにフックを置く。複数経路がある場合は実装時に確認 |
| Q7 | 装備屋バフ × 鍛冶屋バフ の乗算合成は許容するか？ | 推奨：**許容**（互いに独立したシステムのため）。GAME_DESIGN にも上限規定なし |
| Q8 | 防衛拠点（WATCHTOWER）からの防衛出撃への対応はいつ行うか？ | 確定：防衛拠点実装と同時に対応（本要件のスコープ外・§7.2） |

---

## 10. 関連ドキュメント

- `docs/GAME_DESIGN_V0_2_MVP.md`（§3 建物分類、§4.4 建物一覧、§4.5 鍛冶屋詳細仕様、§4.8 建物Lv強化）
- `docs/requirements/REQUIREMENTS_V0_2_MVP.md`（§2.5.9 隣接兵舎へのDPS強化、§2.6 戦闘、§2.7 建物一覧）
- `docs/requirements/req_econ_exchange_building.md`（既存パターン参照・enum追加・update分岐の構造を踏襲）
- `scripts/econ_mvp/EconBuilding.gd`（実装対象本体）
- `scripts/econ_mvp/EconUnit.gd`（apply_smithy_buff 追加先・既存 apply_equipment_buff パターン踏襲）
- `scripts/econ_mvp/EconBattle.gd`（ユニット生成フック挿入先）
- `data/cards_econ.json`（カード定義）

---

更新日: 2026-05-02
バージョン: v0.1（初版）
ステータス: DRAFT（CEO承認待ち）
