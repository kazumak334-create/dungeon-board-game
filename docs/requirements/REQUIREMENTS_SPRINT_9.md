# Sprint 9 要件定義書 — 報酬・マイルストーン・宝箱システム

ステータス: 実装リソース（一時）
対応Sprint: Sprint 9
参照Final企画書: `docs/sprint9_reward_milestone_chest_final.md`（SSoT）
参照Designer企画書: `docs/design/sprint9_designer_plan.md`
統合先: `docs/requirements/REQUIREMENTS_V0_2_MVP.md`（Sprint 9 セクション）
作成日: 2026-05-04
更新日: 2026-05-04

---

## 1. 目的・背景

### 1.1 目的
バトルごとの成長報酬を「マイルストーン報酬」と「宝箱」によって構成し、バトル中のプレイ目標を明確化する。達成内容に応じたカード・土地・特殊報酬を獲得できる報酬基盤を実装する。

### 1.2 核となる体験との整合
- 報酬は「次の盤面設計の素材」として位置付ける（足し算ではなく盤面再設計の選択肢）
- マイルストーンは「介入の指針」として表示する（プレイヤーが何を狙うかの明確化）
- 即時報酬演出はバトル進行を止めない（観戦体験を損なわない）

### 1.3 背景
Sprint 8までで都市運営・バトル骨格が完成。Sprint 9でラン構造の核となる「成長サイクル（バトル → 報酬 → 次バトル）」を確立する。

---

## 2. 用語定義

企画書 §2 をそのまま採用。

| 用語 | 定義 |
|---|---|
| 通常資源 | 木・樹脂・石・鉄鉱石・小麦・綿花。バトル中の建築・建物稼働に使う。原則としてバトル間で持ち越さない。 |
| 通貨 | ラン中に保持される通常通貨。マイルストーン難易度選択、将来のショップ、カード削除、イベントなどに使う。リロールには使わない。 |
| 初期難易度 | バトル開始時に選ぶ難易度。低・中・高の3段階。各系統で提示されるマイルストーン難易度レンジと通貨増減を決める。 |
| マイルストーン | バトル中に達成を狙う目標。8系統ごとに、初期難易度に応じた3段階が提示される。 |
| 通常マイルストーン | バトル開始時に提示される基本マイルストーン。 |
| 特殊マイルストーン | 宝箱取得などで追加される追加マイルストーン。 |
| マイルストーン報酬 | マイルストーン達成により得る報酬の総称。通常マイルストーン報酬・特殊マイルストーン報酬・マイルストーン即時報酬に分かれる。 |
| 通常マイルストーン報酬 | 通常マイルストーン達成時に得るバトル後の選択式カード報酬。 |
| 特殊マイルストーン報酬 | 特殊マイルストーン達成時に得るバトル後の選択式報酬。通常より強めの報酬にする。 |
| マイルストーン即時報酬 | 8系統それぞれの中難度マイルストーン達成時に、バトル中に即時発生するサポート報酬。カード報酬には統合しない。 |
| 宝箱 | バトルパネル上に初期配置される報酬オブジェクト。宝箱に隣接するパネルへ建設すると自動取得される。 |
| 宝箱即時報酬 | 宝箱取得時に完全ランダムで即時付与される報酬。 |
| 通常建物カード | 使用後に捨て札/山札循環へ戻る建物カード。 |
| 特殊建物カード | 使用後に捨て札へ行かず除外される建物カード。建物自体は盤面に残る場合がある。 |
| 政策カード | 一時効果または戦略選択を与えるカード。詳細仕様は後続Sprintで拡張する。 |
| 偉人カード | 永続効果によりビルド方針を変えるカード。詳細仕様は後続Sprintで実装する。 |
| 土地カード | マイルストーン報酬で獲得できる土地拡張カード。獲得時点で対象資源と資源値が分かる。 |
| 未建設土地 | 建物が建っておらず、建設予定地にもなっていない土地。 |
| 自領地 | 自建物から3マス以内の未建設土地。 |

---

## 3. スコープ

### 3.1 対象機能（実装対象）

| 機能 | 概要 |
|---|---|
| 初期難易度選択 | バトル開始前に低・中・高の3択。通貨増減を反映 |
| マイルストーン生成 | 8系統 × 3段階 = 24個 |
| マイルストーン進捗追跡 | バトル中の値から各系統の進捗を更新 |
| マイルストーン達成判定 | 中難度は即時報酬発火、それ以外は記録のみ |
| マイルストーン即時報酬 | 中難度達成時にバトル中で即時発生 |
| 通常マイルストーン報酬 | バトル後の3択カード選択（通常建物・特殊建物・政策カード） |
| 特殊マイルストーン報酬 | バトル後の3択カード選択（土地・偉人・特殊建物） |
| 宝箱配置 | バトル開始時に3つ自動配置 |
| 宝箱取得 | 隣接パネル建設で自動取得 |
| 宝箱即時報酬 | 完全ランダム1種 |
| 特殊マイルストーン追加 | 宝箱取得で1個追加 |
| 土地カード配置モード | 自建物隣接の未建設土地へ1クリック配置 |
| 報酬スキップ | 各報酬選択でSKIP可能 |

### 3.2 非対象機能（後続Sprint / MVP外）

企画書 §16 をそのまま採用。

