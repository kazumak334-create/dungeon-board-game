# Codex 実装リクエスト：Sprint 8 UI・ログ・デバッグ

**作成日:** 2026-05-04  
**対象Sprint:** Sprint 8  
**実装優先度:** A（Phase 1 コア機能）  
**参照資料:**
- 企画書確定版: `docs/sprint8_ui_logs_debug_final_revised.md`
- Designer企画書: `docs/design/sprint8_designer_plan.md`
- 要件定義書: `docs/requirements/REQUIREMENTS_SPRINT_8.md`
- Sprint 7参考: `docs/requirements/REQUIREMENTS_SPRINT_7.md`

---

## 実装スコープ

### Phase 1: 常時表示UI拡張

**目的:** バトル中の都市状態を常時表示し、プレイヤーが5分で検証可能にする

**要件定義書参照:** §5.1、§6.1

**実装対象:**

#### 1. HEADER上段拡張（1280×36）
- 人口表示
- 食料値表示
- 満足度段階表示
- 兵力表示
- 兵数表示
- ユニット数表示
- 既存人手表示継続

#### 2. EconMain.gd 拡張
- `update_header_stats()` メソッド追加
- 毎フレーム統計値を更新

---

### Phase 2: 建設キューUI

**目的:** 建設予定地を積み上げ形式で表示し、順序変更・即時建設・キャンセル操作を可能にする

**要件定義書参照:** §5.2～5.3、§6.2

**実装対象:**

#### 1. BuildQueueUI.gd（新規作成）
- 盤面左側 140×460px に建設キュー表示
- 建設予定地の積み上げ表示
- 建設順番号の表示
- ドラッグによる順序入れ替え
- クリックで即時建設（通貨G消費）
- 右クリックでキャンセル（コスト返却）

**公開メソッド:**
- `add_to_queue(building_type: String) -> void`
- `remove_from_queue(queue_index: int) -> void`
- `instant_build(queue_index: int) -> bool`
- `reorder_queue(from_idx: int, to_idx: int) -> void`

#### 2. EconBattle.gd 連携
- BuildingSystem から建設完了イベントを受け取り
- キューから建設完了項目を削除

---

### Phase 3: 建設進捗表示

**目的:** 建設中/稼働中/停止中の状態を視覚的に区別し、進捗をBPB形式で表示

**要件定義書参照:** §6.3

**実装対象:**

#### 1. ProgressOverlay 機能拡張
- 建設進捗：円形リング（Sprint 7継承）
- 建物効果進捗：BPB式下→上Overlay
- 停止中：数値赤点滅

#### 2. StopReasonIcon 表示
- 資源不足：❌資
- 稼働人手不足：❌小
- 作業人手不足：❌作
- その他：❌人

---

### Phase 4: 詳細ポップアップシステム

**目的:** クリック位置近傍に小型ポップアップで詳細情報を表示

**要件定義書参照:** §6.4

**実装対象:**

#### 1. DetailPopup.gd（新規作成）
- 建物詳細ポップアップ（稼働効果、人手消費量）
- 満足度詳細ポップアップ（段階別ボーナス）
- 兵力詳細ポップアップ（防御計算）
- クリック位置+12px に表示
- 別オブジェクトクリックで即時切替
- 外部クリックで閉じる

**公開メソッド:**
- `show_building_popup(building_type: String, position: Vector2) -> void`
- `show_satisfaction_popup(current_value: int, stage: int, position: Vector2) -> void`
- `show_military_popup(military_power: int, defense: int, position: Vector2) -> void`
- `close_popup() -> void`

---

### Phase 5: ログ・デバッグシステム

**目的:** 開発者向けのログ出力とデバッグ操作を実装

**要件定義書参照:** §6.5

**実装対象:**

#### 1. EconLogger.gd（新規作成）
- 建設開始ログ
- 建設完了ログ
- 即時建設ログ
- キャンセルログ
- 人手配分変更ログ
- 停止理由ログ
- 効果発動ログ
- リソース変化ログ
- 建物稼働ログ

#### 2. DebugToolsPanel.gd（新規作成）
- FOOTER右端 320×180
- ログビューア
- リアルタイム統計表示
- デバッグ操作（強制進捗、リソース追加等）
- 本番ビルドで非表示

---

## 完了条件チェックリスト

