# 防衛拠点（WATCHTOWER）建物 要件定義書

| 項目 | 内容 |
|------|------|
| プロジェクト | Econ MVP v0.2 |
| 上位設計（SSoT） | docs/GAME_DESIGN_V0_2_MVP.md（§3 建物分類, §4.3, §4.4, §4.8, §6.11 防壁, §6.12 見張り塔, §6.16 防衛兵力） |
| 上位要件 | docs/requirements/REQUIREMENTS_V0_2_MVP.md（§2.5 兵力・ユニット, §2.6 戦闘, §2.7 建物一覧） |
| タスク | Sprint 2 タスク「防衛拠点（WATCHTOWER）実装」 |
| 更新日 | 2026-05-02 |
| ステータス | DRAFT（CEO承認待ち） |
| 実装ディレクトリ | scripts/econ_mvp/ |

---

## 1. 概要・目的

### 1.1 目的
GAME_DESIGN §4.4 で定義された全11種類の建物のうち、未実装である「防衛拠点（WATCHTOWER）」を MVP に追加する。本MVPは敵・防壁システムが Sprint 5 以降に実装される **「敵なしMVP」** であるため、本要件では **enum追加と骨格（スタブ実装）のみ** をスコープとし、防衛兵力出撃ロジック・防壁回復ロジックは Sprint 5 以降の実装とする。

### 1.2 核となる体験との整合
- 「限られた資源の流し先を決める」：通常兵舎（攻撃用）と防衛拠点（防衛用）への配分判断を生む
- 「配分が戦況を作る」：防衛兵力は範囲内兵舎から引き抜く設計のため、攻防の兵力配分が戦況に直結する
- 3秒ルール：効果は「範囲内防壁を回復」「範囲内兵舎から防衛兵力出撃」のみで視認性が高い
- **本MVPではスタブ実装のため、上記体験は次期MVP以降で発現する**

### 1.3 GAME_DESIGN §4.4 の該当記述
> 防衛拠点 | アクティブ | 1 | TBD | 防衛兵力統括・防壁回復

### 1.4 GAME_DESIGN §6.12 の該当記述
| Lv | 名称 | 効果 |
|---|---|---|
| Lv1 | 防衛指揮所 | 防衛範囲2、範囲内兵舎から防衛兵力出撃、敵がいなくなったら生存兵力返還 |
| Lv2 | 修復指揮所 | 防衛範囲2、範囲内防壁を5秒ごとにHP+10回復（攻撃中も対象、破壊済みは復活しない） |
| Lv3 | 広域防衛司令部 | 防衛範囲3、範囲内防壁を5秒ごとにHP+15回復、防衛ユニット反応/帰還範囲も3 |

### 1.5 用語統一（GAME_DESIGN 付録B）
| 正式名称 | 別称（仕様書では使用禁止） |
|---|---|
| 防衛拠点 | 見張り塔（UI表示は可） |

> コード上は `BuildingType.WATCHTOWER`、設計文書上は「防衛拠点」、UI表示は「見張り塔」も可。

---

## 2. 変更対象ファイル

### 2.1 触ってよいファイル
| ファイル | 変更内容 |
|---|---|
| scripts/econ_mvp/EconBuilding.gd | enum 値追加・定数追加・BUILD_COSTS/BUILD_HP/REQUIRED_CONSTRUCTION 追記・_update_watchtower 関数追加（スタブ）・match 分岐追加・_draw 着色追加 |
| data/cards_econ.json | WATCHTOWER のカード定義を追加（既存建物カードに倣う） |
| docs/CHANGELOG.md | 実装後に PMO が完了記録を追記 |
| docs/roadmap.md | 実装後に PMO がタスク状態を更新 |

### 2.2 触らないファイル（明示的な禁止）
| ファイル | 理由 |
|---|---|
| scripts/econ_mvp/EconUnit.gd | 防衛兵力出撃ロジックは Sprint 5 で実装。本MVPでは触らない |
| scripts/econ_mvp/EconBattle.gd | 建物 update ループに既に組み込まれているため、改変不要 |
| scripts/econ_mvp/EconEconomy.gd | 通貨/資源の操作は不要（建設コスト支払いは既存処理で完結） |
| scripts/econ_mvp/EconGrid.gd | ヘックス座標・距離計算ロジックは流用のみ（hex_distance は範囲判定で利用） |
| scripts/econ_mvp/EconDeckManager.gd | 防衛拠点はカード使用以外でデッキに干渉しない |

