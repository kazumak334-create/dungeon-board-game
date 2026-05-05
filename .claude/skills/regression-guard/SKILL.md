---
name: regression-guard
description: Use before implementation or review to prevent repeating previously corrected mistakes. Reads lessons learned and checks the current task against past user corrections.
allowed-tools: Read Grep Glob Bash
---

# Regression Guard Skill

Your job is to prevent repeating mistakes that the user has already corrected.

## Required Inputs

Read:

- `docs/ai/LESSONS_LEARNED.md`
- `CLAUDE.md`
- `docs/ai/OPEN_ISSUES.md`

If `docs/ai/LESSONS_LEARNED.md` does not exist, create a recommendation to create it, but do not invent lessons.

## Procedure

### 1. Extract relevant lessons

Find lessons related to:

- current file type
- current feature area
- current task type
- user preferences
- past correction patterns

### 2. Convert lessons into constraints

For each relevant lesson, produce:

```text
Lesson:
- ...

Constraint for this task:
- ...

How I will verify:
- ...
```

### 3. Apply before implementation

Before making changes, explicitly state:

```text
## Regression Guard

Relevant past lessons:
- ...

Constraints applied:
- ...

Checks I will perform:
- ...
```

## Hard Rules

- Do not repeat a behavior listed as prohibited in `LESSONS_LEARNED.md`.
- If a user corrected terminology, preserve the corrected terminology exactly.
- If the user said "余計なことをするな", do not add interpretation, expansion, or unsolicited redesign.
- If a lesson conflicts with the current user request, follow the current explicit user request and note the conflict.
