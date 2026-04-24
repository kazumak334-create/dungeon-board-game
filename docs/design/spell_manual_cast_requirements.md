# 呪文手動発動システム＋プロトコルシステム 要件定義書

## 1. 概要

本要件定義は以下3点をカバーする。

1. **呪文システムの手動発動化**（PvE・高優先度）
   - 現在の「条件+マナで自動発動」を廃止し、プレイヤーがバトル画面で任意のタイミングで発動する方式へ切り替える。
2. **プロトコルシステム**（PvP専用・低優先度）
   - PvE完全クリア後のPvP解禁と同時に登場。呪文スロットに「プロトコル」を装着すると呪文が自動発動に切り替わる。
   - デジタル的トーンの世界観的伏線として機能する。
3. **呪文発動データ収集ログ**（中優先度）
   - 将来の学習モデル転換（AI化）に備え、発動タイミング・盤面状態・マナ量をJSON形式で記録する。

核体験（「盤面を設計して、介入を仕込んで、答え合わせを観戦する」）において、呪文は「介入」の意思決定要素である。自動発動からプレイヤー介入へ戻すことで、観戦中の能動性を高める。

---

## 2. 実装対象

| 対象ファイル | 変更種別 | 主な変更箇所 |
|---|---|---|
| `scripts/SpellSlotSystem.gd` | 改修 | `process_slots()`自動発動削除、`can_cast()`/`cast_spell()`追加、ログ出力追加 |
| `scripts/GameUI.gd` | 改修 | `_build_spell_slots()`に発動ボタン/クリック対応、`update_spell_slots()`でグレーアウト/活性化状態反映 |
| `scripts/Main.gd` | 改修 | `process_slots()`呼び出し箇所の整理（手動発動のため毎フレーム呼び出し不要化）、ログ保存窓口 |
| `scripts/SpellActivationLogger.gd` | **新規** | 発動ログ収集・JSON書き出し（Phase B） |
| `scripts/Protocol.gd` | **新規** | プロトコルデータクラス（Phase C） |
| `scripts/ProtocolDB.gd` | **新規** | プロトコル定義DB（Phase C） |
| `data/protocols.json` | **新規** | プロトコル定義データ（Phase C） |
| `docs/GAME_DESIGN.md` | 追記 | 呪文手動発動ルール、プロトコルシステム章追加 |

### ファイルサイズ事前チェック

- `SpellSlotSystem.gd`: 現状 317行 → Phase A改修後 推定 330〜360行（問題なし）
- `GameUI.gd`: 現状 約 650行前後 → Phase A改修後 推定 +40行（問題なし、800行未満）
- Phase C（プロトコル）は**新規ファイル分離必須**。`SpellSlotSystem.gd`に詰め込まない。

---

## 3. データ構造

### 3-1. 呪文スロット構造（既存維持・フィールド追加なし）

```gdscript
# SpellSlotSystem.slots[i]
{
    "spell": Object,      # 呪文データ
    "condition": String,  # 発動条件（手動発動でも判定に使用）
    "mana_cost": int,     # マナコスト
    "enabled": bool       # 呪文が装填されているか
}
```

**変更方針**：スロット構造は変更しない。`condition`は「発動可否判定」として継続利用する。

### 3-2. プロトコル（Phase C 新規）

```gdscript
# Protocol.gd
class_name Protocol
extends RefCounted

var id: String              # 例: "proto_autocast_common"
var display_name: String    # 例: "AUTO.EXEC"
var rarity: String          # "common" | "uncommon" | "rare" | "epic" | "legend" | "god"
var flavor_text: String     # 世界観テキスト（デジタル的トーン）
var effect_type: String     # "autocast" 固定（初期版）
var effect_params: Dictionary  # 追加効果パラメータ（将来拡張）
```

**レアリティ6段階**：Common / Uncommon / Rare / Epic / Legend / GOD（6段階）。GODは既存のレアリティ体系（cards.json等）で使用済みのため、整合性を保つ。

### 3-3. 装着状態（SpellSlotSystemへの追加フィールド）

