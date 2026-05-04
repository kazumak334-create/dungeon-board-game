STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# 要件定義書 — MVP v0.2：5戦ワンラン型都市建設デッキバトル

## 0. ドキュメントメタデータ

| 項目 | 内容 |
|------|------|
| 対象バージョン | MVP v0.2 |
| 対応するUI/UX企画版 | UI/UX企画書（HEADER/BOARD/FOOTER/LEFT/RIGHT 5パネル構成版） |
| 対応する設計ドキュメント | 統合企画書 v1（5戦ワンラン型）、兵力・ユニット化・突撃/防衛ダメージ仕様、特殊ユニット変換システム仕様 |
| 最終更新日 | 2026-05-02 |
| ステータス | DRAFT（CEO承認待ち） |
| 前提 | docs/GAME_DESIGN.md の核（限られた資源の流し先を決める／配分が戦況を作る／戦闘は答え合わせ）に整合 |

> 本書は実装可能な単位まで仕様を分解した要件定義書である。本書からの逸脱・追加は禁止。
> 仕様変更が必要になった場合は本書を直接更新すること（新ファイル禁止：CLAUDE.md「要件定義書の更新ルール」）。

---

## 1. ゲーム全体仕様

### 1.1 コンセプト要約
6角パネル上に建物カードを配置し、稼働人口と作業人口を配分しながら都市を拡張する「都市建設×デッキ構築×配置パズル」。1ランは5戦で完結する。プレイヤーの主体験は「限られた資源の流し先を決める」こと、戦闘は「配分の答え合わせ」を観戦するフェーズとして機能する。

### 1.2 1ラン構造
- **構成**：5戦／ラン
  - 1戦目：初期戦（チュートリアル兼ねる）
  - 2戦目：通常戦
  - 3戦目：中ボス戦
  - 4戦目：通常戦
  - 5戦目：最終ボス戦
- **戦間設計フェーズ**：60秒固定
- **戦闘フェーズ**：セミリアルタイム制、最大10ターン／5分。1ターン=30秒（5秒ティック×6）
- **遷移**：戦間設計 → 戦闘 → リザルト → 次戦の戦間設計

### 1.3 セミリアルタイム制
- ベースティック：5秒／tick
- 1ターン = 6 tick = 30秒
- 上限：10ターン = 60 tick = 5分
- 全システム（建設・人口・幸福度・兵力生成）は5秒ティック単位で評価

### 1.4 主要リソース
| リソース | 用途 | 変動契機 |
|---------|------|---------|
| 木材 (Wood) | 建設コスト・防壁建設 | 採集建物・カード効果 |
| 石材 (Stone) | 建設コスト・防壁建設 | 採集建物・カード効果 |
| 食料 (Food) | 人口維持・幸福度 | 農地・カード効果 |
| 通貨 (Coin) | 即時建設コスト・特殊購入 | 商業建物・戦闘報酬 |

### 1.5 ゲーム勝敗条件
- **勝利**：5戦目を突破
- **敗北**：いずれかの戦闘で拠点HPが0になる
- **戦闘終了条件**：(a) 拠点HP=0（敗北） / (b) 10ターン経過時点で拠点HP>0（勝利） / (c) 突撃成功で敵拠点撃破（早期勝利）

---

## 2. UI/UX要件マッピング

### 2.1 画面領域定義（基準解像度 1920×1080）

| 領域 | 位置・サイズ | 役割 | 主表示要素 |
|------|------------|------|----------|
| HEADER | 上端、全幅×40px | リソース・時間表示 | 木材/石材/食料/通貨/人口/幸福度/ターン/残り時間 |
| LEFT PANEL | 左端、240px×(1080-240) | 建設キュー | キュー一覧、進捗バー、ワーカー割当 |
| BOARD | 中央、(1920-240-280)×(1080-240) = 1400×800 | ヘクスグリッド盤面 | パネル、建物、防壁、敵ユニット |
| RIGHT PANEL | 右端、280px×(1080-240) | 軍事/突撃コントロール | 兵舎一覧、兵力ゲージ、突撃旗ON/OFF、兵力プレビュー |
| FOOTER | 下端、全幅×200px | 手札/デッキ操作 | 手札8枚、ドローパイル、捨て札、リロードボタン |

### 2.2 UI/UX企画 → 実装要件マッピング

