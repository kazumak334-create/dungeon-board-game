# UIデザイントークン定義

作成日: 2026-04-23
用途: Designer / Architect / Implementer が参照するUI統一の基盤SSOT

世界観方針: ダークファンタジー + 無機質（整いすぎている感）

---

## 注意事項

- 本ファイルは**scripts/ui/UIColors.gd**（autoload）を正のSSOTとして整理したドキュメント版
- 新規UI要素は本ファイル記載のトークンのみ使用可（ハードコード禁止）
- 該当トークンがない場合は Designer が本ファイルに追加提案してから使用
- UIColors.gd / UIFactory.gd で命名揺れあり（`COLOR_BG` / `BG_COLOR` / `BG` 等）。**新規実装は `UIColors.COLOR_*` を標準**とし、他は段階的にリファクタ対象

---

## 1. 色トークン（Color Tokens）

出典: `scripts/ui/UIColors.gd` L6-L20

### 基本色

| トークン名 | 値（RGBA） | 用途 |
|---|---|---|
| `COLOR_BG` | (0.08, 0.08, 0.12) | 画面背景 |
| `COLOR_PANEL` | (0.13, 0.13, 0.2) | パネル背景 |
| `COLOR_PANEL_DARK` | (0.05, 0.05, 0.08) | 暗めパネル（強調背景） |
| `COLOR_SIDE_PANEL` | (0.1, 0.1, 0.15) | サイドパネル背景 |
| `COLOR_BORDER` | (0.3, 0.3, 0.4) | パネル境界線 |
| `COLOR_OVERLAY` | (0, 0, 0, 0.4) | モーダル背景（半透明黒） |

### テキスト色

| トークン名 | 値（RGBA） | 用途 |
|---|---|---|
| `COLOR_TITLE` | (0.9, 0.85, 0.6) | 画面タイトル（琥珀） |
| `COLOR_SUBTITLE` | (0.7, 0.75, 0.85) | サブタイトル |
| `COLOR_TEXT` | (0.8, 0.8, 0.8) | 本文テキスト |
| `COLOR_DIM` | (0.5, 0.5, 0.5) | 無効化・補足テキスト |

### 状態色

| トークン名 | 値（RGBA） | 用途 |
|---|---|---|
| `COLOR_SELECTED` | (0.9, 0.75, 0.3) | 選択中（琥珀強調） |
| `COLOR_PICKED` | (0.4, 0.6, 0.4) | 購入/選択済み（緑） |
| `COLOR_GLOW` | (0.9, 0.75, 0.3, 0.3) | 選択中の光彩 |

### ボタン色

| トークン名 | 値（RGBA） | 用途 |
|---|---|---|
| `COLOR_BTN_BG` | (0.15, 0.15, 0.22) | ボタン通常背景 |
| `COLOR_BTN_HOVER` | (0.2, 0.2, 0.3) | ボタンホバー背景 |

### 意味色（UIFactory.gd 由来、段階的に UIColors.gd へ統合推奨）

| トークン名 | 値（RGBA） | 用途 | 出典 |
|---|---|---|---|
| `BENEFIT_COLOR` | (0.4, 0.85, 0.5) | 恩恵・回復（緑） | UIFactory.gd L11 |
| `DEMERIT_COLOR` | (0.9, 0.35, 0.35) | 損害・危険（赤） | UIFactory.gd L12 |
| `GOLD_COLOR` | (0.9, 0.8, 0.3) | ゴールド表示 | UIFactory.gd L13 |

---

## 2. 間隔・サイズトークン（Spacing & Size Tokens）

### タスクバー（出典: `scripts/CommonTaskbar.gd` L9-L13）

| トークン名 | 値 | 用途 |
|---|---|---|
| `TASKBAR_H` | 36px | タスクバー高さ |
| `BUTTON_SIZE` | 30px | タスクバー内ボタンサイズ |
| `BUTTON_GAP` | 6px | タスクバー内ボタン間隔 |

### カードスロット（出典: `scripts/CardSlot.gd` L6-L11）

