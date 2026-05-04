STATUS: 廃止（→ docs/GAME_DESIGN_V0_2_MVP.md）
最終更新: 2026-05-04

# 要件定義書: Qスロット・フェーズアクションバー (Q-Slot Phase Action Bar)

作成日: 2026-04-25
状態: 承認済み・実装待ち

---

## 概要

呪文スロット（Q1/Q2/Q3）をバトル外フェーズではフェーズ専用アクションバーとして転用する。
SCRATCH/SHOP/NEXT_EI 各フェーズに対応したアクションを Q1/Q2/Q3 に割り当て、既存のフェーズ操作ボタン（準備完了 / 次へ進む / スキップ）を廃止する。

---

## REQ-QPA-01: 全体動作モード

| モード | 状態 | Q1/Q2/Q3 内容 |
|---|---|---|
| BATTLE | バトル進行中 | 通常呪文スロット（既存仕様・変更なし） |
| SCRATCH | 報酬選択中 | 確定 / 覗き見 / 強欲 |
| SHOP | ショップ中 | 退店 / リロール / 交渉 |
| NEXT_EI | 次バトル準備中 | 出撃 / 偵察 / 暗転 |

- モード判定は `EnemyPanelManager._phase` に同期する。
- BATTLE モード復帰時は `SpellSlotSystem.draw_to_fill_slots()` で呪文を再充填する。

---

## REQ-QPA-02: バトル終了時のスロット表示クリア

```
バトル勝利 / 敗北
  ↓
SpellSlotSystem.release_all_slots() を呼び出さず、
表示専用クリアメソッド clear_spell_display() を新設して呼ぶ
  ↓
slots[i] の spell/condition/mana_cost/synth_level/base_card_name/range_variant をクリア
（GameSession.spell_hand / spell_deck / spell_discard には触らない）
  ↓
GameUIQueue.update_spell_slots() で空表示に切り替わる
```

- **デッキからは除去しない**（`GameSession.spell_hand` 維持）
- **バトル再開時**: NEXT_EI 終了 → BATTLE 開始のタイミングで `draw_to_fill_slots()` 実行

---

## REQ-QPA-03: SCRATCHフェーズ アクション仕様

| スロット | アクション名 | 効果 | コスト |
|---|---|---|---|
| Q1 | 確定 | 選択中マスを確定して報酬獲得し SHOP フェーズへ遷移 | なし |
| Q2 | 覗き見 | 選択中マスの隣接3マス（上下左右で領域内のみ）の中身を公開 | 金20G |
| Q3 | 強欲 | 1マスを犠牲にして残り中央マス＋自由1マスの2マスを取得。犠牲マスは選択不可 | 1マス無効化 |

### Q1: 確定
- 前提: SCRATCH画面で active_index が選択済み（既存 `_on_scratch_selected` 経路）
- 押下時: 選択中の `active_index` のセルに対して `_on_scratch_selected(card_data, cell)` を呼ぶ
- 未選択時: 押下不可（グレーアウト）

### Q2: 覗き見
- 前提: `GameSession.gold >= 20`
- 押下時:
  1. `GameSession.gold -= 20`
  2. 現在の `active_index` の隣接3マス（上下左右、盤外除外）の `_scratch_rewards[i]` を表示
  3. 表示済みマスは再公開不可（フラグ管理）
- 押下不可: 金不足 / 既に隣接全て公開済み

### Q3: 強欲
- 前提: SCRATCH 開始時のみ押下可（取得確定後は不可）
- 押下時:
  1. ユーザーに「犠牲にするマス」を1つ選択させる（クリック待ち）
  2. 選択マスは disabled 表示（暗転＋クリック不可）
  3. 残りマスから2マス取得可能モードへ遷移
  4. 2マス取得完了後 SHOP フェーズへ遷移
- 押下不可: 既に Q1/Q2 を実行後

---

## REQ-QPA-04: SHOPフェーズ アクション仕様

| スロット | アクション名 | 効果 | コスト |
|---|---|---|---|
| Q1 | 退店 | NEXT_EI フェーズへ遷移 | なし |
| Q2 | リロール | 商品9枠を全て引き直す（初回無料、以降は金消費） | 金 X G（**未決定**） |
| Q3 | 交渉 | 成功60%: 全商品-30% / 失敗40%: 即退店＋次ショップのレア度1段階低下（次回1ショップのみ） | なし |