| UI/UX企画項目 | 実装要件章 | 対応クラス／シーン |
|-------------|----------|----------------|
| HEADER（リソース/時間表示） | 3.1 | `CityHUDHeader.gd` |
| BOARD（ヘクスグリッド） | 3.2、4.1 | `CityBoard.gd`, `HexPanel.gd` |
| FOOTER（手札・デッキ） | 3.3、4.2 | `CityHand.gd`, `CardView.gd` |
| LEFT PANEL（建設キュー） | 3.4、4.3 | `BuildQueuePanel.gd` |
| RIGHT PANEL（軍事/突撃） | 3.5、4.7 | `MilitaryPanel.gd` |
| ドラッグ&ドロップ配置 | 3.2.3 | `CityBoard.gd::_on_card_dropped()` |
| 5秒ティック更新 | 4.0 | `CityTicker.gd`（中央タイマー） |
| 突撃フェーズ画面 | 3.6 | `ChargePhaseOverlay.gd` |
| 戦間設計画面 | 3.7 | `IntermissionScreen.gd` |
| 人口配分スライダー | 3.4.2 | `WorkerAllocSlider.gd` |
| 25/50/75スナップ | 3.4.2 | スライダー実装内 |
| カラーコード | 6.4 | `CityTheme.gd`（Color定数） |
| アニメーション | 6.5 | `CityAnim.gd`（Tween管理） |

### 2.3 実装優先順位（UI/UX企画準拠）
1. 基本レイアウト（HEADER/BOARD/FOOTER/LEFT/RIGHT）
2. ドラッグ&ドロップ配置
3. 建設キュー＋人口配分
4. 突撃フェーズ
5. アニメーション

---

## 3. スクリーン別詳細要件

### 3.0 共通仕様
- **中央ティック**：`CityTicker.gd` が5秒ごとに `tick(tick_index: int)` シグナルを発火。全システムはこれを購読する。
- **状態管理**：`CitySession.gd`（シングルトン的に保持）が現在ターン・残り時間・リソース・人口・幸福度を保持。
- **シグナル名規約**：`資源名_changed(new_value: int)`、`tick_advanced(tick_index: int)`、`turn_advanced(turn_index: int)`。

### 3.1 HEADER（リソース・時間表示）
- **配置**：x=0, y=0, w=1920, h=40
- **表示要素（左→右）**：
  1. 木材アイコン+数値（幅120px）
  2. 石材アイコン+数値（幅120px）
  3. 食料アイコン+数値（幅120px）
  4. 通貨アイコン+数値（幅120px）
  5. 人口（稼働/最大、幅140px）
  6. 幸福度（数値+カラーバー、幅180px）
  7. ターン表示（"Turn X / 10"、幅140px、中央寄せ）
  8. 残り時間（"MM:SS"、幅140px、右寄せ）
- **更新契機**：該当リソースの `_changed` シグナル受信時、または `tick_advanced` 受信時
- **アニメーション**：数値変動時、0.2秒のスケールパルス（1.0→1.2→1.0）

### 3.2 BOARD（ヘクスグリッド盤面）

#### 3.2.1 グリッド仕様
- 表示領域：x=240, y=40, w=1400, h=800
- ヘクスサイズ：半径=48px（pointy-top）
- グリッド範囲：プレイヤー領域 半径3 hex（19パネル）＋拡張可能領域（最大半径5、61パネル）
- 座標系：軸座標（q, r）。中心 (0,0) を拠点パネル

#### 3.2.2 パネル状態
| 状態 | 説明 | 視覚表現 |
|------|------|--------|
| `EMPTY` | 未拡張・未配置 | 灰色塗りつぶし、点線縁 |
| `EXPANDABLE` | 拡張可能（隣接） | 半透明、点滅縁 |
| `OWNED_EMPTY` | 自領土・建物なし | 緑色薄塗り、実線縁 |
| `OWNED_BUILT` | 建物配置済み | 建物アイコン表示 |
| `WALL_EDGE` | 防壁設置辺 | 該当辺のみ太線（青） |
| `ENEMY_OCCUPIED` | 敵ユニット占有 | 赤マーカー、HP表示 |

#### 3.2.3 ドラッグ&ドロップ
- **入力**：FOOTERの手札カードを掴む（マウスダウン）
- **ホバー**：カーソル下のヘクスをハイライト（配置可=金、配置不可=赤）
- **配置可条件**：(a) 自領土 (b) 該当パネル状態が `OWNED_EMPTY` (c) リソース充足
- **配置確定**：マウスアップ時、配置可能なら `CityBoard.place_card(card_id, q, r)` を呼ぶ。即時建設コストを支払うか建設キューに登録される
- **キャンセル**：配置不可な場所でドロップ、またはBOARD外でドロップ

### 3.3 FOOTER（手札・デッキ）

#### 3.3.1 配置
- 領域：x=0, y=880, w=1920, h=200
- 手札カード：8枚分の枠、横並び（カード幅=180px、間隔=12px）
  - 計算：(180+12)×8 - 12 = 1524px。中央寄せ x=(1920-1524)/2=198
- 9枚以上は横スクロール（左右矢印UI）

#### 3.3.2 デッキ操作
- 左下：ドローパイル枚数表示（残り枚数）
- 右下：捨て札枚数表示
- 中央右：リロードボタン（5秒クールタイム）
  - クリック時：手札を捨て札に送り、ドローパイルから5枚ドロー（または山切れ時のシャッフル＋ドロー）
  - クールダウン中：ボタングレーアウト＋クールダウン円形ゲージ表示

