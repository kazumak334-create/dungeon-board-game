# 要件定義書: EconMVP ユニット生産のハーベスター供給化

更新日: 2026-05-02
STATUS: 企画確定（Planning 2026-05-01・敵側追記 2026-05-02）・MVP実装対象

---

## 0. スコープ

ユニット生産（兵舎・要塞・工房）を **「ハーベスターが資源を供給 → 生産建物が消費して生成」** のフローに変更する。

### 現状（廃止）

- 建物が存在するだけで `_produce_timer` が経過 → `economy.spend()` で **EconEconomy のグローバル資源プールから直接消費** → ユニット生成

### 変更後

- ハーベスターが各リソース（wood/stone/sulfur）を **生産建物に供給**
- 生産建物は供給を受けた分だけ生産（ストックがなければ待機）
- ビルダー（建物建設時のハーベスター挙動）と同じメカニクス

### 敵側の扱い（2026-05-02 追記・確定方針）

**敵側もプレイヤー側と同じフロー（ハーベスター供給 → 建物在庫消費）に統一する。**

判断理由（公平性 + ゲームバランス + KISS）:
- プレイヤーと敵の挙動を同一ロジックで実装することで、戦況の予測可能性が保たれる（プレイヤーが「自分の盤面で起きていること」と「敵陣で起きていること」を同じメンタルモデルで読める）
- ハーベスター数 → 生産速度の因果が敵側でも成立 → AI 難易度を「敵ハーベスター数」で調整可能になる（バランス調整の自由度向上）
- 別フローを 2 系統メンテナンスするコストを避ける（KISS）

採用パラメータ（プレイヤーと完全共通）:
- `MAX_STACK = 8`（敵陣 col 18-25 のスタック制限）
- `STOCKPILE_CAP = 6`（敵建物の在庫上限）
- 初期 stockpile = `{"wood": 0, "stone": 0, "sulfur": 0}`（敵もプレイヤーと同じ「ハーベスターの初手収穫を待つ」体験）

ルーティング関数の実装方針:
- **案A 採用**: `_route_harvested_resource(rtype: int, is_player: bool = true)` の単一関数でパラメータ分岐
- 案B（敵専用関数を分離）は DRY 違反になるため不採用

### 核となる体験との整合性

- 「配分の答え合わせ」: ハーベスター割り当てがユニット数に直結
- ハーベスター数 → 各建物への供給速度 → ユニット生産速度の因果が明示化

### スコープ外

- ハーベスター割り当て UI の刷新（既存 EconHarvester の割り当てロジックを流用）
- 既存コスト値の変更（wood 3 / stone 3 / sulfur 3 のまま）
- 配置ボーナス時の半減ルールの変更（既存ロジック維持）

---

## 1. 概要

### 1.1 既存コスト（変更なし）

| 建物 | 必要リソース | 量 | 配置ボーナス時 |
|-----|------------|---|-------------|
| BARRACKS | wood | 3 | 2（ceil(3/2)） |
| FORTRESS | stone | 3 | 2 |
| WORKSHOP | sulfur | 3 | 2 |

### 1.2 フロー比較

#### 旧フロー（現行・廃止）

```
[Tick]
  EconBuilding._update_barracks(delta, economy)
    _produce_timer += delta
    if _produce_timer >= interval:
      if economy.can_afford({"wood": cost}):
        economy.spend({"wood": cost})       # ← グローバルプールから直接消費
        unit_produced.emit()
```

#### 新フロー（変更後）

```
[Tick]
  EconHarvester.update()
    [target=WOOD] 木材タイル到達 → harvested.emit(WOOD)
      ↓
    EconBattle ハンドラ
      → 「最寄りの BARRACKS の stockpile に +1 wood」
      （未建設・全建物満杯なら economy にフォールバック追加）

  EconBuilding._update_barracks(delta, economy)
    _produce_timer += delta
    _resource_ready = (stockpile["wood"] >= cost)
    if _produce_timer >= interval:
      if _resource_ready:
        stockpile["wood"] -= cost           # ← 自分のストックから消費
        unit_produced.emit()
```