要件定義書 §7 全40項目すべてが実装完了できること：

- [ ] HEADER上段に人口・食料値・満足度段階が表示される
- [ ] HEADER上段に兵力・兵数・ユニット数が表示される
- [ ] 常時表示UI が毎フレーム更新される
- [ ] 建設キューが盤面左側に積み上げ表示される
- [ ] 建設順番号がパネルに表示される
- [ ] ドラッグで建設順を入れ替えられる
- [ ] クリックで即時建設ができる（通貨G消費）
- [ ] 右クリックでキャンセルできる（コスト返却）
- [ ] 即時建設が建築コストを計算できる
- [ ] キャンセルが建設コストを返却できる
- [ ] 建設進捗が円形リングで表示される（直径28px）
- [ ] 建物効果進捗がBPB式Overlayで表示される
- [ ] 停止中が数値赤点滅で表示される
- [ ] 停止理由アイコン（❌資/❌小/❌作/❌人）が正確に表示される
- [ ] 詳細ポップアップがクリック位置+12pxに表示される
- [ ] 建物詳細ポップアップが稼働効果を表示できる
- [ ] 満足度詳細ポップアップが段階別ボーナスを表示できる
- [ ] 兵力詳細ポップアップが防御計算を表示できる
- [ ] 別オブジェクトクリックでポップアップが切り替わる
- [ ] 外部クリックでポップアップが閉じる
- [ ] ログが建設開始・完了・即時建設を出力できる
- [ ] ログがキャンセル・人手配分変更を出力できる
- [ ] ログが停止理由・効果発動を出力できる
- [ ] ログがリソース変化・建物稼働を出力できる
- [ ] デバッグツールが本番ビルドで非表示になる
- [ ] デバッグツールがリアルタイム統計を表示できる
- [ ] Sprint 7 BuildingSystem と疎結合で連携している
- [ ] 新規ファイル4個（BuildQueueUI/DetailPopup/DebugToolsPanel/EconLogger）が分割作成されている
- [ ] EconMain.gd への追記が+200行以内である
- [ ] EconMain.gd が800行を超えない
- [ ] 既存 COLOR_* 定数のみを使用している
- [ ] 新規色定義が0個である
- [ ] KISS原則に従った実装になっている
- [ ] 疎結合ルール（メソッド経由）を遵守している
- [ ] DetailPopup が read-only である
- [ ] 企画書と要件定義書の用語が完全に一致している
- [ ] check_syntax.sh でエラー0件
- [ ] Checker による要件整合性確認に合格
- [ ] Sprint 7依存の前提機能がすべて完了している
- [ ] BPB形式Overlayの実装が企画書の3秒ルールに適合している

---

## 検証方法

実装完了後：

bash check_syntax.sh

全エラー0件を確認後、Checkerに以下を依頼：

- 要件定義書 §7 完了条件チェックリスト全40項目
- Sprint 7 BuildingSystem との疎結合連携
- UI表現が企画書の3秒ルール、Designer企画と一致しているか
- ファイル分割の妥当性（EconMain.gd が800行以下か）
- ログシステムが全9種類を網羅しているか

---

## 参考情報

### 既存ファイル構造
- scripts/econ_mvp/EconMain.gd: UI 統合点（2452行で超過）
- scripts/econ_mvp/EconBattle.gd: バトル連携
- scripts/econ_mvp/BuildingSystem.gd: Sprint 7 で新規作成
- data/cards_econ.json: カードデータ

### CLAUDE.md 重要ルール
- 疎結合ルール: 他クラスの内部配列への直接代入は禁止
- 用語統一: 設計文書と実装で同じ用語を使用
- 足し算禁止: 指示されていない効果・フィールド追加は禁止
- 3秒ルール: UI要素がバトル画面で3秒で伝わるか検証

---

## 特記事項

- **ファイル分割必須**: EconMain.gd は既に2452行で閾値超過。Sprint 8では4個ファイルに分割
- **新規色定義は0個**: 既存 COLOR_* のみ使用（KISS原則）
- **BPB形式**: 建物効果進捗は下→上へ塗りつぶすOverlay表現
- **詳細ポップアップ**: 右側パネル・ボトムシート禁止、クリック位置近傍のみ
- **Sprint 7依存**: BuildingSystem, BuildingStateOverlay の前提が必須
