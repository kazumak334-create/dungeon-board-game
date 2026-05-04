# Econ MVP フッターUI 企画書

**作成日:** 2026-05-01
**ステータス:** 企画（未実装）
**対象:** `scripts/econ_mvp/EconMain.gd` の `_setup_ui()` フッター領域
**画面サイズ:** 1280 × 720（フッター 1280 × 180）

---

## 1. 画面の目的

### この画面で何を達成するか
1ランの戦闘準備〜進行中、プレイヤーが「資源の流し先（配分）」と「建設物の選択」を最小操作で完結させるためのコックピット。

### ユーザーが何を判断・選択するか
- ハーベスター12人をどの資源・役割に何人ずつ流すか（±ボタンで微調整）
- 直近で建てる建物は4種のうちどれか（カード選択でモード切替）
- 「次に盤面のどこに置くか」の意思決定（右端のヒント領域）

### 核となる体験との接続
> 限られた資源の流し先を決める → その配分が戦況を作る快感

フッターは「配分の意思決定面」そのもの。1画面で配分が"見えて・触れて・伝わる"こと。

---

## 2. レイアウト構成

### 2.1 全体（フッター 1280 × 180）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  HARVESTER ALLOCATION ブロック  │  BUILD ブロック   │  PLACE-ON-BOARD ヒント │
│  幅 700px                       │  幅 420px         │  幅 160px              │
└─────────────────────────────────────────────────────────────────────────────┘
   x=0..700                          x=700..1120         x=1120..1280
```

座標は親 `HBoxContainer`（`PRESET_FULL_RECT`）配下。`VSeparator` は1pxで領域境界に挿入。

### 2.2 HARVESTER ALLOCATION ブロック（700 × 180）

```
┌──────────────────────────────────────────────────────────────┐
│ — HARVESTER ALLOCATION —     total 12 · weights drive distrib │ 24px ヘッダー
├──────────────────────────────────────────────────────────────┤
│ [WOOD ] [STONE] [SULFR] [WHEAT] [BUILD] [TRADE]              │ 110px 6列メイン
│  icon    icon    icon    icon    icon    icon                │
│  [-] N [+]                                                    │
├──────────────────────────────────────────────────────────────┤
│ ████ STACK BAR (12 segments, color-coded) ████               │ 22px
│ DISTRIBUTION · READ-ONLY                       12 HARVESTERS │ 24px フッター
└──────────────────────────────────────────────────────────────┘
```

- 6列横並び：各列幅 約108px、列間スペース 8px、左右パディング 16px
- 視線の流れ：ヘッダー（左→右）→ 6列上から下（icon→数値→±）→ スタックバー（左→右）

### 2.3 BUILD ブロック（420 × 180）

```
┌──────────────────────────────────────────┐
│ ────── BUILD ──────                      │ 24px ヘッダー
├──────────────────────────────────────────┤
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐     │ 140px
│ │  ⚔   │ │  🛡   │ │  ⚒   │ │  ⌂   │     │
│ │ 兵舎 │ │ 要塞 │ │ 工房 │ │ 農村 │     │
│ │20W·10S│15W·48S│25W·5S │15W·5W │      │
│ └──────┘ └──────┘ └──────┘ └──────┘     │
└──────────────────────────────────────────┘
```

- カード4枚横並び：各カード 92×140、カード間 8px、左右パディング 16px
- 視線の流れ：ヘッダー → カード4枚（左→右）→ クリックで盤面配置モード

### 2.4 PLACE-ON-BOARD ヒント（160 × 180）

選択中の建物カードがあるときだけ「place on board」テキストを薄く表示し、未選択時は空。
盤面側（Board）への注意誘導用のサインポストとしてのみ機能する読み取り専用ラベル。

---

## 3. 色彩設計（カラー定義）

### 3.1 ベースカラー（ダークファンタジー基調）

| 定数名 | 16進数 | 用途 |
|---|---|---|
| `COLOR_BG` | `#1A1814` | フッター背景（最下層） |
| `COLOR_PANEL` | `#231F1B` | パネル・カード背景 |
| `COLOR_BORDER` | `#3C3628` | ボーダー・装飾線 |
| `COLOR_TEXT` | `#DCD2B9` | 標準テキスト（数値・名前） |
| `COLOR_TEXT_DIM` | `#8A8070` | サブテキスト（注釈・モード表示） |
| `COLOR_ACCENT_GOLD` | `#B49448` | 選択中ボーダー・装飾線 |

