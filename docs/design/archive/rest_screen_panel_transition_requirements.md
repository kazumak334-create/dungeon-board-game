STATUS: 廃止（→ docs/GAME_DESIGN_V0_2_MVP.md）
最終更新: 2026-05-04

# RestScreen Phase 5 右パネル・遷移統合 要件定義書

## 1. 概要
RestScreenのUI完成度を上げる最終Phase。右パネルの状態別情報表示、ホバー連携、「次へ進む／スキップ」ボタンによるWaveManagerへの復帰を実装する。MVP範囲では合成／スキルツリーは対象外（Phase 5以降）。

---

## 2. 実装対象

### 2.1 修正ファイル
- `C:\Users\kazum\dungeon-board-game\scripts\RestScreenManager.gd`
  - 現在230行 → 追加約+100行 → **約330行**（500行未満、分割不要）

### 2.2 変更箇所（既存関数）
| 関数 | 変更内容 |
|------|---------|
| `build_ui()` L53-104 | 右パネル初期構築を拡張（state連動のために子ノード構造化） |
| `create_card_view()` L175-202 | `mouse_entered` / `mouse_exited` シグナル接続を追加 |
| `on_next_button_clicked()` L125-127 | 空実装 → バリデーション＋WaveManager連携へ置換 |
| `on_skip_button_clicked()` L130-132 | 空実装 → WaveManager連携へ置換 |

### 2.3 追加関数（新規）
| 関数 | 役割 |
|------|------|
| `update_right_panel()` | rest_state.modeに応じて右パネル内容を切り替え |
| `_clear_right_panel_contents()` | 右パネルの子ノードをクリア |
| `_build_right_panel_empty()` | 未選択時のガイドテキスト構築 |
| `_build_right_panel_card_detail(card_data, is_shop)` | カード詳細構築（ステータス・効果・特性） |
| `_on_card_hover_enter(card_name, source)` | ホバー開始ハンドラ（source: "hand"/"board"/"shop"） |
| `_on_card_hover_exit()` | ホバー終了ハンドラ |
| `validate_deck() -> bool` | 盤面3×3配置バリデーション |
| `_show_validation_error(msg)` | エラーメッセージをフッターに表示 |
| `_transition_to_next_wave()` | WaveManager.resume_from_rest()呼び出し＋cleanup |

---

## 3. データ構造

### 3.1 rest_state拡張（既存Dictionaryに追記）
```gdscript
var rest_state: Dictionary = {
    "mode": RestMode.NONE,
    "selected_card": null,        # 既存
    "selected_index": -1,         # 既存
    "shop_items": [],             # 既存
    "gold": 0,                    # 既存
    "hover_source": "",           # 新規: "hand"/"board"/"shop"/""
    "hover_card_name": ""         # 新規: 現在ホバー中のカード名（空=未ホバー）
}
```

### 3.2 RestMode列挙型（既存、変更なし）
- `NONE`：未選択・未ホバー
- `CARD_SELECTED`：手持ち／盤面カード選択中
- `SHOP_HOVER`：ショップ商品ホバー中

### 3.3 バリデーション結果
```gdscript
# validate_deck() の返り値
# true  : initial_unitsが9マス全て埋まっている
# false : 未配置セルが存在
```

---

## 4. 実装詳細

### 4.1 右パネル表示ロジック

#### 座標定義（既存LAYOUT.right_panel準拠）
- パネル位置: X:840, Y:52, W:200, H:508
- 背景色: `UIColors.COLOR_SIDE_PANEL` = (0.1, 0.1, 0.15)
- ボーダー: `UIColors.COLOR_BORDER` = (0.3, 0.3, 0.4)

#### 状態A：RestMode.NONE（未選択時）
```
[右パネル中央]
  "カードを選択して" (Y:240, 色: COLOR_DIM)
  "詳細を表示"       (Y:260, 色: COLOR_DIM)
  font_size: 12
  水平中央揃え
```

