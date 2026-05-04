# 要件定義書: EconMVP 交易所（Trade Post）

更新日: 2026-05-01
STATUS: 企画確定（次回MVP実装対象）

企画書: Planning出力 2026-05-01 / Designer出力 2026-05-01

---

## 0. スコープ

EconMVP に新規建物「交易所（Trade Post）」を追加する。
プレイヤーが G（ゴールド）を消費して即時実行する 8 種類の戦術コマンドを提供する。

### 核となる体験との整合性

- 「限られた資源の流し先を決める」体験を G という新リソースで深化
- 「設計して観戦する」体験は維持（コマンドはバトル前/介入タイミングで使用）
- KISS原則: G 単一リソース・8 個固定コマンド・モーダルダイアログ 1 枚で完結

### スコープ外（次回MVP以降）

- G の獲得手段の多様化（戦闘終了収入のみで十分）
- コマンドのアンロック条件・進行度システム
- 交易所の Lv 化（融合システムは装備屋専用）

---

## 1. 概要

### 1.1 機能定義

| 項目 | 値 |
|------|----|
| 建物種別 | TRADE_POST（EconBuilding.BuildingType に追加） |
| 配置制約 | 自陣の最前列（col=0）または最後列（col=7）に限定 |
| 建設コスト | wood:5, stone:5（KISS: 既存 VILLAGE と同程度） |
| 建設時間 | 5.0 秒（VILLAGE と同等） |
| HP | 80（軽建造物） |
| 機能 | クリックで G 交換メニューモーダルを開く |
| 色（_draw） | #7A4F8C（紫） |

### 1.2 G（ゴールド）リソース定義

| 項目 | 値 |
|------|----|
| リソース名 | gold |
| 初期値 | 0 |
| 獲得契機 | バトル終了時に +50G（プレイヤー勝敗問わず固定収入） |
| 消費契機 | 交易所メニューからのコマンド実行のみ |
| 上限 | なし（既存 EconEconomy のリソース上限ルールに準拠） |

### 1.3 配置ルール（重要）

- 配置可能 col: **0 または 7 のみ**（自陣の前列/後列の両端）
- Designer出力の「col=0 or col=8」表記は概念的記述。実装の自陣は col 0-7 のため col=7 を採用
- 既存の `highlight_cells`（半径3ルール）と AND 条件で適用：自陣端 ∩ 領土内
- 山岳・既設建物・敵領土とは衝突しない（既存ルール踏襲）
- 同時設置数の上限なし（KISS: G 経済が自然に上限を作る）

---

## 2. メニュー仕様（8 コマンド）

### 2.1 コマンド一覧

| # | コマンド名 | コスト | 効果概要 | 即時/予約 |
|---|----------|-------|---------|---------|
| 1 | 緊急徴兵 | 10G | 自陣最前列（col=0）に ATTACKER を 3 体即時生成 | 即時 |
| 2 | 緊急防衛 | 12G | 自陣最前列（col=0）に TANK を 2 体即時生成 | 即時 |
| 3 | 石壁設置 | 8G | 指定ヘックスに HP 100 の石壁（建物・移動阻害・攻撃可）を 1 個生成 | 即時（ヘックス選択） |
| 4 | 戦場の霧 | 15G | 30 秒間、敵 AI の偵察精度低下（敵ユニットがプレイヤー旗位置を把握できない期間を延長） | 即時（タイマー駆動） |
| 5 | 補給物資 | 10G | wood +20, stone +20, sulfur +20, wheat +10 を即時付与 | 即時 |
| 6 | 行軍命令 | 5G | 全プレイヤーユニット（is_idle=true のもの）の移動速度を 30 秒間 +50% | 即時（タイマー駆動） |
| 7 | 治癒の祈り | 12G | 全プレイヤーユニット・建物の HP を 30% 回復（max_hp 比） | 即時 |
| 8 | 偵察報告 | 5G | 敵建物の位置・種別を 60 秒間プレイヤー UI に強調表示 | 即時（タイマー駆動） |

### 2.2 コスト設計の根拠

