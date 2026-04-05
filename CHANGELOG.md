# CHANGELOG

## [Unreleased]

### Added — 2026-04-05: 効果テーブルシステム（EffectDB + EffectExecutor）

#### EffectDB.gd（新規）
- class_name EffectDB, extends RefCounted
- EFFECTS: Dictionary に65種の効果定義を一元管理
- buff_apply/debuff_apply/damage/self_damage/heal/atk_permanent/summon/deck_add/draw/mana_add/steal_buffs/move/skill_flag/mana_drain/debuff_spread/inject_status/cost_reduce/temp_buff_all/stat_boost/deck_remove_status/front_status/front_damage_status/all_enemy_damage/all_enemy_debuff/move_enemy_random/swap_front_back/push_to_back/delay_spawn/randomize_col/revive/revive_ally/crystallize/critical 各type定義

#### EffectExecutor.gd（新規）
- class_name EffectExecutor, extends RefCounted
- execute(effect_id, params, context)でEffectDBのデフォルト値をparams上書きして実行
- contextに board_manager/deck_manager/enemy_ai/event_queue/source/target/side/row/col を渡す設計
- _resolve_target()で"self"/"random_front_ally"/"same_col_ally"/"same_row_beast"/"adjacent_beast"/"all_allies"/"all_enemies"/"single_ally"/"random_ally"/"enemy_random_col"/"ally_max_atk"/"enemy_front_one"を解決

#### UnitData.gd
- skills: Array = [] フィールド追加
- clone()でskillsもdeep copy

#### DeckManager.gd / EnemyAI.gd
- card_pool全ユニットに skills配列を追加（support/activeは空文字に変更）
- spell_poolに主要3呪文のskills追加

#### BoardManager.gd
- effect_executor: RefCounted フィールド追加
- _apply_support_effects()内でskills[always]をEffectExecutor経由で処理
- _push_on_hit_effects()でskills[on_hit]をEffectExecutor経由で処理（旧方式は後方互換で維持）
- _push_summon_effects()でskills[on_summon]をEffectExecutor経由で処理
- _init_skill_timers()でskills[timer]を"timer_N"キーで登録
- _process_timed_skills()で"timer_N"形式キーをEffectExecutor経由で発火
- _process_on_kill()でskills[on_kill]をEffectExecutor経由で処理
- remove_unit()でskills[on_death]をEffectExecutor経由で処理

#### SpellExecutor.gd
- effect_executor: RefCounted フィールド追加
- execute()先頭でspell.skillsがある場合はEffectExecutor経由で処理（既存matchは後方互換）
- _inject_status_card()で異常状態カードにskills配列を設定
- _apply_self_status()でスライム優先判定をunit_name判定に更新

#### EventQueue.gd
- デバフ波及チェックをskills配列にも対応（support_effect文字列との両対応）

#### Main.gd
- EffectExecutorScript preload追加
- EffectExecutor生成・board_manager/spell_executorに注入
- synthesis_registryのresult定義にskillsを含める

#### DevUI.gd
- unit_defsにskills配列追加（主要ユニット全件）
- _build_card()でskillsをUnitData.skillsに設定

### Fixed — 2026-04-05
- CheckAgent：DeckManager.gd 57行目（バンシー active）・EnemyAI.gd 58行目（リッチ support）・59行目（リッチ active）・64行目（ヴリコラカス active）の日本語文字化け（U+FFFD）を修正
- CheckAgent：BoardManager.gd 217行目コメントの文字化け（ターゲッ□□選択）を修正（実行影響なし）
- CheckAgent：EffectExecutor.gdに"race_buff" typeのmatch分岐を追加（EffectDB.EFFECTSに定義済みの"slime_global_buff"エントリへの対応）

### Added — 開発者モード・リジェネバフ・呪文カードシステム・バフ統一化・撃破時スキル

#### 開発者モード（DevUI.gd 新規作成）
- 起動時にモード選択画面（PLAY / 開発者モード）を表示
- 開発者モードでは自動デッキ無効・戦闘は動作
- カードリスト（ユニット9種＋呪文8種）から選択→ボードセルクリックで配置/発動
- 自陣/敵陣切替・マナ+10・全味方回復・敵全滅のツールボタン

#### 呪文カードシステム（SpellExecutor.gd 新規作成）
- UnitDataに card_type/spell_id/spell_target/spell_effect/is_consumable フィールド追加
- DeckManager/EnemyAIに呪文分岐（unit/spell/status_spell）追加
- 初期デッキに呪文3枚追加（召喚加速・生命の雫・盤面強化）
- SpellExecutorに31種の呪文ロジック実装済み
- 異常状態カード（コスト0・発動後消滅）の基盤実装

#### リジェネバフ
- `_regen_stacks` フィールド追加（重複可・2秒ごとHP5%×スタック回復）

#### バフ統一化（吸血・貫通→常時バフ）
- `_has_lifesteal`/`_has_penetrate` フラグで管理
- 命中時スキルから _do_attack 内バフ処理に移行
- バフ版貫通は攻撃時効果を発動しない

#### 撃破時スキル
- ATK累積（グール）: 撃破時ATK+2（上限+10）
- 敵SPD低下（バンシー）: 撃破時に全敵に凍結+4

### CheckAgent: 修正あり（2026-04-05）
- 対象: 撃破時スキル追加・リッチ/ヴリコラカス追加
- BoardManager.gd `_steal_buffs`: `stealer._atk_bonus += ...` を削除（二重加算バグ修正）
  - 原因: `_atk_bonus`はサポート再計算でフレームごとにリセットされるため、`stealer.attack`のみを変更すべきところ両方に加算していた
  - 修正: `stealer.attack += int(victim._atk_bonus * multiplier)` のみ残し、`stealer._atk_bonus +=` を削除
