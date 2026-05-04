# Sprint 2 実装プロンプト

## 背景

Sprint 1で構築した都市ステータス基盤（`food_value`）と26×13土地パネル基盤を活用し、**「小麦 → 食堂 → 食料値」「小麦 → 製粉所 → 小麦増幅」の生産ライン** および **5秒周期の人口維持処理** を実装する。

これにより、後続Sprint 3で人口増減を処理するための「食料値が消費される」流れが成立する。

「盤面を設計して、介入を仕込んで、答え合わせを観戦する」体験のうち、本Sprintは盤面の生産ループを起動させる役割である。

---

## 参照ドキュメント

- 企画書：
  - `docs/econ/design_sprint2_food_system_and_land.md`
- 要件定義書：
  - `docs/requirements/req_econ_food_system_sprint2.md`（実装の根拠・常時参照）

---

## 実装対象

### 1. 食堂（DINER）建物（`scripts/econ_mvp/EconBuilding.gd`）

- `BuildingType` enum に `DINER` を追加
- `BUILD_COSTS`, `BUILD_HP` に追加（HP=60）
- `_update_diner(delta, economy)` 新規追加：
  - 発動間隔：5.0秒（`const DINER_INTERVAL := 5.0`）
  - 通常効果：小麦1消費 → 食料値+2
  - 香辛料タグ効果：足元パネルに `special_tag == "spice"` がある場合 食料値+3
  - 小麦不足時：発動せずログのみ
- `update()` 内 match に DINER 分岐追加

### 2. 製粉所（MILL）建物（`scripts/econ_mvp/EconBuilding.gd`）

- `BuildingType` enum に `MILL` を追加
- `BUILD_COSTS`, `BUILD_HP` に追加
- `_update_mill(delta, economy)` 新規追加：
  - 発動間隔：5.0秒（`const MILL_INTERVAL := 5.0`）
  - 通常効果：小麦1消費 → 小麦+2（差し引き+1）
  - パネルボーナス：足元パネルの小麦値が3以上なら 小麦+3（差し引き+2）
  - 小麦不足時：発動しない
- `update()` 内 match に MILL 分岐追加

### 3. 人口維持処理（`scripts/econ_mvp/EconEconomy.gd`）

- `consume_food_for_maintenance()` 新規追加：
  - 5秒周期で発動
  - `floor(population_float)` ぶんの食料値を消費
  - 食料値が足りる場合：`food_shortage_count` を1減（最低0）
  - 食料値が不足する場合：`food_shortage_count` を1増、残食料値はすべて消費、不足ログ出力
- `add_food(amount: int)` 新規追加（食堂から呼び出される共通API）
- 既存`food` フィールドは後方互換のため `food_value` と同期書き込み
- 旧30秒周期・`population_used / 10` 式は完全削除

### 4. カードデータ（`data/cards_econ.json`）

- `card_diner` を新規追加（食堂）
- `card_mill` を新規追加（製粉所）
- 既存カードと同じスキーマで定義する

### 5. 配置ルール統合（Sprint 1 §4.3 継承）

- VILLAGE / DINER / MILL の配置判定が「自建物隣接」AND「資源値開示済み」のAND条件で動くこと
- 未開示パネル・自建物非隣接パネルには配置できないこと

### 6. 香辛料タグ・小麦値パネル参照

- 食堂の `_update_diner` から土地パネルの `special_tag` を参照する判定APIを実装
- 製粉所の `_update_mill` から土地パネルの小麦値（`resources["wheat"]` 等）を参照する判定APIを実装
- 土地パネルが未生成の場合（Sprint 1未完了想定）は空Dictionaryでフォールバック（通常効果）

---

## 完了条件

要件定義書 `docs/requirements/req_econ_food_system_sprint2.md` の以下のチェックリストをすべて満たすこと：

### 食堂・製粉所・人口維持処理
- [ ] 食堂が5秒ごとに小麦-1・食料値+2を行う
- [ ] 食堂は小麦不足時に発動しない（ログ出力あり）
- [ ] 製粉所が5秒ごとに小麦-1・小麦+2を行う（差し引き+1）
- [ ] 製粉所は小麦不足時に発動しない
- [ ] 人口維持処理が5秒ごとに発動し、`floor(population_float)` ぶんの食料値を消費する
- [ ] 食料値が足りる場合、`food_shortage_count` が1減る（最低0）
- [ ] 食料値が不足する場合、`food_shortage_count` が1増える、残食料値はすべて消費
- [ ] 食料値不足状態がログ出力される

### 香辛料タグ・小麦値パネル
- [ ] 食堂が香辛料タグパネル上で食料値+3を生成する
- [ ] 食堂が通常パネル上で食料値+2を生成する
- [ ] 製粉所が小麦値3以上パネル上で小麦+3を生成する（差し引き+2）
- [ ] 製粉所が通常パネル上で小麦+2を生成する（差し引き+1）
- [ ] 農村が小麦パネル・小麦/綿花複合パネル上に配置可能

### 配置ルール
- [ ] 農村（VILLAGE）の配置判定が「自建物隣接」AND「資源値開示済み」になっている
- [ ] 食堂（DINER）の配置判定が「自建物隣接」AND「資源値開示済み」になっている
- [ ] 製粉所（MILL）の配置判定が「自建物隣接」AND「資源値開示済み」になっている
- [ ] 未開示パネル・自建物非隣接パネルには配置できない

### タイマー周期
- [ ] 食堂・製粉所・人口維持処理がすべて5.0秒周期で発動する
- [ ] 旧30秒周期・`population_used / 10` 式が完全に削除されている
- [ ] grep で「30.0」「/ 10」等の旧式リテラルが食料関連コードに残っていない

### 全体
- [ ] check_syntax.sh エラー0件

---

## テスト方針

1. **構文チェック必須**：1ファイル編集ごとに `bash check_syntax.sh` を実行
2. **grep確認**：
   - `grep -rn "30.0\|/ 10" scripts/econ_mvp/` で旧式リテラルが食料関連コードに残っていないか
   - `grep -rn "DINER\|MILL" scripts/econ_mvp/` で新規分岐が正しく追加されているか
3. **起動確認**：Godotで起動して食堂・製粉所が5秒ごとに発動しログが出ること
4. **視覚確認はユーザーに委ねる**

---

## 報告フォーマット

完了報告は以下の形式で：

```
✅ Sprint 2 実装完了

## 変更ファイル
- scripts/econ_mvp/EconEconomy.gd（行番号）
- scripts/econ_mvp/EconBuilding.gd（行番号）
- data/cards_econ.json（card_diner / card_mill 追加）
- その他

## 完了条件チェック
- [x] 食堂が5秒ごとに小麦-1・食料値+2を行う
（…全項目を要件定義書のチェックリスト通り記載…）

## check_syntax.sh 結果
エラー件数：[ 0 件 ]

## grep確認結果
- 旧30.0/10リテラル：残存ゼロ
- DINER/MILL分岐：正しく追加

## その他
- 設計書記載と異なる判断をした箇所があれば理由を明記
- TODO/未実装として残した部分があれば明記
```

完了報告をこのフォーマットで返してください。その後、自動ループが次の Sprint へ進みます。
