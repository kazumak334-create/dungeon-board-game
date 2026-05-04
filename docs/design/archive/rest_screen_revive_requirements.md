STATUS: 廃止（→ docs/GAME_DESIGN_V0_2_MVP.md）
最終更新: 2026-05-04

# RestScreenRevive 要件定義書（Phase 4 ユニット復帰システム）

## 1. 概要
BW間の休憩画面でHP=0となった死亡ユニットをゴールド消費で復帰させる機能。
死亡ユニット情報は `GameSession.wave_dead_units` に集約されているため、これを取得して復帰UIを構築する。
「盤面を設計して、介入を仕込んで、答え合わせを観戦する」の「盤面設計」フェーズに属する機能であり、
プレイヤーは手持ちリソース（gold）と引き換えに戦力を再構築する。

## 2. 実装対象

### 2.1 新規作成ファイル
- `scripts/RestScreenRevive.gd`（予測100行）

### 2.2 連携する既存ファイル（変更なし）
- `scripts/GameSession.gd`: `wave_dead_units` を読み取り、`gold` を減算、`selected_deck` に追加
- `scripts/RestScreenManager.gd`: `RestScreenRevive` を初期化・クリーンアップ
- `scripts/CardDB.gd`: CardDB.UNITS からユニットデータ取得
- `scripts/ConfigLoader.gd`: shop.rarity_price を流用（復帰コスト算出用）

### 2.3 ファイルサイズ確認
| ファイル | 現在行数 | 追加行数 | 予測行数 | 判定 |
|---------|---------|---------|---------|------|
| RestScreenRevive.gd | 0 | +100 | 100 | 新規・OK |
| RestScreenManager.gd | 202 | +10 | 212 | OK（500行未満） |

## 3. データ構造

### 3.1 wave_dead_units（既存・GameSession.gd L79）
```gdscript
var wave_dead_units: Array = []
# スキーマ: [{unit_name: String, rarity: String, death_wave: int, initial_slot: int}, ...]
```

**注意**: 既存コード `BoardManager.gd:310` は `record_dead_unit(unit.unit_name, initial_slot)` と2引数で呼んでおり、
定義側 `GameSession.gd:176` の4引数シグネチャと不整合がある。
→ **本Phase 4では本件には踏み込まず、wave_dead_unitsが持つデータのみを信頼して読み取る**。
実装時に呼び出し側がrarity/waveを渡していない場合、 `get("rarity", "common")` 等でフォールバック参照する。

### 3.2 revivable_units（新規・RestScreenRevive.gd内）
```gdscript
var revivable_units: Array = []
# スキーマ: [{
#   unit_name: String,       # ユニットID（CardDB.UNITSのキー）
#   rarity: String,          # レアリティ（復帰コスト算出用）
#   initial_slot: int,       # 配置スロット（0-8）
#   revive_cost: int,        # 復帰コスト（gold）
#   death_wave: int          # 死亡ウェーブ（UI表示のみ）
# }, ...]
```

### 3.3 復帰ボタン領域
```gdscript
const REVIVE_AREA = {"x": 20, "y": 550, "w": 800, "h": 30}
# 手持ちカードエリア（Y:390-540）の下、フッター（Y:560-）の上の20px余白内に配置
# → 設計整合性のため、手持ちカードタイル内に復帰ボタンを配置する方式に変更（5.2参照）
```

## 4. 実装詳細

### 4.1 クラス構造
```gdscript
# RestScreenRevive.gd
extends Node

signal revive_completed(unit_name: String, new_gold: int)

const COLOR_REVIVE := Color(0.6, 0.3, 0.3)
const COLOR_REVIVE_HOVER := Color(0.7, 0.4, 0.4)
const COLOR_DIM := Color(0.5, 0.5, 0.5)

var game_session: Node
var ui_root: Control
var revivable_units: Array = []
var revive_buttons: Array = []  # Button参照の配列（クリーンアップ用）
```