### 1.3 KISS判断

- 「専用の供給配管」は作らない（建物毎の harvester_assignment 等の設定を新設しない）
- 「最寄りの該当建物に在庫補充」だけで十分（ハーベスターの target_role 切り替えは既存仕組みに任せる）
- 在庫が満杯（後述§2.2）なら economy（既存グローバルプール）に積む = 既存の振る舞いに自然フォールバック

---

## 2. データ構造

### 2.1 EconBuilding に追加（生産建物のみ使用）

```gdscript
# scripts/econ_mvp/EconBuilding.gd

# 各生産建物の在庫（自分専用ストック）
# BARRACKS: stockpile["wood"]
# FORTRESS: stockpile["stone"]
# WORKSHOP: stockpile["sulfur"]
var stockpile: Dictionary = {"wood": 0, "stone": 0, "sulfur": 0}
const STOCKPILE_CAP := 6   # 各リソースの上限（KISS: 全建物共通の固定値）
```

### 2.2 在庫上限ルール

- 各建物 1 リソースにつき **最大 6**（生産 2 回分）まで保持可能
- 上限到達時は新規供給を受けない（ハーベスターは別の建物・別ターゲットに移行）
- 上限到達 + 該当建物が全部満杯の場合のみ economy にフォールバック追加

### 2.3 EconBattle 側のルーティング関数

```gdscript
# EconBattle.gd（または EconMain）に追加
# ハーベスターの harvested シグナル受信時のルーティング

func _route_harvested_resource(rtype: int) -> void:
    var btype: int = -1
    var key: String = ""
    match rtype:
        EconGrid.ResourceType.WOOD:
            btype = EconBuilding.BuildingType.BARRACKS
            key = "wood"
        EconGrid.ResourceType.STONE:
            btype = EconBuilding.BuildingType.FORTRESS
            key = "stone"
        EconGrid.ResourceType.SULFUR:
            btype = EconBuilding.BuildingType.WORKSHOP
            key = "sulfur"
        _:
            # WHEAT / IRON / COTTON 等は既存通り economy に直接追加
            economy.add_resource(rtype, 1)
            return
    # 該当タイプの建物のうち、在庫に空きがある最寄りを選定
    var best: EconBuilding = null
    var best_priority: int = 0
    for b in player_buildings:
        if not b.is_alive or not b.is_built: continue
        if b.building_type != btype: continue
        if b.stockpile.get(key, 0) >= EconBuilding.STOCKPILE_CAP: continue
        # 集中建設モードの優先度を流用 + 在庫が少ない順を優先
        var priority: int = b.build_priority * 100 + (EconBuilding.STOCKPILE_CAP - b.stockpile.get(key, 0))
        if best == null or priority > best_priority:
            best = b
            best_priority = priority
    if best != null:
        best.stockpile[key] += 1
    else:
        # 全建物満杯 or 該当建物なし → 既存通り economy にフォールバック
        economy.add_resource(rtype, 1)
```

### 2.4 ハーベスター側の変更

**変更不要**。
- EconHarvester は引き続き `harvested.emit(rtype)` を発火するだけ
- ルーティングは EconBattle 側の責務（疎結合）
- 既存の target_role / 割り当てロジック（economy.get_harvest_target_for）に手を入れない

---

## 3. 実装仕様

### 3.1 EconBuilding._update_barracks の変更

