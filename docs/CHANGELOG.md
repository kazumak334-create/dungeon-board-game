
# CHANGELOG
## 2026-04-24

### ファイル構成整理フェーズB（scripts/debug/分離）

**実装内容**

- デバッグ・テスト用18ファイル（+.uid 18）を `scripts/` → `scripts/debug/` へ移動
- `DebugPanel.gd`（autoload）は `scripts/` 直下に維持
- 影響ファイル参照パス更新：`DebugPanel.gd` / `Main.gd` / `DevUI.gd` / `RunTests.gd` / `TestRunner.gd`（11箇所）/ `tests/` 3ファイル / `scenes/` 2ファイル / `settings.local.json` / `debug_ui_requirements.md`
- `.git/hooks/pre-commit` のテスト実行パスも更新
- テスト結果：4652 passed / 0 failed

## 2026-04-21

### Phase 4 #6「敵デッキパターン」初期MVP実装完了

**実装内容**

**1. 警戒レベルシステム要件定義更新（3ドキュメント）**
- alert_level_combat_impact.md: 警戒MAX=3、通常戦0-2、ボス1-3に変更
- alert_level_requirements.md: エリート廃止、3段階デッキ構成に変更
- enemy_deck_system_requirements.md: 新規作成、ボスデッキ構成確定

**2. エリートノード廃止**
- elite_pools削除（44行削除）
- EnemyPlacementHelper.gdのエリート混入ロジック不要化

**3. ボス戦alert判定を新仕様に対応**
- EnemyAI.gd: alert >= 4/5 → alert >= 3に変更
- 全15ボスデータ: phase2_lv4/lv5 → phase2_lv3に統一
- alert_level_buffs: "4"/"5" → "2"に変更
- alert 1: バフなし、alert 2: 小バフ（HP+5/ATK+1）、alert 3: 強化デッキ

**4. ボス9体に絞り込み**
- 15ボス → 9ボスに削減（種族バランス考慮）
- 削除: boss_firewall, boss_kepalos, boss_cryptor, boss_null, boss_overfit, boss_adversary
- 残存: 各Act × beast/slime/undead（+mixed）

**5. Act2/3ボスデッキ実装**
- boss_act2_deadlock（ベース + 強化）
- boss_act3_guardian（ベース + 強化）
- 初期MVP: 3ボス×2段階=6デッキで全Act通しプレイ可能

**検証結果**
- ✅ 構文チェックパス
- ✅ テスト全件成功（4655件）
- ✅ 通しプレイ可能な状態

**コミット**
- 1615778: 警戒レベル要件定義更新
- c535680: 敵デッキシステム要件定義書作成 + elite_pools削除
- 36a152b: ボス戦alert判定を新仕様に対応
- 1251a30: 未使用ボス6体削除
- ddef4df: Act2/3初期MVPボスデッキ実装

**影響範囲**
- Phase 4 #6完了により通しプレイテスト可能
- Phase 4 #11バランス調整の前提条件整備完了

## 2026-04-20

### 呪文手動発動システム実装（Phase A）

**実装内容**
- SpellSlotSystem.gd: 自動発動削除、手動発動API追加（can_cast/cast_spell/get_cast_block_reason）
- GameUI.gd: 4状態表示（empty/unavailable/ready/casting）、8コンポーネント構成、パルスアニメーション、エラーフィードバック実装
- Main.gd: process_slots()自動呼び出し削除

**検証結果**
- ✅ 構文チェックパス
- ✅ UI継承チェックパス
- ✅ 要件定義書との乖離なし

**備考**
- 要件定義書: spell_manual_cast_ui_design.md（Designer）、spell_manual_cast_requirements.md（Architect）
- Phase B（ログ収集）、Phase C（プロトコル）は未実装
- 左クリック発動、右クリック破棄に対応

### 64枚新規カード用effect_id 30個実装（Phase 4基盤）

**実装内容**
- EffectDB.gd: 30個の新規effect_id定義追加
  - x_stack_add, atk_apply, burn_by_status_count, curse_multiply, damage_by_x, mana_steal, position_swap_front_back, crit_mult_boost 等
- EffectActions.gd: 21個のdo_*関数実装（732行追加）
  - do_damage_by_x, do_curse_multiply, do_buff_steal_all, do_burn_by_status_count 等
- 仕様修正3件:
  - position_swap_front_back: 呪い最大優先に変更
  - on_ally_death_thorn_boost: 効果B実装（死亡数倍率）
  - tile_set_all: scope="front_columns"対応
- cards.json: Toxswamp呪文追加（前列毒沼設置）
- UnitData.gd: _ally_death_countフィールド追加