```gdscript
# SpellSlotSystem.slots[i] に追加（Phase Cのみ）
{
    ...既存フィールド...,
    "protocol": Object  # Protocol or null（装着時のみ非null）
}
```

### 3-4. 発動ログエントリ（Phase B 新規）

```json
{
  "timestamp": "2026-04-20T12:34:56.789Z",
  "session_id": "uuid-v4",
  "wave": { "big": 2, "small": 3 },
  "trigger": "manual",
  "spell": {
    "id": "spell_firebolt",
    "name": "炎の矢",
    "mana_cost": 30
  },
  "condition": "ally_front:avg_hp < 50",
  "condition_satisfied": true,
  "mana_before": 45.0,
  "mana_after": 15.0,
  "board_state": {
    "ally": [[1,0,0],[1,1,0],[0,0,1]],
    "enemy": [[1,1,0],[1,1,0],[0,1,0]],
    "ally_avg_hp_ratio": 0.42,
    "enemy_avg_hp_ratio": 0.88
  },
  "slot_index": 1,
  "protocol_attached": false
}
```

`trigger` は `"manual"` / `"autocast_protocol"` の2種類を想定する。

---

## 4. 実装詳細

### 4-1. Phase A：呪文手動発動実装（高優先度）

#### 4-1-1. SpellSlotSystem.gd 改修

**削除**：
- `process_slots(delta)` の自動発動ループ本体を削除する。関数自体は残してもよいが、呼び出し元から切り離す。

**新規追加**：

```gdscript
# 発動可否判定（UI表示・発動前チェック兼用）
func can_cast(index: int) -> bool:
    if index < 0 or index >= 3:
        return false
    var slot = slots[index]
    if not slot["enabled"] or slot["spell"] == null:
        return false
    if deck_manager == null or deck_manager.mana < slot["mana_cost"]:
        return false
    # 条件チェック（既存 _check_condition を流用）
    if not _check_condition(slot["condition"]):
        return false
    return true

# 発動不可理由取得
func get_cast_block_reason(index: int) -> String:
    if index < 0 or index >= 3:
        return "無効なスロット"
    var slot = slots[index]
    if not slot["enabled"] or slot["spell"] == null:
        return "空き"
    if deck_manager == null or deck_manager.mana < slot["mana_cost"]:
        return "マナ不足"
    if not _check_condition(slot["condition"]):
        return "条件未達"
    return "発動可"

# 手動発動API
func cast_spell(index: int) -> bool:
    if not can_cast(index):
        return false
    _trigger_spell(index, slots[index])
    return true
```

**_trigger_spell 改修**：
- 引数 `trigger_type: String = "manual"` を追加し、ログ出力時に記録する。
- マナ消費・`spell_executor.execute`・消費型クリアは既存ロジックを維持する。
- Phase B 実装時に `SpellActivationLogger` へログ投入する呼び出しを追加する（後述）。

#### 4-1-2. Main.gd 改修

- `_process()` 内の `spell_slot_system.process_slots(effective_delta)` 呼び出しを**削除**する（584行目付近）。
- 削除により自動発動が完全に停止する。

#### 4-1-3. GameUI.gd 改修（UI要件）

**スロット表示更新** (`update_spell_slots()`)：

発動可否に応じて**4状態**で表示する。

| 状態 | 条件 | パネル色 | ラベル色 | 追加表示 |
|---|---|---|---|---|
| 空き | `spell == null` | `Color(0.08, 0.10, 0.14, 0.8)` | `Color(0.5,0.5,0.5)` | 状態アイコン `·`（中点） |
| 発動不可 | 装填済み & `can_cast(i) == false` | `Color(0.12, 0.15, 0.22)` | `Color(0.5, 0.5, 0.5)` | 状態アイコン `×`、グレーアウト |
| 発動可能 | `can_cast(i) == true` | `Color(0.18, 0.32, 0.22)`（緑がかった活性化色） | `Color(1,1,1)` | 状態アイコン `▶`、縁取り発光（2pxボーダー `Color(0.6, 1.0, 0.7)`）、パルス発光 |
| 発動中 | 左クリック直後0.3秒 | 黒半透明オーバーレイ `Color(0,0,0,0.4)` | 白フラッシュ `modulate=Color(2,2,2)→(1,1,1)` | クールダウンオーバーレイ表示 |