### 3.2 リソース・役割カラー（6列）

| 定数名 | 16進数 | 対象 |
|---|---|---|
| `COLOR_WOOD` | `#3F6932` | WOOD列・スタックバー WOOD セグメント |
| `COLOR_STONE` | `#5D5650` | STONE列・スタックバー STONE セグメント |
| `COLOR_SULFUR` | `#9A8A3C` | SULFUR列・スタックバー SULFUR セグメント |
| `COLOR_WHEAT` | `#A9924F` | WHEAT列・スタックバー WHEAT セグメント |
| `COLOR_BUILD` | `#375590` | BUILD（建設役割）列 |
| `COLOR_TRADE` | `#783C8C` | TRADE（交易役割）列 |

### 3.3 既存実装との関係（`EconMain.gd:421-428`）

既存の `row_colors` は彩度高めの暫定値。本企画書のパレットへ置換することで、ダークファンタジー基調と整合する（既存6色 → 上記6色へ1:1マッピング）。

---

## 4. UIコンポーネント一覧

### 4.1 HARVESTER ALLOCATION

| ID | 種類 | サイズ | テキスト/役割 |
|---|---|---|---|
| `alloc_root` | `PanelContainer` | 700×180 | ブロック全体（背景 `COLOR_PANEL`） |
| `alloc_header` | `HBoxContainer` | 700×24 | ヘッダー行 |
| `alloc_title` | `Label` | auto | "— HARVESTER ALLOCATION —"（大文字、装飾線あり） |
| `alloc_subtitle` | `Label` | auto | "total 12 · weights drive distribution"（薄テキスト） |
| `alloc_columns` | `HBoxContainer` | 700×110 | 6列横並びコンテナ |
| `col_<key>` | `VBoxContainer` ×6 | 108×110 | 各列（WOOD/STONE/SULFUR/WHEAT/BUILD/TRADE） |
| `col_<key>_icon` | `TextureRect` | 32×32 | リソースアイコン（中央寄せ） |
| `col_<key>_name` | `Label` | 108×16 | 大文字略称（"WOOD" 等） |
| `col_<key>_minus` | `Button` | 24×24 | "−" ボタン |
| `col_<key>_count` | `Label` | 36×24 | target_count 数値（中央寄せ） |
| `col_<key>_plus` | `Button` | 24×24 | "+" ボタン |
| `alloc_stack_bar` | `Control`（自前draw） | 668×22 | フッタースタックバー |
| `alloc_footer` | `HBoxContainer` | 700×24 | フッター行 |
| `alloc_mode_label` | `Label` | auto | "DISTRIBUTION · READ-ONLY"（薄テキスト） |
| `alloc_total_label` | `Label` | auto | "12 HARVESTERS"（実ハーベスター数） |

### 4.2 BUILD

| ID | 種類 | サイズ | テキスト/役割 |
|---|---|---|---|
| `build_root` | `PanelContainer` | 420×180 | ブロック全体（背景 `COLOR_PANEL`） |
| `build_header` | `Label` | 420×24 | "— BUILD —"（大文字、装飾線あり） |
| `build_cards` | `HBoxContainer` | 420×140 | カード4枚横並び |
| `card_barracks` | `Button`（背景カスタム） | 92×140 | 兵舎：⚔ / "20 W · 10 S" |
| `card_fortress` | `Button` | 92×140 | 要塞：🛡 / "48 S · 15 W" |
| `card_workshop` | `Button` | 92×140 | 工房：⚒ / "25 W · 5 S" |
| `card_village` | `Button` | 92×140 | 農村：⌂ / "15 W · 5 W" |

### 4.3 PLACE-ON-BOARD ヒント

| ID | 種類 | サイズ | テキスト/役割 |
|---|---|---|---|
| `place_hint_label` | `Label` | 160×180 | "place on board"（中央配置・`COLOR_TEXT_DIM`、選択時のみ表示） |

