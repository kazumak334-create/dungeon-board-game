# CHANGELOG

## [Unreleased]

### 2026-04-24 Claude Design → DesignerAgent 自動パイプライン実装

**新規ファイル:**
- `docs/design/handoff/README.md`: bundle受け取りフォルダの利用説明
- `docs/design/handoff/.gitkeep`: フォルダgit保持用
- `docs/design/handoff/processed/.gitkeep`: アーカイブフォルダgit保持用
- `.claude/hooks/claude_design_watcher.sh`: bundle検知 → DesignerAgent起動スクリプト
- `.claude/hooks/lib/handoff_adapter.sh`: bundle形式抽象化レイヤー（JSON/MD対応、API移行ポイント実装）

**変更ファイル:**
- `.claude/settings.local.json`: hooks セクション追加（UserPromptSubmit / Stop）
- `.gitignore`: `docs/design/handoff/.errors.log` と `docs/design/handoff/processed/` を除外

**設計:**
- `.bundle.json` または `.bundle.md` をドロップすると次のプロンプト送信時に自動処理
- jq未導入時はbundle全体をフォールバック転記
- API webhook化時の差し替えポイント2箇所をコメントで明記（watcher.sh + adapter.sh）

### 2026-04-07 Phase3基盤実装（GameSessionマップフィールド+bossesデータ+MapGenerator+Result遷移変更）

**変更ファイル:**
- `scripts/GameSession.gd`: map_data/race_theme/map_seed/current_act/current_node/completed_nodes/boss_candidates/selected_boss_id フィールド追加、reset()対応
- `data/cards.json`: bossesセクション追加（boss_beast_king/boss_slime_mother/boss_death_lord、Act1各種族テーマ）
- `scripts/CardDB.gd`: BOSSES変数追加、cards.json読み込み時に登録
- `scripts/MapGenerator.gd`: _generate_act()実装（横StS風、3レーンスタート、depth 2-4にevent強制・depth 3-5にshop強制、seed再現性確保）、validate_connectivity()実装（BFS連結検証）
- `scripts/Result.gd`: _on_continue()遷移先をDECK_PREP→MAP_SELECTに変更、run_depth加算をカード選択スキップ時も実行するよう移動
- `scripts/TestSession.gd`: テスト5件追加（map_fields/map_reset/seed_reproducibility/acts_count/bosses_count）

**設計:**
- MapGeneratorはseed再現性のため全RNG操作を`_rng`インスタンスに統一（pool.shuffle()禁止）
- bossesデータはAct2/3拡張を前提とした最小スケルトン（act/race_themeフィールドで将来のフィルタリングに対応）
- ボス候補選択はrace_theme一致→act一致→全体のフォールバック順

### 2026-04-07 段階5: 報酬システム（バトル中gold累積 + Result報酬パネル分離 + キャストゲージ下表示）

**変更ファイル:**
- `scripts/GameSession.gd`: `current_battle_gold`, `battle_drops` フィールド追加 + reset()対応
- `scripts/BoardManager.gd`: `unit_died` シグナルに `unit: Object` 引数追加（撃破ユニット情報引き継ぎ）
- `scripts/Main.gd`: `_on_unit_died` で敵撃破時に `cost × 5G × reward_multiplier` を累積。`last_result` に `battle_gold` フィールド追加
- `scripts/GameUIOverlay.gd`: キャストゲージ下に獲得通貨ラベル追加（プレイヤー側のみ）、`update_battle_gold_label()` メソッド追加
- `scripts/Result.gd`: 報酬パネルを独立エリア（`_build_reward_panel()`）に分離。カード3択を大きく（355×400）。撃破ドロップgold加算処理追加
- `scripts/TestSession.gd`: テスト4件追加（battle_gold累積/引き継ぎ/報酬フィールド/カード3択）

**設計:**
- gold計算はハードコードせず `battle_config.reward_multiplier` で倍率調整可能
- アイテムドロップ枠はPhase 3実装予定としてプレースホルダー表示
- `battle_drops` フィールドはPhase 3で活用予定（今回は枠のみ）

### CheckAgent：確認完了・修正なし — 2026-04-07 DeckPrep UI追加修正5項目検証

#### 検証内容: DeckPrep.gd(530行) / DeckPrepInfo.gd(623行) — 装備縦配置・合成カード化・詳細大型化・ホバー動作