**色定義追加**：

```gdscript
# GameUI.gd 色定義追加
const COLOR_SLOT_EMPTY       = Color(0.08, 0.10, 0.14, 0.8)  # 空きスロット
const COLOR_SLOT_LOADED_OFF  = Color(0.12, 0.15, 0.22)       # 装填・発動不可
const COLOR_SLOT_READY_BG    = Color(0.18, 0.32, 0.22)       # 発動可能（緑がかった活性色）
const COLOR_SLOT_GLOW        = Color(0.6, 1.0, 0.7, 0.85)    # 発動可能の縁取り発光
const COLOR_LABEL_READY      = Color(1.0, 1.0, 1.0)          # 発動可能時ラベル
const COLOR_LABEL_DISABLED   = Color(0.5, 0.5, 0.5)          # 発動不可時ラベル
const COLOR_LABEL_EMPTY      = Color(0.5, 0.5, 0.5)          # 空きスロットラベル
const COLOR_READY_ACCENT     = Color(0.4, 1.0, 0.5)          # 「▶ 発動可」テキスト
const COLOR_FAIL_ACCENT      = Color(1.0, 0.35, 0.35)        # 「× 失敗」テキスト・フラッシュ
```

**スロット構造追加**（`_build_spell_slots()` 改修）：

各スロットに以下のコンポーネントを追加。

| コンポーネント | サイズ | 位置（slot基準） | 用途 |
|---|---|---|---|
| パネル（`ColorRect`） | 90×130 | (0, 0) | 背景色（状態で変化） |
| 縁取り発光（`ColorRect`） | 94×134 | (-2, -2), z_index=-1 | 発動可能時のみ表示 |
| 状態アイコン（`Label`） | 20×14 | (5, 3) | `▶` / `×` / `·` |
| 呪文名ラベル（`Label`） | 80×32 | (5, 18) | 最大2行・`AUTOWRAP_WORD_SMART` |
| 条件タグ（`Label`） | 80×16 | (5, 52) | `[HP<50%]` 等 |
| コストラベル（`Label`） | 80×14 | (5, 72) | `コスト: 30` |
| 発動可否行（`Label`） | 80×16 | (5, 92) | `▶ 発動可` / `× マナ不足` / `× 条件未達` |
| クールダウンオーバーレイ（`ColorRect`） | 90×130 | (0, 0), z_index=+1 | 発動直後0.3秒のみ表示（黒半透明） |

**クリック操作** (`_on_spell_slot_input()` 改修)：

| 操作 | スロット状態 | 挙動 |
|---|---|---|
| 左クリック | 発動可能 | `cast_spell(i)` 呼び出し → 発動演出 → 状態更新 |
| 左クリック | 発動不可 | **振動アニメーション**（パネルを左右に±3px、0.15秒）＋ 発動可否行を赤フラッシュ |
| 左クリック | 空き | 無反応（クリック吸収のみ） |
| 右クリック | 装填済み（可/不可問わず） | `discard_slot(i)` 呼び出し → 状態(A)へ |
| 右クリック | 空き | 無反応 |

**パルスアニメーション**（発動可能状態）：
- 縁取り発光の alpha を 0.55 ⇄ 0.95 で1.2秒周期サインカーブ
- 実装：`Tween.tween_property(glow_rect, "modulate:a", 0.95, 0.6).set_trans(Tween.TRANS_SINE).set_loops()`

**振動アニメーション**（発動失敗時）：
- トリガー：発動不可状態で左クリックされた時のみ
- 実装：`Tween.tween_property(panel, "position:x", base_x + 3, 0.05).set_trans(Tween.TRANS_SINE)` を4回繰り返し（±3px × 4）
- 合計時間：0.15秒

**ホバー挙動** (`mouse_entered` / `mouse_exited` / Timer)：

