---
name: implement-with-verification
description: Use for implementing requested changes. Requires current-state inspection, minimal implementation, verification, and a final evidence-based report.
allowed-tools: Read Grep Glob Bash Edit
---

# Implement With Verification Skill

You are implementing a requested change with strict evidence discipline.

## Non-Negotiable Rules

- Inspect before editing.
- Edit only the minimum necessary files.
- Do not add unrequested features.
- Do not refactor unrelated code.
- Do not assume tests pass.
- Do not claim completion without verification.
- If verification cannot be run, explain exactly why.

## Workflow

### Step 1. Load lessons

Read:

- `CLAUDE.md`
- `docs/ai/LESSONS_LEARNED.md`
- `docs/ai/OPEN_ISSUES.md`

Extract any lessons relevant to the current task.

### Step 2. Inspect current state

Use `/inspect-first` behavior:

- Locate files
- Read relevant implementation
- Summarize FACT / INFERENCE / UNKNOWN
- Identify the exact gap

### Step 3. Plan minimal patch

Before editing, write:

```text
## Minimal Change Plan

Files to change:
- ...

Do not change:
- ...

Reason:
- ...
```

### Step 4. Implement

Make the smallest change that satisfies the request.

Avoid:
- renaming unless requested
- architecture changes unless requested
- speculative cleanup
- broad formatting changes
- unrelated bug fixes
- game balance changes unless requested
- card effect changes unless requested
- terminology changes unless requested

### Step 5. Verify

Run the strongest available verification for the repository.

For Godot projects, prefer:

```bash
bash check_syntax.sh
```

Also consider:

```bash
git diff --check
git diff --stat
git status --short
```

### Step 6. Update logs

For non-trivial tasks, update:

- `docs/ai/TASK_LOG.md`
- `docs/ai/VERIFICATION_LOG.md`

If something remains unresolved, update:

- `docs/ai/OPEN_ISSUES.md`

### Step 7. Report

Final response must include:

```text
## Result

Changed files:
- ...

What changed:
- ...

Verification:
- [command] => [result]

Evidence:
- file path + confirmed behavior

Remaining uncertainty:
- none / ...
```

## Failure Handling

If an error occurs:

1. Read the exact error message.
2. Identify the file and line if available.
3. Inspect that code.
4. Apply the smallest fix.
5. Re-run verification.
6. Do not guess the cause without evidence.