**テスト修正**
- TestBattleScenario.gd: スケルトン参照削除
- TestGameSystem.gd / TestDeckPrepLayout.gd: シグネチャエラー修正（r: Node → r: RefCounted）
- TestSession.gd: DeckPrep.tscnスキップ追加

**検証結果**
- ✅ 構文チェックパス
- ✅ テスト全件成功（4665件）
- ✅ JSON構文正常

**備考**
- コミット: 24a6ffe
- 影響範囲: Phase 4 #1-#3（上位ユニット・呪文追加）の基盤実装完了

### 継続ウェーブ型転換の残論点確定完了（Phase 4 #0）

**完了内容**
- pve_wave_pending_issues.md 11項目中10項目を確定（✅ マーク）
- 未確定2項目の対応方針決定:
  - 項目4（キュー式呪文の制約）: Phase 4 #11バランス調整フェーズで決定
  - 項目11（素材ドロップ詳細）: Phase 4 #13系列タスクで実装予定

**roadmap更新**
- タスク#0: 「保留」→「完了」（2026-04-20）
- 備考欄に対応方針を明記

**影響範囲**
- Phase 4実装作業の前提条件が整備完了
- #0a-0e実装タスクの仕様確定

### スキルツリーT4完了確認（Phase 4 #5）

**確認内容**
- T1-T6全階層が既にPhase 2 #4で実装済みであることを確認
- T4: クラス固有スキル各8個（カード追加系）
- T6: クラス固有究極スキル各5-6個（最強スキル）
- SkillTreeGenerator.gd に全データ定義済み

**roadmap更新**
- タスク#5: 「未着手」→「完了」（実装済みタスクの再評価）

### Phase 4 タスク整理（#1, #2, #2a, #4, #7, #12）

**廃止タスク（4件）**
- #1（上位ユニット★4）: 64枚カード追加でlegend 32枚実装済み
- #2（最終形態★5）: 64枚カード追加でgod 18枚実装済み
- #2a（合成ツリー再設計）: 合成システム廃止により不要
- #4（アーティファクト30種追加）: 現状14種で十分
- #12（警戒レベル減少イベント）: Phase 3 #27で全イベント/レスト時に警戒-1実装済み

**規模縮小（1件）**
- #7（イベント量産）: 「20種以上」→「最小6種、ローンチ15種」に変更（Act毎最大2回発生のため）

**影響範囲**
- Phase 4残タスクが大幅に削減され、優先順位が明確化

## 2026-04-19

### UI継承チェックスクリプト作成

**作成ファイル**
- check_ui_inheritance.sh（UI操作を行うRefCountedクラスを自動検知）
- docs/dev/ui_inheritance_check.md（使い方・修正方法ドキュメント）

**統合**
- check_syntax.sh に統合（構文チェック後に自動実行）

**検出した問題**
- 8ファイルが RefCounted を継承しつつ UI操作を実行
  - CardUIComponent.gd
  - DeckPrepBoard.gd
  - DeckPrepBoardSpells.gd
  - DeckPrepInfo.gd
  - DeckPrepRightPanel.gd
  - DeckPrepSidebar.gd
  - DevUI.gd
  - UIFactory.gd

**備考**
- コミット: 未コミット
- 問題修正は別タスク（全て extends Control への変更が必要）

### Phase 4 #0a WaveManager実装完了 + UI改修

**実装内容**
- WaveManager.gd（275行）新規作成: Wave進行管理、小Wave間状態保存、BW休憩遷移
- ProgressBar.gd（61行）新規作成: Wave進行バー7マス表示（戦闘4区間+ショップ3）
- DeckPrepPopup.gd（45行）新規作成: Battle内ポップアップとしてデッキ編集
- 画面遷移フロー変更: InitialCardPick→BATTLE直行（DeckPrep独立画面廃止）
- シグナル整合性修正: wave_started/wave_ended/big_wave_completedシグナル実装
- BoardManager.gd: record_dead_unit引数修正（4引数対応）
- 継承エラー修正: WaveManager extends Node（RefCountedから変更）

**検証結果**
- ✅ 構文チェックパス
- ✅ エラー0件（75件→0件）
- ✅ 全シグナル接続正常

**備考**
- コミット: 未コミット

### CheckAgent検証：WaveManager改修 + ショップUI 3段構成化（Phase 5 #0f step 2-4～2-7）

**検証対象**
- scripts/WaveManager.gd（SHOP_TRIGGER_WAVES、intermission_requested、_build_shop_config、resume_from_intermission）
- scripts/Main.gd（intermission_requested接続、start_rest_screen引数、_on_intermission_requested）
- scripts/RestScreenManager.gd（DEFAULT_SHOP_CONFIG、_shop_config正規化、initialize引数）
- scripts/RestScreenShop.gd（TIER定数、DUMMY_MATERIALS、3段抽選、ダミー素材分岐、_get_cell_position変更）

