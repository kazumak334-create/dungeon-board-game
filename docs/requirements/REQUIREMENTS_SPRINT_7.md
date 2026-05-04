# Sprint 7 要件定義書 — 初期デッキ・住宅・交換所・建築基盤

ステータス: 実装リソース（一時）
対応Sprint: Sprint 7
参照Final企画書: `docs/sprint7_initial_deck_building_base_final.md`（SSoT）
参照Designer企画書: `docs/design/sprint7_designer_plan.md`
統合先: `docs/requirements/REQUIREMENTS_V0_2_MVP.md`（Sprint 7 セクション）
作成日: 2026-05-04
更新日: 2026-05-04（Design Review 反映：FOOTER_H 180px 固定化／VILLAGE ハーベスター生成廃止明記／建設リング外径 14px 修正）

> 注意: 旧版 `docs/requirements/req_econ_initial_deck_sprint7.md`（11枚デッキ・2026-05-03 版）は本書で上書き完了後に廃止する。本書をSSoTとして扱うこと。
>
> **ADR-003（2026-05-04）採択**: Construction の所有者は `EconBattle` に変更。
> §4.3（spawn_building シグネチャ）、§5.3（update_construction 呼び出し位置）、
> §5.4（LogManager 記録位置）が改訂された。詳細は `docs/meta/adr/003_econ_construction_architecture.md` 参照。

---

## 1. 目的

### 1.1 目的
Sprint 7 では初期デッキ13枚と建物カード使用フローを実装し、「建物カードを使用 → 建設予定地指定 → 建設コスト支払い → 建設時間に応じて進捗 → 建設完了 → 稼働開始」までのループを内部実装で成立させる。Sprint 8 における都市成長の検証が成立することを目指す。

### 1.2 核となる体験との整合
- **盤面設計**: 建物カードの配置（自建物隣接の開示済み未建設土地）に制約を設けることで、盤面設計の意思決定を要求する。
- **介入**: 人手スライダーで稼働/作業比率をリアルタイムに変更でき、プレイヤーの介入として機能する。
- **観戦**: 建設進捗・稼働状態は手出し不要のリアルタイム進行であり、観戦体験を損なわない。

### 1.3 KISS適用
- 既存の `EconEconomy.alloc_work_ratio`（稼働/作業比率に相当）を流用し、新フィールドを最小化する。
- 既存 `EconBuilding.BuildingType` enum（HOUSE/VILLAGE/SAWMILL/MINE/DINER/BARRACKS/PLAZA/TRADE_POST 全て定義済み）を流用する。
- 建設進捗は既存の `_construction_ready` 変数とは別に `construction_progress` を新設するが、既存の建物完成済みフラグ（`is_built`）を再利用する。
- 建設キャンセル・建設予定地変更・建設予約キューは Sprint 7 非対象（企画書 §4）。
- UI新規色定義は0個（Designer企画 §6.1）。

---

## 2. 用語定義（企画書 §2 と完全一致）

| 用語 | 定義 | コード上の対応 |
|---|---|---|
| 建物カード | 手札から使用し、土地パネル上に建物を建設するためのカード | `card.category == "building" or "special"` |
| 通常建物 | 使用後に捨て札/山札循環へ戻る建物カードで建てる建物 | `category == "building"`（既存） |
| 特殊建物 | 使用後に捨て札へ行かず除外される建物カード。建物自体は盤面に残る | `category == "special"`（既存・交換所のみ） |
| 建設予定地 | 建物カード使用時に指定される、建設中の土地パネル | `EconGrid.construction_sites: Dictionary[Vector2i → ConstructionSite]`（新規） |
| 未建設土地 | 建物が建っておらず、建設予定地にもなっていない土地 | `land_panels` 内 ∧ 建物未配置 ∧ 建設予定地でない |
| 建設後パネル | 建設が完了し、建物が建っている土地パネル | `is_built == true` の `EconBuilding` |
| 建設コスト | 建物カード使用時に支払う通常資源コスト | `card.cost: Dictionary` |
| 建設時間 | 建設開始から建設完了までに必要な時間（秒） | `BUILD_TIMES_SEC: Dictionary[BuildingType → float]`（新規） |
| 建設進捗 | 建設時間に対する進行度（0.0〜1.0） | `ConstructionSite.progress: float`（新規） |
| 人手 | 人口から算出される作業可能枠 | 既存 `EconEconomy` ベース |
| 稼働人手 | 完成済み建物の効果発動に使う人手 | `EconEconomy.get_working_population()`（既存） |
| 作業人手 | 建設中建物の建設進捗に使う人手 | `EconEconomy.get_building_population()`（既存） |
| 人手スライダー | 人手総量を稼働/作業に配分するUI | `LABOR` ブロック（新規 UI）+ `set_alloc_work_ratio()`（既存 API） |
| 人手総量 | `floor(人口 × 20%)`（仮置き） | `EconEconomy.get_total_labor()`（新規・補助関数） |
| 住宅/農村/森小屋/採掘所/食堂/兵舎/広場 | 通常建物（企画書 §2 参照） | `BuildingType.HOUSE/VILLAGE/SAWMILL/MINE/DINER/BARRACKS/PLAZA` |
| 交換所 | 特殊建物。足元土地の通常資源累計10獲得ごとに1ドロー | `BuildingType.TRADE_POST` + `category: "special"` |

