# Codex 実装リクエスト：Sprint 7 初期デッキ・建築基盤

**作成日:** 2026-05-04  
**対象Sprint:** Sprint 7  
**実装優先度:** A（Phase 1 コア機能）  
**参照資料:**
- 企画書確定版: `docs/sprint7_initial_deck_building_base_final.md`
- Designer企画書: `docs/design/sprint7_designer_plan.md`
- 要件定義書: `docs/requirements/REQUIREMENTS_SPRINT_7.md`

---

## 実装スコープ

### Phase 1: 初期デッキ・カード定義

**目的:** 13枚初期デッキを定義し、建物カード（通常・特殊）の仕様を確立

**要件定義書参照:** §3（スコープ）、§4（データ構造）

**実装対象:**

#### 1. cards_econ.json 拡張
```json
{
  "decks": {
    "initial": [
      { "id": "dwelling_1", "name": "住宅", "type": "normal_building", "cost": {"wood": 1}, "time": 1.0 },
      { "id": "farm_1", "name": "農村", "type": "normal_building", "cost": {"wood": 2, "wheat": 1}, "time": 1.5 },
      { "id": "forest_shack_1", "name": "森小屋", "type": "normal_building", "cost": {"wood": 1}, "time": 1.2 },
      { "id": "mine_1", "name": "採掘所", "type": "normal_building", "cost": {"stone": 1}, "time": 1.5 },
      { "id": "canteen_1", "name": "食堂", "type": "normal_building", "cost": {"wood": 2}, "time": 1.0 },
      { "id": "barracks_1", "name": "兵舎", "type": "normal_building", "cost": {"stone": 2}, "time": 2.0 },
      { "id": "plaza_1", "name": "広場", "type": "normal_building", "cost": {"wood": 3}, "time": 1.8 },
      { "id": "exchange_1", "name": "交換所", "type": "special_building", "cost": {"wood": 2, "stone": 1}, "time": 3.0 },
      { "id": "dwelling_2", "name": "住宅", "type": "normal_building", "cost": {"wood": 1}, "time": 1.0 },
      { "id": "farm_2", "name": "農村", "type": "normal_building", "cost": {"wood": 2, "wheat": 1}, "time": 1.5 },
      { "id": "forest_shack_2", "name": "森小屋", "type": "normal_building", "cost": {"wood": 1}, "time": 1.2 },
      { "id": "mine_2", "name": "採掘所", "type": "normal_building", "cost": {"stone": 1}, "time": 1.5 },
      { "id": "canteen_2", "name": "食堂", "type": "normal_building", "cost": {"wood": 2}, "time": 1.0 }
    ]
  }
}
```

#### 2. EconEconomy.gd 拡張
- `get_construction_cost(building_type: String) -> Dictionary`
- `get_construction_time(building_type: String) -> float`
- `get_building_effect(building_type: String) -> Dictionary`

---

### Phase 2: 建築基盤システム

**目的:** 建物カード使用 → 建設予定地指定 → 建設進捗 の基本フローを実装

**要件定義書参照:** §5.1～5.4

**実装対象:**

#### 1. BuildingSystem.gd（新規作成）
- 建設予定地の指定と管理
- 建設進捗の計算・更新
- 建設完了判定と建物稼働開始
- 人手不足時の停止処理

**公開メソッド:**
- `place_building(building_type: String, target_panel: Panel) -> bool`
- `update_construction_progress(delta: float) -> void`
- `check_construction_complete() -> Array`
- `on_labor_allocation_change(work_ratio: float) -> void`

#### 2. GameSession.gd 拡張
- `construction_sites: Dictionary` 追加（建設中の建物管理）
- `building_on_panel: Dictionary` 追加（完成済み建物パネルマッピング）

#### 3. EconBattle.gd 連携
- バトル開始時に初期デッキを hand に配置
- バトル中、各フレームで建設進捗を更新
- カード使用時に建設予定地指定UIを発火

---

### Phase 3: UI システム（建設中表現）

**目的:** 建物状態（未建設/建設中/稼働中）を視覚的に区別

**要件定義書参照:** §6.1～6.3

**実装対象:**

#### 1. BuildingStateOverlay.gd（新規作成）
- 建設中パネル上に半透明マスク (α=0.4) を表示
- リングゲージ（直径28px）で進捗を表示
- 稼働中パネル下部に稼働ドット（直径6px、緑または灰）を表示

