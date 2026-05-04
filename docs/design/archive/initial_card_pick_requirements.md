STATUS: 廃止（→ docs/GAME_DESIGN_V0_2_MVP.md）
最終更新: 2026-05-04

# InitialCardPick（初期カード選択）要件定義書

## 1. 概要

ラン開始時に「3枚から1枚選ぶ」を6回繰り返して初期デッキ6枚を構築する画面。クラス選択後、マップ画面遷移前に挟まる。

## 2. 実装対象ファイル一覧

| ファイル | 操作 | 現在行数 | 追加後予測行数 |
|---------|------|---------|-------------|
| `scripts/InitialCardPick.gd` | 新規作成 | 0 | 約350行 |
| `scenes/InitialCardPick.tscn` | 新規作成 | 0 | 約15行 |
| `scripts/ui/UIColors.gd` | 新規作成 | 0 | 約25行 |
| `scripts/SceneManager.gd` | 変更（2箇所） | 57行 | 59行 |
| `scripts/CommonTaskbar.gd` | 変更（1箇所） | 既存 | +5行 |
| `scenes/MaterialSelect.tscn` | 変更なし（残置） | 13行 | - |

**ファイルサイズ判定**: InitialCardPick.gdは350行予測で500行以下。分割不要。

### MaterialSelect.tscn/gdの扱い

MaterialSelect.gdは既に削除済み。MaterialSelect.tscnはControlノード+スクリプト参照のみの空シェル（13行）。SceneManager.gdがパスを参照しているため、以下の方針とする。

- MaterialSelect.tscnは残置（既存テスト参照あり）
- InitialCardPick.tscn/gdを完全新規作成
- SceneManagerの`material_select`パスをInitialCardPickに差し替え

## 3. UIColors.gd（色定数共通化）

DeckPrep.gd、DeckPrepBoard.gd、Shop.gd等で色定数が重複定義されている。新規ファイル`scripts/ui/UIColors.gd`を作成し、InitialCardPick.gdはこれを参照する。既存ファイルの色定数置き換えは本タスクのスコープ外。

```gdscript
# scripts/ui/UIColors.gd
class_name UIColors
extends RefCounted

const BG          := Color(0.08, 0.08, 0.12)
const PANEL       := Color(0.13, 0.13, 0.2)
const BORDER      := Color(0.3, 0.3, 0.4)
const TITLE       := Color(0.9, 0.85, 0.6)
const TEXT        := Color(0.8, 0.8, 0.8)
const SELECTED    := Color(0.9, 0.75, 0.3)
const DIM         := Color(0.5, 0.5, 0.5)
const PICKED      := Color(0.4, 0.6, 0.4)
const GLOW        := Color(0.9, 0.75, 0.3, 0.3)
```

## 4. 状態管理の設計

### 状態変数

```gdscript
var _current_pick: int = 0        # 現在のピック番号（0-5）
var _selected_idx: int = -1       # 仮選択中のカードインデックス（0-2, -1=未選択）
var _picked_cards: Array = []     # 確定済みカード名リスト（最大6要素）
var _choice_pool: Array = []      # 現在の3択カード名リスト（3要素）
var _is_animating: bool = false   # アニメーション中フラグ（入力ブロック用）
```

### 状態遷移図

```
[IDLE] -- マウスenter --> [HOVER]（scale 1.05）
[IDLE] -- クリック --> [PRE_SELECTED]（仮選択: 枠点灯+他暗転）
[PRE_SELECTED] -- 同じカード再クリック --> [CONFIRMING]（アニメーション中）
[PRE_SELECTED] -- 別カードクリック --> [PRE_SELECTED]（仮選択切替）
[CONFIRMING] -- アニメ完了 --> [IDLE]（次の3択表示 or 全完了）
```

### 入力ブロック

`_is_animating == true` の間は全クリック・ホバーイベントを無視する。

## 5. カードプール生成ロジック

### 前提

- `GameSession.class_id` がタイトル/クラス選択画面で設定済み
- `CardDB.CLASSES[class_id].initial_deck` にクラス固有の初期デッキ（9枚: ユニット6+呪文3）が定義済み

### 生成手順

1. `CardDB.CLASSES[GameSession.class_id]` から `initial_deck` を取得
2. initial_deckからユニットのみ抽出: `CardDB.UNITS.has(name)` でフィルタ
3. 同名カードをまとめてユニークリスト化し、各カードに「必要枚数」を記録
   - 例: `["スライム", "スライム", "スライム", "マッドスライム", "マッドスライム", "ブラッドスライム"]`
   - → `{スライム: 3, マッドスライム: 2, ブラッドスライム: 1}`
