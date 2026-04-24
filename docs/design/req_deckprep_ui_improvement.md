# DeckPrepBoard UI改善 要件定義書

作成日: 2026-04-24
対象ブランチ: claude/zealous-hofstadter-95e7b2

---

## 1. 概要・スコープ

デッキ準備画面（DeckPrepBoard）のUXを改善し、バトル画面（GameUI/GameUIQueue）との視覚的一貫性を高める。
「盤面を設計して、介入を仕込んで、答え合わせを観戦する」体験のうち「設計」フェーズを強化する5機能を定義する。

対象ファイル（現行行数）:
- scripts/DeckPrepBoard.gd（1158行）
- scripts/DeckPrepBoardSpells.gd（497行）
- scripts/GameUIQueue.gd（実装確認済み・Q1～Q3は既に実装あり）
- scripts/GameUI.gd（呪文スロット: _build_spell_slots 573行付近）
- scripts/DebugParamTab.gd（新セクション追加）
- config/balance.json（perspective パラメータ追加）

---

## 2. Must（必ず実装する）

| ID | 内容 |
|----|------|
| REQ-1 | 左パネル手持ちカード → 盤面セルへのD&D |
| REQ-2 | 配置済みカードセルへのカード情報表示 + スプライト表示領域確保 |
| REQ-3 | GameUIQueue.gd への Q1スロット追加（確認: 既存コードに既にQ1実装あり → 3.3参照） |
| REQ-4 | デッキ準備画面での呪文スロット3マス非表示 |
| REQ-5 | 盤面コンテナへの疑似遠近法（skew/rotation）+ DebugParamTab連携 |

---

## 3. Must-Not（実装禁止）

- 既存の `try_drop_card` / `start_drag_group` / `_show_drop_hints` のロジックを書き換えない
- `GameSession.placement_config` のデータ構造を変更しない
- バトル画面（GameUI.gd）の呪文スロットを削除しない（非表示に切り替えるのみ）
- スプライトが存在しない場合にエラーを出さない（存在確認してから読み込む）
- perspective パラメータを balance.json の既存セクションに混在させない（専用セクションに分離）
- DebugParamTab 以外の場所にスライダーを追加しない

---

## 4. Out-of-Scope（今回対象外）

