# 交換所（EXCHANGE）建物 要件定義書

| 項目 | 内容 |
|------|------|
| プロジェクト | Econ MVP v0.2 |
| 上位設計（SSoT） | docs/GAME_DESIGN_V0_2_MVP.md（§3.3, §4.3, §4.4, §4.8, §5.1） |
| 上位要件 | docs/requirements/REQUIREMENTS_V0_2_MVP.md（§2.4.1, §2.7, §6.4） |
| タスク | Sprint 2 タスク 2-2「交換所（EXCHANGE）実装」 |
| 更新日 | 2026-05-02 |
| ステータス | DRAFT（CEO承認待ち） |
| 実装ディレクトリ | scripts/econ_mvp/ |

---

## 1. 概要・目的

### 1.1 目的
通貨を消費してデッキから追加ドローするアクティブ型建物「交換所（EXCHANGE）」を MVP に追加する。GAME_DESIGN §4.4 で定義された全11種類の建物のうち、未実装である交換所を実装し、「通貨をドローに変換する」ローグライト・デッキビルドの選択肢を成立させる。

### 1.2 核となる体験との整合
- 「限られた資源（通貨）の流し先を決める」：通貨を即時建設・政策コスト・交換所ドローに振り分ける選択肢を増やす
- 「配分が戦況を作る」：ドローを増やして展開を加速するか、通貨を温存して即時建設に使うかの判断を生む
- 3秒ルール：効果は「通貨を払って1枚引く」のみで視認性が高い

### 1.3 GAME_DESIGN §4.4 の該当記述
> 交換所 | アクティブ | 1 | TBD | 通貨を消費して追加ドロー（Lv1基準、Lv2以上はCT短縮またはコスト削減）

### 1.4 REQUIREMENTS §6.4 の該当記述（確定事項）
- 交換所の追加ドロー消費は **通貨のみ**
- §2.2.5 の「リソース-15で追加ドロー」とは **別経路**：
  - 追加ドロー（カード固有）：対象リソース15
  - 交換所の追加ドロー：通貨（CT基準・Lvで短縮/コスト削減）

---

## 2. 変更対象ファイル

### 2.1 触ってよいファイル
| ファイル | 変更内容 |
|---|---|
| scripts/econ_mvp/EconBuilding.gd | enum 値追加・定数追加・BUILD_COSTS/BUILD_HP/REQUIRED_CONSTRUCTION 追記・_update_exchange 関数追加・match 分岐追加・_draw 着色追加 |
| data/cards_econ.json | EXCHANGE のカード定義を追加（cards_econ.json に建物カードがある場合） |
| docs/CHANGELOG.md | 実装後に PMO が完了記録を追記 |
| docs/roadmap.md | 実装後に PMO がタスク状態を更新 |

### 2.2 触らないファイル（明示的な禁止）
| ファイル | 理由 |
|---|---|
| scripts/econ_mvp/EconDeckManager.gd | 既存 `request_extra_draw("currency")` をそのまま呼び出すだけ。**改変しない** |
| scripts/econ_mvp/EconEconomy.gd | currency フィールドの操作は EconDeckManager 内部で完結している |
| scripts/econ_mvp/EconBattle.gd | 建物 update ループに既に組み込まれているため、改変不要 |
| scripts/econ_mvp/EconGrid.gd | ヘックス座標・距離計算ロジックは流用のみ |

### 2.3 関連 enum・命名規則
- enum 名：`BuildingType.EXCHANGE`（GAME_DESIGN/REQUIREMENTS の英語表記に準拠）
- 用語：日本語表記「交換所」、英語コード上は `EXCHANGE`
- 旧 `TRADE_POST`（市場）と混同しない（市場＝通貨**生産**、交換所＝通貨**消費でドロー**）

---

## 3. 仕様テーブル

### 3.1 建物基本仕様

| 項目 | 値 | 根拠 |
|---|---|---|
| 種別 | アクティブ型 | GAME_DESIGN §4.3, §4.4 |
| 必要稼働人口 | 1 | GAME_DESIGN §4.4 |
| 建設コスト（Lv1） | 木材4 / 石材2 / 通貨10 | **要確認**（GAME_DESIGN §12.3 で TBD。市場 TRADE_POST=木材5/石材5 と同等以下、機能差から通貨コストを追加して提案） |
| 必要作業量（Lv1） | 5.0 | **要確認**（市場 TRADE_POST=5.0 と同水準で提案） |
| 初期 HP | 80.0 | 市場 TRADE_POST と同じ。生産系建物の標準値 |
| パッシブ効果 | なし | GAME_DESIGN §4.3（アクティブ型） |