| 操作 | 挙動 |
|---|---|
| カーソルON | パネルを1px明るく（`modulate.v += 0.1`） |
| カーソルON 0.5秒経過 | ツールチップ表示（呪文詳細＋発動不可理由） |
| カーソルOFF | ツールチップ非表示・modulate戻す |

**活性化状態の更新頻度**：
- マナ量・盤面状態により毎フレーム変化しうるため、`update_spell_slots()` はゲーム進行中（`battle_active`）は `_process` 経由で 0.1〜0.2秒間隔で呼ぶ。
- パフォーマンス負荷を避けるため、タイマー方式で間引く。

**ラベル文字列の更新**：
```
{状態アイコン} {spell.unit_name}
[{condition_display}]
コスト: {mana_cost}
{発動可否ステータス}  ← 新規行
```
発動可否ステータスは `get_cast_block_reason()` の戻り値に応じて以下のように表示：
- `"発動可"` → `▶ 発動可`（`COLOR_READY_ACCENT`）
- `"マナ不足"` → `× マナ不足`（`COLOR_FAIL_ACCENT` の30%輝度）
- `"条件未達"` → `× 条件未達`（`COLOR_FAIL_ACCENT` の30%輝度）
- `"空き"` → `空き`（`COLOR_LABEL_EMPTY`）

#### 4-1-4. 既存条件システムの扱い

- `_check_condition()` / `_check_avg_hp()` / `_check_empty_ratio()` は手動発動でも「発動可否判定」として継続利用する。
- `on_enemy_attack` 系のイベントトリガー型は、手動発動に切り替えると意味を失うため **Phase A では常に `false` を返す**（未実装のまま）。将来的に `condition` 自体を「発動時の盤面メモ」扱いに変える方針は Phase C 以降で再検討する。

---

### 4-2. Phase B：データ収集ログ実装（中優先度）

#### 4-2-1. SpellActivationLogger.gd 新規

```gdscript
class_name SpellActivationLogger
extends RefCounted

var _entries: Array = []
var _session_id: String = ""
var _save_path: String = "user://spell_activation_log.json"

func _init() -> void:
    _session_id = _generate_uuid()

func log_activation(entry: Dictionary) -> void:
    _entries.append(entry)
    if _entries.size() >= 50:  # 50件ごとに書き出し
        flush()

func flush() -> void:
    # 既存ログに追記書き出し
    ...

func build_entry(slot_index: int, slot: Dictionary, trigger_type: String,
                 mana_before: float, mana_after: float,
                 board_manager: Node, main_ref: Node) -> Dictionary:
    # 3-4のJSON構造を構築
    ...
```

#### 4-2-2. Main.gd 統合

- `Main._ready()` 相当で `SpellActivationLogger` インスタンスを生成し、`spell_slot_system.logger = logger` で注入する。
- `_trigger_spell()` 内で `logger.log_activation(logger.build_entry(...))` を呼ぶ。
- シーン終了時（`_exit_tree()` または Result画面遷移時）に `logger.flush()` を呼ぶ。

#### 4-2-3. 収集項目の詳細

| 項目 | 目的 |
|---|---|
| `timestamp` | 時系列分析 |
| `session_id` | セッション単位の集計 |
| `wave` | 難易度コンテキスト |
| `trigger` | 手動/自動（プロトコル）の切り分け |
| `spell.*` | 使用呪文の識別 |
| `condition_satisfied` | 条件未達でも発動したか（手動のみ可能） |
| `mana_before/after` | マナ管理の学習素材 |
| `board_state.*` | 盤面特徴量（味方3×3、敵3×3の占有マスと平均HP率） |
| `slot_index` | スロット選好の学習 |
| `protocol_attached` | Phase C以降の分離用 |

#### 4-2-4. プライバシー・送信

- 初期実装は `user://` 配下にローカル保存のみ。送信機能は実装しない。
- 将来のサーバー送信に備え、`session_id` は UUIDv4 相当で匿名化する。

---

### 4-3. Phase C：プロトコルシステム実装（低優先度・PvP実装時）

#### 4-3-1. PvP解禁フラグ

**注**：本機能はPvP実装時（Phase C）に実装する。現時点では実装しない。