- BoardManager.gd `_process_on_kill`: `ally != killer` の除外条件あり OK
- BoardManager.gd `_fire_timed_skill`: 全バフ奪取・呪い付与・全体凍結・強力な毒・全体麻痺 elif チェーン OK
- BoardManager.gd `_push_on_hit_effects`: バフ奪取は`命中時`フィルタ後のためentryに`"全バフ奪取〈時間経過〉"`は到達しない OK
- DeckManager.gd: リッチ/ヴリコラカス card_pool キー・deck_list name 一致 OK
- EnemyAI.gd: リッチ/ヴリコラカス card_pool キー・deck_list name 一致 OK
- active_skill " / " パース: 全エントリ統一 OK

### CheckAgent: 確認完了・修正なし（2026-04-04）
- 対象: 開発者モード実装（モード選択画面・手動カード配置・呪文発動）
- Main.gd: `dev_mode` / `dev_ui` / `mode_select_panel` / `game_started` 変数追加 OK
- Main.gd: `_build_mode_select()` PLAYボタン・開発者モードボタンのオーバーレイ実装 OK
- Main.gd: `_on_mode_play()` オーバーレイ削除・`game_started=true` 設定 OK
- Main.gd: `_on_mode_dev()` オーバーレイ削除・`dev_mode=true`・DevUI.gd ロード・setup 呼び出し OK
- Main.gd: `_process` で `not game_started` ならreturn OK
- Main.gd: `_process` で `dev_mode` 時に `deck_manager.process_deck` / `enemy_ai.process_ai` をスキップ OK
- Main.gd: `_process` で `dev_mode` 時も `board_manager.process_combat` は動作 OK
- Main.gd: `_unhandled_input` で `dev_mode=false` の場合は早期return OK
- Main.gd: `_unhandled_input` で左クリック時にセル位置を検出し `dev_ui.on_cell_clicked()` を呼び出し OK
- DevUI.gd: `class_name DevUI extends RefCounted` OK
- DevUI.gd: `setup(main, board, deck, enemy)` 初期化 OK
- DevUI.gd: UIノードは `main.add_child()` で追加（RefCounted のため自身はノードでない） OK
- DevUI.gd: 画面右側（x=1020〜）に開発者パネル・選択中カード表示・自陣/敵陣切替・ツールボタン・カードリスト（スクロール）OK
- DevUI.gd: `_on_card_selected(index)` UnitData インスタンス生成・`selected_card` 設定 OK
- DevUI.gd: `on_cell_clicked` ユニット配置時に `selected_side` を使用（クリック側ではない） OK
- DevUI.gd: `on_cell_clicked` ユニット配置時に `board` 直接操作・`_init_skill_timers` 呼び出し・`unit_placed emit`・`on_board_changed` 呼び出し OK
- DevUI.gd: `on_cell_clicked` 呪文発動時に `spell_executor.execute` を使用 OK
- DevUI.gd: `_toggle_side()` `selected_side` を 0/1 切替 OK
- DevUI.gd: ツールボタン4種（マナ+10・全味方回復・敵全滅・選択解除）実装 OK

### CheckAgent: 確認完了・修正なし（2026-04-04）
- 対象: 呪文カードシステム基盤（Phase 1）+ 基本呪文3枚（Phase 2）
- UnitData.gd: card_type / spell_id / spell_target / spell_effect / is_consumable フィールド追加 OK
- UnitData.gd: clone() で5フィールドをコピー OK
- SpellExecutor.gd（新規）: class_name SpellExecutor extends RefCounted OK
- SpellExecutor.gd: execute() が `not spell.is_consumable` を返す（true=捨て札/false=消滅）OK
- SpellExecutor.gd: 基本呪文3枚（召喚加速・生命の雫・盤面強化）実装 OK
- SpellExecutor.gd: board_manager.spell_cast.emit(side, spell.spell_id) 呼び出し OK
- SpellExecutor.gd: EventQueue.PRIORITY_ACTIVE 等の定数参照 OK
- DeckManager.gd: spell_executor / enemy_ai_ref / _cost_reduction_remaining フィールド追加 OK
- DeckManager.gd: spell_pool 定義・spell_list 3枚追加（ユニット9枚+呪文3枚=12枚）OK
- DeckManager.gd: process_deck で card_type 分岐（unit/spell/status_spell）OK
- DeckManager.gd: status_spell は捨て札に行かない OK
- DeckManager.gd: force_play_card で card_type 分岐 OK
- DeckManager.gd: _cost_reduction_remaining による 1 コスト軽減処理 OK
- EnemyAI.gd: spell_executor / deck_manager_ref フィールド追加 OK
- EnemyAI.gd: process_ai で mana チェック後に card_type 分岐 OK
- EnemyAI.gd: force_play_card で card_type 分岐 OK
- Main.gd: SpellExecutorScript preload OK
- Main.gd: SpellExecutor インスタンス化・DeckManager/EnemyAI へ注入 OK
- Main.gd: spell_cast シグナル接続 + _on_spell_cast ハンドラ（ログ出力）OK

### CheckAgent: 確認完了・修正なし（2026-04-04）
- 対象: 企画Agentバランス調整提言（セクション3・4）
- BoardManager.gd: 凍結ペナルティ 0.8→0.5、前列・後列の2箇所ともに適用済み OK
- BoardManager.gd: 鎧スケーリング型（1スタック=10%軽減）に変更済み OK
- BoardManager.gd: 貫通バフの後ろダメージも同じスケーリング計算を適用済み OK
- BoardManager.gd: ATKバフ重複上限 `min(_atk_bonus, 10)` がサポート効果+アクティブスキル適用後に実装済み OK
- EventQueue.gd: 麻痺がスタック加算式（`min(3, paralysis_turns + stacks)`）で上限3秒に変更済み OK
- SpellExecutor.gd: 「全体再生」ケース追加・全味方に `_regen_stacks += 1` 適用済み OK
- DevUI.gd: spell_defs に「全体再生」エントリ（cost:4, target:all_allies）追加済み OK
- docs/card_database.md: 鎧説明「1スタック=10%軽減」、凍結「最大50%」、麻痺「最大3秒」、全体再生エントリ 全て更新済み OK
- Main.gd: 次カードパネルで呪文時に【呪文】プレフィックス・紫色・spell_effect 表示 OK
- Main.gd: 呪文カード時に HP/ATK/配置列を表示しない OK
- BoardManager.gd: spell_cast シグナル定義 OK

