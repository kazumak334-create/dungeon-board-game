# 要件定義書：ヘックスグリッド自動戦闘ゲーム MVP

作成日: 2026-04-29
更新日: 2026-04-29
ステータス: 新規
対象ディレクトリ: `res://scenes/hex_mvp/`, `res://scripts/hex_mvp/`
前提PoC: `req_poc_hex_battle.md`（戦闘エンジンを継承）

---

## 1. 概要

### 1.1 核となる体験
**「盤面を設計して、介入を仕込んで、答え合わせを観戦する」**

プレイヤーは敵の種類情報だけを頼りに自陣にユニットを配置し（=設計）、
バトル開始後は介入できず（=観戦）、
3Wave勝ち抜く構造でリプレイ価値を出す（=答え合わせ）。

### 1.2 MVPで検証すること
1. **設計フェーズ**として配置画面が成立するか（時間をかけて考える楽しさが出るか）
2. **情報の非対称性**（敵の種類は見えるが位置は見えない）が緊張感を生むか
3. **3Wave構造**でリワードによる手持ち成長を感じられるか

### 1.3 スコープ
- 1ステージ（3Wave固定）
- 突・守・崩の3種ユニット（PoC継承）
- Wave間リワード3択
- 単一プレイ（セーブ・ロード・章構成なし）

---

## 2. ゲームループ

```
[タイトル]
   ↓ ゲーム開始
[配置フェーズ Wave1]
   ↓ 配置完了ボタン
[バトルフェーズ Wave1]（オート観戦）
   ↓ プレイヤー勝利
[リワード Wave1→2]
   ↓ ユニット選択
[配置フェーズ Wave2]
   ↓
[バトルフェーズ Wave2]
   ↓ プレイヤー勝利
[リワード Wave2→3]
   ↓
[配置フェーズ Wave3]
   ↓
[バトルフェーズ Wave3]
   ↓
[クリア画面 / 敗北画面]
   ↓ リトライ
[タイトル]
```

### 敗北時
バトルフェーズで敗北した時点で「敗北画面」へ遷移。リトライでタイトルに戻る。

---

## 3. 画面一覧

| 画面ID | 役割 | 主要要素 |
|---|---|---|
| TitleScreen | エントリーポイント | スタートボタン |
| DeploymentScreen | 配置フェーズ | ヘックスグリッド・ユニットトレイ・敵情報・配置完了ボタン |
| BattleScreen | バトルフェーズ | ヘックスグリッド・ログ・スピード調整（任意） |
| RewardScreen | Wave間リワード | 3択ユニットカード |
| ResultScreen | 勝利・敗北 | 結果表示・リトライボタン |

---

## 4. データ構造

### 4.1 GameState（オートロード = シングルトン）

ファイル: `res://scripts/hex_mvp/GameState.gd`
オートロード名: `GameState`

```gdscript
class_name GameStateClass
extends Node

# デッキ（手持ちユニット種類IDの配列）
# UnitTypeのint値を格納（0=ATTACKER, 1=TANK, 2=BREAKER）
var deck: Array[int] = []

# 現在のWave番号（1〜3）
var current_wave: int = 1

# 配置されたユニット（Wave開始時に決まる）
# [{unit_type: int, col: int, row: int}, ...]
var deployed_units: Array = []

# 定数
const DECK_MAX: int = 12
const DEPLOY_MAX: int = 8
const WAVE_COUNT: int = 3

# メソッド
func reset_run() -> void           # 新規プレイ開始（デッキを初期手持ちで初期化）
func add_to_deck(unit_type: int) -> bool  # デッキに追加（上限チェック）
func get_initial_deck() -> Array[int]     # 突2守2崩2を返す
```

### 4.2 WaveConfig（Wave定義データ）

ファイル: `res://scripts/hex_mvp/WaveConfig.gd`

```gdscript
class_name WaveConfig
extends RefCounted

# 各Waveの敵構成（種類と数のみ。配置位置はWaveStarterが決める）
# [{unit_type: int, count: int}, ...]
var wave_configs: Array = [
    # Wave 1: 弱め（合計5体程度）
    [{"unit_type": 0, "count": 2}, {"unit_type": 1, "count": 2}, {"unit_type": 2, "count": 1}],
    # Wave 2: 中（合計6体）
    [{"unit_type": 0, "count": 2}, {"unit_type": 1, "count": 2}, {"unit_type": 2, "count": 2}],
    # Wave 3: 強め（合計8体）
    [{"unit_type": 0, "count": 3}, {"unit_type": 1, "count": 3}, {"unit_type": 2, "count": 2}],
]

# Wave内ランダム配置：敵ゾーン（row 8-10）にランダム配置
static func generate_enemy_placement(composition: Array, hex_grid: HexGrid, rng: RandomNumberGenerator) -> Array
```