4. 同じ種族（race）のカードをCardDB.UNITSから追加候補として取得（rarity=commonまたはuncommon限定）
5. 各ピックで3択を生成:
   - **必ず1枚**: initial_deckからまだピック済みでないカード（必要枚数が残っているもの）をランダム選出
   - **残り2枚**: 同種族のカードプール（initial_deck含む）からランダム選出（重複なし）
6. これにより「クラス固有カードを拾いやすいが、別のカードも選べる」選択体験を実現

### 呪文の扱い

initial_deckの呪文3枚はピック対象外。6ピック完了後に自動でGameSession.selected_deckに追加する。

## 6. 実装詳細

### 6-1. InitialCardPick.tscn

Controlノード1つ + スクリプト参照のみ（MaterialSelect.tscnと同構造）。

```
[node name="InitialCardPick" type="Control"]
anchors_preset = 15（FULL_RECT）
script = "res://scripts/InitialCardPick.gd"
```

### 6-2. InitialCardPick.gd 構造

```gdscript
extends Control

const UIF = preload("res://scripts/UIFactory.gd")
const TaskbarClass = preload("res://scripts/CommonTaskbar.gd")
const CardViewScene = preload("res://scenes/ui/CardView.tscn")

# 状態変数（セクション4参照）

# UI参照
var _taskbar: RefCounted = null
var _pick_dots: Array = []         # ColorRect x6（進捗ドット）
var _pick_label: Label = null      # "PICK N / 6"
var _card_views: Array = []        # CardView x3
var _select_borders: Array = []    # ColorRect x3（選択枠）
var _picked_slots: Array = []      # Control x6（下部ミニカード枠）
var _picked_mini_cards: Array = [] # CardView x6（ミニカード、nullで初期化）
var _confirm_button: Button = null
```

### 6-3. 主要関数シグネチャ

| 関数名 | 引数 | 戻り値 | 説明 |
|--------|------|--------|------|
| `_ready()` | なし | void | UI構築、1回目の3択表示 |
| `_build_ui()` | なし | void | 全UIコンポーネント生成 |
| `_build_progress_bar()` | なし | void | 進捗ドット6個 + ラベル生成 |
| `_build_card_choices()` | なし | void | CardView x3 + 選択枠x3 生成 |
| `_build_picked_area()` | なし | void | 下部ミニカード枠6個 生成 |
| `_build_confirm_button()` | なし | void | 確定ボタン生成（非表示） |
| `_generate_choices()` | なし | Array[String] | セクション5ロジックで3枚選出 |
| `_show_choices(cards: Array)` | cards: Array[String] | void | 3枚をCardViewにバインド+フェードインTween |
| `_bind_card(view: CardView, card_name: String)` | view, card_name | void | CardDB→CardViewプロパティ設定 |
| `_on_card_hover(idx: int)` | idx: 0-2 | void | ホバーTween（scale 1.05） |
| `_on_card_unhover(idx: int)` | idx: 0-2 | void | アンホバーTween（scale 1.0） |
| `_on_card_clicked(idx: int)` | idx: 0-2 | void | 仮選択 or 確定判定 |
| `_select_card(idx: int)` | idx: 0-2 | void | 仮選択状態適用（枠点灯+他暗転） |
| `_confirm_card(idx: int)` | idx: 0-2 | void | 確定→PickedSlot移動Tween→次の3択 |
| `_update_progress()` | なし | void | ドット色更新 + ラベルテキスト更新 |
| `_add_to_picked_slot(card_name: String)` | card_name | void | ミニカード生成して下部スロットに配置 |
| `_on_confirm_pressed()` | なし | void | GameSession保存→マップ画面遷移 |

### 6-4. CardViewへのデータバインディング

CardView.gdはexportプロパティ（mana, card_name, hp, atk, spd, frame_texture, art_texture）で表示を制御する。setterが定義済みなので、インスタンス化後にプロパティ代入するだけで表示が更新される。

```gdscript
func _bind_card(view: CardView, card_name: String) -> void:
    var data = CardDB.UNITS.get(card_name, {})
    view.card_name = card_name
    view.mana = data.get("cost", 0)
    view.hp = data.get("hp", 0)
    view.atk = data.get("atk", 0)
    view.spd = int(data.get("interval", 1.0))  # intervalをSPD表示に変換
    view.card_kind = CardView.CardKind.UNIT
    # テクスチャ: assets/cards/units/{snake_case}.png があれば設定
    var tex_path = "res://assets/cards/units/%s.png" % card_name
    if ResourceLoader.exists(tex_path):
        view.art_texture = load(tex_path)
```