### Q1: 退店
- 押下時: `set_phase(EnemyPanelPhase.NEXT_EI)`
- 押下不可: 商品購入処理中

### Q2: リロール
- 状態管理: `GameSession.shop_reroll_count` （セッション全体ではなく**現ショップ内**カウント）
- リロールコスト: 初回 0G、2回目以降 X G（**未決定**: 案として 30G 固定 / 50G * 累積回数）
- 押下時:
  1. コスト判定（`shop_reroll_count == 0` なら無料）
  2. `GameSession.gold -= cost`
  3. `_generate_shop_items(9)` を再実行して再描画
  4. `shop_reroll_count += 1`
- 押下不可: 金不足

### Q3: 交渉
- 押下時:
  1. `randf() < 0.6` で成功判定
  2. 成功: 全商品の `price` を `int(price * 0.7)` に更新
  3. 失敗:
     - `GameSession.next_shop_rarity_penalty = true` を立てる
     - `set_phase(EnemyPanelPhase.NEXT_EI)`（即退店）
- 1ショップ内で1回限定: `shop_negotiated` フラグで制御
- 押下不可: 既に交渉済み

---

## REQ-QPA-05: NEXT_EIフェーズ アクション仕様

| スロット | アクション名 | 効果 | コスト |
|---|---|---|---|
| Q1 | 出撃 | バトル開始（既存「準備完了」と同義） | なし |
| Q2 | 偵察 | 敵1マスのステータス（HP/ATK）を公開 | 金 Y G（**未決定**） |
| Q3 | 暗転 | 押下不可・グレーアウト表示固定 | ー |

### Q1: 出撃
- 押下時: `ready_to_battle.emit()`（既存シグナル）
- 押下不可: 自陣に1ユニットも配置されていない（既存 `_has_at_least_one_unit()` チェック流用）

### Q2: 偵察
- 偵察コスト: **未決定**（案として 30G / 40G / 50G、敵レアリティ別の固定値）
- 押下時:
  1. ユーザーに「偵察対象マス」を敵陣9マスから1つ選択させる（クリック待ち）
  2. `GameSession.gold -= Y`
  3. 選択マスのセルに HP/ATK を上書き表示
- 押下不可: 金不足 / 偵察対象なし
- **注記**: 現在 `_get_next_enemy_layout()` は全 false 配列を返すフォールバック実装。実装フェーズで `wave_manager` から次バトルの敵配置を取得する処理を追加すること。

### Q3: 暗転
- 常時 disabled 表示（テキスト「未使用」、グレーアウト）
- 押下不可・gui_input 接続なし

---

## REQ-QPA-06: フェーズ遷移フロー

```
バトル勝利
  ↓ clear_spell_display()
SCRATCH（Q1確定 / Q2覗き見 / Q3強欲）
  ↓ Q1で確定 or 報酬選択完了
SHOP（Q1退店 / Q2リロール / Q3交渉）
  ↓ Q1退店 or 交渉失敗
NEXT_EI（Q1出撃 / Q2偵察 / Q3暗転）
  ↓ Q1出撃 or 敵エリアクリック（既存）
バトル開始
  ↓ draw_to_fill_slots()
BATTLE（通常呪文スロット復帰）
```

---

## REQ-QPA-07: 既存ボタン廃止

以下の既存ボタンは廃止する：

| 廃止対象 | 場所 | 移行先 |
|---|---|---|
| 「準備完了」ボタン | `EnemyPanelManager._build_next_ei_ui()` / `_build_shop_ui()` | NEXT_EI Q1（出撃）/ SHOP Q1（退店） |
| 「次へ進む」ボタン | `RestScreenManager.create_footer()` | NEXT_EI Q1（出撃） |
| 「スキップ」ボタン | `RestScreenManager.create_footer()` | 廃止（バリデーション必須化） |

- フッター自体は `error_label` 表示のため残す（ボタン2つを削除）
- スキップ動作は廃止（最低1ユニット配置を必須化）

---

## REQ-QPA-08: UI仕様（GameUIQueue.gd）

### 8.1 スロット表示の3状態