> **既存実装との整合**: `alloc_work_ratio` は「作業比率」を意味（既存）。企画書の「稼働配分率」とは逆数関係になるため、UI 層で 1 - alloc_work_ratio として OPS（稼働）比率を表示する（新フィールドは増やさない）。

---

## 3. 実装スコープ

### 3.1 対象機能

| 機能ID | 機能 | 概要 |
|---|---|---|
| F1 | 初期デッキ13枚定義 | 同一カード重複可・定数として記述 |
| F2 | 建物カード仕様確定 | 8種類のカードに `cost / build_time / required_work_labor / required_operation_labor` を設定 |
| F3 | 建物カード使用フロー | 手札 → 建設予定地指定 → コスト支払い → 建設開始 |
| F4 | 建設予定地システム | `EconGrid` に `construction_sites` を追加・占有判定追加 |
| F5 | 建設進捗システム | `_process` 内で進捗更新・人手不足時停止 |
| F6 | 建設完了処理 | 進捗100%到達で `EconBuilding` 化・`is_built=true` |
| F7 | 人手スライダー UI | フッター中央に LABOR ブロック新設（160×180） |
| F8 | 人手不足時の停止 | 稼働人手不足→効果停止 / 作業人手不足→建設停止 |
| F9 | 人手割当優先順位 | 稼働: 食料系→資源系→兵力系→満足度系 / 作業: 古い順 |
| F10 | 盤面パネル状態表現 | 建設リング・半透明マスク・稼働ドット |
| F11 | BUILDブロック圧縮 | 4種固定 → 手札5枚（48×140 圧縮表示） |
| F12 | 交換所の特殊建物分類 | 使用後除外（既存・確認のみ） |

### 3.2 非対象機能（企画書 §4 準拠）

- 建設キャンセル / 建設予定地変更 / 即時建設 / 建設予約キュー / 建設優先順位変更UI
- 建設UI/建設ログ/建物詳細UIの作り込み（Sprint 8）
- 上位住宅（集合住宅・居住区）詳細仕様
- 部分稼働（必要人手を満たせない場合は完全停止）
- 建設中の資源不足による進捗停止（建設開始後は資源不足で止めない）

---

## 4. データ構造

### 4.1 初期デッキ（F1）

`EconDeckManager.gd` または `EconMain.gd` 内の定数として記述する。

```gdscript
# 企画書 §5.1 準拠（合計13枚）
const INITIAL_DECK_SPEC: Array = [
    {"id": "card_house",          "count": 3},  # 住宅
    {"id": "card_village",        "count": 2},  # 農村
    {"id": "card_wood_extractor", "count": 2},  # 森小屋
    {"id": "card_stone_extractor","count": 2},  # 採掘所
    {"id": "card_diner",          "count": 1},  # 食堂
    {"id": "card_barracks",       "count": 1},  # 兵舎
    {"id": "card_plaza",          "count": 1},  # 広場
    {"id": "card_trade_post",     "count": 1},  # 交換所（特殊）
]
# 合計: 3+2+2+2+1+1+1+1 = 13
```

### 4.2 建物カードデータ（F2）

`data/cards_econ.json` の各カードに以下フィールドを追加（仮置き値・Sprint 8 で調整）。

| 建物 | building_type | cost | build_time(s) | required_work_labor | required_operation_labor | category |
|---|---|---|---:|---:|---:|---|
| 住宅 | HOUSE | wood:3 | 20 | 1 | 0 | building |
| 農村 | VILLAGE | wood:4, stone:3, wheat:2 | 25 | 1 | 1 | building |
| 森小屋 | SAWMILL | wood:8, stone:3 | 25 | 1 | 1 | building |
| 採掘所 | MINE | stone:10, resin:4 | 30 | 1 | 1 | building |
| 食堂 | DINER | wood:4, stone:2 | 25 | 1 | 1 | building |
| 兵舎 | BARRACKS | wood:8 | 35 | 2 | 1 | building |
| 広場 | PLAZA | wood:4, stone:2 | 20 | 1 | 0 | building |
| 交換所 | TRADE_POST | wood:5, stone:5 | 25 | 1 | 1 | **special** |

> cost は既存 `EconBuilding.BUILD_COSTS` と整合させる。新規追加は `build_time / required_work_labor / required_operation_labor` の3フィールドのみ。

#### 建物別効果仕様（VILLAGE 改訂）