**注**: 敵構成はWave毎にランダムバリエーションを持たせる。
バリエーション化のため `wave_configs` は `Array[Array]` の中に複数候補を持ち、
Wave開始時にランダム選択する設計とする（実装詳細はImplementer判断可）。

### 4.3 UnitData（ユニット定義）

PoCの `PoCUnit.UNIT_STATS` をそのまま使用。新規定義不要。

### 4.4 RewardChoice（リワード3択）

ファイル: `res://scripts/hex_mvp/RewardGenerator.gd`

```gdscript
class_name RewardGenerator
extends RefCounted

# 3択ユニットを生成（重複なし）
# 戻り値: [unit_type: int, unit_type: int, unit_type: int]
static func generate_choices(rng: RandomNumberGenerator) -> Array[int]
```

MVPでは3種類しかないため、3択は突・守・崩の固定3種を順序ランダムで返す（重複なし）。
※将来ユニット増加時にrarity等を導入する余地を残す。

---

## 5. 画面別機能要件

### 5.1 TitleScreen

ファイル: `res://scenes/hex_mvp/TitleScreen.tscn` + `res://scripts/hex_mvp/TitleScreen.gd`

**要素:**
- タイトルラベル「ヘックスバトルMVP」（中央上部）
- 「ゲーム開始」ボタン（中央）

**挙動:**
- 「ゲーム開始」押下 → `GameState.reset_run()` → `DeploymentScreen.tscn` に遷移

---

### 5.2 DeploymentScreen（配置画面）

ファイル: `res://scenes/hex_mvp/DeploymentScreen.tscn` + `res://scripts/hex_mvp/DeploymentScreen.gd`

#### レイアウト（1280x720想定）

```
+--------------------------------------------------------+
| [Wave 1/3]  敵構成: 突2 守2 崩1                        |
+--------------------------------------------------------+
|                                                        |
|              [ヘックスグリッド 11行]                    |
|              row 0-2: プレイヤーゾーン（青）             |
|              row 3-7: 中立                             |
|              row 8-10: 敵ゾーン（赤・配置不明）          |
|                                                        |
+--------------------------------------------------------+
| ユニットトレイ（手持ちデッキ表示）                       |
| [突]x3 [守]x2 [崩]x2 ... 配置可能数: X/8               |
+--------------------------------------------------------+
|                              [配置完了]ボタン           |
+--------------------------------------------------------+
```

#### 機能

**a. 敵情報表示（画面上部）**
- 「Wave X/3」ラベル
- 敵構成を「突N 守N 崩N」形式で表示
- 配置位置は表示しない（伏せたまま）
- データ参照: `WaveConfig.wave_configs[GameState.current_wave - 1]`

**b. ユニットトレイ（画面下部）**
- `GameState.deck` に含まれる種類別の数を表示
- クリックで「選択中ユニット」を切り替え
- 配置済みユニットを引いた残り数を表示
- 例: デッキに突3、配置済み突1 → 「突 x2」と表示

**c. ヘックスグリッド（中央）**
- HexGrid.gd を再利用
- プレイヤーゾーン（row 0-2）のみクリック可能
- クリック時の挙動:
  - 空セル + ユニット選択中 + 配置数 < 8 → ユニット配置
  - 配置済みセル → 配置取り消し（トレイに戻す）
- 配置済みユニットは PoCUnit と同じ見た目で描画
- スタック上限: 同セル最大3体（HexGrid.MAX_STACK）

**d. 配置完了ボタン**
- 配置数 >= 1 で活性化（0体スタートは禁止）
- 押下時:
  1. 配置情報を `GameState.deployed_units` に保存
  2. `BattleScreen.tscn` に遷移

**e. 制約**
- 配置上限: 8体 / Wave
- スタック制限: 同セル3体まで
- プレイヤーゾーン外への配置不可

---

### 5.3 BattleScreen（バトル画面）

ファイル: `res://scenes/hex_mvp/BattleScreen.tscn` + `res://scripts/hex_mvp/BattleScreen.gd`

#### レイアウト