| 表示モード | name_lbl | cond_lbl | cost_lbl | status_lbl | synth_badge | range_lbl |
|---|---|---|---|---|---|---|
| BATTLE（既存） | 呪文名 | 条件タグ | "コスト: N" | 発動可否 | Lv表示 | 範囲表示 |
| PHASE_ACTION | アクション名 | 効果説明（要約） | コスト表示（"なし" / "金20G" / "1マス" 等） | 押下可否 | 非表示 | 非表示 |
| EMPTY | "─" | "" | "" | "" | 非表示 | 非表示 |

### 8.2 フェーズアクション時の色定義（既存定数を流用）

| スロット状態 | 背景色 | テキスト色 |
|---|---|---|
| 押下可 | `COLOR_SLOT_READY_BG` (0.18, 0.32, 0.22) | `COLOR_LABEL_READY` |
| 押下不可（コスト不足等） | `COLOR_SLOT_LOADED_OFF` (0.12, 0.15, 0.22) | `COLOR_LABEL_DISABLED` |
| 暗転（Q3 NEXT_EI） | `COLOR_SLOT_EMPTY` (0.08, 0.10, 0.14, 0.8) | `COLOR_LABEL_EMPTY` |

### 8.3 ヘッダーラベル

- BATTLE: 既存「Q1 (前列)」「Q2 (中列)」「Q3 (後列)」
- PHASE_ACTION: 「Q1 / [フェーズ名]」「Q2 / [フェーズ名]」「Q3 / [フェーズ名]」
  - 例: 「Q1 / SCRATCH」

### 8.4 ヘッダー色

- BATTLE: 緑系 `Color(0.5, 0.7, 0.5)`（既存）
- SCRATCH: 黄系 `Color(0.85, 0.75, 0.4)`
- SHOP: 金系 `Color(1.0, 0.85, 0.2)`
- NEXT_EI: 赤系 `Color(0.85, 0.4, 0.4)`

### 8.5 入力処理切替

- `_on_spell_slot_input(event, slot_index)` 内で、`main.spell_slot_system.mode` を判定
- BATTLE: 既存処理（左クリック→キャスト、右クリック→破棄、D&D→合成）
- PHASE_ACTION: 左クリック→該当アクション実行、右クリック・D&D は無効化

---

## REQ-QPA-09: SpellSlotSystem 拡張仕様

```gdscript
# モード列挙
enum SlotMode { BATTLE, PHASE_ACTION }
var mode: SlotMode = SlotMode.BATTLE

# フェーズアクションスロットデータ
# slots[i] にフェーズアクション時は以下を格納:
slots[i] = {
  "spell": null,                          # nullで判別
  "condition": "",                        # 未使用
  "mana_cost": 0,                         # 未使用
  "enabled": bool,                        # 押下可否
  "synth_level": 1, "base_card_name": "", # 未使用
  "range_variant": "default",
  "value_mult": 1.0, "duration_mult": 1.0,
  # 拡張フィールド
  "is_action": true,                      # フェーズアクション識別フラグ
  "action_id": String,                    # "scratch_confirm" / "shop_reroll" 等
  "action_label": String,                 # 表示名「確定」「リロール」等
  "action_desc": String,                  # 効果説明
  "action_cost_text": String,             # 「金20G」「1マス」「なし」
  "action_callback": Callable,            # 押下時の処理
}

# 新メソッド
func clear_spell_display() -> void
# 各スロットの spell/synth_* をリセットするが GameSession.spell_* には触らない

func set_phase_actions(actions: Array) -> void
# actions = [{action_id, action_label, action_desc, action_cost_text, enabled, action_callback}, ...] 3要素
# mode を PHASE_ACTION に切替し、slots[i] にアクションをセット

func restore_battle_mode() -> void
# mode を BATTLE に戻し、draw_to_fill_slots() を呼ぶ

func cast_action(slot_index: int) -> bool
# PHASE_ACTION モードでスロット押下時に呼ぶ
# slot[i].action_callback.call() を実行
```

---

## REQ-QPA-10: EnemyPanelManager 拡張仕様

```gdscript
# 既存フェーズに加え、Qスロット連動を追加
func set_phase(phase: EnemyPanelPhase, _context: Dictionary = {}) -> void:
    # 既存処理...
    _bind_q_slot_actions(phase)   # ← 追加

func _bind_q_slot_actions(phase: EnemyPanelPhase) -> void:
    var sys = _get_spell_slot_system()
    if sys == null:
        return
    var actions: Array
    match phase:
        EnemyPanelPhase.SCRATCH:
            actions = _build_scratch_actions()
        EnemyPanelPhase.SHOP:
            actions = _build_shop_actions()
        EnemyPanelPhase.NEXT_EI:
            actions = _build_next_ei_actions()
    sys.set_phase_actions(actions)

# 各 _build_*_actions() は REQ-QPA-03/04/05 の仕様に従い 3要素配列を返す
```