**全10項目正常:**
1. EQUIP_SLOTS 6個固定（head/body/feet/accessory1/2/3）— 正常
2. 装備3行×2列配置 — 左サイドバー200px内に収まる（右端約151px）— 正常
3. create_mini_card_icon() 60×78px — ヘッダー帯+グラフィック+ステータス — 正常
4. _build_card_frame_header frame_h=175, 戻り値y+183 — 正常
5. mouse_filter: ミニカードSTOP / row_ctrl IGNORE / STATUS_SPELLS対応 — 正常
6. クロージャキャプチャ: icon_name/icon_x をローカル変数化済み — 正常
7. _build_synthesis_row 参照残りなし — 正常
8. R1/R7: EffectDB.display参照、ハードコードなし — 正常（フレーバーテキストはUI固有ラベル）
9. テスト: 1875件全パス / 0件失敗
10. R10警告: DeckPrepInfo.gd 623行・DeckPrepBoard.gd 562行（既存警告、今回変化なし）

### CheckAgent：確認完了・修正なし — 2026-04-07 DeckPrep UI修正10項目検証

#### 検証内容: DeckPrepInfo.gd新規分離 + DeckPrepBoard/DeckPrep修正 + テスト4追加

**制約チェック（最優先）:**
1. EQUIP_SLOTS 6個固定（head/body/feet/accessory1/2/3）— 変更なし — 正常
2. SIDEBAR_W=200, INFO_W=275 — 変更なし — 正常

**10項目実装確認:**
1. (項目1) セル内カード型（ヘッダー+イラスト枠+ステータス縦並び） — create_card_chip()で実装済み — 正常
2. (項目2) 自陣・敵陣ラベル完全削除 — _build_board_headersは存在せず、コメントにのみ「自陣行ラベル」記述 — 正常
3. (項目3) チェックボックス12px以上マージン+上部中央 — CELLS_START_Y=BOARD_Y+52(20+12+16+4)で確保済み — 正常
4. (項目4) 合成カード枠 — build_synthesis_section()でカード枠+ホバー対応 — 正常
5. (項目5) カード詳細右上カード枠 — _build_card_frame_header()でmini_name(枠内小)とname_lbl(左側大)を別親に配置（重複なし）— 正常
6. (項目6) 合成先ホバー表示 — _build_synthesis_row()でmouse_entered/exited接続 — 正常
7. (項目7) 合成素材ホバー表示 — 同上（base_name/card2_nameをhover_targetに渡す）— 正常
8. (項目8) ステータスパネル区切り線/余白 — グループ間sep ColorRect+12px余白実装済み — 正常
9. (項目9) 敵陣行ラベル非表示 — ri×3ループ内で敵陣ラベルを追加しない（コメントのみ）— 正常
10. (項目10) モンハン式持ち物 — _build_material_slot_mh()で所持>0のみ左上詰め、空スロットは_build_empty_slot() — 正常

**分離整合性:**
- _info.setup()が_build_info_lane()内で呼ばれている — 正常
- _info==nullチェック — _update_info_lane()冒頭で実施 — 正常
- DeckPrep.gdから_show_unit_info/_show_spell_info/_info_labelが削除済み — 正常

**重点検証:**
- CELLS_START_Y(95行)とtry_drop_at_mouse(459行)のby計算式が完全一致 — 正常
- _build_card_frame_headerのname_lbl(434行)はmini_name(403行)と別親・別用途 — 重複バグなし

**行数（R10）:**
- DeckPrep.gd: 529行（500超→分離済み検討中）
- DeckPrepBoard.gd: 562行（500超→分離検討要）
- DeckPrepInfo.gd: 486行（正常範囲）

**テスト:**
- 1875 passed / 0 failed（+15件、4テスト追加確認）— 正常
- 構文・インデント — ヘッドレス起動成功 — 正常

### CheckAgent：バトルループ通しテスト — 2026-04-07 静的検証+シナリオテスト追加

#### 静的検証結果

1. Title→MaterialSelect: class_idをGameSessionに保存し遷移 — 正常
2. MaterialSelect→DeckPrep: selected_deck/selected_material/placement_configを構築して遷移 — 正常
3. DeckPrep→Battle: go_to(BATTLE)のみ（battle_configはGameSession維持） — 正常
4. Battle→Result: game_over時にlast_resultを設定しSceneManager.go_to(RESULT) — 正常
5. Result→DeckPrep: _cleanup_battle_cards()でpersistence="battle"除去 → run_depth加算(カード選択時) → go_to(DECK_PREP) — 正常
6. 敗北時: タイトルへボタン→GameSession.reset()→go_to(TITLE) / もう一度ボタン→go_to(BATTLE) — 正常
7. battle_configリセット: reset()は呼ばれないがDEFAULT_BATTLE_CONFIGが初期値のため実害なし — 正常

#### 検出された既知の未実装（修正不要・報告のみ）

- selected_material.demerits（HP低下/マナリジェネ低下等）がバトル開始時に適用されていない（Main.gdにselected_material参照なし）
- last_resultの`turns`フィールドが常に0（未集計）
- run_depthはカードスキップ時に加算されない（設計上問題なし）