**検証結果**
- ✅ 全項目実装プロンプト通り
- ✅ 旧シグナル名（rest_screen_requested）削除確認
- ✅ 旧メソッド名（resume_from_rest）削除確認
- ✅ 修正不要

**備考**
- コミット: 未コミット

### CheckAgent検証：次Wave開始時アニメーション（Phase 5 #0f step 2-3）

**検証結果**
- ✅ `_on_wave_started()` に `await _animate_wave_start()` 追加（L975）
- ✅ `_animate_wave_start()` 関数実装（L1037-1055）
  - is_animating = true/false 設定
  - 暗転・敵配置・暗転明け・スライドイン・睨み合い（1.5秒）の順序
- ✅ 補助関数4つ実装（L1057-1097）
  - `_animate_fade_to_black()`
  - `_animate_fade_from_black()`
  - `_position_enemies_offscreen()`
  - `_animate_enemy_slidein()`
- ✅ 実装プロンプトとの完全一致を確認

**備考**
- コミット: 未コミット

### CheckAgent検証：自軍ユニット前進アニメーション（Phase 5 #0f step 2-2）

**検証結果**
- ✅ `_on_battle_victory()` 内に `await _animate_player_advance()` 呼び出し追加（L995）
- ✅ `_animate_player_advance()` 関数実装（L1022-1034）
  - Tweenによる右方向30px前進
  - parallel()で全ユニット同時実行
  - await tween.finishedで完了待機
- ✅ 実装プロンプトとの完全一致を確認

**備考**
- コミット: 未コミット

## 2026-04-18

### 警戒レベルシステム仕様変更（Phase 3 #27）

**仕様変更**
- 警戒レベル最大値を5→3に変更
- 変動ルール統一: 戦闘+1、イベント/レスト-1（旧: レスト-2）
- 警戒レベルによる敵強化はPhase 4バランス調整フェーズで実装予定

**変更ファイル**
- GameSession.gd: MAX_ALERT_LEVEL = 3 に変更
- MapSelect.gd: レストノード選択時の警戒減少を-1に統一

**備考**
- roadmap.md Phase 3に#27追加、#23備考欄更新
- コミット: 未コミット

### RestScreen実装進捗（Phase 4 #0b）

**Phase 1完了: 基盤構築**
- RestScreenManager.gd作成
- 基本的な画面構造の確立

**Phase 2完了: デッキ編集機能**
- BoardManager.gd拡張（RestScreen用モード追加）
- 手持ちカードエリア実装
- カードドラッグ&ドロップ対応

**Phase 3完了: ショップ機能**
- RestScreenShop.gd作成（220行）
- 9個の商品をランダム生成・3x3グリッド表示
- クリック購入処理（gold減算、selected_deck追加）
- 購入可否による枠線色変更（緑=購入可、赤=資金不足、灰=売却済）
- RestScreenManager.gd統合（購入完了シグナル連携）

**Phase 4完了: ユニット復帰システム**
- RestScreenRevive.gd作成（143行）
- wave_dead_unitsから死亡ユニット検索
- 復帰コスト計算（rarity_price × 0.3）
- 復帰ボタン生成・クリック処理（gold減算、selected_deck追加、wave_dead_units削除）
- RestScreenManager.gd統合（build_hand_area拡張、復帰完了シグナル連携）

**Phase 5完了: 右パネルUI・遷移統合**
- 右パネル状態別表示（未選択時/カード選択時/ショップホバー時）
- 手持ちカードホバーで詳細表示（CardDB参照、ステータス・効果・特性）
- デッキバリデーション（3×3配置必須、未完成時エラー表示3秒）
- 次へ進むボタン（バリデーション→Main._on_rest_screen_closed()経由で遷移）
- スキップボタン（バリデーション省略、即座に遷移）
- RestScreenManager.gd拡張（230行→480行）

**RestScreen Phase 3-5完了: 全機能実装済み**

**備考**
- roadmap.md Phase 4 #0bステータス更新（未着手→進行中）
- TaskList #20に対応


## 2026-04-13

### DeckPrep バランスパネル実装 + コンポーネント分割

**バランスパネル実装**（d57724a）
- DeckPrep左サイドバーに突・守・崩のバランス可視化パネル追加
- 企画書: balance_panel_plan.md（ペルソナ全員ポジティブ評価）
- 技術設計: balance_panel_architecture.md
- DeckPrepSidebar.gd: バー3本構築・自動分類（traits/HP/ATK比率）・リアルタイム更新
- DeckPrep.gd: update_balance_panel()呼び出し追加