### 2.3 関連 enum・命名規則
- enum 名：`BuildingType.WATCHTOWER`（GAME_DESIGN/REQUIREMENTS の英語表記に準拠）
- 用語：日本語表記「防衛拠点」、英語コード上は `WATCHTOWER`
- UI 表示「見張り塔」も許可（GAME_DESIGN 付録B）
- 旧 `FORTRESS`（要塞・ユニット生産用）と混同しない（FORTRESS = 守ユニット生産、WATCHTOWER = 防衛兵力統括）

---

## 3. 仕様テーブル

### 3.1 建物基本仕様

| 項目 | 値 | 根拠 |
|---|---|---|
| 種別 | アクティブ型 | GAME_DESIGN §4.3, §4.4 |
| 必要稼働人口 | 1 | GAME_DESIGN §4.4 |
| 建設コスト（Lv1） | 木材6 / 石材6 / 硫黄2 | **要確認**（GAME_DESIGN §12.3 で TBD。兵舎 BARRACKS=木材8、市場 TRADE_POST=木材5/石材5、採掘所 MINE=石材10/硫黄4 と比較し、軍事系・石材主体・通貨不要として提案） |
| 必要作業量（Lv1） | 8.0 | **要確認**（兵舎 5.0、採掘所 8.0 を参考に、防衛系の重要建物として 8.0 を提案） |
| 初期 HP | 100.0 | 兵舎 BARRACKS=100 と同水準（軍事系建物の標準値） |
| パッシブ効果 | なし | GAME_DESIGN §4.3（アクティブ型） |

### 3.2 効果仕様（防衛兵力統括・防壁回復）

| 項目 | Lv1 | Lv2 | Lv3 | 根拠 |
|---|---|---|---|---|
| 名称 | 防衛指揮所 | 修復指揮所 | 広域防衛司令部 | GAME_DESIGN §6.12 |
| 防衛範囲（hex距離） | 2 | 2 | 3 | GAME_DESIGN §6.12 |
| 防壁回復 | なし | +10 HP / 5秒 | +15 HP / 5秒 | GAME_DESIGN §6.12 |
| 防衛兵力出撃 | あり（範囲内兵舎から引き抜き） | あり | あり | GAME_DESIGN §6.12, §6.16 |
| 生存兵力返還 | 100% | 100% | 100% | GAME_DESIGN §6.16, §11.3 |
| 稼働条件 | 必要稼働人口1を満たす | 同左 | 同左 | GAME_DESIGN §4.3 |
| 破壊済み防壁の復活 | なし | なし | なし | GAME_DESIGN §6.12（破壊済みは復活しない） |

### 3.3 強化コスト（GAME_DESIGN §4.8 準拠）

| Lv | 強化コスト | 効果差分 |
|---|---|---|
| Lv1→Lv2 | 建設コストの 50%（端数切り上げ） | 防壁回復 +10HP/5秒を解禁 |
| Lv2→Lv3 | 建設コストの 100% | 防衛範囲 2→3、防壁回復 +10→+15 HP/5秒 |

具体的な強化コストは、§3.1 の建設コスト確定後に派生計算（木材6×0.5=3、石材6×0.5=3、硫黄2×0.5=1 → Lv1→Lv2）。

### 3.4 既存建物との比較（参考）

| 建物 | 木材 | 石材 | 硫黄 | 必要作業量 | 初期 HP |
|---|---:|---:|---:|---:|---:|
| BARRACKS（兵舎） | 8 | 0 | 0 | 5.0 | 100.0 |
| FORTRESS（要塞・守ユニット生産） | 0 | 10 | 0 | 8.0 | 200.0 |
| MINE（採掘所） | 10 | 4 | 0 | 8.0 | 100.0 |
| WATCHTOWER（防衛拠点・本要件） | 6 | 6 | 2 | 8.0 | 100.0 |

> 防衛拠点は石材主体（防壁を扱う性質）＋硫黄少量（軍事系の特殊資源）で、兵舎より重く要塞より軽い設計。

---

## 4. EconBuilding.gd への追加内容

