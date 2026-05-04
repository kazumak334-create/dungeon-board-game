STATUS: 廃止（→ docs/GAME_DESIGN_V0_2_MVP.md）
最終更新: 2026-05-04

# RestScreen実装 要件定義書

## 1. 概要
バトル間の休憩画面。デッキ編集・ショップ購入・ユニット復帰を1画面で実施。MVP範囲は合成・スキルツリーを除外。

## 2. ファイル分割戦略

### 2.1 現在の行数状況
- Main.gd: 935行
- BoardManager.gd: 515行

### 2.2 分割方針
**新規作成ファイル**:
- `scripts/RestScreenManager.gd`: RestScreen専用マネージャー（予測300行）
- `scripts/RestScreenShop.gd`: ショップ機能（予測150行）
- `scripts/RestScreenRevive.gd`: ユニット復帰機能（予測100行）

**変更ファイル**:
- `Main.gd`: シーン遷移のみ追加（+20行 → 955行）
- `BoardManager.gd`: Rest用マウス操作追加（+50行 → 565行）

### 2.3 分割根拠
- Main.gdは1000行超予測のため、RestScreen機能は別ファイル化
- BoardManager.gdはバトル用・Rest用で責務が分かれるため、Rest用のボード操作は最小限にとどめ、RestScreenManager側で制御

## 3. データ構造

### 3.1 RestScreenState
```gdscript
# RestScreenManager.gd内
enum RestMode {
    NONE,           # 未選択
    CARD_SELECTED,  # カード選択中
    SHOP_HOVER      # ショップ商品ホバー中
}

var rest_state: Dictionary = {
    "mode": RestMode.NONE,
    "selected_card": null,      # CardData or null
    "selected_index": -1,        # 手持ちカードのインデックス
    "shop_items": [],            # Array of CardData
    "gold": 0                    # プレイヤー所持金
}
```

### 3.2 ショップ商品データ
```gdscript
# RestScreenShop.gd内
var shop_data: Array = [
    {"card_id": "unit_001", "price": 50, "slot_index": 0},
    {"card_id": "unit_002", "price": 80, "slot_index": 1},
    # ... 最大9個
]
```

### 3.3 復帰対象データ
```gdscript
# RestScreenRevive.gd内
var revivable_units: Array = []  # {card_data: CardData, index: int, revive_cost: int}
```

## 4. クラス設計

### 4.1 RestScreenManager.gd（新規作成）

**責務**: RestScreen全体の制御・UI構築・状態管理

**主要フィールド**:
```gdscript
extends Node

var board_manager: BoardManager
var game_session: GameSession
var ui_root: Control           # RestScreen全体のルートContainer
var right_panel: Panel         # 右パネル
var hand_area: HBoxContainer   # 手持ちカードエリア
var shop: RestScreenShop
var revive: RestScreenRevive

var rest_state: Dictionary     # 上記3.1参照
```

**主要メソッド**:
```gdscript
func initialize(session: GameSession, board: BoardManager) -> void
func build_ui() -> void
func on_card_clicked(card_data: CardData, index: int) -> void
func on_shop_item_clicked(item_data: Dictionary) -> void
func on_revive_button_clicked(index: int) -> void
func on_next_button_clicked() -> void
func on_skip_button_clicked() -> void
func update_right_panel() -> void
func cleanup() -> void
```

### 4.2 RestScreenShop.gd（新規作成）

**責務**: ショップ商品の生成・表示・購入処理

**主要フィールド**:
```gdscript
extends Node

var shop_board: Control        # 敵陣盤面（3×3グリッド）
var shop_data: Array           # 商品データ
var game_session: GameSession
```

**主要メソッド**:
```gdscript
func initialize(session: GameSession, parent: Control) -> void
func generate_shop_items(level: int) -> Array
func display_items(items: Array) -> void
func on_item_clicked(item_data: Dictionary) -> void
func purchase_item(item_data: Dictionary) -> bool
```

### 4.3 RestScreenRevive.gd（新規作成）

**責務**: HP=0ユニットの復帰UI・処理

**主要フィールド**:
```gdscript
extends Node

var revivable_units: Array
var game_session: GameSession
```

**主要メソッド**:
```gdscript
func initialize(session: GameSession) -> void
func find_revivable_units() -> Array
func calculate_revive_cost(card_data: CardData) -> int
func revive_unit(index: int) -> bool
func create_revive_button(card_view: Control, cost: int) -> Button
```

## 5. UI構築手順

### 5.1 座標定義（企画書準拠）
```gdscript
const LAYOUT = {
    "header": {"x": 0, "y": 0, "w": 1280, "h": 36},
    "player_board": {"x": 20, "y": 52, "w": 390, "h": 315},
    "shop_board": {"x": 430, "y": 52, "w": 390, "h": 315},
    "center_gap": {"x": 410, "y": 52, "w": 20, "h": 315},
    "right_panel": {"x": 840, "y": 52, "w": 200, "h": 508},
    "hand_area": {"x": 20, "y": 390, "w": 800, "h": 150},
    "footer": {"x": 20, "y": 560, "w": 800, "h": 20}
}

const CELL = {"w": 130, "h": 95}
```