```
+--------------------------------------------------------+
| [Wave 1/3]                                             |
+--------------------------------------------------------+
|                                                        |
|              [ヘックスグリッド + ユニット表示]            |
|              敵ユニット（row 8-10にランダム配置）         |
|              プレイヤーユニット（配置情報通り）           |
|                                                        |
+--------------------------------------------------------+
| ログパネル（右側 250px）                                 |
+--------------------------------------------------------+
```

#### 機能

**a. 初期化処理（_ready）**
1. `HexGrid` 生成
2. プレイヤーユニット生成: `GameState.deployed_units` を元に PoCUnit を生成
3. 敵ユニット生成:
   - `WaveConfig.wave_configs[current_wave - 1]` から構成を取得
   - `WaveConfig.generate_enemy_placement(...)` でランダム配置決定
   - 敵ゾーン（row 8-10）に配置
4. `PoCBattle` に登録
5. **0.5秒待機後**に `start_battle()` 呼び出し（敵配置を見せる演出）

**b. バトル進行**
- PoCBattle.gd の更新ループをそのまま使用
- ログ表示はPoCMain.gd の `_on_attack_logged` / `_on_kill_logged` を流用

**c. バトル終了処理**
- `battle_ended(player_won: bool)` シグナル受信
  - 勝利 + Wave < 3 → `RewardScreen.tscn` に遷移
  - 勝利 + Wave == 3 → `ResultScreen.tscn`（クリア）に遷移
  - 敗北 → `ResultScreen.tscn`（敗北）に遷移

**d. スコープ外（実装しない）**
- スピード調整ボタン
- 一時停止
- 早送り
- バトル中の操作

---

### 5.4 RewardScreen（リワード画面）

ファイル: `res://scenes/hex_mvp/RewardScreen.tscn` + `res://scripts/hex_mvp/RewardScreen.gd`

#### レイアウト

```
+--------------------------------------------------------+
| Wave X 突破！ ユニットを1体獲得                          |
+--------------------------------------------------------+
|                                                        |
|    +---------+   +---------+   +---------+             |
|    |   突    |   |   守    |   |   崩    |             |
|    | HP/ATK  |   | HP/ATK  |   | HP/ATK  |             |
|    | 説明    |   | 説明    |   | 説明    |             |
|    | [選択]  |   | [選択]  |   | [選択]  |             |
|    +---------+   +---------+   +---------+             |
|                                                        |
+--------------------------------------------------------+
```

#### 機能

**a. 3択生成**
- `RewardGenerator.generate_choices(rng)` で3種返却
- MVPでは突・守・崩の3種固定（順序ランダム）

**b. カード表示**
- 3枚のカード（各300x400程度）
- 各カードに以下を表示:
  - ユニット種類（突/守/崩）
  - HP / ATK / 移動速度 / 攻撃間隔
  - カウンター倍率説明（例:「崩にx2」）
  - 「選択」ボタン

**c. 選択時の挙動**
1. `GameState.add_to_deck(unit_type)` でデッキに追加
   - 上限12到達時: 警告ダイアログ「デッキ満杯。捨てるユニットを選択」
   - MVPスコープでは初期6体 + 最大2回獲得 = 最大8体なので発生しないはず
2. `GameState.current_wave += 1`
3. `DeploymentScreen.tscn` に遷移

**d. スキップオプション（任意・優先度低）**
- 「スキップ」ボタンで何も取らずに次Waveへ
- MVPスコープ外でも可

---

### 5.5 ResultScreen（結果画面）

ファイル: `res://scenes/hex_mvp/ResultScreen.tscn` + `res://scripts/hex_mvp/ResultScreen.gd`

#### 機能

- 引数（GameState.current_wave と勝利フラグ）から表示切り替え:
  - 全Wave勝利: 「ステージクリア！」（金色）
  - 敗北: 「Wave X で敗北」（赤色）
- 「タイトルへ」ボタン → `TitleScreen.tscn` 遷移

---

## 6. PoCからの変更点・追加点

### 6.1 そのまま使うもの（変更禁止）
- `scripts/poc/HexGrid.gd` — グリッド・経路探索
- `scripts/poc/PoCUnit.gd` — ユニット挙動・カウンター倍率
- `scripts/poc/PoCBattle.gd` の戦闘ループ部分

### 6.2 PoCBattle.gd の扱い
- `_setup_balanced` 等のパターン関数は使用しない（呼ばない）
- `setup()` / `start_battle()` / `update()` / `check_victory()` を再利用
- BattleScreen.gd から直接 `_add_player_unit` / `_add_enemy_unit` 相当のロジックを呼ぶ
  - ただしこれらはprivateなため、BattleScreen側でPoCUnit.create() + 直接 `player_units.append()` する形が望ましい