##### VILLAGE（農村）
- **効果**: 「完成後、毎 5 秒ごとに小麦+2、コットン+1 を生産」
- **ハーベスター生成**: **なし**（旧 v0.1 仕様の廃止）
  - 旧実装から `harvester_timer` 関連ロジックを全削除
  - `EconBuilding._update_village()` から `unit_produced.emit(grid_pos, -1)` を削除
  - **理由**: 農村は「食料系土地からリソース取得」の単一責務に統一する。ハーベスター生成は別建物（後続Sprint）の責務に分離する
  - 詳細削除手順は §5.6 を参照

### 4.3 建設予定地（F4）

> **ADR-003 採択（2026-05-04）により、`construction_sites` の所有者は `EconBattle` に変更。**
> `EconGrid` は配置可能性判定（`get_buildable_cells_for_card()`）のみを担う。

`EconBattle.gd` に新規 `Dictionary` を追加。

```gdscript
# Vector2i → Dictionary
# 1パネルにつき高々1個の建設予定地（占有）
var construction_sites: Dictionary = {}

# 各 entry の構造（KISS: 専用クラスを作らずDictionaryで保持）
# {
#   "panel_id": Vector2i,                      # 建設位置
#   "btype": String,                           # 建物タイプ（EconBuilding.BuildingType の文字列名）
#   "pos": Vector2i,                           # グリッド座標
#   "card_id": String,                         # 使用カードID（除外/捨て札判定用）
#   "is_special": bool,                        # 特殊建物フラグ
#   "construction_time": float,                # 建設総時間（秒）
#   "construction_progress": float,            # 0.0〜1.0
#   "required_work_labor": int,                # 作業人手要求値
#   "required_operation_labor": int,           # 完成後稼働人手要求値（建物に引き継ぎ）
#   "is_under_construction": bool,             # 進行中フラグ
#   "started_at": int,                         # 建設開始Tick（古い順優先用）
# }
```

#### spawn_building() 仕様（ADR-003）

```gdscript
# EconBattle.gd
func spawn_building(site: Dictionary) -> EconBuilding
```

**site parameter structure**（上記 `construction_sites` の値と同一構造）:

```gdscript
{
    "panel_id": int,          # 盤面上のセル位置（既存実装の panel_id 表現を踏襲）
    "btype": String,          # 建物タイプ
    "pos": Vector2i,          # グリッド座標
    "is_under_construction": bool,
    # ... その他 4.3 表中のフィールド
}
```

> **設計理由**: 単一 Dictionary パラメータ採用により、Sprint 8 以降のフィールド追加で
> シグネチャ変更が不要になる（ADR-003「理由 §2 型安全性・拡張性」）。
> 旧シグネチャ `spawn_building(panel_id, btype, required_operation_labor)` は廃止。

### 4.4 人手データ（F7・F8）

`EconEconomy.gd` に最小限の補助関数を追加（新フィールド禁止・既存 `alloc_work_ratio` を流用）。

```gdscript
# 企画書 §7.2: 人手総量 = floor(人口 × 20%)
func get_total_labor() -> int:
    return int(floor(get_display_population() * 0.20))

# 企画書 §7.3: 稼働人手 = floor(人手総量 × 稼働配分率)
# alloc_work_ratio は「作業比率」なので稼働比率は (1 - alloc_work_ratio)
func get_operation_labor() -> int:
    return int(floor(get_total_labor() * (1.0 - alloc_work_ratio)))

# 作業人手 = 人手総量 − 稼働人手
func get_work_labor() -> int:
    return get_total_labor() - get_operation_labor()
```

> **既存命名との整合性**: `get_working_population()` / `get_building_population()` は「全人口の稼働/作業」を返す既存API。Sprint 7 では「人手（人口×20%）」を返す上記3関数を新設し、UI と建設進捗ロジックは新関数を使用する。`alloc_work_ratio` 自体は既存値をそのまま流用（初期値 0.30 = 作業30% / 稼働70%・企画書 §7.3 準拠）。

---

## 5. システム仕様

### 5.1 建築フロー（F3・F4・F5・F6）

