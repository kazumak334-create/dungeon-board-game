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

### 運用ルール
- 全指示はCEOを通す
- コード変更を伴う実装は全てchecker必須
- CLAUDE.md更新・ドキュメントのみの変更はchecker不要
- 仕様変更後は必ずdata-syncを実行（ズレ防止）
- architectとimplementerの境界：共通基盤=architect、個別カード/呪文=implementer

### 現在のフェーズ
Phase 1・4合目（効果システム基盤設計中）
次のマイルストーン：効果テーブルシステム完成 → カード全実装

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

全ユニットは「攻撃」「サポート効果」「アクティブスキル」の3レイヤーを持つ。
攻撃とサポート効果は**盤面位置で排他的に切り替わる**。アクティブスキルは位置無関係。

| レイヤー | 発動位置 | 全ユニット共通？ | 説明 |
|---------|---------|----------------|------|
| **攻撃** | 前列のみ（原則） | 全ユニット | 前列にいれば自動攻撃 |
| **サポート効果** | 中列・後列のみ（原則） | 全ユニット | 前列以外にいれば自動発動 |
| **アクティブスキル** | 位置無関係 | 任意（持たないユニットもいる） | 条件を満たせば発動 |

**原則と例外（スキルが例外を作る）:**
- 原則: 前列=攻撃モード、中列/後列=サポートモード
- 例外スキル「狙撃」: 後列から攻撃可能
- 例外スキル「支援攻撃」: 中列+後列から攻撃可能
- 前列に繰り上がったユニットのサポート効果は**自動停止**

**アクティブスキルのトリガー:**
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
| 自己再起 | 3秒後に同段空きマスでHP5復活（1回限り） | アクティブスキル |

### 召喚と復活の定義

| 概念 | シグナル | 召喚時効果 | 盤面合成 | サポート再計算 |
|------|---------|-----------|---------|--------------|
| **召喚** | `unit_placed` | 発動する | 判定する | する |
| **復活** | `unit_revived` | 発動しない | 判定しない | する |

- 復活はあくまで「盤面に戻る」だけ。新規ユニットとして扱わない
- 遅延復活（スケルトン等）は死亡→N秒後に同段空きマスに配置

### タイマー管理（_skill_timers統合方式）

`UnitData._skill_timers`にアクティブスキルとサポート効果の定期発動を統合管理：
- `"timer_N"` — アクティブスキルの時間経過（N=skills配列インデックス）
- `"support_N"` — サポート効果の定期発動（N=skills配列インデックス）
- 発火時にサポート効果は前列チェックを実施（前列なら発動しない）

### 残論点（今後実装時に決定）

- **盤面効果の発動条件**: 呪文で設置？ユニットスキルで設置？ステージ固有？全パターン対応予定
- **呪い・透明化**: デバフ/バフとして将来実装。現時点ではカード定義にeffect_idなしで登録
- **board_effects構造**: `board_effects[side][row][col]`で盤面効果レイヤーを管理予定。飛行スキルで無視

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

**R4. カード種別（card_type）とカード属性（is_consumable等）は独立**
- 消費＝異常状態カードではない。呪文でも消費型はある
- 将来の属性: 山札戻し、敵デッキ移動なども想定

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

**R8. replace_all使用後はインデント検証を必ず行う**
- GDScriptはインデントが構文の一部。replace_allでインデントが壊れるとパースエラー
- 置換後に前後5行のインデントを確認する

## GDScript Conventions

- Scripts use `class_name` declarations (`BoardManager`, `DeckManager`, `EnemyAI`, `UnitData`)
- `Main.gd` preloads scripts and instantiates via `Node.new()` + `set_script()` to avoid circular references
- `UnitData` uses `get_script().new()` in `clone()` for the same reason