### CheckAgent: 確認完了・修正なし（2026-04-04）
- 対象: 吸血・貫通・鎧をバフとして統一管理（常時バフ化）
- UnitData.gd: `_has_lifesteal` / `_has_penetrate` フィールド追加・clone() に引き継がない OK
- BoardManager.gd `_do_attack`: 吸血バフでhealイベント、貫通バフで後ろユニットへのダメージイベントを積む OK
- BoardManager.gd `_do_attack`: 貫通バフのダメージに `_push_on_hit_effects` を呼ばない OK
- BoardManager.gd `_do_attack`: 貫通バフのダメージに `_damage_reduction` 軽減を適用 OK
- BoardManager.gd `_push_on_hit_effects`: 吸血・貫通の処理が削除済み OK
- BoardManager.gd `_apply_support_effects`: `_has_lifesteal` / `_has_penetrate` をfalseにリセット OK
- BoardManager.gd `_process_unit_support`: 「吸血付与」「貫通付与」でバフ付与 OK
- BoardManager.gd `_apply_support_effects`: アクティブスキル由来のバフ適用がサポート効果適用ループの後に配置 OK

### CheckAgent: 修正あり（2026-04-04）
- 対象: 撃破時アクティブスキル2種（ATK累積・敵SPD低下）実装検証
- EventQueue.gd "damage" 死亡時: `{"pos": ex, "killer": event["source"]}` 形式 OK
- EventQueue.gd "poison_damage" 死亡時: `{"pos": ex, "killer": null}` 形式 OK
- EventQueue.gd 死亡後処理ループ: `death["pos"]` から enemy_side/row/col 取得 OK
- EventQueue.gd: killer 非null・生存中チェック後に `_process_on_kill(killer)` 呼び出し OK
- UnitData.gd: `_kill_atk_bonus: int = 0` 追加・clone() に含まれていない OK
- BoardManager.gd `_process_on_kill`: 3重ループで盤面位置探索・未発見時は早期リターン OK
- BoardManager.gd `_process_on_kill`: " / " split で撃破時エントリのみ処理 OK
- BoardManager.gd `_process_on_kill` SPD低下: 全敵ユニットに凍結+4スタック付与・active_skill_used emit OK
- ❌ 修正: ATK累積の上限処理に問題あり。`_kill_atk_bonus += 2` してから `min(, 10)` でクランプ後に `attack += 2` していたため、`_kill_atk_bonus = 9` 時に実ATKが仕様より1多く増加するバグを修正。`prev_bonus` を保存し `attack += (_kill_atk_bonus - prev_bonus)` で実際に増加したボーナス分だけ attack に加算するよう変更。

### CheckAgent: 修正あり（2026-04-04）
- 対象: 盤面合成システム実装検証
- UnitData.gd: `synthesis_base` / `synthesis_card` フィールド追加 OK
- UnitData.gd: clone() で両フィールドをコピー OK
- BoardManager.gd: `synthesis_registry: Array` フィールド追加 OK
- BoardManager.gd: `synthesis_done` シグナル定義 OK
- BoardManager.gd: `_check_synthesis()` synthesis_registry を検索して合成結果を返す OK
- BoardManager.gd: `_execute_synthesis()` バフ継続・デバフ10スタック解除・タイマー比率継続・unit_placed emit・on_board_changed・_init_skill_timers・_push_summon_effects・synthesis_done emit OK
- BoardManager.gd: ❌ `place_unit` の合成分岐が不正。シャッフルされた行順で空きマスより先に合成マスを見つけると、空きマスが残っているのに合成を実行してしまう問題。空きマス探索ループと合成探索ループを分離して修正（空きマス優先・列満杯時のみ合成）
- DeckManager.gd: `process_deck` で呪文/異常状態カード発動前に `_try_spell_synthesis` チェック OK
- DeckManager.gd: `_try_spell_synthesis` 合成成立時に spell_executor.execute を呼ばない OK
- EnemyAI.gd: `process_ai` で呪文合成チェック（`_try_spell_synthesis`）実装 OK
- EnemyAI.gd: `_try_spell_synthesis` DeckManager と同じロジックで実装 OK
- Main.gd: `_build_synthesis_registry` レシピ11件（スライム系チェーン3件＋呪文合成8件）登録 OK
- Main.gd: `synthesis_done` シグナル接続・`_on_synthesis_done` でログ出力とフラッシュ表示 OK

### Added — アクティブスキル全面実装（効果システム完成・3合目到達）

#### 命中時スキル拡張
- **クリティカル**（タイガー）: 初撃ATK×2、`_first_attack` フラグで配置ごとにリセット
- **貫通**: 前列ヒット後、後列ユニットにも50%ダメージ（`_get_behind_col` ヘルパー追加）
- **連鎖**: 隣接行の最前列敵に50%ダメージ波及（`_get_adjacent_rows` ヘルパー追加）
- **凍結付与**: 凍結+3スタック付与
- **麻痺付与**: 麻痺+1スタック付与
- 複合スキル対応: `elif` → `if` に変更し「連鎖＋毒付与」等で両方発動

#### 召喚時スキル
- **追加召喚**（アメーバ）: 隣接空きマスに同種1体配置（連鎖防止: clone の active_skill を空に）
- **2枚ドロー**（ゴブリン）: マナ不要で即座に2枚プレイ（`force_play_card` 追加）
- **最前列突撃**（タイガー）: 配置後に前列へ強制移動
- EventQueue に `extra_summon` / `draw_cards` / `force_move_front` ハンドラ追加
- BoardManager に `draw_cards_requested` シグナル追加

