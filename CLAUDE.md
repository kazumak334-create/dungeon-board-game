# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## エージェント体制

### Agent一覧
| Agent | 役割 | 担当範囲 |
|---|---|---|
| ceo | 統括・振り分け | ユーザー指示の解釈、Agent間調整 |
| planning | 企画・仕様設計 | ゲームデザイン、カード企画、バランス |
| marketing | 市場調査・競合分析 | 競合ゲーム分析、差別化戦略 |
| architect | ゲーム基盤設計・実装 | 効果システム、イベントキュー、データ構造、BoardManager核 |
| implementer | カード・呪文の個別実装 | カードデータ追加、スキルロジック、SpellExecutor |
| data-sync | 仕様⇔コード同期 | card_database.md更新、DevUI/DeckManager/EnemyAIデータ一致保証 |
| ui | UI/UX実装 | 画面レイアウト、表示系 |
| checker | コード検証・修正 | バグ検出、品質保証 |
| pmo | 進捗管理 | CHANGELOG、進捗レポート |
| pr | X・note投稿生成 | 発信コンテンツ作成 |

全Agent：Sonnet統一

### 連携パターン
- A（仕様決定）：CEO → planning ←→ marketing → data-sync（仕様書更新）
- B（基盤変更）：CEO → architect → checker
- C（カード追加）：CEO → implementer → data-sync → checker
- D（仕様変更後の同期）：CEO → data-sync（card_database.md/CLAUDE.md/DevUI/DeckManager/EnemyAI全同期）
- E（発信）：pmo → pr → ユーザー確認 → 投稿
- F（戦略）：marketing → planning → CEO → ユーザー報告

### Agent間連携ルール（後戻り削減）

**CEO → implementer:**
- 実装指示に「CLAUDE.mdの該当セクション」を明示引用する
- 新規ファイルはCEOがWriteでスケルトン作成→implementerにEdit実装
- 影響範囲（変更するファイル）と変更しないファイルを明記
- EffectDB/CardDBのデータ追加とロジック実装は別タスクに分ける

**implementer → checker 引き継ぎ:**
- 「何を実現するためのコードか」（設計意図）を含める
- 変更したファイル一覧と各ファイルの変更概要
- 新規追加したeffect_id/target/triggerのリスト

**checker 検証フレームワーク（3段階）:**

1. **「何を実現すべきか」を理解する（最重要）**
   - implementerからの引き継ぎで設計意図を把握する
   - CLAUDE.mdの該当セクションを必ず読み、実装が設計定義と矛盾しないか突合する
   - 「このコードは正しく動くか」ではなく「このコードは正しいことをしているか」を問う

2. **「データとロジックが分離されているか」を検証する**
   - DB（EffectDB/CardDB）に定義すべきものがコードにハードコードされていないか
   - 新カード/効果を追加した時にコード変更が必要になる書き方をしていないか
   - grep: match文の条件にDB定義済みID、Color()リテラル、日本語文字列がないか

3. **「壊れていないか」を検証する（従来のチェック）**
   - 構文/インデント/nullアクセス/Godot互換性

**planning → implementer:**
- 新効果提案時に「既存EffectDBのどのtypeで実現可能か」を明記
- 新typeが必要な場合は理由と代替案を併記

**data-sync タイミング:**
- implementer完了後、checker前に実行（card_database.md/cards.json/CLAUDE.md 3点同期）

### 運用ルール
- 全指示はCEOを通す
- コード変更を伴う実装は全てchecker必須
- CLAUDE.md更新・ドキュメントのみの変更はchecker不要
- 仕様変更後は必ずdata-syncを実行（ズレ防止）
- architectとimplementerの境界：共通基盤=architect、個別カード/呪文=implementer

### Agent品質基準（全Agent必読）

**CEO:**
- リファクタリングと新機能追加を同一タスクに混ぜない。基盤変更→コミット→機能追加の順
- 1コミット=1目的。「AとBとCをまとめて」を安易に投げない
- 実装指示には必ず「影響範囲」と「変更しないファイル」を明記する
- 新規ファイルが必要な場合はCEOがWriteでスケルトン作成→implementerにEdit実装を振る

**architect:**
- 新機能追加前に既存ファイルの肥大化を確認する。500行超のファイルには追加前に分割を検討
- 新しいデータ構造を追加する際は、既存構造との排他/共存ルールを明記する
- EventQueueの優先度変更は影響範囲を全列挙してから実施する