- バトル毎収入 50G、各コマンド最大 15G → 1 バトルで 3-5 個実行可能
- 最高コスト 15G（戦場の霧）= 1 戦闘収入の 30%（重い意思決定）
- 最低コスト 5G（行軍命令・偵察報告）= 1 戦闘収入の 10%（軽い介入）
- 8 コマンド全て使うには 77G ≒ 1.5 戦闘分（経済バランスとして適正）

### 2.3 コマンド実装方針（KISS: 既存システム流用）

| # | コマンド | 既存システムの流用 |
|---|---------|------------------|
| 1 | 緊急徴兵 | EconBattle.spawn_player_unit(pos, ATTACKER) を 3 回 |
| 2 | 緊急防衛 | EconBattle.spawn_player_unit(pos, TANK) を 2 回 |
| 3 | 石壁設置 | 新規 BuildingType.WALL（HP のみ・update なし）を追加 |
| 4 | 戦場の霧 | EconAI に `_fog_remaining: float` フィールド追加・update で減算 |
| 5 | 補給物資 | EconEconomy.add_resource(...) を各リソース呼び出し |
| 6 | 行軍命令 | EconUnit に `_speed_buff_remaining: float` フィールド追加 |
| 7 | 治癒の祈り | 全 player_units / player_buildings をループして hp += max_hp * 0.3（max_hp clamp） |
| 8 | 偵察報告 | EconMain に `_recon_remaining: float` 追加・enemy_buildings 描画時に強調 |

---

## 3. データ構造

### 3.1 EconEconomy への追加

```gdscript
# scripts/econ_mvp/EconEconomy.gd

var gold: int = 0  # ゴールド（交易所コマンド用）

func add_gold(amount: int) -> void:
    gold += amount

func can_afford_gold(amount: int) -> bool:
    return gold >= amount

func spend_gold(amount: int) -> bool:
    if not can_afford_gold(amount):
        return false
    gold -= amount
    return true
```

### 3.2 EconBuilding への追加

```gdscript
# enum BuildingType に TRADE_POST, WALL を追加（並び維持・後方互換のため末尾に追加）
enum BuildingType { BARRACKS, FORTRESS, WORKSHOP, VILLAGE, BASE, SAWMILL, MINE, TRADE_POST, WALL }

# BUILD_COSTS / BUILD_HP / REQUIRED_CONSTRUCTION に各エントリ追加
# BUILD_COSTS: 7: {"wood": 5, "stone": 5}, 8: {}（壁は交易所コマンドで生成・直建設不可）
# BUILD_HP:    7: 80.0, 8: 100.0
# REQUIRED_CONSTRUCTION: 7: 5.0, 8: 0.0（壁は即時設置）
```

### 3.3 EconAI / EconMain への追加（タイマー駆動コマンド）

```gdscript
# EconAI.gd
var _fog_remaining: float = 0.0  # コマンド#4 戦場の霧

# EconMain.gd
var _recon_remaining: float = 0.0  # コマンド#8 偵察報告
var _trade_modal: Window = null    # モーダルダイアログのルートノード参照

# EconUnit.gd
var _speed_buff_remaining: float = 0.0  # コマンド#6 行軍命令
```

### 3.4 戦闘終了時の G 付与（EconBattle.gd）

```gdscript
# battle_ended シグナル発火時に economy.add_gold(50) を呼ぶ
# 既存の battle_ended.emit() 直前に追加
const BATTLE_END_GOLD := 50
```

---

## 4. UI/UX 要件

### 4.1 建物配置 UI（Designer 出力反映）

#### 建物パネル 4×2 グリッド再構成

現在の 6 個 4 列 GridContainer を **4×2 グリッド（columns=4）** に再編する。

| 行 | スロット | 配置 |
|---|---------|------|
| 上段（軍事） | 1-4 | BARRACKS / FORTRESS / WORKSHOP / EQUIPMENT_SHOP（装備屋・別要件定義書） |
| 下段（経済） | 5-8 | VILLAGE / SAWMILL / MINE / TRADE_POST |