### 4.1 enum BuildingType への追加
既存：
```
enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE, EQUIPMENT_SHOP, TRADE_POST, WALL, PLAZA, HOUSE, EXCHANGE, LIBRARY, LIBRARY_ADV, MUSEUM, ART_GALLERY }
```

変更後：
```
enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE, EQUIPMENT_SHOP, TRADE_POST, WALL, PLAZA, HOUSE, EXCHANGE, LIBRARY, LIBRARY_ADV, MUSEUM, ART_GALLERY, WATCHTOWER }
```

`WATCHTOWER` を末尾に追加（インデックス 17）。既存 enum 値の順序を変えない（cards_econ.json などの既存データが破壊されないようにするため）。

### 4.2 BUILD_COSTS への追加
```gdscript
static var BUILD_COSTS: Dictionary = {
    ...既存のまま...
    16: {},                         # ART_GALLERY（美術館・スタブ）
    17: {"wood": 6, "stone": 6, "sulfur": 2},  # WATCHTOWER（要件 §3.1）
}
```

### 4.3 BUILD_HP への追加
```gdscript
static var BUILD_HP: Dictionary = {
    ...既存のまま...
    16: 60.0,  # ART_GALLERY
    17: 100.0, # WATCHTOWER（要件 §3.1）
}
```

### 4.4 REQUIRED_CONSTRUCTION への追加
```gdscript
static var REQUIRED_CONSTRUCTION: Dictionary = {
    ...既存のまま...
    16: 5.0,   # ART_GALLERY
    17: 8.0,   # WATCHTOWER（要件 §3.1）
}
```

### 4.5 定数定義（class フィールド領域）
既存の `BARRACKS_PRODUCE_INTERVAL` 等のパターンに倣う：
```gdscript
# 防衛拠点：防衛兵力統括・防壁回復（要件 req_econ_watchtower_building.md）
const WATCHTOWER_RANGE_LV1 := 2          # 防衛範囲（hex距離）Lv1
const WATCHTOWER_RANGE_LV2 := 2          # 防衛範囲 Lv2
const WATCHTOWER_RANGE_LV3 := 3          # 防衛範囲 Lv3
const WATCHTOWER_REPAIR_INTERVAL := 5.0  # 防壁回復tick（秒）
const WATCHTOWER_REPAIR_AMOUNT_LV2 := 10 # Lv2 防壁回復量
const WATCHTOWER_REPAIR_AMOUNT_LV3 := 15 # Lv3 防壁回復量
```

### 4.6 インスタンス変数の追加
既存の `_produce_timer: float = 0.0` 等に倣う：
```gdscript
var _watchtower_repair_timer: float = 0.0  # 防壁回復tick用タイマー
var watchtower_level: int = 1              # Lv1〜Lv3（強化システム連動・MVPでは 1 固定）
```

> 注：建物 Lv 強化システムが MVP で未実装の場合、`watchtower_level` は 1 固定で運用する。Lv2/Lv3 の効果は本MVPでは発現しない。

### 4.7 _update_watchtower 関数の追加（**スタブ実装**）

**本MVPは敵なしMVPのため、防衛兵力出撃・防壁回復ロジックは骨格のみ実装し、実際の処理は Sprint 5 以降に実装する。**

```gdscript
func _update_watchtower(delta: float, economy: EconEconomy) -> void:
    # 稼働判定：稼働人口割当＆建設完了済みであること（既存の is_built 判定で担保）
    # MVP スコープ：本関数は骨格のみ。敵・防壁システムが未実装のため、ロジックは空で良い
    # 防衛兵力出撃ロジックは Sprint 5（敵実装後）に追加（§5.1）
    # 防壁回復ロジックは Sprint 5（防壁HPシステム拡張後）に追加（§5.2）

    # _resource_ready は常に true（消費資源なし・スタブ）
    _resource_ready = true

    # 防壁回復tickの空回し（Sprint 5 で内部処理を実装）
    _watchtower_repair_timer += delta
    if _watchtower_repair_timer >= WATCHTOWER_REPAIR_INTERVAL:
        _watchtower_repair_timer = 0.0
        # TODO(Sprint 5): watchtower_level >= 2 のとき範囲内防壁を回復
        # TODO(Sprint 5): 範囲内に敵がいるとき範囲内兵舎から防衛兵力を引き抜き出撃
        pass
```