### 4.2 関数シグネチャ
```gdscript
func initialize(session: Node, parent: Control) -> void
# 役割: GameSession参照を保持、wave_dead_unitsからrevivable_units構築、UIは直接作らず呼び出し側に委ねる

func find_revivable_units() -> Array
# 役割: GameSession.wave_dead_unitsを走査し、各要素に revive_cost を付与して返す
# 戻り値: Array[Dictionary]（3.2のスキーマ）

func calculate_revive_cost(rarity: String) -> int
# 役割: レアリティに応じた復帰コスト算出
# 計算式: shop.rarity_priceの30%（小数切り捨て）
#   common=15, uncommon=30, rare=60, epic=120, legend=240

func create_revive_button(target_container: Control, unit_data: Dictionary) -> Button
# 役割: 復帰ボタンを生成し target_container に add_child
# 引数: target_container（手持ちカードタイル等）、unit_data（revivable_unitsの1要素）
# 戻り値: 生成したButton（シグナル接続用）

func revive_unit(index: int) -> bool
# 役割: revivable_units[index]のユニットを復帰させる
# 処理:
#   1. gold チェック（不足時false）
#   2. GameSession.gold -= revive_cost
#   3. GameSession.selected_deck に unit_name を追加
#   4. GameSession.wave_dead_units から該当要素を削除
#   5. revive_completed シグナル発火
# 戻り値: 成功時true、失敗時false

func cleanup() -> void
# 役割: revive_buttons内のボタンを全てqueue_free、配列クリア
```

### 4.3 ロジックフロー

#### 4.3.1 初期化フロー
```
RestScreenManager.build_ui()
  └─> RestScreenRevive.initialize(game_session, ui_root)
        ├─> find_revivable_units() で復帰候補リスト構築
        └─> RestScreenManager.build_hand_area() 内でHP=0カードに create_revive_button() を呼び出し
```

#### 4.3.2 復帰処理フロー
```
プレイヤーが復帰ボタンクリック
  └─> revive_unit(index) 実行
        ├─> gold < revive_cost → return false（ボタン側でガード済み想定）
        ├─> GameSession.gold を減算
        ├─> GameSession.selected_deck.append(unit_name)
        ├─> GameSession.wave_dead_units から該当要素削除
        └─> revive_completed.emit(unit_name, new_gold)
              └─> RestScreenManager が受信
                    ├─> hand_area再構築（build_hand_area呼び直し）
                    └─> CommonTaskbar のゴールド表示更新
```

### 4.4 復帰コスト計算（確定仕様）
```gdscript
func calculate_revive_cost(rarity: String) -> int:
    var rarity_price: Dictionary = ConfigLoader.get_value("shop", "rarity_price", {
        "common": 50, "uncommon": 100, "rare": 200, "epic": 400, "legend": 800
    })
    var base_price: int = rarity_price.get(rarity, 50)
    return int(base_price * 0.3)  # 購入価格の30%
```

**根拠**:
- 既存設計書（rest_screen_requirements.md 6.3）の `Tier × 30gold` は CardData に tier フィールドがないため不採用
- 既存データは `rarity` を持っており、ショップ価格体系と整合性が取れる
- 「復帰 < 新規購入」であることで、復帰の戦略的価値（育てたユニットの再利用）を維持

### 4.5 復帰ボタンUI仕様
| 項目 | 値 |
|-----|-----|
| 配置位置 | 手持ちカードタイル内下部（RestScreenManager側のカードタイルに追加） |
| サイズ | 90×20 px |
| テキスト | "復帰 XXG"（XX=revive_cost） |
| 通常色 | COLOR_REVIVE (0.6, 0.3, 0.3) |
| ホバー色 | COLOR_REVIVE_HOVER (0.7, 0.4, 0.4) |
| 資金不足時 | COLOR_DIM (0.5, 0.5, 0.5) / disabled=true |
| フォントサイズ | 10 |

### 4.6 RestScreenManagerとの連携インターフェース

#### RestScreenManager.gd への追加（+10行想定）
```gdscript
# プロパティ追加
var revive: Node  # RestScreenRevive

# build_ui() 内で shop 初期化の直後に追加
revive = preload("res://scripts/RestScreenRevive.gd").new()
add_child(revive)
revive.initialize(game_session, ui_root)
revive.revive_completed.connect(_on_revive_completed)

# build_hand_area() 内で HP=0判定時に追加
# 現状のbuild_hand_areaはHP情報を持たないため、revivable_unitsと照合して
# unit_name が含まれるカードにのみ revive.create_revive_button() を呼ぶ

# コールバック追加
func _on_revive_completed(unit_name: String, new_gold: int) -> void:
    rest_state.gold = new_gold
    for child in hand_area.get_children():
        child.queue_free()
    build_hand_area()

# cleanup() 内に追加
if revive:
    revive.cleanup()
```

