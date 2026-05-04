# Sprint 3 実装プロンプト

## 背景

Sprint 1 の都市ステータス基盤と Sprint 2 の食料値消費を活用し、**人口を「リアルタイムに小数で増減する都市ステータス」として実装** する。

人口変化量を増加要因・減少要因の合算で算出し、整数到達時に食料値を消費する。
満足度段階を主な人口増加要因として参照する（Sprint 4で本格的な満足度更新が入るが、本Sprintではスタブとして `get_satisfaction_stage()` を使用）。

「盤面を設計して、介入を仕込んで、答え合わせを観戦する」体験のうち、本Sprintは「街が育っていく」感覚を作り出す中核である。

---

## 参照ドキュメント

- 企画書：
  - `docs/econ/design_sprint3_population_system.md`
- 要件定義書：
  - `docs/requirements/req_econ_population_sprint3.md`（実装の根拠・常時参照）

---

## 実装対象

### 1. 人口リアルタイム増減（`scripts/econ_mvp/EconEconomy.gd`）

- `update_population(delta)` 新規追加：毎フレーム呼ばれる
- `_calculate_population_growth_rate() -> float` 新規追加：増加要因合計
- `_calculate_population_decline_rate() -> float` 新規追加：減少要因合計
- `_try_confirm_population_growth()` 新規追加：整数到達時に食料値消費 → 確定
- `_get_population_growth_log() -> Dictionary` 新規追加：ログ用内訳辞書

### 2. 増加・減少要因（割合ベース、%/秒）

増加要因（`_calculate_population_growth_rate`）：
- 基礎増加：満足度段階別
  - thriving: +0.05
  - satisfied: +0.03
  - uneasy: +0.01
  - dissatisfied: 0
  - declining: 0
- 人口上限到達時は0

減少要因（`_calculate_population_decline_rate`）：
- 食料値不足時（`food_shortage_count > 0`）：+0.04/秒
- 不満段階（dissatisfied）：+0.04/秒
- 衰退段階（declining）：+0.10/秒

合算：
- `delta_population_per_sec = growth_rate - decline_rate`
- `population_float += delta_population_per_sec * delta`
- 上限：`population_cap`、下限：1.0（最低人口）

### 3. 整数到達時の食料値消費（人口増加確定処理）

- `population_float` が次の整数を超えたとき：
  - 必要食料値：`max(1, floor(population_float))`
  - 繁栄段階（thriving）では：`max(1, floor(population_float) - 1)` に軽減
  - 食料値が足りる場合：消費して人口増加確定
  - 食料値が足りない場合：`_growth_blocked_by_food = true` にして人口増加を一時停止（次の整数に到達しない）。population_float を直前の整数に丸める
- 食料値が補充されたら次フレームで増加再開

### 4. update() への組み込み

- `update()` 内に Step 7 として `update_population(delta)` 呼び出しを追加
- 毎フレーム呼ぶ（5秒tickではない。`_try_confirm_population_growth()` も毎フレーム判定）

### 5. ログ出力

- 人口変化量の内訳を5秒ごとにサマリprintで出す（毎フレームprintは禁止・トークン消費抑制）
- `_get_population_growth_log()` は内訳辞書（増加要因・減少要因・現在値）を返す

---

## 完了条件

要件定義書 `docs/requirements/req_econ_population_sprint3.md` の以下のチェックリストをすべて満たすこと：

- [ ] `population_float` が `update_population(delta)` で増減する
- [ ] 人口上限（`population_cap`）で増加が止まる
- [ ] 食料値不足時（`food_shortage_count > 0`）に減少要因0.04/秒が加算される
- [ ] 不満段階で減少要因0.04/秒が加算される
- [ ] 衰退段階で減少要因0.10/秒が加算される
- [ ] 増加・減少要因が同時発生時に正しく合算される
- [ ] 整数人口到達時に `max(1, floor(population_float))` ぶんの食料値が消費される
- [ ] 繁栄段階では `max(1, floor(population_float) - 1)` に軽減される
- [ ] 食料値不足で人口増加確定が止まる（次の整数に到達しない）
- [ ] 食料値が補充されたら人口増加が再開する
- [ ] 人口変化量の内訳がprintログに出る
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- `population_used`（既存int）は別概念（稼働人口数）として残す。本Sprintで触らない
- 表示用の `get_display_population()` は Sprint 1 で実装済み。本Sprintでは利用のみ
- `update_population` は毎フレーム呼ばれるため、過剰なログを避ける（5秒に1回サマリprintで十分）
- `_growth_blocked_by_food` は内部状態。UIには直接出さない（Sprint 8で表示検討）
- 突撃・防衛突破による即時人口減少は Sprint 6 で別途実装（人口変化量とは別枠）

---

## テスト方針

1. **構文チェック必須**：1ファイル編集ごとに `bash check_syntax.sh` を実行
2. **起動確認**：Godotで起動し、人口変化量が5秒ごとにログ出力されること
3. **シナリオ確認**：
   - 食料値が十分なときに人口がじわじわ増えること
   - 食料値0で人口増加が止まること
   - 食料値補充で再開すること
4. **視覚確認はユーザーに委ねる**

---

## 報告フォーマット

完了報告は以下の形式で：

```
✅ Sprint 3 実装完了

## 変更ファイル
- scripts/econ_mvp/EconEconomy.gd（行番号）
- その他

## 完了条件チェック
- [x] population_float が update_population(delta) で増減する
（…全項目を要件定義書のチェックリスト通り記載…）

## check_syntax.sh 結果
エラー件数：[ 0 件 ]

## その他
- 設計書記載と異なる判断をした箇所があれば理由を明記
- TODO/未実装として残した部分（Sprint 4以降の前提）があれば明記
```

完了報告をこのフォーマットで返してください。その後、自動ループが次の Sprint へ進みます。