#### 追加テスト（TestSession.gd）

- シナリオ1: Title→MaterialSelect→DeckPrepのデータ引き継ぎ（class_id/素材/deck/config）
- シナリオ2: DeckPrep→Battle→Resultの1ラン（battle_config初期化/last_result設定/run_depth加算）
- シナリオ3: バトル終了後のpersistence="battle"カードクリーンアップ
- シナリオ4: Result→DeckPrep戻り時のデータ保持（gold/SP/class_id/placement_config）
- テスト結果: 1860 passed / 0 failed（+19件）

### CheckAgent：確認完了・修正なし — 2026-04-07 DeckPrep持ち物タブ実装検証

#### 検証内容: DeckPrep.gd 持ち物タブ（カテゴリフィルタ + 素材グリッド）

1. 装備スロット6個固定（head/body/feet/accessory1/2/3）— 変更なし — 正常
2. INV_TOTAL_SLOTS = 30 固定 — 正常
3. カテゴリID 4種 ["all","normal","cursed","consumable"] — 正常
4. グリッド 5列×6行、座標計算 8+145×5+10×4=773px ≤ 790px — 正常
5. CardDB.MATERIALS 経由取得、ハードコードなし (R1/R7準拠) — 正常
6. カテゴリフィルタロジック（all/normal/cursed/consumable分岐）— 正常
7. 解説レーン更新（クリック→選択→表示、呪い素材ラベル、タブ切替リセット）— 正常
8. R10チェック — 727行（500-800範囲内）、次回機能追加前に分離検討
9. テスト全パス — 1841件 / 0 failed（TestDeckPrepLayout 7テスト含む）— 正常
10. 構文・インデント — ヘッドレス起動成功 — 正常

### CheckAgent：確認完了・修正なし — 2026-04-07 DeckPrepレイアウト（パターンB）検証

#### 検証内容: DeckPrep.gd パターンB（左サイドバー型）レイアウト

1. 制約違反チェック — EQUIP_SLOTS 6個固定・ID ["head","body","feet","accessory1","accessory2","accessory3"] — 正常
2. レイアウト座標（全定数） — 仕様通り — 正常
3. 装備スロット2×3配置（55×55px/ギャップ8px/行1=頭胴足/行2=アクセ1-3） — 正常
4. 旧定数参照（STATUS_H/EQUIP_ROWS等） — 残存なし — 正常
5. R1適合（_build_equipment_slot内ハードコードなし） — 正常
6. テスト全パス — 1827件 / 0 failed（TestDeckPrepLayout含む） — 正常
7. 構文・インデント — ヘッドレス起動成功 — 正常

### CheckAgent：確認完了（要手動確認あり）— 2026-04-07 TestRunner分離検証

#### 検証内容: TestRunner.gd R10分離（835行→62行）

静的検証（全項目OK）:
1. `run(runner: RefCounted)`シグネチャ — 全6ファイル統一済み
2. `self._assert_true`誤用なし — 全て引数`r`経由で正しく呼び出し
3. TestRunner.gd run_all()が全6ファイルをload().new().run(self)で呼ぶ構造 — OK
4. 構文・インデント — タブインデント統一、スペースインデント0件 — OK
5. テスト関数35個が6ファイルに責務分離済み — 漏れなし
6. static 209件のアサーション定義 + DBエントリ数依存のループアサーションで1813件相当と推定

要手動確認（Bash実行権限なし）:
- ヘッドレス実行 `godot4 --path . --headless --script scripts/RunTests.gd` でテスト件数1813件・全パスを確認する

### CheckAgent：確認完了・修正なし — 2026-04-07

#### 検証内容: battle_config辞書の実装
- `GameSession.gd`: DEFAULT_BATTLE_CONFIG 17キー全定義・型・デフォルト値正常
- `GameSession.gd`: reset()でduplicate(true)による深いコピー正常
- `Main.gd`: _apply_battle_config()がbase_hp/MANA_REGEN/check_interval/_battle_timer/_battle_timer_activeに正しく流し込み済み
- `Main.gd`: const BATTLE_TIME_LIMIT参照なし（全ファイルで削除済み確認）
- `Main.gd`: _on_battle_timeout()の"win"/"draw"/"lose"3パターン分岐正常
- `TestRunner.gd`: 新規4件（battle_config_default/reset/time_limit/custom_hp）正しく実装済み
- 二重管理なし: battle_configから各マネージャへの一方向流し込み設計が正しく維持
- 構文・インデント整合性: 全変更ファイル正常
- R10警告: TestRunner.gdが835行（分離必須閾値800行超）。次機能追加前に分離必要。分離候補: TestBattleConfig.gd / TestDBIntegrity.gd

