# Codex 引継ぎプロンプト：Sprint 1 完了通知手順

## 概要

Sprint 1 の実装完了後、このドキュメントに記載された手順に従って完了通知を出してください。

完了通知は Codex の責務の終点です。通知後は自動 Hook により Sprint 2 の自動ループが開始されます。

---

## Sprint 1 の実装範囲

| 項目 | 実装内容 | ファイル |
|---|---|---|
| 都市ステータス基盤 | 人口・食料値・満足値フィールド追加 | `scripts/econ_mvp/EconEconomy.gd` |
| 土地パネル基盤 | 盤面構造・距離帯計算・資源値生成 | `scripts/econ_mvp/EconGrid.gd` |
| 初期化ロジック | ゲーム起動時の盤面・都市ステータス初期化 | `scripts/econ_mvp/EconMain.gd` |

---

## Step 1：実装内容の確認

実装は以下の要件定義書に基づいて行われます。

### 参照文書
- `docs/econ/design_sprint1_city_status_and_land.md` — Sprint 1 企画書
- `docs/requirements/req_econ_city_status_sprint1.md` — 都市ステータス要件定義
- `docs/econ/sprint_plan_econ_mvp_v0_2_unified.md` — 全Sprint計画（参考）

### 実装チェックリスト（参考）
以下を実装してください：

- [ ] **EconEconomy.gd の拡張**
  - [ ] 都市ステータスフィールド追加（population_float, food_value, satisfaction_value 等）
  - [ ] 初期化処理 `initialize_v0_2()` への都市ステータス初期化追加
  - [ ] ゲッター `get_satisfaction_stage()` 実装
  - [ ] ゲッター `get_display_population()` 実装

- [ ] **EconGrid.gd の実装（新規作成またはメイン拡張）**
  - [ ] 盤面サイズ 26×13 の定数定義
  - [ ] 自拠点初期位置 (col=2, row=7) の定義
  - [ ] マンハッタン距離計算ロジック
  - [ ] 距離帯分類ロジック（7段階：Inner～Outer）
  - [ ] 距離帯別資源値生成ロジック
  - [ ] 単一資源パネル生成
  - [ ] 複合資源パネル生成（一部パネル）
  - [ ] 初期保証ロジック（近傍パネルの多様性確保）

- [ ] **EconMain.gd への統合**
  - [ ] ゲーム起動時に EconGrid と EconEconomy の初期化を呼び出し
  - [ ] デバッグログ出力（盤面情報・都市ステータス初期値）

---

## Step 2：構文チェック（必須）

実装完了後、以下を実行して構文エラーをチェックしてください。

```bash
bash C:/Users/kazum/dungeon-board-game/check_syntax.sh
```

### チェック結果への対応

#### ✅ エラー0件の場合
Step 3 へ進んで完了通知を出してください。

#### ❌ エラーがある場合
修正を行い、再度チェックを実行します。

```bash
# エラー修正後
bash C:/Users/kazum/dungeon-board-game/check_syntax.sh
```

**エラーが1件でもあれば、完了通知を出さないでください。**
修正とチェック実行を繰り返し、**エラー0件になるまで**続けます。

---

## Step 3：完了通知を出力

構文チェックで **エラー0件** を確認した後、ユーザーに以下の形式で通知してください。

### 通知フォーマット

```
✅ Sprint 1 実装完了

【変更ファイル】
- EconEconomy.gd（都市ステータス基盤拡張）
- EconGrid.gd（土地パネル基盤実装）
- EconMain.gd（初期化ロジック統合）

【構文チェック結果】
check_syntax.sh：エラー0件 ✅

【実装完了項目】
✅ 都市ステータスデータ構造
  - population_float（小数人口）
  - food_value（食料値）
  - satisfaction_value（満足値）
  - population_cap（人口上限）

✅ 土地パネルデータ構造
  - position（座標）
  - land_type（パネルタイプ）
  - primary_resource / primary_value（主資源）
  - secondary_resource / secondary_value（副資源）
  - distance_tier（距離帯分類）
  - is_discovered（発見フラグ）

✅ 盤面初期化
  - 26×13盤面生成
  - マンハッタン距離計算
  - 距離帯別資源値生成
  - 初期保証ロジック（近傍多様性確保）
  - ゲーム起動時の自動初期化

✅ ゲッター実装
  - get_satisfaction_stage()（5段階判定）
  - get_display_population()（表示用整数値）

【次ステップ】
自動 Hook により以下が開始されます：

1. **Checker による要件検証**
   - EconEconomy.gd / EconGrid.gd の実装が req_econ_city_status_sprint1.md と一致するか確認
   - 構文エラー・ロジックエラーの検出

2. **Sprint 2 の診断・Codex プロンプト作成**
   - Sprint 1 検証完了後、Sprint 2 食料システムの実装を開始
   - 新しい Codex プロンプトが自動生成される

3. **Sprint 2-8 の自動実装ループ開始**
   - 各 Sprint の実装 → 検証 → 次 Sprint の自動ループ
```

---

## Step 4：通知完了

上記メッセージをユーザーに出力したら、**Codex の役割はここまでです。**

以下のアクションは Codex が行わないでください：

- ❌ ユーザーの返答を待つ
- ❌ Checker の実行
- ❌ Sprint 2 のコード編集
- ❌ Hook の実行

すべて自動化されたプロセスで、他のエージェントが処理します。

---

## 重要なルール

### 1. 通知形式の統一性
- 必ず `✅ Sprint 1 実装完了` で始まること
- 変更ファイル・チェック結果・実装項目を記載すること
- 次ステップが「自動 Hook で開始される」ことを明記すること

### 2. 構文チェックの厳密さ
- 通知を出す前に必ず `check_syntax.sh` を実行すること
- エラーが1件でもあれば、通知を出さず修正指示を返すこと
- 「テストが通ったから」という理由で構文チェックをスキップしないこと

### 3. 指示からの乖離禁止
- 指示された実装範囲以外のコードは変更しないこと
- 「ついでに」最適化・リファクタリング・追加実装をしないこと
- 足し算禁止（削除と置き換えのみ）

### 4. 通知後のアクション禁止
- 通知を出した後は Codex は何もしないこと
- ユーザーからの質問・要望を待つこと
- Sprint 2 の作業は Codex プロンプト再発行を待つこと

---

## 参考：自動 Hook 後のフロー

Codex の完了通知を受けると、以下が自動実行されます。（Codex が行うのではなく、システムが自動実行）

```
【完了通知出力】
         ↓
【自動 Hook 起動】
    ↙        ↘
[Checker]   [CEO/PMO]
    ↓            ↓
[検証]      [Sprint 2 診断]
    ↓            ↓
[OK/NG]     [Codex プロンプト作成]
    ↓            ↓
[報告]      [Sprint 2 Codex 起動]
```

---

## 最後に

このドキュメントは Codex が **Sprint 1 完了後に参照する** 唯一の引継ぎドキュメントです。

実装完了時に、上記の手順と通知フォーマットに従ってください。

質問や不明点がある場合は、ユーザーに相談してください。