#### 時間経過スキル
- **SPD低下**（マッドスライム・10s）: 同行敵全体に凍結+2スタック
- **全体回復**（ブラッドスライム・20s）: 自HP20%消費→全味方HP+10
- **全体ATK低下**（バンシー・15s）: 敵全行に火傷+2スタック
- **ATKバフ**（ウルフ・10s）: 同行獣全員ATK+3（5秒間）
- **単体大ダメージ**（タイガー・20s）: 最大HP敵1体にATK×3
- `_skill_timers` 辞書で配置時に自動初期化、毎秒減算・発火・リセット（繰り返し発動）
- `_temp_atk_bonus` / `_temp_atk_timer` で一時バフの減衰管理

#### HP閾値スキル
- **後退**（HP30%以下）: 後列に自動退避
- **結晶化**（HP50%以下）: 完全無敵3秒（毒は貫通）
- **前列強制突撃**（HP50%以下）: 前列に強制移動
- **ATK/SPD2倍**（HP50%以下）: ATK2倍＋攻撃速度2倍（10秒間）
- `_hp_threshold_triggered` で1回限り発動保証
- `_invincible_timer` で無敵管理（EventQueue の damage ハンドラで判定）
- `_temp_spd_bonus` / `_temp_spd_timer` で一時SPDバフ管理
- UI表示に「無敵」「ATK↑N」「SPD↑」を追加
- BoardManager.gd `_fire_hp_threshold_skill` ATK/SPD2倍: `_temp_atk_bonus=unit.attack`・`_temp_atk_timer=10.0`・`_temp_spd_bonus=attack_interval*0.5`・`_temp_spd_timer=10.0` OK
- Main.gd: 「無敵」「ATK↑N」「SPD↑」のUI表示 OK

### CheckAgent: 確認完了・修正なし（2026-04-04）
- 対象: 時間経過アクティブスキル5種実装検証
- UnitData.gd: `_skill_timers: Dictionary = {}`・`_temp_atk_bonus: int = 0`・`_temp_atk_timer: float = 0.0` フィールド追加 OK
- UnitData.gd: `clone()` にこれら3フィールドの引き継ぎなし OK
- BoardManager.gd `_do_attack`: `effective_atk = attacker.attack + attacker._atk_bonus + attacker._temp_atk_bonus` OK
- BoardManager.gd `place_unit`: `_init_skill_timers(placed)` が `_push_summon_effects` の前に呼ばれている OK
- BoardManager.gd `_init_skill_timers`: "時間経過"を含むエントリのみタイマー初期化 OK
- BoardManager.gd `_parse_skill_interval`: `marker.length()` で日本語オフセット計算・"s"の位置まで数値抽出 OK
- BoardManager.gd `_on_status_tick`: `_apply_regen()` → `_process_timed_skills()` → 状態異常処理の順序 OK
- BoardManager.gd `_process_timed_skills`: `fired` 配列による Dictionary 反復中の変更回避 OK
- BoardManager.gd `_fire_timed_skill` SPD低下: 同行敵全体に凍結+2スタック OK
- BoardManager.gd `_fire_timed_skill` 全体回復: `unit.current_hp > hp_cost` 条件・自己ダメージ `"enemy_side": side`（自side） OK
- BoardManager.gd `_fire_timed_skill` 全体ATK低下: 敵全行に火傷+2スタック OK
- BoardManager.gd `_fire_timed_skill` ATKバフ: 同行獣ユニットに `_temp_atk_bonus=3`・`_temp_atk_timer=5.0` OK
- BoardManager.gd `_fire_timed_skill` 単体大ダメージ: 最大current_hp敵1体にATK×3 OK
- 追加召喚ユニット（`active_skill=""`）はタイマー初期化されないこと OK

### CheckAgent: 修正あり（2026-04-04）
- 対象: 召喚時アクティブスキル3種実装（追加召喚・2枚ドロー・最前列突撃）検証
- BoardManager.gd `draw_cards_requested` シグナル宣言 OK
- BoardManager.gd `place_unit` 内の `_push_summon_effects` 呼び出し OK
- BoardManager.gd `_push_summon_effects`: "追加召喚" / "ドロー" / "最前列"+"突撃" 検出・イベント積み OK
- EventQueue.gd "extra_summon" ハンドラ: 隣接空きマスへclone直接配置・`active_skill = ""`で連鎖防止・`unit_placed` emit・`on_board_changed`・`active_skill_used` emit OK
- EventQueue.gd "draw_cards" ハンドラ: `draw_cards_requested` emit・`active_skill_used` emit OK
- EventQueue.gd "force_move_front" ハンドラ: 前列col(side 0=2, side 1=0)正確・既前列/前列埋まりスキップ・タイマー移動・`on_board_changed`・`active_skill_used` emit OK
- DeckManager.gd `force_play_card`: マナ不要・タイマー無視・デッキ空時リシャッフル OK
- EnemyAI.gd `force_play_card`: マナ不要・デッキ空時リシャッフル・`_pick_next_card` 呼び出し OK
- Main.gd `draw_cards_requested` 接続・`_on_draw_cards_requested` ハンドラ OK
- ❌ 修正: EventQueue.gd effect_type コメント（20-21行）に "extra_summon" / "draw_cards" / "force_move_front" が未追記 → 追記済み

