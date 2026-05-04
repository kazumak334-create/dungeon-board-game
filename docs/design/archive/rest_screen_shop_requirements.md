STATUS: 廃止（→ docs/GAME_DESIGN_V0_2_MVP.md）
最終更新: 2026-05-04

# RestScreenShop 要件定義書

## 1. 概要
RestScreen（休憩画面）のショップ機能。敵陣盤面（3x3グリッド）を商品表示に転用し、9個の商品を生成・表示し、クリック購入処理を行う。リロール・合成はMVP対象外。

## 2. 実装対象

### 2.1 新規ファイル
- ファイル名: `scripts/RestScreenShop.gd`
- 行数目標: 150行以内
- 責務: ショップ商品生成・表示・購入処理（UI構築はRestScreenManagerから委譲）

### 2.2 関連ファイル（変更なし・参照のみ）
- `scripts/RestScreenManager.gd`: ショップ初期化呼び出し側（既存）
- `scripts/GameSession.gd`: gold / selected_deck フィールド
- `scripts/CardDB.gd`: UNITS / SPELLS 辞書
- `scripts/ConfigLoader.gd`: rarity_price 取得（Shop.gd 既存定義と同一）

## 3. ファイルサイズチェック
- RestScreenManager.gd 現在185行 → 変更なし（+ 2行のみ：shop変数追加と初期化呼び出し）
- RestScreenShop.gd 新規150行目標
- 判定: 全ファイル800行未満維持

## 4. データ構造

### 4.1 商品データ（Array of Dictionary）
```gdscript
var shop_data: Array = []
# 各要素:
# {
#     "card_type": "unit" | "spell",   # 商品タイプ
#     "card_id": String,               # CardDBのキー（例: "slime_basic"）
#     "card_data": Dictionary,         # CardDB参照（表示用）
#     "price": int,                    # 価格（レアリティベース）
#     "slot_index": int,               # 0-8（3x3グリッド位置）
#     "sold_out": bool                 # 購入済みフラグ
# }
```

### 4.2 価格計算規則（Shop.gd 既存ロジックと一致）
```gdscript
# ConfigLoader経由で取得（shop.rarity_price）
# common: 50, uncommon: 100, rare: 200, epic: 400, legend: 800
```

## 5. クラス設計

### 5.1 主要フィールド
```gdscript
extends Node

const CELL_W: int = 130
const CELL_H: int = 95
const SHOP_BOARD_X: int = 430
const SHOP_BOARD_Y: int = 52
const GRID_COLS: int = 3
const GRID_ROWS: int = 3
const SHOP_ITEM_COUNT: int = 9

var ui_root: Control                 # 親ノード（RestScreenManager.ui_root）
var game_session: Node               # GameSession参照
var shop_data: Array = []            # 商品データ配列
var shop_panels: Array = []          # 商品UI Panel参照配列（更新用）
var shop_board_container: Control    # ショップ盤面のルートコンテナ
```

### 5.2 主要メソッド

#### initialize(session, parent) -> void
- game_session / ui_root を保存
- generate_shop_items() を呼び出し
- build_shop_board() でUI構築

#### generate_shop_items() -> void
- CardDB.UNITS と CardDB.SPELLS から全カードを候補リストに追加
- シャッフルして先頭9個を shop_data に格納
- 各商品に slot_index (0-8) / price / sold_out=false を設定
- 候補が9個未満の場合は可能な数のみ生成

#### build_shop_board() -> void
- Control ノードを座標(430, 52)、サイズ(390, 315)で作成
- 3x3グリッドに商品セルを配置
- セル座標計算: x = SHOP_BOARD_X + col * CELL_W, y = SHOP_BOARD_Y + row * CELL_H
- 各セルに create_item_panel(item, slot_index) を配置