- `GameSession` に `pvp_unlocked: bool` フィールドを追加する（既存構造に依存、実装時要確認）。
- PvE完全クリア（最終Wave討伐）時に `true` へ更新する。
- セーブデータに永続化する。

#### 4-3-2. プロトコル装着UI

**注**：本機能はPvP実装時（Phase C）に実装する。現時点では実装しない。

- PvPシーンでのみ表示するデッキ編成画面（新規または既存DeckPrepの拡張）に「プロトコルスロット」欄を3つ追加する。
- 各呪文スロットに対して1枚のプロトコルを装着できる。
- UIは本要件定義の範囲外（Phase C着手時に別途UI要件定義を作成）。

#### 4-3-3. 装着時の動作変更

- `SpellSlotSystem.set_slot(index, spell, condition, protocol = null)` に `protocol` 引数を追加する。
- `Main._process()` 内で再度 `spell_slot_system.process_autocast_slots(delta)` を呼び出す（手動発動用とは別の専用関数）。
- `process_autocast_slots()` は、プロトコル装着済みスロットのみを対象に既存の自動発動ロジックを実行する。

```gdscript
func process_autocast_slots(delta: float) -> void:
    for i in range(3):
        var slot = slots[i]
        if slot.get("protocol") == null:
            continue  # プロトコル未装着なら手動のみ
        if not can_cast(i):
            continue
        _trigger_spell(i, slot, "autocast_protocol")
```

#### 4-3-4. レアリティと効果（初期版）

| レアリティ | 効果（初期版） | 備考 |
|---|---|---|
| Common | 自動発動のみ | 最低限の利便性 |
| Uncommon | 自動発動＋マナコスト-10% | 効率化 |
| Rare | 自動発動＋条件達成時の発動優先度強化 | 複数条件成立時に先に発動 |
| Epic | 自動発動＋条件緩和（閾値を甘く） | 例: `avg_hp<50` → `avg_hp<60` |
| Legend | 自動発動＋条件無視（常時発動可） | マナだけ見る |
| GOD | 自動発動＋マナコスト無視＋条件無視 | 完全自律（究極のAUTO） |

#### 4-3-5. 世界観的位置づけ（デジタル的トーン）

- 呪文は「魔術」、プロトコルは「古代の演算規約 / 自動化スクリプト」という対比。
- 命名は `AUTO.EXEC` / `SIGIL.LOOP` / `CONDUIT.SYNC` などローマ字＋ドット記法を採用。
- フレーバーテキスト例：
  - Common `AUTO.EXEC`: 「条件節を監視し、閾値到達時に呪文式を自動実行する。」
  - Legend `GODMODE.OVERRIDE`: 「条件節を無視する。呪文は自律し、術者は観測者となる。」
  - GOD `DIVINITY.UNLOCK`: 「マナと条件の束縛から解放される。呪文は意志を持つ。」
- **伏線としての役割**：プレイヤーに「この世界は何らかのシステム上で動いている」という示唆を与える。真実の開示は本要件定義の範囲外。

#### 4-3-6. プロトコル装着時のUI変化（Phase C）

**装着マーク**：
- スロット右上隅に **`⚙ AUTO`** 風バッジを追加（14×14px、位置 `(slot_w - 16, 2)`）。
- バッジ色：`Color(0.3, 0.8, 0.9)`（シアン・デジタルトーン）。
- フォント：等幅系フォント使用を指定（`theme_font = "mono"`）→ 「魔術」との質感差別化。

**発光色の切り替え**：
- プロトコル装着スロットのみ、発動可能時の縁取り発光を**シアン系** `Color(0.3, 0.9, 1.0, 0.85)` に切り替える。
- パルス周期を 1.2秒 → **0.8秒** に短縮（自動化＝機械的リズム）。

**発動時演出の差別化**：
- 手動発動（魔術）：白フラッシュ（`modulate = Color(2,2,2) → (1,1,1)` の0.3秒Tween）
- プロトコル発動（自動化）：シアン縦スキャンライン（`ColorRect` を上→下へ0.2秒で移動）