- `_get_spell_slot_system()` は `Main.spell_slot_system` を参照する
- 「準備完了」ボタン生成コードは削除（NEXT_EI / SHOP の両方）

---

## REQ-QPA-11: GameSession 拡張仕様

```gdscript
# 追加フィールド
var shop_reroll_count: int = 0          # 現ショップ内リロール回数
var shop_negotiated: bool = false       # 現ショップで交渉済みか
var next_shop_rarity_penalty: bool = false  # 次回ショップのレア度ペナルティフラグ
var scratch_peeked: Array = []          # 覗き見済みインデックス
var scratch_sacrificed_index: int = -1  # 強欲犠牲マスインデックス
var scratch_action_used: String = ""    # 使用済みSCRATCHアクション ID
```

- ショップ離脱時に `shop_reroll_count` / `shop_negotiated` をリセット
- SCRATCH 終了時に `scratch_peeked` / `scratch_sacrificed_index` / `scratch_action_used` をリセット

---

## REQ-QPA-11b: 疎結合設計原則

### バランス値の一元管理

全コスト・確率・ペナルティ値を `scripts/PhaseActionConfig.gd`（新規・Autoload）に集約。
ロジック側はこのファイルだけ参照する。

```gdscript
# PhaseActionConfig.gd
# バランス調整用定数。ここだけ変えれば全体に反映される。
extends Node

# --- SHOP リロールコスト ---
const REROLL_COSTS: Array[int] = [0, 30, 50]  # index=使用回数（3回目以降は末尾固定）

# --- NEXT_EI 偵察コスト ---
const SCOUT_BASE_COST: Dictionary = {1: 20, 2: 35, 3: 55}  # キー=Act番号
const SCOUT_COST_PER_USE: int = 20  # 使用のたびに加算

# --- SHOP 交渉 ---
const NEGOTIATE_SUCCESS_RATE: float = 0.6
const NEGOTIATE_DISCOUNT: float = 0.30   # 成功時の値引き率（1.0 - この値が乗数）
const NEGOTIATE_PENALTY_RARITY_SHIFT: int = 1  # 失敗時にレア度を下げるステップ数

# --- SCRATCH 覗き見 ---
const PEEK_COST: int = 20

# --- レアリティ重みテーブル（ペナルティ適用後）---
const RARITY_WEIGHTS_NORMAL: Dictionary   = {"common": 70, "uncommon": 20, "rare": 8, "epic": 2}
const RARITY_WEIGHTS_PENALIZED: Dictionary = {"common": 85, "uncommon": 12, "rare": 3, "epic": 0}

func get_reroll_cost(use_count: int) -> int:
    return REROLL_COSTS[min(use_count, REROLL_COSTS.size() - 1)]

func get_scout_cost(act: int, use_count: int) -> int:
    var base: int = SCOUT_BASE_COST.get(act, SCOUT_BASE_COST[1])
    return base + use_count * SCOUT_COST_PER_USE
```

### コンポーネント間の疎結合

```
【禁止】EnemyPanelManager が SpellSlotSystem を直接参照・呼び出す
【禁止】SpellSlotSystem が EnemyPanelManager のフェーズを知る

【正しい依存方向】
  EnemyPanelManager
    ↓ シグナル emit: phase_actions_ready(actions: Array)
  Main.gd（ワイヤリング層）
    ↓ 受け取り、SpellSlotSystem.set_phase_actions(actions) を呼ぶ
  SpellSlotSystem
    ↓ シグナル emit: slot_action_triggered(slot_index: int, action_id: String)
  Main.gd
    ↓ 受け取り、EnemyPanelManager.execute_action(action_id) を呼ぶ
  EnemyPanelManager（アクション実行）
```

- `EnemyPanelManager` は actions の Array を組み立ててシグナルで渡すだけ。SpellSlotSystem を知らない。
- `SpellSlotSystem` はアクションデータ（ラベル・コスト・有効フラグ）を保持するだけ。EnemyPanelManager を知らない。
- バランス値は `PhaseActionConfig` のみが持つ。両者ともそこだけ参照。
- `PhaseActionDefs.gd`（新規）でフェーズごとのアクション定義を構築。EnemyPanelManager から分離。