- 悪魔の釜型の詳細係数
- 失敗時ペナルティ
- ショップ
- カード削除
- イベントでの通貨使用
- 報酬レアリティ詳細
- 住宅上位建物の詳細実装
- 偉人カードの詳細実装
- 政策カードの大量追加
- 特殊ユニット報酬
- 敵による宝箱取得
- 報酬まとめ選択UIの高度化
- 報酬留保（企画書 §15: 留保なし）
- リロール（通貨はリロール用途では使わない）

---

## 4. 機能要件

### 4.1 初期難易度選択

#### 4.1.1 提示仕様

**要件:** ラン開始時、バトル開始前に「低 / 中 / 高」を3択カードで提示する。

| 難易度 | 通貨増減 | 系統別マイルストーン提示レンジ |
|---|---|---|
| 低 | +100G | 極低 / 低 / 中 |
| 中 | ±0G | 低 / 中 / 高 |
| 高 | -100G | 中 / 高 / 極高 |

通貨増減は初期難易度にのみ紐づく（個別マイルストーン難易度には紐づかない）。

**実装ポイント（Implementer向け）:**
- `RewardSystemManager.set_initial_difficulty(difficulty: String)` を新規実装
- `GameSession.initial_difficulty: String` を追加
- 通貨増減は `GameSession.currency` に即時反映（既存通貨フィールドを利用）
- 提示UIは新規シーンまたは EconMain 内に追加

#### 4.1.2 完了条件
- 低 / 中 / 高 のいずれか1つを必ず選択（スキップ不可）
- 選択後、対応する通貨増減を反映
- 選択後、対応するレンジで通常マイルストーン24個を生成

---

### 4.2 マイルストーン

#### 4.2.1 マイルストーン生成

**要件:** 初期難易度に基づき、8系統 × 3段階 = 24個の通常マイルストーンを生成する。

8系統:
- 人口系 (population)
- 食料系 (food)
- 満足度系 (satisfaction)
- 建築系 (building)
- 資源系 (resource)
- 兵力系 (troop)
- 土地系 (land)
- リスク系 (risk)

各系統に対して、初期難易度に応じた3段階（極低/低/中、低/中/高、中/高/極高）の数値マイルストーンを生成する。

**実装ポイント（Implementer向け）:**
- `RewardSystemManager.generate_milestones(difficulty: String) -> void`
- `GameSession.milestones: Dictionary` にデータを保持
- 各系統の数値テーブルは `MilestoneDefinition.gd` に定義（または `data/milestones.json`）
- 数値バランスはSprint 9実装フェーズ内で確定（残論点 §9参照）

#### 4.2.2 マイルストーン進捗追跡

**要件:** バトル中、各系統の現在値を5秒tick（既存tick）で取得し、進捗を更新する。

| 系統 | 進捗参照先（既存フィールド・取得経路） |
|---|---|
| 人口系 | `EconEconomy.population` |
| 食料系 | `EconEconomy.food_value` |
| 満足度系 | `EconEconomy.satisfaction_value` |
| 建築系 | `EconGrid` 上の建設済み建物数（既存カウント可能ロジックを利用） |
| 資源系 | 通常資源累積採取量（新規カウンタを `EconEconomy` に追加） |
| 兵力系 | `EconBattle` 自軍兵力合計（既存集計を利用） |
| 土地系 | 土地拡張回数（土地カード配置回数 + 既存土地カウント） |
| リスク系 | 制約付き条件達成記録（個別条件は実装フェーズで確定） |

**実装ポイント:**
- `RewardSystemManager.update_progress(system: String, current_value: int) -> void`
- 既存5秒tick（`EconEconomy.gd`）から `RewardSystemManager` を呼び出す
- 累積カウンタが必要な系統（資源系・土地系）は新規フィールドを追加（資源カウンタは `EconEconomy.cumulative_resource_collected: Dictionary`）

#### 4.2.3 マイルストーン達成判定

**要件:** 進捗が条件閾値を超えた瞬間に達成とする。

| 達成段階 | バトル中処理 | バトル後処理 |
|---|---|---|
| 極低 | 記録のみ | 通常マイルストーン報酬対象として記録 |
| 低 | 記録のみ | 通常マイルストーン報酬対象として記録 |
| 中 | **マイルストーン即時報酬を発火** | 通常マイルストーン報酬には含めない |
| 高 | 記録のみ | 通常マイルストーン報酬対象として記録 |
| 極高 | 記録のみ | 通常マイルストーン報酬対象として記録 |
| 特殊マイルストーン | 記録のみ | 特殊マイルストーン報酬対象として記録 |

中難度マイルストーン達成時はマイルストーン即時報酬のみ。中難度達成時にバトル後カード報酬は発生しない（企画書 §7）。

**実装ポイント:**
- `RewardSystemManager.check_milestone_achievement(system: String, current_value: int) -> void`
- 達成済みフラグは `GameSession.achieved_milestones: Array` に記録
- バトル終了時、達成済みリストをバトル後報酬選択フローへ渡す

#### 4.2.4 マイルストーン即時報酬

**要件:** 中難度マイルストーン達成時にバトル中で即時発生する。

| 系統 | 中難度即時報酬 |
|---|---|
| 人口系 | 人口 +10 |
| 食料系 | 食料値 +10 |
| 満足度系 | 満足値 +10% |
| 建築系 | 建設中タイマーを全建物 +20%進める |
| 資源系 | 通常資源からランダム1種 +5 |
| 兵力系 | そのバトル中、兵力 +10% |
| 土地系 | 自領地内の未建設土地ランダム1マスに特殊資源を発生（候補：香辛料・硫黄） |
| リスク系 | 通貨 +100G |