**注意点**: card_view.gdの`_update_text()`がEffectLabelを参照しているが、CardView.tscnにEffectLabelノードが存在しない。実行時エラーにはならない（`has_node`チェックで早期returnするため）が、effect_textは表示されない。本タスクでは対応不要（CardView改修は別タスク）。

### 6-5. 座標・サイズ一覧（企画書準拠）

| 要素 | X | Y | W | H |
|------|---|---|---|---|
| ヘッダーバー | 0 | 0 | 1280 | 36 |
| 進捗ドット群（中央寄せ） | 計算値 | 50 | 12x12/個, 間隔20px | - |
| PickLabel | ドット右+30px | 45 | auto | 30 |
| CardChoice1 | 155 | 130 | 220 | 320 |
| CardChoice2 | 530 | 130 | 220 | 320 |
| CardChoice3 | 905 | 130 | 220 | 320 |
| SelectBorder1 | 152 | 127 | 226 | 326 |
| SelectBorder2 | 527 | 127 | 226 | 326 |
| SelectBorder3 | 902 | 127 | 226 | 326 |
| PickedSlot[n] | 410+n*80 | 510 | 60 | 86 |
| PickedLabel | 中央 | 490 | auto | - |
| ConfirmButton | 540 | 635 | 200 | 40 |

### 6-6. アニメーション仕様（Tween使用）

全てノードの`create_tween()`で実装。

| アニメーション | プロパティ | From | To | Duration | Easing |
|-------------|----------|------|-----|----------|--------|
| カード出現 | modulate:a | 0.0 | 1.0 | 0.3s | EASE_OUT |
| カード出現 | position:y | +30 | 元位置 | 0.3s | EASE_OUT |
| ホバー拡大 | scale | (1,1) | (1.05,1.05) | 0.15s | EASE_OUT |
| ホバー縮小 | scale | (1.05,1.05) | (1,1) | 0.15s | EASE_IN |
| 他カード暗転 | modulate:a | 1.0 | 0.4 | 0.2s | LINEAR |
| PickedSlot移動 | position | カード位置 | スロット位置 | 0.4s | EASE_IN_OUT |
| PickedSlot移動 | scale | (1,1) | (0.27,0.27) | 0.4s | EASE_IN_OUT |
| ConfirmButton出現 | modulate:a | 0.0 | 1.0 | 0.3s | EASE_OUT |
| 進捗ドット点灯 | color | DIM | PICKED | 0.2s | LINEAR |

### 6-7. ダブルクリック方式の実装

```
_on_card_clicked(idx):
    if _is_animating: return
    if _selected_idx == idx:
        # 2回目クリック → 確定
        _confirm_card(idx)
    else:
        # 1回目 or 別カード → 仮選択
        _select_card(idx)
```

`_select_card(idx)`:
1. `_selected_idx = idx`
2. 選択カードのSelectBorderをCOLOR_SELECTED（3px幅）に設定
3. 他2枚のSelectBorderを非表示 + modulate.a = 0.4にTween
4. 選択カードのmodulate.a = 1.0に復帰（別カードから切替時）

`_confirm_card(idx)`:
1. `_is_animating = true`
2. 選択カードをPickedSlotの位置へTween移動+縮小
3. `_picked_cards.append(_choice_pool[idx])`
4. `_current_pick += 1`
5. `_update_progress()`
6. Tween完了コールバック:
   - `_selected_idx = -1`
   - `_is_animating = false`
   - `_current_pick < 6` → `_show_choices(_generate_choices())`
   - `_current_pick == 6` → ConfirmButton表示Tween

## 7. GameSessionへの保存方法

`_on_confirm_pressed()`で実行:

```gdscript
func _on_confirm_pressed() -> void:
    # ユニット6枚
    var deck: Array = []
    for card_name in _picked_cards:
        var data = CardDB.UNITS.get(card_name, {})
        deck.append({"name": card_name, "col": data.get("col", 1)})

    # 呪文をinitial_deckから自動追加
    var cls = CardDB.CLASSES.get(GameSession.class_id, {})
    var initial = cls.get("initial_deck", [])
    for name in initial:
        if CardDB.SPELLS.has(name) or CardDB.STATUS_SPELLS.has(name) or CardDB.SYSTEM_SPELLS.has(name):
            deck.append({"name": name, "col": -1})

    GameSession.selected_deck = deck
    SceneManager.go_to(SceneManager.MAP_SELECT)
```

