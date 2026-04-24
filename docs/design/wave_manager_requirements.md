# Phase 4 #0a WaveManager実装 要件定義書

## 0. 設計判断確定事項（2026-04-18）

### 0.1 ボス連戦の扱い
**決定：** 連戦形式を維持（小Wave2回のイメージで第一形態・第二形態）
- ボスWave = Wave7（第一形態）→ Wave8（第二形態）の2連戦
- WaveConfig.TOTAL_WAVES_PER_BW = 8（小Wave6 + ボス第一形態 + ボス第二形態）
- 既存の`_start_boss_phase2()`ロジックは「Wave8開始」に統合

### 0.2 Act間遷移フロー
**決定：** MapSelectなし（RestScreen→次Act Wave1直行）
- BW完了時：RestScreen表示
- RestScreen終了時：次ActのWaveManager.start_big_wave(next_act)を直接呼び出し
- MapSelect画面は経由しない

### 0.3 死亡ユニット識別キー
**決定：** カードごとに識別（初期配置スロットインデックス併用）
- 記録形式：`{unit_name, rarity, death_wave, initial_slot_index}`
- initial_slot_index（0-8）で同名ユニットを区別
- RestScreenで復帰時、スロット単位で選択可能

---

## 1. 概要

継続ウェーブ型への転換に伴い、1Act = 1BW = 6小Wave + ボス2連戦（計8Wave）の進行管理を担う中核システムを実装する。CombatSystemは個別Waveの戦闘処理に専念し、WaveManagerがWave遷移・状態保持・敵強化係数適用・BW間RestScreen呼び出しを統括する。

**核体験との整合性：** プレイヤーは盤面を設計して介入を仕込み、答え合わせを観戦する。WaveManagerはこの観戦体験の「次のWave」に向けた調整機会（BW間休憩）と状態継承（小Wave間）を提供する。

---

## 2. ファイルサイズチェック結果（予防的品質管理）

### 2.1 現状
| ファイル | 現行行数 | 状態 |
|---------|---------|------|
| Main.gd | 941行 | 警告域（近い将来分割推奨） |
| BoardManager.gd | 562行 | 適正 |
| EnemyAI.gd | 289行 | 適正 |
| GameSession.gd | 158行 | 適正 |

### 2.2 追加予定行数と判定

| ファイル | 追加行数 | 予測行数 | 判定 |
|---------|---------|---------|------|
| scripts/WaveManager.gd（新規） | +350 | 350 | 新規・500行未満 |
| scripts/WaveConfig.gd（新規・係数テーブル） | +70 | 70 | 新規・定数のみ |
| GameSession.gd | +30 | 188 | 適正 |
| Main.gd | +60 | 1001 | **800行超→分割必須** |
| EnemyAI.gd | +20 | 309 | 適正 |

### 2.3 分割対応
- **Main.gd 1001行予測 → 分割必須**
  - Wave遷移制御のロジックはWaveManager.gd側に集約（Main.gdからは`wave_manager.start_next_wave()`等のメソッド呼び出しのみ）
  - `_check_game_over()`内の「勝利時にRestScreen呼び出し or 次Wave開始」分岐はWaveManager.gdの判定メソッドに委譲
  - Main.gdへの追加は**30行以内**に抑える（949 → 979行、1000行未満死守）

- **WaveConfig.gdを別ファイル化**
  - 係数テーブル（0.6～3.0の9段階）を定数として分離
  - WaveManager.gdの肥大化を防ぐ

**報告：** 現在Main.gd=941行。WaveManager機能追加後の素朴な実装だと1001行予測のため、WaveManager.gdとWaveConfig.gdへのロジック分離を要件に含めました。Main.gdへの追加は呼び出し数行のみに制限します。

---

## 3. データ構造

### 3.1 WaveConfig.gd（新規・定数モジュール）
```gdscript
# scripts/WaveConfig.gd
extends RefCounted

# Wave強化係数テーブル（pve_wave_pending_issues.md 論点1 確定仕様）
# HP・ATKに乗算（SPDは固定）
const WAVE_SCALE: Array = [
    0.6,  # 小Wave1
    0.8,  # 小Wave2
    1.0,  # 小Wave3
    1.3,  # 小Wave4
    1.6,  # 小Wave5
    2.0,  # 小Wave6
    3.0,  # ボスWave第一形態（Wave7）
    3.5,  # ボスWave第二形態（Wave8）
]

const SMALL_WAVE_COUNT: int = 6          # 小Waveの数
const BOSS_WAVE_PHASE1: int = 7          # ボスWave第一形態（1-indexed）
const BOSS_WAVE_PHASE2: int = 8          # ボスWave第二形態（1-indexed）
const TOTAL_WAVES_PER_BW: int = 8        # 1BWあたりのWave総数（小6 + ボス2）
const BIG_WAVES_PER_ACT: int = 1         # 1Act = 1BW
```