```gdscript
# 変更前
func _update_barracks(delta: float, economy: EconEconomy) -> void:
    var interval := 5.0 if _placement_bonus_active else BARRACKS_PRODUCE_INTERVAL
    var cost := ceili(BARRACKS_PRODUCE_COST / 2.0) if _placement_bonus_active else BARRACKS_PRODUCE_COST
    _resource_ready = economy.can_afford({"wood": cost})
    _produce_timer += delta
    if _produce_timer >= interval:
        if _resource_ready:
            economy.spend({"wood": cost})
            _produce_timer = 0.0
            unit_produced.emit(grid_pos, 0)

# 変更後
func _update_barracks(delta: float, economy: EconEconomy) -> void:
    var interval := 5.0 if _placement_bonus_active else BARRACKS_PRODUCE_INTERVAL
    var cost := ceili(BARRACKS_PRODUCE_COST / 2.0) if _placement_bonus_active else BARRACKS_PRODUCE_COST
    _resource_ready = (stockpile.get("wood", 0) >= cost)   # ← 自分の在庫を見る
    _produce_timer += delta
    if _produce_timer >= interval:
        if _resource_ready:
            stockpile["wood"] -= cost                       # ← 自分の在庫から消費
            _produce_timer = 0.0
            unit_produced.emit(grid_pos, 0)
        # else: 在庫が貯まるまで待機（_produce_timer は止めず、毎フレーム再判定）
        #       → ストック充填と同時に即生産される
```

### 3.2 EconBuilding._update_fortress / _update_workshop も同様に変更

| 関数 | リソースキー | unit_type |
|-----|-------------|-----------|
| `_update_fortress` | `"stone"` | 1 |
| `_update_workshop` | `"sulfur"` | 2 |

### 3.3 在庫待機時の `_produce_timer` 挙動

**仕様: タイマーは継続加算する（リセットしない）。**

理由:
- 「資源不足で待機中、補給と同時に即生産される」体験が直感的
- 旧仕様も `_produce_timer >= interval` 到達後は毎フレーム判定だったため挙動互換

ただし `_produce_timer` の上限はクランプ:
```gdscript
_produce_timer = minf(_produce_timer + delta, interval + 1.0)
```

### 3.4 ハーベスター → 建物の供給確認（!表示）

- 既存の `_resource_ready` フラグ + 「!」描画は維持（EconBuilding._draw 内）
- 在庫不足時に該当建物の右上に「!」が出る
- ハーベスターが供給に向かっていることはプレイヤーが視覚的に推測（既存の H マーカーで判断可能）

### 3.5 ビルダーモード（建設）との関係

- **建設フロー（既存・変更なし）**: ハーベスターが target_role=ROLE_BUILD のとき、未建設建物に近づいて build_progress を加算しつつ economy.spend() でグローバル資源を消費
- 本要件は **生産フロー** のみを変更する。建設フローには手を入れない
- 建設に必要な資源（wood/stone/sulfur 等）は引き続き economy（グローバル）から消費される

理由（KISS）: 建設はハーベスター 1 体で完結する独立シーケンス・現行で問題なし。

### 3.6 シグナル接続

```gdscript
# EconBattle.gd（または EconMain）の _ready / _setup 系で
for h in harvesters:
    if not h.harvested.is_connected(_on_harvested):
        h.harvested.connect(_on_harvested)

func _on_harvested(rtype: int) -> void:
    _route_harvested_resource(rtype)
```

既存の harvested シグナルハンドラがある場合、その中で economy.add_resource() の代わりに `_route_harvested_resource()` を呼ぶように差し替える。

---

### 3.7 敵側の実装（プレイヤー側と同じフロー）

#### 3.7.1 spawn_enemy_unit への MAX_STACK チェック追加

`EconBattle.spawn_enemy_unit(utype: int, pos: Vector2i)` の **先頭** にスタック制限チェックを追加する。