```
[1] プレイヤーがBUILDブロックの建物カードをクリック
  ↓
[2] EconMain が「建設予定地指定モード」に入る
  - EconGrid.get_buildable_cells_for_card(card) → 配置可能Vector2i配列
  - 配置可能条件（企画書 §6.2）：
    a) 自建物に隣接（マンハッタン距離=1）
    b) land_panels に登録済み（土地として開示済み）
    c) 既存の EconBuilding が配置されていない
    d) construction_sites に登録されていない
  ↓
[3] プレイヤーが配置可能マスをクリック
  ↓
[4] EconMain が建設コスト支払い判定
  - EconEconomy.can_afford(cost) → true/false
  - false: カードに「!」アイコン + 赤フラッシュ500ms（既存実装流用）
  - true: continue
  ↓
[5] EconEconomy.pay_cost(cost) で資源を消費
  ↓
[6] EconGrid.start_construction(panel_id, building_type, card_id, ...) を呼ぶ
  - construction_sites[panel_id] に entry 追加
  - is_under_construction = true
  - construction_progress = 0.0
  - started_at = 現在 tick
  ↓
[7] 手札から該当カードを除去
  - 通常建物: discard_pile へ移動
  - 特殊建物（交換所）: excluded へ移動
  ↓
[8] _process 内で建設進捗更新（ADR-003）
  - EconMain._process() → EconBattle._update_construction_progress(delta) を毎フレーム呼び出し
  - construction_sites の所有者は EconBattle（ADR-003）
  - 作業人手割当判定（5.2 参照）
  - 割当成功サイト: progress += delta / construction_time
  - 割当失敗サイト: progress 据え置き（停止）
  - 進捗更新ごとに LogManager.log_event("BUILDING_PROGRESS_UPDATED") を記録
  ↓
[9] progress >= 1.0 で建設完了（ADR-003）
  - construction_sites から該当 site を削除
  - EconBattle.spawn_building(site) を呼ぶ（site Dictionary 単一引数）
  - 新 EconBuilding が is_built=true で生成され盤面に登録
  - LogManager: BUILDING_COMPLETED イベント記録（EconBattle 内で発火）
  ↓
[10] 稼働判定（5.3 参照）
  - 完成済み建物全体で稼働人手割当を再計算
  - 稼働人手割当成功時: 通常の効果発動タイマー進行
  - 失敗時: タイマー停止（既存 _process_xxx を skip）
```

### 5.2 作業人手割当（F8・F9）

毎フレーム以下を実行（ADR-003 により EconBattle 内で実行）：

```gdscript
# EconBattle._update_construction_progress(delta) 内
func _allocate_work_labor() -> Array:
    # 1. 建設中サイトを「started_at 古い順」でソート（企画書 §7.7）
    var sorted_sites: Array = construction_sites.values()
    sorted_sites.sort_custom(func(a, b): return a.started_at < b.started_at)

    # 2. 作業人手プール = EconEconomy.get_work_labor()
    var pool: int = economy.get_work_labor()
    var active_sites: Array = []

    # 3. 各サイトに required_work_labor を割り当て
    #    部分稼働しない（企画書 §7.6）→ 不足したら割り当て失敗（停止）
    for site in sorted_sites:
        if pool >= site.required_work_labor:
            pool -= site.required_work_labor
            active_sites.append(site)
        # else: 停止（progress 据え置き、is_under_construction はtrueのまま）

    return active_sites
```

`active_sites` のみ `progress += delta / construction_time` を加算する。

### 5.3 稼働人手割当（F8・F9）

毎フレーム以下を実行（または建物完成時/スライダー変更時の再計算）：

```gdscript
# EconBattle._allocate_operation_labor() 内
func _allocate_operation_labor() -> Array:
    # 1. 完成済み建物を優先順位順にソート（企画書 §7.7）
    #    1: 食料系（VILLAGE/DINER）
    #    2: 資源系（SAWMILL/MINE/TRADE_POST）
    #    3: 兵力系（BARRACKS）
    #    4: 満足度系（PLAZA）
    #    5: その他（HOUSE 等・required_operation_labor=0 は最下位）
    var sorted_buildings: Array = _get_buildings_by_priority()

    # 2. 稼働人手プール = EconEconomy.get_operation_labor()
    var pool: int = economy.get_operation_labor()
    var active_buildings: Array = []

    # 3. 部分稼働なし（企画書 §7.6）
    for b in sorted_buildings:
        var req: int = _get_required_operation_labor(b.building_type)
        if pool >= req:
            pool -= req
            b.is_operating = true
            active_buildings.append(b)
        else:
            b.is_operating = false  # 停止フラグ

    return active_buildings
```

> 既存 `EconBuilding._process_xxx` 内で `if not is_operating: return` のガードを追加することで効果発動タイマーを停止する（既存タイマーは前進させない＝再開時にそのまま続きから動く）。

### 5.4 進捗判定（F6・F12）

> **ADR-003 採択（2026-05-04）により、進捗更新および完了処理は `EconBattle` 内で実行する。**
> 進捗更新ごとに `BUILDING_PROGRESS_UPDATED` を記録し、完了時に `BUILDING_COMPLETED` を記録する。

```gdscript
# EconBattle._update_construction_progress(delta) 末尾
for panel_id in construction_sites.keys().duplicate():
    var site = construction_sites[panel_id]

    # 進捗更新と同時に PROGRESS_UPDATED を記録
    LogManager.log_event({
        "type": "BUILDING_PROGRESS_UPDATED",
        "panel_id": [panel_id.x, panel_id.y],
        "progress": site.construction_progress,
    })

    if site.construction_progress >= 1.0:
        # 建設完了
        var btype = site.btype
        var card_id = site.card_id
        var is_special = site.is_special

        construction_sites.erase(panel_id)
        spawn_building(site)  # ADR-003: 単一 Dictionary 引数

        # カード回収（疎結合: deck_manager のメソッド経由）
        if is_special:
            deck_manager.exclude_card(card_id)  # 交換所など
        else:
            deck_manager.discard_card(card_id)

        LogManager.log_event({
            "type": "BUILDING_COMPLETED",
            "panel_id": [panel_id.x, panel_id.y],
            "building_type": btype,
        })
```