### 3.2 GameSession.gd 拡張フィールド
既存の4フィールド（L74-77）に加えて以下を追加：
```gdscript
# Wave進行管理（Phase 4 #0a 拡張）
var wave_current_big: int = 0          # 現在の大Wave（1-3, 0=未開始）※既存
var wave_current_small: int = 0        # 現在の小Wave（1-9, 0=未開始）※既存
var wave_mana_carryover: float = 0.0   # 小Wave間のマナ持ち越し※既存
var wave_board_snapshot: Dictionary = {}  # 小Wave間の盤面スナップショット※既存

# 新規追加
var wave_unit_states: Array = []       # 各ユニットの状態 [{row, col, unit_name, initial_slot, current_hp, ...}, ...]
var wave_dead_units: Array = []        # BW中に死亡したユニット記録 [{unit_name, rarity, death_wave, initial_slot}, ...]
var wave_rest_pending: bool = false    # 次の遷移先がRestScreenかどうか
```

### 3.3 WaveManager.gd 内部状態
```gdscript
# scripts/WaveManager.gd
extends Node

# 参照ノード
var board_manager: Node = null
var deck_manager: Node = null
var enemy_ai: Node = null
var main_ref: Node = null              # Main.gdの参照（Wave遷移トリガー用）

# Wave状態
enum WaveState {
    IDLE,           # 未開始
    COMBAT,         # 戦闘中
    BETWEEN_SMALL,  # 小Wave間（短い遷移）
    REST,           # BW間休憩（RestScreen表示中）
    BW_COMPLETE,    # BW完了（Act遷移）
}
var state: WaveState = WaveState.IDLE

# Signal
signal wave_started(big: int, small: int, scale: float)
signal wave_ended(big: int, small: int, victory: bool)
signal rest_screen_requested()         # BW間休憩をMain.gdが受け取る
signal big_wave_completed(big: int)    # Act遷移用
```

---

## 4. API設計

### 4.1 WaveManager.gd 公開メソッド

```gdscript
# === 初期化 ===
func setup(bm: Node, dm: Node, eai: Node, main: Node) -> void
    # 参照を受け取りシグナル接続

# === Wave開始 ===
func start_big_wave(big_index: int) -> void
    # 指定BWを開始（wave_current_big=big_index, small=1）
    # GameSession.wave_mana_carryoverを0.0にリセット
    # 最初の小Waveを開始

func start_next_small_wave() -> void
    # 現在の小Waveの次を開始（1→2→...→7→8[ボス第一]→9[ボス第二]）
    # 敵強化係数を適用して敵を配置
    # 味方ユニットの状態を復元
    # マナは持ち越し値を設定

# === Wave終了処理 ===
func on_wave_victory() -> void
    # Main._check_game_over()の勝利時に呼ばれる
    # 現在のWaveがボス第二形態ならBW完了、そうでなければ次Waveへ
    # 小Wave1-7終了時: 状態保存 → 次の小Wave自動開始
    # ボス第一形態終了時: 状態保存 → 第二形態開始
    # ボス第二形態終了時: BW完了 → RestScreen呼び出し → 次Act or エンディング

func on_wave_defeat() -> void
    # 敗北時はラン終了（既存Result画面遷移を踏襲）

# === 状態保存・復元 ===
func save_wave_state() -> void
    # 現在の盤面・ユニット状態・マナをGameSessionに保存
    # 味方のみ保存（敵は次Waveで再構築）
    # initial_slot（0-8）も保存

func restore_wave_state() -> void
    # GameSessionから味方盤面・ユニット状態を復元
    # on_summonは再発動しない（論点9 確定仕様）
    # 合体状態は維持（論点7 確定仕様）

# === 敵強化係数適用 ===
func apply_enemy_scale(wave_index: int) -> void
    # WaveConfig.WAVE_SCALE[wave_index]を取得
    # EnemyAI側の敵ユニット生成時に HP*scale, ATK*scale を適用
    # SPDは固定（論点1 確定仕様）

func get_current_scale() -> float
    # 現在のWave係数を返す（UI表示用）

# === 問い合わせ ===
func is_boss_wave() -> bool
    # 現在のWaveがボス（第一または第二形態）かどうか

func is_big_wave_complete() -> bool
    # 現BWが完了したか（ボス第二形態勝利直後はtrue）

func get_remaining_waves() -> int
    # 現BWの残りWave数
```