- **PoCBattle.gd は変更しない**（パターン無視で呼ばないだけ）

### 6.3 新規追加
- `scripts/hex_mvp/GameState.gd`（オートロード）
- `scripts/hex_mvp/WaveConfig.gd`
- `scripts/hex_mvp/RewardGenerator.gd`
- `scripts/hex_mvp/TitleScreen.gd`
- `scripts/hex_mvp/DeploymentScreen.gd`
- `scripts/hex_mvp/BattleScreen.gd`
- `scripts/hex_mvp/RewardScreen.gd`
- `scripts/hex_mvp/ResultScreen.gd`
- `scenes/hex_mvp/*.tscn`（5ファイル）

### 6.4 project.godot の変更
- AutoLoad に `GameState` を追加
- メインシーンを `scenes/hex_mvp/TitleScreen.tscn` に変更（任意）

### 6.5 PoCMain.gd の扱い
- 削除しない（PoC検証用に残す）
- `scenes/poc/PoCMain.tscn` も削除しない

---

## 7. 実装しないもの（スコープ外）

明示的に実装しないと宣言する項目（後追いで「なぜないの？」を防ぐ）。

- セーブ・ロード機能
- ローグライト構造（章・ノード分岐）
- マップ選択画面
- バトル中のスピード調整・一時停止
- BGM・SE・パーティクル
- アニメーション（攻撃エフェクト・移動補間）
- ユニット拡張（突守崩以外の種類）
- スキル・アイテム・装備
- カード収集UI（デッキ閲覧画面）
- ステージ複数（MVPは1ステージ固定）
- 難易度選択
- ガチャ・課金要素
- 多言語対応

---

## 8. 制約・注意事項

### 8.1 既存コードとの整合性
- PoC実装（`scripts/poc/*.gd`）は変更禁止
- `scenes/poc/PoCMain.tscn` も変更禁止（PoC検証用に保持）

### 8.2 設計文書との整合性
- 「盤面を設計して、介入を仕込んで、答え合わせを観戦する」を最優先
- 廃止済み設計（盤面召喚・本体HP等）を復活させない
- バトル中のプレイヤー操作要素を追加しない（完全オート維持）

### 8.3 ファイルサイズ予測
| ファイル | 予測行数 | 判定 |
|---|---:|---|
| GameState.gd | 60行 | OK |
| WaveConfig.gd | 80行 | OK |
| RewardGenerator.gd | 40行 | OK |
| TitleScreen.gd | 50行 | OK |
| DeploymentScreen.gd | 280行 | OK（500行未満） |
| BattleScreen.gd | 200行 | OK |
| RewardScreen.gd | 130行 | OK |
| ResultScreen.gd | 50行 | OK |

いずれも500行を超えないため、初期実装で分割不要。

### 8.4 Godot 4.x前提
- GDScript 4 の型注釈を使用
- AutoLoad登録は project.godot を編集

---

## 9. 受入基準（完成判定）

以下を全て満たすこと。

- [ ] タイトル → 配置 → バトル → リワード → 配置 → ... → クリア画面 まで一通り動く
- [ ] 配置画面で敵の「種類と数」のみ表示され、配置位置は隠れている
- [ ] バトル開始時に敵が敵ゾーン（row 8-10）にランダム配置される
- [ ] バトル中はプレイヤーが介入できない（完全オート）
- [ ] 3Wave全勝でクリア画面に遷移する
- [ ] バトル敗北時に敗北画面に遷移する
- [ ] リワードで選んだユニットが次Wave以降のデッキに反映される
- [ ] check_syntax.sh エラー0件

---

## 10. 実装タスクリスト

実装順は依存関係に沿う。Implementerは上から順番に実装し、各タスク完了時に check_syntax.sh を実行する。

### Task 1: ディレクトリ構造とAutoLoad設定
- 作成: `res://scripts/hex_mvp/`
- 作成: `res://scenes/hex_mvp/`
- `project.godot` に AutoLoad `GameState` を追加（後続タスク完了後）
- 完了基準: ディレクトリが存在する

### Task 2: GameState.gd（オートロード）
- ファイル: `scripts/hex_mvp/GameState.gd`
- 内容: 4.1節の仕様を実装
- メソッド: `reset_run()`, `add_to_deck()`, `get_initial_deck()`
- 完了基準: GDScript構文エラーなし