#### 状態B：RestMode.CARD_SELECTED（手持ち／盤面選択時）
パネル内相対座標（基準：右パネル左上=X:840, Y:52）。
| 要素 | 相対X | 相対Y | サイズ | 内容 | 色 |
|------|------|------|--------|------|-----|
| カード名 | 10 | 10 | 180×22 | unit_name | COLOR_TITLE |
| レアリティ | 10 | 34 | 180×18 | "Common/Rare/Epic" | レアリティ色 |
| HPラベル | 10 | 60 | 180×16 | "HP: 100" | COLOR_TEXT |
| ATKラベル | 10 | 78 | 180×16 | "ATK: 20" | COLOR_TEXT |
| SPDラベル | 10 | 96 | 180×16 | "SPD: 1.2" | COLOR_TEXT |
| Manaラベル | 10 | 114 | 180×16 | "Mana: 3" | COLOR_TEXT |
| 種族ラベル | 10 | 140 | 180×18 | "スライム/獣/アンデッド" | 種族色 |
| 特性バッジ列 | 10 | 164 | 180×20 | traits[] をアイコン風Label列挙（文字のみ可） | COLOR_SUBTITLE |
| 効果テキスト | 10 | 190 | 180×80 | support_effectテキスト（word-wrap） | COLOR_SUBTITLE, font_size:11 |

#### 状態C：RestMode.SHOP_HOVER（ショップ商品ホバー時）
状態Bと同じ構成 + 価格表示を追加。
| 要素 | 相対Y | 内容 |
|------|------|------|
| 価格ラベル | 280 | "価格: 50G" (COLOR_SELECTED) |
| 購入可否 | 300 | "購入可能"/"資金不足" (COLOR_AFFORDABLE or COLOR_UNAFFORDABLE) |

#### 処理フロー
```
update_right_panel():
  1. _clear_right_panel_contents() で既存子ノード削除
  2. match rest_state.mode:
       NONE           → _build_right_panel_empty()
       CARD_SELECTED  → _build_right_panel_card_detail(selected_card, false)
       SHOP_HOVER     → _build_right_panel_card_detail(selected_card, true)
```

### 4.2 ホバーイベント連携

#### 発生元3種
| 発生元 | 関数 | source引数 |
|-------|------|----------|
| 手持ちカードエリア | `create_card_view()` 内のContainer | "hand" |
| 自陣盤面セル | BoardManager（Rest mode時） | "board" |
| ショップ商品セル | RestScreenShop.display_items() | "shop" |

#### シグナル接続（手持ちカード例）
```gdscript
# create_card_view() 末尾に追加
card_container.mouse_entered.connect(_on_card_hover_enter.bind(card_name, "hand"))
card_container.mouse_exited.connect(_on_card_hover_exit)
```

#### ハンドラ実装
```gdscript
func _on_card_hover_enter(card_name: String, source: String) -> void:
    var card_db = get_node_or_null("/root/CardDB")
    if not card_db or not card_db.UNITS.has(card_name):
        return
    rest_state.hover_source = source
    rest_state.hover_card_name = card_name
    rest_state.selected_card = card_db.UNITS[card_name]
    rest_state.mode = RestMode.SHOP_HOVER if source == "shop" else RestMode.CARD_SELECTED
    update_right_panel()

func _on_card_hover_exit() -> void:
    # 選択がない状態ならNONEへ戻す
    if rest_state.selected_index == -1:
        rest_state.mode = RestMode.NONE
        rest_state.selected_card = null
    rest_state.hover_source = ""
    rest_state.hover_card_name = ""
    update_right_panel()
```

#### 盤面・ショップ側連携（外部I/F）
- BoardManagerには Rest mode時に `cell_hovered(row, col, card_name)` シグナルを発行する既存機構を利用（既存なら接続、なければ本Phaseでは手持ち側のみ接続とし、盤面・ショップ連携はTODOコメントで明示）。
- RestScreenShopには既存 `item_hovered(card_id)` があれば接続。なければ `shop.on_item_clicked()` でCARD_SELECTED代替。

### 4.3 「次へ進む」ボタン

