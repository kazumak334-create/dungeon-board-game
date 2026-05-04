STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# Econ MVP v0.2 ハードコード最小化＆疎結合設計書

**更新日:** 2026-05-03（初版）
**ステータス:** 実装リソース（一時）／実装後に `docs/requirements/REQUIREMENTS_V0_2_MVP.md` へ統合して削除
**対象:** scripts/econ_mvp/EconEconomy.gd / EconBuilding.gd / EconBattle.gd / EconMain.gd / EconDeckManager.gd ／ data/cards_econ.json

**関連ドキュメント:**
- `docs/requirements/REQUIREMENTS_V0_2_MVP.md`（v0.2 上位要件）
- `docs/requirements/req_econ_draw_hand_circulation.md`（ドロー・手札循環）
- `docs/requirements/req_econ_card_placement_flow.md`（カード配置フロー）
- `docs/meta/adr/001_econ_spawn_centralized.md`（EconBattle 一元化規約）
- `docs/meta/adr/002_tile_resource_separation.md`（タイル/リソース分離）
- `CLAUDE.md`「用語統一ルール」「KISS 原則」「疎結合ルール（Econ MVP）」

---

## 修正履歴

| 日付 | 版 | 修正内容 | 修正者 |
|------|----|---------|------|
| 2026-05-03 | v0.1（初版） | 全ハードコード値の集約・疎結合設計・優先度定義 | Architect |

---

## 1. 概要・目的

Econ MVP v0.2 のコードベースには「同じ値を複数箇所に書いている」「クラス間の責任分界が不明瞭」というハードコード／結合度の問題が残存している。本設計書は以下を行う：

1. **全ハードコード値の集約（§2）** — どこに何が書かれているかをテーブル化
2. **疎結合設計（§3）** — 値の所有者と参照経路を明確化
3. **実装方針（§4）** — v0.2 内で削減すべきハードコードと次フェーズ繰越分の優先度
4. **ADR 候補（§5）** — 記録すべき設計決定の洗い出し

**設計原則（CLAUDE.md より）:**
- KISS：足し算より引き算。新しいクラス／JSON は最小限に
- 単一の真実のソース（SSOT）：同じ値を2箇所以上に書かない
- 疎結合：他クラスの内部配列・フィールドへの直接代入禁止（メソッド経由）

---

## 2. パラメータ集約ドキュメント

### 2.1 全ハードコード一覧