### CheckAgent: 修正あり（2026-04-04）
- 対象: 命中時アクティブスキル5種追加（クリティカル・貫通・連鎖・凍結付与・麻痺付与）実装検証
- UnitData.gd: `_first_attack: bool = true` フィールド追加 OK
- UnitData.gd: clone() に `_first_attack` 代入なし（デフォルトtrue維持） OK
- BoardManager.gd `_do_attack`: 火傷ATK低下 → クリティカル2倍 の順序 OK
- BoardManager.gd `_do_attack`: クリティカル発動時に `active_skill_used` emit OK
- BoardManager.gd `_push_on_hit_effects`: 凍結付与 stacks: 3 OK
- BoardManager.gd `_push_on_hit_effects`: 麻痺付与 stacks: 1 OK
- BoardManager.gd `_get_behind_col`: side 0/1 それぞれ前列→後列方向に正しく探索 OK
- BoardManager.gd `_get_adjacent_rows`: 自身の行を含まない OK
- BoardManager.gd `_push_on_hit_effects`: 複合スキル対応のため `elif` チェーンを `if` チェーンに修正（「連鎖＋毒付与」等で2つ目以降のスキルがスキップされる問題を修正）

### CheckAgent: 確認完了・修正なし（2026-04-04）
- 対象: 火傷・凍結・毒のスタックによる効果スケーリング実装検証
- EventQueue.gd: 火傷 `+=` 加算スタック（デフォルト+2） OK
- EventQueue.gd: 凍結 `+=` 加算スタック（デフォルト+2） OK
- EventQueue.gd: 毒 `+=` 加算スタック（既存） OK
- BoardManager.gd _do_attack: 火傷逓減公式 `0.8 * stacks / (stacks + 2)` ATK低下 OK
- BoardManager.gd process_combat 前列: 凍結逓減公式 freeze_penalty 加算 OK
- BoardManager.gd process_combat 後列: 凍結逓減公式 freeze_penalty 加算 OK
- UnitData.gd: frozen_turns「攻撃速度低下（逓減・最大80%）」コメント OK
- UnitData.gd: burn_turns「ATK低下（逓減・最大80%）」コメント OK
- UnitData.gd: poison_stacks「毎秒スタック数分ダメージ（線形）」コメント OK

### CheckAgent: 確認完了・修正なし（2026-04-04）
- 対象: 状態異常名称変更・凍結効果変更の実装検証
- UnitData.gd: `burn_turns`/`paralysis_turns` フィールド名 ✅
- BoardManager.gd: 凍結を攻撃スキップから速度ペナルティに変更（前列・後列両方） ✅
- BoardManager.gd: 麻痺チェックに旧凍結スキップなし ✅
- EventQueue.gd: status_apply で「火傷」「麻痺」ブランチ ✅
- Main.gd: UI表示「火傷」「麻痺」「凍結」正常 ✅
- DeckManager.gd / EnemyAI.gd: スキル文字列「火傷付与」正常 ✅
- card_database.md: 「火傷付与」「麻痺付与」あり・旧名称なし ✅
- 旧名称（恐怖/石化/fear_turns/stun_turns）スクリプト全体に残存なし ✅

### Changed — マルチエージェント体制の再構築
- `~/.claude/CLAUDE.md` を新規作成（対話・出力ルール・トークン節約ルール）
- `.claude/agents/` に8Agent定義ファイルを作成（ceo・planning・marketing・implementer・checker・ui・pmo・pr）
- `CLAUDE.md` 冒頭のエージェント運用ルールをAgent一覧・連携パターン・フェーズ定義に全面刷新
- 全AgentをSonnet統一・checker.mdを新フォーマットに更新

### Added / Changed — チェーン処理システム実装

#### 実装1：状態異常・サポート・アクティブをEventQueue経由に変更
- **状態異常付与 (PRIORITY_STATUS)**: `status_apply` イベントタイプを追加。恐怖・毒・凍結・石化の付与をEventQueue経由に統一。`マッドスライム`/`バンシー`の 恐怖付与（命中時）が実際に動作するようになった
- **状態異常解除 (PRIORITY_STATUS)**: `_on_status_tick` 内の `status_cleared` 直接 emit を廃止。`status_clear` イベントをキューに積む方式に変更
- **サポート効果 (PRIORITY_SUPPORT)**: `on_board_changed()` が `_board_dirty` フラグではなく `support_apply` イベントをキューに push するよう変更。`_apply_support_effects()` はFlush内で優先度順に呼ばれる
- **アクティブスキル (PRIORITY_ACTIVE)**: 吸血ヒールの優先度を PRIORITY_IMMEDIATE→PRIORITY_ACTIVE に変更。命中時スキルを `_push_on_hit_effects()` に集約（吸血・恐怖付与・毒付与）
- `_apply_regen` のhealイベントに位置情報 (src_side/src_row/src_col) を追加

#### 実装2：盤面条件チェックをイベント駆動型に変更
- **毎フレームの `_try_promote` スキャンを廃止**: `process_combat` から繰り上げループを削除
- **イベント駆動型promote_check**: 前列ユニット死亡時・中列ユニット配置時に `PRIORITY_BOARD` の `promote_check` イベントをキューに積む
- **1フレームタイムラグ**: 遅延キュー (`_deferred_pending`) 経由で次フラッシュ時に `_try_promote` を実行
- **チェーン処理 (multi-pass flush)**: `EventQueue.flush()` を while ループ化（最大20パス）。死亡後処理をループ内で実行し、`remove_unit` が push したイベントを次パスで処理可能に

#### 実装3：デバッグUIの更新を軽量化
- `_cell_dirty[side][row][col]` フラグを追加。変化のあったセルのみ `_render_cell()` を呼ぶ
- `_update_cells()` は dirty フラグまたはフラッシュタイマーが有効なセルのみ更新
- フラッシュ終了時に dirty フラグをセット（通常色への戻し描画を保証）
- `unit_damaged` シグナルを BoardManager に追加。EventQueue が damage/heal/poison_damage 処理時に emit
- `unit_placed` シグナル接続を追加。配置・死亡時に `_mark_all_cells_dirty()` を呼び全セルを再描画
- `_render_cell()` に状態異常（恐怖・凍結・石化・毒）のスタック数表示を追加

