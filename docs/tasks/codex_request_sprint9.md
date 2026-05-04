# Codex実装リクエスト: Sprint 9 報酬・マイルストーン・宝箱システム

**作成日:** 2026-05-04  
**対象Sprint:** Sprint 9  
**実装優先度:** A（Phase 2コア機能）  
**参照資料:**
- 企画書確定版: `docs/sprint9_reward_milestone_chest_final.md`
- Designer企画書: `docs/design/sprint9_designer_plan.md`
- 要件定義書: `docs/requirements/REQUIREMENTS_SPRINT_9.md`

---

## 実装スコープ

### Phase 1: マイルストーンシステム基盤

**目的:** マイルストーン生成・追跡・達成判定の基本システムを実装

**要件定義書参照:** §4.1～4.2

**実装対象:**

#### 1. RewardSystemManager.gd（新規作成）
- マイルストーン生成アルゴリズム（初期難易度に応じた8系統×3段階＝24個生成）
- マイルストーン進捗追跡（バトル中の値から進捗を更新）
- マイルストーン達成判定（中難度は即時報酬発火、その他は記録のみ）
- マイルストーン即時報酬発火（各系統の中難度達成時）

**データ構造:**
```gdscript
class_name RewardSystemManager

var milestone_tracker: Dictionary = {}  # { "population": { "low": 0, "normal": 15, "high": 0 }, ... }
var special_milestones: Array = []      # [{ "system": "population", "difficulty": "low", "condition": ... }, ...]
var reward_selection_history: Array = []
```

**公開メソッド:**
- `generate_milestones(difficulty: String) -> void`
- `check_milestone_achievement(system: String, current_value: int, threshold: int) -> void`
- `get_immediate_reward(system: String) -> Dictionary`
- `offer_reward(system: String, difficulty: String) -> Array` （3択報酬を返す）

#### 2. GameSession.gd 拡張
- `GameSession.milestones: Dictionary` 追加
- `GameSession.special_milestones: Array` 追加
- `GameSession.current_battle_gold: int` 追加（通貨管理）

**初期難易度の通貨増減:**
- 低: +100G
- 中: ±0G
- 高: -100G

#### 3. EconBattle.gd 連携
- バトル開始時に初期難易度選択UI発火
- バトル中、各マイルストーンの達成判定をフックに組み込む
- 中難度達成時に即時報酬演出

---

### Phase 2: UIシステム（マイルストーンウィンドウ）

**目的:** ドラッグ可能なマイルストーン表示ウィンドウを実装

**要件定義書参照:** §5.3～5.4

**実装対象:**

#### 1. MilestoneWindow.gd（新規作成）
- PanelContainer ベース
- ドラッグ可能なウィンドウ（タイトルバーをドラッグ）
- 初期位置: x=1050, y=100（盤面右上）
- サイズ: 160×180px
- 上位3系統の進捗を常時表示
- ホバーで全8系統展開（任意）
- 特殊マイルストーン追加時に「+1 SPECIAL ◇」バッジ点滅

**座標・サイズ:**
- ウィンドウ全体: 160×180px
- タイトルバー: 160×20px
- コンテンツ領域: 160×160px
- マージン: 8px