### 4.2 GameSession.gd 追加メソッド
```gdscript
func reset_wave_state() -> void
    # wave_current_big/small/mana_carryover/board_snapshot/unit_states/dead_units をリセット
    # ラン開始時・Act遷移時に呼ぶ

func record_dead_unit(unit_name: String, rarity: String, wave: int, slot: int) -> void
    # BW中死亡ユニットをwave_dead_unitsに記録（RestScreen復帰用）
    # slotは初期配置時のスロットインデックス（0-8）
```

### 4.3 EnemyAI.gd 拡張メソッド
```gdscript
func apply_wave_scale(hp_scale: float, atk_scale: float) -> void
    # 既存_build_enemy_deck()直後に呼ぶ
    # enemy_deck内の全UnitDataに対し max_hp/current_hp/attack にスケール適用
    # SPDは変更しない
```

---

## 5. 他システムとの連携

### 5.1 CombatSystem連携
- **変更なし**：CombatSystemは単一Wave内の戦闘処理に専念する
- WaveManagerはCombatSystemを直接操作しない（board_managerを介す）

### 5.2 Main.gd連携（最小変更）
変更箇所：`_check_game_over()`（L573-600）

```gdscript
# 修正前（既存）
elif base_hp[1] <= 0 or enemy_all_dead:
    # ボス連戦判定
    if GameSession.battle_type == "boss" and ... : _start_boss_phase2(); return
    game_over = true
    # ... 勝利処理
    _transition_to_result_timer()

# 修正後（WaveManager呼び出しに変更）
elif base_hp[1] <= 0 or enemy_all_dead:
    if wave_manager != null and wave_manager.state == WaveState.COMBAT:
        wave_manager.on_wave_victory()  # WaveManagerが遷移先を判定
        return
    # 既存ロジック（ツールモード・dev_mode用）はフォールバック
    game_over = true
    # ...
```

追加箇所（30行以内）：
- `var wave_manager: Node = null` フィールド追加
- `_ready()`でWaveManager初期化
- `wave_manager.rest_screen_requested`シグナル接続
- `_on_rest_screen_requested()`ハンドラ（RestScreen呼び出し）
- `wave_manager.big_wave_completed`シグナル接続
- `_on_big_wave_completed(next_act)`ハンドラ（次Act直行）

### 5.3 RestScreen連携
- WaveManagerから`rest_screen_requested`シグナル発火
- Main.gdがシグナルを受け取り、RestScreenManagerを起動（rest_screen_requirements.md準拠）
- RestScreen終了時のコールバックでWaveManager.start_big_wave(next_act)を呼ぶ（**MapSelect経由なし**）

### 5.4 DeckManager連携
- 小Wave開始時：`deck_manager.mana = GameSession.wave_mana_carryover`（持ち越し）
- 小Wave終了時：`GameSession.wave_mana_carryover = deck_manager.mana`（保存）
- BW間休憩時：`deck_manager.mana = 0.0`（論点6 確定仕様）

### 5.5 EnemyAI連携
- Wave開始時：`enemy_ai._build_enemy_deck()` → `wave_manager.apply_enemy_scale(n)` → `enemy_ai.apply_wave_scale(scale, scale)` → 敵配置
- 敵は各Waveで新規構築（敵状態は持ち越さない）

---

## 6. ロジックフロー

### 6.1 Wave開始フロー
```
[Wave開始呼び出し]
  ↓
WaveConfig.WAVE_SCALE[wave_index] を取得（例：小Wave3なら1.0）
  ↓
敵デッキ構築（EnemyAI._build_enemy_deck）
  ↓
スケール適用（EnemyAI.apply_wave_scale(scale, scale)）
  ↓
敵初期配置（Main._place_enemy_initial_units）
  ↓
味方状態復元（小Wave2以降のみ、WaveManager.restore_wave_state）
  ↓ 注意: on_summonは再発動しない（初回配置時のみ発動済み）
マナ設定（deck_manager.mana = GameSession.wave_mana_carryover）
  ↓
EnemyAI.initialize_mana_from_deck()
  ↓
state = COMBAT、wave_startedシグナル発火
```