### Added
- **CheckAgent相当の確認実施**: `_get_lifesteal_pct` が `_push_on_hit_effects` 移行後に未使用のまま残存 → 削除

- **マルチエージェント体制を構築**
  - `.claude/agents/checker.md` を新規作成。実装完了後に呼び出す CheckAgent を定義
  - `CLAUDE.md` 冒頭に「エージェント運用ルール」セクションを追加。コード変更を伴う全実装でchecker必須のフローを明記

### Added
- **EventQueue コメント修正**: effect_type 一覧に `"poison_damage"` を追記（実装済みだが未記載だった）

- **EventQueue 最適化・状態異常システム完成** (`BoardManager.gd`, `EventQueue.gd`, `Main.gd`)
  - **サポート効果の再計算を盤面変化時のみに限定**: `_board_dirty` フラグ + `on_board_changed()` で毎フレーム呼び出しを廃止。place_unit/remove_unit/promote 時のみ再計算
  - **状態異常管理を Timer ノードに移行**: `_status_timer`（1秒ごと）で poison_stacks ダメージ・frozen/fear/stun カウントダウンを処理。毎フレームのスタックチェックを廃止
  - **毒ダメージを EventQueue 経由に**: `poison_damage` イベントタイプを追加。ダメージ後に `status_damage` シグナルを発火。毒で死亡したユニットは death_events 経由で `remove_unit`
  - **恐怖中の ATK 半減**: `_do_attack` 冒頭で `fear_turns > 0` のとき `effective_atk = max(1, effective_atk / 2)`
  - **凍結・石化中の攻撃スキップ**: `process_combat` で前列・後列ループに `frozen_turns > 0 or stun_turns > 0` チェックを追加
  - **状態異常シグナルをログ表示**: `status_damage` / `status_cleared` を Main.gd に接続しログへ出力
  - `base_hp_ref` を BoardManager に追加して Main.gd から参照を渡すことで Timer tick の flush が base_hp にアクセス可能に

- **優先度付きチェーンイベントキューを実装** (`scripts/EventQueue.gd` 新規作成)
  - 優先度定数: IMMEDIATE(1) / STATUS(2) / SUPPORT(3) / ACTIVE(4) / ARTIFACT(5) / BOARD(6) / MERGE(7)
  - イベント構造: priority, source, target, effect_type, value, extra, timestamp
  - 同フレーム内は優先度昇順で処理、同優先度は積まれた順を保持
  - ループ防止: `_damaged_ids` で同フレーム内に damage を受けたユニットを管理し二重適用をスキップ
  - 遅延キュー: priority 6–7 は `_deferred_pending` フラグで次フレームに処理（将来の盤面条件チェック/合体判定用）
  - `flush(board_manager, base_hp)`: ダメージ→死亡後処理→遅延キューの順で実行
  - Main.gd でインスタンス化し `board_manager.event_queue` にセット

- **BoardManager のダメージ/回復/本体ダメージを EventQueue 経由に変更** (`BoardManager.gd`)
  - `_do_attack`: `target.take_damage()` の直接呼び出しを廃止し `event_queue.push("damage")` に変更
  - `_do_attack`: 吸血ヒールも `event_queue.push("heal")` 経由に変更（skill_name 付き extra で `active_skill_used` シグナルを通知）
  - `_do_attack`: 本体ダメージも `event_queue.push("base_damage")` 経由に変更
  - `_apply_regen`: HP直接変更を `event_queue.push("heal")` 経由に変更
  - `process_combat` 末尾に `event_queue.flush(self, base_hp)` を追加
  - `remove_unit` に null ガードを追加（EventQueue の二重処理対策）

### Added
- **吸血・再起・障壁付与の実装** (`BoardManager.gd`, `UnitData.gd`)
  - **吸血（命中時）**: `_get_lifesteal_pct()` でactive_skillを解析し命中ダメージの%をHP回復
    - ブラッドスライム: 30%回復 / グール: 25%回復
  - **自己再起（撃破時・1回限り）**: `remove_unit` でactive_skillに"自己再起"があれば`_has_revived`フラグを確認してHP5で復活・タイマーリセット
    - スケルトン: 撃破時HP5で1度だけ復活
  - **障壁付与（常時発動）**: `_damage_reduction` フィールドを追加。支援元が生存中は対象の受けるダメージを毎フレーム-1軽減
    - マッドスライム: 同行前列の味方に障壁付与
  - `UnitData` に `_has_revived: bool`・`_damage_reduction: int` を追加

- **デバッグログ強化** (`Main.gd`, `BoardManager.gd`)
  - サポート効果ログ（5秒ごと）: `[サポート] source → target に 効果名` 形式
  - アクティブスキルログ: `[アクティブ] ユニット名 の スキル名 発動（命中時/撃破時）`
  - 新シグナル `active_skill_used(side, row, col, skill_name)` を追加
  - 新シグナル `unit_revived(side, row, col)` を追加

- **UIセル表示強化** (`Main.gd`)
  - HPバー: 各セルに `██████░░` 形式の8ブロックHP可視化
  - アクティブバフ略称: `ATK+N` / `SPD+` / `HP回` / `障壁` / `後列↑` をセル内に表示
  - スキルフラッシュ: 吸血発動時0.6秒・再起発動時1秒間セルがオレンジでハイライト + `★スキル名!` 表示
  - デッキ枚数表示: 自デッキ/捨て札枚数・敵デッキ/捨て札枚数をUIに追加