#### バリデーション仕様
```gdscript
func validate_deck() -> bool:
    # GameSession.initial_units が 9要素、全て non-null/non-empty か
    if game_session.initial_units.size() != 9:
        return false
    for slot in game_session.initial_units:
        if slot == null or (slot is Dictionary and slot.get("name", "") == ""):
            return false
    return true
```

#### 処理フロー
```gdscript
func on_next_button_clicked() -> void:
    if not validate_deck():
        _show_validation_error("盤面を3×3全て埋めてください")
        return
    _transition_to_next_wave()

func _transition_to_next_wave() -> void:
    # WaveManagerは Main.gd が保持している想定
    var main = get_tree().get_root().get_node_or_null("Main")
    if main and main.has_method("_on_rest_screen_closed"):
        main._on_rest_screen_closed()
    else:
        # フォールバック: GameSession.wave_rest_pending をクリア
        game_session.wave_rest_pending = false
    cleanup()
```

#### エラー表示
- フッターのステータスサマリー内に `Label` を追加し、`COLOR_UNAFFORDABLE` で3秒間表示（Timer使用）。
- Tweenは使わず、`await get_tree().create_timer(3.0).timeout` で消す。

### 4.4 「スキップ」ボタン

#### 仕様
- バリデーション省略
- 盤面が未完成でも強制遷移（プレイヤー責任）
- UX配慮：初回スキップ時に `print()` ログ出力のみ（確認ダイアログは不要＝rest_screen_ux_plan.md §5-6準拠）

```gdscript
func on_skip_button_clicked() -> void:
    print("[RestScreenManager] スキップ（バリデーション省略）")
    _transition_to_next_wave()
```

### 4.5 WaveManager連携方式

本Phaseで直接 `WaveManager.resume_from_rest()` を呼ばない。理由：

1. WaveManagerは `RefCounted` でMain.gd内の変数として保持される
2. RestScreenManagerは Main.gd が `add_child` で生成
3. 責務境界：Main.gd が「RestScreenの閉鎖 → WaveManager再開」を担う

→ RestScreenManagerは `Main.gd._on_rest_screen_closed()` を呼ぶのみ。
Main.gd側で次を実装する想定（本要件定義の範囲外だが依存としてTODO明記）：
```gdscript
# Main.gd（別タスクで追加）
func _on_rest_screen_closed() -> void:
    if wave_manager:
        wave_manager.resume_from_rest()
```

---

## 5. UIコンポーネント一覧

| コンポーネント | 型 | 役割 | 新規/既存 |
|--------------|---|------|---------|
| right_panel | Panel | 右パネルルート | 既存 |
| right_panel_content | VBoxContainer | 状態別コンテンツ入れ替え用 | 新規 |
| error_label | Label | バリデーションエラー表示 | 新規 |
| card_detail_name | Label | カード名表示 | 新規 |
| card_detail_stats | VBoxContainer | ステータス行群 | 新規 |
| card_detail_traits | HBoxContainer | 特性バッジ列 | 新規 |
| card_detail_effect | Label | 効果テキスト（autowrap） | 新規 |
| price_label | Label | ショップホバー時のみ | 新規 |

---

## 6. インタラクション仕様

| 操作 | 状態遷移 | 右パネル更新 |
|------|---------|------------|
| 手持ちカードhover_enter | NONE→CARD_SELECTED | カード詳細表示 |
| 手持ちカードhover_exit | CARD_SELECTED→NONE | ガイドテキスト |
| 盤面セルhover_enter | NONE→CARD_SELECTED | カード詳細表示 |
| ショップ商品hover_enter | NONE→SHOP_HOVER | 詳細+価格表示 |
| ショップ商品hover_exit | SHOP_HOVER→NONE | ガイドテキスト |
| 「次へ進む」クリック（deck valid） | - | cleanup→次Wave |
| 「次へ進む」クリック（deck invalid） | - | エラー3秒表示 |
| 「スキップ」クリック | - | cleanup→次Wave |

---

## 7. 制約・注意事項