- 上段背景色: 既存 COLOR_BUILD_COL（#375590・青系）を維持
- 下段背景色: 経済建物は既存通り
- 交易所ボタン:
  - icon: "$" または "⚖"（KISS: 既存テキストアイコンに合わせる）
  - name: "交易所"
  - cost: "5W·5S"
  - 選択時の枠色（_update_build_card_styles）: COLOR_TRADE_COL（#783C8C）

#### 配置時のハイライト（Designer 出力反映）

- 既存の `_update_build_highlight()` 内で `_place_mode == PlaceMode.TRADE_POST` のとき:
  - fill_cells に追加するセルを **col == 0 OR col == 7** で絞り込む
  - 既存の半径3制限・敵領土排除・占有セル排除は維持
- 配置不可ヘックスにマウスホバー時:
  - `_place_hint_label` のテキストを「盤面端のみ配置可（最前列または最後列）」に変更
  - 表示条件: `_place_mode == PlaceMode.TRADE_POST and !fill_cells.has(hover_cell)`

### 4.2 交易所モーダルダイアログ

#### トリガー

- プレイヤー所有の交易所（建設済み・is_alive=true）を **左クリック**
- 既存の `_input()` でユニット選択前にチェック
- バトル中・バトル前どちらでも開ける

#### モーダル構造

| 項目 | 値 |
|------|----|
| ノード型 | AcceptDialog（Godot 標準・モーダル） |
| サイズ | 480×360 px |
| 位置 | ビューポート中央 |
| 背景色 | COLOR_PANEL（#231F1B） |
| 枠色 | COLOR_TRADE_COL（#783C8C・紫） |
| タイトル | "交易所 — Trade Post" |
| 閉じる方法 | ×ボタン または ESCキー（AcceptDialog 標準動作） |

#### コマンドリスト UI

- VBoxContainer に 8 個の Button（HBoxContainer 行）
- 各行の構成:
  ```
  [#1 緊急徴兵]  [10G]  [説明: 自陣前列にATK×3]  [実行ボタン]
  ```
- 列幅: 名前 120px / コスト 50px / 説明 220px / ボタン 60px
- フォントサイズ: 13（既存 BUILD パネルに合わせる）
- 文字色: COLOR_TEXT（#DCD2B9）
- G 不足時:
  - 実行ボタンを `disabled = true`
  - コスト表記を赤色（#FF4040）

#### G 残高表示

- モーダル上部に `[現在 G: 35]` ラベル
- フォントサイズ 16・色 COLOR_ACCENT_GOLD（#B49448）
- コマンド実行直後に即時更新

### 4.3 ヘックス選択コマンド（#3 石壁設置）

- 石壁設置ボタンを押すと:
  1. モーダルを一旦閉じる
  2. `_place_mode = PlaceMode.WALL`（新 enum 値）に切り替え
  3. ハイライト: 自陣の空きヘックス全部（col 0-7・既存ハイライトロジック）
  4. クリックで配置 → G を消費 → place_mode を NONE に戻す
- ESCキーで配置キャンセル時は G を消費しない

### 4.4 ヘッダー G 表示

- 既存の `_resource_label`（資源表示ラベル）に G を追加
- 表記例: `Wood: 23 / Stone: 15 / Sulfur: 8 / Wheat: 12 / Gold: 35`
- フォーマット維持・既存と同じスタイル

---

## 5. 実装対象ファイル

| ファイル | 変更内容 | 規模目安 |
|---------|---------|---------|
| scripts/econ_mvp/EconEconomy.gd | gold フィールド・add/can_afford/spend_gold メソッド追加 | +20 行 |
| scripts/econ_mvp/EconBuilding.gd | BuildingType に TRADE_POST/WALL 追加・BUILD_COSTS/HP/CONSTRUCTION 拡張・_draw 色追加 | +15 行 |
| scripts/econ_mvp/EconBattle.gd | battle_ended 直前で economy.add_gold(50)・スポーン公開メソッド整備 | +5 行 |
| scripts/econ_mvp/EconUnit.gd | _speed_buff_remaining 追加・update で残時間減算・移動速度倍率反映 | +10 行 |
| scripts/econ_mvp/EconAI.gd | _fog_remaining 追加・update で残時間減算・偵察精度分岐 | +10 行 |
| scripts/econ_mvp/EconMain.gd | PlaceMode に TRADE_POST/WALL 追加・建物パネル 4×2 化・モーダル生成・8 コマンド実行ハンドラ・G ラベル・_recon_remaining | +200 行 |
| 新規: scripts/econ_mvp/EconTradePostModal.gd | モーダルダイアログ専用クラス（コマンドリスト UI と実行ハンドラ）<br>※EconMain.gd が 800 行超見込みのため分離 | +180 行 |

