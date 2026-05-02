# Sprint 7: 初期デッキ再設計

ステータス: 実装リソース（一時）
対応Sprint: Sprint 7
参照設計書:
- docs/econ/population_satisfaction_food_system_design.md §11
- docs/econ/sprint_plan_population_satisfaction_food.md §11
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 7 セクション）
更新日: 2026-05-03

---

## 目的

「小麦 → 食料値 → 人口」の導線を初期デッキから成立させる。

具体的には：
- 初期デッキに食堂（DINER）を追加し、序盤から食料値生成が可能にする
- 序盤カードプールに製粉所（MILL）を追加し、報酬で小麦ブーストを得られるようにする

---

## 実装対象クラス・関数

### 修正対象ファイル
- `data/cards_econ.json`
  - `card_diner` を初期デッキ用としてマーク（Sprint 2 で追加済み）
  - `card_mill` を序盤カードプール用としてマーク（Sprint 2 で追加済み）
  - 初期デッキ／プール区分のためのフィールド追加（後述）

- `scripts/econ_mvp/EconMain.gd` または `EconDeckManager.gd`
  - 初期デッキ構築ロジック（`_build_initial_deck()` 等）の修正
  - 序盤カードプール定義の修正

---

## 仕様

### 1. 初期デッキ構成（合計6枚）

設計書 §11 に従う：

| カード | building_type | 枚数 | 役割 |
|---|---|---:|---|
| 森小屋 | SAWMILL | 1 | 木 / 樹脂の獲得 |
| 採掘所 | MINE | 1 | 石 / 鉄鉱石の獲得 |
| 農村 | VILLAGE | 2 | 小麦 / 綿花の獲得 |
| 食堂 | DINER | 1 | 小麦を食料値に変換 |
| 住宅 | HOUSE | 1 | 人口上限の増加 |

注：
- 森小屋＝SAWMILL、採掘所＝MINE、農村＝VILLAGE は既存のbuilding_typeを流用
- 樹脂・鉄鉱石・綿花の生産は MVP範囲では未実装でも可（panel_resource_system_design.md 範疇）
- カード名は日本語の最終呼称に合わせる（既存JSONでは「製材所」「採石場」「農場」になっている → 「森小屋」「採掘所」「農村」へリネーム検討、もしくは既存呼称を維持して内部building_typeのみ流用）

#### 既存カードIDマッピング

| 役割 | 既存ID | 既存name | 採用 |
|---|---|---|---|
| 森小屋 | `card_wood_extractor` | 製材所 | そのまま使用（呼称は維持） |
| 採掘所 | `card_stone_extractor` | 採石場 | そのまま使用 |
| 農村 | `card_village` | 農場 | そのまま使用（×2枚） |
| 食堂 | `card_diner` | 食堂 | Sprint 2 で新規追加 |
| 住宅 | `card_house` | 住居 | そのまま使用（×1枚） |

呼称統一は本Sprint対象外（別タスクで実施可）。

### 2. 初期デッキ識別の方法

cards_econ.json に `initial_deck_count: int` フィールドを追加する案：

```json
{
  "id": "card_village",
  "name": "農場",
  ...
  "initial_deck_count": 2,
  "starter_pool": false
}
```

または、初期デッキはコード側で配列定義（推奨）：

```gdscript
# EconMain.gd or EconDeckManager.gd
const INITIAL_DECK: Array[Dictionary] = [
    {"id": "card_wood_extractor", "count": 1},
    {"id": "card_stone_extractor", "count": 1},
    {"id": "card_village", "count": 2},
    {"id": "card_diner", "count": 1},
    {"id": "card_house", "count": 1},
]
```

→ コード側定義のほうが見通しが良いため、本Sprintでは **コード側で INITIAL_DECK 配列定義** を採用する。

### 3. 序盤カードプール構成

| カード | building_type | 役割 |
|---|---|---|
| 製粉所 | MILL | 小麦ブースト（差し引き+1〜+2） |
| 兵舎 | BARRACKS | 兵力生成 |
| 市場 | TRADE_POST | 通貨生産 |
| 広場 | PLAZA | 幸福度供給 |
| その他既存BASIC建物 | - | （既存運用通り） |