### 新規ファイル構成

| ファイル | 役割 |
|---|---|
| `scripts/PhaseActionConfig.gd` | バランス値一元管理（Autoload） |
| `scripts/PhaseActionDefs.gd` | フェーズ別アクション定義組み立て（純粋データ） |

---

## REQ-QPA-12: 実装対象ファイル

| ファイル | 変更内容 | 想定追加行数 |
|---|---|---|
| `scripts/SpellSlotSystem.gd` | mode 切替・set_phase_actions / clear_spell_display / cast_action / restore_battle_mode | +60 |
| `scripts/GameUIQueue.gd` | フェーズアクション表示分岐・ヘッダー色変更・入力処理分岐 | +80 |
| `scripts/EnemyPanelManager.gd` | _bind_q_slot_actions / _build_*_actions 3メソッド・準備完了ボタン削除 | +120 / -20 |
| `scripts/RestScreenManager.gd` | 「次へ進む」「スキップ」ボタン削除・create_footer 簡素化 | -30 |
| `scripts/GameSession.gd` | フィールド追加（REQ-QPA-11） | +10 |
| `scripts/Main.gd` | バトル終了時 clear_spell_display 呼び出し / バトル開始時 restore_battle_mode 呼び出し | +10 |

### ファイルサイズチェック

- `EnemyPanelManager.gd` は現在 400行。+120 で **520行（review trigger 超過）**
  - **対応**: アクション定義部を `scripts/PhaseActionDefs.gd` に分離（_build_scratch_actions 等を移動）
- `GameUIQueue.gd` は現在 479行。+80 で **559行（review trigger 超過）**
  - **対応**: フェーズアクション表示処理を `scripts/PhaseActionRenderer.gd` または GameUIQueue 内部のヘルパー関数として整理（既存の update_spell_slots を分割）
- `SpellSlotSystem.gd` は現在 519行。+60 で **579行（review trigger 超過）**
  - **対応**: PHASE_ACTION モードのロジックを既存の合成ロジックと並列に置く。リファクタは別タスクで対応（今回は機能追加のみ）

---

## REQ-QPA-13: 受け入れ基準

- [ ] バトル終了直後にQ1/Q2/Q3の呪文名表示が消える
- [ ] SCRATCH画面でQ1/Q2/Q3 が「確定」「覗き見」「強欲」になる
- [ ] SCRATCH Q2押下で金20G消費し隣接3マス（盤外除外）が公開される
- [ ] SCRATCH Q3押下で1マス選択→以降そのマスがクリック不可になる
- [ ] SHOP画面でQ1/Q2/Q3 が「退店」「リロール」「交渉」になる
- [ ] SHOP Q1押下でNEXT_EIフェーズへ遷移する
- [ ] SHOP Q2押下でリロール実行（初回無料、以降コスト消費）
- [ ] SHOP Q3押下で60%確率成功時に全商品price×0.7、失敗時に即退店＋ペナルティフラグ
- [ ] NEXT_EI画面でQ1/Q2/Q3 が「出撃」「偵察」「暗転」になる
- [ ] NEXT_EI Q1押下でバトル開始
- [ ] NEXT_EI Q3は常時グレーアウトでクリック不可
- [ ] バトル開始時に呪文スロットが復帰し draw_to_fill_slots が動作
- [ ] 既存「準備完了」「次へ進む」「スキップ」ボタンが画面に表示されない
- [ ] バトル中の通常呪文スロット動作・合成D&Dが従前通り動作（リグレッション）
- [ ] `GameSession.spell_hand` / `spell_deck` / `spell_discard` がバトル間で維持される

---

## REQ-QPA-14: 依存関係

- 前提タスク: なし（既存 `req_spell_synthesis.md` と独立。合成機能と非干渉）
- 既存関数の再利用:
  - `SpellSlotSystem.draw_to_fill_slots()`（バトル復帰時）
  - `EnemyPanelManager._on_scratch_selected()`（SCRATCH Q1確定の本体）
  - `EnemyPanelManager._generate_shop_items()`（SHOP リロール時）
  - `RestScreenManager._has_at_least_one_unit()`（NEXT_EI Q1 出撃可否判定）