### ファイルサイズ予防チェック

- EconMain.gd 現在 1100 行前後 → +200 行で 1300 行予測
- **800 行超のため EconTradePostModal.gd を分離必須**（要件に分離設計を含める）
- 装備屋要件と合わせると EconMain.gd は更に肥大するため、本要件と別要件で計 2 ファイルを分離する

---

## 6. 制約・注意事項

### 6.1 疎結合ルール（CLAUDE.md 準拠）

- EconTradePostModal が EconEconomy / EconBattle / EconAI / EconUnit の内部状態を直接書き換えるのは禁止
- 必ず `economy.spend_gold(...)`, `battle.spawn_player_unit(...)`, `ai.apply_fog(...)` 等のメソッド経由で操作
- 新規メソッドが必要なら EconBattle / EconAI 側に最小限のラッパーを追加

### 6.2 設計整合性

- 「廃止済み設計」（CLAUDE.md）への抵触なし
  - 盤面召喚システム復活ではない（介入コマンドであり、配置式と別軸）
  - アクティブスキル復活ではない（ユニット個別ではなく交易所建物の機能）
- 3 秒ルール: モーダル UI で意図を 3 秒で伝える（コマンド名・コスト・効果説明）

### 6.3 既存システムとの整合性

- ラリーフラグ（req_econ_rally_point.md）と独立: 交易所はラリー接続対象ではない
- 配置ボーナス（req_econ_building_variants.md）と独立: 交易所は生産しないため `_placement_bonus_active` の対象外
- 集中建設モード（既存）の対象に含める: build_priority フィールドは継承

### 6.4 バランス調整余地

- BATTLE_END_GOLD = 50 は初期値・実プレイで微調整想定
- 各コマンドコストは const として定義し、後で一括調整可能にする
- コマンド一覧は `EconTradePostModal.COMMANDS: Array` の Dictionary 配列で定義（追加/削除しやすい構造）

---

## 7. 完了定義（Checker チェックリスト）

- [ ] EconEconomy に gold フィールド・add/can_afford/spend_gold が追加されている
- [ ] EconBuilding.BuildingType に TRADE_POST と WALL が追加されている
- [ ] BUILD_COSTS / BUILD_HP / REQUIRED_CONSTRUCTION に新規エントリがある
- [ ] 建物パネルが 4×2 グリッド（columns=4）に変更されている
- [ ] 交易所ボタンの選択時枠色が COLOR_TRADE_COL（#783C8C）になっている
- [ ] PlaceMode.TRADE_POST 時、fill_cells が col=0 または col=7 のみに絞られる
- [ ] 配置不可ヘックスホバー時に「盤面端のみ配置可」ヒントが表示される
- [ ] 交易所をクリックでモーダルダイアログが開く
- [ ] モーダルが ESC または ×ボタンで閉じる
- [ ] 8 コマンドが Button として表示されコスト・説明が見える
- [ ] G 不足時に該当ボタンが disabled になる
- [ ] コマンド実行で G が減り、効果が即時反映される
- [ ] 戦闘終了時に economy.gold が +50 される
- [ ] ヘッダーラベルに G 残高が表示される
- [ ] 石壁設置コマンドで _place_mode が WALL に切り替わり、ヘックス選択で生成される
- [ ] EconTradePostModal.gd が新規ファイルとして分離されている
- [ ] check_syntax.sh が通る
- [ ] CEO 承認済み
