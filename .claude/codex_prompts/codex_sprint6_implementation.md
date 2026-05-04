# Sprint 6 実装プロンプト

## 背景

Sprint 1-5 で構築した人口・満足度・建物効率の都市ステータスに、**戦闘行動・防衛失敗が都市人口に直接影響する仕組み** を実装する。

- **突撃**：送り出したユニット数ぶん人口を即時減少
- **防衛突破**：防衛を突破した敵ユニット数ぶん人口を即時減少

人口変化量（リアルタイム増減・Sprint 3）とは別枠の「即時処理」として実装する。

「盤面を設計して、介入を仕込んで、答え合わせを観戦する」体験のうち、本Sprintは「戦闘の代償が街に響く」緊張感を作る役割。

---

## 参照ドキュメント

- 企画書：
  - `docs/econ/design_sprint6_military_system.md`
- 要件定義書：
  - `docs/requirements/req_econ_battle_population_sprint6.md`（実装の根拠・常時参照）

---

## 実装対象

### 1. 即時人口減少API（`scripts/econ_mvp/EconEconomy.gd`）

#### 1-1. `apply_charge_population_loss(unit_count: int)`

- 突撃時に呼ばれる
- `population_float -= unit_count`
- 下限：1.0（最低人口）。1.0未満にならないようにクランプ
- ログ出力（cause=charge）

#### 1-2. `apply_defense_breakthrough_loss(enemy_count: int)`

- 防衛突破時に呼ばれる
- `population_float -= enemy_count`
- 下限：1.0（最低人口）。1.0未満にならないようにクランプ
- ログ出力（cause=defense_breakthrough）

#### 1-3. `get_max_chargeable_units() -> int`

- 突撃可能ユニット数の上限取得
- 戻り値：`floor(population_float) - 1`（最低0）
- 突撃で人口を1未満にしないため、1人は必ず残す

### 2. 即時減少と人口リアルタイム処理の独立性

- 即時減少は `population_float` への直接代入で行う
- `_try_confirm_population_growth()`（Sprint 3）の整数到達判定とは独立処理
- `update_population` の diff 計算からは除外する（即時減少分が人口変化量ログに混入しないこと）
- 即時減少時は食料値消費はしない（人口維持処理／人口増加確定処理のみが食料値を使う）

### 3. EconBattle 連携（`scripts/econ_mvp/EconBattle.gd`）

#### 3-1. 突撃発火箇所

- 突撃判定で `economy.get_max_chargeable_units()` を上限として使用
- ユニット数が上限を超えてリクエストされたとき、上限内に丸める
- 突撃発火時に `economy.apply_charge_population_loss(unit_count)` を呼ぶ

#### 3-2. 防衛突破判定箇所

- 防衛突破時に `economy.apply_defense_breakthrough_loss(enemy_count)` を呼ぶ

**注意**：EconBattle に「突撃」処理が現状存在しない場合は、Sprint 6 範囲外として **要件再確認をCEOに依頼する**。実装を進めず報告してください。

### 4. ログ出力

- 突撃時：`[EconEconomy] 突撃で人口減少 -X（cause=charge, before=Y, after=Z）`
- 防衛突破時：`[EconEconomy] 防衛突破で人口減少 -X（cause=defense_breakthrough, before=Y, after=Z）`

---

## 完了条件

要件定義書 `docs/requirements/req_econ_battle_population_sprint6.md` の以下のチェックリストをすべて満たすこと：

- [ ] 突撃時に `apply_charge_population_loss(n)` が呼ばれ、`population_float` が n 減少する
- [ ] 突撃で `population_float` が 1.0 未満にならない
- [ ] `get_max_chargeable_units()` が `floor(population_float) - 1`（最低0）を返す
- [ ] 突撃ユニット数が上限を超えてリクエストされたとき、上限内に丸められる
- [ ] 防衛突破時に `apply_defense_breakthrough_loss(n)` が呼ばれ、`population_float` が n 減少する
- [ ] 防衛突破で `population_float` が 1.0 未満にならない
- [ ] 即時減少が `update_population` のリアルタイム処理とは独立して動作する（diff計算から除外される）
- [ ] 突撃・防衛人口減少ログが print 出力される
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- 即時減少は `population_float` への直接代入で行う
- 即時減少時は食料値消費はしない（人口維持処理／人口増加確定処理のみが食料値を使う）
- 突撃ユニット数と兵力（`military_power`）の関係は MVP対象外（設計書 §14.4 残論点）。本Sprintでは「ユニット数」を引数として受け取るのみ
- 防衛突破による満足値傾きペナルティは MVP対象外（設計書 §6.4 「将来拡張枠」）
- **EconBattle に「突撃」処理が現状存在しない場合、Sprint 6 範囲外として要件再確認をCEOに依頼**
- 突撃で生還したユニットを人口へ戻すかは MVP対象外（設計書 §14.2 残論点）

---

## テスト方針

1. **構文チェック必須**：1ファイル編集ごとに `bash check_syntax.sh` を実行
2. **起動確認**：Godotで起動し、突撃・防衛突破が発生する状況を作って人口減少ログが出ること
3. **シナリオ確認**：
   - 突撃ユニット数が上限を超えると丸められること
   - population_float が 1.0 で止まること（1.0未満にならない）
   - 即時減少分が update_population のリアルタイム差分ログに混入しないこと
4. **視覚確認はユーザーに委ねる**

---

## 報告フォーマット

完了報告は以下の形式で：

```
✅ Sprint 6 実装完了

## 変更ファイル
- scripts/econ_mvp/EconEconomy.gd（行番号）
- scripts/econ_mvp/EconBattle.gd（行番号・突撃発火箇所・防衛突破判定箇所）
- その他

## 完了条件チェック
- [x] 突撃時に apply_charge_population_loss(n) が呼ばれ、population_float が n 減少する
（…全項目を要件定義書のチェックリスト通り記載…）

## check_syntax.sh 結果
エラー件数：[ 0 件 ]

## その他
- EconBattle に「突撃」処理が存在しなかった場合、その旨を明記
- 設計書記載と異なる判断をした箇所があれば理由を明記
- TODO/未実装として残した部分があれば明記
```

完了報告をこのフォーマットで返してください。その後、自動ループが次の Sprint へ進みます。