> **設計理由**: LogManager イベントを `EconBattle._update_construction_progress()` 内に
> 集約することで、ADR-001 が定めた「ライフサイクルイベントは EconBattle が記録する」原則と
> 整合する。`PROGRESS_UPDATED` と `COMPLETED` の発火順序も同一関数内で保証される
> （ADR-003「理由 §4 イベント記録の一貫性」）。

### 5.5 交換所の効果（F12・企画書 §9）

```text
進捗率 = 現在累計値 / 10
累計対象 = 足元土地の通常資源（land_panels[panel_id].resources）
累計10到達ごとに +1 ドロー
```

実装上、`EconBuilding.TRADE_POST._process` 内で `is_operating == true` の間のみ累計値を更新し、10到達ごとに `deck_manager.draw_card()` を呼ぶ。Sprint 7 では既存の交換所実装（`req_econ_exchange_building.md` 参照）を踏襲し、稼働判定（is_operating）のフックのみ追加する。

### 5.6 廃止済み効果・コードの明示削除ルール

Sprint 7 実装時、過去の v0.1 仕様で残存しているコードを明示的に削除する。

#### VILLAGE ハーベスター生成の廃止

**削除対象ファイル・処理**:

1. `EconBuilding.gd` の `_update_village()` メソッド内で以下を削除:
   ```gdscript
   # 削除対象（旧 v0.1 残置）:
   harvester_timer -= delta
   if harvester_timer <= 0.0:
       harvester_timer = HARVESTER_INTERVAL
       unit_produced.emit(grid_pos, -1)  # ← ハーベスター生成シグナル（廃止）
   ```
   - 関連変数 `harvester_timer`、定数 `HARVESTER_INTERVAL` も削除

2. `EconMain.gd:280-285` 付近の VILLAGE 専用ハーベスター接続を削除（`unit_produced` シグナル → ハーベスター生成ハンドラの接続部）

3. `EconBattle.gd:417-422` 付近の `utype == -1` 分岐を削除（ハーベスター用ユニットタイプ判定）

**実装完了後の確認コマンド**:
```bash
grep -n "unit_produced.emit.*-1" scripts/econ_mvp/*.gd && echo "❌ 残存あり" || echo "✅ 廃止確認"
grep -n "harvester_timer\|HARVESTER_INTERVAL" scripts/econ_mvp/EconBuilding.gd && echo "❌ 残存あり" || echo "✅ 廃止確認"
```

> **設計判断**: VILLAGE は「小麦+コットン生産」のみの単一責務にする。ハーベスター生成は概念上独立したシステムであり、農村の責務として混在させない（KISS 原則）。

---

## 6. UI仕様（Designer企画 §10.3 確定事項に準拠）

### 6.1 フッター再レイアウト（F7・F11）

**配置**: 画面下部、y=1100、**高さ=180px固定（FOOTER_H = 180.0）**

**ブロック構成（左から右へ）**:

| ブロック | 旧（既存） | 新（Sprint 7） |
|---|---|---|
| HARVESTER ALLOCATION | x=0-700 / 700×180 | x=0-700 / 700×180（変更なし） |
| **LABOR（新設）** | — | **x=700-860 / 160×180** |
| BUILD（圧縮） | x=700-1120 / 420×180 | **x=860-1120 / 260×180** |
| PLACE-ON-BOARD ヒント | x=1120-1280 / 160×180 | x=1120-1280 / 160×180（変更なし） |

> **【重要・恒久ルール】**: ヘッダー・盤面・フッターの**サイズおよびY座標は以降変更禁止**。
> - HEADER: y=0, h=80
> - 盤面領域: y=80-1100
> - **FOOTER: y=1100, h=180px固定**
>
> **完了条件**: `EconMain.gd` 内に `const FOOTER_H := 180.0` を定義し、180px を明確に指定する。フッター内ブロックの高さ合計が 180px を超えないこと。

### 6.2 LABOR ブロック仕様（F7）

| 要素 | 高さ | 内容 |
|---|---:|---|
| ヘッダー "— LABOR —" | 24px | 14px Bold / `COLOR_TEXT` |
| TOTAL 表示 | 12px | "TOTAL  6" 形式・読み取り専用・11px Bold |
| 水平スライダー本体 | 36px | 128×12px 軌道・つまみ直径12px |
| OPS 行 | 22px | "OPS   70%  4" 形式（割合% + 実数） |
| WORK 行 | 22px | "WORK  30%  2" 形式 |
| ±ボタン | 22px | `[-]` `[+]`（10%刻みで OPS 増減） |