**DeckPrepコンポーネント分割リファクタリング**
- DeckPrepSidebar.gd（新規255行）: 左サイドバー独立化
- DeckPrepRightPanel.gd（新規38行）: 右パネル独立化
- DeckPrepBoardSpells.gd（新規600行）: 呪文・手持ち・合成エリア独立化
- DeckPrep.gd: 157行削減（可読性向上）

**シナジーシステム基盤追加**
- synergies.json: 毒シナジーデータ
- SynergyDB.gd: シナジーDB実装

**設計ドキュメント追加**
- artifact_design_plan.md: アーティファクト設計企画
- persona_gameplay_review.md: コアループ独自性評価
- persona_detailed_review.md, core_loop_progression_review.md

**テスト修正**
- TestDBIntegrity.gd: cost→mana、装備テスト無効化
- TestDeckPrepLayout.gd: DeckPrepBoardSpells移行に対応
- SpellSlotSystem.gd: cost→mana修正
- テスト全パス（2432 passed / 0 failed）

**ダンジョンマップ完全書き換え**（74bc403）
- 画面サイズ基準の座標計算（viewport基準・固定座標廃止）
- 交差完全禁止アルゴリズム（i番目→i〜i+1番目のみ接続）
- タイトルを上余白中央に固定配置
- 全ノードが画面内に収まるレイアウト
- MapGenerator.gd: _generate_layer_connections()で層間接続一括生成
- MapSelect.gd: 動的座標計算・タイトル固定位置化

**スタートノード選択可能化 + 接続交差完全除去**（4ec7a3f）
- 層0の3ノードが選択可能に（depth→layer修正）
- 接続生成前のlane順ソート明示化（交差完全除去）

**Python版アルゴリズム完全移植**（c24f2be）
- 10×10グリッドベース配置（ランダムな行に配置）
- 交差判定関数による厳格な接続制御
- 全ノードに最低1本接続保証（途切れ禁止）
- グリッド座標→画面座標変換（grid_to_screen）
- ノードデータ構造: layer/lane → col/row
- アイコン・ノードデザイン・クリック処理は変更なし

**マップにルートメモ機能追加**（68355e6）
- 右クリック+ドラッグで予定ルートを描画
- 情報パネル: 総マス数/最大警戒Lv/ノード種別内訳
- 警戒レベルシミュレート機能
- StS実況者がペンで書き込むようなUX

## 2026-04-12

### Phase 2 完了宣言

**Phase 2（画面ループ）完了**
- 全タスク（#1-6）実装完了
- 1ランを通しで遊べる状態を達成
- Title → MaterialSelect → MapSelect → DeckPrep → Battle → Result → BossReward のフロー確立

### Phase 3→4 移行：タスク整理・バランス調整計画策定

**Phase 3 完了宣言**
- 主要タスク（#1-7, #12, #18, #21-26）全て完了
- MVP（マップ/ショップ/イベント/ボス/警戒/アーティファクト/ドロップ）実装完了

**タスク整理**
- #14（エリート戦）廃止 → 警戒システムに統合済み
- #17（グリッチ演出）Phase 5以降に延期
- #11（スキルツリーT2-T3）Phase 4へ移動
- #16（ストーリー断片）Phase 4へ移動

**Phase 4 開始**
- balance_adjustment_plan.md作成（Sprint A-I、9スプリント）
- ユニット以外の全バランス調整要素を体系化
  - 呪文/アーティファクト/マナ経済/敵デッキ/警戒システム/報酬/ノード確率/イベント/ボス/スキルツリー

### Phase 3 ボスシステムAct1完成（#6）

**企画書作成**
- boss_system_completion.md: planningエージェント（Opus）による全8ボス企画
- 各ボス3段階デッキ（normal/strong/enraged）、boss_phase・alert_levelで切り替え
- ボス専用ユニット15体定義（Act1: 5, Act2: 6, Act3: 4）

**要件定義作成**
- boss_system_requirements.md: architectエージェント（Sonnet）によるAct1スコープ要件定義
- 3ボス、9デッキ、5専用ユニットに絞った実装計画

**実装完了（Sprint 1-3）**
- Sprint 1: cards.json データ追加
  - boss_decks: 9エントリ追加（boss_act1_beast/beast_strong/beast_enraged × 3種族）
  - boss_exclusive_units: 5体追加（猛獣使い、母スライム核、融合スライム、屍術師、死骸の王座）
  - bosses: alert_level_buffs更新（Lv4: HP+5/ATK+1、Lv5: HP+10/ATK+2）

