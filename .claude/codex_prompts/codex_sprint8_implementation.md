# Sprint 8 実装プロンプト

## 背景

Sprint 1-7 で構築した都市ステータス・食料値・人口・満足度・建物効率・戦闘連動・初期デッキ・土地カード報酬を、**UI表示とログ出力で確認できるようにする** 仕上げのSprint。

- 都市ステータスをUIに常時表示
- 人口変化量・満足値傾きの内訳ログを LogManager に流す
- 突撃・防衛突破による即時人口減少を視覚化（ログレベル）
- 土地パネル情報を盤面UIに表示
- ホバー/クリックで詳細ポップアップ
- 土地パネル生成・土地カード報酬のログ出力

「盤面を設計して、介入を仕込んで、答え合わせを観戦する」体験のうち、本Sprintは「観戦」を支える可視化レイヤーを完成させる。

---

## 参照ドキュメント

- 企画書：
  - `docs/econ/design_sprint8_ui_logging.md`
  - `docs/econ/design_sprint8_ui_logging_and_land.md`
- 要件定義書：
  - `docs/requirements/req_econ_logging_ui_sprint8.md`（実装の根拠・常時参照）

---

## 実装対象

### 1. 都市ステータスHUD（新規 `scripts/econ_mvp/EconUI.gd`）

- `Control` 派生のNode
- フィールド：`economy: EconEconomy` 参照
- 関数：`update_status_display()`
  - 0.5秒tick で表示更新（または毎フレーム）
- 子要素：Label群
  - 人口（表示/上限/内部値：`get_display_population()` / `population_cap` / `population_float`）
  - 食料値（`food_value`）
  - 食料不足カウント（`food_shortage_count`）
  - 満足値（`satisfaction_value`）
  - 満足値傾き（`satisfaction_slope`）
  - 満足度段階（`satisfaction_stage`）
  - 兵力（`military_power`）
  - 建物効率（`building_efficiency_modifier`）
- 動的生成でよい（KISS原則・.tscn は作らない）
- `scripts/econ_mvp/EconMain.gd` でシーンに追加し、`EconUI.economy = economy` を接続

### 2. LogManager 拡張（`scripts/econ_mvp/LogManager.gd`）

- イベントタイプ追加：
  - `POP_CHANGE`：人口変化量サマリ
  - `SAT_SLOPE`：満足値傾き内訳
  - `POP_LOSS`：突撃・防衛突破による即時人口減少
  - `LAND_PANEL_GEN`：土地パネル生成（起動時に338行）
  - `LAND_CARD_REWARD`：土地カード報酬発生時
- `_should_log` の許可リストに追加
- 既存の `_file = FileAccess.open(...)` 構造を流用。新規ファイル作成は不要

### 3. EconEconomy ログ呼び出し（`scripts/econ_mvp/EconEconomy.gd`）

- 5秒tickで `LogManager.log_event({"type": "POP_CHANGE", ...})` を呼ぶ（増加要因・減少要因の内訳含む）
- 5秒tickで `LogManager.log_event({"type": "SAT_SLOPE", ...})` を呼ぶ（5要因 base/scale/growth/building/penalty の内訳含む）
- `apply_charge_population_loss` で `LogManager.log_event({"type": "POP_LOSS", "cause": "charge", ...})` を呼ぶ
- `apply_defense_breakthrough_loss` で `LogManager.log_event({"type": "POP_LOSS", "cause": "defense_breakthrough", ...})` を呼ぶ
- POP_CHANGE / SAT_SLOPE は5秒tick内で2件のJSON行を出力（1tickあたり最大3-5行のログ増加で許容範囲）

### 4. 土地パネルUI

- 盤面の各マスに土地パネル情報を視覚的に表示：
  - 資源アイコン・値
  - 特殊タグ（spice/sulfur）
  - 地形タイプ
- 複合資源パネルでは複数の資源アイコンと値が同時に表示される
- 自拠点マスに基地アイコンを表示
- 未開示パネル（`revealed == false`）は「?」表示
- 開示済みパネルは通常表示
- 資源アイコン素材は既存資産を流用。なければ単色矩形＋テキストで代用（KISS）

### 5. 土地パネル詳細ポップアップ

- パネルをホバー or クリックで詳細情報が表示される
- 詳細項目：
  - 座標（pos）
  - 距離（マンハッタン距離）
  - 距離帯（near/mid/far）
  - カテゴリ（single/composite）
  - 資源値（resources）
  - 特殊タグ（special_tag）
  - 地形（terrain_type）
  - 配置建物（あれば）
- 動的生成でよい（.tscn は作らない）

### 6. 建物進捗UI

- 各建物の発動進捗（次回発動までの残秒数 or バー表示）を盤面に視覚化
- 動的生成でよい

### 7. デバッグ操作

- デバッグキー（F1〜F12 等）で以下を強制発動できるように：
  - 食料値±10
  - 満足値±10
  - 人口±1
  - 突撃ユニット数指定
  - 土地カード報酬発生
- ホットキー割り当ては要件定義書または企画書を参照。なければ実装者判断でCEOに報告

### 8. 土地パネル生成・土地カード報酬ログ

