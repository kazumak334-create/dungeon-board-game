# タイトル画面 要件定義書

## 1. 概要

タイトル画面のUI/UXを企画書(title_screen_design.md)に基づいてリニューアルする。背景画像+オーバーレイ、ロゴ画像(代替Label)、サブタイトル追加、クラスカードの情報整理、出発ボタンのスタイル改善、フェードインアニメーション、色定数の共通化を行う。

## 2. 変更対象ファイル一覧

| ファイル | 操作 | 現在行数 | 追加後予測 |
|---|---|---|---|
| `scripts/ui/UIColors.gd` | **新規作成** | 0 | 約30行 |
| `scripts/Title.gd` | **大幅修正** | 202行 | 約350行 |
| `scripts/DeckPrep.gd` | **軽微修正**（色定数の参照先変更） | 既存 | 変更なし(行数同等) |
| `scenes/Title.tscn` | **変更なし** | 13行 | 13行 |

### ファイルサイズ判定

Title.gd: 現在202行 → 追加後約350行予測。500行未満のため分割不要。ただし`_build_ui()`が巨大化する可能性があるため、背景構築・タイトル構築・カード構築・ボタン構築をヘルパー関数に分離することを要件に含める。

### .tscn化判断

MEMORY.mdの方針「Phase 5以降に.tscn化検討」に従い、コード生成を継続する。Title.tscnは現状の空Controlノードのまま変更しない。

## 3. データ構造

### 3.1 UIColors.gd（新規作成）

```
ファイルパス: scripts/ui/UIColors.gd
class_name: UIColors
```

DeckPrep.gdの既存色定数8個 + Title画面で追加する4色を定義する。

| 定数名 | 値 | 出典 |
|---|---|---|
| COLOR_BG | Color(0.08, 0.08, 0.12) | DeckPrep既存 |
| COLOR_SIDE_PANEL | Color(0.07, 0.07, 0.11) | DeckPrep既存 |
| COLOR_PANEL | Color(0.13, 0.13, 0.2) | DeckPrep既存 |
| COLOR_PANEL_DARK | Color(0.07, 0.07, 0.11) | 企画書(= SIDE_PANEL同値) |
| COLOR_BORDER | Color(0.3, 0.3, 0.4) | DeckPrep既存 |
| COLOR_TITLE | Color(0.9, 0.85, 0.6) | DeckPrep既存 |
| COLOR_TEXT | Color(0.8, 0.8, 0.8) | DeckPrep既存 |
| COLOR_SELECTED | Color(0.9, 0.75, 0.3) | DeckPrep既存 |
| COLOR_DIM | Color(0.5, 0.5, 0.5) | DeckPrep既存 |
| COLOR_SUBTITLE | Color(0.6, 0.55, 0.4) | 企画書新規 |
| COLOR_BTN_BG | Color(0.18, 0.16, 0.1) | 企画書新規 |
| COLOR_BTN_HOVER | Color(0.25, 0.22, 0.12) | 企画書新規 |
| COLOR_OVERLAY | Color(0, 0, 0, 0.4) | 企画書新規 |

### 3.2 Title.gd 変数追加

```gdscript
# 既存変数(維持)
var _taskbar: RefCounted
var _selected_class_id: String = ""
var _class_buttons: Dictionary = {}
var _description_label: Label
var _skill_label: Label
var _start_button: Button

# 追加変数
var _is_first_show: bool = true  # アニメーション制御用
```

## 4. 実装詳細

### 4.1 実装手順（順序・依存関係）

```
Step 1: scripts/ui/UIColors.gd 新規作成
  ↓
Step 2: scripts/DeckPrep.gd の色定数を UIColors 参照に変更
  ↓ (Step 1に依存)
Step 3: scripts/Title.gd リニューアル
  ↓ (Step 1に依存)
Step 4: 構文チェック (bash check_syntax.sh)
```

### 4.2 Step 1: UIColors.gd 新規作成

- パス: `scripts/ui/UIColors.gd`
- class_name UIColors を宣言
- 上記3.1の定数をすべて `const` で定義
- extends RefCounted（インスタンス化不要、定数参照のみ）

### 4.3 Step 2: DeckPrep.gd 色定数の参照先変更

- DeckPrep.gd 12-19行目の `const COLOR_*` 8行を削除
- 各参照箇所を `UIColors.COLOR_*` に置換
- DeckPrepInfo.gdは独自のローカル色を使用しているため変更しない（企画書の範囲外）

### 4.4 Step 3: Title.gd リニューアル

`_build_ui()` を以下のヘルパー関数に分割する。

#### 4.4.1 _build_background() -> void

| 処理 | 詳細 |
|---|---|
| bg_color | ColorRect, UIColors.COLOR_BG, PRESET_FULL_RECT |
| bg_image | TextureRect, パス `res://assets/ui/title_bg.png`, stretch_mode=KEEP_ASPECT_COVERED. ファイル存在チェック: `FileAccess.file_exists()` で判定、なければスキップ |
| bg_overlay | ColorRect, UIColors.COLOR_OVERLAY, PRESET_FULL_RECT |