#### 3.3.3 カード循環ルール（カードタイプ別）
| タイプ | 配置後の挙動 |
|--------|-----------|
| 通常建物 | 配置→捨て札→リシャッフル時に山に戻る（循環） |
| 政策 | 使用→バトル中除外（ゾーンPOLICY_LOCKED）→次バトル開始時に山に復帰 |
| 偉人 | 使用→バトル中永続効果→次バトル開始時に山に復帰 |

### 3.4 LEFT PANEL（建設キュー）

#### 3.4.1 配置
- 領域：x=0, y=40, w=240, h=840
- 建設タスク行：高さ80px、最大10件表示（10件超過は縦スクロール）

#### 3.4.2 各タスク行の表示要素
1. 建物アイコン（48×48）
2. 建物名＋座標（"製材所 (q,r)"）
3. 進捗バー（残り時間/総時間）
4. 割当ワーカー数（"3/5"）と+/-ボタン
5. 即時建設ボタン（通貨コスト表示、押下で残り時間ゼロ）

#### 3.4.3 人口配分スライダー
- 配置：パネル下部、固定高さ120px
- スライダー：稼働人口 vs 作業人口
  - スナップポイント：作業25% / 50% / 75%
  - スナップ範囲：±3% 以内でスナップ
- 表示：稼働XX / 作業YY（合計=現在人口）

### 3.5 RIGHT PANEL（軍事・突撃）

#### 3.5.1 配置
- 領域：x=1640, y=40, w=280, h=840

#### 3.5.2 兵舎リスト
- 1兵舎=1行、高さ72px
- 表示：兵舎Lv、座標、現在兵力／上限、生成レート（/5秒）
- 上限：兵舎Lvにより異なる（Lv1=20、Lv2=40、Lv3=60）

#### 3.5.3 突撃旗トグル
- 各兵舎に旗ON/OFFスイッチ
- ON：突撃フェーズ時に出撃対象になる
- OFF：防衛兵力として待機

#### 3.5.4 兵力プレビュー
- 全兵舎の合計兵力表示
- 「ユニット化数」表示：`floor(合計兵力 / 10)` 体（HP10/体）
- スタック制約警告（1パネル最大3ユニット超過時）

### 3.6 突撃フェーズ画面（オーバーレイ）

#### 3.6.1 起動条件
- 戦闘終了タイミング（10ターン経過 or 任意タイミング）に旗ON兵舎が存在する場合に起動
- BOARD全画面オーバーレイ（半透明黒背景 50%）

#### 3.6.2 表示要素
- 出撃ユニット配置プレビュー（敵領土側に表示）
- ユニットHP（HP10/体）
- 進軍ペース：0.2秒ごとに1ユニット出撃
- 防壁・拠点HPゲージ
- 「キャンセル」ボタン（フェーズ中止、兵力は防衛側に戻す）
- 「進軍開始」ボタン

#### 3.6.3 進軍ロジック
- 1ユニット出撃（0.2秒）→敵防壁／拠点へ進軍 →ダメージ計算（4.7参照）
- 全ユニット消費 or 敵拠点HP=0 でフェーズ終了

### 3.7 戦間設計画面

#### 3.7.1 配置・タイマー
- フルスクリーン
- 60秒カウントダウン（残り時間表示、上中央、48ptフォント）
- 残り10秒以下で警告色（黄）

#### 3.7.2 表示要素
- マップ全体表示（ボード縮小プレビュー）
- 初期手札5枚（中央下）
- リソース・人口表示（HEADER流用）
- 「準備完了」ボタン（押下で即座に戦闘開始）
- 戦闘ハイライト（次戦の敵情報・推奨戦略）

---

## 4. システム別詳細要件

### 4.0 中央ティック・ループ

```
CityTicker.gd
- _process(delta): タイマー累積。5秒到達でtick発火
- signal tick_advanced(tick_index: int)
- 30秒（6tick）ごとに signal turn_advanced(turn_index: int) 追加発火
- 10ターン経過で signal battle_ended()
```

各システムは `tick_advanced` を購読し、自身の状態更新を行う。

### 4.1 ボード・グリッド・パネル管理

#### 4.1.1 クラス
```
CityBoard.gd（Node2D）
- panels: Dictionary[Vector2i, HexPanel]
- place_card(card_id: String, q: int, r: int) -> bool
- get_panel(q: int, r: int) -> HexPanel
- expand_panel(q: int, r: int) -> bool
- get_neighbors(q: int, r: int) -> Array[Vector2i]
- signal panel_state_changed(coord: Vector2i, new_state: int)

HexPanel.gd（Node2D）
- coord: Vector2i
- state: int (enum: EMPTY, EXPANDABLE, OWNED_EMPTY, OWNED_BUILT, ENEMY_OCCUPIED)
- building: Building or null
- wall_edges: Array[int] (0-5、設置辺)
```