#### 検証内容: バトル画面の不要ボタン削除 + Result画面整備
- `Main.gd`: restart_button参照なし（変数宣言・メソッド・参照すべて削除済み）確認
- `GameUI.gd`: restart_button生成ブロックなし、game_over_labelのsize/center alignment設定済み確認
- `Result.gd`: 敗北時「もう一度挑戦」のSceneManager.BATTLE定数使用・定数定義済み確認
- 構文・インデント整合性: 全変更ファイル正常
- R8（ハードコード禁止）: 盤面効果可視化はEffectDBから取得済み、match文直書きなし
- テスト: _test_battle_timer()追加済み（3件、TestRunner.gd 760-776行）確認

### refactor: バトル画面UI全面リデザイン — 2026-04-06

#### 変更ファイル
- `scripts/GameUI.gd` — 陣営/行ラベル削除、列アイコンヘッダー追加、セル中央揃え
- `scripts/GameUIOverlay.gd` — キャラパネルを盤面全体高さに拡張、縦3段デッキ情報VBox追加
- `scripts/GameUIQueue.gd` — Q1/Q2/Q3を列X座標に揃え配置、Q1光り枠・Q2/Q3グレーアウト

#### 変更内容
- 「自陣」「敵陣」「上」「中」「下」テキストラベルを全削除
- 列ヘッダーをUnicodeアイコン（自陣: 🏹🚩⚔ / 敵陣: ⚔🚩🏹）に変更
- キャラパネル: BOARD_TOP起点・高さ3×CELL_H=285pxに拡張、全ゲージをパネル内に収める
- デッキ情報: 横並びラベルを廃止→縦3段（山札=茶/捨て=灰/除外=黒紫）、数字のみ表示
- キューカード: Q1=前列位置（大・光り枠）、Q2=中列（やや小・グレーアウト）、Q3=後列（小・グレーアウト）
- Overlayに`_deck/discard/exile_count_labels`フィールド追加、Queueから毎フレーム更新
- ロジック変更なし（テスト全パス）

### refactor: GameUI.gd R10分割（1136行→3ファイル） — 2026-04-06

#### 変更ファイル
- `scripts/GameUI.gd` — 551行（メイン・盤面描画・デリゲート）
- `scripts/GameUIQueue.gd` — 292行（新規: キュー+デッキ情報UI）
- `scripts/GameUIOverlay.gd` — 350行（新規: キャラパネル・装備・ホバー・ダメージフロート）

#### 変更内容
- ロジック変更なし、ファイル分割のみ
- Main.gdへの外部インターフェース（spawn_damage_float等）はGameUI.gdのデリゲートで維持
- GameUIQueue/Overlay は `extends RefCounted`、setup時にmain/_EDB参照を注入
- GameUI.gd build_ui()内で `_overlay.build()` / `_queue.build()` を呼ぶ構成

### feat: バトル画面UI改善 — 2026-04-06

#### 変更ファイル
- `scripts/GameUI.gd` — 7項目のUI改善を実装

#### 変更内容
1. 環境表示: 画面上部に `GameSession.base_environment` の表示名を追加
2. セル内HPバー: `render_cell()` でColorRectのHPバー（背景+前景）とHP数値ラベルを表示。HP>50%=緑/20-50%=黄/<20%=赤
3. マナバー改善: 格子表示廃止→横長ゲージ（ColorRect）+「3.0 / 3（上限3）」テキスト。色は青→黄でグラデーション
4. ダメージフロート改善: `spawn_damage_float()` でamount=0の時は非表示
5. 一時停止ボタン: `_build_speed_buttons()` に⏸/▶トグルボタンを追加。`main.game_paused` をトグル
6. 列ラベル・行ラベル: 既存実装を維持（build_ui内に実装済み）
7. セル表示改善: ユニット名 + ATK + デバフ行 + HPバー（ColorRect）の構成に変更

### feat: cards.jsonの全エントリにrarityフィールドを追加 — 2026-04-06

#### 変更ファイル
- `data/cards.json` — units/spells/status_spells/system_spells/artifactsの全エントリに`rarity`フィールドを追加（`anim`の直後に配置）

#### レアリティ内訳
- units: common×5, uncommon×8, rare×15, epic×5, legend×4, god×2
- spells: common×6, uncommon×11, rare×5, epic×2, legend×1
- status_spells: common×4
- system_spells: common×1
- artifacts: epic×7

### refactor: シーン名文字列リテラルをSceneManager定数参照に置換 — 2026-04-06