#### 2. EconMain.gd 統合
- BuildingStateOverlay を UILayer に追加
- 毎フレーム建設状態を更新・再描画

---

### Phase 4: 人手スライダー UI

**目的:** 稼働人手と作業人手の配分を調整可能にする

**要件定義書参照:** §6.4、Designer企画 §10.3

**実装対象:**

#### 1. LaborSliderUI.gd（新規作成または既存拡張）
- フッター中央に LABOR ブロック（160×180px）を新設
- スライダーで稼働人手：作業人手の比率を10%刻みで選択
- 現在値表示（例：「作業: 50%」）

#### 2. EconBattle.gd 連携
- スライダー値変更時に `on_labor_allocation_change()` をトリガー

---

## 完了条件チェックリスト

企画書 §12 + 要件定義書 §7 をそのまま採用。以下30項目すべてが実装完了できること：

- [ ] 初期デッキ13枚を定義できる
- [ ] 建物カード（通常・特殊）の区別ができる
- [ ] 建物カード使用時に建設予定地を指定できる
- [ ] 建設コストを自動計算・支払いできる
- [ ] 建設時間を建物ごとに設定できる
- [ ] 建設進捗が時間経過で進む
- [ ] 人手配分により建設進捗が変化する
- [ ] 人手不足時に建設が停止する
- [ ] 建設完了時に建物が自動稼働する
- [ ] 稼働人手が建物効果に適用される
- [ ] 作業人手が建設進捗に適用される
- [ ] 人手スライダーで稼働/作業人手を配分できる
- [ ] 建設中パネルに半透明マスクが表示される
- [ ] 建設進捗リング（直径28px）が表示される
- [ ] 稼働中パネル下部に稼働ドット（直径6px）が表示される
- [ ] 建設中と稼働中が3秒で視覚的に区別できる
- [ ] 人手不足警告が表示される（数値赤点滅）
- [ ] 建物パネルのマッピングが正確である
- [ ] バトル開始時に手札が初期デッキで満たされる
- [ ] バトル終了時に建物状態が保持される
- [ ] 既存 COLOR_* 定数のみを使用している
- [ ] 新規色定義が0個である
- [ ] KISS 原則に従った実装になっている
- [ ] 疎結合ルール（メソッド経由）を遵守している
- [ ] BuildingSystem と EconBattle の連携が疎結合である
- [ ] EconEconomy への追加がフィールド増設ではなく関数追加である
- [ ] EconMain.gd が 800行を超えない
- [ ] 企画書と要件定義書の用語が完全に一致している
- [ ] check_syntax.sh でエラー0件
- [ ] Checker による要件整合性確認に合格

---

## 検証方法

実装完了後：

bash check_syntax.sh

全エラー0件を確認後、Checkerに以下を依頼：

- 要件定義書 §7 完了条件チェックリスト全項目
- 既存 EconBattle/EconEconomy との整合性
- 疎結合ルール（CLAUDE.md）準拠確認
- 新規ファイル（BuildingSystem等）の実装品質
- UI表現が企画書の3秒ルール、Designer企画と一致しているか

---

## 参考情報

### 既存ファイル構造
- scripts/econ_mvp/EconMain.gd: UI 統合点
- scripts/econ_mvp/EconBattle.gd: バトル連携
- scripts/econ_mvp/EconEconomy.gd: 経済値参照
- data/cards_econ.json: カードデータ（拡張対象）

### CLAUDE.md 重要ルール
- 疎結合ルール: 他クラスの内部配列への直接代入は禁止
- 用語統一: 設計文書と実装で同じ用語を使用
- 足し算禁止: 指示されていない効果・フィールド追加は禁止
- 3秒ルール: UI要素がバトル画面で3秒で伝わるか検証

---

## 特記事項

- **新規色定義は0個**: 既存 COLOR_* のみ使用（KISS原則）
- **建物状態の3区分**: 未建設/建設中/稼働中を明確に区別（停止中は派生表現）
- **リングゲージ**: 直径28px で手元パネルサイズ（72×100px）と整合
- **稼働ドット**: 直径6px で建物アイコン内に収まる（小さすぎない）
- **人手不足警告**: 数値の赤点滅のみ、新規アイコンは追加しない