#### 4.1.2 配置可否判定
- 自領土内（state == OWNED_EMPTY）
- リソース充足（建物の `cost_wood`/`cost_stone`/`cost_food`/`cost_coin` を参照）
- 建設キュー上限未達（最大10件）

### 4.2 カード・手札・ドロー・リロード

#### 4.2.1 クラス
```
CityDeck.gd（Node）
- draw_pile: Array[Card]
- discard_pile: Array[Card]
- hand: Array[Card] (最大8)
- policy_locked: Array[Card] (バトル中ロック)
- great_person_active: Array[Card] (バトル中常駐)
- draw(n: int) -> Array[Card]
- discard(card: Card)
- shuffle()
- reload() -> void  # 手札→捨て札、5枚ドロー
- on_battle_start()  # ロックカード復帰、手札5枚ドロー
- signal hand_changed()
- signal reload_cooldown(remaining: float)
```

#### 4.2.2 リロード
- クールタイム：5秒（`reload_cooldown_timer: float`）
- リロード操作：手札を全捨て札→ドローパイルから5枚ドロー（足りない場合は捨て札をシャッフルしてドロー継続）

### 4.3 建設キュー＋作業人口配分

#### 4.3.1 クラス
```
BuildQueue.gd（Node）
- tasks: Array[BuildTask] (最大10)
- enqueue(building_id: String, coord: Vector2i, base_time: int)
- assign_workers(task_idx: int, workers: int)
- instant_build(task_idx: int)  # 通貨消費
- _on_tick(): 各タスクの残り時間を ワーカー割当 比率で減算
- signal task_completed(task_idx: int, building_id: String, coord: Vector2i)
- signal queue_changed()

BuildTask.gd
- building_id: String
- coord: Vector2i
- total_time: int (tick)
- remaining_time: float
- assigned_workers: int
- instant_cost_coin: int
```

#### 4.3.2 進捗計算
- 1tickあたり進捗 = `assigned_workers × WORKER_PROGRESS_PER_TICK`
- `WORKER_PROGRESS_PER_TICK` = 1.0
- 例：建物総時間6tick、ワーカー3人→6/3=2tickで完成
- ワーカー配分上限：作業人口の合計 ≦ 全タスクの割当合計

#### 4.3.3 即時建設
- 通貨コスト = 残り時間tick × 5（暫定）
- 押下で `remaining_time = 0` 即完成

### 4.4 人口・幸福度シミュレーション

#### 4.4.1 クラス
```
Population.gd（Node）
- total: int
- working: int  # 作業人口
- operating: int  # 稼働人口（total - working）
- happiness: int (0-100)
- _on_tick():
  - 食料消費 = total × 0.5（端数切上）
  - 食料不足時：happiness -= 5
  - 幸福度補正による稼働人口効率変動
- signal population_changed()
- signal happiness_changed(new_value: int)
```

#### 4.4.2 配分スナップ
- 25/50/75 のいずれかにスナップ（±3%以内）
- 自由値（スナップ外）も許容、ただし表示は四捨五入

#### 4.4.3 幸福度補正
| 幸福度範囲 | 名称 | 兵力生成補正 | 稼働効率 |
|----------|------|------------|---------|
| 80-100 | 高幸福 | +10% | +10% |
| 50-79 | 通常 | ±0% | ±0% |
| 30-49 | 不安 | -10% | -5% |
| 0-29 | 危険 | -20% | -15% |

更新契機：5秒tick

### 4.5 リソース管理

#### 4.5.1 クラス
```
CityResources.gd（Node）
- wood: int
- stone: int
- food: int
- coin: int
- spend(wood, stone, food, coin) -> bool  # 不足時false
- gain(wood, stone, food, coin)
- signal wood_changed(new: int)
- signal stone_changed(new: int)
- signal food_changed(new: int)
- signal coin_changed(new: int)
```

#### 4.5.2 初期値（戦間設計開始時）
- 木材: 30
- 石材: 20
- 食料: 40
- 通貨: 10

戦闘継続時は前戦終了時の値を引き継ぐ。

### 4.6 兵力生成・ユニット化

#### 4.6.1 クラス
```
Barracks.gd（Building継承）
- coord: Vector2i
- level: int (1-3)
- power: int (現在兵力)
- power_cap: int (Lv別上限：20/40/60)
- charge_flag: bool (突撃旗)
- _on_tick():
  - if not active: return
  - gen = base_gen[level] × happiness_modifier
  - power = min(power + gen, power_cap)
- signal power_changed(new: int)

base_gen = {1: 2, 2: 3, 3: 4}  # +X/5秒
```

#### 4.6.2 ユニット化
- ユニット化条件：`power >= 10`
- 1ユニット = 兵力10消費、HP10
- 突撃時の出撃ペース：0.2秒/体

#### 4.6.3 スタック
- 1パネル最大3ユニット
- 超過分は次パネル進軍時まで待機