```gdscript
func spawn_enemy_unit(utype: int, pos: Vector2i) -> void:
    # 敵陣スタック制限チェック（プレイヤー側と同じ MAX_STACK = 8）
    # col >= 18 を敵陣と定義（プレイヤー陣 col 0-17 / 敵陣 col 18-25）
    var enemy_stack_count: int = 0
    for u in enemy_units:
        if u.is_alive and u.grid_pos.x >= 18:
            enemy_stack_count += 1

    if enemy_stack_count >= EconGrid.MAX_STACK:
        # スタック満杯時のみログ出力（毎 tick ではない・スパム防止）
        log_message.emit("Enemy production blocked: stack full (%d/%d)" % [enemy_stack_count, EconGrid.MAX_STACK])
        return

    # 以下、既存の生成ロジック
    var unit := EconUnit.create(utype, EconUnit.Side.ENEMY, pos.x, pos.y)
    unit.position = grid.hex_to_pixel(pos.x, pos.y)
    unit.is_idle = true
    unit._spawn_building_pos = pos
    enemy_units.append(unit)
    grid.add_child(unit)
```

仕様確定:
- 敵 MAX_STACK = **8**（プレイヤーと同じ・公平性）
- 敵陣定義 = `col >= 18`（プレイヤー陣は `col < 18`）
- ログ出力 = **スキップ時のみ**（ログスパム防止）

---

#### 3.7.2 敵建物の stockpile 対応

敵建物（`enemy_buildings`）も **プレイヤー側と同じ `stockpile` フィールド・`STOCKPILE_CAP` 定数を共有する**。

`EconBuilding.gd` に既に追加した `stockpile` / `STOCKPILE_CAP` / `add_stock()` は side（プレイヤー / 敵）に依存しないため、追加の修正は不要。

`_update_barracks` / `_update_fortress` / `_update_workshop` も両側共通で動作する（自分の `stockpile` を見るだけのため）。

確認項目:
- 敵建物が `register_enemy_building()` 経由で登録される際、既定値 `stockpile = {"wood": 0, "stone": 0, "sulfur": 0}` で初期化されることを確認
- 敵側生産建物（BARRACKS / FORTRESS / WORKSHOP）も既存の `_update_*` 経由で生産が走ること

---

#### 3.7.3 _route_harvested_resource を両側対応に拡張（案A 採用）

§2.3 の関数シグネチャを `is_player: bool = true` 引数付きに変更する。

```gdscript
# EconBattle.gd（または EconMain）
func _route_harvested_resource(rtype: int, is_player: bool = true) -> void:
    var buildings: Array = player_buildings if is_player else enemy_buildings

    var btype: int = -1
    var key: String = ""
    match rtype:
        EconGrid.ResourceType.WOOD:
            btype = EconBuilding.BuildingType.BARRACKS
            key = "wood"
        EconGrid.ResourceType.STONE:
            btype = EconBuilding.BuildingType.FORTRESS
            key = "stone"
        EconGrid.ResourceType.SULFUR:
            btype = EconBuilding.BuildingType.WORKSHOP
            key = "sulfur"
        _:
            # WHEAT / IRON / COTTON 等は既存通り economy に直接追加（敵側も同じ economy を使用）
            economy.add_resource(rtype, 1)
            return

    var best: EconBuilding = null
    var best_priority: int = 0
    for b in buildings:  # ← player_buildings / enemy_buildings を切替
        if not b.is_alive or not b.is_built: continue
        if b.building_type != btype: continue
        if b.stockpile.get(key, 0) >= EconBuilding.STOCKPILE_CAP: continue
        var priority: int = b.build_priority * 100 + (EconBuilding.STOCKPILE_CAP - b.stockpile.get(key, 0))
        if best == null or priority > best_priority:
            best = b
            best_priority = priority

    if best != null:
        if not best.add_stock(key, 1):
            economy.add_resource(rtype, 1)
    else:
        economy.add_resource(rtype, 1)
```

採用理由:
- プレイヤー / 敵で **重複コードなし**（案B 比較で 50 行近い重複を回避）
- 引数 1 つの追加だけで両側対応・読みやすさを損なわない
- 将来 side 数が 3 以上になっても拡張容易（buildings 配列の選択ロジックだけ変えればよい）