### 5.2 UI構築シーケンス
```gdscript
func build_ui() -> void:
    # 1. ルートContainer作成
    ui_root = Control.new()
    ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(ui_root)
    
    # 2. ヘッダーバー（CommonTaskbar使用）
    var header = CommonTaskbar.new()
    header.set_position(Vector2(LAYOUT.header.x, LAYOUT.header.y))
    header.set_size(Vector2(LAYOUT.header.w, LAYOUT.header.h))
    ui_root.add_child(header)
    
    # 3. 自陣盤面（既存BoardManager利用）
    board_manager.set_position(Vector2(LAYOUT.player_board.x, LAYOUT.player_board.y))
    ui_root.add_child(board_manager)
    
    # RestMode有効化・UI調整（RestScreen専用のBoardManager設定）
    board_manager.enable_rest_mode()
    board_manager.hide_enemy_side()  # 敵陣非表示（自陣のみ表示）
    board_manager.hide_battle_ui()   # HP・マナバー等のバトルUI非表示
    
    # 4. ショップ盤面
    shop.initialize(game_session, ui_root)
    var shop_board = shop.create_board(LAYOUT.shop_board)
    ui_root.add_child(shop_board)
    
    # 5. 右パネル
    right_panel = Panel.new()
    right_panel.set_position(Vector2(LAYOUT.right_panel.x, LAYOUT.right_panel.y))
    right_panel.set_size(Vector2(LAYOUT.right_panel.w, LAYOUT.right_panel.h))
    ui_root.add_child(right_panel)
    
    # 6. 手持ちカードエリア
    hand_area = HBoxContainer.new()
    hand_area.set_position(Vector2(LAYOUT.hand_area.x, LAYOUT.hand_area.y))
    hand_area.set_size(Vector2(LAYOUT.hand_area.w, LAYOUT.hand_area.h))
    ui_root.add_child(hand_area)
    
    # 7. フッター（次へ/スキップボタン）
    var footer = create_footer()
    ui_root.add_child(footer)
```

## 6. 実装詳細

### 6.1 デッキ編集（D&D）
**処理フロー**:
1. 手持ちカードエリアのカードをクリック
2. ドラッグ開始→BoardManager.on_drag_started()
3. 自陣3×3グリッドにドロップ→BoardManager.on_drop()
4. GameSession.deck配列を更新

**BoardManager.gd追加メソッド（RestScreen専用）**:
```gdscript
func enable_rest_mode() -> void:
    is_rest_mode = true
    # バトル用イベント無効化（Tick更新・攻撃・HP減少等）

func hide_enemy_side() -> void:
    # 敵陣（side=1）のセル表示・ユニット表示を非表示
    # RestScreenでは自陣のみ表示し、敵陣位置はショップに転用される

func hide_battle_ui() -> void:
    # HP表示・マナバー・攻撃エフェクト等のバトル用UIを非表示
    # RestScreenではデッキ編成判断に不要な情報を取り除く

func on_rest_drop(card_data: CardData, row: int, col: int) -> bool:
    # 配置可能チェック
    # GameSession.deck更新
    # CardView再描画
```

### 6.1.5 手持ちカード配置（クリック方式・DeckPrep流用）
**処理フロー**:
1. 手持ちカードエリアのカードをクリック→選択状態
2. 盤面セル（自陣3×3）をクリック→配置
3. 配置可能チェック（ユニットカードのみ）
4. GameSession.placement_config更新
5. 盤面再描画

**DeckPrepBoard.gd参照箇所**:
- `_selected_card_idx`: 選択中カードのインデックス
- `_on_chip_input()`: カードチップクリック処理
- `select_card()`: カード選択処理

**RestScreenManager.gd実装**:
```gdscript
var _selected_hand_index: int = -1

func on_hand_card_clicked(index: int) -> void:
    _selected_hand_index = index
    update_right_panel()

func on_board_cell_clicked(row: int, col: int) -> void:
    if _selected_hand_index < 0:
        return
    var card_data = GameSession.hand[_selected_hand_index]
    # 配置処理（BoardManager委譲）
    board_manager.on_rest_drop(card_data, row, col)
    GameSession.hand.remove_at(_selected_hand_index)
    _selected_hand_index = -1
    rebuild_hand_area()
```

### 6.2 ショップ購入
**処理フロー**:
1. RestScreenShop.generate_shop_items(level) → 9個の商品生成
2. 商品クリック→on_shop_item_clicked()
3. 所持金チェック→purchase_item()
4. GameSession.gold -= price, GameSession.hand.append(card_data)
5. hand_area再描画

**価格計算**:
```gdscript
func calculate_price(card_data: CardData) -> int:
    match card_data.tier:
        1: return 50
        2: return 80
        3: return 120
        _: return 50
```

### 6.3 ユニット復帰
**処理フロー**:
1. RestScreenRevive.find_revivable_units() → HP=0のカードを検索
2. 各カードに復帰ボタンを追加（cost表示）
3. ボタンクリック→revive_unit(index)
4. GameSession.gold -= cost, card_data.hp = card_data.max_hp
5. CardView更新