| # | 値 | 定義場所 | 型／値 | 意味・用途 | 参照先 |
|---|----|---------|-------|----------|-------|
| 1 | `BASE_POPULATION_CAP` | EconEconomy.gd L8 | int = 50 | 拠点（BASE）が常時供給する人口上限 | `calculate_population_cap()` の初期値・REQUIREMENTS §7.4 |
| 2 | `HOUSE_POP_CAP_LV1` | EconEconomy.gd L9 | int = 10 | 住居 Lv1 の人口上限供給量 | 未使用（将来用） |
| 3 | HOUSE Lv 別人口上限 | EconEconomy.gd L356 | `[10, 15, 20]` ローカル配列 | 住居 Lv1/Lv2/Lv3 の上限ボーナス | `calculate_population_cap()` 内ローカル定義 |
| 4 | `BARRACKS_POWER_PER_SEC` | EconEconomy.gd L10 | float = 0.2 | 兵舎 1棟あたりの兵力蓄積/秒 | `accumulate_military_power()` |
| 5 | `INITIAL_FOOD` | EconEconomy.gd L11 | int = 30 | 初期食料 | `initialize_v0_2()` |
| 6 | `INITIAL_CURRENCY` | EconEconomy.gd L12 | int = 100 | 初期通貨 | `initialize_v0_2()` |
| 7 | 初期 resources 辞書 | EconEconomy.gd L22, L371 | `{wood/stone/sulfur=5, food=30, iron/cotton=5}` | 各資源の初期値 | コンストラクタ・`initialize_v0_2()`（**2箇所重複**） |
| 8 | 初期 wheat | EconEconomy.gd L17 | int = 10 | 食料の後方互換フィールド初期値 | `initialize_v0_2()` で上書き |
| 9 | `WHEAT_CONSUME_INTERVAL` / `WHEAT_PER_UNIT` | EconEconomy.gd L48-49 | 5.0 / 0.5 | 旧食料消費（v0.2 では未使用？） | 廃止候補 |
| 10 | `TICK_INTERVAL` | EconEconomy.gd L58 | float = 5.0 | 経済ループの 5秒tick | `update()` |
| 11 | 食料消費レート | EconEconomy.gd L119 | `population_used / 10` | 人口10人毎に5秒で食料-1 | `update()` 内マジックナンバー |
| 12 | 幸福度ペナルティ | EconEconomy.gd L130 | -10 | 食料不足時の幸福度減少 | `update()` 内マジックナンバー |
| 13 | 幸福度クランプ範囲 | EconEconomy.gd L153 | 0-100 | 幸福度の上下限 | `update()` 内マジックナンバー |
| 14 | 幸福度状態閾値 | EconEconomy.gd L194-201 | 70/40/20 | high/normal/dissatisfied/danger 境界 | `get_happiness_state()` |
| 15 | 生産補正係数 | EconEconomy.gd L233-240 | 0.9 / 0.75 / 1.0 | 幸福度別生産倍率 | `get_happiness_production_modifier()` |
| 16 | 兵力補正係数 | EconEconomy.gd L246-252 | 1.1 / 0.8 / 1.0 | 幸福度別兵力倍率 | `get_happiness_military_modifier()` |
| 17 | snap_values | EconEconomy.gd L175 | `[0.25, 0.5, 0.75]` | 人口配分のスナップ値 | `snap_alloc_ratio()` |
| 18 | Lv ボーナス係数 | EconEconomy.gd L78 | `1.0 + (lv-1)*0.25` | Lv1=1.0, Lv2=1.25, Lv3=1.5 | `update()` 内マジックナンバー |
| 19 | `BUILD_COSTS` | EconBuilding.gd L15-35 | Dictionary（19エントリ） | 建物別建設コスト（旧経路用） | **cards_econ.json の `cost` と重複** |
| 20 | `BUILD_HP` | EconBuilding.gd L37-57 | Dictionary（19エントリ） | 建物別最大HP | cards_econ.json の `hp` と重複（カード経由配置時のみ）|
| 21 | `REQUIRED_CONSTRUCTION` | EconBuilding.gd L90-110 | Dictionary（19エントリ） | 建物別建設必要作業量 | cards_econ.json の `required_work` と重複 |
| 22 | 各種生産間隔・コスト | EconBuilding.gd L61-87 | const 多数 | BARRACKS/FORTRESS/WORKSHOP/VILLAGE/SMITHY/WATCHTOWER の生産パラメータ | 各 `_update_*()` |
| 23 | `STOCKPILE_CAP` | EconBuilding.gd L117 | int = 6 | ストックパイル上限 | `add_stock()` |
| 24 | `btype_map`（EconMain） | EconMain.gd L1210-1225 | Dictionary（15エントリ） | 文字列→Enum マッピング | `_place_building_from_card()` 内ローカル |
| 25 | `btype_map`（EconBattle） | EconBattle.gd L100-119 | Dictionary（19エントリ） | 文字列→Enum マッピング | `_create_building_from_card()` 内ローカル（**EconMain版と重複・微妙に異なる**） |
| 26 | `INITIAL_HAND_SIZE` | EconDeckManager.gd L10 | int = 5 | 初期手札枚数 | `_init_hand()` |
| 27 | `HAND_MAX_SIZE` | EconDeckManager.gd（既存定数） | int = 8 | 手札上限 | ドロー保留判定 |
| 28 | 自建物配置距離 | EconMain.gd L1233 | <= 3 | 半径3hex 内配置制限 | `_place_building_from_card()` |
| 29 | プレイヤー BASE 位置 | EconMain.gd L180 | Vector2i(1, 6) | プレイヤー拠点固定座標 | `_setup_initial_entities()` |
| 30 | 敵 BASE 位置 | EconMain.gd L174 | Vector2i(24, 6) | 敵拠点固定座標 | `_setup_initial_entities()` |

### 2.2 値の重複・不整合パターン