### 3.2 効果仕様（追加ドロー）

| 項目 | Lv1 | Lv2 | Lv3 | 根拠 |
|---|---|---|---|---|
| 概念 | 基本ドロー | **未定**（次期MVP） | **未定**（次期MVP） | 2026-05-02 |
| ドロー消費通貨 | 15 | TBD | TBD | Lv2/Lv3は次期MVPで設計 |
| クールダウン（CT） | 30秒 | TBD | TBD | Lv2/Lv3は次期MVPで設計 |
| 1ドロー枚数 | 1枚 | TBD | TBD | GAME_DESIGN §3.3 |
| 稼働条件 | 必要稼働人口1を満たす | 同左 | 同左 | GAME_DESIGN §4.3 |

> **方針（2026-05-02）**：Lv2/Lv3 の効果・数値はすべて未定。次期MVPで設計する。本MVPでは Lv1 のみ実装する。

### 3.3 強化コスト（GAME_DESIGN §4.8 準拠）

| Lv | 強化コスト | 効果差分 |
|---|---|---|
| Lv1→Lv2 | 建設コストの 50%（端数切り上げ） | 消費15→10、CT 30→20 |
| Lv2→Lv3 | 建設コストの 100% | 消費10→5、CT 20→10 |

具体的な強化コストは、§3.1 の建設コスト確定後に派生計算（木材4×0.5=2、石材2×0.5=1、通貨10×0.5=5 → Lv1→Lv2）。

### 3.4 既存建物との比較（参考）

| 建物 | 木材 | 石材 | 必要作業量 | 初期 HP |
|---|---:|---:|---:|---:|
| TRADE_POST（市場） | 5 | 5 | 5.0 | 80.0 |
| EXCHANGE（交換所・本要件） | 4 | 2 | 5.0 | 80.0 |
| HOUSE（住居） | 3 | 0 | 3.0 | 60.0 |

> 交換所は「通貨を消費する」性質上、建設に通貨を要求することで序盤の建設を抑制する設計。

---

## 4. EconBuilding.gd への追加内容

### 4.1 enum BuildingType への追加
既存：
```
enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE, EQUIPMENT_SHOP, TRADE_POST, WALL, PLAZA, HOUSE }
```

変更後：
```
enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE, EQUIPMENT_SHOP, TRADE_POST, WALL, PLAZA, HOUSE, EXCHANGE }
```

`EXCHANGE` を末尾に追加（インデックス 12）。既存 enum 値の順序を変えない（cards_econ.json などの既存データが破壊されないようにするため）。

### 4.2 BUILD_COSTS への追加
```gdscript
static var BUILD_COSTS: Dictionary = {
    ...既存のまま...
    11: {"wood": 3},               # HOUSE（§2.7.2）
    12: {"wood": 4, "stone": 2, "currency": 10},  # EXCHANGE（要件 §3.1）
}
```

> 注：既存の BUILD_COSTS には `currency` キーは未使用。EconBuilding 側のコスト確認・支払い処理で `currency` キーが扱われるか実装時に確認すること。扱われない場合は、currency コストはカード使用時に EconDeckManager または EconEconomy 経由で別処理する設計とする（**要確認**）。

### 4.3 BUILD_HP への追加
```gdscript
static var BUILD_HP: Dictionary = {
    ...既存のまま...
    11: 60.0,  # HOUSE
    12: 80.0,  # EXCHANGE（要件 §3.1）
}
```

### 4.4 REQUIRED_CONSTRUCTION への追加
```gdscript
static var REQUIRED_CONSTRUCTION: Dictionary = {
    ...既存のまま...
    11: 3.0,  # HOUSE
    12: 5.0,  # EXCHANGE（要件 §3.1）
}
```

### 4.5 定数定義（class フィールド領域）
既存の `BARRACKS_PRODUCE_INTERVAL` 等のパターンに倣う：
```gdscript
# 交換所：通貨消費による追加ドロー（要件 req_econ_exchange_building.md）
const EXCHANGE_DRAW_CT_LV1 := 30.0
const EXCHANGE_DRAW_CT_LV2 := 20.0
const EXCHANGE_DRAW_CT_LV3 := 10.0
const EXCHANGE_DRAW_COST_LV1 := 15
const EXCHANGE_DRAW_COST_LV2 := 10
const EXCHANGE_DRAW_COST_LV3 := 5
```

### 4.6 インスタンス変数の追加
既存の `_produce_timer: float = 0.0` 等に倣う：
```gdscript
var _exchange_cd_remaining: float = 0.0  # 交換所のドロー CT 残り
var exchange_level: int = 1               # Lv1〜Lv3（強化システム連動・MVPでは 1 固定）
```