---

#### 3.7.4 敵ハーベスターの harvested シグナル接続

現状 `spawn_enemy_harvester()` 内で `h.harvested.connect(func(rtype): economy.add_resource(rtype))` と直接 economy に追加している。

**変更後**: 敵ハーベスターも `_route_harvested_resource(rtype, false)` を経由するよう接続を差し替える。

```gdscript
# EconBattle.spawn_enemy_harvester() 内の修正
func spawn_enemy_harvester(pos: Vector2i, economy: EconEconomy) -> void:
    var h := EconHarvester.new()
    h.grid_pos = pos
    h.economy = economy
    h.position = grid.hex_to_pixel(pos.x, pos.y)
    # 変更前: h.harvested.connect(func(rtype): economy.add_resource(rtype))
    # 変更後:
    h.harvested.connect(_on_harvested_enemy)
    h.harvester_index = enemy_harvesters.size()
    enemy_harvesters.append(h)
    grid.add_child(h)

# 新規ハンドラ
func _on_harvested_enemy(rtype: int) -> void:
    _route_harvested_resource(rtype, false)
```

プレイヤー側ハンドラ `_on_harvested(rtype)` は §3.6 の通り `_route_harvested_resource(rtype, true)` を呼ぶ。

代替案（不採用）: 単一ハンドラで side を判定する案は、シグナルから発信元の side を取得する追加情報が必要になり KISS 違反。ハンドラを 2 つに分けたほうがシンプル。

---

## 4. 実装対象ファイル

| ファイル | 変更内容 | 規模目安 |
|---------|---------|---------|
| scripts/econ_mvp/EconBuilding.gd | `stockpile` フィールド追加・`STOCKPILE_CAP` 定数・`add_stock()` メソッド・_update_barracks/_update_fortress/_update_workshop の在庫参照に変更（プレイヤー / 敵共通） | +30 行 / 修正 15 行 |
| scripts/econ_mvp/EconBattle.gd（または EconMain.gd） | `_route_harvested_resource(rtype, is_player)` 関数追加・プレイヤー / 敵双方の harvested シグナルハンドラ追加・`spawn_enemy_unit()` に MAX_STACK チェック追加・`spawn_enemy_harvester()` のシグナル接続差し替え | +60 行 / 修正 10 行 |
| scripts/econ_mvp/EconHarvester.gd | **変更なし**（harvested シグナルはそのまま発火・プレイヤー / 敵共通） | 0 行 |

### ファイルサイズ予防チェック

| ファイル | 現行行数 | 追加後予測 | 判定 |
|---------|---------|-----------|------|
| EconBuilding.gd | 約 220 行 | 約 250 行 | 500 行未満・許容 |
| EconBattle.gd | （要確認） | +60 行（敵側分込み） | 500 行超なら別途対応 |

実装着手時に Implementer が `wc -l` で確認すること。

---

## 5. ハーベスター割り当てルールの整理

### 5.1 既存の割り当てロジック（変更なし）

- ハーベスター数の配分は既存の `economy.get_harvest_target_for(harvester_index, total_harvesters)` で決定
- プレイヤーが UI で wood / stone / sulfur / wheat / cotton / iron / build / trade に何体ずつ振るかを指定
- 各ハーベスターはその指定に従って tile を探し、収穫したら `harvested.emit(rtype)` を発火するだけ

### 5.2 「どのハーベスターがどの建物に供給するか」の答え

**ハーベスターは建物を意識しない。**

- ハーベスター: 採取と発火のみ（既存ロジック）
- ルーティング: EconBattle が `_route_harvested_resource()` で「最寄りの該当建物 + 在庫の余裕」で配分
- 同種建物が複数ある場合: 在庫の少ない方を優先（priority = build_priority × 100 + 余り容量）

### 5.3 サプライ可視化（将来拡張・本要件スコープ外）