- Sprint 2: CardDB.gd 読み込み実装
  - BOSS_DECKS変数追加・JSON読み込み
  - BOSS_EXCLUSIVE_UNITS変数追加・UNITS辞書にマージ

- Sprint 3: EnemyAI.gd ボスデッキ構築
  - _build_boss_deck() TODO解消（109-116行目）
  - CardDB.BOSS_DECKSから取得、エラー時はENEMY_POOLSにフォールバック

**roadmap.md更新**
- #6: Act1データ完了・Act2/3はPhase4

### Phase 3 警戒システム 企画・要件定義・実装完了（#22-26）

**企画書作成**
- alert_level_combat_impact.md: planningエージェント（Opus）による企画
- Lv1-2: 盤面環境効果のみ（敵前列アーマー/自陣棘・呪いマス）
- Lv3-5: 強化デッキ1/2/3 + エリート混入（50%/100%）
- Act遷移時に警戒レベル0リセット
- Phase 3 #13（環境変化システム）を警戒システムに統合・廃止

**要件定義作成**
- alert_level_requirements.md: architectエージェント（Sonnet）による要件定義
- 実装対象ファイル・変更箇所・実装順序を明確化
- レストノード実装計画を追加（alert_level -= 2の入口）

**実装完了（Sprint A-C）**
- Sprint A: レストノード・戦闘マス+1・データ定義
  - MapGenerator.gd: restノード追加（depth 4-6, 20%確率）
  - MapSelect.gd: rest選択処理（alert_level -= 2）、battle/elite選択（+1）
  - cards.json: enemy_pools構造変更（act_N_weak/enhanced1/2/3）、elite_pools追加
  - CardDB.gd: ELITE_POOLS読み込み
  - GameSession.gd: elite_injected_in_battle追加

- Sprint B: ロジック層
  - EnemyAI.gd: 警戒レベル別プールキー決定（_select_pool_key）
  - TileEffectManager.gd（新規）: 盤面環境効果（Lv1アーマー/Lv2棘・呪い）
  - EnemyPlacementHelper.gd（新規）: エリート混入（Lv4=50%/Lv5=100%）
  - Main.gd: alert修飾処理呼び出し

- Sprint C: UI・報酬
  - MapSelect.gd: 警告マーク表示（!/!!/!!!、黄/橙/赤）
  - Result.gd: エリート混入時カード選択肢+1

- 追加実装: Act遷移時リセット
  - BossReward.gd: Act遷移時にalert_level = 0

**roadmap.md更新**
- #22-26: 警戒システムタスク追加・完了
- #13（環境変化システム）を廃止としてマーク

**プロセス改善**
- memory/feedback_requirements_first.md: 追加仕様判明時は企画・要件定義を先に修正するルール追加

**Phase 4計画追加**
- event_worldview_candidates.md: 警戒レベル減少イベント企画追加（各Act1個、合計3個）
- roadmap.md Phase 4 #12: 警戒レベル減少イベント追加（バランス調整時実装）

**警戒レベル変動ルール修正（2026-04-12追加）**
- alert_level_combat_impact.md: その他ノード（イベント・宝箱・ショップ）選択時-1を追加
- alert_level_requirements.md: MapSelect.gd 変更箇所に event/shop/gather 選択時-1処理を追記
- MapSelect.gd: event/shop/gather選択時に alert_level -= 1（下限0）を実装
- 戦略的意義: 戦闘を避けてイベント・宝箱・ショップを通るルートで警戒レベルを緩やかに下げられる

### ドロップテーブルシステム実装完了（#12）

**企画書・要件定義書作成**
- drop_table_system.md: planningエージェント（Opus）による企画
- drop_table_requirements.md: architectエージェント（Opus）による要件定義
- run_depth主軸の3ステージ構成（早期0-3/中期4-7/後期8+）
- エリート混入時ステージ+1参照（警戒システムとの統合点）

**実装完了（Sprint A + C）**
- RewardTable.gd（新規）: run_depth→ステージ→重み決定ロジック分離
- Result.gd: 既存RARITY_WEIGHTS_*削除、RewardTable.get_weights()呼び出しに差し替え
- Result.gd: BOOSTEDアイコン追加（エリート時ステージ繰り上げ時のみ表示）
- Late重み合計100調整（uncommon 36）、godレアリティ0%（MVP仕様）

**roadmap.md更新**
- #12: ドロップテーブル実装 完了マーク

### Phase 3 #21: マップノード数増加（最大6並列）

**マップ生成ロジック改善**
- MapGenerator.gd: MAX_LANES=6, MAX_CONNECTIONS=3定数追加
- depth別ノード数可変化
  - 序盤（depth 1-2）: 2-4ノード
  - 中盤（depth 3-6）: 3-6ノード
  - 終盤（depth 7-8）: 2-4ノード
