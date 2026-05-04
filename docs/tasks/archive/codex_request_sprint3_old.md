# Sprint 3 実装リクエスト：人口システム

**作成日**: 2026-05-03  
**対象**: Econ MVP V0.2  
**Sprint**: 3 / 8

---

## 実装概要

Sprint 3 では、人口をリアルタイムに増減する都市ステータスとして実装する。

**核となる仕様:**
- 人口を内部的に `float` で小数管理
- 内部人口 1 = 1k人として UI 表示
- 初期人口: 50、人口上限: 100、人口下限: 10
- 人口増減は割合ベース（固定値ではない）
- 満足度段階による人口増加率・減少率
- 5秒ごとの食料値消費と食料不足カウント
- 人口増加確定単位: 10
- 即時人口減少処理: `apply_population_loss(amount)`

---

## 根拠ドキュメント

以下のドキュメントを参照して実装してください：

1. **企画書（確定版）**
   - G:\マイドライブ\ざったなファイル\ゲームアイデア系\v0.2_MVP用\sprint3_population_system_final.md

2. **要件定義書**
   - `docs/requirements/req_econ_population_sprint3.md`

**重要**: 企画書 Final 版が Single Source of Truth です。

---

## 実装対象ファイル

主要変更対象:
- `scripts/econ_mvp/EconEconomy.gd` - 都市ステータス基盤（Sprint 1 の拡張）
  - 既存: `population_float`, `satisfaction_value`, `satisfaction_slope` など
  - 追加: 人口増減処理、食料値消費処理、growth_blocked 管理

---

## 実装内容

### 1. 人口フィールド設定
- `population_float: float = 50.0` - 初期人口 50（表示: 50k人）
- `population_cap: float = 100.0` - 初期人口上限 100（表示: 100k人）
- `population_min: float = 10.0` - 人口下限 10（表示: 10k人）
- `growth_blocked: bool = false` - 人口増加停止フラグ

### 2. リアルタイム人口増減
- `_process(delta)` で毎フレーム人口を増減させる
- 人口増加率・減少率は満足度段階から取得
- 満足度段階表:
  | 段階 | 増加率 | 減少率 |
  |------|--------|--------|
  | 衰退 | 0%/秒 | -0.12%/秒 |
  | 不満 | 0%/秒 | -0.04%/秒 |
  | 安定 | +0.02%/秒 | 0%/秒 |
  | 満足 | +0.04%/秒 | 0%/秒 |
  | 繁栄 | +0.06%/秒 | 0%/秒 |

### 3. 食料値消費処理
- 5 秒ごとに `_consume_food_maintenance()` を呼び出し
- 必要食料値: `ceil(現在人口 / 50)` 最小値 1
- 食料値が足りる場合: 食料値を消費し、食料不足カウント -1（最小 0）
- 食料値が足りない場合: 残り食料値をすべて消費し、食料不足カウント +1

### 4. 人口増加確定処理
- 人口増加確定単位: 10
- 次の確定人口: `ceil(現在人口 / 10) × 10`
- 人口増加必要食料値: `ceil(次の確定人口 / 50)` 最小値 1
- 繁栄時: `max(1, ceil(次の確定人口 / 50) - 1)`
- 食料値が足りた場合: 確定人口に到達
- 食料値が足りない場合: 確定人口直前で停止（e.g., 159.99）し `growth_blocked = true`

### 5. 即時人口減少処理
```gdscript
func apply_population_loss(amount: float) -> void:
    population_float = max(population_min, population_float - amount)
```

### 6. 表示人口計算
- `get_display_population() -> int`: `max(1, floor(population_float))` を返す

---

## 完了条件

要件定義書 `req_econ_population_sprint3.md` のチェックリストをすべて満たすこと：

### 人口フィールド
- [ ] `population_float` が小数で保持されている
- [ ] `population_cap` が 100 で初期化されている
- [ ] `population_min` が 10 で初期化されている
- [ ] `growth_blocked` が管理されている

### リアルタイム増減
- [ ] `_process(delta)` で毎フレーム人口が増減する
- [ ] 人口増加率・減少率が満足度段階から取得される
- [ ] 人口変化量 = 増加要因 - 減少要因で計算されている
- [ ] 人口上限を超えない
- [ ] 人口下限を下回らない

### 食料値消費
- [ ] 5 秒ごとに食料値消費処理が実行される
- [ ] 必要食料値が `ceil(現在人口 / 50)` で計算される
- [ ] 食料不足カウントが管理されている

### 人口増加確定
- [ ] 人口増加確定単位が 10 で機能している
- [ ] 次の確定人口が `ceil(現在人口 / 10) × 10` で計算される
- [ ] 人口増加必要食料値が計算される
- [ ] 繁栄時に必要食料値が -1 される
- [ ] 食料値不足時に `growth_blocked = true` になる

### 即時人口減少
- [ ] `apply_population_loss(amount)` が実装されている

### 表示
- [ ] `get_display_population()` が `floor(population_float)` を返す

### テスト
- [ ] `bash check_syntax.sh` エラー 0 件
- [ ] ゲーム起動時に人口システムが正常に初期化される

---

## テスト方針

1. **構文チェック**: 1 ファイル編集ごとに `bash check_syntax.sh` を実行
2. **起動確認**: Godot で起動してエラーログが出ないこと
3. **デバッグ出力**: 人口増減が予期通りに行われることを確認
4. **視覚確認**: ユーザーに委ねる（Claude Code ルール）

---

## 報告フォーマット

実装完了時は以下の形式で報告してください：

```markdown
# Codex 実装結果: Sprint 3 人口システム

## 変更ファイル
- scripts/econ_mvp/EconEconomy.gd（行番号）

## 変更概要
- 人口フィールド追加・初期化
- リアルタイム人口増減処理
- 食料値消費処理
- 人口増加確定処理
- 即時人口減少処理

## 検証
\`\`\`bash
bash check_syntax.sh
\`\`\`

結果: エラー 0 件

## 未検証項目
- UI 表示の確認（ユーザーに委ねる）

## 残リスク
- なし
```

---

**実装準備完了。Codex へお願いします。**