**色定数（既存COLOR_*のみ使用）:**
- 背景: COLOR_PANEL (#231F1B), α=0.9
- ボーダー: COLOR_BORDER (#3C3628), 2px
- テキスト: COLOR_TEXT (#DCD2B9)
- ハイライト: COLOR_ACCENT_GOLD (#B49448)

**ドラッグ機能:**
- マウスダウン時に前面表示
- マウスドラッグでウィンドウ全体移動
- 画面外への移動は制限（クランプ処理）
- 位置を GameSession に保存

#### 2. EconMain.gd 統合
- MilestoneWindow を UILayer に追加
- バトル開始時にマイルストーン生成と同時に表示開始
- バトル終了時に非表示（報酬選択フェーズに移行）

---

### Phase 3: 報酬システム

**目的:** マイルストーン報酬と宝箱報酬の選択UIを実装

**要件定義書参照:** §4.3～4.5

**実装対象:**

#### 1. RewardSelectionUI.gd（新規作成）
- バトル後の全画面オーバーレイUI
- 3択カード形式で報酬提示（220×280pxカード）
- カード種別ごとの色分け（ボーダー色で識別）
- SKIPボタン機能

**報酬3択ロジック:**
- 通常マイルストーン報酬: 通常建物 : 特殊建物 : 政策 = 1:1:1
- 特殊マイルストーン報酬: 土地カード : 偉人カード : 特殊建物
- 各プール: `data/cards_econ.json` の `"reward_pools"` セクションから取得

#### 2. cards_econ.json 拡張
```json
{
  "reward_pools": {
    "normal_milestone_rewards": {
      "normal_building": [...],
      "special_building": [...],
      "policy_card": [...]
    },
    "special_milestone_rewards": {
      "land_card": [...],
      "great_person_card": [...],
      "special_building": [...]
    }
  }
}
```

#### 3. 宝箱システム (EconChest.gd)
- バトル開始時に盤面上に3つ自動配置
- 隣接パネルへの建設で自動取得
- 取得時に宝箱即時報酬とランダム付与
- 特殊マイルストーン1個追加

**宝箱即時報酬プール（完全ランダム）:**
- 木 +5, 石 +5, 小麦 +5, 樹脂 +3, 鉄鉱石 +3
- 食料値 +10, 満足値 +5%
- 建設中タイマー1件 +30%, バトル中兵力 +5%
- 通貨 +50G

---

### Phase 4: 土地カード配置モード

**目的:** マイルストーン報酬で取得した土地カードの配置UIを実装

**要件定義書参照:** §4.5

**実装対象:**

#### 1. LandCardPlacementController.gd（新規作成）
- 土地カード選択後に配置モード発動
- 配置可能マス（自建物隣接の未建設土地）をパルスハイライト
- クリックで1つ配置（確定・キャンセル不可）
- 配置不能カードは選択不可にする

**配置条件:**
- 自建物に隣接する未建設土地のみ配置可能
- 建設予定地・建設後パネルには配置不可

---

## 実装順序と依存関係

```
Phase 1: RewardSystemManager + GameSession拡張
  ↓（Phase 1完了後）
Phase 2: MilestoneWindow + EconMain統合
  ↓（Phase 2完了後）
Phase 3: RewardSelectionUI + EconChest + cards_econ.json拡張
  ↓（Phase 3完了後）
Phase 4: LandCardPlacementController
```

---

## 完了条件チェックリスト

企画書 §17 をそのまま採用。以下21項目すべてが実装完了できること：

```
- [ ] 初期難易度を低/中/高から選択できる
- [ ] 初期難易度に応じて通貨を増減できる
- [ ] 初期難易度に応じて各系統のマイルストーン提示レンジを切り替えられる
- [ ] 8系統×3段階の通常マイルストーンを生成できる
- [ ] 中難度マイルストーン達成時にマイルストーン即時報酬をバトル中に発生できる
- [ ] 極低/低/高/極高マイルストーン達成時にバトル後の通常マイルストーン報酬対象として記録できる
- [ ] 通常マイルストーン報酬で通常建物・特殊建物・政策カードを3択提示できる
- [ ] 通常マイルストーン報酬に土地カードを含めない
- [ ] 宝箱を1バトル3つ配置できる
- [ ] 宝箱に隣接するパネルへ建設した時に自動取得できる
- [ ] 宝箱取得時に宝箱即時報酬を完全ランダムで付与できる
- [ ] 宝箱取得時に特殊マイルストーンを1つ追加できる
- [ ] 特殊マイルストーン達成時に特殊マイルストーン報酬対象として記録できる
- [ ] 特殊マイルストーン報酬で土地カード・偉人カード・特殊建物カードを3択提示できる
- [ ] 土地カード選択時に対象資源・資源値を確認できる
- [ ] 土地カード選択後に配置モードへ移行できる
- [ ] 土地カードを自建物に隣接する未建設土地へ配置できる
- [ ] 建設予定地・建設後パネルには土地カードを配置できない
- [ ] 配置不能な土地カードを選択不可にできる
- [ ] 報酬をスキップできる
- [ ] 報酬を留保できない
```

---

## 検証方法

実装完了後：

```bash
bash check_syntax.sh
```

全エラー0件を確認後、Checkerに以下を依頼：

```
- 要件定義書 §7 完了条件チェックリスト全項目
- 既存EconBattle/EconEconomyとの整合性
- 疎結合ルール（CLAUDE.md）準拠確認
- 新規ファイル（RewardSystemManager等）の実装品質
```

---

## 参考情報

### 既存ファイル構造
- `scripts/econ_mvp/EconMain.gd`: 統合点
- `scripts/econ_mvp/EconBattle.gd`: バトル連携
- `scripts/econ_mvp/EconEconomy.gd`: 経済値参照
- `scripts/econ_mvp/EconUI.gd`: UI基盤（参考）
- `data/cards_econ.json`: カードデータ（拡張対象）

### CLAUDE.md重要ルール
- 疎結合ルール: 他クラスの内部配列への直接代入は禁止
- 用語統一: 設計文書と実装で同じ用語を使用
- 足し算禁止: 指示されていない効果・フィールド追加は禁止
- 3秒ルール: UI要素がバトル画面で3秒で伝わるか検証

---

## 特記事項

- **新規色定義は0個**: 既存COLOR_*のみ使用（KISS原則）
- **ウィンドウドラッグ**: 位置をGameSessionに永続化（通しプレイ対応）
- **宝箱配置**: 自軍/敵軍の中距離+中央配置（企画書§12参照）
- **土地カード配置**: ドラッグなし、クリック1回で確定・キャンセル不可