> 注：建物 Lv 強化システムが MVP で未実装の場合、`exchange_level` は 1 固定で運用する（要件 §6 検証条件）。

### 4.7 _update_exchange 関数の追加（既存 `_update_barracks` パターンに倣う）

```gdscript
func _update_exchange(delta: float, economy: EconEconomy) -> void:
    # CT を進行
    if _exchange_cd_remaining > 0.0:
        _exchange_cd_remaining = maxf(0.0, _exchange_cd_remaining - delta)
    # CT 中はリソースレディフラグを CT 終了表示に切替（!マーク表示制御）
    var cost: int = _get_exchange_draw_cost()
    _resource_ready = (economy.currency >= cost) and (_exchange_cd_remaining <= 0.0)
    # CT が残っている、または通貨不足ならドローしない
    if _exchange_cd_remaining > 0.0:
        return
    # 通貨が cost に満たない場合はドローしない（蓄積待機）
    if economy.currency < cost:
        return
    # EconDeckManager 経由で追加ドロー実行（疎結合）
    var deck_manager: EconDeckManager = _get_deck_manager()
    if deck_manager == null:
        return
    var success: bool = deck_manager.request_extra_draw("currency")
    if success:
        _exchange_cd_remaining = _get_exchange_draw_ct()

func _get_exchange_draw_cost() -> int:
    match exchange_level:
        2: return EXCHANGE_DRAW_COST_LV2
        3: return EXCHANGE_DRAW_COST_LV3
        _: return EXCHANGE_DRAW_COST_LV1

func _get_exchange_draw_ct() -> float:
    match exchange_level:
        2: return EXCHANGE_DRAW_CT_LV2
        3: return EXCHANGE_DRAW_CT_LV3
        _: return EXCHANGE_DRAW_CT_LV1

func _get_deck_manager() -> EconDeckManager:
    # EconBattle 経由で取得（既存の疎結合ルール準拠）
    var node: Node = self
    while node != null:
        if node is EconBattle:
            return (node as EconBattle).deck_manager
        node = node.get_parent()
    return null
```

> **疎結合ルール（CLAUDE.md より）**：
> - 他クラスの内部配列・フィールドへの直接代入・append は禁止
> - 状態変更は必ず相手クラスのメソッド経由で行う
> 本要件では `deck_manager.request_extra_draw("currency")` を呼ぶのみで、deck/hand/discard_pile への直接操作は **行わない**。

### 4.8 update 関数の match 分岐追加
既存：
```gdscript
match building_type:
    BuildingType.BARRACKS:
        _update_barracks(delta, economy)
    ...
    BuildingType.TRADE_POST:
        pass
```

変更後：
```gdscript
match building_type:
    BuildingType.BARRACKS:
        _update_barracks(delta, economy)
    ...
    BuildingType.TRADE_POST:
        pass
    BuildingType.EXCHANGE:
        _update_exchange(delta, economy)
```

### 4.9 _draw 関数の着色追加
既存：
```gdscript
match building_type:
    ...
    BuildingType.HOUSE: color = Color.SANDY_BROWN
```

変更後：
```gdscript
match building_type:
    ...
    BuildingType.HOUSE: color = Color.SANDY_BROWN
    BuildingType.EXCHANGE: color = Color.GOLD  # 通貨建物・市場との差別化のため金色系
```

> 色は GOLD（金色）を提案。市場 TRADE_POST が紫（#7A4F8C）であるため、混同しない別系統の色を選択した。デザイナー判断で変更可。

---

## 5. EconDeckManager.gd との連携仕様

### 5.1 既存メソッドの活用（**改変なし**）
EconDeckManager.gd:172-190 に既に実装済みの `request_extra_draw(resource_key: String) -> bool` をそのまま使用する：

```gdscript
func request_extra_draw(resource_key: String) -> bool:
    if battle == null or battle.economy == null:
        return false
    if hand.size() >= HAND_MAX_SIZE:
        return false
    if not _ensure_deck_has_cards():
        return false
    if not _can_pay_draw_resource(resource_key):
        return false
    _pay_draw_resource(resource_key)
    var drawn_card: Dictionary = draw_card()
    if drawn_card.is_empty():
        _refund_draw_resource(resource_key)
        return false
    return true
```

### 5.2 呼び出し方
- 引数：`"currency"`（FALLBACK_DRAW_RESOURCE と一致）
- 戻り値：`bool`（true=ドロー成功・通貨消費済、false=失敗・通貨は消費されない）