### 6.2 Wave終了フロー
```
[Main._check_game_over() 勝利判定]
  ↓
wave_manager.on_wave_victory()
  ↓
小Wave1-6勝利？
  ├─ YES → save_wave_state() → state=BETWEEN_SMALL → 2秒後にstart_next_small_wave()
  │
ボスWave第一形態勝利？
  ├─ YES → save_wave_state() → state=BETWEEN_SMALL → 2秒後にstart_next_small_wave()（第二形態へ）
  │
ボスWave第二形態勝利？
  └─ YES → state=REST → rest_screen_requested発火 → Main経由でRestScreen起動
              ↓ RestScreen終了
            state=BW_COMPLETE → big_wave_completed発火 → 次Act直行（MapSelect経由なし）
```

### 6.3 状態保存内容（wave_unit_states）
各ユニットについて保存：
```gdscript
{
    "row": int, "col": int,
    "initial_slot": int,          # 初期配置スロットインデックス（0-8）※死亡記録の識別キー
    "unit_name": String,
    "current_hp": int,
    "max_hp": int,                # 合体でmax_hpが変わるため保存必須
    "attack": int,                # _kill_atk_bonus等で変動するため保存
    "_atk_bonus": int,
    "_interval_bonus": float,
    "_kill_atk_bonus": int,
    "_stolen_atk": int,
    "_stolen_spd": float,
    "_stolen_armor": int,
    "_has_penetrate": bool,
    "_has_big_penetrate": bool,
    "_has_impact": bool,
    "_damage_reduction": int,
    "regen_stacks": int,
    "power_stacks": int,
    "boots_stacks": int,
    "spring_stacks": int,
    "sense_stacks": int,
    "skills": Array,              # 合体後のスキル配列
    "is_synthesized": bool,       # 合体済みフラグ
}
```

**リセット対象（保存しない）：**
- デバフ（poison_stacks, frozen_turns, burn_turns） → 小Wave開始時に0へ
- 攻撃タイマー → 小Wave開始時にget_attack_interval()でリセット
- _temp_atk_bonus / _temp_spd_bonus（時限バフ）→ 0にリセット

---

## 7. 実装詳細

### 7.1 敵強化係数適用の実装
```gdscript
# WaveManager.gd
func apply_enemy_scale(wave_index: int) -> void:
    var scale: float = WaveConfig.WAVE_SCALE[wave_index - 1]  # 1-indexed→0-indexed
    enemy_ai.apply_wave_scale(scale, scale)
    print("[WaveManager] Wave %d スケール適用: ×%.2f" % [wave_index, scale])

# EnemyAI.gd
func apply_wave_scale(hp_scale: float, atk_scale: float) -> void:
    for u in enemy_deck:
        u.max_hp = int(float(u.max_hp) * hp_scale)
        u.current_hp = u.max_hp
        u.attack = int(float(u.attack) * atk_scale)
        # SPDは変更しない（論点1 確定仕様）
```

### 7.2 on_summon再発動防止
`restore_wave_state()`内では`board_manager.place_unit()`ではなく、盤面配列に直接UnitDataを代入する低レベル操作を使う。これにより`SupportSystem.push_summon_effects()`が呼ばれず、on_summonトリガーが再発動しない。

```gdscript
func restore_wave_state() -> void:
    for state in GameSession.wave_unit_states:
        var unit = _reconstruct_unit(state)  # UnitData再生成・フィールド復元
        board_manager.board[0][state.row][state.col] = unit
        board_manager.attack_timers[0][state.row][state.col] = unit.get_attack_interval()
        # tile_system.check_tile_on_enter() は呼ぶ（マス効果は再適用）
        board_manager.tile_system.check_tile_on_enter(0, state.row, state.col, unit)
    board_manager.on_board_changed()
```

### 7.3 合体状態の持ち越し
`is_synthesized`フラグと`unit_name`（合成後の名前）で判定。復元時は合成済みユニットのスキル配列をそのまま使う。BW間休憩では分解不可（論点7 確定仕様）。

### 7.4 死亡ユニット記録（initial_slot識別）
```gdscript
# BoardManager.gd または CombatSystem.gd内、ユニット死亡時
func _on_unit_death(side: int, row: int, col: int) -> void:
    if side == 0:  # 味方のみ記録
        var unit = board[side][row][col]
        var slot_index = row * 3 + col  # 0-8のスロットインデックス
        GameSession.record_dead_unit(unit.unit_name, unit.rarity, GameSession.wave_current_small, slot_index)
```