**実装ポイント:**
- `RewardSystemManager.apply_immediate_reward(system: String) -> void`
- 各効果は既存の対応フィールドへ即時反映（食料値→`EconEconomy.food_value` など）
- 兵力 +10% は「そのバトル中限定」のバフフィールド（`EconBattle.troop_buff_multiplier`）として実装
- 建設中タイマー +20% は `EconBuilding.construction_progress` を全建物分加算
- UI演出は §5.3.4 参照

---

### 4.3 報酬システム

#### 4.3.1 通常マイルストーン報酬

**要件:** 通常マイルストーン（極低/低/高/極高）達成時、バトル後に3択カードを提示する。

カード比率: 通常建物 : 特殊建物 : 政策 = 1 : 1 : 1

含めない: 土地カード・偉人カード・通常資源・即時補助報酬

**実装ポイント:**
- `RewardSystemManager.offer_normal_reward(system: String, difficulty: String) -> Array[Dictionary]`
- 戻り値は3要素配列。各要素は `{ "card_type": String, "card_id": String, "data": Dictionary }`
- 系統別報酬カードプールから3枚をランダム抽選（重複なし）
- カードプールは `data/cards_econ.json` の `reward_pools.normal_milestone_rewards` から取得

#### 4.3.2 特殊マイルストーン報酬

**要件:** 特殊マイルストーン達成時、バトル後に3択カードを提示する。

カード種別: 土地カード / 偉人カード / 特殊建物カード

特殊マイルストーン報酬は強めの報酬とする（バランス調整は実装フェーズ）。

**実装ポイント:**
- `RewardSystemManager.offer_special_reward() -> Array[Dictionary]`
- カードプールは `data/cards_econ.json` の `reward_pools.special_milestone_rewards` から取得
- 配置可能マスが0個の土地カードは選択不可表示（§4.5.4 参照）

#### 4.3.3 報酬選択フロー

```
バトル終了
  ↓
達成マイルストーン一覧を取得（達成順）
  ↓
通常マイルストーン報酬 1個目 → 3択選択UI（or SKIP）
  ↓
... 達成数だけ繰り返し
  ↓
特殊マイルストーン報酬（あれば）→ 3択選択UI
  ↓
土地カードを選択した場合 → [配置モード]へ遷移
  ↓
全報酬処理完了 → 次バトル準備フェーズへ
```

**実装ポイント:**
- `RewardFlowController.gd`（新規）で報酬提示の順序制御
- 各報酬選択結果は `GameSession.reward_selection_history` に記録
- スキップ時は破棄（留保なし）

#### 4.3.4 系統ごとの報酬カードプール

| 系統 | 主な報酬カード候補 |
|---|---|
| 人口系 | 住宅 / 移住奨励 / 将来：集合住宅・居住区 |
| 食料系 | 農村 / 食堂 / 製粉所 / 配給制 |
| 満足度系 | 広場 / 祭典 / 将来：レストラン・市場 |
| 建築系 | 森小屋 / 採掘所 / 住宅 / 交換所 / 建設動員 |
| 資源系 | 森小屋 / 採掘所 / 製粉所 / 採取強化 |
| 兵力系 | 兵舎 / 徴兵令 / 将来：鍛冶屋・厩舎・火薬工房 |
| 土地系 | 農村 / 森小屋 / 採掘所 / 交換所 / 測量令 |
| リスク系 | 交換所 / ドロー系特殊建物 / 一時補助系特殊建物 / 非常令 |

カードプールの最終枚数はSprint 9実装フェーズで確定（残論点 §9参照）。

---

### 4.4 宝箱システム

#### 4.4.1 宝箱配置

**要件:** バトル開始時、盤面に3つ自動配置する。

配置位置:
- 自軍/敵軍から中距離の位置に2つ
- 中央/遠距離寄りの位置に1つ

宝箱はUIではなく盤面上の固定オブジェクト（企画書 §12）。

**実装ポイント:**
- `EconChest.gd`（新規）を `EconGrid` 上に配置
- バトル開始時 `EconBattle.setup_chests()` で3つ生成
- 具体的な配置座標は `EconGrid` のサイズに応じて算出（実装フェーズで定義）
- MVPでは敵は宝箱を取得しない

#### 4.4.2 宝箱取得

**要件:** 宝箱に隣接するパネルへ建設完了した時点で自動取得。

```
建設完了
  ↓
建物の隣接マスに宝箱があるか判定
  ↓
あり → 宝箱即時報酬を発動 + 特殊マイルストーンを1つ追加
  ↓
宝箱オブジェクト消滅（フェードアウト）
```

**実装ポイント:**
- `EconBuilding._on_construction_complete()` 内で隣接判定 + 取得処理
- `EconChest.acquire() -> Dictionary` で取得結果を返す（即時報酬内容含む）
- 隣接判定は `EconGrid.is_adjacent(pos_a, pos_b)` を新規追加または既存ロジック流用

#### 4.4.3 宝箱即時報酬

**要件:** 宝箱取得時、以下の候補プールから完全ランダムで1種を付与。