- 実際のスプライト画像ファイル（assets/sprites/units/*.png）の用意
- バトル画面（GameUI.gd）の盤面コンテナへの perspective 適用（REQ-5 は DeckPrepBoard のみ対象。バトル画面は「別途・同じ仕組み」と企画書に記載あり）
- 呪文スロット自体のUI変更（非表示切り替えのみ）
- Q2・Q3の表示スタイル変更
- DeckPrepBoardSpells.gd の内部ロジック変更

---

## 5. 受け入れ基準

### REQ-1: 手持ちカード → 盤面 D&D

**3秒ルール判定: OK** — 手持ちカードを盤面にドラッグする操作はバトル画面のD&Dと同じ視覚的操作で直感的に伝わる。

#### 現状分析

- `_on_chip_input`（1147行）で左クリック時に `start_drag_group` を呼び出している
- `try_drop_at_mouse` は盤面セル・呪文デッキ・ユニット手持ち・呪文手持ちへのドロップを判定している
- 手持ちカード（`row=1, col=-1`）からのドラッグは `_drag_source_idx` にセットされる
- `try_drop_card` 内（780行）: `source_row == 1` の場合を「手持ち→盤面」として処理するコードが存在する

#### Clause 1-1: ドラッグ開始

- 条件: 手持ちカードチップ（`row=1, col=-1` のカード）を左クリック押下
- 処理: 既存の `_on_chip_input` → `start_drag_group` を流用する
- ドラッグノード: 既存の90×130px縦長カード形式（DeckPrepBoard内の定数 `DRAG_CARD_W=90`, `DRAG_CARD_H=130` を使用）
- ドロップヒント: `_show_drop_hints(card_name)` を既存通り呼び出す

#### Clause 1-2: ドロップ判定

- `try_drop_at_mouse` の盤面セル判定ロジックをそのまま使用する
- ドロップ先が盤面セル（col>=0）の場合: `try_drop_card(idx, 0, ri, ci)` を呼ぶ
- ユニット以外の手持ちカード（呪文）を盤面にドロップした場合: 既存の `CardDB.UNITS.has(card_name)` チェック（742-753行）が拒否する。これをそのまま活かす

#### Clause 1-3: 配置後の更新

- ドロップ成功後: 既存の `populate_cards()` 呼び出しで盤面を再描画する
- 手持ちカードパネルも同タイミングで再描画する

---

### REQ-2: 盤面セルへのカード情報表示 + スプライト準備

**3秒ルール判定: OK** — カード名・種族・HP・ATK はバトル画面でも表示されている情報と同一。3秒で認識できる。

#### Clause 2-1: セル内情報レイアウト

既存のセル（`CELL_W=118, CELL_H=105`）内に以下を配置する。現行の VBoxContainer（`vbox`）を活用する。

```
[スプライト領域] 縦: 52px, 横: 114px（CELL_W-4）, 上寄せ
[カード名]       font_size: 10, Color(0.9, 0.9, 0.8)
[種族]           font_size: 9,  Color(RACE_COLORS[race] or DEFAULT_COLOR)
[HP / ATK]       font_size: 9,  "HP:X  ATK:Y" 形式, Color(0.7, 0.8, 0.7)
```

#### Clause 2-2: スプライト表示領域

- ノード種別: TextureRect
- サイズ: 幅 `CELL_W - 4`px、高さ 52px（セル高 105px の約半分）
- デフォルト状態: texture = null のとき `expand_mode = KeepAspect`、 `stretch_mode = Scale` で透明表示
- プレースホルダー: スプライトなしの場合は背景色として種族カラー（`RACE_COLORS` を流用）の `ColorRect` を敷く
- スプライト読み込み:
  - パス: `res://assets/sprites/units/{card_name}.png`
  - 読み込み前に `ResourceLoader.exists(path)` で存在確認する
  - 存在する場合: `load(path)` してTextureRectにセット
  - 存在しない場合: プレースホルダーColorRectを表示（エラーなし）

#### Clause 2-3: 表示更新タイミング

- `populate_cards()` の呼び出し時に毎回再構築する（既存の populate_cards 呼び出しフロー維持）

---

### REQ-3: Q1スロット追加（GameUIQueue.gd）

**3秒ルール判定: 確認必要（後述）**

#### 現状分析（重要）

GameUIQueue.gd のコードを確認した結果、**Q1・Q2・Q3 は既に実装済み**であることが確認できた。

```
var _queue_card_self: Control = null      # 自分のキューカード Q1(NEXT)
var _queue_card_enemy: Control = null     # 敵のキューカード Q1(NEXT)
```

127-258行に自分側Q1/Q2/Q3 および 敵側Q1/Q2/Q3 の全スロットが実装されている。

- 自陣 Q1 = `self_q1_x` = col2（前列）
- 自陣 Q2 = `self_q2_x` = col1（中列）
- 自陣 Q3 = `self_q3_x` = col0（後列）
- 敵陣 Q1 = `enemy_q1_x` = col0（前列）
- 敵陣 Q2 = `enemy_q2_x` = col1（中列）
- 敵陣 Q3 = `enemy_q3_x` = col2（後列）

**Implementer への指示**: まず現在のバトル画面でQ1/Q2/Q3が正しく表示されているかを視覚確認すること。
表示されていない場合のみ、以下の原因を調査する。

#### Clause 3-1: 追加実装が必要な場合

GameUIQueue.gdの `_build_card_queue_ui()` が呼ばれていない場合、または `build()` から正しく呼ばれていない場合に対処する。

**3秒ルール判定（REQ-3）: OK** — 各列の上部に並ぶデッキキューは「次に出るカード」を一目で示す。バトル観戦の情報量として必要。

#### Clause 3-2: Q1スロットのスタイル仕様（Q2/Q3との統一基準）

| 要素 | Q1（NEXT） | Q2・Q3 |
|------|-----------|--------|
| 背景色 | `Color(0.1, 0.12, 0.18, 0.7)` | 同左 |
| 光り枠 | 自: `Color(0.3, 0.8, 0.3, 0.4)` / 敵: `Color(0.8, 0.3, 0.3, 0.4)` | なし |
| ラベル | "▶ NEXT" / "NEXT ◀" | "Q2" / "Q3" |

---

### REQ-4: デッキ準備画面での呪文スロット非表示

**3秒ルール判定: OK** — デッキ準備画面に「左クリック発動/右クリック破棄」UI があっても発動できない。誤操作防止のため非表示が正しい。バトル画面では引き続き表示するので機能は損なわれない。

#### Clause 4-1: 実装箇所

- 対象: GameUI.gd の `_build_spell_slots()` で生成する全ノード（573行付近）
  - titleラベル（「呪文スロット（左クリック発動／右クリック破棄）」）
  - 3スロット分のglow_rect・panel・status_icon・spell_name_label等（`_spell_slot_panels` 配列の全要素）

#### Clause 4-2: 制御方法

- `_build_spell_slots()` の冒頭で現在の画面状態を判定するのではなく、生成した全ノードを `_spell_slot_parent: Control` にまとめる
- 代替案（シンプル）: `_spell_slot_panels` 配列の各パネル辞書に `"nodes": Array` を追加し、`set_spell_slots_visible(visible: bool)` 関数で一括 visible 切り替えを実装する
- DeckPrep画面への遷移時: `set_spell_slots_visible(false)` を呼ぶ
- バトル開始時（GameUI の既存遷移処理から）: `set_spell_slots_visible(true)` を呼ぶ

#### Clause 4-3: 呼び出し元

- GameUI.gd 内に `set_spell_slots_visible(visible: bool)` 関数を定義する
- DeckPrep.gd から GameUI インスタンスへの参照経由で呼び出すか、AutoLoad / Signal 経由とする（既存の呼び出しパターンに従う）

---

### REQ-5: 盤面の疑似遠近法（動的角度調整付き）

**3秒ルール判定: 条件付きOK** — 疑似遠近法は「盤面の設計感」を視覚強化するが、数値が過大になると可読性を損なう。デフォルト値は3秒ルールを満たす保守的な値とする（後述）。

#### Clause 5-1: 実装対象ノード

- DeckPrepBoard の盤面全体を包む `Node2D` コンテナ（新規: `_board_perspective_container`）
- `_build_board_cells` で生成する全セルノードをこのコンテナの子とする
- 列ラベル（`_build_board_col_labels`）もこのコンテナに含める

#### Clause 5-2: Transform 適用方法

Godot 4 の `Node2D.transform` に `Transform2D` を設定する方式で実装する。

```
# 適用する変換（疑似コード）
var t = Transform2D.IDENTITY
# 1. perspective_angle: 水平軸回転（X軸方向のskew）
t = t.rotated(deg_to_rad(perspective_angle))
# 2. perspective_skew: 縦方向圧縮（Y軸スケール）
t = Transform2D(t.x, t.y * (1.0 - perspective_skew), t.origin)
# _board_perspective_container.transform = t
```

実際の適用は `_apply_perspective()` 関数にまとめ、パラメータ変更時に呼び出す。

#### Clause 5-3: row_depth_offset

- 後列セル（col=0, 手前から遠い方）を上に、前列セル（col=2, 手前）を下に配置するオフセット
- `_build_board_cells` で各セルの `position.y` に `ci * row_depth_offset` を加算する（ci=0が後列=遠景）
- perspective コンテナ適用後に絵的に奥行きが出ることを意図している

#### Clause 5-4: パラメータ定義

| パラメータ名 | 型 | デフォルト | 範囲 | balance.json セクション |
|------------|---|-----------|------|----------------------|
| perspective_skew | float | 0.15 | 0.0 ～ 0.5 | "deckprep_perspective" |
| perspective_angle | float | 12.0 | 0.0 ～ 30.0（度） | "deckprep_perspective" |
| row_depth_offset | float | 20.0 | 0.0 ～ 40.0（px） | "deckprep_perspective" |

balance.json への追加スキーマ（既存セクションを変更しない）:
```json
"deckprep_perspective": {
  "perspective_skew": 0.15,
  "perspective_angle": 12.0,
  "row_depth_offset": 20.0
}
```

#### Clause 5-5: ConfigLoader との連携

- DeckPrepBoard.gd の `build_placement_tab()` 内で以下を実行する:
  ```
  perspective_skew = ConfigLoader.get_value("deckprep_perspective", "perspective_skew", 0.15)
  perspective_angle = ConfigLoader.get_value("deckprep_perspective", "perspective_angle", 12.0)
  row_depth_offset = ConfigLoader.get_value("deckprep_perspective", "row_depth_offset", 20.0)
  ```
- ランタイム変更は `ConfigLoader.set_runtime_value()` 経由で行い、`_apply_perspective()` を再呼び出しする

#### Clause 5-6: DebugParamTab への追加

- DebugParamTab.gd の `_build_ui()` に新セクション「DeckPrep遠近法」を追加する
- 追加スライダー（既存の `_add_slider` 関数を使用）:
  ```
  _add_slider(vbox, "deckprep_perspective", "perspective_skew", "縦圧縮率", 0.0, 0.5, 0.01)
  _add_slider(vbox, "deckprep_perspective", "perspective_angle", "水平回転角(度)", 0.0, 30.0, 0.5)
  _add_slider(vbox, "deckprep_perspective", "row_depth_offset", "列奥行きオフセット(px)", 0.0, 40.0, 1.0)
  ```
- スライダー変更時: `ConfigLoader.set_runtime_value()` → DeckPrepBoard の `_apply_perspective()` を呼ぶ
  - DeckPrepBoard への参照渡しは DebugParamTab の既存コールバック方式に合わせる

---

## 6. 依存関係・実装順序

```
REQ-4（最初）
  → GameUI.gd に set_spell_slots_visible() を追加
  → DeckPrep.gd の遷移処理から呼ぶ

REQ-2（次）
  → DeckPrepBoard._build_board_cells() 内のセル構築を拡張
  → populate_cards() の表示ロジックに TextureRect 追加

REQ-1（REQ-2 後）
  → 手持ちカードの D&D は REQ-2 のセル表示が完成してからテストが容易

REQ-5（REQ-2 後）
  → _board_perspective_container の導入は、セル構造が固まってから行う
  → balance.json / DebugParamTab の変更も同時に実施

REQ-3（最後・確認後）
  → 視覚確認でQ1が表示されていれば実装不要
  → 表示されていない場合のみ対処
```

---

## 7. 用語定義

| 用語 | 定義 |
|------|------|
| 手持ちカード | `placement_config` で `row=1, col=-1` のカード。盤面未配置のユニット/呪文 |
| 盤面セル | `_cell_rects[side][row][col]` で管理される Panel ノード（3×3） |
| Q1/Q2/Q3 | GameUIQueue が表示するデッキキュー。Q1=前列(NEXT)、Q2=中列、Q3=後列 |
| perspective_skew | Y軸方向の縦圧縮率。0.0=変形なし、0.5=50%圧縮 |
| perspective_angle | 盤面水平軸の回転角。単位は度。正の値で手前が広く見える |
| row_depth_offset | 各列のY軸オフセット量。前列ほど下に、後列ほど上に配置することで奥行きを演出する |
| _board_perspective_container | DeckPrepBoard で新規作成する盤面ルートの Node2D。transform で遠近法を適用する |
| RACE_COLORS | DeckPrepBoard.gd の定数。スライム/獣/アンデッド の種族カラーマップ |
| set_spell_slots_visible | GameUI.gd に追加する関数。呪文スロット全ノードの visible を一括切り替えする |

---

## 8. ファイルサイズ予測（Implementer 参照用）

| ファイル | 現行行数 | 追加予測 | 合計予測 | 判定 |
|---------|---------|---------|---------|------|
| DeckPrepBoard.gd | 1158 | +80（REQ-1,2,5） | 1238 | 要注意（800超）。分割は今回不要だが次フェーズで検討 |
| GameUI.gd | 確認要 | +20（REQ-4） | - | 小規模 |
| DebugParamTab.gd | 約130 | +10（REQ-5） | 約140 | 問題なし |
| balance.json | - | +1セクション | - | 問題なし |

DeckPrepBoard.gd は既に1158行と大きい。REQ-5 の `_apply_perspective()` は独立した小関数（15行以内）にまとめ、`_build_board_cells` への変更も最小限に抑えること。
