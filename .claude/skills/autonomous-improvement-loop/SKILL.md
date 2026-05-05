---
name: autonomous-improvement-loop
description: Use for any non-trivial implementation, bug fix, refactor, review, or project maintenance task. Runs the full inspect, guard, implement, verify, log, and learn loop.
allowed-tools: Read Grep Glob Bash Edit
---

# Autonomous Improvement Loop Skill

Use this skill for any non-trivial implementation, bug fix, review, refactor, or project maintenance task.

The purpose is to prevent assumption-based work and create a reusable improvement loop.

## Core Principle

Do not rely on memory, guesses, filenames, or inferred behavior.

Every decision must be grounded in:

- actual files
- actual logs
- actual diffs
- actual command output
- explicit user instructions

Separate:

- FACT
- INFERENCE
- UNKNOWN

## Loop Overview

Run the following loop for every non-trivial task:

1. Load rules and lessons
2. Check recurrence risks
3. Inspect current state
4. Identify the exact gap
5. Plan minimal change
6. Implement
7. Verify
8. Record task result
9. Record verification result
10. Update lessons if needed
11. Report remaining uncertainty

---

# Step 1. Load Rules and Lessons

Read these files if they exist:

- `CLAUDE.md`
- `docs/ai/LESSONS_LEARNED.md`
- `docs/ai/TASK_LOG.md`
- `docs/ai/VERIFICATION_LOG.md`
- `docs/ai/OPEN_ISSUES.md`

If any file does not exist, create it only if needed for this task.

Before doing anything else, summarize relevant constraints:

```text
## Loaded Constraints

Relevant project rules:
- ...

Relevant past lessons:
- ...

Potential recurrence risks:
- ...
```

---

# Step 2. Inspect Current State

Use `Read`, `Grep`, `Glob`, and `Bash`.

Minimum checks:

```bash
git status --short
find . -maxdepth 4 -type f | sort | head -300
```

Then locate task-relevant files.

Do not implement before reading the relevant files.

Output:

```text
## Current State

FACT:
- Confirmed from `path/to/file`

INFERENCE:
- Reasoned from confirmed facts

UNKNOWN:
- Not yet verified
```

---

# Step 3. Identify Gap

Compare the user request with the current state.

Output:

```text
## Gap Analysis

Requested:
- ...

Current:
- ...

Gap:
- ...

Out of scope:
- ...
```

---

# Step 4. Minimal Change Plan

Before editing, produce:

```text
## Minimal Change Plan

Files to change:
- ...

Files to inspect but not change:
- ...

Do not change:
- ...

Verification plan:
- ...
```

Do not add:

- unrequested features
- speculative refactors
- naming changes
- unrelated cleanup
- architecture changes
- game balance changes
- card effect changes
- UI/UX behavior changes unless requested

---

# Step 5. Implement

Make the smallest change that satisfies the request.

During implementation:

- preserve existing design intent
- avoid broad formatting changes
- avoid touching unrelated files
- keep changes easy to review

---

# Step 6. Verify

Run the strongest available verification.

For this Godot project:

```bash
bash check_syntax.sh
```

General checks:

```bash
git diff --check
git diff --stat
git status --short
```

Do not claim success without evidence.

---

# Step 7. Update Logs

Update `docs/ai/TASK_LOG.md` with:

```md
## YYYY-MM-DD - [Task Title]

### Request
- ...

### Files Changed
- ...

### Summary
- ...

### Verification
- ...

### Follow-up
- ...
```

Update `docs/ai/VERIFICATION_LOG.md` with:

```md
## YYYY-MM-DD - [Task Title]

### Commands Run
...

### Result
- Passed / Failed / Not run

### Evidence
- ...

### Remaining Uncertainty
- ...
```

If something remains unresolved, update `docs/ai/OPEN_ISSUES.md`.

---

# Step 8. Update Lessons If Needed

If the user corrected Claude, or if a mistake was found during the task, update `docs/ai/LESSONS_LEARNED.md`.

Use this format:

```md
## YYYY-MM-DD - [Short Title]

### Trigger
- ...

### Lesson
- ...

### Do Not Repeat
- ...

### Required Future Behavior
- ...

### Scope
- Applies to:
- Does not apply to:
```

Do not invent lessons.
Do not overgeneralize.

---

# Step 9. Final Report

Final response must include:

```text
## Result

Changed files:
- ...

What changed:
- ...

Verification:
- command => result

FACT:
- ...

INFERENCE:
- ...

UNKNOWN:
- ...

Updated logs:
- ...

Remaining risks:
- ...
```

## Stop Conditions

Stop and inspect more if:

- relevant files have not been read
- verification results are missing
- the request conflicts with existing project rules
- current implementation is unclear

Do not continue from guesses.
