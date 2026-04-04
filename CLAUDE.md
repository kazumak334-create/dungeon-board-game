# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## エージェント体制

### Agent一覧
| Agent | 役割 |
|---|---|
| ceo | 統括・振り分け |
| planning | 企画・仕様設計 |
| marketing | 市場調査・競合分析 |
| implementer | 機能実装 |
| ui | UI/UX実装（箱のみ） |
| checker | コード検証・修正 |
| pmo | 進捗管理 |
| pr | X・note投稿生成 |

全Agent：Sonnet統一

### 連携パターン
- A（仕様決定）：CEO → planning ←→ marketing → CLAUDE.md更新 → implementer
- B（実装）：CEO → implementer → checker → pmo → pr
- C（発信）：pmo → pr → ユーザー確認 → 投稿
- D（戦略）：marketing → planning → CEO → ユーザー報告

### 運用ルール
- 全指示はCEOを通す
- コード変更を伴う実装は全てchecker必須
- CLAUDE.md更新・ドキュメントのみの変更はchecker不要

### 現在のフェーズ
Phase 1・2.5合目
次のマイルストーン：効果システム・チェーン処理完成（3合目）

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

### Unit Effect Structure

Each `UnitData` carries two effect layers (data only; logic is future work):

| Layer | Field | Trigger types |
|-------|-------|--------------|
| サポート効果 | `support_effect: String` | 常時発動 / 召喚時 / 条件達成時 |
| アクティブスキル | `active_skill: String` | 命中時 / 撃破時 / HP閾値時 / 時間経過 / その他 |

- 旧「攻撃時効果」は **アクティブスキル（命中時）** に統合
- 効果の実装は未着手。フィールドはデータ保持専用

## GDScript Conventions

- Scripts use `class_name` declarations (`BoardManager`, `DeckManager`, `EnemyAI`, `UnitData`)
- `Main.gd` preloads scripts and instantiates via `Node.new()` + `set_script()` to avoid circular references
- `UnitData` uses `get_script().new()` in `clone()` for the same reason