### 5.3 通貨消費量の差異（重要）
EconDeckManager.EXTRA_DRAW_RESOURCE_COST は **15 で固定**。本要件 §3.2 では Lv2 以降で消費を 10/5 に下げる仕様としているが、**EXTRA_DRAW_RESOURCE_COST は変更しない**（カード固有の追加ドローと共有定数のため）。

#### 解決策（要 CEO 判断）
**案 A（推奨）：交換所 Lv1 のみ実装、Lv2/Lv3 はスコープ外**
- 交換所 Lv1 = 通貨15消費・CT30秒で `request_extra_draw("currency")` を呼ぶ
- Lv2/Lv3 のコスト削減・CT短縮は MVP スコープ外（建物 Lv 強化システム未実装のため）
- §3.2 の Lv2/Lv3 仕様は将来実装時の参考情報として記載のみ

**案 B：交換所側で通貨を直接操作**
- `request_extra_draw` を呼ばず、交換所側で `economy.currency -= cost` し、deck_manager.draw_card() を直接呼ぶ
- ただし疎結合ルール違反に近いため、EconDeckManager 側に Lv 引数付きの新メソッド `request_exchange_draw(currency_cost: int)` を追加する形式が望ましい
- ただし「EconDeckManager.gd は触らない」という本要件 §2.2 の制約と矛盾するため、CEO 判断が必要

**本要件のデフォルト推奨**：**案 A（Lv1 のみ実装、Lv2/Lv3 は将来）**

### 5.4 EconBattle との連携
EconBattle が `deck_manager` フィールドを公開している前提（既存実装）。`_get_deck_manager()` ヘルパーで取得する。

---

## 6. 検証条件

### 6.1 機能検証
- [ ] EXCHANGE 建物がカードから建設できる（建設キュー → 完成 → 稼働）
- [ ] 稼働後、通貨が15以上ある状態で CT0 のとき、自動的に `request_extra_draw("currency")` が呼ばれる
- [ ] 通貨が15未満のときは CT が残らず、通貨が貯まり次第ドローする
- [ ] ドロー成功時、通貨が15減少している
- [ ] ドロー失敗時（手札上限 / 山札+捨て札空）、通貨が消費されない
- [ ] CT 中は再ドローしない（CT0 まで待機）
- [ ] 必要稼働人口1が割り当てられていない場合は機能しない（既存の建物稼働判定と同じ）
- [ ] 建設中（is_built=false）は機能しない

### 6.2 構文検証
- [ ] `bash check_syntax.sh` がエラー0件で通過
- [ ] enum 値追加による既存実装の破壊なし（grep で BuildingType の利用箇所を確認）

### 6.3 疎結合検証
- [ ] EconBuilding.gd 内で `deck_manager.deck`, `deck_manager.hand`, `deck_manager.discard_pile` への直接アクセスなし
- [ ] EconBuilding.gd 内で `economy.currency` への直接代入なし（読み取りのみ。支払いは `request_extra_draw` 経由）

### 6.4 GAME_DESIGN 整合性検証
- [ ] §3.3 ドロー仕様（手札上限7・山札切れ時シャッフル）が `request_extra_draw` 経由で自動的に守られる
- [ ] §4.4 「アクティブ型・必要稼働人口1」が満たされている
- [ ] §6.4 REQUIREMENTS「交換所のリソース消費は通貨のみ」が守られている

---

## 7. MVP除外事項（実装しない）

### 7.1 政策・偉人カードの個別効果
- 交換所がドローしたカードが政策・偉人だった場合の挙動は EconDeckManager 既存実装に委ねる
- 政策/偉人カードの個別効果は GAME_DESIGN §12.6/§12.7 で「実装はフレームワークのみ」のため、本要件でも対応しない（REQUIREMENTS §6.5）

### 7.2 建物 Lv 強化（Lv2/Lv3）
- Lv2/Lv3 の効果・数値はすべて **未定（次期MVPで設計）**
- 本 MVP では `exchange_level = 1` 固定（§4.6 のインスタンス変数は将来拡張のための予約）

### 7.3 複数交換所の同時稼働制限
- 1都市内に複数の交換所を建てた場合、それぞれが独立に CT を持ちドローする
- 「同名建物制限」は GAME_DESIGN §3.8/§8.5 で「MVP では制限なし」のためそのまま踏襲

### 7.4 交換所による特定カードの優先ドロー
- 交換所はランダム1枚ドローのみ（既存 `draw_card()` の挙動）
- 「指定カードを引く」「特定種別のカードのみ引く」などのギミックは実装しない