**implementer:**
- 1タスク=1機能。複数機能を混ぜない
- DB定義（EffectDB/CardDB）のデータ追加とロジック実装を分けてコミットする
- 新effectを追加する前に既存effectの組み合わせで実現できないか必ず確認する（R2）
- match文を書く前に「新しいカード追加時にこのmatch文に分岐追加が必要か？」を自問する。YESならDBに移す

**checker:**
- 構文チェック: GDScriptのインデント整合性を全変更ファイルで検証する
- nullアクセスパターン: `board[s][r][c]`の後にnullチェックなしでプロパティアクセスしている箇所を全探索
- ハードコード検出: 変更ファイルのmatch文をgrepし、EffectDB/CardDBに定義済みのIDが条件にあればNG
- Godot互換性: `Object.get()`の引数数、`preload`と`load`の使い分けを確認
- 旧方式残存: support_effect/active_skillの文字列パースが新規追加されていないか確認
- **設計整合性（最重要）**: 変更がCLAUDE.mdの3レイヤー定義（攻撃/サポート/パッシブスキル）と矛盾しないか検証。特に「位置制限」「発動条件」が設計書と一致しているか

**data-sync:**
- コード変更後にcard_database.md/CLAUDE.mdとの差分を全チェック
- CardDB.gdの定義とcard_database.mdの記載が一致しているか検証
- 新フィールド追加時はcard_database.mdにも定義を反映

**planning:**
- 新効果・新カードを提案する際はtexture/anim/sfxの想定を記述する
- 既存のtrigger/target/effect_idで表現できるか確認してから新typeを提案する
- UI表示への影響（セル表示、ホバー、DevUI）を提案に含める

### 現在のフェーズ
Phase 2・5合目（画面遷移+デッキ構築フェーズ）
次のマイルストーン：クラス選択→バトル→結果の画面ループ完成

## Running the Game

```bash
godot4 --path .
```

To run headless (e.g., for CI):
```bash
godot4 --path . --headless
```

## Project Overview

Godot 4.6 (GDScript) real-time board card game prototype. 1280×720, Forward Plus renderer.

**Concept:** Player and enemy each control a 3×3 grid. Front-row units attack automatically. Player uses an auto-cycling deck with an energy system; enemy AI spawns units on a timer.

## Architecture

All game logic runs through `_process` in `Main.gd`, which manually calls into each manager each frame — there are no Godot `_process` overrides in the subsystems.

```
Main.gd          — UI construction, game loop orchestration, signal handlers
BoardManager.gd  — 3×3×2 board state, unit placement, combat resolution
DeckManager.gd   — Player deck cycling, energy regen, card auto-play
EnemyAI.gd       — Timed enemy unit spawning from a shuffled deck
UnitData.gd      — RefCounted value object; clone() resets HP on placement
```

### Board Layout

- `side 0` = player (left), `side 1` = enemy (right)
- `board[side][row][col]` — row 0–2 (top/mid/bot), col 0–2
- Player: col 2 = front (center side), col 0 = back
- Enemy: col 0 = front (center side), col 2 = back
- **Front-col units attack**; when front is empty the next available col is targeted (`_get_frontmost_col`)
- `_try_promote` moves mid-col (col 1) → front-col when front is empty (called every frame + on death)

### 盤面座標と対象範囲の定義

```
          col0(後列)  col1(中列)  col2(前列)  ← プレイヤー側
row0(上段)  [0,0]      [0,1]      [0,2]
row1(中段)  [1,0]      [1,1]      [1,2]
row2(下段)  [2,0]      [2,1]      [2,2]
```

**プレイヤー向け表記**: 深さ=「前列/中列/後列」(col)、高さ=「上段/中段/下段」(row)

**対象範囲定義（MECE）**:

| 定義名 | 意味 | コード関数 |
|--------|------|-----------|
| 自身 | 自分のマスのみ | — |
| 隣接 | 上下左右4方向 | `get_adjacent(row, col)` |
| 同段 | 同じrow（横ライン3マス） | `get_same_row(row)` |
| 同深度 | 同じcol（縦ライン3マス） | `get_same_col(col)` |
| 前列 | 同深度のうちfront col限定 | `get_same_col(front_col)` |
| 後列 | 同深度のうちback col限定 | `get_same_col(back_col)` |
| 全体 | 味方or敵の全9マス | `get_all(side)` |