| 重複 | 場所 A | 場所 B | リスク |
|------|--------|-------|-------|
| 建設コスト | EconBuilding.BUILD_COSTS | data/cards_econ.json `cost` | カード経路と既存経路で値が乖離する可能性。v0.2 では cards_econ.json が SSOT、BUILD_COSTS は旧経路（テスト・直接生成）で使用 |
| 建物 HP | EconBuilding.BUILD_HP | data/cards_econ.json `hp` | カード配置時は cards_econ.json 値で上書き（EconBattle L128-130）。直接生成時は BUILD_HP |
| btype_map | EconMain.gd L1210-1225 | EconBattle.gd L100-119 | エントリ数・キーが微妙に異なる（EconBattle に FORTRESS / WORKSHOP / EQUIPMENT_SHOP / WHEAT_EXTRACTOR が追加で存在） |
| 初期 resources | EconEconomy.gd L22 | EconEconomy.gd L371 | コンストラクタ初期化と `initialize_v0_2()` で同じ値を2回書いている |

---

## 3. 疎結合設計

### 3.1 単一の真実のソース（SSOT）方針

| 概念 | SSOT | 参照経路 |
|------|-----|---------|
| 建物別コスト | **cards_econ.json `cost`** | カード辞書経由で `consume_resources(card)`／`can_afford_card(card)` に渡す |
| 建物別 HP | cards_econ.json `hp` | EconBattle._create_building_from_card() で `b.hp = card.hp` |
| 建物別必要作業 | cards_econ.json `required_work` | （現状未配線。ハーベスター建設プロセスでは EconBuilding.REQUIRED_CONSTRUCTION 参照） |
| 建物別人口要求 | cards_econ.json `population_required` | EconBattle.play_card_to_cell()／EconMain._place_building_from_card() |
| 建物別人口供給 | cards_econ.json `population_supply` | **HOUSE のみ非0だが、実際の上限計算は `EconEconomy.calculate_population_cap()` が建物リスト走査で行う**（カード値は表示用） |
| 文字列→Enum マッピング | **EconBuilding.gd の static 関数 `btype_from_string()`** ← 新設提案 | EconMain／EconBattle の両方からこの関数を呼ぶ |
| population_cap | **EconEconomy.population_cap** | 読取は他クラス可、書込は EconEconomy 経由（`calculate_population_cap()` の戻り値を代入） |
| population_used | **EconEconomy.population_used** | 加算は呼出側で `economy.population_used += N`（既存パターン）／メソッド化提案あり |

### 3.2 btype_map の一元管理

**現状の問題:** EconMain.gd と EconBattle.gd が独立した `btype_map` Dictionary をローカル定義しており、エントリが微妙にずれている（v0.2 で実装漏れの主原因の一つ）。

**設計方針（v0.2 実施推奨）:**

EconBuilding.gd に static 関数を追加：

```gdscript
# EconBuilding.gd 末尾に追加
static func btype_from_string(btype_str: String) -> int:
    var m: Dictionary = {
        "BARRACKS":         BuildingType.BARRACKS,
        "FORTRESS":         BuildingType.FORTRESS,
        "WORKSHOP":         BuildingType.WORKSHOP,
        "VILLAGE":          BuildingType.VILLAGE,
        "BASE":             BuildingType.BASE,
        "SAWMILL":          BuildingType.SAWMILL,
        "MINE":             BuildingType.MINE,
        "EQUIPMENT_SHOP":   BuildingType.EQUIPMENT_SHOP,
        "TRADE_POST":       BuildingType.TRADE_POST,
        "WALL":             BuildingType.WALL,
        "PLAZA":            BuildingType.PLAZA,
        "HOUSE":            BuildingType.HOUSE,
        "EXCHANGE":         BuildingType.EXCHANGE,
        "LIBRARY":          BuildingType.LIBRARY,
        "SMITHY":           BuildingType.SMITHY,
        "WATCHTOWER":       BuildingType.WATCHTOWER,
        # cards_econ.json 別名（互換マッピング）
        "WOOD_EXTRACTOR":   BuildingType.SAWMILL,
        "STONE_EXTRACTOR":  BuildingType.MINE,
        "SULFUR_EXTRACTOR": BuildingType.MINE,
        "IRON_EXTRACTOR":   BuildingType.MINE,
        "COTTON_EXTRACTOR": BuildingType.VILLAGE,
        "WHEAT_EXTRACTOR":  BuildingType.VILLAGE,
        "MARKET":           BuildingType.TRADE_POST,
    }
    return m.get(btype_str, -1)  # -1 = 未知
```

