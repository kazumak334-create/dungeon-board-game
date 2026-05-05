---
name: inspect-first
description: Use before any implementation, bug fix, code review, architecture judgment, or analysis. Forces Claude to inspect actual repository files before making claims or decisions.
allowed-tools: Read Grep Glob Bash
---

# Inspect First Skill

You must not analyze or implement from memory, guesses, or assumptions.

## Purpose

Before any judgment, implementation, refactor, or bug fix, establish the actual current state of the repository.

## Mandatory Steps

### 1. Read project rules

Read these files if they exist:

- `CLAUDE.md`
- `docs/ai/LESSONS_LEARNED.md`
- `docs/ai/TASK_LOG.md`
- `docs/ai/VERIFICATION_LOG.md`
- `docs/ai/OPEN_ISSUES.md`
- relevant design docs under `docs/`

If a file does not exist, state that explicitly.

### 2. Locate relevant files

Use `Glob`, `Grep`, or `Bash` to find relevant files.

Recommended commands:

```bash
find . -maxdepth 4 -type f | sed 's#^\./##' | sort | head -300
grep -R "TARGET_KEYWORD" -n . --exclude-dir=.git --exclude-dir=.godot --exclude-dir=addons
git status --short
```

### 3. Inspect actual implementation

Read the relevant files before making any claim.

Do not say:
- "probably implemented in..."
- "likely handled by..."
- "this should be..."

Instead say:
- "I confirmed in `path/to/file.gd` that..."
- "I could not find implementation of..."
- "The current code does X, but the requested behavior is Y."

### 4. Produce current-state summary

Before proposing changes, output:

```text
## Current State

FACT:
- [file path] confirmed behavior

INFERENCE:
- Reasoned interpretation based on confirmed code

UNKNOWN:
- Anything not yet verified

## Gap

Requested:
- ...

Current:
- ...

Gap:
- ...
```

## Stop Condition

If you have not inspected the relevant files, stop and inspect them.
Do not proceed to implementation.