### 7.1 既存コードとの整合性
- `RestScreenShop.gd` / `RestScreenRevive.gd` のシグナル（`purchase_completed` / `revive_completed`）は既に接続済み（L74, L80）。変更しない。
- `build_hand_area()` はカード再構築時に全`queue_free`→再生成しているため、hover接続も自動的に再生成される。
- `game_session.initial_units` がnullまたは未初期化の場合 `validate_deck()` はfalseを返す（防御的実装）。

### 7.2 GAME_DESIGN.mdとの整合性
- デッキサイズ3×3は `GAME_DESIGN.md` と一致（既存`rest_screen_requirements.md` §9.2参照）
- WaveManager復帰仕様は `WaveManager.resume_from_rest()` (L115-117) に準拠
- 「バリデーション省略」スキップはUX企画書 `rest_screen_ux_plan.md` §5-6に準拠

### 7.3 廃止済み設計との整合性
- **盤面召喚システム（廃止）**: 本実装は「初期配置式」に従う。RestScreenでの編集は`initial_units`配列の更新のみ。召喚UIは追加しない。
- **時間経過マナ回復（廃止）**: 「次へ進む」時に`wave_mana_carryover`には一切触れない（WaveManager側管理）。

### 7.4 MVP範囲外（本Phaseで実装しない）
- 合成機能（Phase 5以降）
- スキルツリー（Phase 5以降）
- フェードアニメーション（即時切替で十分、UX基準5項目合格済み）
- リロールボタン（RestScreenShop側の後フェーズ課題）
- 右パネル内の合成候補ボタン列（`rest_screen_ux_plan.md` §4-4 状態B Y:280）

### 7.5 3秒ルールチェック
- 状態別表示は3択のみ（未選択/選択/ショップ）→ 視聴者が3秒で把握可能 ✅
- エラー表示は赤色3秒表示 → 即座に伝わる ✅
- 「次へ進む」/「スキップ」の役割差は見出し色で区別（緑/灰） ✅

---

## 8. ファイルサイズ予測

| ファイル | 現在行数 | 追加行数 | 予測行数 | 判定 |
|---------|---------|---------|---------|------|
| RestScreenManager.gd | 230 | +100 | **330** | ✅ 500行未満 |

**分割判定**: 不要。単一ファイル内に収まる。
**根拠**: 右パネル構築ロジックは本Phaseのコア責務であり、別ファイル化すると責務分散になる。

---

## 9. 実装順序（推奨）

1. `update_right_panel()` + 3つの `_build_right_panel_*` を実装（UI表示のみ確認）
2. `_on_card_hover_enter` / `_on_card_hover_exit` を実装、`create_card_view()` に接続
3. `validate_deck()` + `_show_validation_error()` を実装
4. `on_next_button_clicked()` / `on_skip_button_clicked()` を完成形へ置換
5. `_transition_to_next_wave()` 実装、Main.gd側 `_on_rest_screen_closed()` を別タスクでTODO明記
6. 構文チェック: `bash check_syntax.sh`
7. Checkerへ引き継ぎ

---

## 10. 完了定義

- [ ] 右パネル3状態表示が仕様通り
- [ ] 手持ちカードホバーで詳細表示
- [ ] 盤面・ショップ連携は既存シグナルが無ければTODOで明示
- [ ] デッキ未完成時のエラー表示動作
- [ ] 「次へ進む」「スキップ」でRestScreen閉鎖
- [ ] ファイル行数330行以下
- [ ] `check_syntax.sh` 通過
- [ ] CEO承認

---

## 11. 参照ファイル（絶対パス）

- `C:\Users\kazum\dungeon-board-game\docs\design\rest_screen_requirements.md`
- `C:\Users\kazum\dungeon-board-game\docs\design\rest_screen_ux_plan.md`
- `C:\Users\kazum\dungeon-board-game\docs\GAME_DESIGN.md`
- `C:\Users\kazum\dungeon-board-game\scripts\RestScreenManager.gd`
- `C:\Users\kazum\dungeon-board-game\scripts\WaveManager.gd`
- `C:\Users\kazum\dungeon-board-game\scripts\GameSession.gd`
- `C:\Users\kazum\dungeon-board-game\scripts\CardDB.gd`
- `C:\Users\kazum\dungeon-board-game\scripts\Main.gd`