### 7.5 ドロー失敗時の通知 UI
- ドロー失敗（手札上限・山札空）時の通知 UI は本要件のスコープ外
- 既存のリソース不足!マーク表示（_resource_ready=false）で代替

### 7.6 スタブ建物（次期MVP設計予定）
以下の建物は `EconBuilding.BuildingType` enum に予約エントリとして追加する。
効果・コスト・実装内容はすべて次期MVPで設計する。

| 建物名 | enum名 | 旧名称 | 備考 |
|--------|--------|--------|------|
| 書庫 | LIBRARY | 交換所の旧名称（≠現交換所） | 次期MVPで効果設計 |
| 図書館 | LIBRARY_ADV | — | 次期MVPで効果設計 |
| 博物館 | MUSEUM | — | 次期MVPで効果設計 |
| 美術館 | ART_GALLERY | — | 次期MVPで効果設計 |

**本MVPでの実装内容（最小限）：**
- `BuildingType` enum に4値を追加するのみ
- `update()` 内の `match` 分岐にスタブ（何もしない）を追加
- `BUILD_COSTS` / `BUILD_HP` / `REQUIRED_CONSTRUCTION` にはダミー値を設定

---

## 8. 実装上の注意

### 8.1 既存パターンとの整合
- `_update_barracks` `_update_fortress` `_update_workshop` のパターンに倣い、`_update_exchange` を追加
- `_resource_ready` フラグの使い方を踏襲（リソース不足/CT中は false にして!マーク表示）

### 8.2 cards_econ.json への追加
建物カードが cards_econ.json に定義されている場合、以下のエントリを追加する必要がある：
```json
{
    "id": "exchange",
    "name": "交換所",
    "type": "building",
    "building_type": 12,
    "cost": {"wood": 4, "stone": 2, "currency": 10}
}
```

> 既存の cards_econ.json 構造を確認の上、整合する形式で追加すること。本要件では構造詳細は規定しない（実装時に既存カードに倣う）。

### 8.3 通貨コスト処理の取り扱い
- 既存 BUILD_COSTS は wood/stone/sulfur のみ扱っている可能性がある
- `currency` キーが BUILD_COSTS で未対応の場合、建設時の通貨支払い処理を別途実装する必要がある
- **実装時に EconBattle / EconEconomy のコスト支払いロジックを確認し、必要なら currency キー対応を追加すること**（ただし対応範囲を最小化する）

### 8.4 用語統一（CLAUDE.md「用語統一ルール」）
- 設計文書：「交換所」（日本語）
- データ：`"exchange"` / `EXCHANGE`（英語コード）
- コード：`BuildingType.EXCHANGE`
- 旧 `TRADE_POST`（市場）と混同しないこと（市場＝通貨**生産**、交換所＝通貨**消費でドロー**）

---

## 9. 想定される質問・要確認事項（CEO 判断待ち）

| # | 確認事項 | 推奨案 |
|---:|---|---|
| Q1 | 建設コスト（木材4/石材2/通貨10）は妥当か？ | 案：そのまま採用。理由は §3.4 の比較表 |
| Q2 | 必要作業量 5.0 は妥当か？ | 案：そのまま採用（市場 TRADE_POST と同水準） |
| Q3 | Lv2/Lv3 を MVP で実装するか？ | **確定：実装しない**。効果・数値は未定、次期MVPで設計（2026-05-02） |
| Q4 | Lv 別の効果差分は「コスト削減のみ」か「CT短縮+コスト削減両方」か？ | 推奨：両方（成長感重視）。CEO が片方を望む場合は仕様変更可 |
| Q5 | 建物色は GOLD で良いか？ | デザイナー判断に委ねる |
| Q6 | currency キーが BUILD_COSTS で扱われない場合の処理 | 推奨：実装時に最小限の修正で対応（建設コストから通貨を別途引く処理を追加） |

---

## 10. 関連ドキュメント

- `docs/GAME_DESIGN_V0_2_MVP.md`（§3.3 ドロー仕様、§4.3 建物分類、§4.4 建物一覧、§4.8 建物強化）
- `docs/requirements/REQUIREMENTS_V0_2_MVP.md`（§2.4.1 5資源、§2.7 建物一覧、§6.4 交換所のリソース消費）
- `scripts/econ_mvp/EconBuilding.gd`（実装対象本体）
- `scripts/econ_mvp/EconDeckManager.gd`（連携先・改変なし）
- `data/cards_econ.json`（カード定義）

---

更新日: 2026-05-02
バージョン: v0.1（初版）
ステータス: DRAFT（CEO承認待ち）