#### create_item_panel(item: Dictionary, slot_index: int) -> Panel
- Panel ノード作成（130x95）
- カード名 Label（上部）
- ステータス Label（HP/ATK or 呪文説明）
- 価格 Label（下部 "50G"）
- 購入可否に応じた枠線色設定:
  - 購入可: Color(0.3, 0.5, 0.3) AFFORDABLE
  - 資金不足: Color(0.3, 0.2, 0.2) UNAFFORDABLE
  - 売却済: Color(0.5, 0.5, 0.5) DIM + modulate.a = 0.4
- gui_input シグナル接続 → on_item_clicked(slot_index)

#### on_item_clicked(slot_index: int) -> void
- shop_data[slot_index] 取得
- sold_out なら何もしない
- purchase_item(item) 呼び出し
- 成功時は refresh_item_panel(slot_index) で該当セル再描画

#### purchase_item(item: Dictionary) -> bool
- game_session.gold < item.price なら false を返す（購入失敗）
- game_session.gold -= item.price
- game_session.selected_deck.append(item.card_id)  # 手持ちに追加
- item.sold_out = true
- RestScreenManager に通知（rest_state.gold 更新・hand_area 再構築）
- true を返す

#### refresh_item_panel(slot_index: int) -> void
- shop_panels[slot_index] の枠線色・透明度を状態に応じて更新
- 売却済の場合は Panel 内を半透明化

#### cleanup() -> void
- shop_board_container.queue_free()
- shop_data / shop_panels クリア

## 6. RestScreenManagerとの連携

### 6.1 初期化フロー（RestScreenManager.build_ui() 内）
```gdscript
# build_ui() の「4. 右パネル」の前に追加:
shop = preload("res://scripts/RestScreenShop.gd").new()
add_child(shop)
shop.initialize(game_session, ui_root)
# 購入完了コールバック
shop.purchase_completed.connect(_on_shop_purchase_completed)
```

### 6.2 購入完了通知（シグナル）
```gdscript
# RestScreenShop.gd
signal purchase_completed(card_id: String, new_gold: int)

# RestScreenManager.gd
func _on_shop_purchase_completed(card_id: String, new_gold: int) -> void:
    rest_state.gold = new_gold
    # 手持ちカードエリア再構築
    for child in hand_area.get_children():
        child.queue_free()
    build_hand_area()
```

### 6.3 クリーンアップフロー
- RestScreenManager.cleanup() 内で shop.cleanup() を呼ぶ必要あり
- ui_root.queue_free() と shop のライフサイクル整合性を確保

## 7. 実装詳細

### 7.1 商品生成ロジック（ランダム抽選）
```gdscript
func generate_shop_items() -> void:
    shop_data.clear()
    var candidates: Array = []
    
    for uid in CardDB.UNITS.keys():
        var u = CardDB.UNITS[uid]
        candidates.append({
            "card_type": "unit",
            "card_id": uid,
            "card_data": u,
            "price": _get_price(u),
            "sold_out": false
        })
    for sid in CardDB.SPELLS.keys():
        var s = CardDB.SPELLS[sid]
        candidates.append({
            "card_type": "spell",
            "card_id": sid,
            "card_data": s,
            "price": _get_price(s),
            "sold_out": false
        })
    
    candidates.shuffle()
    var count = min(SHOP_ITEM_COUNT, candidates.size())
    for i in range(count):
        var item = candidates[i]
        item["slot_index"] = i
        shop_data.append(item)
```

### 7.2 セル配置座標計算
```gdscript
func _get_cell_position(slot_index: int) -> Vector2:
    var col = slot_index % GRID_COLS
    var row = slot_index / GRID_COLS
    var x = SHOP_BOARD_X + col * CELL_W
    var y = SHOP_BOARD_Y + row * CELL_H
    return Vector2(x, y)
```

### 7.3 購入可否判定による枠線色
```gdscript
func _get_border_color(item: Dictionary) -> Color:
    if item.sold_out:
        return Color(0.5, 0.5, 0.5)       # DIM
    if game_session.gold >= item.price:
        return Color(0.3, 0.5, 0.3)       # AFFORDABLE
    return Color(0.3, 0.2, 0.2)           # UNAFFORDABLE
```