| 候補 | 効果 |
|---|---|
| 木 +5 | 即時獲得 |
| 石 +5 | 即時獲得 |
| 小麦 +5 | 即時獲得 |
| 樹脂 +3 | 即時獲得 |
| 鉄鉱石 +3 | 即時獲得 |
| 食料値 +10 | 即時獲得 |
| 満足値 +5% | 即時獲得 |
| 建設中タイマー1件 +30% | 即時適用（任意1建物） |
| そのバトル中、兵力 +5% | 即時適用 |
| 通貨 +50G | 即時獲得 |

**実装ポイント:**
- `RewardSystemManager.roll_chest_reward() -> Dictionary`
- 候補プールは `data/cards_econ.json` の `reward_pools.chest_rewards` に定義
- 出現率はSprint 9実装フェーズで確定（残論点 §9参照）

#### 4.4.4 特殊マイルストーン追加

**要件:** 宝箱取得時、特殊マイルストーンを1つ追加する。

**実装ポイント:**
- `RewardSystemManager.add_special_milestone() -> void`
- 特殊マイルストーンの具体条件は実装フェーズで確定（残論点 §9参照）
- `GameSession.special_milestones: Array` に追加
- FOOTER右下に `[+1]` バッジで通知（§5.3.5 参照）

---

### 4.5 土地カード

#### 4.5.1 土地カードデータ

**要件:** 土地カードは獲得時点で以下が判明している。

- 対象資源
- 資源値
- 複合資源の有無
- 特殊タグの有無

**実装ポイント:**
- `data/cards_econ.json` の `reward_pools.special_milestone_rewards.land_card` に定義
- データ構造は §6.3 参照

#### 4.5.2 配置条件

**要件:** 自建物に隣接する未建設土地のみ配置可能。

**配置可能:**
- 自建物に隣接するパネル
- かつ未建設土地である

**配置不可:**
- 自建物に隣接していない土地
- 建設予定地（建設中の土地）
- 建設後パネル（建物が建っている）
- 配置可能な土地が存在しない場合

**実装ポイント:**
- `LandCardPlacementController.get_placeable_cells() -> Array[Vector2i]`
- 隣接判定は `EconGrid.get_adjacent_cells(pos)` を利用（または新規追加）
- 「建設中」「建設後」状態は `EconGrid.cell_state[pos]` から取得

#### 4.5.3 配置モード（1クリック確定）

**要件:** 土地カード選択後、配置モードに移行し、1クリックで確定する（ドラッグなし、確定ボタンなし、キャンセル不可）。

```
土地カード選択
  ↓
報酬選択UI消去
  ↓
通知バナー上部スライドイン (300ms)
  "土地カードを自建物隣接マスへ配置してください"
  ↓
配置可能マスをパルスアニメーションでハイライト
  ↓
プレイヤーが配置可能マスをクリック
  ↓
土地カードがマスにフェードイン (200ms)
  ↓
配置確定（自動）
  ↓
GameSession.land_cards にレコード追加
  ↓
次の報酬処理へ
```

**実装ポイント:**
- `LandCardPlacementController.gd`（新規）
- `LandCardPlacementController.enter_placement_mode(card_data: Dictionary) -> void`
- `LandCardPlacementController.on_cell_clicked(pos: Vector2i) -> void`
- `GameSession.land_cards: Array[Dictionary]` に追加

#### 4.5.4 配置不能カードの選択不可

**要件:** 配置可能マスが0個の土地カードは、3択提示時点で選択不可表示にする（α=0.5、ホバーでツールチップ「配置可能マスなし」）。

**実装ポイント:**
- `RewardSystemManager.offer_special_reward()` 内で各土地カードに `is_placeable` フラグを付与
- UI側で `is_placeable == false` のカードは選択不可表示

---

## 5. UI/UX要件

Designer企画書（`docs/design/sprint9_designer_plan.md`）を参照のこと。本セクションでは座標・サイズ・色など実装に必要な情報のみ集約する。

### 5.1 全体方針

- 既存EconMain.gdの色定数（`COLOR_*`）のみ使用。**新規色定義は0個**
- 既存BUILDカード形状・装飾線スタイルを継承
- バトル中は情報過多防止のためマイルストーン進捗を上位3系統に絞る

### 5.2 画面領域（ドラッグ可能ウィンドウ）

```
┌───────────────────────────────────────┐
│ HEADER (既存)                    56px │
├───────────────────────────────────────┤
│                                       │
│ BOARD (既存)                   484px  │
│  - 宝箱は盤面上に直接アイコン配置     │
│  - 即時報酬テロップは盤面中央上部     │
│                                       │
│                  ┌─────────────┐      │
│                  │ MILESTONE ◇ │      │
│                  │ (ドラッグ可) │      │
│                  │ POP ▓▓░     │      │
│                  │ FOOD ▓▓▓░   │      │
│                  │ SAT ▓░░     │      │
│                  └─────────────┘      │
│                                       │
├───────────────────────────────────────┤
│ FOOTER                          180px │
│ ┌──────┬─────┬──────────────────────┐│
│ │HARV  │BUILD│ (MILESTONE別ウィンドウ)││
│ │700px │420px│                      ││
│ └──────┴─────┴──────────────────────┘│
└───────────────────────────────────────┘
```

### 5.3 MILESTONEウィンドウ仕様