> **スタブ実装の理由**：
> - 本MVPは敵ユニットが存在しない（`req_enemyless_mvp_logging.md` 参照）
> - 防壁HPの管理単位（パネル所属防壁グループ）は GAME_DESIGN §6.11 で定義されているが、回復処理が呼び出す対象API（例：`grid.repair_wall_hp(pos, amount)`）が未実装
> - 防衛兵力の引き抜き元（範囲内兵舎の `accumulated_force` 相当）も MVP では未実装
> - 本MVPでは「enum 追加・建設可能・稼働できる骨格」までを成立させ、実ロジックは Sprint 5 で接続する

> **疎結合ルール（CLAUDE.md より）**：
> - 他クラスの内部配列・フィールドへの直接代入・append は禁止
> - 状態変更は必ず相手クラスのメソッド経由で行う
> - Sprint 5 実装時は、防壁回復は `EconGrid.repair_wall_hp()`、防衛兵力出撃は `EconBuilding.request_defensive_force()` 相当のメソッド経由で実装する（**今回は実装しない**）

### 4.8 update 関数の match 分岐追加
既存：
```gdscript
match building_type:
    BuildingType.BARRACKS:
        _update_barracks(delta, economy)
    ...
    BuildingType.LIBRARY, BuildingType.LIBRARY_ADV, BuildingType.MUSEUM, BuildingType.ART_GALLERY:
        pass  # 次期MVPで効果設計
```

変更後：
```gdscript
match building_type:
    BuildingType.BARRACKS:
        _update_barracks(delta, economy)
    ...
    BuildingType.LIBRARY, BuildingType.LIBRARY_ADV, BuildingType.MUSEUM, BuildingType.ART_GALLERY:
        pass  # 次期MVPで効果設計
    BuildingType.WATCHTOWER:
        _update_watchtower(delta, economy)
```

### 4.9 _draw 関数の着色追加
既存：
```gdscript
match building_type:
    ...
    BuildingType.LIBRARY, BuildingType.LIBRARY_ADV, BuildingType.MUSEUM, BuildingType.ART_GALLERY: color = Color.LIGHT_GRAY  # スタブ
```

変更後：
```gdscript
match building_type:
    ...
    BuildingType.LIBRARY, BuildingType.LIBRARY_ADV, BuildingType.MUSEUM, BuildingType.ART_GALLERY: color = Color.LIGHT_GRAY  # スタブ
    BuildingType.WATCHTOWER: color = Color.STEEL_BLUE  # 防衛系・FORTRESS（SLATE_GRAY）と差別化
```

> 色は STEEL_BLUE（鋼色青）を提案。要塞 FORTRESS が SLATE_GRAY、兵舎 BARRACKS が PERU（茶系）であるため、防衛系として識別可能な青系を選択。デザイナー判断で変更可。

---

## 5. MVP実装スコープの明確化

### 5.1 本MVPで実装すること（最小限・骨格のみ）
- `BuildingType.WATCHTOWER` enum値追加（インデックス17）
- `BUILD_COSTS[17]`、`BUILD_HP[17]`、`REQUIRED_CONSTRUCTION[17]` の追加
- 防衛範囲・防壁回復量・回復tick間隔の定数定義
- `_update_watchtower()` の骨格関数（タイマー進行のみ。実ロジックは TODO コメント）
- `update()` の match 分岐追加
- `_draw()` の着色追加
- `data/cards_econ.json` への WATCHTOWER カード定義追加
- 建設キューから建設可能・稼働人口で稼働可能な状態まで到達

### 5.2 本MVPで実装しないこと（Sprint 5 以降）
- **防衛兵力出撃ロジック**（範囲内兵舎から `accumulated_force` を引き抜く処理）
- **生存兵力返還ロジック**（敵殲滅後に残存兵力を兵舎へ戻す処理）
- **防壁HP回復ロジック**（範囲内防壁グループの HP に `+10/+15` する処理）
- **範囲判定ロジック**（`grid.hex_distance` を使った範囲内パネル列挙）
- **Lv2/Lv3 強化システムとの連携**（`watchtower_level` は 1 固定）