操作仕様:

| 操作 | 動作 | 内部呼び出し |
|---|---|---|
| つまみドラッグ | 10%刻みで OPS:WORK 比率変更（OPS 10〜90%） | `economy.set_alloc_work_ratio(1 - ops_ratio)` |
| `[-]` クリック | OPS −10% | 同上 |
| `[+]` クリック | OPS +10% | 同上 |

警告表現（人手不足時）:

| 状態 | 表現 |
|---|---|
| OPS不足（稼働建物が止まっている） | OPS行数値を `COLOR_RED` で1.0sサイクル点滅 |
| WORK不足（建設が止まっている） | WORK行数値を `COLOR_RED` で1.0sサイクル点滅 |
| 不足解消 | 即座に通常色 `COLOR_TEXT` 復帰 |

### 6.3 盤面パネル状態表現（F10）

| 状態 | パネル背景 | パネル枠 | 中央 | 下部装飾 |
|---|---|---|---|---|
| 未建設土地（資源開示済み） | 既存（資源色） | 既存 | 資源アイコン | なし |
| 建設中・進行中 | 半透明マスク（COLOR_PANEL × α=0.4） | COLOR_ACCENT_GOLD 1px | 建設リング（COLOR_ACCENT_GOLD・**外径14px**） | なし |
| 建設中・停止中（作業人手不足） | 同上 | 同上 | 建設リング（COLOR_TEXT_DIM 灰色） | なし |
| 建設後・稼働中 | 既存（建物色・不透明） | 既存 | 建物アイコン | 稼働ドット（COLOR_WOOD・直径6px） |
| 建設後・停止中（稼働人手不足） | 既存（α=0.7） | 既存 | 建物アイコン | 稼働ドット（COLOR_TEXT_DIM） |

#### 6.3.2 建設リング描画仕様

**サイズ**: **外径14px（半径14px）**
- 旧記述「直径28px」は冗長表記であり、正は **外径14px = 半径14px**
- 旧実装で 8px の場合は要件不適合のため **14px に修正**（曖昧性排除）

**色**: COLOR_ACCENT_GOLD（#C9A961）

**位置**: パネル中央上端（パネル中心から上に 12px）

**描画API**: `_draw()` + `draw_arc()`
- 線幅 2px（旧 3px は外径 14px に対し過大のため 2px に統一）
- 内径 = 外径 - 線幅×2 = 10px
- リング背景: 薄い円（`COLOR_BORDER` 1px）

**進捗表示**: 0°-360° を進捗 0%-100% にマップ（BPB式・時計回り・線形）
  - 進捗 **0%**: リング線なし（パネルのみ・背景円のみ表示）
  - 進捗 **1%-99%**: 該当角度のアークを描画（線幅 2px）
  - 進捗 **100%**: 建設完了（リング消滅 → EconBuilding に遷移）

**稼働状態**:
  - 作業人手あり（`is_active=true`）: 金色リング（COLOR_ACCENT_GOLD）
  - 作業人手不足（`is_active=false`）: 灰色リング（COLOR_TEXT_DIM）・進捗は停止

**進捗% テキスト表示**: **なし**（KISS）

#### 6.3.3 稼働ドット描画仕様
- 位置: パネル中央下端から内側4px
- 直径6px・`draw_circle()`

### 6.4 BUILDブロック圧縮（F11）

| 項目 | 旧 | 新 |
|---|---|---|
| カード枚数 | 4枚（兵舎・要塞・工房・農村固定） | **5枚（手札スロット）** |
| カードサイズ | 92×140 | **48×140** |
| カード間スペース | 8px | 4px |
| 表示内容 | アイコン + 名称 + コスト | アイコン + コスト（名称はホバーで表示） |

### 6.5 配置可能マスのハイライト

Sprint 9 と同じ規則を流用（プレイヤーの学習コスト削減）。

| 状態 | 表現 |
|---|---|
| 配置可能 | 枠線 `COLOR_WOOD` 2px + 1.0sサイクルパルス（α 0.5↔1.0） |
| 配置不可（建設予定地・建設後パネル） | 枠線 `COLOR_RED` 1px + α=0.3 暗転 |
| ホバー中の配置可能マス | 枠線 `COLOR_ACCENT_GOLD` 3px |

### 6.6 アニメーション仕様

| 演出 | 所要時間 | 補間 |
|---|---|---|
| 配置可能マスパルス | 1.0sサイクル | sin波 |
| 建設リング進行 | リアルタイム（construction_time に従う） | 線形 |
| 建設完了→建物アイコンフェードイン | 300ms | ease-out |
| 配置不可（資源不足）赤フラッシュ | 500ms | 赤→透明 |
| 人手不足数値点滅 | 1.0sサイクル | sin波 |