#### 変更ファイル
- `scripts/SceneManager.gd` — go_to_battle内の"battle"をBATALLE定数に変更
- `scripts/BossReward.gd` — "deck_prep" → SceneManager.DECK_PREP
- `scripts/DeckPrep.gd` — "map_select"/"title" → SceneManager.MAP_SELECT/TITLE
- `scripts/Event.gd` — "map_select"×2 → SceneManager.MAP_SELECT
- `scripts/Gather.gd` — "map_select" → SceneManager.MAP_SELECT
- `scripts/Main.gd` — "result" → SceneManager.RESULT
- `scripts/MaterialSelect.gd` — "title"/"deck_prep" → SceneManager.TITLE/DECK_PREP
- `scripts/MapSelect.gd` — "deck_prep"/"battle"×3 → SceneManager.DECK_PREP/BATTLE
- `scripts/Result.gd` — "boss_reward"/"deck_prep"/"title" → SceneManager定数
- `scripts/Shop.gd` — "map_select" → SceneManager.MAP_SELECT
- `scripts/Title.gd` — "material_select"/"battle" → SceneManager.MATERIAL_SELECT/BATTLE

### refactor: EffectExecutor.gd を3ファイルに分割（R10対応） — 2026-04-06

#### 変更ファイル
- `scripts/EffectExecutor.gd` — エントリポイントのみ残存（103行）。match文を`_actions.do_*()`呼び出しに変換
- `scripts/EffectTargets.gd` — 新規作成。ターゲット解決ロジック（281行）
- `scripts/EffectActions.gd` — 新規作成。effect type実行関数群（724行）

#### 変更概要
960行のEffectExecutor.gdをR10ルール（800行超で分離必須）に従い3ファイルへ分割。
ロジックの変更は一切なく、移動のみ。

### CheckAgent — 2026-04-06: 修正2件

#### 対象ファイル
- scripts/Title.gd
- scripts/Main.gd
- scripts/DeckManager.gd
- scripts/GameSession.gd
- scripts/SceneManager.gd
- scripts/DeckPrep.gd
- scripts/MapSelect.gd（新規スタブ）

#### 検証結果

- Title.gd: ✅ 開発者モードボタン・テスト実行ボタン追加正常。_on_dev_mode_pressedでGameSession.dev_mode=trueをセットしてbattle遷移。正常。
- GameSession.gd: ✅ dev_modeフィールド宣言・reset()での初期化あり。正常。
- SceneManager.gd: ✅ map_selectパス追加済み。正常。
- DeckPrep.gd: ✅ 「マップへ」ボタンでmap_select遷移。正常。
- MapSelect.gd: ✅ スタブとして最低限の構造。正常。
- Main.gd: ❌ 廃止済み `mode_select_panel: Control = null` 変数が残存 → 削除。_build_mode_selectはGameSession.dev_mode分岐で正常動作確認。_check_game_overはgame_overフラグで二重遷移防止済み。
- DeckManager.gd: ❌ STATUS_SPELLSブロックでcard_typeが "spell" のまま → "status_spell" に修正。錬金術師コスト軽減・status_spell専用処理が正常適用される。

### CheckAgent — 2026-04-06: 確認完了・修正なし

#### 対象ファイル
- scripts/DeckPrep.gd（新規）
- scripts/Result.gd（新規）
- scripts/SceneManager.gd
- scripts/GameSession.gd
- scripts/MaterialSelect.gd
- scripts/Main.gd
- scenes/DeckPrep.tscn（新規）
- scenes/Result.tscn（新規）

#### 検証結果
- GDScript構文・インデント: 全ファイル問題なし
- SceneManagerパス名とtscnの一致: deck_prep/result/battle 全て一致
- GameSession.reset(): 全9フィールド（materials/gold/skill_points含む）リセット確認
- Autoload参照（GameSession/SceneManager）: 全画面で正しく参照
- nullアクセス危険箇所: なし
- _transition_to_result_timer: create_timer(process_always=true)のため game_over 後も正常動作、二重呼び出しなし
- tscnスクリプトパス: DeckPrep.tscn/Result.tscn 共に正しいパスを参照
- MaterialSelect 遷移先: battle→deck_prep 変更済み確認

### Fixed — 2026-04-06: CheckAgent: Title.gd / MaterialSelect.gd EffectDB参照キー修正

#### scripts/Title.gd
- `_edb.DB.get()` を `_edb.EFFECTS.get()` に修正（EffectDBの定数名は `EFFECTS`、`DB` は存在しない）

#### scripts/MaterialSelect.gd
- `_edb.DB.get()` を `_edb.EFFECTS.get()` に修正（同上、2箇所）

### Added — 2026-04-05: data/cards.json ユニット18体追加