**ラベル表記の変更**：
- 発動可否行の文言を変更：
  - `▶ 発動可` → `[AUTO.EXEC]`（`COLOR_READY_ACCENT` をシアン `Color(0.3, 0.9, 1.0)` に変更）
  - `× マナ不足` → `[STALL: MANA]`
  - `× 条件未達` → `[STALL: COND]`
- **ローマ字＋角括弧＋ドット記法**で「演算規約」の世界観を表現。

**プロトコル未装着スロットとの共存**：
- 同じ3スロット内で装着/未装着が混在可能。
- UI上は**バッジの有無＋発光色**で区別。
- プレイヤーは「どのスロットが自動で動くか」を一瞥で判別できる。

---

## 5. 実装フェーズと優先度

| Phase | 内容 | 優先度 | 依存 |
|---|---|---|---|
| **A** | 呪文手動発動化（自動発動廃止・UI・発動API） | 高 | なし |
| **B** | 発動ログ収集（JSON保存） | 中 | Phase A |
| **C** | プロトコル（PvP解禁後の自動発動装備） | 低 | Phase A・PvPシステム |

---

## 6. 制約・注意事項

### 6-1. 核体験との整合性

- 「盤面を設計して、介入を仕込んで、答え合わせを観戦する」の「介入」強化に寄与する。
- 観戦中の能動性が上がるが、**3秒ルール**は維持する（発動ボタンを押した結果の効果は3秒で伝わること）。
- プロトコルによる自動発動は「介入の自動化」であり、PvP専用に留めることでPvEの観戦体験は崩さない。

### 6-2. GAME_DESIGN.mdとの整合性

- GAME_DESIGN.mdに以下を追記する必要がある（Architectの別タスクで対応）：
  - 呪文の発動方式を「手動発動（PvE標準）」「自動発動（PvP+プロトコル装着時のみ）」と明記する。
  - プロトコルシステム章を新設する（Phase C着手時）。
- 現状の `CONDITION_DISPLAY_NAMES` 等の条件表記はそのまま継続利用する。

### 6-3. 既存コードとの整合性

- `SpellSlotSystem.discard_slot()`（右クリック破棄）は維持する。
- 消費型呪文（`spell.is_consumable`）の自動クリア処理は `_trigger_spell` 内で維持する。
- `on_enemy_attack` 条件は Phase A 時点で実質無効化されるが、データ定義は残す（Phase C以降の再利用可能性のため）。

### 6-4. テスト・検証

- **Phase A完了時**：
  - `bash tools/ci/tools/ci/check_syntax.sh` でエラー0件を確認する。
  - 4状態の視覚表現を確認する：
    - 空きスロット：暗色＋中点アイコン
    - 発動不可：グレー＋×アイコン＋失敗理由
    - 発動可能：緑色＋▶アイコン＋縁取り発光＋パルス
    - 発動中：黒オーバーレイ＋白フラッシュ
  - 手動発動：左クリックで発動・マナ消費・効果適用を目視確認（ユーザー）。
  - 自動発動が発生しないこと（マナと条件が揃っていても発動しない）を確認する。
  - 発動失敗時の振動アニメーション・赤フラッシュを確認する。
  - ホバー時のツールチップ表示を確認する。
- **Phase B完了時**：
  - `user://spell_activation_log.json` に想定フォーマットでエントリが記録されることを確認する。
- **Phase C完了時**：
  - PvE中はプロトコル装着UIが表示されないことを確認する。
  - PvPでプロトコル装着後は該当スロットのみ自動発動することを確認する。
  - プロトコル装着スロットのUI変化を確認する：
    - AUTOバッジ表示
    - シアン系発光色
    - ローマ字ラベル表記（`[AUTO.EXEC]`等）
    - シアン縦スキャンライン発動演出

### 6-5. 廃止済み設計との関係

- CLAUDE.mdの廃止リストに「アクティブスキル・固有スキル」とあるが、これはユニット側の話であり、**呪文手動発動はプレイヤーの介入手段**として区別される。矛盾しない。
- 念のためCEO確認を経てから実装に移ること。

---

## 7. 未確定事項（要CEO/企画判断）