**呼出側（EconMain・EconBattle）:**
```gdscript
var btype: int = EconBuilding.btype_from_string(btype_str)
if btype < 0:
    _add_log("Unknown building type: %s" % btype_str)
    return
```

**根拠:** EconBuilding.gd は BuildingType Enum を所有しているため、文字列→Enum 変換も同クラスで持つのが自然（凝集度向上）。**Dictionary を JSON や別ファイルに切り出さない理由は KISS：1関数で完結し、Enum 変更時に同ファイル内で修正完結する**。

### 3.3 EconBuilding.BUILD_COSTS と cards_econ.json の同期方法

**v0.2 の方針: 二重管理を許容、ただし参照経路を分ける**

| 経路 | コスト参照先 |
|------|-----------|
| カード配置経路（EconMain._place_building_from_card / EconBattle.play_card_to_cell） | **cards_econ.json `cost`**（card.cost） |
| 直接生成経路（テスト・初期配置・AI 等） | EconBuilding.BUILD_COSTS（フォールバック用） |

**理由:** v0.2 では `BUILD_COSTS` を完全削除すると初期農村配置・敵 AI 配置などの非カード経路が壊れる。**v0.3 で全経路をカード化してから `BUILD_COSTS` 削除を検討する**（KISS：今期は段階的移行）。

**整合性検証ルール（追加提案）:** `tools/check_card_cost_sync.py`（仮）で `BUILD_COSTS[btype]` と `cards_econ.json[building_type=btype].cost` を突合し乖離があれば warning。実装は次フェーズで OK。

### 3.4 population_cap / population_used の責任分担

| 概念 | 所有者 | 計算ロジック | 更新タイミング | 更新者 |
|------|-------|------------|------------|-------|
| population_cap | EconEconomy | `calculate_population_cap()` が `BASE_POPULATION_CAP + sum(HOUSE Lv ボーナス)` を返す | HOUSE 配置時／HOUSE 破壊時 | 呼出側が `economy.population_cap = economy.calculate_population_cap()` |
| population_used | EconEconomy | 単純加算 | カード配置成功時／建物破壊時／突撃時兵力減算後 | 呼出側が `economy.population_used += N` |

**疎結合チェック:** 上記は CLAUDE.md「疎結合ルール」上、外部からのフィールド代入は本来禁止だが、**現状は許容**（v0.2 では `set_population_used(n)` のような setter 化はせず、直接代入を続ける）。理由：

1. 加算箇所が4箇所（カード配置／建物破壊／突撃兵力化／pop_overflow 解決）に分散しており、setter 化のメリット小
2. 計算ロジック（`calculate_population_cap()`）はメソッド化済み＝設計の本質的な疎結合は守られている

**v0.3 検討事項:** `economy.allocate_population(card)` / `economy.release_population(card)` のメソッド化（ADR 候補）。

### 3.5 economy（EconEconomy）と building（EconBuilding）の依存方向

**現状の依存:**
- EconBuilding は EconEconomy を引数で受け取る（`_update_*(delta, economy)`）— OK（外部注入）
- EconEconomy は building リストを `buildings: Array` フィールドで保持（L62）— EconBattle が代入する（直接代入だが「リストへの参照保持」のみで内部状態書換はしていない）

**判定:** v0.2 では現状維持で OK。
**v0.3 検討:** EconEconomy を「建物リストを引数で受け取る純関数」に近づけ、`buildings` フィールド廃止する案（ADR 候補）。

---

## 4. 実装方針・優先度

### 4.1 v0.2 内（MVP 必須）