- 「前列」「後列」は「同深度」のフィルタ（特定colに固定した同深度）
- 斜めは全パターンで含まない
- 種族フィルタ（獣のみ等）は対象範囲と直交する別軸で指定

### Key Signals (BoardManager)

- `unit_placed(side, row, col, unit)` — after successful placement
- `unit_died(side, row, col)` — after removal
- `base_damaged(side, amount)` — when front row attacks with no target

### Mana & Deck Loop (DeckManager)

- Mana regenerates at 1.0/s up to max 10
- Every `check_interval` seconds (default 1.0s), if `mana >= deck[0].cost` the card is played and moved to `discard`
- When `deck` is empty, `discard` is shuffled back into `deck` (infinite cycling)
- `get_next_card()` peeks `deck[0]` without consuming

### Enemy AI (EnemyAI)

- Spawns from a 9-card shuffled deck every 3.5s (sequential draw, not random)
- Played cards go to `enemy_discard`; when empty, discard is reshuffled into deck
- `get_next_card()` returns the pre-selected top-of-deck card for UI display

### ユニット効果の3レイヤー構造

全ユニットは「攻撃」「サポート効果」「パッシブスキル」の3レイヤーを持つ。
攻撃とサポート効果は**盤面位置で排他的に切り替わる**。パッシブスキルは位置無関係。

| レイヤー | 発動位置 | 全ユニット共通？ | 説明 |
|---------|---------|----------------|------|
| **攻撃** | 前列のみ（原則） | 全ユニット | 前列にいれば自動攻撃 |
| **サポート効果** | 中列・後列のみ（原則） | 全ユニット | 前列以外にいれば自動発動 |
| **パッシブスキル** | 位置無関係 | 任意（持たないユニットもいる） | 条件を満たせば発動 |

**原則と例外（スキルが例外を作る）:**
- 原則: 前列=攻撃モード、中列/後列=サポートモード
- 例外スキル「狙撃」: 後列から攻撃可能
- 例外スキル「支援攻撃」: 中列+後列から攻撃可能
- 前列に繰り上がったユニットのサポート効果は**自動停止**

**パッシブスキルのトリガー:**
命中時 / 撃破時 / HP閾値時 / 時間経過 / 召喚時 / 死亡時

### skillsエントリ構造（ユニット・呪文共通）

```
{
  "trigger":   "always",           # いつ発動するか
  "target":    "front_one",        # 誰に効くか（対象範囲）
  "effect_id": "atk_buff_apply",   # 何が起きるか（EffectDB参照）
  "params":    {"stacks": 2},      # 数値パラメータ（効果の強さ等）
  "delay":     0.0                 # 発動遅延秒数（省略=即時）
}
```

**trigger一覧:**

| trigger | 意味 | ユニット | 呪文 |
|---------|------|---------|------|
| `always` | 常時発動（サポート効果） | ○ | — |
| `on_summon` | 召喚時 | ○ | — |
| `on_hit` | 命中時 | ○ | — |
| `on_kill` | 撃破時 | ○ | — |
| `on_death` | 死亡時 | ○ | — |
| `on_hp_threshold` | HP閾値時 | ○ | — |
| `timer` | 時間経過N秒 | ○ | — |
| `on_play` | カード使用時 | — | ○ |

**target一覧:**

| target | 意味 |
|--------|------|
| `self` | 自分自身 |
| `front_one` | 自分の前のマス1体 |
| `adjacent` | 上下左右4方向 |
| `same_row` | 同段（同じrow） |
| `same_col` | 同深度（同じcol） |
| `same_row_beast` | 同段の獣のみ |
| `same_col_ally` | 同深度の味方 |
| `random_front_ally` | 前列味方ランダム1体 |
| `random_ally` | 味方ランダム1体 |
| `single_ally` | 味方1体（戦略的選択） |
| `all_allies` | 味方全体 |
| `all_enemies` | 敵全体 |
| `all_front` | 両陣営の前列全体 |
| `enemy_random_col` | 敵ランダム列 |
| `ally_max_atk` | ATK最大の味方1体 |
| `self_deck` | 自分のデッキ |
| `enemy_deck` | 敵のデッキ |