### Added
- **常時発動サポート効果を実装** (`BoardManager.gd`, `UnitData.gd`)
  - `UnitData` にランタイムボーナスフィールドを追加: `_atk_bonus`, `_interval_bonus`, `_regen`, `_can_attack_from_back`, `_back_atk_factor`（`clone()` には引き継がない）
  - `BoardManager._apply_support_effects()`: 毎フレーム全ユニットのボーナスをリセット→再計算
  - `BoardManager._process_unit_support()`: 各ユニットの `support_effect` 文字列を " / " で分割し 常時発動 エントリを処理
  - `BoardManager._get_support_targets()`: ターゲット記述（隣接/同行/同列/前列/全体）と種族フィルタを解析
  - `BoardManager._apply_regen()`: 1秒ごとに `_regen > 0` のユニットのHPを回復
  - 実装済み効果: **ATKバフ**（隣接/同行獣に+2 ATK）/ **SPDバフ**（同行/同列味方の攻撃間隔-0.3s）/ **HPバフ**（1 HP/秒回復）/ **後列攻撃**（後列ユニットが攻撃タイマーをティック・極低ATKは×0.3）
  - 未実装（今後）: 障壁付与・吸血付与・再起付与・デバフ波及・シナジー増幅
  - `_do_attack` に `atk_override: int = -1` パラメータを追加（後列攻撃の減衰ATK対応）

### Changed
- **敵デッキをプレイヤーと同一構成に変更** (`EnemyAI.gd`)
  - 旧構成：ゼリーフィッシュ・ミミック・アビスゼリー・シャドウ・ヴリコラカス・ワイト・コカトリス・ケットシー・マンティコア（高HPで重すぎ）
  - 新構成：アメーバ・マッドスライム・ブラッドスライム・スケルトン・グール・バンシー・ゴブリン・ウルフ・タイガー（プレイヤーと同じ）

### Changed
- **効果構造を2層化** (`UnitData.gd`, `DeckManager.gd`, `EnemyAI.gd`, `docs/card_database.md`)
  - 旧構造：サポート効果・攻撃時効果・固有スキルの3層
  - 新構造：サポート効果（常時発動/召喚時/条件達成時）＋アクティブスキル（命中時/撃破時/HP閾値時/時間経過/召喚時/その他）の2層
  - 攻撃時効果 → アクティブスキル（命中時）に統合
  - 固有スキル → アクティブスキルに【固有】プレフィックス付きで統合
  - `UnitData` フィールド: `attack_effect` を廃止し `active_skill` に一本化（`support_effect` は据え置き）

- **card_database.md を2層効果構造で全面書き直し**（`docs/card_database.md`）
  - 全28ユニット（プレイヤー14枚・敵14枚）のサポート効果／アクティブスキルを〈発動タイプ・対象・詳細〉形式に統一
  - 攻撃時効果欄を削除し、命中時発動としてアクティブスキル欄に移行
  - 固有スキルをアクティブスキル内【固有】エントリとして統合

- **プレイヤーデッキをcard_database.md準拠9枚構成に再構築** (`DeckManager.gd`)
  - 旧構成：アメーバ/マッドスライム/ゼリーフィッシュ（スライム）・スケルトン/グール/バンシー（アンデッド）・ゴブリン/ウルフ/コカトリス（獣）
  - 新構成：アメーバ・マッドスライム・ブラッドスライム（スライム）／スケルトン・グール・バンシー（アンデッド）／ゴブリン・ウルフ・タイガー（獣）
  - 全カードに card_database.md 準拠の `support_effect` / `active_skill` データを追加

- **敵デッキをcard_database.md準拠9枚構成に再構築** (`EnemyAI.gd`)
  - 新構成：ゼリーフィッシュ・ミミック・アビスゼリー（スライム）／シャドウ・ヴリコラカス・ワイト（アンデッド）／コカトリス・ケットシー・マンティコア（獣）
  - 全カードに card_database.md 準拠の `support_effect` / `active_skill` データを追加
  - プレイヤーと異なるカードセットで差別化

- **CLAUDE.md にユニット効果構造表を追加**（`CLAUDE.md`）
  - 2層効果（support_effect / active_skill）の発動タイプ一覧と説明を追記

### Changed
- **攻撃対象を「前列優先・貫通なし（案A）」に変更** (`BoardManager.gd`)
  - `_do_attack`: 固定 `enemy_front_col` を廃止し `_get_frontmost_col()` で前列→中列→後列の順に最初のユニットを攻撃
  - `_get_frontmost_col(side, row)` を追加（-1=行にユニットなし）
  - `_try_promote`: 前列が既に埋まっている場合は何もしないガードを追加
  - `process_combat`: 毎フレームの先頭で全行の繰り上がりチェックを実行（中列→前列の自動昇格により中列ユニットも攻撃に参加）

### Fixed
- **本体ダメージ判定を全列チェックに修正** (`BoardManager.gd`)
  - 変更前：前列が空なら同行の中列・後列にユニットがいても本体ダメージが入っていた
  - 変更後：対象行の全3列（前・中・後）にユニットが1体もいない場合のみ本体ダメージ

### Added
- **中列繰り上がりロジックを実装** (`BoardManager.gd`)
  - `_try_promote(side, row, col)` を追加。`remove_unit` の末尾から呼び出される
  - 前列（自陣=col2、敵陣=col0）が空になった際、同行の中列（col=1）ユニットを前列に移動
  - 後列（col=0/2）は移動しない（固定）
  - 移動はHPをそのまま引き継ぎ、攻撃タイマーは1インターバル分リセット

### Changed
- **敵デッキをcard_database.md準拠の9枚構成に刷新** (`EnemyAI.gd`)
  - 旧構成：ゴブリン/オーク/スケルトン/ウルフ/シャーマン（5枚・独自ステータス・前列集中）
  - 新構成：スライム3枚・アンデッド3枚・獣3枚（9枚・card_database.md準拠ステータス）
  - 列分散：前列3（ゼリーフィッシュ・シャドウ・ゴブリン）/ 中列3（クリスタルスライム・グール・コカトリス）/ 後列3（ブラッドスライム・ワイト・タイガー）
  - DeckManagerと同形式の `{name, col}` 辞書ベースに構造統一

