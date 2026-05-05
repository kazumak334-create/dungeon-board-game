---
name: update-lessons
description: Use when the user corrects Claude, points out a repeated mistake, says not to do something again, or clarifies a project rule. Updates docs/ai/LESSONS_LEARNED.md.
allowed-tools: Read Edit Bash
---

# Update Lessons Skill

Use this skill when the user corrects you or gives a reusable preference/rule.

## Trigger Examples

Use this when the user says things like:

- "違う"
- "定義間違えんな"
- "余計なことするな"
- "前も言った"
- "これはこうして"
- "今後は..."
- "繰り返さないで"
- "勝手に判断しないで"
- "現物見て"
- "憶測で判断しないで"

## Procedure

### 1. Identify the reusable lesson

Extract only durable, reusable guidance.

Do not store:
- temporary task details
- emotional wording only
- private information unrelated to development
- guesses about user intent

### 2. Update `docs/ai/LESSONS_LEARNED.md`

Use this format:

```md
## YYYY-MM-DD - [Short Title]

### Trigger
User corrected:

> brief paraphrase, not necessarily exact quote

### Lesson
- ...

### Do Not Repeat
- ...

### Required Future Behavior
- ...

### Scope
- Applies to: ...
- Does not apply to: ...
```

### 3. Confirm

After updating, report:

```text
Updated docs/ai/LESSONS_LEARNED.md

Lesson added:
- ...

Future behavior:
- ...
```

## Important

Do not overgeneralize.
A lesson should be specific enough to prevent recurrence, but not so broad that it blocks valid future work.