### 7.4 価格取得
```gdscript
func _get_price(card_data: Dictionary) -> int:
    var rarity = card_data.get("rarity", "common")
    var rarity_price = ConfigLoader.get_value("shop", "rarity_price", {
        "common": 50, "uncommon": 100, "rare": 200, "epic": 400, "legend": 800
    })
    return rarity_price.get(rarity, 50)
```

## 8. UI要件（企画書準拠）

### 8.1 ショップ盤面配置
- 位置: (430, 52)
- サイズ: 390x315
- グリッド: 3列x3行、セル 130x95

### 8.2 商品セル内レイアウト（130x95）
| 要素 | 相対座標 | サイズ | 内容 |
|------|---------|--------|------|
| カード名 Label | (5, 4) | 120x16 | card_data.display |
| ステータス Label | (5, 24) | 120x30 | "HP:X ATK:Y" (unit) or effect 概要 (spell) |
| タイプ Label | (5, 58) | 60x14 | "ユニット" / "呪文" |
| 価格 Label | (70, 75) | 55x16 | "50G" (右寄せ、金色) |

### 8.3 インタラクション
- ホバー: 枠線が明るくなる（+0.1 明度）
- クリック（購入可）: 即購入・確認ダイアログなし
- クリック（購入不可）: 何も起きない（視覚的に分かるため）
- クリック（売却済）: 何も起きない

## 9. 制約・注意事項

### 9.1 既存コードとの整合性
- Shop.gd の価格計算ロジック（rarity_price）と一致させる
- GameSession.selected_deck に追加 → RestScreenManager.build_hand_area() 再実行で手持ち表示更新
- GameSession.gold は int 型、減算のみ（負数チェックは purchase_item 内）
- ConfigLoader のキー構造は既存 Shop.gd と同じ（"shop" > "rarity_price"）

### 9.2 GAME_DESIGN.mdとの整合性
- ショップ商品数: 9個（3x3グリッド、敵陣盤面転用）
- 購入確認ダイアログなし（企画書「1クリック購入」準拠）
- リロール機能はMVP範囲外（企画書 8章 MVP実装範囲参照）
- 合成機能はMVP範囲外

### 9.3 MVP範囲外（後フェーズ）
- リロールボタン（5G / 50G）
- ショップ詳細の右パネル連動表示（ホバー時の詳細情報）
- 購入アニメーション

### 9.4 ファイルサイズ維持
- RestScreenShop.gd 150行目標（上限200行）
- UIコンポーネント作成ヘルパーが肥大化する場合、_create_label / _create_panel_style を private static で定義
- 超過予測時は Helper 関数を `UIFactory.gd` に移植

## 10. 完了定義
- [ ] RestScreenShop.gd が150行以内で作成される
- [ ] 9個の商品が3x3グリッドで表示される
- [ ] 購入可否が枠線色で視覚的に区別される
- [ ] クリックで GameSession.gold が減算・selected_deck に追加される
- [ ] 購入後に該当セルが売却済表示になる
- [ ] RestScreenManager から signal 経由で手持ちエリアが更新される
- [ ] check_syntax.sh が通る
- [ ] CEO承認済み

## 11. 参照ファイル
- `scripts/RestScreenManager.gd`（連携先）
- `scripts/Shop.gd`（価格計算・商品生成ロジック参考）
- `scripts/GameSession.gd`（gold / selected_deck）
- `scripts/CardDB.gd`（UNITS / SPELLS）
- `scripts/ConfigLoader.gd`（価格取得）
- `docs/design/rest_screen_requirements.md`（全体要件）
- `docs/design/rest_screen_ux_plan.md`（UI/UX企画書）
- `docs/GAME_DESIGN.md`