#### data/cards.json
- unitsセクションにアンデッド系5体追加：レヴナント・ワイト・シャドウ・デュラハン・デスナイト
- unitsセクションに獣系6体追加：コカトリス・ケットシー・マンティコア・キリン・ビャッコ・グリフォン・フェンリル
- unitsセクションに企画済み新ユニット7体追加：ソウルイーター・リッチキング・ストームホーク・フェンリスウルフ・ゾンビの手・ホブゴブリン
- 全18体のskillsは空配列（将来実装用予約）

### Added — 2026-04-05: GameSession.gd + SceneManager.gd 実装・cards.jsonクラスデータ拡充

#### scripts/GameSession.gd（新規）
- Autoload用ランデータ保管クラス
- `class_id`, `selected_deck`, `last_result`, `run_depth`, `artifacts_acquired` フィールド
- `reset()` で全フィールドを初期値に戻す

#### scripts/SceneManager.gd（新規）
- Autoload用画面遷移管理クラス
- `_scenes` 辞書でシーン名→パスを管理（未作成シーンはnull）
- `go_to(scene_name)` でnullチェック・ロード失敗チェック付きシーン遷移
- `go_to_battle(class_id)` でGameSession.class_idをセットしてバトルへ遷移

#### data/cards.json
- classes の alchemist・berserker・necromancer に `description`（クラス説明文）と `initial_deck`（初期デッキカード名配列）を追加

### Perf — 2026-04-05: load()キャッシュ化（6ファイル）

#### SupportSystem.gd / TileSystem.gd / CombatSystem.gd
- `var _EDB = null` フィールド追加、`setup()` 内で1回だけ `load("res://scripts/EffectDB.gd")` を実行
- `apply_support_effects()`・`set_tile_effect()`・`check_tile_on_enter()`・`check_tile_on_leave()`・`process_tile_effects()`・`_do_attack()`・`_apply_class_skills()` 内のローカルload()を削除してフィールド参照に置換

#### DeckManager.gd / EnemyAI.gd
- `var _EDB / _CardDB / _UnitDataScript = null` フィールド追加、`_ready()` 内でキャッシュ
- `_build_default_deck()`・`ensure_shuffle_card()`・`process_deck()`・`process_ai()` 内のload()をすべてフィールド参照に置換

### Added — 2026-04-05: バトル完成6件修正（ゲームスピード・棘・合成スキル・ターゲット拡張・race_buff・合成バフ引き継ぎ）

#### Main.gd
- `game_speed: float = 1.0` フィールド追加
- `_process()` 内に `effective_delta = delta * game_speed` を導入し、deck/ai/combatの各processに適用
- `_on_synthesis_done()` に on_synthesis trigger スキル（錬金術師パッシブ: 合成時マナ+N）の発火ロジックを追加

#### DevUI.gd
- ツールボタン行の後に速度ボタン行（x0.5 / x1 / x2 / x4）を追加
- `_on_set_speed(speed: float)` 新規追加：main.game_speed を更新

#### EffectDB.gd
- `tile_fire`（炎床 on_tick 3dmg）を `tile_thorn`（棘 on_enter 5dmg）に置き換え

#### TileSystem.gd
- `check_tile_on_enter()` に `on_enter` かつ `damage` フィールドを持つ盤面効果のダメージ処理を追加（棘対応）

#### EffectExecutor.gd
- `_resolve_target()` に 4種のターゲット指定子を追加: `ally_undead_lowest` / `enemy_most_buffs` / `front_enemy` / `adjacent_enemy`
- `race_buff` typeのpassブランチを実装（種族フィルタ＋atk_pctによる_atk_bonus付与）

#### BoardManager.gd
- `_execute_synthesis()` のバフコピーに 8フィールドを追加: `lifesteal_stacks` / `_kill_atk_bonus` / `_stolen_atk` / `_stolen_spd` / `_stolen_lifesteal` / `_stolen_penetrate` / `_stolen_regen` / `_stolen_armor`

### Added — 2026-04-05: クラススキルロジック実装 + PlayerData統合 + DevUIクラス選択

#### BoardManager.gd
- `player_data: RefCounted` フィールド追加（Main.gd が設定）
- `place_unit()` に死霊術師パッシブ「アンデッドHP+10%」適用ロジックを追加（EffectDB type="hp_pct_buff" 判定）

#### SupportSystem.gd
- `apply_support_effects()` 内でプレイヤークラススキル適用を呼び出す処理を追加
- `_apply_class_skills()` 新規追加：バーサーカーの前列SPD+20%（spd_pct_buff）・HP50%以下全ATK+3（conditional_buff）を適用

#### DeckManager.gd
- `process_deck()` 内に錬金術師パッシブ「異常状態カードコスト-1」ロジックを追加（EffectDB type="cost_modifier" 判定）

