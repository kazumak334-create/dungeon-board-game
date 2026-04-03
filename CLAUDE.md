# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
- **Only col 0 units participate in combat** — `process_combat` always checks `board[side][row][0]`

### Key Signals (BoardManager)

- `unit_placed(side, row, col, unit)` — after successful placement
- `unit_died(side, row, col)` — after removal
- `base_damaged(side, amount)` — when front row attacks with no target

### Energy & Deck Loop (DeckManager)

- Energy regenerates at 1.0/s up to max 10
- Every `check_interval` seconds (default 1.0s), if `energy >= deck[0].cost`, the card is played and re-queued at the back
- `get_next_card()` peeks `deck[0]` without consuming

### Enemy AI (EnemyAI)

- Spawns a random unit from its shuffled deck every 3.5s
- No energy system — pure timer-based

## GDScript Conventions

- Scripts use `class_name` declarations (`BoardManager`, `DeckManager`, `EnemyAI`, `UnitData`)
- `Main.gd` preloads scripts and instantiates via `Node.new()` + `set_script()` to avoid circular references
- `UnitData` uses `get_script().new()` in `clone()` for the same reason