### Task 3: WaveConfig.gd
- ファイル: `scripts/hex_mvp/WaveConfig.gd`
- 内容: 4.2節の仕様を実装
- メソッド: `generate_enemy_placement(composition, hex_grid, rng) -> Array`
  - 敵ゾーン（row 8-10）の有効セルから重複なくランダム選択
  - スタック制限（3体/セル）に注意
  - 戻り値: `[{unit_type: int, col: int, row: int}, ...]`
- 完了基準: 構文エラーなし、placementテスト時に有効セル内に収まる

### Task 4: RewardGenerator.gd
- ファイル: `scripts/hex_mvp/RewardGenerator.gd`
- 内容: 4.4節の仕様を実装
- メソッド: `generate_choices(rng) -> Array[int]`
  - 突・守・崩を順序ランダムで返す
- 完了基準: 構文エラーなし

### Task 5: TitleScreen
- ファイル: `scenes/hex_mvp/TitleScreen.tscn` + `scripts/hex_mvp/TitleScreen.gd`
- 内容: 5.1節の仕様
- 完了基準: 起動して「ゲーム開始」押下で DeploymentScreen に遷移

### Task 6: DeploymentScreen（最重要）
- ファイル: `scenes/hex_mvp/DeploymentScreen.tscn` + `scripts/hex_mvp/DeploymentScreen.gd`
- 内容: 5.2節の仕様
- 実装ポイント:
  - HexGrid.gd を子ノードとして配置
  - クリック判定は `_input` または `_unhandled_input` でマウス座標→セル変換
  - セル変換は逆ピクセル→ヘックス計算（参考実装可）
  - ユニットトレイは Container を使ったボタン群
  - 配置済みユニットは PoCUnit 流用、ただしバトルロジックは動かさない（visualのみ）
- 完了基準: 配置・取り消し・配置完了が動作

### Task 7: BattleScreen
- ファイル: `scenes/hex_mvp/BattleScreen.tscn` + `scripts/hex_mvp/BattleScreen.gd`
- 内容: 5.3節の仕様
- 実装ポイント:
  - PoCBattle.gd を流用するが、setup_units_for_pattern は呼ばない
  - 代わりに GameState.deployed_units と WaveConfig.generate_enemy_placement で直接ユニット生成
  - PoCMain.gd のログ表示処理を移植（_on_attack_logged 等）
- 完了基準: 配置情報通りにユニットが召喚され、自動戦闘が動作

### Task 8: RewardScreen
- ファイル: `scenes/hex_mvp/RewardScreen.tscn` + `scripts/hex_mvp/RewardScreen.gd`
- 内容: 5.4節の仕様
- 完了基準: 3択表示・選択でデッキ反映・次Wave遷移

### Task 9: ResultScreen
- ファイル: `scenes/hex_mvp/ResultScreen.tscn` + `scripts/hex_mvp/ResultScreen.gd`
- 内容: 5.5節の仕様
- 完了基準: 勝敗別表示・タイトル復帰

### Task 10: project.godot 更新
- AutoLoad に `GameState=*res://scripts/hex_mvp/GameState.gd` を追加
- run/main_scene を `res://scenes/hex_mvp/TitleScreen.tscn` に変更（任意・MVP単体実行時のみ）
- 完了基準: Godotエディタで起動時にAutoLoadエラーが出ない

### Task 11: 統合テスト（手動）
- 起動 → タイトル → 配置 → バトル → リワード × 2 → クリア画面
- 各画面の遷移確認
- 敗北パスの確認（弱い配置でWave1敗北させる）
- 完了基準: 9節の受入基準を全て満たす

---

## 11. 参考情報

### 11.1 PoCで確認済みの動作
- 3すくみカウンター（カウンター倍率2倍）
- BFS経路探索（自軍は通過可、敵軍は完全ブロック）
- スタック制限（同セル3体）
- バトル終了判定（全滅 or 敵ベース到達）

### 11.2 ヘックスセル ⇔ ピクセル変換
- HexGrid.hex_to_pixel(col, row) で順方向変換あり
- 逆変換（ピクセル→セル）は新規実装が必要
  - 推奨: 全セルに対して距離計算 → 最近傍セルを返すブルートフォース実装で十分（11行 x 6列 = 66セル）

### 11.3 既存コード再利用マップ
| 機能 | 再利用元 |
|---|---|
| ヘックス描画・経路探索 | scripts/poc/HexGrid.gd |
| ユニット定義・戦闘 | scripts/poc/PoCUnit.gd |
| 戦闘ループ | scripts/poc/PoCBattle.gd（パターン関数除く） |
| ログ表示UI | scripts/poc/PoCMain.gd の _on_attack_logged / _on_kill_logged |