---

## 5. タイポグラフィ

| 用途 | サイズ | ウェイト | 大小 | 色 |
|---|---|---|---|---|
| ブロックタイトル（"— HARVESTER ALLOCATION —"） | 14px | Bold | 大文字 | `COLOR_TEXT` |
| ブロックサブタイトル（"total 12 ..."） | 11px | Regular | 小文字 | `COLOR_TEXT_DIM` |
| 列名（"WOOD"等） | 12px | Bold | 大文字略称 | `COLOR_TEXT` |
| 数値（target_count） | 16px | Bold | 数字 | `COLOR_TEXT` |
| ±ボタン文字 | 14px | Bold | "−" / "+" | `COLOR_TEXT` |
| フッターラベル（"DISTRIBUTION · READ-ONLY"） | 10px | Regular | 大文字 | `COLOR_TEXT_DIM` |
| ハーベスター総数（"12 HARVESTERS"） | 12px | Bold | 大文字 | `COLOR_TEXT` |
| カード名（"兵舎"等） | 13px | Bold | 日本語 | `COLOR_TEXT` |
| カードコスト（"20 W · 10 S"） | 11px | Regular | 数字+略号 | `COLOR_TEXT_DIM` |
| カードアイコン（⚔🛡⚒⌂） | 28px | - | 記号 | `COLOR_TEXT` |
| place-on-boardヒント | 11px | Regular | 小文字 | `COLOR_TEXT_DIM` |

装飾線（"—"）は前後に2文字分の `─` を配置し、`COLOR_BORDER` を視覚区切りとして利用。

---

## 6. インタラクション仕様

### 6.1 HARVESTER ALLOCATION

| 操作 | 動作 |
|---|---|
| `[-]` クリック | `target_count[key]` を 1 減らす（ただし合計が 1 を下回らない） |
| `[+]` クリック | `target_count[key]` を 1 増やす（合計が `alive + 6` を超えない） |
| ホバー（列） | 列背景がわずかに明るくなる（`COLOR_PANEL` → +5%輝度） |
| 数値表示 | `target_count[key]` の整数値（リアルタイム更新） |
| スタックバー | 押すたびに即時再描画（`queue_redraw`） |

ハーベスター実数とtarget_countの差分は **左ヘッダーのサブタイトルに表示しない**（既存実装の "予約" / "未割当" 表示は廃止し、視線の一本化を優先）。差分は `12 HARVESTERS` のフッター数値が、現実の値と一致しないことで暗黙に伝える。

### 6.2 BUILD

| 操作 | 動作 |
|---|---|
| カードクリック | `_place_mode` を該当タイプへ切替。選択カードに `COLOR_ACCENT_GOLD` のボーダー（2px）を表示。他カードは `COLOR_BORDER` で固定 |
| 同じカード再クリック | 選択解除（`_place_mode = NONE`）。ゴールドボーダー消える |
| ホバー | カード背景が +5%輝度。ボーダーは選択中のゴールドを上書きしない |
| 配置モード中 | 右端 `place_hint_label` が "place on board" を `COLOR_TEXT_DIM` で表示（フェードイン 150ms）|
| 配置完了 or キャンセル | 選択解除＆ヒント非表示 |

### 6.3 状態の可視化

| 状態 | 表現 |
|---|---|
| 建物カード未選択 | 全カードが `COLOR_PANEL` 背景＋`COLOR_BORDER`。右端ヒント非表示 |
| 建物カード選択中 | 選択カードのみ `COLOR_ACCENT_GOLD` 2px ボーダー。他は薄く見える（不透明度 80%）。右端ヒント表示 |
| ハーベスター未割当（target<alive） | スタックバー右端に「未塗り領域」が現れる（`COLOR_BORDER` で塗り） |
| ハーベスター予約（target>alive） | スタックバー上に半透明オーバーレイ（α=0.35）で予約分セグメントを描画 |

---

## 7. スタックバーの描画仕様

### 7.1 構造

スタックバーは **1本の水平バー（幅 668px × 高さ 22px）** で、6色のセグメントを横に並べて描く。全フッター下部に張り出し、視線で「全体の流し先比率」が一目で分かる。