| 項目 | 値 |
|---|---|
| **形態** | ドラッグ可能な独立ウィンドウ（PanelContainer） |
| **サイズ** | 160 × 180 px |
| **初期位置** | x: 1050, y: 100（盤面右上） |
| **タイトルバー** | 「MILESTONE」+ ドラッグハンドル（◇） |
| **背景色** | COLOR_PANEL (#231F1B), α=0.9 |
| **ボーダー** | COLOR_BORDER (#3C3628), 2px |
| **表示内容** | 進捗が近い上位3系統（プログレスバー + 数値） |
| **特殊バッジ** | 宝箱取得で「+1 SPECIAL ◇」点滅表示 |

### 5.4 ドラッグ機能

| 機能 | 詳細 |
|---|---|
| **マウス操作** | タイトルバーをドラッグしてウィンドウ移動 |
| **前面表示** | マウスダウン時に他ウィンドウより手前に移動 |
| **画面境界制限** | ウィンドウが画面外に出ないようクランプ処理 |
| **位置保存** | GameSession に位置を保存（通しプレイで位置を保持） |

### 5.3 各UI要素仕様

#### 5.3.1 初期難易度選択UI（バトル開始前）

| 項目 | 仕様 |
|---|---|
| 配置 | 画面中央、半透明オーバーレイ (α=0.85) |
| カードサイズ | 220 × 280 |
| カード3枚配置 | 横並び、間隔24px |
| 通貨増減ハイライト | 低: COLOR_WOOD系、中: COLOR_TEXT、高: COLOR_RED |
| 操作 | 1クリック確定、SKIP不可 |

#### 5.3.2 マイルストーン常時表示（FOOTER右160px）

| 項目 | 仕様 |
|---|---|
| サイズ | 160 × 180 |
| ヘッダー | "— MILESTONE —"（10px） |
| 表示行数 | 進捗が近い上位3系統 |
| 系統名表記 | 3-4文字大文字略称（POP/FOOD/SAT等） |
| 進捗バー | 3 segment ブロック表示 |
| 数値 | "12/30" 形式 |
| 達成時表示 | バーが COLOR_ACCENT_GOLD で満タン |
| 特殊マイルストーン追加バッジ | 右下 `[+N]`、点滅（500msサイクル） |
| ホバー | 全8系統表示（任意） |

**実装ポイント:**
- `EconMilestonePanel.gd`（新規）
- 上位3系統の選定ロジック: `(current / threshold)` の値が大きい順

#### 5.3.3 バトル後報酬選択UI（オーバーレイ）

| 項目 | 仕様 |
|---|---|
| オーバーレイ | 全画面、半透明 (α=0.85) |
| カードサイズ | 220 × 280 |
| 配置 | 画面中央 (x: 320–960, y: 200–480) |
| カード間隔 | 24px |
| SKIPボタン | 80 × 32、3カード下中央 (x: 600, y: 510) |
| フェードイン | 300ms |

**カード本体レイアウト（220 × 280）:**
```
┌──────────────────┐
│  [TYPE BADGE]    │ 16px ヘッダー
├──────────────────┤
│      ICON        │ 120px アイコン領域
│      48px        │
├──────────────────┤
│ カード名          │ 20px (font_size=16, Bold)
│ ─────────        │
│ 説明文1行目       │ font_size=11
│ 説明文2行目       │
│ COST: 20W·10S   │ font_size=10, COLOR_TEXT_DIM
└──────────────────┘
```

**カード種別別ボーダー色:**

| 種別 | ボーダー色 | アイコン |
|---|---|---|
| 通常建物カード | COLOR_BORDER (#3C3628) | 既存建物アイコン |
| 特殊建物カード | COLOR_ACCENT_GOLD (#B49448) 1px | 既存建物アイコン + 右上に星マーク |
| 政策カード | COLOR_POP (#5D8FB8) 1px | 巻物アイコン |
| 偉人カード | COLOR_SAT (#B89AC7) 1px | 王冠アイコン |
| 土地カード | COLOR_WOOD (#3F6932) 1px | 大地アイコン + 資源タグ |

#### 5.3.4 即時報酬テロップ（バトル中）

| 項目 | 仕様 |
|---|---|
| 配置 | 盤面中央上部 (x: 中央, y: 100) |
| 背景 | COLOR_PANEL with α=0.85 |
| ボーダー | COLOR_ACCENT_GOLD 1px |
| 表示時間 | 1500ms (in 200ms / hold 1000ms / out 300ms) |
| 見出し | font_size=16, Bold, 系統色（または COLOR_ACCENT_GOLD） |
| 内容 | font_size=14, COLOR_TEXT |

**マイルストーン即時報酬テロップ例:**
```
┌──────────────────────────────────┐
│  POPULATION MILESTONE            │ POP色 (#5D8FB8)
│  人口 +10                         │
└──────────────────────────────────┘
```

**宝箱取得テロップ例:**
```
┌──────────────────────────────────┐
│  CHEST OBTAINED                  │ COLOR_ACCENT_GOLD
│  ─────────────                  │
│  木 +5                            │
│  +1 SPECIAL MILESTONE            │
└──────────────────────────────────┘
```

#### 5.3.5 宝箱演出

| フェーズ | 仕様 |
|---|---|
| パーティクル放射 | 500ms、COLOR_ACCENT_GOLDベース |
| テロップ表示 | 1500ms (§5.3.4 参照) |
| 宝箱アイコン消滅 | 300ms フェードアウト |
| 全体所要時間 | 約2秒 |

**宝箱アイコン:**
- サイズ: 24×24
- 色: COLOR_ACCENT_GOLD
- 形状: 木箱風アイコン（⛁ または既存アイコン流用）

#### 5.3.6 土地カード配置モード

| 状態 | 表現 |
|---|---|
| 配置可能（自建物隣接・未建設） | 枠線 COLOR_WOOD 2px + パルスアニメ (α 0.5↔1.0、1.0sサイクル) |
| 配置不可（自建物非隣接） | 枠線なし（通常表示） |
| 配置不可（建設予定地・建設後パネル） | 枠線 COLOR_RED 1px + α=0.3 |
| ホバー中の配置可能マス | 枠線 COLOR_ACCENT_GOLD 3px |

**通知バナー:**
- サイズ: 1280 × 48
- 配置: 上部、スライドイン (300ms)
- テキスト: "土地カードを自建物隣接マスへ配置してください"

**HEADER/FOOTER暗転:**
- 配置モード中は α=0.4

**配置不可マスをクリック時:**
- クリック非反応
- 一瞬画面端に "配置不可" 文字をフラッシュ表示（500ms）

### 5.4 タイポグラフィ統一

| 用途 | サイズ | ウェイト | 色 |
|---|---|---|---|
| 報酬カードタイトル | 16px | Bold | COLOR_TEXT |
| 報酬カード説明 | 11px | Regular | COLOR_TEXT |
| 報酬カードコスト | 10px | Regular | COLOR_TEXT_DIM |
| TYPE BADGE | 10px | Bold | カード種別色 |
| マイルストーン進捗系統名 | 11px | Bold | カード種別色（系統色） |
| マイルストーン進捗数値 | 11px | Regular | COLOR_TEXT |
| テロップ見出し | 16px | Bold | COLOR_ACCENT_GOLD（または系統色） |
| テロップ内容 | 14px | Regular | COLOR_TEXT |
| SKIPボタン | 12px | Regular | COLOR_TEXT_DIM |

---

## 6. データ仕様

### 6.1 マイルストーン

#### 6.1.1 GameSession 拡張フィールド

```gdscript
# GameSession 追加フィールド
var initial_difficulty: String = ""           # "low" | "normal" | "high"
var milestones: Dictionary = {}               # 通常マイルストーン24個
var special_milestones: Array = []            # 特殊マイルストーン
var achieved_milestones: Array = []           # 達成済み記録
var reward_selection_history: Array = []      # 選択履歴
var land_cards: Array = []                    # 配置済み土地カード
```

#### 6.1.2 milestones 構造

```gdscript
# milestones[system_key] = { difficulty_key: { threshold, achieved } }
{
  "population": {
    "very_low":  { "threshold": 10, "achieved": false },
    "low":       { "threshold": 20, "achieved": false },
    "normal":    { "threshold": 0,  "achieved": false },  # 中難度（即時報酬発火枠）
    "high":      { "threshold": 0,  "achieved": false },
    "very_high": { "threshold": 0,  "achieved": false }
  },
  ...
}
```

各系統につき、初期難易度に応じた3段階のみ `threshold` が有効。それ以外は `0` または未生成。

#### 6.1.3 achieved_milestones レコード

```gdscript
{
  "system": "population",       # 系統キー
  "difficulty": "low",          # 達成難易度
  "battle_id": 1,               # 達成バトル番号
  "is_special": false           # 特殊マイルストーン or 通常
}
```

#### 6.1.4 reward_selection_history レコード

```gdscript
{
  "round": 1,                   # ラン中バトル番号
  "system": "food",             # 達成系統
  "difficulty": "low",          # 達成難易度
  "is_special": false,
  "options": [card_id_1, card_id_2, card_id_3],  # 提示3択
  "selected": "farm",           # 選択ID（"" ならスキップ）
  "skipped": false
}
```

### 6.2 報酬プール

#### 6.2.1 cards_econ.json の追加セクション

```json
{
  "reward_pools": {
    "normal_milestone_rewards": {
      "normal_building": [
        { "card_id": "house", "weight": 1, "system": "population" },
        ...
      ],
      "special_building": [
        { "card_id": "exchange_post", "weight": 1, "system": "risk" },
        ...
      ],
      "policy_card": [
        { "card_id": "migration_promotion", "weight": 1, "system": "population" },
        ...
      ]
    },
    "special_milestone_rewards": {
      "land_card": [
        { "card_id": "land_wood_3", "weight": 1, "resource": "wood", "value": 3, "tags": [] },
        ...
      ],
      "great_person_card": [
        { "card_id": "great_builder", "weight": 1, "effect": "construction_speed_+20%" },
        ...
      ],
      "special_building": [
        { "card_id": "spice_grand_market", "weight": 1, "system": "satisfaction" },
        ...
      ]
    },
    "chest_rewards": [
      { "reward_type": "resource", "resource": "wood", "value": 5, "weight": 1 },
      { "reward_type": "resource", "resource": "stone", "value": 5, "weight": 1 },
      { "reward_type": "resource", "resource": "wheat", "value": 5, "weight": 1 },
      { "reward_type": "resource", "resource": "resin", "value": 3, "weight": 1 },
      { "reward_type": "resource", "resource": "iron", "value": 3, "weight": 1 },
      { "reward_type": "food_value", "value": 10, "weight": 1 },
      { "reward_type": "satisfaction_pct", "value": 5, "weight": 1 },
      { "reward_type": "construction_boost", "value": 30, "target": "single", "weight": 1 },
      { "reward_type": "troop_buff", "value": 5, "duration": "battle", "weight": 1 },
      { "reward_type": "currency", "value": 50, "weight": 1 }
    ]
  }
}
```

カードプールの最終枚数・出現率はSprint 9実装フェーズで確定（残論点 §9参照）。

### 6.3 土地カード

#### 6.3.1 土地カードレコード

```gdscript
# data/cards_econ.json reward_pools.special_milestone_rewards.land_card 内
{
  "card_id": "land_wood_3",
  "resource": "wood",           # "wood" | "stone" | "wheat" | "resin" | "iron" | "cotton" | "spice" | "sulfur"
  "value": 3,                   # 資源値
  "secondary_resource": null,   # 複合資源（null または resource文字列）
  "secondary_value": 0,
  "tags": []                    # 特殊タグ ["mountain", "river"等]
}
```

#### 6.3.2 配置済み土地カード（GameSession.land_cards）

```gdscript
{
  "card_id": "land_wood_3",
  "placed_at": Vector2i(3, 5),  # EconGrid座標
  "battle_round": 2             # 配置バトル番号
}
```

### 6.4 宝箱

#### 6.4.1 EconChest インスタンス

```gdscript
# EconChest.gd
class_name EconChest extends Node2D

var grid_pos: Vector2i
var acquired: bool = false

func acquire() -> Dictionary:
    # 即時報酬を抽選して返す
    pass
```

#### 6.4.2 宝箱配置レコード（EconBattle 保持）

```gdscript
var chests: Array[EconChest] = []  # バトル開始時に3つ生成
```

---

## 7. 完了条件チェックリスト

企画書 §17 をそのまま採用。

- [ ] 初期難易度を低/中/高から選択できる
- [ ] 初期難易度に応じて通貨を増減できる
- [ ] 初期難易度に応じて各系統のマイルストーン提示レンジを切り替えられる
- [ ] 8系統×3段階の通常マイルストーンを生成できる
- [ ] 中難度マイルストーン達成時にマイルストーン即時報酬をバトル中に発生できる
- [ ] 極低/低/高/極高マイルストーン達成時に、バトル後の通常マイルストーン報酬対象として記録できる
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

---

## 8. 実装フロー・優先度

### Phase 1: マイルストーンシステム基盤（依存なし）

| # | タスク | 対象ファイル | 依存 |
|---|---|---|---|
| 1.1 | GameSession 拡張フィールド追加 | `EconMain.gd`または新規 `GameSession.gd` | - |
| 1.2 | `RewardSystemManager.gd` 新規作成（初期難易度・マイルストーン生成・進捗追跡・達成判定） | `scripts/econ_mvp/RewardSystemManager.gd`（新規） | 1.1 |
| 1.3 | マイルストーン定義テーブル | `data/milestones.json` または `MilestoneDefinition.gd` | - |
| 1.4 | `EconEconomy.gd` 5秒tick から `RewardSystemManager.update_progress` を呼び出す | `EconEconomy.gd` | 1.2 |
| 1.5 | 累積資源カウンタ追加（資源系用） | `EconEconomy.gd` | - |
| 1.6 | マイルストーン即時報酬適用処理 | `RewardSystemManager.gd` + 既存各ファイル | 1.2 |

### Phase 2: UI実装

| # | タスク | 対象ファイル | 依存 |
|---|---|---|---|
| 2.1 | 初期難易度選択UI | `InitialDifficultyDialog.gd`（新規） | 1.2 |
| 2.2 | バトル中マイルストーン表示パネル | `EconMilestonePanel.gd`（新規）+ `EconMain.gd` 配置 | 1.2 |
| 2.3 | 即時報酬テロップ表示 | `RewardTelopOverlay.gd`（新規） | 1.6 |
| 2.4 | バトル後報酬選択UI（オーバーレイ） | `RewardSelectionOverlay.gd`（新規） | 1.2 |

### Phase 3: 宝箱・土地カード

| # | タスク | 対象ファイル | 依存 |
|---|---|---|---|
| 3.1 | 報酬プール拡張 | `data/cards_econ.json`（reward_pools 追加） | 1.2 |
| 3.2 | `EconChest.gd` 新規作成 | `scripts/econ_mvp/EconChest.gd`（新規） | - |
| 3.3 | 宝箱配置・取得ロジック | `EconBattle.gd` + `EconBuilding.gd` | 3.2 |
| 3.4 | 宝箱演出（パーティクル） | `RewardTelopOverlay.gd` 拡張 | 2.3, 3.3 |
| 3.5 | 土地カード配置コントローラ | `LandCardPlacementController.gd`（新規） | 2.4 |
| 3.6 | 配置可能マスのハイライト・パルスアニメ | `LandCardPlacementController.gd` + `EconGrid.gd` | 3.5 |
| 3.7 | 報酬フローコントローラ | `RewardFlowController.gd`（新規） | 2.4, 3.5 |

### Phase 4: 統合テスト

| # | タスク |
|---|---|
| 4.1 | 通しプレイテスト（初期難易度3パターン） |
| 4.2 | バランス確認・残論点（§9）の数値確定 |
| 4.3 | 完了条件チェックリスト全項目確認 |
| 4.4 | check_syntax.sh 通過確認 |

### 依存関係まとめ

```
Phase 1（基盤）
   ↓
Phase 2（UI）
   ↓
Phase 3（宝箱・土地カード）
   ↓
Phase 4（統合テスト）
```

各Phase内のタスクは依存関係に従い順次実装。Phase 1とPhase 3.1（データ）は並行可能。

---

## 9. 残論点・判断待ち

### 9.1 数値バランス（実装フェーズで確定）

企画書 §18 + Designer企画書 §9.1 から該当分:

| # | 項目 | 判断タイミング |
|---|---|---|
| 9.1.1 | 各系統の具体的なマイルストーン条件（数値テーブル） | Phase 1 実装開始時 |
| 9.1.2 | 各系統の報酬カードプールの最終枚数 | Phase 3.1 実装時 |
| 9.1.3 | 中難度即時報酬の数値バランス | Phase 4 テスト後調整 |
| 9.1.4 | 宝箱即時報酬の出現率（weight） | Phase 4 テスト後調整 |
| 9.1.5 | 特殊マイルストーンの具体条件 | Phase 1 実装開始時 |
| 9.1.6 | 特殊マイルストーン報酬の強さ（具体カード選定） | Phase 3.1 実装時 |
| 9.1.7 | リスク系マイルストーンの制約条件具体化 | Phase 1 実装開始時 |

### 9.2 後続Sprint連携

| # | 項目 | 担当Sprint候補 |
|---|---|---|
| 9.2.1 | 住宅上位建物の詳細仕様（集合住宅・居住区） | Sprint 10+ |
| 9.2.2 | 偉人カードの詳細仕様（永続効果ロジック・ビジュアル） | Sprint 10+ |
| 9.2.3 | 政策カードの詳細仕様（一時効果ターン管理） | Sprint 10+ |
| 9.2.4 | 悪魔の釜型の詳細係数 | 未定 |
| 9.2.5 | 失敗時ペナルティ | 未定 |
| 9.2.6 | 報酬レアリティ表示（コモン・レア等） | Sprint 12+ |
| 9.2.7 | ショップ統合時のレイアウト | Sprint 11（ショップSprint） |
| 9.2.8 | 敵による宝箱取得 | MVP外 |

### 9.3 設計判断（Designer推奨案 → CEO承認済み前提）

Designer企画書 §9.1 / §12 の推奨案を本要件定義に採用済み。CEO承認確認が必要な事項:

| # | 項目 | 採用方針 |
|---|---|---|
| 9.3.1 | マイルストーン常時表示数 | 上位3系統 + ホバーで全表示 |
| 9.3.2 | 土地カード配置キャンセル | 不可（操作最小化） |
| 9.3.3 | 報酬カードサイズ | 220×280 新規定義（バトル中BUILDカードと差別化） |
| 9.3.4 | 新規色定義 | 0個（既存COLOR_*のみ流用） |
| 9.3.5 | 達成マイルストーン一覧画面 | 省略（テンポ優先） |

CEO承認後、本要件定義を確定とする。

### 9.4 アーキテクチャ判断（Architect補足）

| # | 項目 | 採用方針 |
|---|---|---|
| 9.4.1 | RewardSystemManager の保持方法 | 新規 `scripts/econ_mvp/RewardSystemManager.gd` を `EconMain.gd` から `add_child` |
| 9.4.2 | GameSession の実体 | 既存に専用クラスがあれば拡張、なければ `EconMain.gd` の自前管理を `GameSession.gd` に切り出し（Phase 1.1で確定） |
| 9.4.3 | マイルストーン定義の保持 | `data/milestones.json` を推奨（数値調整しやすい）。バランス調整中は GDScript 定数でも可 |
| 9.4.4 | 隣接判定 | 既存 `EconGrid` の隣接判定を再利用、なければ `EconGrid.get_adjacent_cells(pos)` を新規追加 |
| 9.4.5 | 疎結合ルール（CLAUDE.md準拠） | 他クラス内部配列への直接代入禁止。すべて `RewardSystemManager` のメソッド経由で状態変更 |

---

## 10. 参照

- 企画書（SSoT）: `docs/sprint9_reward_milestone_chest_final.md`
- Designer企画書: `docs/design/sprint9_designer_plan.md`
- 既存色定数: `scripts/econ_mvp/EconMain.gd:100-117`
- 既存FOOTER UI: `docs/design/econ_mvp_footer_ui.md`
- ラン構造: `docs/design/econ_mvp_run_structure.md`
- 既存要件定義（参考）: `docs/requirements/REQUIREMENTS_V0_2_MVP.md`, `req_econ_logging_ui_sprint8.md`
- 設計判断基準: `docs/design/design_principles.md`
- 用語: `docs/design/glossary.md`
- 核となる体験: `CLAUDE.md`「盤面を設計して、介入を仕込んで、答え合わせを観戦する」
- 疎結合ルール: `CLAUDE.md`「疎結合ルール（Econ MVP）」

---

## 11. 統合フロー（CLAUDE.md「個別req統合ルール」準拠）

実装完了後、本ファイルの内容を `docs/requirements/REQUIREMENTS_V0_2_MVP.md` の Sprint 9 セクションへ統合する。

統合前に本ファイル冒頭に以下を追記する:

```md
STATUS: 統合済み
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md
統合日: YYYY-MM-DD
```

統合済み確認後、本ファイルは削除する（Git履歴で参照可能）。