### 効果カテゴリ定義

| カテゴリ | 特徴 | 時間経過 | 例 |
|---------|------|---------|-----|
| **バフ** | スタック式、数値で強さが変わる | 2秒ごと-1 | ATKバフ、吸血、貫通 |
| **デバフ** | スタック式、数値で強さが変わる | 毎秒-1（毒は永続） | 火傷、凍結、麻痺、毒 |
| **スキル** | ON/OFF、永続的な能力 | 消えない | 飛行、後列攻撃、再起 |

#### バフ一覧（スタック+2秒ごと-1）

| 名前 | フィールド | スタック効果 | 10スタック時ボーナス |
|------|----------|------------|-------------------|
| ATKバフ | `atk_buff` | ATK+1/スタック | 上限10 |
| SPDバフ | `spd_buff` | 攻撃間隔-0.1s/スタック | — |
| 吸血 | `lifesteal_stacks` | 回復率3%/スタック | 回復率30% |
| 貫通 | `penetrate_stacks` | ダメージ波及5%/スタック | 2マス後ろまで波及 |
| 鎧 | `armor_stacks` | 被ダメ-10%/スタック、被弾で-1 | 被ダメ-100% |
| リジェネ | `regen_stacks` | 2秒ごとHP5%×スタック回復 | — |

- サポート効果由来: 常時発動中は2秒ごとにスタック補充（減少と補充が均衡）
- 呪文/スキル由来: 一回付与→時間で減少
- 召喚時付与系（吸血付与・貫通付与等）: N秒ごとにスタック付与に変更

#### デバフ一覧（スタック+毎秒-1）

| 名前 | フィールド | 効果 | 特記 |
|------|----------|------|------|
| 火傷 | `burn_turns` | ATK低下（逓減max80%） | 毎秒-1 |
| 凍結 | `frozen_turns` | SPD低下（逓減max50%） | 毎秒-1 |
| 麻痺 | `paralysis_turns` | 行動不能 | 毎秒-1、上限3秒 |
| 毒 | `poison_stacks` | 毎秒スタック数dmg | 永続（自然減少なし） |

#### スキル一覧（永続ON/OFF）

**攻撃の例外スキル（後列/中列から攻撃可能にする）:**

| 名前 | 効果 | 発動位置 |
|------|------|---------|
| 狙撃 | 後列から敵最後列を優先攻撃、命中時アクティブ発動なし | 後列のみ |
| 支援攻撃 | 後列+中列から敵を攻撃 | 後列+中列 |

**その他のスキル:**

| 名前 | 効果 | 付与条件 |
|------|------|---------|
| 飛行 | 盤面効果（環境呪文等）を受けない | ユニット固有 |
| 再起 | HP1で1度だけ復活 | サポート効果 or 自己スキル |
| 自己再起 | 3秒後に同段空きマスでHP5復活（1回限り） | パッシブスキル |

### 召喚と復活の定義

| 概念 | シグナル | 召喚時効果 | 盤面合成 | サポート再計算 |
|------|---------|-----------|---------|--------------|
| **召喚** | `unit_placed` | 発動する | 判定する | する |
| **復活** | `unit_revived` | 発動しない | 判定しない | する |

- 復活はあくまで「盤面に戻る」だけ。新規ユニットとして扱わない
- 遅延復活（スケルトン等）は死亡→N秒後に同段空きマスに配置

### タイマー管理（_skill_timers統合方式）

`UnitData._skill_timers`にパッシブスキルとサポート効果の定期発動を統合管理：
- `"timer_N"` — パッシブスキルの時間経過（N=skills配列インデックス）
- `"support_N"` — サポート効果の定期発動（N=skills配列インデックス）
- 発火時にサポート効果は前列チェックを実施（前列なら発動しない）

### 将来拡張ポイント（実装予定・構造のみ把握）

**プレイヤークラスシステム:**
- 3クラス: 錬金術師(スライム)/バーサーカー(獣)/死霊術師(アンデッド)
- PlayerData.gd: class_id, initial_mana, mana_max, mana_regen, skills, equipment
- クラスパラメータ: 初期マナ統一(3)、マナ上限はクラスで異なる(8/10/12)
- クラススキル: パッシブのみ（skills配列で定義、trigger/target/effect_id）
- 装備: 将来実装（枠のみ）
- スキルツリー: 将来実装（枠のみ）
- 廃止: 本体HP/防御力、デッキ上限、アーティファクトスロット制限

