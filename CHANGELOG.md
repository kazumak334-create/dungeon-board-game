# CHANGELOG

## 2026-05-03

### feat: Sprint 3 人口システム・Sprint 4 満足度システム実装（EconEconomy.gd）

#### Sprint 3: リアルタイム人口増減（req_econ_population_sprint3.md）
- `EconEconomy.gd`: `_growth_blocked_by_food: bool` フィールド追加（72行）
- `EconEconomy.gd`: `_calculate_population_growth_rate()` 追加（441行）
- `EconEconomy.gd`: `_calculate_population_decline_rate()` 追加（455行）
- `EconEconomy.gd`: `_try_confirm_population_growth()` 追加（467行）
- `EconEconomy.gd`: `_get_population_change_breakdown()` 追加（484行）
- `EconEconomy.gd`: `update_population(delta)` 追加（496行）
- `EconEconomy.gd`: `update()` を毎フレーム/5秒tick分離構造に変更（74行）

#### Sprint 4: リアルタイム満足値更新（req_econ_satisfaction_sprint4.md）
- `EconEconomy.gd`: `_get_population_scale_influence()` 追加（519行）
- `EconEconomy.gd`: `_get_population_growth_influence()` 追加（528行）
- `EconEconomy.gd`: `_get_building_satisfaction_influence()` 追加（537行）
- `EconEconomy.gd`: `_get_food_shortage_penalty()` 追加（550行）
- `EconEconomy.gd`: `_calculate_satisfaction_slope()` 追加（554行）
- `EconEconomy.gd`: `_get_satisfaction_slope_breakdown()` 追加（562行）
- `EconEconomy.gd`: `update_satisfaction(delta)` 追加（573行）
- `EconEconomy.gd`: `get_happiness_state()` を5段階ベース後方互換ラッパーに置換（189行）

## 2026-04-25

### feat: バトル遷移・WAVE表示・キャストゲージ・素材ドロップ基盤実装 (req_battle_transition.md)

#### REQ-A1: cell_rects 正規座標リセット関数
- `Main.gd`: `_reset_cell_rects_to_canonical()` 追加（SW遷移バグ修正）

#### REQ-A2: 勝利フロー演出
- `Main.gd`: `_on_battle_victory()` を書き換え（敵フェードアウト0.5s → VICTORY!1.5s）
- `Main.gd`: `_animate_enemy_fadeout()` 追加
- `Main.gd`: `_animate_enemy_slideout()`, `_animate_player_advance()` 削除

#### REQ-A3: SW内遷移演出
- `Main.gd`: `_on_wave_started()` 書き換え（SW1/SW2分岐）
- `Main.gd`: `_animate_battle_start()`, `_animate_sw_transition()` 追加
- `Main.gd`: `_animate_wave_start()` 削除
- `Main.gd`: `_animate_enemy_slidein()` 座標バグ修正（GameUI._cell_x相当に修正）

#### REQ-A5: Actクリア遷移
- `Main.gd`: `_on_big_wave_completed()` のTODOコメントをPhase5表記に更新

#### REQ-B1: WAVE X-X 表示関数
- `Main.gd`: `wave_label` 変数追加、`_show_wave_label()` 追加
- `GameUI.gd`: `wave_label` ノード生成追加

#### REQ-C1: SpellSlotSystem キャストゲージ
- `SpellSlotSystem.gd`: `cast_timer`, `cast_interval` 変数追加
- `SpellSlotSystem.gd`: `process_slots()` 復活（タイマー減算実装）
- `SpellSlotSystem.gd`: `can_cast()`, `get_cast_block_reason()` にCDチェック追加
- `SpellSlotSystem.gd`: `_trigger_spell()` にタイマーリセット追加
- `Main.gd`: `_process()` 内で `spell_slot_system.process_slots(delta)` 呼び出し追加

#### REQ-C2: キャストゲージUI
- `GameUIQueue.gd`: `_build_one_spell_slot()` にゲージColorRect追加
- `GameUIQueue.gd`: `update_spell_slots()` にratio反映追加

#### REQ-D1: GameSession.materials
- `GameSession.gd`: `materials: Dictionary = {}` 追加

#### REQ-D2: material_dropped シグナル
- `BoardManager.gd`: `material_dropped` シグナル定義追加

#### REQ-D3: 素材ドロップ基盤
- `EventQueue.gd`: 敵死亡時に `_drop_materials_from_unit()` 呼び出し追加
- `EventQueue.gd`: `_drop_materials_from_unit()`, `_resolve_material_id()` 追加（スタブ実装）
