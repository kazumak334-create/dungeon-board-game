STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# Sprint 7: 初期デッキ・土地カード 要件定義書（更新版 2026-05-03）

ステータス: 実装リソース（一時）
対応Sprint: Sprint 7
参照Final企画書: 初期デッキ・土地カードFinal企画書（SSoT）
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 7 セクション）
更新日: 2026-05-03

---

## 対応状況
- Final企画書準拠：✅

---

## ⚠️ 重大変更

| 項目 | 旧（参考設計） | 新（Final企画書） |
|---|---|---|
| 土地カード上書き | 既存パネルを resources/tag/terrain で上書き可能 | **既存土地パネルを上書きしない** |
| 土地カード配置ルール | 上書き対象は land_panels 全体 | **自建物隣接の空き土地のみ配置** |
| 土地カード報酬発生 | 単発・条件不明 | **毎戦闘後に土地カード3択を提示**（必須化） |
| 初期デッキ構成 | 6枚（森小屋1/採掘所1/農村2/食堂1/住宅1） | **11枚**（住宅×3, 農村×2, 森小屋×2, 採掘所×2, 食堂×1, 兵舎×1, 広場×1, 交換所×1） |
| 交換所の分類 | 通常建物 | **特殊建物に分類** |

---

## 実装対象

### 修正対象ファイル
- `data/cards_econ.json`
  - 既存カード定義のうち、初期デッキで使用されるものを確認
  - 交換所カードに `category: "special"` フィールドを追加（特殊建物分類）

- `scripts/econ_mvp/EconMain.gd` または `EconDeckManager.gd`
  - `INITIAL_DECK` 定数を 11枚構成に更新
  - 初期デッキ構築ロジック更新

- `scripts/econ_mvp/EconGrid.gd`
  - `get_adjacent_empty_land_cells_for_player() -> Array` 新規追加（自建物隣接の空き土地取得）
  - `place_land_card(card, target_pos)` 新規追加（**新規土地配置**、上書きではない）
  - 既存パネル上書きAPI（`overwrite_land_panel` 等）は **実装しない**

- 戦闘後の報酬フロー
  - 毎戦闘後に土地カード3択UIを表示
  - 既存報酬フローに統合（戦闘終了 → 報酬選択 → 次ターン）

---

## 実装詳細

### 1. 初期デッキ構成（合計11枚）

| カード | building_type | 枚数 | 役割 | 分類 |
|---|---|---:|---|---|
| 住宅 | HOUSE | 3 | 人口上限拡張 | 通常 |
| 農村 | VILLAGE | 2 | 食料生産 | 通常 |
| 森小屋 | SAWMILL | 2 | 木材獲得 | 通常 |
| 採掘所 | MINE | 2 | 石材獲得 | 通常 |
| 食堂 | DINER | 1 | 食料値生成 | 通常 |
| 兵舎 | BARRACKS | 1 | 兵力獲得 | 通常 |
| 広場 | PLAZA | 1 | 満足度供給 | 通常 |
| 交換所 | TRADE_POST | 1 | 資源交換 | **特殊建物** |
| **合計** | | **11** | | |

### 2. 既存カードIDマッピング（要確認）

| 役割 | 想定ID | 既存JSONとの照合 |
|---|---|---|
| 住宅 | `card_house` | 要確認・なければ追加 |
| 農村 | `card_village` | 既存 `card_village` を使用 |
| 森小屋 | `card_wood_extractor` | 既存 |
| 採掘所 | `card_stone_extractor` | 既存 |
| 食堂 | `card_diner` | Sprint 2 で追加済み |
| 兵舎 | `card_barracks` | 要確認 |
| 広場 | `card_plaza` | 要確認 |
| 交換所 | `card_trade_post` | 要確認・特殊建物として `category: "special"` 追加 |

### 3. 初期デッキ定義（コード側 SSoT）

```gdscript
# EconDeckManager.gd
const INITIAL_DECK: Array = [
    {"id": "card_house",          "count": 3},
    {"id": "card_village",        "count": 2},
    {"id": "card_wood_extractor", "count": 2},
    {"id": "card_stone_extractor","count": 2},
    {"id": "card_diner",          "count": 1},
    {"id": "card_barracks",       "count": 1},
    {"id": "card_plaza",          "count": 1},
    {"id": "card_trade_post",     "count": 1},
]
```

合計：3+2+2+2+1+1+1+1 = **11枚**

### 4. 交換所の特殊建物分類

`card_trade_post` の cards_econ.json に以下を追加：

```json
{
  "id": "card_trade_post",
  "name": "交換所",
  ...
  "category": "special",
  "draw_type": "BASIC"
}
```

通常建物カテゴリと区別することで、将来的に「特殊建物枠」の制限・配置ルールに対応可能にする。

### 5. 土地カードの配置ルール（重大変更）

#### 旧仕様（破棄）
- 既存土地パネルを上書きする方式は **採用しない**
- `place_land_card` で resources/special_tag/terrain_type/category を上書きする処理は **実装しない**

#### 新仕様（Final企画書）

```text
土地カードは「自建物隣接の空き土地のみ」に配置する。
既存の土地パネルを上書きしない。
新しい土地パネルを自建物隣接の空きマスに追加する。
```

ただし、Sprint 1 で 26×13 全マスを land_panels に登録済みである場合、「空き土地」の定義を明確化する：