### 4.7 バトルシミュレーション・ダメージ計算

#### 4.7.1 クラス
```
BattleSimulator.gd（Node）
- enemy_walls_hp: Dictionary[edge_id, int]
- enemy_base_hp: int = 200
- player_walls_hp, player_base_hp = 200
- simulate_charge(units: Array[Unit]) -> ChargeResult
- simulate_defense(enemy_units: Array[Unit]) -> DefenseResult
```

#### 4.7.2 DPS計算
- 残存兵力 = 出撃ユニット中の生存数 × 10
- DPS = 残存兵力 × 0.2
- 1tick(5秒)あたりダメージ = DPS × 5

#### 4.7.3 防壁HP
- 1辺：60HP
- 設置辺数 × 60 = 防壁総HP
- 防壁ゼロで拠点HPに直接ダメージ

#### 4.7.4 拠点HP
- 200HP固定
- ゼロでバトル敗北（防衛側） / 突撃成功（攻撃側）

#### 4.7.5 防衛時の兵力返還
- 攻撃側が壊滅した時点で防衛兵力の生存分を100%返還（兵舎にpower加算）
- 攻撃時返還なし（突撃失敗で全損）

### 4.8 防壁・防衛拠点

#### 4.8.1 防壁建設
- カード「防壁」または建設キューから追加
- リソース消費：木材5＋石材10／辺
- 設置場所：城下町外周辺のみ
- 再建：壊された辺に対して再建キュー登録可

#### 4.8.2 防衛拠点
- BOARD中央のヘクス（0,0）に固定
- HP200、防衛兵力（旗OFFの兵舎）が割当てられる

### 4.9 宝物・マイルストーン（MVPスコープ）

- 建物配置時、隣接ヘクスに宝物パネルがあれば「開封」フラグ立て
- 開封報酬：即時報酬（リソース or カード）+ マイルストーン目標追加
- マイルストーン例：「3戦目までに兵舎Lv2を建てる」 → 達成で偉人カード獲得

> MVP v0.2では「即時報酬1パターン」のみ実装。マイルストーン報酬は追加目標表示のみ（達成判定は次フェーズ）。

### 4.10 特殊ユニット変換システム（MVPスコープ外）

仕様は記録のみ。実装は次フェーズ：
- 攻城工房／厩舎／弓術場／兵器庫：パッシブ型、効果範囲2、変換率30%
- 攻城兵（防壁特化）／騎兵（高速）／弓兵（遠距離）／重装兵（耐久）

---

## 5. データスキーマ定義

### 5.1 cards.json（建物・政策・偉人）

```json
{
  "id": "lumbermill_01",
  "name": "製材所",
  "type": "building",        // building | policy | great_person | wall
  "tier": 1,
  "cost_wood": 0,
  "cost_stone": 5,
  "cost_food": 0,
  "cost_coin": 0,
  "build_time_tick": 4,       // 建設に必要なtick数
  "active": true,             // アクティブ建物か（パッシブ=false）
  "category": "production",   // production | military | wall | special
  "produces": {"wood": 2},    // /tick生産（active=falseは常時、active=trueは稼働中のみ）
  "effects": [],              // EffectActions準拠
  "race": "neutral",          // 種族（既存スキーマ流用）
  "description": "毎tick木材+2"
}
```

### 5.2 buildings.json（兵舎・防壁固有パラメータ）

```json
{
  "id": "barracks_01",
  "name": "兵舎",
  "type": "building",
  "category": "military",
  "level": 1,
  "power_cap": 20,
  "power_gen_per_tick": 2,
  "happiness_modifier": true   // 幸福度補正適用フラグ
}
```

### 5.3 wave_definition.json（敵側構成・1ラン5戦）

```json
{
  "run_id": "default_run",
  "battles": [
    {"battle_idx": 0, "label": "初期戦", "enemy_units": 5, "enemy_walls": 2, "enemy_base_hp": 100},
    {"battle_idx": 1, "label": "通常戦", "enemy_units": 10, "enemy_walls": 4, "enemy_base_hp": 150},
    {"battle_idx": 2, "label": "中ボス", "enemy_units": 15, "enemy_walls": 5, "enemy_base_hp": 200, "boss": true},
    {"battle_idx": 3, "label": "通常戦", "enemy_units": 12, "enemy_walls": 5, "enemy_base_hp": 175},
    {"battle_idx": 4, "label": "最終ボス", "enemy_units": 20, "enemy_walls": 6, "enemy_base_hp": 300, "boss": true}
  ]
}
```

### 5.4 GameSession 拡張（CitySession.gd）

```
CitySession.gd
- current_battle_idx: int (0-4)
- current_turn: int (1-10)
- current_tick: int (1-60)
- resources: CityResources
- population: Population
- deck: CityDeck
- board: CityBoard
- build_queue: BuildQueue
- run_state: int (INTERMISSION | BATTLE | RESULT)
```

---

## 6. 実装アーキテクチャ

