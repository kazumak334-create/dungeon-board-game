# Sprint 4 実装プロンプト

## 背景

Sprint 1-3 で構築した都市ステータス・食料値・人口システムを土台に、**満足値（0〜100%）と満足値傾き（%/秒）をリアルタイム更新し、5段階の満足度段階を算出するシステム** を実装する。

満足値傾きは複数要因（基礎・人口規模・人口変化量・建築物・食料不足ペナルティ）の合算で算出する。
満足度段階別の建物効果適用は Sprint 5 で実装する。

---

## 参照ドキュメント

- 企画書：
  - `docs/econ/design_sprint4_satisfaction_system.md`
- 要件定義書：
  - `docs/requirements/req_econ_satisfaction_sprint4.md`（実装の根拠・常時参照）

---

## 実装対象

### 1. 満足値リアルタイム更新（`scripts/econ_mvp/EconEconomy.gd`）

- `update_satisfaction(delta)` 新規追加：毎フレーム呼ばれる
  - `satisfaction_value += satisfaction_slope * delta`
  - `satisfaction_value` を 0〜100 にクランプ
  - 5秒tickで `_calculate_satisfaction_slope()` を再計算しキャッシュ（または毎フレーム再計算でも可）
  - 既存 `satisfaction: int` も同期書き込み（後方互換）

### 2. 満足値傾きの合算（`_calculate_satisfaction_slope`）

5要因を合算した値を `satisfaction_slope` として返す：

| 要因 | 値 |
|---|---|
| 基礎傾き（base） | -0.20 / 秒（自然減衰） |
| 人口規模影響（scale） | 人口値帯別に減算（5段階） |
| 人口変化量影響（growth） | `-1.0 × max(0, 増加-減少)`（人口増加が早いほどマイナス） |
| 建築物影響（building） | PLAZA/TRADE_POST が稼働中の建物分加算 |
| 食料不足ペナルティ（penalty） | `food_shortage_count × 0.20` を減算 |

サブメソッド：
- `_get_population_scale_influence() -> float`：5段階の人口規模影響
- `_get_population_growth_influence() -> float`：`-1.0 × max(0, growth - decline)`
- `_get_building_satisfaction_influence(buildings: Array) -> float`：PLAZA/TRADE_POST集計
- `_get_food_shortage_penalty() -> float`：`food_shortage_count × 0.20` 減算
- `_get_satisfaction_slope_breakdown() -> Dictionary`：ログ用内訳辞書

### 3. 満足度段階の5段階分類

`get_satisfaction_stage() -> String`（Sprint 1 で実装済みのものを最終確認）：
- 80 ≤ value ≤ 100 → "thriving"
- 60 ≤ value < 80 → "satisfied"
- 40 ≤ value < 60 → "uneasy"
- 20 ≤ value < 40 → "dissatisfied"
- 0 ≤ value < 20 → "declining"
- 境界は下側に含める：例 20.0 は dissatisfied

`get_happiness_state()` を後方互換ラッパーとして維持。

### 4. update() への組み込み

- `update()` 内に毎フレーム部分として `update_satisfaction(delta)` を追加
- 既存の `update_population(delta)`（Sprint 3）と同じ毎フレーム位置

### 5. ログ出力

- 5秒tickで `_get_satisfaction_slope_breakdown()` をprintで出す
- 内訳：base / scale / growth / building / penalty / total

---

## 完了条件

要件定義書 `docs/requirements/req_econ_satisfaction_sprint4.md` の以下のチェックリストをすべて満たすこと：

- [ ] `satisfaction_value` がリアルタイムに変化する
- [ ] `satisfaction_slope` が複数要因の合算で算出される
- [ ] 人口規模影響が人口値帯に応じて正しく反映される（5段階）
- [ ] 人口変化量影響が `-1.0 × max(0, 増加-減少)` で算出される
- [ ] 建築物影響（PLAZA/TRADE_POST）が稼働中の建物分加算される
- [ ] 食料不足ペナルティが `food_shortage_count × 0.20` で減算される
- [ ] `satisfaction_value` が0〜100にクランプされる
- [ ] `get_satisfaction_stage()` が5段階を返す
- [ ] `get_happiness_state()` 後方互換ラッパーが既存呼び出し元で正しく動く
- [ ] 満足値傾きの内訳がprintログに出る
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- 食堂（DINER）は満足値傾きに直接影響させない（設計書 §6.9）
- レストラン（RESTAURANT）／香辛料市場（SPICE_MARKET）はMVP未実装。建物enum追加時に有効化
- `satisfaction_value` は float、UIや既存コード参照のため `satisfaction: int` も同期書き込み
- 5段階閾値は設計書通り：20/40/60/80（境界は下側に含める）
- 突撃・防衛突破による満足値傾きペナルティはMVP対象外（設計書 §6.4 「将来拡張枠」）
- PLAZA/TRADE_POST 建物が現状未実装の場合、enum参照時に未存在チェックを入れて 0.0 でフォールバック

---

## テスト方針

1. **構文チェック必須**：1ファイル編集ごとに `bash check_syntax.sh` を実行
2. **起動確認**：Godotで起動し、5秒ごとに満足値傾きの内訳がログ出力されること
3. **シナリオ確認**：
   - 食料値不足時に satisfaction_value が下降すること
   - 食料値潤沢時に satisfaction_value が安定 or 上昇すること
   - 段階閾値で satisfaction_stage が正しく切り替わること
4. **視覚確認はユーザーに委ねる**

---

## 報告フォーマット

完了報告は以下の形式で：

```
✅ Sprint 4 実装完了

## 変更ファイル
- scripts/econ_mvp/EconEconomy.gd（行番号）
- その他

## 完了条件チェック
- [x] satisfaction_value がリアルタイムに変化する
（…全項目を要件定義書のチェックリスト通り記載…）

## check_syntax.sh 結果
エラー件数：[ 0 件 ]

## その他
- 設計書記載と異なる判断をした箇所があれば理由を明記
- TODO/未実装として残した部分（Sprint 5以降の前提）があれば明記
```

完了報告をこのフォーマットで返してください。その後、自動ループが次の Sprint へ進みます。