### 5.3 Sprint 5 実装時の前提条件（参考情報）
Sprint 5 で本MVPの骨格にロジックを追加する際、以下が前提：
- 敵ユニット（`EconUnit`）が実装済み
- 防壁HP管理システム（パネル所属防壁グループ）が実装済み
- 兵舎の蓄積兵力フィールド（例：`barracks.accumulated_force: float`）が実装済み
- 防壁回復用API（例：`EconGrid.repair_wall_hp(pos, amount)`）が実装済み

これらの前提が揃ってから `_update_watchtower()` 内の TODO を実装する。

---

## 6. 検証条件

### 6.1 機能検証（本MVPスコープ）
- [ ] WATCHTOWER 建物がカードから建設できる（カード使用 → 建設キュー → 完成）
- [ ] 建設完了後、`is_built = true` になる
- [ ] 稼働人口1を割り当てたとき、`update()` の match 分岐で `_update_watchtower()` が呼ばれる
- [ ] `_update_watchtower()` 内でタイマーが進行する（println等で確認可能）
- [ ] 必要稼働人口1が割り当てられていない場合は機能しない（既存の建物稼働判定と同じ）
- [ ] 建設中（is_built=false）は機能しない
- [ ] **本MVPでは防衛兵力出撃・防壁回復は発生しない**ことを確認（スタブ実装の証跡）

### 6.2 構文検証
- [ ] `bash check_syntax.sh` がエラー0件で通過
- [ ] enum 値追加による既存実装の破壊なし（grep で BuildingType の利用箇所を確認）
- [ ] `BUILD_COSTS[17]` / `BUILD_HP[17]` / `REQUIRED_CONSTRUCTION[17]` が全て揃っている

### 6.3 疎結合検証
- [ ] EconBuilding.gd 内で `EconUnit` の内部フィールドへの直接アクセスなし（Sprint 5 で追加するロジックも含めて、メソッド経由で行う前提）
- [ ] EconBuilding.gd 内で `EconGrid` の内部フィールドへの直接代入なし（hex_distance の読み取りのみ許可）
- [ ] 他建物（BARRACKS等）の内部フィールドに直接アクセスしない

### 6.4 GAME_DESIGN 整合性検証
- [ ] §4.4 「アクティブ型・必要稼働人口1・防衛兵力統括・防壁回復」を仕様として記述している
- [ ] §6.12 の Lv別効果（範囲2/2/3、回復+10/+15、Lv3で帰還範囲も3）を仕様として記述している
- [ ] §6.16 の防衛兵力フロー（引き抜き → 迎撃 → 生存兵力返還100%）を仕様として記述している
- [ ] 用語統一：「防衛拠点」（仕様書）と `WATCHTOWER`（コード）の整合

---

## 7. MVP除外事項（実装しない）

### 7.1 防衛兵力出撃ロジック（Sprint 5）
- 範囲内兵舎の蓄積兵力を引き抜き、防衛ユニットとして出撃させる処理
- 同パネル最大3ユニット制約
- 敵ユニットがいない時の防衛ユニット帰還
- 生存兵力の100%返還
- 攻撃側ユニットは帰還しない非対称設計（GAME_DESIGN §6.16）

### 7.2 防壁回復ロジック（Sprint 5）
- 範囲内防壁グループの HP に Lv2=+10、Lv3=+15 を加算
- 攻撃中も対象（GAME_DESIGN §6.12）
- 破壊済み防壁は復活しない（GAME_DESIGN §6.12）

### 7.3 範囲判定ロジック（Sprint 5）
- `EconGrid.hex_distance(self.grid_pos, target.grid_pos)` で範囲内判定
- Lv1/Lv2 = 距離2以内、Lv3 = 距離3以内

### 7.4 建物 Lv 強化（Lv2/Lv3）
- Lv2/Lv3 の効果はすべて Sprint 5 以降で実装
- 本 MVP では `watchtower_level = 1` 固定

### 7.5 防衛範囲のビジュアル表示
- 防衛範囲を盤面上にハイライト表示する機能は本要件のスコープ外
- デザイナーから依頼があれば別要件として切り出す

### 7.6 複数防衛拠点の干渉
- 同一兵舎が複数防衛拠点の範囲内にある場合の優先順位は本要件のスコープ外
- Sprint 5 実装時に GAME_DESIGN §6.16 を再参照して決定