### 6.1 ファイル構成（提案）

```
scripts/city_mvp/
├── CityMain.gd              # シーンエントリポイント
├── CitySession.gd           # ラン全体の状態保持
├── CityTicker.gd            # 中央5秒ティック
├── CityBoard.gd             # ヘクスグリッド管理
├── HexPanel.gd              # 個別パネル
├── CityResources.gd         # リソース
├── CityDeck.gd              # デッキ・手札・ロック
├── BuildQueue.gd            # 建設キュー
├── BuildTask.gd             # 個別タスク
├── Population.gd            # 人口・幸福度
├── Barracks.gd              # 兵舎（Building継承）
├── BattleSimulator.gd       # 攻撃/防衛ダメージ計算
├── ChargePhase.gd           # 突撃フェーズ制御
├── Building.gd              # 建物基底
├── Card.gd                  # カードデータ
├── ui/
│   ├── CityHUDHeader.gd
│   ├── CityHand.gd
│   ├── CardView.gd
│   ├── BuildQueuePanel.gd
│   ├── WorkerAllocSlider.gd
│   ├── MilitaryPanel.gd
│   ├── ChargePhaseOverlay.gd
│   ├── IntermissionScreen.gd
│   ├── CityTheme.gd         # 色定数・フォント定数
│   └── CityAnim.gd          # Tweenヘルパー
└── data/
    ├── cards.json           # 既存スキーマ拡張
    ├── buildings.json
    └── wave_definition.json
```

### 6.2 シグナル・メッセージング

**中央バス：CityTicker.gd**
- `tick_advanced(tick_index: int)` … 全システムが購読
- `turn_advanced(turn_index: int)`
- `battle_started()`、`battle_ended(victory: bool)`

**個別シグナル：**
- `CityResources.gd` → `wood_changed` 等
- `Population.gd` → `population_changed`、`happiness_changed`
- `CityDeck.gd` → `hand_changed`、`reload_cooldown`
- `BuildQueue.gd` → `task_completed`、`queue_changed`
- `CityBoard.gd` → `panel_state_changed`、`card_placed`
- `Barracks.gd` → `power_changed`

UIは個別シグナルを購読して更新。データクラスはUIを知らない（疎結合）。

### 6.3 ゲームループ全体フロー

```
1. シーン読み込み（CityMain.gd）
2. CitySession初期化（resources、deck、board、population）
3. IntermissionScreen表示（60秒）
   - プレイヤー：カード確認、手札5枚ドロー
   - 「準備完了」or 60秒経過で戦闘開始
4. BATTLEモード
   - CityTicker開始（5秒ごとtick）
   - 各tick：
     a. BuildQueue進捗
     b. Barracks兵力生成
     c. Population食料消費・幸福度更新
     d. 建物の_on_tick（資源生産等）
   - 30秒（6tick）ごとturn_advanced
   - プレイヤー操作：D&D配置、ワーカー配分、突撃旗、リロード
5. 戦闘終了判定（10ターン or 拠点HP=0 or 突撃成功）
6. ChargePhase（任意）
7. リザルト表示
8. 次戦のIntermissionへ（current_battle_idx++）
9. 5戦目クリアでラン勝利、敗北時はリザルト→タイトル
```

### 6.4 カラーコード（CityTheme.gd）

```
const COLOR_PLAYER     = Color("#3B82F6")  # 青
const COLOR_ENEMY      = Color("#EF4444")  # 赤
const COLOR_RESOURCE   = Color("#10B981")  # 緑
const COLOR_WARNING    = Color("#FBBF24")  # 黄
const COLOR_CHARGE     = Color("#F59E0B")  # 金
const COLOR_BG_PANEL   = Color("#1F2937")
const COLOR_BG_OVERLAY = Color("#000000", 0.5)
```

### 6.5 アニメーション規約（CityAnim.gd）

| シーン | 種類 | デュレーション |
|------|------|------------|
| リソース変動 | スケールパルス | 0.2秒 |
| カード配置 | フェードイン+移動 | 0.4秒 |
| 建設完了 | フラッシュ+音 | 0.5秒 |
| 突撃ユニット出撃 | フェードイン+移動 | 0.6秒/体 |
| 戦闘終了 | フェードアウト | 1.0秒 |
| シーン遷移 | クロスフェード | 1.5秒 |

---

## 7. MVP採用／除外リスト

### 7.1 MVP v0.2 採用項目
- HEADER/BOARD/FOOTER/LEFT/RIGHT 5パネル基本レイアウト
- 5秒ティック・10ターン制
- リソース4種（木材/石材/食料/通貨）
- ヘクスグリッド配置（拡張含む）
- D&Dカード配置
- 手札8枚＋リロード（5秒CT）
- カード循環ルール（通常/政策/偉人の3タイプ）
- 建設キュー（最大10件、ワーカー割当、即時建設）
- 人口・作業人口スライダー（25/50/75スナップ）
- 幸福度シミュレーション（4段階補正）
- 兵舎兵力生成（Lv1-3、上限あり）
- ユニット化（兵力10=1体、HP10）
- DPS計算・防壁HP・拠点HP
- 突撃フェーズ（旗ON/OFF、出撃ペース）
- 防衛兵力返還（生存分100%、攻撃時0%）
- 1ラン5戦構成（初期/通常/中ボス/通常/最終ボス）
- 戦間設計画面（60秒、初期手札5枚）
- カラーコード・アニメーション規約