| # | 項目 | 工数感 | 効果 |
|---|------|------|-----|
| A | **btype_map 一元化（§3.2）** | 小（1関数追加 + 2箇所置換） | EconMain と EconBattle の不整合解消・将来の建物追加時のメンテコスト半減 |
| B | **初期 resources の重複削除** | 極小（コンストラクタ初期値削除し `initialize_v0_2()` で統一） | SSOT 化・初期値変更時の修正漏れ防止 |
| C | **`req_econ_card_placement_flow.md` 実装** | 中（呼出順序の正規化） | 配置フロー全体の整合性確保（リソース・人口チェック実装） |

### 4.2 v0.3 以降（次フェーズ）

| # | 項目 | 工数感 | 効果 |
|---|------|------|-----|
| D | EconBuilding.BUILD_COSTS の段階的削除 | 大（非カード経路もカード化が必要） | コスト管理の SSOT 完全化 |
| E | EconEconomy のマジックナンバー定数化（食料消費レート・幸福度ペナルティ等） | 中 | 設計値変更時の追跡性向上 |
| F | `economy.allocate_population(card)` メソッド化（ADR 候補） | 小 | 疎結合度向上・テスタビリティ向上 |
| G | `tools/check_card_cost_sync.py` 整合性チェッカ | 中 | 自動回帰検出 |
| H | EconEconomy.buildings フィールド廃止検討（ADR 候補） | 大 | 純関数化による疎結合度向上 |
| I | 旧 WHEAT_CONSUME_INTERVAL/WHEAT_PER_UNIT 削除 | 極小 | 死コード除去 |

### 4.3 KISS 引き算チェック

本要件で**追加するもの**：
- 1 static 関数（EconBuilding.btype_from_string）

**追加しないもの（意図的に除外）:**
- 新クラス（ParameterRegistry / ConfigLoader 等）— 過剰設計
- 新 JSON ファイル（building_config.json 等）— cards_econ.json で十分
- グローバル Singleton（GlobalConfig 等）— Godot Autoload は他に存在せず、v0.2 では導入しない
- DI コンテナ — KISS 原則違反

---

## 5. ADR 候補（次フェーズ）

以下を `docs/meta/adr/` に追記検討。

### ADR 候補 003: 建物文字列→Enum 変換の EconBuilding 集約
- 背景: EconMain と EconBattle で btype_map が重複・不整合
- 決定: EconBuilding.btype_from_string() に集約
- 代替案: JSON 化（却下：KISS）／Singleton 化（却下：オーバーキル）

### ADR 候補 004: 建物コスト管理の段階的 SSOT 化
- 背景: BUILD_COSTS と cards_econ.json の二重管理
- 決定（v0.3）: 全経路をカード経由に統一し BUILD_COSTS を削除
- 移行戦略: ① 整合性チェッカ追加 → ② 非カード経路の段階的カード化 → ③ BUILD_COSTS 削除

### ADR 候補 005: 人口割当のメソッド化
- 背景: `economy.population_used += N` の直接加算が4箇所に分散
- 決定（v0.3）: `economy.allocate_population(amount)` / `release_population(amount)` を導入
- 効果: 疎結合度向上・ロギング一元化・将来のバリデーション追加容易化

---

## 6. 実装パターン（参考コードスニペット）

### 6.1 btype_map 一元化（§3.2 採用時）

**EconBuilding.gd（追加）:**
```gdscript
# ファイル末尾に追加
static func btype_from_string(btype_str: String) -> int:
    var m: Dictionary = {
        "BARRACKS":         BuildingType.BARRACKS,
        "FORTRESS":         BuildingType.FORTRESS,
        # ... §3.2 参照
    }
    return m.get(btype_str, -1)
```

**EconMain.gd._place_building_from_card（変更）:**
```gdscript
# Before
var btype_map: Dictionary = { "BARRACKS": ..., ... }
if not btype_map.has(btype_str):
    _add_log("Unknown building type: %s" % btype_str)
    return
var btype: int = int(btype_map[btype_str])

# After
var btype: int = EconBuilding.btype_from_string(btype_str)
if btype < 0:
    _add_log("Unknown building type: %s" % btype_str)
    return
```

**EconBattle.gd._create_building_from_card（変更）:** 同上のパターンで Dictionary 削除→`btype_from_string()` 呼出に置換。

### 6.2 初期 resources 重複削除