#### EffectExecutor.gd
- クラススキル4種（cost_modifier / spd_pct_buff / conditional_buff / hp_pct_buff）のpassブランチを match 文に追加

#### Main.gd
- `_ready()` 内でPlayerData生成（デフォルト: バーサーカー）、DeckManager/BoardManagerに反映
- `_on_unit_died()` に死霊術師パッシブ「味方死亡時マナ+1（最大10回）」フックを追加

#### DevUI.gd
- カードリストにクラス選択セクション追加（CardDB.CLASSESから動的生成）
- `_on_class_select()` 新規追加：クラス変更時にPlayerData再生成・BoardManager/DeckManagerへ即時反映

### Fixed — 2026-04-05: CheckAgent確認・R8ハードコード修正

#### DeckManager.gd
- `process_deck()` のマナ妨害処理を `"スケルトン"` ユニット名直書きから EffectDB type="mana_drain" を持つスキルのユニット数カウントに変更（R8準拠）
- `mana_regen_boost` effect_id 直書きを EffectDB type="mana_regen_modify" 判定に変更（R8準拠）
- 未使用変数 `_EDB_regen` を実際に使用する形に修正（チェック項目15）

#### EnemyAI.gd
- `process_ai()` のマナ妨害処理を `"スケルトン"` ユニット名直書きから EffectDB type="mana_drain" を持つスキルのユニット数カウントに変更（R8準拠）

#### EventQueue.gd
- `base_damage` 処理の `"base_damage_reduce"` effect_id 直書きを EffectDB type="base_damage_reduce" 判定に変更（R8準拠）
- インデント崩れを修正（`_EDB_ev` を for ループ外に移動）

### Added — 2026-04-05: アーティファクトシステム基盤実装

#### EffectDB.gd
- `tile_grave`: 盤面効果（on_tick/3s間隔・スケルトン召喚）を追加
- `mana_regen_boost`: type="mana_regen_modify" 永久効果型アーティファクト用
- `base_damage_reduce`: type="base_damage_reduce" 本体ダメージ軽減
- `summon_to_empty`: type="summon_to_empty" ランダム空きマス召喚

#### CardDB.gd
- ARTIFACTS辞書を新規追加（永久効果型3種 + 盤面出現型4種）
  - 永久効果型: 加速の石板/速攻の刃/守護の紋章
  - 盤面出現型: 戦旗/呪いの祭壇/召喚門/王墓の石碑
- 全エントリにtexture/anim/sfxフィールド含む

#### BoardManager.gd
- `board_artifacts[side][row][col]` フィールド追加・_setup()で初期化
- `player_artifacts` / `enemy_artifacts` 配列フィールド追加（永久効果型管理）
- `place_artifact()` / `remove_artifact()` 関数追加
- `place_unit()` にアーティファクト排他チェック追加
- `_push_artifact_summon_effects()` / `_execute_artifact_skill()` ヘルパー追加
- `_apply_support_effects()` にアーティファクトのalwaysスキル処理追加
- `_apply_permanent_artifact_effects()` 追加（永久効果型のfront_ally_all ATKバフ等）
- `_process_artifact_timers()` 追加（timerスキル1秒ごと処理）
- `_on_status_tick()` から `_process_artifact_timers()` を呼び出し
- `set_tile_effect()` に protect_tiles チェック追加（`_is_protected_by_artifact()`）
- `_process_tile_effects()` の on_tick に summon_unit 処理追加
- `_summon_unit_to_random_empty()` ヘルパー追加

#### EffectExecutor.gd
- `_resolve_target` に `adjacent_8` / `front_ally_all` / `random_empty_ally` 追加
- `tile_set` type に target="adjacent_8" 対応（隣接マスのみへの盤面効果設置）
- `mana_regen_modify` / `base_damage_reduce` / `summon_to_empty` type 追加

#### EventQueue.gd
- `base_damage` 処理に永久効果型アーティファクトの `base_damage_reduce` 軽減を組み込み

#### DeckManager.gd
- `process_deck()` に `player_artifacts` の `mana_regen_boost` 反映を追加

#### DevUI.gd
- `_build_all_cards()` に ARTIFACTS 追加
- アーティファクト（盤面）/アーティファクト（永久）セクションをカード一覧に追加
- `_build_card()` にアーティファクト用ブランチ追加
- `_normal_play()` / `_manual_place()` にアーティファクト配置処理追加
- `_on_card_hover()` にアーティファクト詳細表示追加

#### Main.gd
- `_render_cell()` にアーティファクト描画追加（金色系背景・名前+HPバー表示）
- `_update_cells()` にアーティファクトセルの常時再描画フラグ追加
- `_on_cell_hover()` にアーティファクト情報ツールチップ追加