### 7.2 MVP v0.2 除外項目（次フェーズ）
- 特殊ユニット変換システム（攻城兵/騎兵/弓兵/重装兵）
- 専門建物（攻城工房/厩舎/弓術場/兵器庫）
- 宝物のマイルストーン報酬達成判定（表示のみ実装）
- ランダムイベント
- 装備・レリック
- メタ進行（ラン跨ぎのアンロック）
- マルチプレイ・対人

### 7.3 廃止済み設計の確認（CLAUDE.md準拠）
本要件定義書は以下の廃止設計を**含まない**ことを確認済み：
- 盤面召喚システム（→初期配置式に統一）
- 時間経過マナ回復（→兵力生成は兵舎による）
- アクティブスキル・固有スキル（→3秒ルール準拠）
- 行範囲攻撃（→ヘクス隣接ベース）
- リアルタイム対人（→PvE）

---

## 8. パラメータ集約表

### 8.1 タイミング・時間
| パラメータ | 値 |
|----------|-----|
| 1ティック | 5秒 |
| 1ターン | 30秒（6tick） |
| 戦闘上限ターン | 10ターン（60tick / 5分） |
| 戦間設計時間 | 60秒 |
| リロードCT | 5秒 |
| 出撃ペース | 0.2秒/体 |

### 8.2 リソース・人口
| パラメータ | 値 |
|----------|-----|
| 初期木材 | 30 |
| 初期石材 | 20 |
| 初期食料 | 40 |
| 初期通貨 | 10 |
| 食料消費/tick | 人口×0.5（端数切上） |
| ワーカースナップ | 25% / 50% / 75% |
| 1ワーカー進捗/tick | 1.0 |

### 8.3 幸福度補正
| 範囲 | 兵力補正 | 稼働補正 |
|------|--------|--------|
| 80-100 | +10% | +10% |
| 50-79 | ±0% | ±0% |
| 30-49 | -10% | -5% |
| 0-29 | -20% | -15% |

### 8.4 兵舎・兵力
| 兵舎Lv | 生成/5秒 | 上限 |
|------|--------|------|
| 1 | +2 | 20 |
| 2 | +3 | 40 |
| 3 | +4 | 60 |

| パラメータ | 値 |
|----------|-----|
| ユニット化閾値 | 兵力10 |
| ユニットHP | 10 |
| DPS係数 | 残存兵力×0.2 |
| 1パネル最大ユニット | 3体 |

### 8.5 防壁・拠点
| パラメータ | 値 |
|----------|-----|
| 防壁HP/辺 | 60 |
| 防壁建設コスト | 木材5＋石材10／辺 |
| 拠点HP | 200 |
| 防衛時返還率 | 生存分100% |
| 攻撃時返還率 | 0% |

### 8.6 戦闘構成
| 戦 | ラベル | 敵ユニット | 敵防壁 | 敵拠点HP |
|---|------|---------|------|---------|
| 1 | 初期戦 | 5 | 2 | 100 |
| 2 | 通常戦 | 10 | 4 | 150 |
| 3 | 中ボス | 15 | 5 | 200 |
| 4 | 通常戦 | 12 | 5 | 175 |
| 5 | 最終ボス | 20 | 6 | 300 |

### 8.7 UI寸法（1920×1080基準）
| 領域 | x | y | w | h |
|------|---|---|---|---|
| HEADER | 0 | 0 | 1920 | 40 |
| LEFT PANEL | 0 | 40 | 240 | 840 |
| BOARD | 240 | 40 | 1400 | 840 |
| RIGHT PANEL | 1640 | 40 | 280 | 840 |
| FOOTER | 0 | 880 | 1920 | 200 |
| ヘクス半径 | - | - | 48 | - |
| カード幅 | - | - | 180 | - |
| カード間隔 | - | - | 12 | - |

---

## 9. チェックリスト（受け入れ基準）

### 9.1 UI/UX企画カバー確認
- [x] HEADER (40px) … 3.1
- [x] BOARD (中央60%) … 3.2
- [x] FOOTER (200px) … 3.3
- [x] LEFT PANEL (240px) … 3.4
- [x] RIGHT PANEL (280px) … 3.5
- [x] リアルタイム5秒ティック … 4.0
- [x] カード手札8枚スクロール … 3.3.1
- [x] D&D配置 … 3.2.3
- [x] 建設キューUI … 3.4
- [x] 人口配分（25/50/75スナップ） … 3.4.3
- [x] 突撃フェーズ画面 … 3.6
- [x] 戦間設計画面（60秒、初期手札5枚） … 3.7
- [x] カラーコード … 6.4
- [x] アニメーション（0.2-1.5秒） … 6.5
- [x] 実装優先順位 … 2.3