---

## 8. 制約・注意事項

### 8.1 既存コードとの整合性
- **Main._check_game_over()の既存ロジックは壊さない**：ツールモード・dev_modeでは従来通りResult画面遷移。WaveManager経由は通常モードのみ。
- **ボス連戦（boss_phase=2）は廃止**：既存の`_start_boss_phase2()`（L610）は削除。ボス第二形態はWave9として扱う。
- **既存のenemy_hp_scale/enemy_atk_scale（battle_config）は残すが未使用**：Debug用の個別調整値として残置。WaveManager経由時はbattle_configのスケールを1.0に上書きする。

### 8.2 GAME_DESIGN.mdとの整合性
- 1Act = 1BW = 6小Wave+ボス2連戦（計8Wave）
- 係数テーブル 0.6→0.8→1.0→1.3→1.6→2.0→3.0→3.5（pve_wave_pending_issues.md 論点1拡張）
- マナ：小Wave間持ち越し、BW間リセット、開始時0（論点6）
- ユニット状態：合体維持、死亡記録（論点7）
- on_summon再発動禁止（論点9）
- 敵に呪文デッキなし（論点10）

### 8.3 廃止済み設計との整合性
- 時間経過マナ回復は復活させない（ユニット攻撃でのみ生成）
- 本体HPシステムは継続。base_hp[0]=0で敗北は変わらず。
- Wave内の完全オートバトルは維持（プレイヤー介入は呪文キャストのみ）

### 8.4 3秒ルール
Wave開始時のUI表示で以下が3秒で伝わること：
- 現在のWave番号（例：「小Wave3 / ボス前」「ボス第一形態」「ボス第二形態」）
- 敵強化係数（例：「敵HP/ATK×1.0」）
- 残りWave数（例：「残り6Wave」）

これらのUI要件は別タスク（RestScreen/GameUI拡張）で対応。WaveManager側は`wave_started`シグナルで情報提供のみ。

### 8.5 実装順序
1. WaveConfig.gd作成（定数のみ・70行）
2. GameSession.gd拡張（追加フィールド・reset_wave_state/record_dead_unit）
3. EnemyAI.apply_wave_scale()追加
4. WaveManager.gd作成（setup/start_big_wave/start_next_small_wave/apply_enemy_scale/save_wave_state/restore_wave_state/on_wave_victory/on_wave_defeat）
5. Main.gd最小変更（WaveManager初期化・_check_game_over修正・_start_boss_phase2削除）
6. シグナル接続確認
7. 既存テスト（TestBattleConfig/TestSession）への影響確認

### 8.6 構文チェック必須
各ファイル編集後に`bash tools/ci/tools/ci/check_syntax.sh`を実行。

---

## 9. 完了定義

- [x] WaveManager.gd / WaveConfig.gd / GameSession.gd拡張 / EnemyAI.gd拡張 / Main.gd最小変更の要件がすべて明示済み
- [x] ファイルサイズ予測が全ファイル800行未満（Main.gd <1000行）
- [x] pve_wave_pending_issues.md 11項目との対応が明示済み
- [x] rest_screen_requirements.mdとの連携シグナル仕様が明示済み
- [x] on_summon再発動防止の実装方針が明示済み
- [x] 設計判断3項目（ボス連戦/Act間遷移/死亡ユニット識別）確定済み

---

## 10. 参照ファイル（絶対パス）

- C:\Users\kazum\dungeon-board-game\docs\design\pve_wave_pending_issues.md
- C:\Users\kazum\dungeon-board-game\docs\design\pve_wave_compatibility_check.md
- C:\Users\kazum\dungeon-board-game\docs\design\rest_screen_requirements.md
- C:\Users\kazum\dungeon-board-game\docs\GAME_DESIGN.md
- C:\Users\kazum\dungeon-board-game\scripts\CombatSystem.gd
- C:\Users\kazum\dungeon-board-game\scripts\GameSession.gd
- C:\Users\kazum\dungeon-board-game\scripts\Main.gd
- C:\Users\kazum\dungeon-board-game\scripts\EnemyAI.gd
- C:\Users\kazum\dungeon-board-game\scripts\BoardManager.gd
- C:\Users\kazum\dungeon-board-game\scripts\DeckManager.gd