**注意**: 現状の `build_hand_area()` は `selected_deck` を列挙して全カードを通常表示しているため、
HP=0ユニットは `wave_dead_units` 側にのみ存在し selected_deck から除外されている前提となる。
→ 仕様確認必須事項（5.1参照）

## 5. 制約・注意事項

### 5.1 仕様確認必須事項（CEOへの確認）
**死亡ユニットの selected_deck 残存ポリシー**:
- A案: BW終了時に死亡ユニットは `selected_deck` から除外、`wave_dead_units` にのみ存在（復帰で selected_deck に戻す）
- B案: 死亡ユニットも `selected_deck` に残す（HP=0フラグで識別、復帰でHPを回復）

**現状実装**: `record_dead_unit` は `wave_dead_units` に追加するだけで、`selected_deck` は変更していない。
→ B案寄りだが、HP状態を保持する仕組みが selected_deck には無い（名前の配列のみ）

**本要件定義では A案を採用**:
- 理由1: selected_deck は単純な文字列配列であり、HP状態を保持する設計になっていない
- 理由2: `wave_dead_units` が既に死亡記録の単一ソースとして存在する
- 理由3: UI上で「手持ちカード（生存）」と「復帰可能カード（死亡）」を明確に分離できる
- 必要な追加処理: BW終了時に `wave_dead_units` に記録されたユニットを `selected_deck` から除外する処理が別途必要（本Phase 4の責務外・別タスク）

### 5.2 既存コード整合性
- `BoardManager.gd:310` の `record_dead_unit(unit.unit_name, initial_slot)` は2引数呼び出しで既存コードとして機能している。rarity/death_wave が記録されない可能性あり → **実装時は `get("rarity", "common")` のフォールバック必須**
- `RestScreenShop.gd` の `_get_price()` との計算ロジック統一（同じ rarity_price を参照）

### 5.3 GAME_DESIGN.mdとの整合性
- 「盤面を設計して、介入を仕込んで、答え合わせを観戦する」の「盤面設計」フェーズの機能として整合
- 3秒ルール：「復帰 60G」のラベルのみで意図が伝わる
- 足し算禁止：新規フィールド・新規システムは追加しない（既存 wave_dead_units / gold / selected_deck のみ使用）

### 5.4 やらないこと（Phase 4スコープ外）
- 復帰時のアニメーション演出（Tween）
- 復帰キャンセル・確認ダイアログ
- 復帰後の自動配置（selected_deckに戻すのみで、BoardManagerへの配置復元は行わない）
  - ※現状の initial_units / placement_config との関係は後続Phaseで整理
- `record_dead_unit` のシグネチャ統一（別Phaseでリファクタリング）

## 6. 完了定義
- [ ] RestScreenRevive.gd（100行以内）作成完了
- [ ] find_revivable_units が wave_dead_units を正しく変換
- [ ] calculate_revive_cost が rarity_price × 0.3 で算出
- [ ] revive_unit が gold減算 + selected_deck追加 + wave_dead_units削除を正しく実行
- [ ] RestScreenManager との連携（シグナル接続・cleanup）が機能
- [ ] check_syntax.sh でエラー0件
- [ ] CEO承認済み

## 7. 参照ファイル
- C:\Users\kazum\dungeon-board-game\scripts\GameSession.gd（L79, L176-184）
- C:\Users\kazum\dungeon-board-game\scripts\RestScreenManager.gd（既存）
- C:\Users\kazum\dungeon-board-game\scripts\RestScreenShop.gd（価格体系参考）
- C:\Users\kazum\dungeon-board-game\scripts\ConfigLoader.gd（L39-47, shop.rarity_price）
- C:\Users\kazum\dungeon-board-game\scripts\BoardManager.gd（L304-310, 死亡記録）
- C:\Users\kazum\dungeon-board-game\docs\design\rest_screen_requirements.md（Phase 4セクション）
- C:\Users\kazum\dungeon-board-game\docs\design\rest_screen_ux_plan.md（UI仕様）
- C:\Users\kazum\dungeon-board-game\docs\GAME_DESIGN.md