- 「どのハーベスターがどの建物に供給したか」の表示
- ハーベスター → 建物への矢印描画
- 本要件では実装しない（プレイヤーは在庫数 + 「!」マーカーで判断）

---

## 6. 制約・注意事項

### 6.1 疎結合ルール（CLAUDE.md 準拠）

- EconHarvester は EconBuilding を直接参照しない（既存通り）
- EconBattle が両者を仲介し、`stockpile` への加算もメソッド経由 or 専用関数経由
- 直接代入を避けるため、必要であれば EconBuilding に `add_stock(key: String, amount: int) -> bool` メソッドを追加する案も検討可

```gdscript
# 推奨: EconBuilding に追加
func add_stock(key: String, amount: int) -> bool:
    var current: int = stockpile.get(key, 0)
    if current >= STOCKPILE_CAP:
        return false
    stockpile[key] = mini(current + amount, STOCKPILE_CAP)
    return true
```

EconBattle 側は `if not best.add_stock(key, 1): economy.add_resource(rtype, 1)` の形にする。

### 6.2 既存設計との整合性

- 「廃止済み設計」（CLAUDE.md）への抵触なし
- WHEAT / COTTON / IRON 等の他リソースは従来通り economy 直接加算（変更なし）
- 配置ボーナス（req_econ_building_variants.md）の半減ロジックは維持（cost が ceil(cost/2) になるだけ）

### 6.3 装備屋システム（req_econ_equipment_shop_mvp.md）との整合

- 装備屋のバフ適用は `unit_produced.emit()` の **直後**（独立フェーズ）
- リソース消費（stockpile から減算）→ 生産（unit_produced 発火）→ バフ適用（_apply_equipment_buffs）の順序
- 在庫不足で生産できなくても装備屋ロジックには影響しない（生産が走らないだけ）

### 6.4 ゲーム開始時の初期在庫

- 開始時 `stockpile = {"wood": 0, "stone": 0, "sulfur": 0}`
- 初回生産まで「待機 + ハーベスターの初手収穫」が必要
- 初手の体感が遅すぎる場合は初期 stockpile を 3 等にする調整余地あり（実プレイで判断）

### 6.5 集中建設モードとの兼ね合い

- `build_priority` は既存通り建設フロー用に使われる
- 本要件のルーティング関数では `build_priority` を「同種建物の選択優先度」にも流用する（KISS: 既存フィールドの再利用）

### 6.6 敵側実装での疎結合

- 敵ハーベスター（EconHarvester）は敵建物（EconBuilding）を直接参照しない（プレイヤー側と同じ原則）
- ルーティングは EconBattle 側で一元管理（`_route_harvested_resource(rtype, is_player)`）
- 敵建物の `stockpile` への加算も `EconBuilding.add_stock(key, amount)` メソッド経由（直接代入禁止）
- `enemy_buildings` 配列への要素追加・削除は EconBattle 内のメソッド（`register_enemy_building` 等）経由のみ

### 6.7 敵側の初期在庫

- 敵建物の開始時 `stockpile = {"wood": 0, "stone": 0, "sulfur": 0}`（プレイヤーと同じ）
- 敵 AI 初期化時に、敵建物が即座に資源を受け取れるよう敵ハーベスターを `EconAI.setup()` で事前配置する（既存ロジック）

注意:
- 敵の初回生産が遅すぎてゲームバランスが崩れる場合、敵建物の初期 `stockpile` を 3 等にする調整余地あり
- ただし §6.4（プレイヤー側初期在庫）と一貫性を保つこと（プレイヤーが 0 のときは敵も 0）
- バランス調整は別 ADR で議論（本要件のスコープ外）

### 6.8 敵スタック制限（MAX_STACK）

敵もプレイヤーと同じ `MAX_STACK = 8` を適用する（公平性）。

定義:
- プレイヤー陣（col 0-17）: スタック数 ≤ 8
- 敵陣（col 18-25）: スタック数 ≤ 8