**アーティファクトシステム:**
- 2タイプ：永久効果型（デッキ外・常時発動）＋ 盤面出現型（盤面配置・パッシブスキルのみ）
- 盤面出現型はユニットと排他（同マスに共存不可。マスを何に使うかが戦略判断）
- `board_artifacts[side][row][col]`で管理（boardとは別レイヤー、排他チェック）
- 盤面効果の影響を受けない（ユニットではないため）
- HPあり・破壊可能。ATK0/SPD0（攻撃しない）
- アーティファクトが召喚したユニットは通常ユニットとしてboardに乗る
- EventQueue.PRIORITY_ARTIFACT（優先度5）は定義済み

**盤面効果（ロックマンエグゼ式）:**
- `board_effects[side][row][col]`でマス単位の効果レイヤー
- 種族強化フィールド / バフ・デバフ付与 / 召喚制限 / ダメージ床
- 飛行スキルで無視

### 残論点（今後実装時に決定）

- **盤面効果の発動条件**: 呪文で設置？ユニットスキルで設置？ステージ固有？全パターン対応予定
- **呪い・透明化**: デバフ/バフとして将来実装。現時点ではカード定義にeffect_idなしで登録
- **board_effects構造**: `board_effects[side][row][col]`で盤面効果レイヤーを管理予定。飛行スキルで無視

### 画面遷移設計

**画面フロー:**
```
Title（クラス選択）
  → MaterialSelect（素材選択・初回のみ）
  → DeckPrep（デッキ準備・ハブ画面）
  → [マップ選択（将来）]
  → Battle → Result（報酬）→ DeckPrep に戻る
```

**Autoload構成:**
- `SceneManager`: 全画面遷移を一元管理（scripts/SceneManager.gd）
- `GameSession`: ランデータの一時保管（scripts/GameSession.gd）

**画面一覧:**

| シーン名 | パス | 状態 |
|---------|------|------|
| TOP/クラス選択 | res://scenes/Title.tscn | 実装済み |
| 素材選択 | res://scenes/MaterialSelect.tscn | 実装済み |
| デッキ準備 | res://scenes/DeckPrep.tscn | スタブ |
| バトル | res://scenes/Main.tscn | 実装済み |
| バトル結果 | res://scenes/Result.tscn | スタブ |
| マップ選択 | 未定 | 未実装 |
| ショップ | 未定 | Phase 3 |
| イベント | 未定 | Phase 3 |

**素材選択システム（初回のみ）:**
- 固定デッキ（base_deck: 全種族基本ユニット+呪文）+ クラス固有1枚
- 素材プール15個（通常10+呪い5）からランダム3つ提示 + 「運命に委ねる」（4択目）
- 通常素材: デメリットなし・効果控えめ
- 呪いの素材: 強効果+ペナルティ（スレスパのボス遺物方式）
- 「運命に委ねる」: 完全ランダム・デッキプレビュー不可

**マップ構造（将来実装）:**
- スレスパ風の分岐ツリーマップ（自動生成）
- ノード種別: 戦闘 / エリート / 素材採集 / ショップ / イベント / ボス
- 休憩ノードなし（デッキ準備画面が兼ねる）
- 環境はマップ上で事前に見える（ルート選択の判断材料）

**環境システム（二層構造）:**

最終環境 = ベース環境 + 環境変化（上書き）

| レイヤー | スコープ | 変更タイミング |
|---------|---------|-------------|
| ベース環境 | ボス区間全体共通（全バトル同じ） | ルート生成時（固定）、イベント（稀） |
| 環境変化 | 自陣 or 敵陣の片方 | 消費アイテム / 装備 / クラススキル |

- ベース環境は両陣営に等しく影響
- 環境変化はベース環境のマスを上書き（自陣だけ獣の森にする等）
- 能動的な環境変更は原則不可。消費アイテム/特定装備/クラススキルのみ

環境一覧（既存盤面効果のみ使用・新規盤面効果は作らない）:

| 環境ID | 表示名 | 盤面効果 |
|--------|--------|---------|
| env_none | 平原 | 盤面効果なし |
| env_curse | 呪われた地 | tile_curse 1〜9マスランダム配置 |
| env_crack | ヒビ割れ荒野 | tile_crack ランダム配置 |
| env_thorn | 棘地帯 | tile_thorn ランダム配置 |
| env_poison | 毒沼 | tile_poison ランダム配置 |
| env_fortress | 鉄壁の砦 | tile_fortress ランダム配置 |
| env_beast | 獣の森 | tile_beast_forest ランダム配置 |

**バトル報酬構成:**
- スキルポイント（固定）
- 通貨（敵に応じた金額）
- 素材 or カード（ランダム）

**遷移時のデータ引き継ぎ（GameSession）:**
- class_id: 選択クラスID
- selected_deck: デッキ配列（base_deck + クラス固有 + 素材ボーナス）
- selected_material: 選択した素材データ
- materials: 所持素材（バトル報酬で蓄積）
- gold: 通貨
- skill_points: スキルポイント
- last_result: バトル結果{win, player_hp_remaining, turns}

### 素材システム設計

**基本方針:**
- 素材はバトル前のデッキ準備画面で使う。使い切り強制ではなく持ち越し可能
- バトル中に「素材」という概念は存在しない。バトルに持ち込むのは装備・クラススキル・カードのみ
- 素材の入手はバトル報酬（ランダム）

**バトル報酬構成:**
- スキルポイント（固定）
- 通貨（敵に応じた金額、アルゴリズム後日検討）
- 素材 or カード（ランダム）

**素材の用途（MECE・全パターン）:**

| カテゴリ | パターン | 説明 |
|---------|---------|------|
| **生産** | 直接生産 | 素材→完成品（装備等） |
| **生産** | 段階生産 | 素材→中間素材→上位装備 |
| **生産** | カード合成 | 素材+素材→カード |
| **生産** | 上位カード合成 | カード+素材→上位カード |
| **生産** | ランダム再ロール | 素材+既存品→ランダム性能 |
| **生産** | 分解 | 完成品→素材に戻す |
| **生産** | 素材交換 | 素材A→素材B |
| **生産** | 複製 | 素材→素材×N |
| **消費** | 即時効果 | 薬草→HP回復等 |
| **消費** | コスト支払い | 素材→ゲート解除 |
| **消費** | イベントトリガー | 特定素材→ボス召喚等 |
| **消費** | 戦闘投擲 | 素材→敵へダメージ/デバフ |
| **消費** | 環境設置 | 素材→盤面効果配置 |
| **経済** | 売却 | 素材→通貨 |
| **経済** | 納品 | クエスト/交易完了 |
| **経済** | 通貨兼用 | 素材自体が交換媒介 |
| **経済** | サービス購入 | 素材→NPCサービス |
| **解放** | 永続パッシブ | 素材→キャラ永続強化 |
| **解放** | デッキ除去 | 素材消費でカード削除 |
| **解放** | 品質乗数 | 素材品質→製品品質 |
| **解放** | スキルポイント取得 | 素材→スキルツリー進行 |
| **解放** | フェーズ遷移 | 特定素材→次章解放 |
| **知識** | コレクション | 図鑑埋め・実績 |
| **知識** | 条件充足 | レシピ/クエスト達成条件 |
| **時間** | ストック管理 | 所持上限・スロット消費 |
| **時間** | 劣化 | 時間経過で品質低下 |

**実装優先度:**

| 優先度 | パターン |
|--------|---------|
| MVP | 即時消費、カード合成、装備合成、デッキ除去 |
| Phase 2 | 上位カード合成、段階生産、素材交換、イベントトリガー |
| Phase 3 | 売却、スキルポイント取得 |
| 保留 | カード+カード合成（圧縮+強化が同時で強すぎる懸念） |

**デッキ除去ルール:**
- プレイヤーが手動選択で除去（ランダムではない）
- 除去コスト = 素材消費（気軽に連発できない制約）
- 枚数制限なし（プレイヤーの自由）
- シャッフルカードのみ除去不可（システム保護）

**カード合成ツリー:**
- カード強化は独立システムにしない。合成ツリーの枝として表現する
- 素材+素材→カード、カード+素材→上位カード
- カード+カード合成はバランス次第で保留（圧縮が同時に起きるため）

**素材データ構造（cards.json）:**