### 7.2 セグメント幅の計算式

```
total_target = sum(target_count[key] for key in [WOOD, STONE, SULFUR, WHEAT, BUILD, TRADE])
alive        = _battle.player_harvesters.size()
scale        = max(alive, total_target, 1)

for each key in 6_keys:
    cnt        = target_count[key]
    seg_width  = BAR_W * (cnt / scale)         # 通常塗り
    alive_w    = BAR_W * (alive / scale)       # alive境界線位置
```

- `BAR_W = 668.0`（左右パディング16pxを差し引いた値）
- 各セグメントは **左から順番に** 描画（WOOD → STONE → SULFUR → WHEAT → BUILD → TRADE）
- セグメントが alive 境界をまたぐ場合：
  - alive 以内の部分 → 不透明（α=1.0）
  - alive 超過の部分 → 半透明（α=0.35、予約分の意味）
- alive < scale の場合：alive 位置に縦線（1px、`COLOR_TEXT_DIM`）を描いて「ここから先は予約」と示す
- バー外枠：`COLOR_BORDER` 1px、塗りつぶしなし

### 7.3 既存実装との差分

既存（`EconMain.gd:496-521`）は **6行に分かれた個別バー**。本企画では1本のスタックバーに統合し、視線の一本化を優先する。各列の数値（[-] N [+]）が"自分の塊"の細部、スタックバーが"全体配分"のサマリ、という役割分担になる。

---

## 8. UI基準6項目チェック

| # | 基準 | 評価 | 根拠 |
|---|---|---|---|
| 1 | **3秒ルール** | ◎ | フッター上部に「HARVESTER ALLOCATION」「BUILD」と装飾線付きヘッダー。3秒で「ここで人を配り、ここで建物を選ぶ」と分かる |
| 2 | **視線の一本化** | ◎ | 左：人の配り方、中：建てるもの、右：盤面への誘導サイン。3ブロックが左→右へ意思決定の順番に並び、視線が迷わない。スタックバーで全体配分を1本化 |
| 3 | **状態の可視化** | ◯ | 建物選択中は `COLOR_ACCENT_GOLD` のゴールドボーダー、未選択は暗パネル。target_countは数値で常時表示。alive/予約はスタックバーの透明度と縦線で表現 |
| 4 | **操作の最小化** | ◎ | 配分は ± の2ボタンのみ、建物は1クリック選択。配分プリセットボタンは別領域に逃がし、フッターには載せない |
| 5 | **配信映え** | ◎ | スタックバーが「今このプレイヤーは木3:石2:小麦4:建設1:交易2で回している」と一目で伝わる。視聴者が配分の偏りを瞬時に読める |
| 6 | **世界観の匂わせ** | ◎ | 暗背景（`#1A1814`）+ ゴールドアクセント（`#B49448`）+ 装飾線（"— —"）でダークファンタジー。記号アイコン（⚔🛡⚒⌂）と大文字英字でどこか無機質。説明的なツールチップは置かない |

総合：6項目すべて合格水準。

---

## 9. 実装上の注意

- 既存 `_create_harvester_alloc_ui()` / `_create_build_panel()` を **本企画書通りに置き換える**（新ファイル作成禁止・直接書き換え）
- 既存の「Mode: None」「Cancel」ボタンは廃止。同カード再クリックで解除する仕様に変更
- 既存の row_colors は本書セクション3.2の `COLOR_*` 定数へ差し替え
- スタックバーは1本化。既存の6行個別バーは削除
- カラー定義は EconMain.gd 冒頭に `const COLOR_BG := Color("#1A1814")` 形式でまとめて宣言する
- `_harvester_ui_update` の更新タイミングは現状維持（_processから毎フレーム）
- `_next_h_label`（次ハーベスター到着タイマー）は本フッターには載せず、ヘッダー側に移すかフローティングに退避する（フッターの3秒ルールを守るため）

---

## 10. 参照

- 既存実装：`scripts/econ_mvp/EconMain.gd:150-292, 404-580`
- 関連設計：`docs/design/econ_mvp_run_structure.md`
- 用語：`docs/design/glossary.md`
- 設計判断基準：`docs/design/design_principles.md`
