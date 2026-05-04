# Sprint 1 実装プロンプト

## 背景

Econ MVP V0.2 の起点となるSprintであり、後続Sprint 2-8で使用する **都市ステータス基盤** および **26×13土地パネル基盤** を構築する。
本Sprintはデータ構造のみを実装し、リアルタイム更新処理（人口増減・満足値傾き計算など）はSprint 2以降で実装する。

「盤面を設計して、介入を仕込んで、答え合わせを観戦する」という核となる体験のうち、本Sprintは「盤面の素地」を作る役割である。

---

## 参照ドキュメント

- 企画書：
  - `docs/econ/design_sprint1_city_status_and_land.md`
  - `docs/econ/sprint1_land_panel_base_design.md`
  - `docs/econ/sprint_plan_updated_with_land_panel.md`
- 要件定義書：
  - `docs/requirements/req_econ_city_status_sprint1.md`（実装の根拠・常時参照）

---

## 実装対象

### 1. 都市ステータス基盤（`scripts/econ_mvp/EconEconomy.gd`）

- 都市ステータス用フィールド追加：
  - `population_float: float = 1.0`
  - `food_value: int = 0`
  - `satisfaction_value: float = 60.0`
  - `satisfaction_slope: float = 0.0`
  - `satisfaction_stage: String = "satisfied"`
  - `building_efficiency_modifier: float = 1.0`（Sprint 5で使用）
  - `food_shortage_count: int = 0`
- `initialize_v0_2()` で全フィールドを初期化
- `get_display_population() -> int`：`max(1, floor(population_float))` を返す
- `get_satisfaction_stage() -> String`：5段階キーを返す（thriving/satisfied/uneasy/dissatisfied/declining、閾値 80/60/40/20）
- 既存フィールド（`food/wheat/satisfaction/population_used`）は後方互換のため並存。削除しない

### 2. 26×13 土地パネル基盤（`EconGrid` 拡張または `scripts/econ_mvp/EconLandPanel.gd` 新規）

- 26列×13行の盤面データ構造を保持
- 自拠点初期位置：`const BASE_INITIAL_POS := Vector2i(2, 7)`
- 土地パネル1枚あたりのデータ構造：
  - `pos: Vector2i`
  - `resources: Dictionary`（資源タイプ → 値）
  - `special_tag: String`（"none" / "spice" / "sulfur"）
  - `terrain_type: String`（"grassland" / "forest" / "rocky" / "desert" / "wetland" / "wasteland"）
  - `category: String`（"single" / "composite"）
  - `distance_band: String`（"near" / "mid" / "far"）
  - `revealed: bool = false`
- 通常資源6種を定数化：`wood`, `resin`, `stone`, `iron`, `wheat`, `cotton`
- `calculate_distance_band(pos: Vector2i, base_pos: Vector2i) -> String`（マンハッタン距離 0-4=near / 5-10=mid / 11+=far）
- 距離帯ごとの資源値レンジ・複合パネル比率・特殊タグ確率・地形確率の生成ロジック
- 初期保証：距離4以内に4種類のパネルが必ず存在
- `EconGrid` 内部配列・フィールドへの直接代入は禁止。新規メソッド経由とする（CLAUDE.md 疎結合ルール）

### 3. 資源値開示・建物配置ルール

- 自拠点(2,7)から距離3以内のパネルを起動時に `revealed = true` に
- `reveal_panels_around(pos: Vector2i, radius: int)` を共通関数として実装
- 建物配置可能条件：「自建物隣接」AND「資源値開示済み」のAND条件
- 建物配置完了時、その建物から距離3以内のパネルを `reveal` する
- 一度開示したパネルは false に戻さない（建物破壊時も維持）
- 未開示パネルのUI表示は「?」、開示済みは資源値・タグ・地形を通常表示

### 4. デバッグログ

- ゲーム起動時にパネル生成ログ（位置・距離・距離帯・資源・タグ・地形）を全338マス分出力
- 都市ステータスの初期化ログを出力

---

## 完了条件

要件定義書 `docs/requirements/req_econ_city_status_sprint1.md` の以下のチェックリストをすべて満たすこと：

### 都市ステータス基盤
- [ ] 都市ステータスが通常資源とは別フィールドとして保持されている
- [ ] `population_float` が小数で保持されている
- [ ] `get_display_population()` が `floor` 値（最低1）を返す
- [ ] `food_value`, `satisfaction_value`, `satisfaction_slope`, `food_shortage_count` が独立して保持されている
- [ ] `get_satisfaction_stage()` が満足値から正しい段階キーを返す（5段階）
- [ ] `initialize_v0_2()` で全フィールドが初期化される
- [ ] 起動時にデバッグprintで都市ステータスが表示される

### 土地パネル基盤
- [ ] 26×13 = 338マス分の盤面データが保持される
- [ ] 自拠点が `col=2, row=7` に配置される
- [ ] 6種通常資源が定数として定義されている
- [ ] マンハッタン距離による距離帯判定が機能する（0-4=near, 5-10=mid, 11+=far）
- [ ] 距離帯ごとに資源値レンジが正しく適用される
- [ ] 単一資源パネル・複合資源パネルが両方生成される
- [ ] 特殊タグ（spice/sulfur）が一定確率で付与され、データ構造として保持される
- [ ] 地形タイプ6種が一定確率で付与され、データ構造として保持される
- [ ] 初期保証ロジックにより、距離4以内に4種類のパネルが必ず存在する
- [ ] ゲーム起動時にパネル生成ログが出力される

### 資源値開示・建物配置ルール
- [ ] 土地パネルに `revealed: bool` フィールドが追加されている（初期値 false）
- [ ] ゲーム開始時、自拠点から距離3以内のパネルが `revealed = true` に初期化される
- [ ] 建物配置時に「自建物隣接」AND「資源値開示済み」の両条件を満たすパネルのみ配置可能
- [ ] 建物配置後、その建物から距離3以内のパネルが `revealed = true` へ遷移する
- [ ] 一度 `revealed = true` になったパネルは `false` へ戻らない（建物破壊時も維持）
- [ ] 未開示パネルのUI表示が「?」となる

### 全体
- [ ] check_syntax.sh エラー0件

---

## テスト方針

1. **構文チェック必須**：1ファイル編集ごとに `bash check_syntax.sh` を実行
2. **起動確認**：Godotで起動してエラーログが出ないこと
3. **デバッグ出力確認**：起動時のパネル生成ログ・都市ステータス初期化ログが期待通り出力されること
4. **視覚確認はユーザーに委ねる**（CLAUDE.md ルール）

---

## 報告フォーマット

完了報告は以下の形式で：

```
✅ Sprint 1 実装完了

## 変更ファイル
- scripts/econ_mvp/EconEconomy.gd（都市ステータス追加・行番号）
- scripts/econ_mvp/EconGrid.gd または scripts/econ_mvp/EconLandPanel.gd（土地パネル基盤）
- その他修正/新規作成ファイル一覧

## 完了条件チェック
- [x] 都市ステータスが通常資源とは別フィールドとして保持されている
- [x] population_float が小数で保持されている
（…全項目を要件定義書のチェックリスト通り記載…）

## check_syntax.sh 結果
エラー件数：[ 0 件 ]

## その他
- 設計書記載と異なる判断をした箇所があれば理由を明記
- TODO/未実装として残した部分（Sprint 2以降の前提）があれば明記
```

完了報告をこのフォーマットで返してください。その後、自動ループが次の Sprint へ進みます。
