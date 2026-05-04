---
description: Run the standard Godot/GDScript project checks
---

# Godot Check

Run the project checks in this order and summarize only actionable output:

1. `bash check_syntax.sh`
2. If Godot MCP is connected, run `mcp__godot__godot_health_check`.
3. If the task touched data files, run `python -m json.tool data/cards.json`.

Report:

- pass/fail status
- first failing file and line if available
- whether the failure is from the current change or pre-existing worktree state
- the next concrete fix

Do not claim the game is visually correct from syntax checks alone.
