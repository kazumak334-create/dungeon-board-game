# Sprint 5 実装プロンプト

## 背景

Sprint 4 で実装した満足度段階（5段階）が、**人口・兵力・建物効率の3軸に補正をかける効果** を実装する。

Sprint 3 で人口増加/減少速度には満足度段階が反映済み。本Sprintでは「兵力獲得量・兵力効果・建物効率補正」を満足度段階別に拡張し、各建物の出力に反映する。

「盤面を設計して、介入を仕込んで、答え合わせを観戦する」体験のうち、本Sprintは「満足度の高低が見て分かる」効果を盤面に反映する。

---

## 参照ドキュメント

- 企画書：
  - `docs/econ/design_sprint5_satisfaction_stage_building_efficiency.md`
- 要件定義書：
  - `docs/requirements/req_econ_satisfaction_effects_sprint5.md`（実装の根拠・常時参照）

---

## 実装対象

### 1. 満足度段階別補正ゲッター（`scripts/econ_mvp/EconEconomy.gd`）

#### 1-1. `get_military_gain_modifier() -> float`（兵力獲得量補正）

| 段階 | 値 |
|---|---|
| thriving | 1.2 |
| satisfied | 1.1 |
| uneasy | 1.0 |
| dissatisfied | 0.8 |
| declining | 0.0（兵力獲得なし） |

衰退時の「-100%（兵力獲得なし）」は **0.0倍** として実装。負値にしない。

#### 1-2. `get_military_effect_modifier() -> float`（兵力効果補正）

| 段階 | 値 |
|---|---|
| thriving | 1.1 |
| satisfied | 1.0 |
| uneasy | 1.0 |
| dissatisfied | 0.9 |
| declining | 0.8 |

#### 1-3. `get_building_efficiency_modifier() -> float`（建物効率補正）

| 段階 | 値 |
|---|---|
| thriving | 1.1 |
| satisfied | 1.05 |
| uneasy | 1.0 |
| dissatisfied | 0.9 |
| declining | 0.7 |

戻り値を `building_efficiency_modifier` フィールドにキャッシュし、`update_satisfaction` 内で更新する。

### 2. 既存ラッパーの後方互換維持

- `get_happiness_production_modifier()` を5段階対応へ拡張（または `get_building_efficiency_modifier()` へ委譲）
- `get_happiness_military_modifier()` を5段階対応へ拡張（または `get_military_gain_modifier()` へ委譲）
- 既存呼び出し元はそのまま動くこと

### 3. 建物出力への補正適用

#### 3-1. 兵力獲得量（BARRACKS）

- BARRACKS の兵力生成量に `get_military_gain_modifier()` を乗算
- 既存の `military_power +=` 計算箇所に補正をかける

#### 3-2. 資源生産量（SAWMILL/MINE/WORKSHOP）

- SAWMILL/MINE/WORKSHOP の資源生産量に `get_building_efficiency_modifier()` を乗算
- 既存の生産処理に補正をかける（`roundi` の前に乗算する。小数誤差対策）

#### 3-3. 食料・小麦生産（VILLAGE/DINER/MILL）

- VILLAGE/DINER/MILL の出力に `get_building_efficiency_modifier()` を乗算
- 食堂は満足値傾きに直接影響しないが、出力（食料値+2 等）には建物効率補正をかける（仕様の差異に注意）

### 4. デバッグログ

- 5段階別の補正値を起動時 or 段階変化時にprintで確認可能にする
- `building_efficiency_modifier` の現在値を5秒tickログに含める（Sprint 8 のサマリログとも整合）

---

## 完了条件

要件定義書 `docs/requirements/req_econ_satisfaction_effects_sprint5.md` の以下のチェックリストをすべて満たすこと：

- [ ] `get_military_gain_modifier()` が5段階で正しい値を返す（0.0/0.8/1.0/1.1/1.2）
- [ ] `get_military_effect_modifier()` が5段階で正しい値を返す（0.8/0.9/1.0/1.0/1.1）
- [ ] `get_building_efficiency_modifier()` が5段階で正しい値を返す（0.7/0.9/1.0/1.05/1.1）
- [ ] `building_efficiency_modifier` フィールドが `update_satisfaction` で更新される
- [ ] BARRACKS 兵力生成量が `get_military_gain_modifier()` の影響を受ける
- [ ] SAWMILL/MINE/WORKSHOP の資源生産量が `get_building_efficiency_modifier()` の影響を受ける
- [ ] VILLAGE/DINER/MILL の出力が `get_building_efficiency_modifier()` の影響を受ける
- [ ] 既存の `get_happiness_production_modifier()` / `get_happiness_military_modifier()` が後方互換ラッパーとして動く
- [ ] 5段階別補正値がデバッグprintで確認できる
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- Sprint 3 で人口増加/減少の段階別効果は実装済み。本Sprintでは触らない
- 兵力効果補正の戦闘適用は Sprint 6 と連動。本Sprintではゲッターのみ用意でも完了扱い
- 建物効率補正は `roundi` の前に乗算する（小数誤差対策）
- 食堂は満足値傾きに影響しないが、出力（食料値+2）には建物効率補正をかける
- 衰退時の兵力獲得量「-100%（兵力獲得なし）」は 0.0倍として実装。負値にしない

---

## テスト方針

1. **構文チェック必須**：1ファイル編集ごとに `bash check_syntax.sh` を実行
2. **起動確認**：Godotで起動し、5段階別の補正値ログが出ること
3. **シナリオ確認**：
   - 満足度を強制的に thriving / declining にして補正値が切り替わること
   - 各建物の出力値が補正前後で変化すること
4. **視覚確認はユーザーに委ねる**

---

## 報告フォーマット

完了報告は以下の形式で：

```
✅ Sprint 5 実装完了

## 変更ファイル
- scripts/econ_mvp/EconEconomy.gd（行番号）
- scripts/econ_mvp/EconBuilding.gd（行番号・各建物の補正適用箇所）
- その他

## 完了条件チェック
- [x] get_military_gain_modifier() が5段階で正しい値を返す
（…全項目を要件定義書のチェックリスト通り記載…）

## check_syntax.sh 結果
エラー件数：[ 0 件 ]

## その他
- 設計書記載と異なる判断をした箇所があれば理由を明記
- TODO/未実装として残した部分（Sprint 6以降の前提）があれば明記
```

完了報告をこのフォーマットで返してください。その後、自動ループが次の Sprint へ進みます。