---

## 8. 実装上の注意

### 8.1 既存パターンとの整合
- `_update_barracks` `_update_fortress` `_update_workshop` のパターンに倣い、`_update_watchtower` を追加
- `_resource_ready` フラグは常に true（消費資源なしのため！マーク非表示）
- スタブ実装である旨をコメントに明記（TODO(Sprint 5)）

### 8.2 cards_econ.json への追加
建物カードが cards_econ.json に定義されている場合、以下のエントリを追加する必要がある：
```json
{
    "id": "watchtower",
    "name": "防衛拠点",
    "type": "building",
    "building_type": 17,
    "cost": {"wood": 6, "stone": 6, "sulfur": 2}
}
```

> 既存の cards_econ.json 構造を確認の上、整合する形式で追加すること。本要件では構造詳細は規定しない（実装時に既存カードに倣う）。

### 8.3 用語統一（CLAUDE.md「用語統一ルール」）
- 設計文書：「防衛拠点」（日本語）
- データ：`"watchtower"` / `WATCHTOWER`（英語コード）
- コード：`BuildingType.WATCHTOWER`
- UI 表示：「防衛拠点」または「見張り塔」（GAME_DESIGN 付録B 許可）
- 旧 `FORTRESS`（要塞・守ユニット生産）と混同しないこと

### 8.4 スタブ実装の証跡
- `_update_watchtower()` 内に `TODO(Sprint 5)` コメントを残す
- 本MVPで防衛効果が発現しないことをコードコメントで明示
- 検証条件 §6.1 で「防衛兵力出撃・防壁回復は発生しない」ことを確認する

---

## 9. CEO判断待ち事項（要確認）

| # | 確認事項 | 推奨案 |
|---:|---|---|
| Q1 | 建設コスト（木材6/石材6/硫黄2）は妥当か？ | 推奨：そのまま採用。理由は §3.4 の比較表 |
| Q2 | 必要作業量 8.0 は妥当か？ | 推奨：そのまま採用（採掘所と同水準。防衛系の重要建物として兵舎5.0より重く） |
| Q3 | 初期 HP 100.0 は妥当か？ | 推奨：そのまま採用（兵舎と同水準。要塞200より軽い軍事系） |
| Q4 | 防衛範囲 Lv1=2 を MVP の骨格に定数として埋め込んでよいか？ | 推奨：YES（GAME_DESIGN §6.12 で確定済） |
| Q5 | 本MVPで防衛兵力出撃・防壁回復をスタブとすることに同意するか？ | **必須確認**：敵なしMVPの方針に基づきスタブ提案。CEO がフル実装を望む場合は Sprint を再設計する必要あり |
| Q6 | Lv2/Lv3 を本MVPで実装するか？ | **確定提案：実装しない**（敵・防壁システム実装後の Sprint 5 で実装） |
| Q7 | 建物色は STEEL_BLUE で良いか？ | デザイナー判断に委ねる |
| Q8 | カード名「防衛拠点」「見張り塔」のどちらを cards_econ.json `name` に入れるか？ | 推奨：「防衛拠点」（仕様書正式名称） |

---

## 10. 関連ドキュメント

- `docs/GAME_DESIGN_V0_2_MVP.md`（§3 建物分類, §4.3 アクティブ型, §4.4 建物一覧, §4.8 建物強化, §6.11 防壁, §6.12 見張り塔, §6.16 防衛兵力, 付録B 用語統一）
- `docs/requirements/REQUIREMENTS_V0_2_MVP.md`（§2.5 兵力・ユニット, §2.6 戦闘, §2.7 建物一覧）
- `docs/requirements/req_enemyless_mvp_logging.md`（敵なしMVPの方針）
- `docs/requirements/req_econ_exchange_building.md`（同様パターンの建物追加要件・参考）
- `scripts/econ_mvp/EconBuilding.gd`（実装対象本体）
- `scripts/econ_mvp/EconGrid.gd`（hex_distance 利用・Sprint 5 で連携）
- `scripts/econ_mvp/EconUnit.gd`（Sprint 5 で連携）
- `data/cards_econ.json`（カード定義）

---

更新日: 2026-05-02
バージョン: v0.1（初版・骨格スタブ実装）
ステータス: DRAFT（CEO承認待ち）