#### 4.4.2 _build_title_area() -> void

| 処理 | 詳細 |
|---|---|
| title_logo | TextureRect, パス `res://assets/ui/title_logo.png`, 位置(340,60), サイズ600x120. ファイル存在チェックで判定 |
| title_label (代替) | ロゴ画像がない場合のみ生成. Label, 位置(0,70), サイズ1280x80, フォント `res://assets/fonts/trajan.ttf` 42pt, UIColors.COLOR_TITLE, 中央揃え, テキスト "DUNGEON BOARD GAME" |
| subtitle_label | Label, 位置(0,185), サイズ1280x30, フォント `res://assets/fonts/PixelMplus10-Regular.ttf` 16pt, UIColors.COLOR_SUBTITLE, 中央揃え, テキスト "盤面を設計し、観戦せよ" |

#### 4.4.3 _build_class_cards() -> void

| 処理 | 詳細 |
|---|---|
| class_container | HBoxContainer, 位置(165,240), サイズ950x220, separation=30 |
| 各カード | PanelContainer 280x220, corner_radius=8 |

各カード内部構成:
1. VBoxContainer (separation=10)
2. クラスアイコン: TextureRect 80x80 中央揃え. パス `res://assets/ui/class_icon_{class_id}.png`. なければColorRect(0.12, 0.12, 0.18) 80x80
3. クラス名: Label, trajan.ttf 20pt, UIColors.COLOR_TITLE, 中央揃え
4. セパレータ: HSeparator, Color(0.25, 0.28, 0.35)
5. 一行説明: Label, 14pt, UIColors.COLOR_TEXT, 中央揃え, autowrap, max_lines_visible=2

**削除対象**: マナ上限・リジェネ表示のLabel（現在126-130行目）

ホバー処理:
- `mouse_entered` シグナル: パネル背景を Color(0.16, 0.16, 0.24) に変更
- `mouse_exited` シグナル: パネル背景を UIColors.COLOR_PANEL に戻す

#### 4.4.4 _build_description_area() -> void

| 処理 | 詳細 |
|---|---|
| desc_panel | PanelContainer, 位置(290,475), サイズ700x60, bg=UIColors.COLOR_PANEL_DARK, border=UIColors.COLOR_BORDER, border_width=1, corner_radius=6 |
| desc_label | Label, 14pt, UIColors.COLOR_TEXT, 中央揃え, autowrap |
| skill_label | Label, 13pt, Color(0.6, 0.75, 0.9), パッシブスキル表示 |

#### 4.4.5 _build_start_button() -> void

| 処理 | 詳細 |
|---|---|
| start_button | Button, 位置(465,555), サイズ350x60, テキスト "出  発", trajan.ttf 26pt |
| normal StyleBoxFlat | bg=UIColors.COLOR_BTN_BG, border=UIColors.COLOR_SELECTED, border_width=2, corner_radius=6 |
| hover StyleBoxFlat | bg=UIColors.COLOR_BTN_HOVER, border=UIColors.COLOR_SELECTED, border_width=3, corner_radius=6 |
| disabled状態 | クラス未選択時: `_start_button.disabled = true`, `_start_button.modulate = Color(0.5, 0.5, 0.5)` |

#### 4.4.6 _build_footer() -> void

| 処理 | 詳細 |
|---|---|
| version_label | Label, 位置(20,690), サイズ200x25, "ver 0.x.x", 12pt, UIColors.COLOR_DIM |
| dev_button | Button, 位置(1080,685), サイズ180x30, "開発者モード", 12pt, modulate=Color(1,1,1,0.4). pressed → _on_dev_mode_pressed |
| test_button | **削除**（企画書: タイトル画面から除去） |

#### 4.4.7 _select_class(class_id) 変更点

- 既存ロジック維持（枠線切り替え・説明表示）
- 追加: 選択時に `_start_button.disabled = false`, `_start_button.modulate = Color(1,1,1)`
- 変更: 非選択カードのクラス名色を UIColors.COLOR_DIM に、選択カードを UIColors.COLOR_TITLE に

#### 4.4.8 _play_intro_animation() -> void

`_is_first_show == true` の場合のみ実行。実行後 `_is_first_show = false`。

| 対象 | 初期状態 | Tween |
|---|---|---|
| タイトルロゴ/ラベル | modulate.a = 0 | alpha 0→1, duration=0.8秒 |
| サブタイトル | modulate.a = 0 | alpha 0→1, duration=0.5秒, delay=0.5秒 |
| class_container | modulate.a = 0, position.y += 30 | alpha 0→1 + position.y -30, duration=0.4秒, delay=0.8秒 |
| start_button | modulate.a = 0 | alpha 0→1, duration=0.3秒, delay=1.2秒 |

