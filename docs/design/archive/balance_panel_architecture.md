STATUS: 廃止（→ docs/GAME_DESIGN_V0_2_MVP.md）
最終更新: 2026-05-04

# バランスパネル技術設計書

作成日: 2026-04-13

---

## 1. 概要

DeckPrep左サイドバーに突・守・崩バランスの可視化パネルを追加する。
盤面上のユニット配置が変わるたびにリアルタイム更新する。

---

## 2. 配置位置

### 2-1. サイドバーレイアウト分析

```
SIDEBAR (x=5, y=40, w=200, h=675)
├── ヘッダー "ステータス"     y=55,  h=24
├── グループ1: クラス基本情報  y=79,  h=90  (5項目 x 18px)
├── 区切り線 + 余白           y=169, h=17  (4+1+12)
├── グループ2: デッキ情報      y=186, h=90  (5項目 x 18px)
├── 区切り線 + 余白           y=276, h=17
├── グループ3: 所持情報        y=293, h=54  (3項目 x 18px)
├── [空き]                    y=347, h=368 ← ここにバランスパネル
└── SIDEBAR下端               y=715
```

### 2-2. バランスパネル配置

```
バランスパネル (x=20, y=370, w=170, h=150)
├── ヘッダー "バランス"        y=370, h=24
├── 突バー + 枚数              y=398, h=20
├── 守バー + 枚数              y=422, h=20
├── 崩バー + 枚数              y=446, h=20
├── 区切り線                   y=470, h=1
├── 推奨ヘッダー "推奨(ActN)"  y=478, h=20
├── 突推奨                     y=502, h=18
├── 守推奨                     y=520, h=18
└── 崩推奨                     y=538, h=18
```

残り高さ: 715 - 538 = 177px（余裕あり）

---

## 3. 計算ロジック

### 3-1. ユニット分類アルゴリズム

cards.jsonの各ユニットを以下の優先順で分類する（ハードコードしない）:

```
func classify_unit(unit_data: Dictionary) -> String:
    var traits = unit_data.get("traits", [])
    
    # 優先1: traits による分類
    if "pierce" in traits or "flying" in traits or "mana_drain" in traits:
        return "break"   # 崩
    if "swarm" in traits:
        return "thrust"  # 突
    if "indomitable" in traits:
        return "guard"   # 守（不撓不屈は前線維持）
    
    # 優先2: cards.json に category フィールドがあればそれを使用
    var category = unit_data.get("category", "")
    if category != "":
        return category
    
    # 優先3: ステータス比率による自動分類
    var hp = unit_data.get("hp", 1)
    var atk = unit_data.get("atk", 0)
    var ratio = float(atk) / max(1.0, float(hp))
    
    if ratio >= 0.15:
        return "thrust"  # 突（高ATK比率）
    elif hp >= 40:
        return "guard"   # 守（高HP）
    else:
        return "break"   # 崩（それ以外＝特殊型）
```

### 3-2. カウント対象

- **盤面上のユニットのみ**: `placement_config[i].col >= 0` のもの
- **呪文は除外**: CardDB.UNITS にないカードはスキップ
- **手持ち・呪文デッキは除外**: col = -1 のカードは対象外

### 3-3. 推奨値テーブル

GameSession.current_act から推奨値を取得:

```gdscript
const RECOMMENDED_BALANCE = {
    1: {"thrust": [4, 5], "guard": [2, 3], "break": [2, 3]},
    2: {"thrust": [3, 4], "guard": [3, 4], "break": [2, 3]},
    3: {"thrust": [2, 4], "guard": [2, 4], "break": [2, 4]},
}
```

Boss戦の推奨は Act 情報のみでは判定不可のため、Phase 1 では Act 別推奨のみとする。

---

## 4. 実装方法

### 4-1. 変更ファイル一覧

| ファイル | 変更内容 | 変更量 |
|---------|---------|--------|
| scripts/DeckPrepSidebar.gd | バランスパネル構築・更新メソッド追加 | +80行程度 |
| scripts/DeckPrep.gd | update_balance() 呼び出し追加 | +5行程度 |

### 4-2. DeckPrepSidebar.gd への追加

```gdscript
# 追加するメンバ変数
var _balance_bars: Dictionary = {}  # {"thrust": ColorRect, "guard": ColorRect, "break": ColorRect}
var _balance_labels: Dictionary = {} # {"thrust": Label, "guard": Label, "break": Label}
var _recommend_labels: Dictionary = {} # {"thrust": Label, "guard": Label, "break": Label}
var _recommend_header: Label = null

# 追加する定数
const BALANCE_PANEL_Y = 370  # ステータス下の空きスペース
const BAR_MAX_W = 130        # バー最大幅（SIDEBAR_W - 余白）
const BAR_H = 12             # バー高さ
const BALANCE_COLORS = {
    "thrust": Color(0.9, 0.3, 0.3),  # 赤
    "guard":  Color(0.3, 0.5, 0.9),  # 青
    "break":  Color(0.7, 0.3, 0.8),  # 紫
}
const BALANCE_NAMES = {
    "thrust": "突",
    "guard":  "守",
    "break":  "崩",
}
const RECOMMENDED_BALANCE = {
    1: {"thrust": [4, 5], "guard": [2, 3], "break": [2, 3]},
    2: {"thrust": [3, 4], "guard": [3, 4], "break": [2, 3]},
    3: {"thrust": [2, 4], "guard": [2, 4], "break": [2, 4]},
}

# build_sidebar() の末尾で呼び出す
func _build_balance_panel() -> void:
    # ヘッダー、バー3本、推奨値表示を構築
    pass  # 実装時に詳細化

# DeckPrep.gd から呼び出される更新メソッド
func update_balance() -> void:
    # 1. 盤面ユニットをカウント
    # 2. 各ユニットを classify_unit() で分類
    # 3. バー幅とラベルを更新
    # 4. 推奨値との比較マーク表示
    pass
```

### 4-3. DeckPrep.gd への追加

```gdscript
# _update_board_mana() と同じ呼び出しパターン
func _update_balance() -> void:
    _sidebar.update_balance()

# 以下の箇所で _update_balance() を呼び出す:
# 1. _build_ui() 末尾（初期表示）
# 2. on_cards_populated コールバック内（配置変更時）
```

### 4-4. 更新タイミング

既存の `on_cards_populated` コールバックに追加:

```gdscript
_board.on_cards_populated = func():
    _update_board_mana()
    _update_balance()  # ← 追加
```

---

## 5. 後方互換性

### 5-1. 影響範囲

- DeckPrepSidebar.gd: 新メソッド・変数の追加のみ。既存メソッドの変更なし
- DeckPrep.gd: `_update_balance()` 追加 + `on_cards_populated` に1行追加のみ
- CardDB: 参照のみ。変更なし
- GameSession: `current_act` 参照のみ。変更なし

### 5-2. フォールバック

- `current_act` が未定義の場合: デフォルト1を使用
- ユニットにtraitsがない場合: ステータス比率で分類
- 盤面にユニットが0枚の場合: バー幅0、ラベル「0枚」表示

### 5-3. テスト観点

- 構文チェック: `bash check_syntax.sh` で確認
- 視覚確認: ユーザーによるスクリーンショット確認（CLAUDE.md準拠）

---

## 6. 将来拡張

1. **cards.json に category フィールド追加**: 手動分類でオーバーライド可能に
2. **呪文の分類追加**: 攻撃呪文→突、防御呪文→守、デバフ呪文→崩
3. **Boss推奨値**: Boss戦フラグ追加時に対応
4. **ツールチップ**: バーホバーで分類ユニット名一覧表示
