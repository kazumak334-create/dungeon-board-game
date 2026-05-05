# Open Issues

This file records unresolved issues, unknowns, and follow-up checks.

## Template

### YYYY-MM-DD - [Issue Title]

#### Issue
- ...

#### Current Status
- ...

#### Next Action
- ...

#### Owner
- ...

---

## 2026-05-06 - Confirm skill auto-invocation in real tasks

#### Issue
- Need to confirm whether Claude Code automatically invokes the intended skills during real implementation tasks.

#### Current Status
- Skill files have been created.
- Actual invocation behavior has not yet been verified in a real task.

#### Next Action
- Run a small implementation task and confirm whether the inspect-first + verify workflow is followed.

#### Owner
- Claude / User

---

## 2026-05-06 - EconBattle.gd L606: magic number 5 (5-building milestone)

#### Issue
- The number `5` for the 5-building milestone is hardcoded at EconBattle.gd approximately line 606.
- Should be extracted as a named constant (e.g., `MILESTONE_BUILDING_COUNT: int = 5`).

#### Current Status
- Identified during Econ MVP session. Deferred by user.

#### Next Action
- Define constant in EconBattle.gd when next touching that file.

#### Owner
- Implementer

---

## 2026-05-06 - COUPLING: direct field access to EconEconomy from outside

#### Issue
- Multiple sites directly assign to economy fields (e.g., `economy.currency -= 1`) from EconBattle.gd and EconMain.gd, violating ADR-001 疎結合ルール.

#### Current Status
- Large-scale refactor. Deferred by user.

#### Next Action
- Define spend/earn methods in EconEconomy and route all mutations through them.

#### Owner
- Architect (design first) -> Implementer
