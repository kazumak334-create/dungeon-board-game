---
description: Diagnose and fix one Godot bug with verification discipline
---

# Bugfix Flow

Handle exactly one bug.

Workflow:

1. Reproduce or locate the failing path with logs/search before editing.
2. Identify the smallest responsible file/function.
3. Check the relevant requirement or design document.
4. Make the smallest scoped fix.
5. Run `bash check_syntax.sh`.
6. Report changed files, verification result, and residual risk.

Rules:

- Do not bundle unrelated refactors.
- Do not edit roadmap/changelog unless this completes a tracked task.
- If the bug cannot be reproduced, say what evidence is missing and add only diagnostic logging if useful.