## 8. SceneManager.gd変更箇所

1. 定数追加（既存`MATERIAL_SELECT`を維持しつつ）:
   - 既存 `"material_select": "res://scenes/MaterialSelect.tscn"` を `"material_select": "res://scenes/InitialCardPick.tscn"` に変更
2. もしくは新定数`INITIAL_CARD_PICK`を追加してパス登録。ただし既存の画面遷移フロー（Title→material_select）を活かすため、パス差し替えが最小変更。

**推奨**: パスのみ差し替え（定数名`MATERIAL_SELECT`は維持）。

## 9. CommonTaskbar.gd変更箇所

`VISIBILITY`辞書の`"material_select"`エントリが既に存在（行22-25）。InitialCardPickでも同じ表示設定を使うため、変更不要（SceneManagerの定数名を維持する場合）。

## 10. 実装手順（順序・依存関係）

| 順序 | タスク | 依存 |
|------|--------|------|
| 1 | UIColors.gd 新規作成 | なし |
| 2 | InitialCardPick.tscn 新規作成 | なし |
| 3 | InitialCardPick.gd 新規作成 - UI構築部分（_build_ui系） | 1, 2 |
| 4 | InitialCardPick.gd - カードプール生成（_generate_choices） | CardDB構造理解 |
| 5 | InitialCardPick.gd - CardViewバインディング（_bind_card, _show_choices） | CardView.tscn |
| 6 | InitialCardPick.gd - インタラクション（ホバー/クリック/ダブルクリック） | 3, 5 |
| 7 | InitialCardPick.gd - アニメーション（Tween全般） | 6 |
| 8 | InitialCardPick.gd - GameSession保存＋画面遷移 | 7 |
| 9 | SceneManager.gd パス差し替え | 2 |
| 10 | 構文チェック＋動作確認 | 全完了 |

## 11. 制約・注意事項

1. **CardView.tscnのEffectLabel欠落**: card_view.gdがEffectLabelを参照するが、tscnに存在しない。has_nodeチェックで動作はするが、effect_textは表示されない。本タスクでは対応しない。
2. **intervalとSPD**: CardDB上のユニットは`interval`（攻撃間隔秒数）を持つ。CardViewの`spd`プロパティにはintで渡す必要がある。`int(data.get("interval", 1.0))`で変換。
3. **既存テスト**: `tests/integration/test_screen_flow.gd`がMaterialSelect.tscnを直接loadしている（行39）。MaterialSelect.tscnファイルは削除しない。テスト修正は別タスク。
4. **GAME_DESIGN.mdとの整合性**: 「盤面を設計して、介入を仕込んで、答え合わせを観戦する」体験の入口。カード選択の戦略性が核に直結。3択から「何を取るか・何を捨てるか」を楽しむ設計は哲学1-1に合致。
5. **ピックの再現性**: ランダムシードは本タスクでは管理しない（将来的にGameSession.map_seedとの統合が必要だが、スコープ外）。

## 12. テスト項目（動作確認チェックリスト）

| # | 確認項目 | 確認方法 |
|---|---------|---------|
| 1 | 画面表示: 3枚のカードが中央に表示される | 目視 |
| 2 | 進捗表示: 「PICK 1 / 6」が表示される | 目視 |
| 3 | ホバー: カードにマウスを乗せるとscale 1.05になる | 目視 |
| 4 | 仮選択: 1回クリックで金色枠点灯、他2枚暗転 | 目視 |
| 5 | 仮選択切替: 別カードクリックで仮選択が移動 | 目視 |
| 6 | 確定: 同じカード2回目クリックで下部スロットへ移動 | 目視 |
| 7 | 進捗更新: 確定後にドット点灯、ラベルが「PICK 2 / 6」に更新 | 目視 |
| 8 | 次の3択: 確定アニメ後に新しい3枚が表示 | 目視 |
| 9 | 6枚完了: 全ピック後に「冒険を始める」ボタン表示 | 目視 |
| 10 | 確定ボタン: 押下でマップ画面に遷移 | 目視 |
| 11 | GameSession保存: 遷移後にGameSession.selected_deckが9エントリ（ユニット6+呪文3） | print確認 |
| 12 | アニメーション中操作: Tween中にクリックしても反応しない | 連打テスト |
| 13 | 構文チェック: `bash check_syntax.sh` でエラー0件 | コマンド実行 |
