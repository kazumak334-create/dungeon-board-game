# Dungeon Board ClaudeCode Plugin Plan

Last updated: 2026-05-02

Goal: package repeatable ClaudeCode workflow pieces so they can be reused across branches or future Godot projects.

## Proposed Plugin

Name: `dungeon-board-workflow`

Components:

- `commands/session-start.md`
- `commands/godot-check.md`
- `commands/econ-next.md`
- `commands/bugfix-flow.md`
- `commands/pmo-update.md`
- `agents/godot-debugger.md`
- `agents/gdscript-checker.md`
- optional `hooks/post-edit-check.sh`

## Local Marketplace Shape

```text
.claude-plugin/marketplace.json
plugins/dungeon-board-workflow/.claude-plugin/plugin.json
plugins/dungeon-board-workflow/commands/
plugins/dungeon-board-workflow/agents/
plugins/dungeon-board-workflow/hooks/
```

## Install Flow

In ClaudeCode:

```text
/plugin marketplace add C:\Users\kazum\dungeon-board-game
/plugin install dungeon-board-workflow@dungeon-board-local
```

Restart ClaudeCode after installation.

## Current Status

The repo-local plugin scaffold has been created. The same commands and agents also exist directly under `.claude/` so they can be used immediately without installing the plugin.

Use the project-local files first during active development. Install the plugin when you want to test the packaged workflow or share it with another checkout.