#### 序盤カードプール識別

cards_econ.json の `draw_type: "BASIC"` を「序盤カードプール」とみなす。製粉所もこの分類で追加する（Sprint 2 で `draw_type: "BASIC"` で追加済み）。

```json
{
  "id": "card_mill",
  "name": "製粉所",
  "draw_type": "BASIC",  // 序盤プールに含まれる
  ...
}
```

### 4. 初期デッキのロード処理

`EconDeckManager` または `EconMain` の初期デッキ構築箇所を以下のように修正：

```gdscript
const INITIAL_DECK: Array = [
    {"id": "card_wood_extractor", "count": 1},
    {"id": "card_stone_extractor", "count": 1},
    {"id": "card_village", "count": 2},
    {"id": "card_diner", "count": 1},
    {"id": "card_house", "count": 1},
]

func _build_initial_deck(all_cards: Dictionary) -> Array:
    var deck: Array = []
    for entry in INITIAL_DECK:
        var card_id: String = entry["id"]
        var count: int = entry["count"]
        var card: Dictionary = all_cards.get(card_id, {})
        if card.is_empty():
            push_warning("[EconDeckManager] 初期デッキカード未定義: %s" % card_id)
            continue
        for _i in range(count):
            deck.append(card.duplicate(true))
    print("[EconDeckManager] 初期デッキ構築: %d枚" % deck.size())
    return deck
```

注：既存の初期デッキ構築箇所を grep で特定し、置換する。

### 5. 既存初期デッキとの差分

- 既存初期デッキ（要確認）：実装次第
- 変更点：
  - 食堂（DINER）を追加
  - 製粉所は初期デッキに入れない（序盤プール限定）
  - 構成枚数は合計6枚

---

## 実装手順

1. `EconMain.gd` または `EconDeckManager.gd` の現状の初期デッキ構築箇所を特定
   ```bash
   grep -rn "INITIAL_DECK\|_build_initial_deck\|initial_deck" scripts/econ_mvp/
   ```
2. `INITIAL_DECK` 配列定数を追加（上記仕様通り）
3. `_build_initial_deck` 関数を実装または既存関数を置換
4. cards_econ.json の `card_diner` / `card_mill` が Sprint 2 で正しく追加されていることを確認
5. ゲーム起動時に初期デッキが6枚（食堂含む）になることを print で確認
   ```
   print("[EconDeckManager] 初期デッキ: card_wood_extractor x1, card_stone_extractor x1, card_village x2, card_diner x1, card_house x1 = 6枚")
   ```
6. 序盤プールから製粉所がドローされうることを確認（draw_type=BASIC のドロー対象になっているか）
7. `bash check_syntax.sh` 実行

---

## 完了条件

- [ ] ゲーム開始時、初期デッキが上記6枚で構成される
- [ ] 初期デッキに食堂が1枚含まれている
- [ ] 初期デッキに製粉所が含まれていない
- [ ] 序盤カードプール（draw_type: BASIC）に製粉所が含まれている
- [ ] 初期デッキで小麦獲得が可能（農村×2）
- [ ] 初期デッキで食料値獲得が可能（食堂）
- [ ] 初期デッキで人口維持導線が成立（小麦→食料値→人口維持）
- [ ] 初期デッキで人口上限拡張が可能（住居）
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- 既存の初期デッキ構築ロジックを完全置換する。並存させない
- カード名（製材所／採石場／農場）の呼称統一は本Sprint対象外
- 樹脂・鉄鉱石・綿花の生産はMVP範囲外。森小屋・採掘所・農村は既存の単一資源生産のままでよい
- 製粉所はSprint 2でcards_econ.jsonに追加済み。本Sprintでは「初期デッキに入れない」ことを明確化するのみ
- INITIAL_DECK は定数化することで、後の調整・テストが容易になる

---

## 関連する既存コード

- `data/cards_econ.json` （カード定義）
- `scripts/econ_mvp/EconDeckManager.gd` （デッキ管理）
- `scripts/econ_mvp/EconMain.gd` （ゲーム起動・初期化）
- Sprint 2 で追加した `card_diner`, `card_mill`