Tween生成: `create_tween()` を使用。`set_parallel(true)` で並列実行。各プロパティに `set_delay()` で遅延を設定。

#### 4.4.9 _ready() 変更

```
_build_ui() の後:
1. デフォルトクラス選択（既存ロジック維持）
2. _play_intro_animation() を呼び出し
```

#### 4.4.10 _on_start_pressed() 変更

- 既存ロジック維持。disabled状態はButton自体が制御するため `_selected_class_id == ""` チェックは残す

#### 4.4.11 _on_run_tests() 削除

テスト実行ボタン削除に伴い関数ごと削除（現在190-201行目）

## 5. 必須アセットリスト

| ファイル | パス | 存在 | 代替手段 |
|---|---|---|---|
| trajan.ttf | `res://assets/fonts/trajan.ttf` | **存在する** | - |
| PixelMplus10-Regular.ttf | `res://assets/fonts/PixelMplus10-Regular.ttf` | **存在する** | - |
| title_bg.png | `res://assets/ui/title_bg.png` | **存在しない** | COLOR_BGフォールバック |
| title_logo.png | `res://assets/ui/title_logo.png` | **存在しない** | Label 42pt trajan.ttf代替 |
| vignette.png | `res://assets/ui/vignette.png` | **存在しない** | スキップ（オプション機能） |
| class_icon_*.png | `res://assets/ui/class_icon_*.png` | **存在しない** | ColorRect(0.12, 0.12, 0.18)プレースホルダ |

**全画像アセットは「なくても動く」実装とする。** `assets/ui/` ディレクトリが存在しないため、実装時にディレクトリ作成は不要（FileAccess.file_existsで判定しスキップ）。

## 6. 色定数共通化の方法

1. `scripts/ui/UIColors.gd` を新規作成し `class_name UIColors` を宣言
2. DeckPrep.gdの8色定数 + Title用4色を定義
3. DeckPrep.gdから色定数定義を削除し、`UIColors.COLOR_*` で参照
4. Title.gdも `UIColors.COLOR_*` で参照
5. 将来的に他画面(MaterialSelect等)も段階的に移行可能だが、今回のスコープはDeckPrep.gdとTitle.gdのみ

## 7. 制約・注意事項

- GAME_DESIGN.mdとの整合性: クラス選択→MATERIAL_SELECT遷移の既存フローを維持。変更なし
- `_on_dev_mode_pressed` は維持（開発者モード機能は削除しない、配置変更のみ）
- `_on_run_tests` は削除（テスト実行ボタンをタイトル画面から除去）
- CardDB.CLASSES のデータ構造参照は変更なし
- CommonTaskbar の attach は変更なし
- デフォルトクラス選択（_readyで最初のクラスを選択）の挙動は維持
- フォント読み込み: `load("res://assets/fonts/trajan.ttf")` で動的ロード。preload不可の場合はloadを使用

## 8. テスト項目（動作確認チェックリスト）

### 構文チェック
- [ ] `bash check_syntax.sh` がエラー0件

### 画面表示
- [ ] 背景がCOLOR_BGで表示される（画像なしフォールバック）
- [ ] タイトル "DUNGEON BOARD GAME" が trajan.ttf 42pt で中央表示
- [ ] サブタイトル "盤面を設計し、観戦せよ" が表示
- [ ] クラスカードが3枚横並び（280x220, 間隔30px）
- [ ] クラスカードにマナ情報が表示されていない
- [ ] クラスカードにプレースホルダ(暗いColorRect)が表示
- [ ] 説明エリアがパネル内にまとまっている
- [ ] 出発ボタンが350x60でカスタムスタイル適用
- [ ] バージョン表記が左下に表示
- [ ] 開発者モードボタンが右下に小さく半透明表示
- [ ] テスト実行ボタンが存在しない

### インタラクション
- [ ] クラスカードクリックで金色枠に変化
- [ ] 非選択カードは通常枠線
- [ ] クラス選択で説明エリアに説明+スキル表示
- [ ] カードホバーでパネル背景が明るくなる
- [ ] 出発ボタンホバーでスタイル変化
- [ ] クラス未選択時、出発ボタンがdisabled+半透明
- [ ] クラス選択後、出発ボタンが有効化
- [ ] 出発ボタンクリックでMATERIAL_SELECT画面に遷移
- [ ] 開発者モードボタンクリックでBATTLE画面に遷移

### アニメーション
- [ ] 初回表示時にフェードイン演出が再生される
- [ ] ロゴ→サブタイトル→カード群→ボタンの順にフェードイン
- [ ] 画面戻り時（2回目表示）にアニメーションなしで即表示

### 色定数共通化
- [ ] DeckPrep画面の色が変更前と同一（UIColors参照で劣化なし）
- [ ] Title画面の色が企画書の値と一致