- **空き土地**：建物が配置されていない `land_panels` 内のパネル
- **自建物隣接**：自軍の建物（自拠点含む）に隣接（マンハッタン距離=1）するマス

#### API 設計

```gdscript
func get_adjacent_empty_land_cells_for_player() -> Array:
    var result: Array = []
    var player_buildings_pos: Array = []
    # 自拠点を含む自軍建物の座標を収集
    for building in placed_buildings:
        if building.is_player and building.is_alive:
            player_buildings_pos.append(building.pos)
    player_buildings_pos.append(BASE_INITIAL_POS)
    
    for pos in land_panels.keys():
        if pos == BASE_INITIAL_POS:
            continue
        if _has_building_at(pos):
            continue
        # 隣接判定
        for bp in player_buildings_pos:
            if abs(pos.x - bp.x) + abs(pos.y - bp.y) == 1:
                result.append(pos)
                break
    return result

func place_land_card(card: Dictionary, target_pos: Vector2i) -> bool:
    # 隣接空きマス判定
    if target_pos not in get_adjacent_empty_land_cells_for_player():
        push_warning("[EconGrid] 土地カード配置不可：自建物隣接の空き土地ではない")
        return false
    
    # 新規土地パネル登録（既存は上書きしない）
    land_panels[target_pos] = card.get("panel_data", {}).duplicate(true)
    LogManager.log_event({
        "type": "LAND_CARD_PLACED",
        "pos": [target_pos.x, target_pos.y],
        "panel_data": card.get("panel_data", {}),
    })
    return true
```

### 6. 毎戦闘後の土地カード3択

#### タイミング

```text
戦闘終了 → ウェーブクリア確定 → 報酬フロー開始
  ├─ 既存：建物カード報酬（現状の流れ）
  └─ 新規：土地カード3択（毎戦闘後 必須）
```

#### 候補生成

`generate_land_card_candidates() -> Array` を新規実装。4タイプから3枚を選出（重複なし）。

| タイプ | 内容 |
|---|---|
| high_single | 高数値単一資源（資源値6など） |
| high_composite | 高総量複合資源（例：小麦3+綿花3） |
| spice_tag | 香辛料タグ付き |
| terrain | 地形（草原・砂漠・荒地・湿地） |

#### UI

- 3択を画面中央付近にカード形式で表示
- ユーザーが1枚選択
- 選択後、配置先（自建物隣接の空き土地）を選択するフェーズへ移行
- 配置先が0個の場合：カード自体は獲得（手札 or デッキ追加）し、後で配置可能とする（要件詳細はDesignerに委ねる）

### 7. 戦闘後フローの統合

```gdscript
# 既存の戦闘終了処理に追加
func _on_battle_end() -> void:
    # 既存：建物カード報酬
    show_building_card_reward()
    # 新規：土地カード3択
    show_land_card_reward()  # ← 必須実行
```

---

## 完了条件

- [ ] ゲーム開始時、初期デッキが 11枚 で構成される
- [ ] 初期デッキの内訳が `住宅×3 / 農村×2 / 森小屋×2 / 採掘所×2 / 食堂×1 / 兵舎×1 / 広場×1 / 交換所×1` になっている
- [ ] 交換所カードに `category: "special"` が設定されている
- [ ] `place_land_card(card, target_pos)` が **新規土地配置**を行う（既存上書きではない）
- [ ] 既存パネル上書きAPIは実装されていない（旧仕様の破棄を確認）
- [ ] `get_adjacent_empty_land_cells_for_player()` が自建物隣接の空き土地のみ返す
- [ ] 土地カードを自建物隣接以外に配置しようとすると失敗する
- [ ] 毎戦闘後に土地カード3択UIが表示される
- [ ] 3択は4タイプ（high_single/high_composite/spice_tag/terrain）から選出される
- [ ] 土地カード選択・配置のログが出力される
- [ ] check_syntax.sh エラー0件

---

## 確定仕様（Final企画書 SSoT）

| 仕様 | 値 |
|---|---|
| 初期デッキ枚数 | 11枚 |
| 初期デッキ構成 | 住宅×3, 農村×2, 森小屋×2, 採掘所×2, 食堂×1, 兵舎×1, 広場×1, 交換所×1 |
| 交換所の分類 | 特殊建物（category: "special"） |
| 土地カード配置 | 自建物隣接の空き土地のみ（新規追加） |
| 既存パネル上書き | 行わない |
| 土地カード3択 | 毎戦闘後に提示（必須） |
| 候補4タイプ | high_single / high_composite / spice_tag / terrain |

---

## 非対象（MVP対象外）

- 土地カード候補の確率調整（MVPは均等）
- 既存土地パネルの改造機能（旧仕様のため廃止）
- 土地カード未配置時の手札保持仕様の詳細（Designer委任）
- 土地カードの売却・破棄
- 土地カードによる地形効果の細部（Sprint 8 で UI 表示のみ）

---

## 関連する既存コード

- `data/cards_econ.json` （カード定義）
- `scripts/econ_mvp/EconDeckManager.gd` （デッキ管理）
- `scripts/econ_mvp/EconMain.gd` （ゲーム起動・初期化）
- `scripts/econ_mvp/EconGrid.gd` （土地パネル管理・上書き不可化）
- Sprint 2 で追加した `card_diner`, `card_mill`