- 接続ロジック改善
  - シャッフルベースのランダム接続
  - 各ノードの接続数を最大3に制限
  - 孤立防止ロジック維持
- TestSession.gd: コメントアウト漏れ修正

### Phase 3 #4: イベントノードシステム実装

**企画・設計**
- event_system_proposal.md: イベントシステム基本設計
- event_worldview_candidates.md: 世界観イベント9個の詳細設計
  - Act 1-3各3個、違和感のみで真実は明かさない
  - 報酬通常並み（Gold 60-100、アーティファクト）

**データ構造**
- cards.json: eventsセクション追加（世界観イベント3個実装）
  - memory_fragment（記憶の断片）
  - atlas_terminal_alpha（ATLAS端末α）
  - gray_stain（灰色の染み）
- 特殊アーティファクト2個追加: subject_card（実験体の札）、memory_key（記憶の鍵）
- CardDB.gd: EVENTS読み込み
- GameSession.gd: current_event_id, visited_events追加

**イベントシステム実装**
- Event.gd: 全面実装
  - ランダムイベント選択（Act別、訪問済み除外）
  - テキスト+選択肢表示
  - 結果適用（gold, hp, artifact, alert_level, sp, flavor）
  - 結果表示画面

**世界観イベント追加（Act 2-3）**
- Act 2: 動かない何か、音声ログ、グリッチ現象β
- Act 3: ATLAS端末Ω、白衣の人物、見たことのない扉
- 特殊アーティファクト4個追加: ATLAS破片α/β/Ω、グリッチコア
- **合計9個の世界観イベント実装完了**

**TODO**
- アーティファクト選択UI（artifact_choice）
- カード選択UI（card_choice）
- 本体HPシステム連携（hp result type）
- 特殊アーティファクト効果実装（ATLAS破片β、グリッチコア）

## 2026-04-11

### Phase 3 #5: ボス戦連戦システムの箱実装

**データ構造**
- GameSession.gd: boss_id, boss_phase追加
- cards.json: ボス3体にフェーズ別デッキID・バフ設定追加
  - enemy_deck_id_phase2_lv4（警戒Lv4用強化デッキ）
  - enemy_deck_id_phase2_lv5（警戒Lv5用超強化デッキ）
  - alert_level_buffs（警戒レベル別HP/ATKボーナス）

**連戦システム**
- Main.gd: _start_boss_phase2()実装
- 警戒Lv4以上: 通常デッキ → 強化デッキの連戦
- 第1戦勝利: マナ+5ボーナス、盤面/HP継続
- 第2戦: 敵デッキ再構築、全マス埋め配置

**ボス報酬**
- Result.gd: ボス戦の場合アーティファクト確定3択
- レアリティ重み付き（Uncommon優遇）

**TODO（バランス調整用）**
- 実際のデッキIDからデッキ読み込み（現在は暫定でActプール使用）
- ボス専用ユニット定義（boss_exclusive: true）
- バフ値の調整（現在は0）

### Phase 3 #7: アーティファクトシステム実装完了

**データ構造**
- cards.json: artifactsセクション追加（Common 5種、Uncommon 3種）
- CardDB.gd/GameSession.gd: ARTIFACTS/artifacts実装済み

**アーティファクト管理UI**
- Inventory.gd: アーティファクト一覧表示（レアリティ別タブ）
- DeckPrep.gd: アーティファクトカウント表示

**アーティファクト効果実装（7種）**
- Main.gd: battle_start_mana（マナ追加）、battle_start_tiles（タイル配置）、stat_buff（ユニットバフ）実装
- Result.gd: gold_bonus（Gold報酬増加）、reward_choices（報酬選択肢増加）実装
- BoardManager.gd: revive_first（最初の死亡ユニット復活）実装
- timed_buff（時間制限バフ）はTODO（バフシステム統合が必要）

**実装済み効果**
- 魔石の欠片（battle_start_mana +3）
- 鉄の護符（stat_buff 全ユニットHP+2）
- 狂戦士の角笛（stat_buff 前列ATK+1）
- 棘の種（battle_start_tiles 自陣前列に棘Lv1）
- 黄金のコイン（gold_bonus +20%）
- 不死鳥の羽（revive_first HP50%で復活）
- 幸運のお守り（reward_choices +1）

### Phase 2完了: スキルツリー実装