### Added — 2026-04-05: CardDB全エントリにtexture/anim/sfxフィールド追加

#### CardDB.gd
- UNITS全21エントリ（スライム系12・アンデッド系5・獣系4）に `"texture": "", "anim": "", "sfx": ""` を追加
- SPELLS全25エントリに同フィールドを追加
- STATUS_SPELLS全4エントリに同フィールドを追加
- SYSTEM_SPELLS（シャッフル）に同フィールドを追加
- 既存の値・skillsの中身は変更なし

### Added — 2026-04-05: 盤面効果（Tile Effect）基盤実装

#### EffectDB.gd
- 盤面効果7種を追加（tile_curse/tile_fire/tile_beast_forest/tile_fortress/tile_crack/tile_poison/tile_hole）
- type="tile_effect" で統一、trigger/display/効果パラメータを定義

#### BoardManager.gd
- board_effects: Array フィールド追加（board と同構造 [side][row][col]）
- _setup() で board_effects を初期化
- set_tile_effect(side, row, col, effect_id, duration) / clear_tile_effect() 追加
- _check_tile_on_enter()：鉄壁の地（鎧付与）処理
- _check_tile_on_leave()：ヒビ→穴への変形処理
- _process_tile_effects()：1秒ごとの持続時間管理・炎床ダメージ・毒沼スタック付与
- place_unit()：穴による召喚ブロックチェック、on_enter 発火
- remove_unit()：on_leave 発火
- _try_promote()：移動元 on_leave → 移動先 on_enter 発火
- _do_attack()：呪われた地によるダメージ×1.5
- _apply_support_effects()：獣の森による ATKボーナス付与
- 飛行ユニット（_is_flying=true）は全盤面効果を無視

#### DevUI.gd
- _pending_tile_effect フィールド追加
- 盤面効果ボタンセクション追加（EffectDB から動的生成）
- on_drop() に盤面効果設置モード追加
- _on_tile_effect_select() / _on_tile_effect_clear() コールバック追加

#### Main.gd
- _render_cell()：盤面効果の色オーバーレイ可視化（lerp ブレンド）
- _on_cell_hover()：盤面効果情報をツールチップに表示、ユニット不在でも表示
- _update_cells()：盤面効果があるセルは常に再描画

### CheckAgent — 2026-04-05: 盤面効果（Tile Effect）基盤チェック
- 修正あり：DevUI.gd `_manual_place()` にて `_check_tile_on_enter` の呼び出しが欠落していたため追加（453行目付近）
- 他13項目は正常

### CheckAgent — 2026-04-05: CardDB一元化＋サポート効果位置制限チェック
確認完了・修正なし（全16項目）

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

---

### CheckAgent：確認完了・修正なし — 2026-04-05: テスト項目#12-#17コードレベル検証

#### 検証結果

**#12 リッチの後列攻撃（狙撃）**
- _apply_support_effectsでskills[always]→EffectExecutor→skill_flagでフラグ設定: 正常
- process_combatの後列攻撃でunit._back_target_rearをtarget_rear引数に渡している: 正常
- _do_attack内で_get_rearmost_col呼び出しへの分岐: 正常

**#13 リッチの後列攻撃で命中時スキル非発動**
- _back_no_on_hitがtrueの場合skip_on_hit=trueで_push_on_hit_effectsをスキップ: 正常

**#14 リッチの魂の器（撃破時）**
- skills[on_kill]→EffectExecutor→revive_ally処理: 正常
- active_skill=""のため旧方式"魂の器"チェックは非発動（二重発動なし）: 正常

**#15 ヴリコラカスのバフ奪取（命中時）**
- skills[on_hit]→EffectExecutor→steal_buffs→bm._steal_buffs呼び出し: 正常
- _steal_buffsでlifesteal_stacks/penetrate_stacksの移動: 正常
- active_skill=""のため旧方式"バフ奪取"チェックは非発動（二重発動なし）: 正常

**#16 グールのATK累積（撃破時+2・上限10）**
- skills[on_kill]→EffectExecutor→atk_permanent: _kill_atk_bonusを加算・cap=10で上限チェック: 正常
- active_skill=""のため旧方式"ATK累積"チェックは非発動（二重発動なし）: 正常

**#17 バンシーの全体ATK低下（時間経過15s）**
- _init_skill_timersでtrigger=="timer"のindex3を"timer_3"キーで登録: 正常
- _process_timed_skillsで減算・0以下でEffectExecutor経由発火・インターバルリセット: 正常
- EffectExecutor all_enemy_debuffでburn_turnsを加算: 正常
- active_skill=""のため旧方式タイマーは非発動: 正常

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