**EconEconomy.gd（変更）:**
```gdscript
# Before
var resources: Dictionary = {"wood": 5, "stone": 5, "sulfur": 5, "food": 30, "iron": 5, "cotton": 5}
...
func initialize_v0_2() -> void:
    resources = {"wood": 5, "stone": 5, "sulfur": 5, "food": INITIAL_FOOD, "iron": 5, "cotton": 5}

# After
const INITIAL_RESOURCES: Dictionary = {
    "wood": 5, "stone": 5, "sulfur": 5,
    "food": INITIAL_FOOD,
    "iron": 5, "cotton": 5,
}
var resources: Dictionary = INITIAL_RESOURCES.duplicate()
...
func initialize_v0_2() -> void:
    resources = INITIAL_RESOURCES.duplicate()
```

定数 1 箇所定義 → 2 箇所参照に集約。値変更時の修正漏れ防止。

---

## 7. 検証方法

### 7.1 静的検証
- `bash check_syntax.sh` でパースエラー0件
- 既存テスト（あれば）の回帰なし
- grep で `btype_map` のローカル定義が EconBuilding.gd 以外で残っていないことを確認

### 7.2 動作確認シナリオ

| # | シナリオ | 確認観点 |
|---|---------|---------|
| 1 | 既存カード配置（HOUSE / BARRACKS / VILLAGE 等） | 配置成功・コスト消費・人口反映が変化しない |
| 2 | EconBattle.play_card_to_cell() 経由の配置 | btype_from_string 経由で正しい Enum が返る |
| 3 | EconMain._place_building_from_card() 経由の配置 | btype_from_string 経由で正しい Enum が返る |
| 4 | 不明な btype_str 渡し | 両経路ともログ出力・配置失敗（既存挙動維持） |
| 5 | 初期化（initialize_v0_2 呼出） | resources の値が INITIAL_RESOURCES と一致 |

### 7.3 整合性チェック（次フェーズ）
v0.3 で導入予定：
```bash
python tools/check_card_cost_sync.py
# 期待出力: All cards in sync. (or warnings list)
```

---

## 8. 制約・注意事項

### 8.1 既存コードとの整合性
- `EconBuilding.BUILD_COSTS` は v0.2 内では削除しない（非カード経路のフォールバック）
- `EconEconomy.buildings` フィールドは v0.2 内では維持（廃止は v0.3 ADR で議論）
- ADR-001（EconBattle 一元化規約）は維持。本要件は規約に違反しない

### 8.2 用語整合性（CLAUDE.md）
| 用語 | コード | 設計文書 |
|------|------|---------|
| btype（建物タイプ） | EconBuilding.BuildingType | GAME_DESIGN.md §2.7 |
| population_cap / used | EconEconomy.population_cap / used | REQUIREMENTS_V0_2_MVP.md §7.4 |
| cost | cards_econ.json `cost`（Dictionary） | REQUIREMENTS_V0_2_MVP.md §8.3 |
| population_required / supply | cards_econ.json | REQUIREMENTS_V0_2_MVP.md §8.5 |

逆数関係・別名関係なし。

### 8.3 KISS チェック
- 新規ファイル: なし
- 新規 JSON: なし
- 新規 Singleton: なし
- 新規クラス: なし
- 追加メソッド: 1（`btype_from_string`）
- 削除（v0.3）: BUILD_COSTS / 旧 WHEAT 定数 / EconEconomy.buildings フィールド（候補）

足し算より引き算優位。

---

## 9. 確定事項・繰越項目

### 9.1 v0.2 で確定
- btype_map の EconBuilding.btype_from_string() 集約（§3.2）
- 初期 resources の INITIAL_RESOURCES 定数化（§6.2）
- BUILD_COSTS の段階的維持（cards.json 経路を主、BUILD_COSTS は副）

### 9.2 v0.3 以降に繰越
- BUILD_COSTS の完全削除（ADR 候補 004）
- population 割当のメソッド化（ADR 候補 005）
- EconEconomy.buildings フィールドの引数化（ADR 候補）
- 整合性チェッカ自動化（tools/check_card_cost_sync.py）
- マジックナンバー（食料消費レート 1/10、幸福度ペナルティ -10 等）の名前付き定数化