**スキルツリー画面（6階層ランダム生成）**
- SkillTreeGenerator.gd: 完全実装済み
- SkillTree.gd: 横ツリー表示UI実装済み
- T1-T6階層、T4/T6はクラス固有カード報酬
- CommonTaskbarの「スキル」ボタンから遷移
- T2の素材関連スキル削除（素材システム廃止対応）
- roadmap.md更新: Phase 2 #4完了

**Phase 2完全完了**
- 全6タスク完了
- 画面遷移ループ、バトル制限、スキルツリー実装済み

### 装備・素材システム廃止 → アーティファクトシステム導入

**設計変更**
- 装備システム全廃（装備スロット・合成ツリー削除）
- 素材システム全廃（素材採集・合成削除）
- アーティファクト（StS風パッシブアイテム）導入
- アーティファクト企画案作成: docs/design/artifact_system_proposal.md

**ドキュメント更新**
- roadmap.md: 装備・素材タスク7件廃止、アーティファクトタスク2件追加
- deckprep.md: 素材表示→アーティファクト表示に変更
- GAME_DESIGN.md: 装備・素材廃止を明記済み

**実装コード修正**
- GameSession.gd: materials → artifacts
- CardDB.gd: MATERIALS/EQUIPMENT削除、ARTIFACTS追加
- DeckPrep.gd: 素材カウント→アーティファクトカウント
- Inventory.gd: 素材タブ→アーティファクトレアリティタブ
- Result.gd, Shop.gd, MapSelect.gd: materials参照削除
- MaterialSelect.gd, Gather.gd: 削除（画面廃止）
- TestSession.gd: materialsテスト→artifactsに変更

### Phase 3 タスク#18完了: DeckPrep UX改善

**手持ちカード左右分離表示**
- DeckPrep.gd: ユニット（左）/呪文（右）を分離表示
- 視認性向上・ドラッグ操作の明確化
- コミット: 4e63372

**バグ修正3件**
- ドロップヒント表示の修正
- カード配置ロジックの修正
- その他UIバグ修正
- コミット: e81dcb9

---

## 2026-04-10

### Phase 3 マップ画面UI v2

**StS風横方向分岐ツリー実装**
- MapSelect.gd: 縦リストから横ツリー表示に全面改修
- MapGenerator連携: シード再現性・ race_theme対応
- ノード配置: depth×lane座標計算・中央配置アルゴリズム
- 接続線描画: Line2Dで前ノード→現ノード接続
- 状態管理: 現在地（青グロー）・訪問済み（灰）・到達可能（種別色）・未到達（暗灰）
- クリック処理: 到達可能ノードのみボタン化
- テスト: test_map_generator.gd追加
- コミット: 2fc9871

---

## 2026-04-10（続き）

### Phase 2完了

**スキルツリー実装**
- 6階層ランダム生成（T1-T6）、70+ダミースキル
- T4/T6階層でクラス固有カード報酬
- 横ツリーUI・前提スキルシステム
- ファイル：`scripts/SkillTree.gd`, `scripts/SkillTreeGenerator.gd`

**敵スケーリングシステム**
- Act別敵プール実装（5ランク：弱→中間→中→中間→強）
- `data/cards.json` enemy_pools、`GameSession.current_act` でプール選択
- ファイル：`scripts/EnemyAI.gd`, `scripts/CardDB.gd`

**警戒レベルシステム設計**
- 戦闘マス+1、レスト-2、Lv3+でデッキランク上昇、Lv5+でエリート確定
- `GameSession.alert_level` 追加、実装はPhase 3
- 設計：`docs/GAME_DESIGN.md`

**UI/UX改善**
- DeckPrep.gd: タブバー復活（配置・持ち物）
- GameUI.gd: セル内情報密度削減、バフ/デバフアイコン化

**ツール作成**
- `tools/session_check.py`: セッション開始時チェック
- `tools/generate_image.py`: Gemini画像生成スクリプト

**設計文書**
- `docs/GAME_DESIGN.md`: Single Source of Truth確立

### UI/UXワークフロー確立

**Designer Agent体制**
- `.claude/agents/designer.md`: Designer Agent定義
- `docs/meta/ui_workflow.md`: UI/UX実装ワークフロー（Designer → ui → checker → CEO）
- `docs/meta/agents.md`: Designer責務追加（事前企画・事後レビュー）
- UI基準6項目定義（3秒ルール/視線の一本化/状態の可視化/操作の最小化/配信映え/世界観の匂わせ）

### Phase 3 ショップ画面実装

**UI/UX企画書**
- `docs/design/ui/shop.md`: ショップ画面UI/UX企画書
- レイアウト構成（1280×720、タイトル/所持金/商品カード/リロール/戻る）
- 色彩設計（MaterialSelect.gd踏襲）
- UIコンポーネント詳細（商品パネル 220×320、フォントサイズ等）
- インタラクション設計（購入フロー・リロールフロー・状態変化）
- UI基準6項目全合格

