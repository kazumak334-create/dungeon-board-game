# 通貨システム要件定義書

## 1. 概要

### 1.1 目的
複数通貨（銅貨・銀貨・金貨）を疎結合で管理するシステムを構築する。
他システムはレートの詳細を知らずに通貨操作を行える。

### 1.2 設計方針
- 単一責任: CurrencyManager がレート計算と変換を一元管理
- 疎結合: 他システムは CurrencyManager の公開 API のみ使用
- 設定駆動: レートは外部ファイルで定義し、コード変更なしで調整可能
- 既存互換: GameSession.gold は銅貨単位の総量として継続使用

---

## 2. 通貨定義

### 2.1 通貨種類

| 通貨名 | 内部ID | 表示名 | 説明 |
|--------|--------|--------|------|
| 銅貨 | copper | 銅貨 | 基本単位 |
| 銀貨 | silver | 銀貨 | 中間単位 |
| 金貨 | gold | 金貨 | 高額単位 |

### 2.2 デフォルトレート

| 変換元 | 変換先 | レート |
|--------|--------|--------|
| 銅貨 10枚 | 銀貨 1枚 | 10:1 |
| 銅貨 100枚 | 金貨 1枚 | 100:1 |
| 銀貨 10枚 | 金貨 1枚 | 10:1（派生） |

---

## 3. 設定ファイル仕様

### 3.1 ファイルパス
`data/currency_config.json`

### 3.2 スキーマ

```json
{
  "currencies": [
    {
      "id": "copper",
      "display_name": "銅貨",
      "base_value": 1
    },
    {
      "id": "silver",
      "display_name": "銀貨",
      "base_value": 10
    },
    {
      "id": "gold",
      "display_name": "金貨",
      "base_value": 100
    }
  ],
  "default_display": "copper"
}
```

### 3.3 フィールド説明

| フィールド | 型 | 必須 | 説明 |
|------------|------|------|------|
| currencies | array | Yes | 通貨定義の配列 |
| currencies[].id | string | Yes | 内部識別子（一意） |
| currencies[].display_name | string | Yes | UI表示用の名前 |
| currencies[].base_value | int | Yes | 銅貨換算での価値（銅貨=1） |
| default_display | string | No | デフォルト表示通貨（省略時: copper） |

### 3.4 レート変更例
銀貨を銅貨20枚相当に変更する場合:
```json
{
  "id": "silver",
  "display_name": "銀貨",
  "base_value": 20
}
```

---

## 4. CurrencyManager 仕様

### 4.1 基本情報
- ファイルパス: `scripts/CurrencyManager.gd`
- 種別: Autoload（シングルトン）
- 登録名: CurrencyManager

### 4.2 公開 API

#### 4.2.1 残高操作

```gdscript
# 残高取得（銅貨単位）
func get_balance() -> int

# 残高取得（指定通貨単位）
func get_balance_as(currency_id: String) -> int

# 加算（銅貨単位）
func add(amount: int) -> void

# 加算（指定通貨単位）
func add_currency(currency_id: String, amount: int) -> void

# 減算（銅貨単位）- 残高不足時は false を返す
func subtract(amount: int) -> bool

# 減算（指定通貨単位）- 残高不足時は false を返す
func subtract_currency(currency_id: String, amount: int) -> bool

# 支払い可能か確認（銅貨単位）
func can_afford(amount: int) -> bool

# 支払い可能か確認（指定通貨単位）
func can_afford_currency(currency_id: String, amount: int) -> bool
```

#### 4.2.2 変換・表示

```gdscript
# 銅貨から指定通貨への変換
func to_currency(copper_amount: int, currency_id: String) -> int

# 指定通貨から銅貨への変換
func to_copper(amount: int, currency_id: String) -> int

# 表示用文字列取得（例: "1金貨 2銀貨 3銅貨"）
func format_display(copper_amount: int) -> String

# 単一通貨での表示（例: "123銅貨"）
func format_single(copper_amount: int, currency_id: String) -> String
```

#### 4.2.3 設定取得

```gdscript
# 通貨IDの一覧取得
func get_currency_ids() -> Array

# 通貨の表示名取得
func get_display_name(currency_id: String) -> String

# 通貨の base_value 取得
func get_base_value(currency_id: String) -> int
```

### 4.3 シグナル

```gdscript
# 残高変動時に発火
signal balance_changed(new_balance: int, delta: int)
```

### 4.4 内部実装要件

- 設定ファイルは `_ready()` で1回のみ読み込む
- 読み込み失敗時はデフォルト値を使用（エラーログ出力）
- GameSession.gold への読み書きは CurrencyManager 経由で行う

---

## 5. 既存システム移行

### 5.1 対象ファイル

| ファイル | 現状 | 移行後 |
|----------|------|--------|
| GameSession.gd | `var gold: int = 0` | 変更なし（CurrencyManager が参照） |
| Shop.gd | `GameSession.gold` 直接操作 | `CurrencyManager.add()` / `subtract()` |
| RestScreenShop.gd | `GameSession.gold` 直接操作 | `CurrencyManager.add()` / `subtract()` |

### 5.2 互換性維持

- `GameSession.gold` は銅貨単位の総量として保持
- 既存の `gold` 参照は段階的に CurrencyManager 経由へ移行
- 移行期間中は両方式が混在可能（値は同一を参照）

---

## 6. 受け入れ基準

### 6.1 機能要件

- [ ] currency_config.json からレートを読み込める
- [ ] 3種通貨の加減算が正しく動作する
- [ ] レート変更がコード変更なしで反映される
- [ ] 残高不足時の減算が false を返す
- [ ] 既存の gold 操作と互換性がある

### 6.2 非機能要件

- [ ] 設定ファイル読み込み失敗時にクラッシュしない
- [ ] 不正な currency_id 指定時にエラーログを出力する
- [ ] 0以下の amount 指定時に適切に処理する

---

## 7. 実装優先度

1. currency_config.json 作成
2. CurrencyManager.gd 基本実装（add/subtract/get_balance）
3. Autoload 登録
4. Shop.gd / RestScreenShop.gd 移行
5. 表示系 API 実装（format_display 等）

---

## 8. 備考

- 通貨の自動両替（銅貨10枚→銀貨1枚）は本要件に含まない
- UI表示形式（アイコン等）は別途 UI 要件として定義
- セーブ/ロード時の通貨保存形式は GameSession のセーブ仕様に従う