- 影響範囲:
  - 直接変更: `SpellSlotSystem.gd` / `GameUIQueue.gd` / `EnemyPanelManager.gd` / `RestScreenManager.gd` / `GameSession.gd` / `Main.gd`
  - 影響なし: `SpellExecutor.gd` / `BoardManager.gd` / `DeckManager.gd`

---

## REQ-QPA-15: 制約・注意事項

- バトル中は既存の呪文スロット仕様（合成・キャスト・破棄）を**完全維持**する
- フェーズアクションスロットには合成D&Dを**接続しない**（誤操作防止）
- スロットUIノード（panel/labels/glow_rect 等）は**再利用**する。新規Control生成は最小限に
- `GameSession.spell_*` 配列はバトル外フェーズで**変更しない**（呪文ドロー保全）
- 用語: 「呪文」= spell（既存通り）。「アクション」= action（フェーズアクションのみで使用）
- BATTLE モード復帰時、合成カードがスロットに残ったまま `clear_spell_display()` を呼ぶと再表示されない問題に注意。表示クリアは spell オブジェクト参照のみ消す（実データは GameSession に維持されるため、`draw_to_fill_slots()` が再充填する）

---

## 確定済み仕様（追加決定事項）

1. **SHOP Q2 リロールコスト**: 案C採用
   - 1回目: 0G（無料）
   - 2回目: 30G
   - 3回目以降: 50G（固定上限）
   - `shop_reroll_count` で回数管理

2. **NEXT_EI Q2 偵察コスト**: Act別テーブル＋回数増加
   ```gdscript
   const SCOUT_BASE_COST: Dictionary = {1: 20, 2: 35, 3: 55}  # Act別基礎コスト
   # 偵察コスト = SCOUT_BASE_COST[act] + (scout_count * 20)
   # scout_count は同一NEXT_EIフェーズ内の使用回数
   ```

3. **交渉失敗時のレア度ペナルティ**: `_generate_shop_items()` 内で適用
   - `GameSession.next_shop_rarity_penalty == true` のとき rarity 重みを1段階下げる
   - common はペナルティ対象外（下限がcommon）
   - 適用後 `next_shop_rarity_penalty = false` にリセット

4. **SCRATCH Q3 強欲の詳細フロー**: 確定
   - 押下 → 「犠牲にするマスを選んでください」モードへ
   - 選択したマスが暗転（クリック不可）
   - 残り8マスから順番に2マスクリックで取得
   - 2マス取得完了 → SHOPフェーズへ自動遷移

5. **action_desc 表示**: スロット内3行表示
   - `cond_lbl` を廃止し `action_desc_lbl`（3行・font_size 11）に差し替え
   - スロット高さは既存のまま（3行収まるよう font_size 調整）

## 未決定事項（実装フェーズで確定）

1. **次バタル敵配置取得方法**:
   - `_get_next_enemy_layout()` のフォールバック実装を解消し、`wave_manager` から次wave敵配置を取得する具体的API（要 WaveManager 側調査）

---

## 実装可能性チェックリスト 自己検証結果

- [x] 座標・サイズ・色が具体値で指定されているか（既存 GameUIQueue 定数を流用、ヘッダー色を新規定義）
- [x] 関数シグネチャ（引数・戻り値・型）が確定しているか（REQ-QPA-09 / 10）
- [x] 条件分岐の全ケース（正常系・異常系・エッジケース）が網羅されているか（押下不可条件を各アクションに明記）
- [x] 既存コードとの連携箇所（呼び出し先・呼び出し元）が明記されているか（REQ-QPA-12 / 14）
- [x] エッジケース（空・null・上限値・下限値）の扱いが決まっているか（金不足 / 既使用フラグ / wave_manager null）
- [x] 失敗時の挙動（エラー表示・リトライ・ログ）が定義されているか（押下不可時グレーアウト）
- [x] パフォーマンス要件: なし（フェーズ切替時の単発処理のみ）
- [x] 用語整合性: spell（呪文）/ mana / gold / col / range は既存定義に準拠（独自別名なし）

---

## 用語SSOT遵守の確認結果

- ssot_canonical_terms.txt は本リポジトリで未配置（Glob検索 0件）
- 既存ファイルの用語に準拠: `spell`（呪文）、`mana`（マナ）、`gold`（金）、`col`（列）、`range`（範囲）、`spd`（速度）
- 禁止別名なし（`speed` / `cost` / `money` 等は使用していない）