### 6.7 新規色定義

**0個**（既存 `EconMain.gd:104-121` の `COLOR_*` 定数のみ流用）。

---

## 7. 完了条件チェックリスト

実装完了時、以下を全て満たすこと。

### 初期デッキ・カード仕様
1. [ ] ゲーム開始時、初期デッキが **13枚** で構成される（住宅×3 / 農村×2 / 森小屋×2 / 採掘所×2 / 食堂×1 / 兵舎×1 / 広場×1 / 交換所×1）
2. [ ] 同一カードの重複が許可されている
3. [ ] 8種類の建物カードに `cost / build_time / required_work_labor / required_operation_labor` が設定されている（4.2 表）
4. [ ] 交換所カードに `category: "special"` が設定されている

### 建物カード使用
5. [ ] 手札の建物カードをクリックすると配置モードに入る
6. [ ] 配置可能マス（自建物隣接・開示済み・未建設・非建設予定地）が `COLOR_WOOD` 緑枠でハイライトされる
7. [ ] 配置可能マスをクリックすると建設コストが支払われる
8. [ ] 資源不足時はカードに「!」アイコン + 赤フラッシュ表示で配置失敗（資源は減らない）
9. [ ] 建設開始時、該当パネルが construction_sites に登録され `is_under_construction = true` になる
10. [ ] 建設予定地に他の建物カード・土地カードを配置できない（占有判定）

### 建設進捗・完了
11. [ ] 作業人手が足りる間、建設リングがリアルタイムに進む（線形・進捗 0〜1.0）
12. [ ] 作業人手不足時、建設進捗が停止し建設リングが灰色化する
13. [ ] 進捗100%到達で construction_sites から削除され EconBuilding が is_built=true で生成される
14. [ ] 建設完了後、通常建物は discard_pile へ・特殊建物（交換所）は excluded へ移動する

### 人手システム
15. [ ] 人手総量が `floor(人口 × 20%)` で算出される
16. [ ] 人手スライダーが OPS 70% / WORK 30% 初期値で表示される
17. [ ] スライダー操作（ドラッグ・±ボタン）で 10% 刻みに OPS:WORK 比率が変更される
18. [ ] 稼働人手不足時、完成済み建物の効果発動タイマーが停止する（再開時に続きから動く）
19. [ ] 作業人手不足時、建設中建物の進捗が停止する
20. [ ] 人手不足解消時、稼働・建設が自動再開する
21. [ ] 稼働人手割当の優先順位が「食料系→資源系→兵力系→満足度系→その他」の順
22. [ ] 作業人手割当の優先順位が「建設開始が古い順（started_at 昇順）」

### UI・視覚表現
23. [ ] フッターに LABOR ブロック（160×180）が x=700-860 に新設される
24. [ ] BUILD ブロックが 260px に圧縮され、手札5枚（48×140）表示になる
25. [ ] 建設中パネルに半透明マスク（α=0.4）+ 建設リング（金色）が表示される
26. [ ] 稼働中パネル下部に緑ドット、停止中パネル下部に灰ドットが表示される
27. [ ] 人手不足時、OPS/WORK 行の数値が `COLOR_RED` で1.0sサイクル点滅する
28. [ ] 新規色定義が0個（既存 COLOR_* のみ使用）

### 品質
29. [ ] check_syntax.sh エラー0件
30. [ ] LogManager に `BUILDING_PLACED / BUILDING_COMPLETED` イベントが記録される

---

## 8. 依存関係・注意事項

### 8.1 ファイル別変更スコープ

| ファイル | 変更内容 | 想定行数 |
|---|---|---:|
| `data/cards_econ.json` | 建物カード8種に `build_time / required_work_labor / required_operation_labor` 追加・交換所に `category: "special"` 確認 | +30行 |
| `scripts/econ_mvp/EconDeckManager.gd` | `INITIAL_DECK_SPEC` 定数追加・`exclude_card(card_id) / discard_card(card_id)` 確認/追加 | +30行 |
| `scripts/econ_mvp/EconEconomy.gd` | `get_total_labor() / get_operation_labor() / get_work_labor()` 追加 | +20行 |
| `scripts/econ_mvp/EconGrid.gd` | `get_buildable_cells_for_card()` 追加（配置可能性判定のみ・ADR-003） | +40行 |
| `scripts/econ_mvp/EconBattle.gd` | `construction_sites` 辞書 + `start_construction() / _update_construction_progress(delta) / spawn_building(site) / _allocate_work_labor() / _allocate_operation_labor()` 追加・既存タイマー前段に `is_operating` ガード（ADR-003） | +180行 |
| `scripts/econ_mvp/EconBuilding.gd` | `is_operating` 変数追加・`_process_*` 関数先頭ガード追加・`_draw_construction_ring()` / `_draw_operation_dot()` 追加 | +50行 |
| `scripts/econ_mvp/EconMain.gd` | LABOR ブロック描画・BUILDブロック圧縮・建設予定地モードのクリックハンドラ | +180行 |
| `scripts/econ_mvp/EconUI.gd` | 配置可能マスハイライト・人手不足警告点滅 | +40行 |