| トークン名 | 値 | 用途 |
|---|---|---|
| `CARD_W` | 90px | カード幅 |
| `CARD_H` | 130px | カード高さ |
| `ILLUST_RATIO` | 0.6 | カード内イラスト部分の比率 |
| `COST_BADGE_SIZE` | 20px | コストバッジサイズ |
| `HOVER_OFFSET_Y` | -40px | ホバー時の上方向移動量 |

### パネル（出典: `scripts/UIFactory.gd` L50-L60 `create_panel`）

| パラメータ | 既定値 | 用途 |
|---|---|---|
| border_width | 1px | パネル境界線太さ |
| corner_radius | 6px | パネル角丸半径 |

### 戻るボタン（出典: `scripts/UIFactory.gd` L75-L76 `add_back_button`）

| パラメータ | 既定値 | 用途 |
|---|---|---|
| position | (40, 550) | 左下固定位置 |
| size | (180, 45) | ボタンサイズ |

---

## 3. フォントトークン（Font Tokens）

出典: `scripts/UIFactory.gd`

| トークン名 | サイズ | 用途 | 該当関数 |
|---|---|---|---|
| `FONT_TITLE` | 28px | 画面タイトル | `add_title()` L26 |
| `FONT_BUTTON` | 22px | 標準ボタン | `add_button()` L63 |
| `FONT_SUBTITLE` | 16px | サブタイトル | `add_subtitle()` L44 |
| `FONT_BACK_BUTTON` | 16px | 戻るボタン | `add_back_button()` L75 |

---

## 4. コンポーネントトークン（Component Tokens）

### ボタン（UIFactory.add_button 由来）

| 種別 | 背景色 | フォント | サイズ |
|---|---|---|---|
| プライマリボタン | デフォルト（Godot既定） | FONT_BUTTON (22) | 任意指定 |
| 戻るボタン | デフォルト | FONT_BACK_BUTTON (16) | (180, 45) |

### パネル（UIFactory.create_panel 由来）

| 種別 | 背景色 | 境界線 | 角丸 |
|---|---|---|---|
| 標準パネル | `PANEL_BG` (0.1, 0.1, 0.15) | `PANEL_BORDER` (0.25, 0.25, 0.35) / 1px | 6px |

---

## 5. 使用ルール（Designer / Architect / Implementer 向け）

### Designer
- 企画書でトークン名を参照（具体値でなく `COLOR_SELECTED` 等で指示）
- 不足トークンは「新規提案」として明示し、Architect引き継ぎメモに記載

### Architect
- 要件定義書で「コンポーネント名」→「トークン名」→「UIColors.gd定数名」の参照チェーンを明記

### Implementer
- UIColors.COLOR_* / UIFactory.* 定数を使う
- 新規の色・サイズをハードコードしない
- ui_tokens.md にないトークンを使う必要がある場合は、Designer に追加提案を依頼

---

## 6. 既知の命名揺れ（段階的リファクタ対象）

- `UIFactory.BG_COLOR` (0.08, 0.08, 0.12) と `UIColors.COLOR_BG` (0.08, 0.08, 0.12) は同値 → UIColors統合推奨
- `UIColors.BG` / `UIColors.COLOR_BG` が重複定義（InitialCardPick.gd用の別名） → 段階的統一
- `UIFactory.TITLE_COLOR` と `UIColors.COLOR_TITLE` は同値 → UIColors統合推奨

---

## 出典まとめ

- `scripts/ui/UIColors.gd` - 色定義SSOT（L6-L20 既存 / L22-L31 新規別名）
- `scripts/UIFactory.gd` - コンポーネント生成・意味色・フォントサイズ定義（L5-L15, L26, L44, L50-L60, L63, L75）
- `scripts/CommonTaskbar.gd` - タスクバーサイズ定数（L9-L13）
- `scripts/CardSlot.gd` - カードスロットサイズ定数（L6-L11）

※他にも `scripts/GameUI.gd` / `scripts/Shop.gd` / `scripts/DeckPrepSidebar.gd` に固有色・サイズ定数があるが、Phase 2時点ではUIColors.gd統合推奨のためここには記載せず。必要時に追加。