`spawn_enemy_unit()` 呼び出し時に敵陣のユニット数（`u.is_alive and u.grid_pos.x >= 18`）をカウントし、上限到達時は生成スキップ。

ログ出力ルール:
- スキップ時のみ `log_message.emit("Enemy production blocked: stack full (X/8)")` を発火
- **毎 tick のチェックではログを出さない**（ログスパム防止）
- プレイヤーは敵陣の状況を可視化されたログで把握可能（敵 AI 行動の透明性確保）

---

## 7. 完了定義（Checker チェックリスト）

- [ ] EconBuilding に `stockpile: Dictionary` フィールドが追加されている
- [ ] EconBuilding に `STOCKPILE_CAP` 定数が追加されている（値=6）
- [ ] `_update_barracks` が `stockpile["wood"]` を参照・消費するよう変更されている
- [ ] `_update_fortress` が `stockpile["stone"]` を参照・消費するよう変更されている
- [ ] `_update_workshop` が `stockpile["sulfur"]` を参照・消費するよう変更されている
- [ ] `economy.spend()` の呼び出しが生産フローから削除されている（建設フローは残す）
- [ ] EconBattle（または EconMain）に `_route_harvested_resource(rtype)` 関数が実装されている
- [ ] harvested シグナルハンドラがルーティング関数を呼ぶように変更されている
- [ ] WOOD → BARRACKS の最寄り在庫に +1 される
- [ ] STONE → FORTRESS の最寄り在庫に +1 される
- [ ] SULFUR → WORKSHOP の最寄り在庫に +1 される
- [ ] 該当建物が全部満杯 or 存在しない場合、economy.add_resource() にフォールバックする
- [ ] WHEAT / IRON / COTTON は従来通り economy 直接加算
- [ ] 在庫不足時は「!」マーカーが表示される（既存ロジック流用）
- [ ] 在庫補充直後に生産が即発火する（_produce_timer 維持）
- [ ] 配置ボーナス時のコスト半減（cost = ceil(3/2) = 2）が在庫参照でも正しく動く
- [ ] EconHarvester.gd に変更が入っていない（疎結合維持）

### 敵側チェック項目（2026-05-02 追記）

- [ ] `spawn_enemy_unit()` の先頭に MAX_STACK = 8 チェックが入っている
- [ ] 敵陣判定が `grid_pos.x >= 18` で実装されている
- [ ] スタック満杯時のみ `log_message.emit("Enemy production blocked: ...")` が発火する（毎 tick ではない）
- [ ] 敵建物（`enemy_buildings`）も `stockpile` フィールドを持つ（EconBuilding 共通）
- [ ] `_route_harvested_resource(rtype, is_player)` が `is_player: bool = true` 引数を受け付ける
- [ ] `is_player == false` のとき `enemy_buildings` を参照する
- [ ] `spawn_enemy_harvester()` 内のシグナル接続が `_on_harvested_enemy` に差し替わっている
- [ ] `_on_harvested_enemy(rtype)` が `_route_harvested_resource(rtype, false)` を呼ぶ
- [ ] WOOD → 敵 BARRACKS の最寄り在庫に +1 される（敵側）
- [ ] STONE → 敵 FORTRESS の最寄り在庫に +1 される（敵側）
- [ ] SULFUR → 敵 WORKSHOP の最寄り在庫に +1 される（敵側）
- [ ] 敵建物が全部満杯 or 存在しない場合、`economy.add_resource()` にフォールバックする（敵側も同じ economy）
- [ ] 敵建物の初期 `stockpile = {"wood": 0, "stone": 0, "sulfur": 0}` で起動する
- [ ] 敵側でも `EconBuilding.add_stock()` 経由で在庫加算（直接代入なし）

### 共通チェック項目

- [ ] check_syntax.sh が通る
- [ ] CEO 承認済み