> **ファイルサイズチェック（Architect 予防的品質管理）**: `EconMain.gd` は現状大きい既存ファイル。+180行 追加で 800行超になる可能性がある。実装前に `wc -l scripts/econ_mvp/EconMain.gd` で現状確認し、800行超予測になる場合は LABOR ブロック専用クラス（例: `LaborSliderUI.gd`）への分割を要件に追加すること。

### 8.2 疎結合ルール（CLAUDE.md 「疎結合ルール」厳守）

- **禁止**: `EconGrid` から `EconDeckManager.discard_pile.append(...)` のような他クラスの内部配列への直接代入
- **必須**: `EconDeckManager.discard_card(card_id) / exclude_card(card_id)` のような相手クラスのメソッド経由
- **禁止**: `EconBattle` から `EconBuilding.is_operating = true` の直接代入（OK だがプロパティ経由が望ましい場合は setter 経由）
- 新しいクラス間連携が必要になったら、まず ADR (`docs/meta/adr/`) に記録してから実装

### 8.3 用語統一ルール（CLAUDE.md 「用語統一ルール」厳守）

| 設計用語 | 実装用語 | 対応 |
|---|---|---|
| 建設時間 | construction_time / build_time | 同義（秒単位） |
| 建設進捗 | construction_progress | 0.0〜1.0 |
| 稼働人手 | operation_labor | 既存 alloc_work_ratio とは逆数関係であることを UI で明示 |
| 作業人手 | work_labor | 同上 |
| 人手総量 | total_labor | floor(人口 × 20%) |

### 8.4 KISS チェック（実装前自問リスト）

- [ ] 新規フィールドは `construction_sites` 1個と `is_operating` 1個のみか？
- [ ] 既存 `alloc_work_ratio` を流用しているか？（新たな ratio 変数を作っていないか）
- [ ] 既存 `BuildingType` enum を流用しているか？（新 enum を作っていないか）
- [ ] 建設キャンセル/予定地変更/予約キューを実装していないか？（Sprint 7 非対象）

### 8.5 廃止予定ファイル

- `docs/requirements/req_econ_initial_deck_sprint7.md`（11枚デッキ・旧版）
  - 本 Sprint 7 完了時に冒頭へ `STATUS: 廃止（→ REQUIREMENTS_SPRINT_7.md）` を追記
  - 13枚デッキ（本書）が新SSoT

### 8.6 既存実装との整合確認ポイント

実装着手前に以下を grep で確認すること：

- `EconBuilding.BuildingType` enum に HOUSE/PLAZA/TRADE_POST が定義されているか（→ 確認済み: 全て存在）
- `EconBuilding.BUILD_COSTS` の値が 4.2 表と一致するか（→ ほぼ一致・差分あれば仮置き値を表に従って更新）
- 既存 `card_house / card_plaza / card_trade_post` の JSON エントリが存在するか（→ 旧 Sprint 7 reqで「要確認」とされていた箇所・実装着手時に確認必須）

### 8.7 残論点（Sprint 8 へ持ち越し・企画書 §13）

以下は Sprint 7 では仮置きとし、Sprint 8 テストプレイで調整：
- 人手総量 = floor(人口 × 20%) の係数
- 稼働 70% / 作業 30% 初期値
- スライダー刻み 10%
- 建物ごとの建設時間・建設コスト・必要人手
- 稼働人手の優先順位
- 交換所の累計10資源で1ドローのバランス

---

## 9. 参照

- 企画書（SSoT）: `docs/sprint7_initial_deck_building_base_final.md`
- Designer企画: `docs/design/sprint7_designer_plan.md`
- 旧 Sprint 7 要件（11枚デッキ・廃止予定）: `docs/requirements/req_econ_initial_deck_sprint7.md`
- 関連 Sprint 9 要件: `docs/requirements/REQUIREMENTS_SPRINT_9.md`
- 既存実装: `scripts/econ_mvp/EconBuilding.gd:4`（BuildingType enum）
- 既存実装: `scripts/econ_mvp/EconEconomy.gd:52, 202`（alloc_work_ratio）
- 既存実装: `scripts/econ_mvp/EconDeckManager.gd:34`（setup・初期デッキ受け取り）
- 設計判断基準: `docs/design/design_principles.md`
- 用語: `docs/design/glossary.md`
- 核となる体験: `CLAUDE.md`「盤面を設計して、介入を仕込んで、答え合わせを観戦する」
- ADR-001（EconBattle スポーン一元化）: `docs/meta/adr/001_econ_spawn_centralized.md`
- ADR-003（Econ Construction Architecture Centralization）: `docs/meta/adr/003_econ_construction_architecture.md`