- ゲーム起動時、全土地パネル（338枚）の生成情報を `LAND_PANEL_GEN` として `LogManager` に記録
- 土地カード報酬発生時、3候補・選択結果・配置座標を `LAND_CARD_REWARD` として記録
- ログレベル DEBUG で両イベントが出力される

---

## 完了条件

要件定義書 `docs/requirements/req_econ_logging_ui_sprint8.md` の以下のチェックリストをすべて満たすこと：

### 都市ステータスHUD・ログ
- [ ] ゲーム起動時、画面に都市ステータスHUDが表示される
- [ ] 0.5秒ごとにHUD表示が更新される
- [ ] 人口（表示/上限/内部値）・食料値・食料不足カウント・満足値・傾き・段階・兵力・建物効率がHUDに表示される
- [ ] 5秒tickで POP_CHANGE イベントがログファイルに記録される
- [ ] POP_CHANGE に増加要因・減少要因の内訳が含まれる
- [ ] 5秒tickで SAT_SLOPE イベントがログファイルに記録される
- [ ] SAT_SLOPE に5要因（base/scale/growth/building/penalty）の内訳が含まれる
- [ ] 突撃発生時に POP_LOSS（cause=charge）がログ出力される
- [ ] 防衛突破時に POP_LOSS（cause=defense_breakthrough）がログ出力される

### 土地パネルUI・ログ
- [ ] 盤面の各マスに土地パネル情報が視覚的に表示される（資源アイコン・値・タグ・地形）
- [ ] 複合資源パネルでは複数の資源アイコンと値が同時に表示される
- [ ] 自拠点マスに基地アイコンが表示される
- [ ] パネルをホバー or クリックで詳細情報が表示される
- [ ] 詳細情報に座標・距離・距離帯・カテゴリ・資源値・特殊タグ・地形・配置建物が含まれる
- [ ] ゲーム起動時、全土地パネルの生成ログが LAND_PANEL_GEN として記録される
- [ ] 土地カード報酬発生時、3候補・選択結果・配置座標が LAND_CARD_REWARD として記録される
- [ ] ログレベル DEBUG で両イベントが出力される

### 全体
- [ ] check_syntax.sh エラー0件

---

## 制約・注意事項

- 画面確認はユーザーに委ねる（CLAUDE.md ルール）。実装側は print + ログファイル確認まで
- HUD配置・サイズ・色は暫定値。最終調整は Designer に委ねる
- LogManager は既存の `_file = FileAccess.open(...)` 構造を流用。新規ファイル作成は不要
- `get_battle_time()` が EconEconomy に未存在の場合、`_tick_index * TICK_INTERVAL` で代用
- POP_CHANGE / SAT_SLOPE は5秒tick内で2件のJSON行を出力（1tickあたり最大3-5行のログ増加で許容範囲）
- EconUI は MVPでは .tscn を作らず動的生成でよい（KISS原則）
- 既存の `LogManager` Autoloadであることを前提（`project.godot` で確認）
- 資源アイコン素材は既存資産を流用。なければ単色矩形＋テキストで代用
- `LAND_PANEL_GEN` は1パネル1行 = 約338行のログが起動時に出力される。DEBUGレベル限定で許容
- 土地パネルUI・詳細UIのレイアウト調整は Designer に委ねる

---

## テスト方針

1. **構文チェック必須**：1ファイル編集ごとに `bash check_syntax.sh` を実行
2. **起動確認**：Godotで起動し以下を確認：
   - 都市ステータスHUDが表示される
   - 0.5秒ごとに更新される
   - 5秒ごとに POP_CHANGE / SAT_SLOPE がログファイルに記録される
   - 起動時に LAND_PANEL_GEN が338行記録される
3. **シナリオ確認**：
   - 突撃発生時に POP_LOSS（cause=charge）がログに出る
   - 防衛突破時に POP_LOSS（cause=defense_breakthrough）がログに出る
   - 土地カード報酬発生時に LAND_CARD_REWARD がログに出る
4. **視覚確認はユーザーに委ねる**

---

## 報告フォーマット

完了報告は以下の形式で：

```
✅ Sprint 8 実装完了

## 変更ファイル
- scripts/econ_mvp/EconUI.gd（新規）
- scripts/econ_mvp/LogManager.gd（イベント追加・行番号）
- scripts/econ_mvp/EconEconomy.gd（ログ呼び出し追加・行番号）
- scripts/econ_mvp/EconMain.gd（EconUI接続・行番号）
- scripts/econ_mvp/EconGrid.gd 等（土地パネルUI・行番号）
- その他

## 完了条件チェック
- [x] ゲーム起動時、画面に都市ステータスHUDが表示される
（…全項目を要件定義書のチェックリスト通り記載…）

## check_syntax.sh 結果
エラー件数：[ 0 件 ]

## ログファイル確認
- POP_CHANGE：5秒ごとに記録確認
- SAT_SLOPE：5秒ごとに記録確認
- POP_LOSS：シナリオ発生時に記録確認
- LAND_PANEL_GEN：起動時に338行記録確認
- LAND_CARD_REWARD：報酬発生時に記録確認

## その他
- 設計書記載と異なる判断をした箇所があれば理由を明記
- TODO/未実装として残した部分があれば明記
- HUD/土地パネルUIの配置・サイズはDesigner調整待ちと明記
```

完了報告をこのフォーマットで返してください。これでSprint 1-8の自動実装ループは完了です。