**実装完了**
- `scripts/Shop.gd`: スタブから完全実装に置き換え
- 商品ランダム生成（ユニット・呪文・素材から3-5個）
- 購入処理（所持金チェック→減算→デッキ追加→UI更新）
- リロールシステム（50G消費→商品再生成）
- 状態管理（購入済み=赤背景、所持金不足=disabled）
- checker検証合格

---

## 2026-04-06

### ドキュメント
- スキル分類の用語を統一：「アクティブスキル」→「パッシブスキル」（CLAUDE.md / docs/game_spec.md / docs/card_database.md）
- 3レイヤー定義を「攻撃/サポート効果/パッシブスキル」に更新
- checker設計整合性チェック文言を「攻撃/サポート/パッシブスキル」に更新

## 2026-04-05

### 新システム
- 効果テーブルシステム導入（EffectDB.gd + EffectExecutor.gd）
- CardDB.gd による全カードデータ一元管理
- ユニット効果の3レイヤー構造定義（攻撃/サポート効果/アクティブスキル）
- skills配列構造標準化（trigger/target/effect_id/params）

### 新ユニット
- リッチ（狙撃+再起付与+魂の器）
- ヴリコラカス（バフ奪取+デバフ波及）

### バランス変更
- スケルトン：ATK4→2, SPD2→3s, サポート効果を再起付与→敵マナ妨害に変更, 自己再起を3秒遅延復活に
- ゴブリン：サポート効果を「隣接の獣ATKバフ」→「前のユニット1体ATKバフ」に変更
- バフスタック化：吸血(3%/スタック), 貫通(5%/スタック, 10で2マス波及), 鎧(被弾で-1), リジェネ(2秒ごと-1)
- 血の契約：HP30%代償（HP1未満にならない）+ 吸血10スタック付与
- サポート効果：前列では発動しない（中列・後列のみ）
- 狙撃/支援攻撃のスキル名称変更

### 開発者モード
- 左側デッキエディタ（ドラッグ追加/右クリック削除/シャッフル/全削除）
- カードホバー詳細パネル
- 本体HP回復ボタン3種
- ゲームオーバー無効化
- 一時停止でデッキ/マナ/時間経過スキルが停止

### バグ修正
- EnemyAIにdeckエイリアス追加（環境呪文フリーズ修正）
- 召喚時効果がドラッグ配置で未発動→修正
- 呪文ドラッグ時のside逆転防止
- _apply_regen_buffのnullアクセス修正
- preload→load変更（起動フリーズ修正）

### アーキテクチャ
- Agent体制更新（architect/data-sync新設）
- 盤面座標・対象範囲のMECE定義
- 召喚と復活の定義明確化
- _skill_timersにsupport_Nプレフィックスで定期サポート統合

---

## 2026-04-05（後半）

### アーキテクチャ（続き）
- BoardManager分割完了（CombatSystem.gd / SupportSystem.gd / TileSystem.gd / TickSystem.gd）
- 旧方式文字列パース（match文によるeffect_id文字列分岐）完全削除
- CardDBデータをJSON外出し（data/cards.json）
- load()キャッシュ化（同一リソースの重複ロード排除）
- GameUI.gd分離（Main.gdからUI構築ロジックを独立）

### 新システム
- アーティファクトシステム実装（永久スロット3 + 盤面スロット4）
- プレイヤークラス3種実装（召喚士 / 戦術家 / 錬金術師）
- 装備3種実装（武器 / 防具 / アクセサリ）
- ゲームスピード変更機能実装（0.5x / 1x / 2x）

### テスト
- TestRunner.gd によるテスト自動化基盤実装

### ユニット調整
- キングスライム：auto_promote対応（前列空きで自動昇格）

## 2026-04-18

### Phase 4 #21（#0c）SpellSlotSystem v2（キュー式）実装完了

**実装内容**（7a96ab6）
- 3スロット並列条件監視システム（v1既存機能維持）
- 右クリック破棄機能追加
  - SpellSlotSystem.gd: discard_slot()メソッド追加（Lines 305-316）
  - GameUI.gd: 右クリック検出実装（Lines 634-641）
- 発動条件満たした際の自動発動（v1既存機能）

**次タスク**
- Phase 4 #0系列（継続ウェーブ型転換）残タスク
  - #0: 残論点確定（pve_wave_pending_issues.md 11項目）
  - #0a: WaveManager実装
  - #0b: RestScreen実装
  - #0d: UnitReviveManager実装
  - #0e: 素材ドロップ判定ロジック