### Added
- **山札切れ時の捨て札リシャッフル処理を実装** (`DeckManager.gd`, `EnemyAI.gd`)
  - DeckManager: `discard` 配列を追加。カード発動後は `deck` 末尾でなく `discard` へ移動。`deck` 空時に `discard` をシャッフルして `deck` に戻す
  - EnemyAI: `enemy_discard` 配列を追加。スポーン時に `enemy_deck[0]` を消費して `enemy_discard` へ移動。`enemy_deck` 空時に `enemy_discard` をシャッフルして `enemy_deck` に戻す
  - EnemyAI: カード選択を「ランダム参照（消費なし）」から「山札先頭を順番に消費」に変更し、正しい無限巡回を実現

### Changed
- **マナ不足時のカード挙動をスタック待機に変更** (`DeckManager.gd`)
  - 変更前：マナ不足→マナ消費なしで捨て札（デッキ末尾）へ送る
  - 変更後：マナが足りるまで先頭のカードで待機し、足りたら即発動

### Added
- **敵の次召喚カードをUI上に表示** (`EnemyAI.gd`, `Main.gd`)
  - EnemyAI にスポーン時点で次のカードを事前決定する `_pick_next_card()` と `get_next_card()` を追加
  - 次の敵カード名とスポーンまでの残り時間を「次の敵：〇〇 (X.Xs後)」形式で次カードパネル右横に表示

### Added
- **UnitData に `race` / `attack_range` フィールドを追加** (`UnitData.gd`)
  - `race: String`（"スライム" / "アンデッド" / "獣"）
  - `attack_range: String`（"1行" / "上含む2行" / "下含む2行" / "上下含む3行"）デフォルト "1行"
  - `clone()` で両フィールドをコピーするよう対応

- **card_database.md 準拠のカードデータ実装** (`DeckManager.gd`)
  - スライム系 3 種: アメーバ・マッドスライム・ゼリーフィッシュ
  - アンデッド系 3 種: スケルトン・グール・バンシー
  - 獣系 3 種: ゴブリン・ウルフ・コカトリス
  - 初期デッキ 9 枚構成（cost 1-2 中心、重複あり）

- **攻撃範囲の多行対応** (`BoardManager.gd`)
  - `_get_target_rows(row, attack_range)` を追加
  - `_do_attack` が attack_range に応じて複数行を攻撃するよう変更
    - "1行": 同行のみ（従来どおり）
    - "上含む2行": 自行＋上行
    - "下含む2行": 自行＋下行
    - "上下含む3行": 全行（バンシー・プラズマスライム等）

- **EnemyAI のユニット定義に race / attack_range を追加** (`EnemyAI.gd`)

### Fixed
- **多行攻撃時の本体ダメージ倍増を修正** (`BoardManager.gd`)
  - 変更前：複数行攻撃で全行が空きの場合、行数分だけ本体ダメージが発生していた
  - 変更後：いずれかの行にユニットがいれば本体ダメージなし、全行空きでも本体ダメージは ATK×1 回のみ

### Changed
- **未使用カード定義にコメントを追加** (`DeckManager.gd`)
  - ゼリーフィッシュ・コカトリスに「将来のデッキ構築機能用予備カード」コメントを付与

### Fixed
- **全カードが前列に集中して配置失敗が連発する問題を修正** (`DeckManager.gd`)
  - 原因: card_pool の全カードが `"col": 0` → `place_unit` で `2 - 0 = 2` に変換され全て前列(col2)へ集中
  - 修正: `deck_list` を `{name, col}` 辞書形式に変更し、配置列をデッキエントリごとに指定できる設計に変更
  - 前列3枚（アメーバ・ゴブリン・グール）/ 中列3枚（マッドスライム・ウルフ・バンシー）/ 後列3枚（スケルトン・アメーバ・ゴブリン）の均等分散
  - card_pool から `"col"` キーを削除（配置列の責務を deck_list 側に移行）

### Fixed
- **自陣の列インデックス逆転を修正** (`BoardManager.gd`)
  - `place_unit` で自陣（side 0）の `assigned_col` を `2 - col` に変換し、前列ユニットが視覚的な前列（col 2）に配置されるよう修正
  - `process_combat` / `_do_attack` で自陣の前列を col 2、敵陣の前列を col 0 として戦闘処理するよう修正
  - `_on_unit_died` のログ表示で物理 col を表示 col に変換し、ログが正しい列名を示すよう修正

- **マナ不足時のカード処理を修正** (`DeckManager.gd`)
  - 変更前：コスト不足でも `place_unit` を試みてマナを消費していた
  - 変更後：`mana < cost` の場合はマナを消費せずカードを捨て札（デッキ末尾）へ送る

### Changed
- **energy → mana に統一** (`DeckManager.gd`, `Main.gd`)
  - 変数名：`energy` → `mana`、`ENERGY_MAX` → `MANA_MAX`、`ENERGY_REGEN` → `MANA_REGEN`
  - シグナル名：`energy_changed` → `mana_changed`
  - UI表示：「Energy」→「Mana」
  - 内部変数：`energy_bar_cells` → `mana_bar_cells`、`energy_value_label` → `mana_value_label`
  - 関数名：`_build_energy_bar` → `_build_mana_bar`、`_update_energy` → `_update_mana`

---

## [0.1.0] - 2026-04-03

### Added
- Phase 1 プロトタイプ初期実装
  - 自陣 3×3 / 敵陣 3×3 の対面盤面
  - 左右対称レイアウト、中央ラインで自陣・敵陣を分割
  - 自動巡回デッキ + マナシステム（1.0/s 回復、最大10）
  - 前列のみ攻撃する戦闘システム
  - シンプルな敵AI（3.5秒間隔でランダム召喚）
  - 次カードパネル（カード名・コスト・詳細・発動チェックタイマー表示）
  - デバッグUI（HP・マナ・ログ表示）
  - ゲームオーバー / YOU WIN 判定