```json
"materials": {
  "herb": {
    "display": "薬草",
    "description": "回復の力を秘めた草",
    "is_cursed": false,
    "usages": [
      {"type": "consume", "display": "HP+20回復", "effect_id": "heal_base", "params": {"amount": 20}},
      {"type": "convert_card", "display": "回復呪文を追加", "result_card": "生命の雫"}
    ]
  }
}
```

## モジュール設計の実装ルール（全Agent必読）

### 原則：効果は独立したモジュールとして設計する

1つの効果（effect）= 1つの責務。複合的な動作が必要な場合は、**複数のeffectをskills配列で並べて実現する**。1つのeffect内に複数の責務を混ぜない。

```
# 悪い例：1つのeffectにシャッフルと再挿入を混ぜる
"shuffle_deck": シャッフルして、自カードを山札最下部に再挿入する

# 良い例：2つの独立effectを並べる
skills: [
    {effect_id: "shuffle_deck"},     # 山札をシャッフルするだけ
    {effect_id: "deck_add_self", params: {position: "bottom"}},  # 自カードを最下部に追加
]
```

### ルール一覧

**R1. effectロジック内でユニット名・カード名をハードコードしない**
- NG: `if unit_name == "スライム"` をeffect内に書く
- OK: CardDB.SYNTHESISなど既存データの関係性から自動導出する

**R2. 新effectを作る前に「既存effectの組み合わせで実現できないか」を確認する**
- 既存effectにパラメータを追加するだけで解決できるなら新effectは作らない
- 例: deck_add_selfにpositionパラメータを追加→top/bottom/randomを切り替え可能に

**R3. effectのパラメータは汎用的に命名する**
- NG: `slime_hp`, `skeleton_delay`（ユニット固有名）
- OK: `stacks`, `factor`, `delay`, `position`, `unit_id`（汎用名）

**R4. カード種別（card_type）とカード属性（is_consumable/persistence等）は独立**
- 消費＝異常状態カードではない。呪文でも消費型はある
- 将来の属性: 山札戻し、敵デッキ移動なども想定
- **persistence（カード存続期間）:**

| 値 | 意味 | 例 |
|---|---|---|
| `"permanent"` | 通常カード（デフォルト。省略時はpermanent扱い） | 全ユニット、通常呪文 |
| `"battle"` | バトル終了後にデッキから自動除去 | 異常状態カード（毒/凍結/火傷/麻痺） |
| `"run"` | ラン中ずっと引き継がれる（除去困難） | 呪いカード（将来実装） |

- `is_consumable`は「使用時に消滅」、`persistence`は「バトル/ラン終了時の存続」。直交する別軸
- バトル終了後のデッキクリーンアップ: `persistence == "battle"` のカードを `selected_deck` から除去

**R5. trigger/target/effect_idの3軸でスキルを定義する**
- skills配列の各エントリは必ず `{trigger, target, effect_id, params}` の構造
- 複合動作は複数エントリで表現。1エントリ=1効果

**R6. EffectDBのdisplay名を必ず定義する**
- 新effectを追加する際は必ず `"display": "日本語名"` を含める
- UIが内部IDを直接表示することを禁止

**R7. データ定義は CardDB に一元管理する**
- ユニット/呪文/異常状態/システムカード/合成レシピ/デッキ構成は全てCardDB.gd
- DeckManager/EnemyAI/DevUI/Main.gdはCardDBを参照するだけ
- 同じデータを複数ファイルに書かない

**R8. UI表示文字列・色・条件分岐はマスタ/DBから取得する（ハードコード絶対禁止）**
- NG: `match tile_id: "tile_curse": rect.color = Color(0.8, 0.2, 0.6)` のような直書き
- NG: `match tile_id: "tile_fire": tile_info = "炎床3dmg/s"` のような直書き
- OK: `var color = tile_def.get("color", [])` でDBから取得
- OK: `var label = tile_def.get("unit_label", "")` でDBから取得
- **判定基準**: そのmatch文に新しいeffect/カード追加時に分岐追加が必要？→ YES ならDBに移す
- **checker必須**: 変更ファイルのmatch文にDB定義済みIDが条件にあればNG判定する

**R8.1 標準化基準（何を定数/共通化すべきか）**