| # | 項目 | 判断が必要な理由 |
|---|---|---|
| 1 | ログJSONのサーバー送信可否・同意UI | 現状はローカル保存のみ（Phase B） |
| 2 | プロトコル装着UI（PvPデッキ編成画面の設計） | Phase C着手時に別要件定義必要 |
| 3 | PvP解禁フラグの保存形式・セーブデータスキーマ | GameSession改修が必要（Phase C） |

---

## 8. UI基準6項目との整合性チェック

### 1. 3秒ルール：この画面で何ができるか3秒で分かるか
- **○ 達成**：
  - 緑に光っているスロット = 今発動できる呪文
  - グレーのスロット = 待機中（不可）
  - 暗いスロット = 空き
  - タイトル文言「左クリック発動／右クリック破棄」で操作も明示
- **根拠**：色と明度の4段階分離で即時判別可能。テキストを読まずとも発動可否が伝わる。

### 2. 視線の一本化：複数の注意点がないか、視線の流れは明確か
- **○ 達成**：
  - 発動可能時のみスロットが光る → **光源は最大3個**に限定
  - 全スロット発動可でも同じ色・同じパルス周期 → 視線は自然と「最初に光ったスロット」へ
  - 盤面（上）→ スロット（下）の縦方向動線が単一
- **留意**：3スロット同時発動可の場合、プレイヤーの選択肢が並列になる → これは**設計上意図した介入判断**なので問題なし。

### 3. 状態の可視化：現在の状態（選択中・購入済み等）が一目で分かるか
- **○ 達成**：4状態を**色・縁取り・アイコン・テキスト**の4重冗長で表現
  - 空き：暗色＋`·`＋「空き」
  - 不可：グレー＋`×`＋失敗理由
  - 可能：緑＋`▶`＋「発動可」＋パルス発光
  - 発動中：黒オーバーレイ＋白フラッシュ
- プロトコル装着状態もバッジ＋発光色変化で明示。

### 4. 操作の最小化：クリック数は最小か、直感的か
- **○ 達成**：
  - 発動：**1クリック**（左クリックのみ）
  - 破棄：**1クリック**（右クリックのみ、既存）
  - 確認ダイアログ・モーダルなし → 観戦リズムを途切れさせない
- **直感性**：「光っているボタンを押す」は全ゲーム共通の普遍的操作。

### 5. 配信映え：視聴者が見ても何をしているか分かるか
- **○ 達成**：
  - 発動可能時の緑パルス発光 → 視聴者にも「次は何か起こる」予感を与える
  - 左クリック → 白フラッシュ → 呪文エフェクト という**因果の明示**
  - プレイヤーの選択タイミング（「光ってから何秒で押したか」）が配信で可視化される
- **介入の見せ場**：「まだ押さないのか？」「今だ！」の緊張がコメント・配信演出の種になる。

### 6. 世界観の匂わせ：ダークファンタジー+無機質な整合性があるか
- **○ 達成**：
  - 基調：暗青紫の石板のような背景 → ダークファンタジー
  - 発動可能時の緑燐光 → 魔力の気配（説明しない）
  - プロトコル装着時のシアン縦スキャンライン → 「この世界は何かの演算系で動いている」匂わせ
  - `AUTO.EXEC` / `[STALL: COND]` 等のローマ字記法 → 無機質さの注入
- **「説明しない、ただそこにある」**：プロトコルの出自・意味はフレーバーテキスト1行のみ。

---

## 9. 参照

- `docs/design/spell_manual_cast_ui_design.md`（本要件定義書のUI/UX企画書）
- `docs/GAME_DESIGN.md`（設計Single Source of Truth）
- `docs/game_philosophy.md`（3秒ルール・核体験）
- `scripts/SpellSlotSystem.gd`（現実装）
- `scripts/GameUI.gd`（スロットUI現実装：562-626行）
- `scripts/Main.gd`（process_slots呼び出し：584行）
- `scripts/GameUIQueue.gd` 155-160行：Q1ハイライト発光（色彩参考）
- `docs/meta/ui_workflow.md`：UI実装ワークフロー