### 9.2 統合企画書 v1 整合性
- [x] 5戦ワンラン構成 … 1.2
- [x] セミリアルタイム制（30秒/ターン×10） … 1.3
- [x] カード循環ルール（通常/政策/偉人） … 3.3.3
- [x] リロード5秒CT … 4.2.2
- [x] 建設システム（キュー+作業人口配分） … 4.3
- [x] 人口25/50/75スナップ … 4.4.2
- [x] 幸福度0-100、5秒更新 … 4.4
- [x] 防壁システム（外周設置・再建キュー） … 4.8
- [x] 突撃フェーズ（旗ON/OFF） … 3.6, 4.6
- [x] 防衛システム（拠点・兵力返還） … 4.7.5
- [x] 宝物・マイルストーン（即時報酬のみMVP） … 4.9

### 9.3 兵力・ユニット化・突撃/防衛仕様
- [x] 兵舎Lv別生成（2/3/4 per 5秒） … 8.4
- [x] 幸福度補正（高+10%、危険-20%） … 8.3
- [x] 兵力10=1ユニット、HP10 … 8.4
- [x] DPS = 残存兵力×0.2 … 4.7.2
- [x] 1パネル最大3スタック … 4.6.3
- [x] 防壁HP60/辺 … 8.5
- [x] 拠点HP200 … 8.5
- [x] 防衛時生存分100%返還、攻撃時0% … 8.5
- [x] 出撃ペース0.2秒/体 … 8.1

### 9.4 特殊ユニット変換（MVPスコープ外確認）
- [x] 仕様記録のみ（4.10）
- [x] MVP除外リスト記載（7.2）

### 9.5 パラメータ定義充足
- [x] 全数値パラメータが集約表（8章）に記載
- [x] 単位・時間・リソース・HP・DPS全て定義済み

### 9.6 MVPスコープ明確化
- [x] 採用項目（7.1）と除外項目（7.2）が明示
- [x] 廃止済み設計を含まないことを確認（7.3）

---

## 10. 用語整合性確認（CLAUDE.md「用語統一ルール」準拠）

| 本書の用語 | GAME_DESIGN.md整合 | 備考 |
|-----------|------------------|------|
| 兵力 (power) | 新規概念 | GAME_DESIGN.mdへの追記が必要 |
| 兵舎 (Barracks) | 新規概念 | 同上 |
| 稼働人口 / 作業人口 | 新規概念 | 同上 |
| 幸福度 (happiness) | 新規概念 | 同上 |
| 拠点 (base) | 既存（廃止済「本体HP」と区別必須） | 都市の中心ヘクス＝拠点。プレイヤー本体ではない |
| ヘクス (hex) | 既存 | OK |
| 建設キュー | 新規概念 | 追記必要 |

> ⚠️ 実装着手前に GAME_DESIGN.md へ上記新規概念の用語定義を追加すること（CLAUDE.md「用語統一ルール」必須チェック）。

---

## 11. ファイルサイズ予測

| ファイル | 予測行数 | 分割判定 |
|--------|--------|--------|
| CityMain.gd | ~150 | OK |
| CitySession.gd | ~200 | OK |
| CityBoard.gd | ~350 | OK |
| CityDeck.gd | ~250 | OK |
| BuildQueue.gd | ~300 | OK |
| Population.gd | ~200 | OK |
| BattleSimulator.gd | ~400 | OK |
| ChargePhaseOverlay.gd | ~300 | OK |
| MilitaryPanel.gd | ~250 | OK |

> 全ファイル500行未満で分割不要。BattleSimulatorが大きくなる場合のみ、AttackResolver/DefenseResolverに分離検討。

---

## 12. 実装順序提案（5スプリント）

| Sprint | 内容 | 完了基準 |
|--------|------|--------|
| S1 | 基本レイアウト＋ヘクスグリッド表示＋リソース表示 | HEADER/BOARD/FOOTER/LEFT/RIGHT が空状態で描画 |
| S2 | カード手札＋D&D配置＋建設キュー基本 | カードを手札からBOARDへ配置→建設キューに登録される |
| S3 | 人口・幸福度・建物稼働＋ティックループ | 5秒ごとに資源生成・建設進捗・幸福度更新 |
| S4 | 兵舎・兵力・突撃フェーズ＋バトルシミュレータ | 突撃で敵防壁・拠点に正しくダメージ |
| S5 | 戦間設計画面＋5戦ループ＋アニメーション＋仕上げ | 1ラン5戦完走 |

---

（本書はDRAFT。CEO承認後にSTATUSを「APPROVED」に更新する）