標準化する（定数・共通関数・DBに移す）:
- **同じ値が3箇所以上**で使われ、変更時に全箇所直す必要があるもの
- **typoするとバグになる**識別子（シーン名、effect_id、DB ID等）
- **データとして増減する**値（カード名、効果名、素材名等）→ DB管理
- **全画面共通の色・レイアウト定数** → UIFactory定数

標準化しない（コード内にハードコードでOK）:
- **画面固有のUIラベル**（「続ける」「戻る」等）→ 文脈依存、1-2箇所のみ
- **画面固有のレイアウト座標** → その画面でしか使わない
- **変更頻度が低い固定値** → ローカライズ時にi18nシステムで対応

判断フロー:
1. 3箇所以上で同じ値？→ YES: 定数化
2. typoでバグ？→ YES: 定数化（例: シーン名→SceneManager定数）
3. 増減するデータ？→ YES: DB管理（例: カード→CardDB）
4. 全画面共通の見た目？→ YES: UIFactory（例: 背景色→UIF.BG_COLOR）
5. 上記全てNO → ハードコードでOK

現在の標準化済みリソース:
- シーン名: `SceneManager.TITLE`, `SceneManager.BATTLE` 等（定数）
- UI色: `UIFactory.BG_COLOR`, `UIFactory.TITLE_COLOR` 等（定数）
- ゲームデータ: CardDB（Autoload）、EffectDB（静的辞書）
- UI共通パーツ: `UIFactory.add_bg()`, `add_title()`, `add_button()` 等

**R9. EffectDB/CardDBの定義には将来拡張フィールドを含める**
- 新しいeffect/カードを定義する際は`texture`, `anim`, `sfx`フィールドを空文字で含める
- コード側はこれらが空ならフォールバック（color等）を使い、値があればそちらを優先する
- 企画Agentは新効果提案時にアニメーション/SE/テクスチャの想定を記述する

**R10. ファイル肥大化ルール: 500行超で分離検討、800行超で分離必須**
- 新機能追加前にwc -lで確認する
- 500行超: 次の機能追加前に分離を検討し、CEOに報告
- 800行超: 機能追加を中断し、先に分離を実施する
- 分離先は責務ごと（Combat/Support/Tick/Tile等）に切り出す

**R11. pushルール: テスト全パス+動作確認済みの区切りでpush。壊れた状態ではpushしない**

**R12. replace_all使用後はインデント検証を必ず行う**
- GDScriptはインデントが構文の一部。replace_allでインデントが壊れるとパースエラー
- 置換後に前後5行のインデントを確認する

**R13. 構造レビュー自動トリガー**

以下の条件に該当したとき、CEOは機能実装を一時停止し構造レビューを実施する：

| トリガー | 閾値 | アクション |
|---------|------|----------|
| ファイル行数 | 500行超のファイルが新たに発生 | R10に従い分離検討 |
| load()呼び出し | 同一リソースのload()が5箇所以上 | Autoload化またはキャッシュ検討 |
| 画面数増加 | 新画面追加時 | SceneManager定数追加・遷移テスト追加 |
| データ構造変更 | GameSessionフィールド追加時 | reset()更新・テスト追加・責務肥大化チェック |
| UI重複 | 3画面以上で同じUIパターン | UIFactory関数追加 |
| テスト失敗 | 1件でもfail | 機能実装を停止しfix優先 |
| コミット粒度 | 1コミットに3ファイル以上の変更 | 分割できないか確認 |
| ペルソナ不合格 | 8人中5人以上が×or△ | 実装前にUI/設計を見直し |

**レビュー実施タイミング:**
- 大機能の実装完了後（DeckPrep、バトルシステム変更等）
- 5コミット以上が溜まった時
- ユーザーから「構造大丈夫？」と聞かれる前に自主的に

**レビュー内容:**
1. wc -l で全ファイル行数チェック
2. grep で重複パターン検出（load()、Color()リテラル、同一UIパターン）
3. GameSessionのフィールド数とreset()の整合性
4. テスト実行（全パスを確認）

## GDScript Conventions

- Scripts use `class_name` declarations (`BoardManager`, `DeckManager`, `EnemyAI`, `UnitData`)
- `Main.gd` preloads scripts and instantiates via `Node.new()` + `set_script()` to avoid circular references
- `UnitData` uses `get_script().new()` in `clone()` for the same reason