**復帰コスト計算**:
```gdscript
func calculate_revive_cost(card_data: CardData) -> int:
    return card_data.tier * 30  # Tier 1=30gold, Tier 2=60gold, Tier 3=90gold
```

### 6.4 右パネル表示
**状態別表示内容**:
```gdscript
func update_right_panel() -> void:
    right_panel.clear()
    
    match rest_state.mode:
        RestMode.NONE:
            var label = Label.new()
            label.text = "カードを選択してください"
            right_panel.add_child(label)
        
        RestMode.CARD_SELECTED:
            var card_detail = create_card_detail(rest_state.selected_card)
            right_panel.add_child(card_detail)
        
        RestMode.SHOP_HOVER:
            var shop_detail = create_shop_detail(rest_state.selected_card)
            right_panel.add_child(shop_detail)
```

### 6.5 次へ進む/スキップ
**処理フロー**:
```gdscript
func on_next_button_clicked() -> void:
    # 最低1枚配置チェック（0マス配置では進行不可）
    if not has_at_least_one_unit():
        show_error("最低1枚は配置してください")
        return
    
    cleanup()
    get_tree().change_scene_to_file("res://scenes/Battle.tscn")

func on_skip_button_clicked() -> void:
    # デッキ変更なしで次へ（next_button と同一バリデーション）
    if not has_at_least_one_unit():
        show_error("最低1枚は配置してください")
        return
    
    cleanup()
    get_tree().change_scene_to_file("res://scenes/Battle.tscn")
```

## 7. Main.gdとの連携

### 7.1 Main.gd追加内容（+20行）
```gdscript
func start_rest_screen() -> void:
    var rest_manager = preload("res://scripts/RestScreenManager.gd").new()
    rest_manager.initialize(game_session, board_manager)
    add_child(rest_manager)

func on_battle_end() -> void:
    # 既存のバトル終了処理
    # ...
    start_rest_screen()
```

## 8. 実装順序

### Phase 1: 基盤構築（Day 1）
1. RestScreenManager.gd作成
   - initialize(), build_ui(), cleanup()
2. UI構築確認（空のパネル表示）
3. Main.gdからの遷移確認

### Phase 2: デッキ編集（Day 2）
1. BoardManager.gd: enable_rest_mode(), on_rest_drop()
2. 手持ちカードエリア構築
3. D&D動作確認

### Phase 3: ショップ（Day 3）
1. RestScreenShop.gd作成
2. 商品生成・表示
3. 購入処理・所持金更新

### Phase 4: ユニット復帰（Day 4）
1. RestScreenRevive.gd作成
2. HP=0検索・復帰ボタン表示
3. 復帰処理・所持金更新

### Phase 5: 右パネル・遷移（Day 5）
1. 右パネル状態別表示
2. 次へ進む/スキップボタン
3. バリデーション・遷移確認

## 9. 制約・注意事項

### 9.1 既存コードとの整合性
- BoardManager.gdはバトル用イベントを無効化する必要あり（is_rest_modeフラグ）
- GameSession.deckとGameSession.handの整合性を保つ
- CommonTaskbarの所持金表示と同期

### 9.2 GAME_DESIGN.mdとの整合性
- ショップ商品数: 9個（3×3グリッド）
- 復帰コスト: Tier × 30gold
- デッキサイズ: 最大3×3（最低1枚配置必須、全マス埋めは任意）

### 9.3 MVP範囲外
- 合成機能（Phase 5以降）
- スキルツリー（Phase 5以降）
- アニメーション（Tween）は最小限

## 10. ファイルサイズ予測結果

| ファイル | 現在行数 | 追加行数 | 予測行数 | 判定 |
|---------|---------|---------|---------|------|
| Main.gd | 935 | +20 | 955 | ✅ 1000行未満 |
| BoardManager.gd | 515 | +50 | 565 | ✅ 800行未満 |
| RestScreenManager.gd | 0 | +300 | 300 | ✅ 新規 |
| RestScreenShop.gd | 0 | +150 | 150 | ✅ 新規 |
| RestScreenRevive.gd | 0 | +100 | 100 | ✅ 新規 |

**結論**: 全ファイル800行未満。分割設計により既存ファイルへの影響を最小化。

## 11. 完了定義
- [ ] 全クラスのメソッドシグネチャが定義済み
- [ ] UI座標が企画書と一致
- [ ] 実装順序が明確
- [ ] ファイルサイズ予測が800行未満
- [ ] CEO承認済み

## 12. 参照ファイル
- `C:\Users\kazum\dungeon-board-game\scripts\Main.gd`
- `C:\Users\kazum\dungeon-board-game\scripts\BoardManager.gd`
- `C:\Users\kazum\dungeon-board-game\scripts\GameSession.gd`
- `C:\Users\kazum\dungeon-board-game\scripts\CommonTaskbar.gd`
- `C:\Users\kazum\dungeon-board-game\docs\GAME_DESIGN.md`
- `C:\Users\kazum\dungeon-board-game\docs\design\rest_screen_ux_plan.md`
