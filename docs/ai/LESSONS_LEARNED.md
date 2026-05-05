# Lessons Learned

This file records durable corrections and project-specific operating rules.
Claude must read this before implementation, review, debugging, or design judgment.

## Standing Lessons

### 1. Inspect actual files before judging

#### Lesson
Do not analyze or implement from assumptions. Always inspect current files first.

#### Do Not Repeat
- Do not infer implementation from memory.
- Do not claim a feature exists without reading the relevant code.
- Do not claim a bug is fixed without verification.
- Do not infer behavior only from filenames, directory names, or prior conversation.

#### Required Future Behavior
- Read relevant files.
- Summarize FACT / INFERENCE / UNKNOWN.
- Then decide.

#### Scope
- Applies to all implementation, debugging, review, and architecture tasks.

---

### 2. Do not add unrequested interpretation

#### Lesson
When the user requests a specific change, implement that change directly.

#### Do Not Repeat
- Do not expand the request into a broader redesign.
- Do not add extra effects, labels, mechanics, or abstractions.
- Do not change terminology without explicit instruction.
- Do not add unsolicited suggestions into implementation files.

#### Required Future Behavior
- Preserve the user's exact definitions.
- Make the smallest sufficient change.
- Ask only if the requested change is impossible or contradictory.

#### Scope
- Applies especially to game design specs, card effects, UI behavior, and balance changes.

---

### 3. Preserve corrected definitions

#### Lesson
If the user corrects a definition, the corrected definition becomes authoritative.

#### Do Not Repeat
- Do not revert to the old definition.
- Do not paraphrase in a way that changes meaning.
- Do not reinterpret corrected terms.

#### Required Future Behavior
- Use corrected wording exactly when precision matters.
- Check this file before touching related docs or code.

#### Scope
- Applies to terminology, game mechanics, architecture rules, and project conventions.

---

### 4. Verification is required before completion claims

#### Lesson
Completion claims must be backed by command output, tests, logs, or inspected code.

#### Do Not Repeat
- Do not say "done", "fixed", or "works" without verification.
- Do not treat implementation as verified just because a patch was applied.

#### Required Future Behavior
- Run relevant verification commands.
- Record results in `docs/ai/VERIFICATION_LOG.md` for non-trivial tasks.
- If verification cannot be run, record why.

#### Scope
- Applies to implementation, bug fixing, refactoring, and project maintenance.

---

## 2026-05-06 - Actual state must be confirmed before reporting

### Trigger
User corrected: "実際の実装状況や要件定義書などのファクトを見て話してくれ"

### Lesson
- Never describe what a file "probably contains" without reading it.
- Never claim a deck has N cards without reading cards_econ.json.
- Never say "it should be correct" after an edit without verifying the actual file content.

### Do Not Repeat
- Do not count cards based on memory or inference.
- Do not report completion without reading the modified file.
- Do not say "11 cards" without confirming the actual INITIAL_DECK array length.

### Required Future Behavior
- After every edit to data files (cards_econ.json, etc.), read the file and count/verify the actual content.
- State FACT (confirmed by read) vs INFERENCE (reasoned but not read).

### Scope
- Applies to: all edits to data files, deck specs, card counts, JSON structure.
- Does not apply to: pure comment changes or trivial whitespace edits.

---

## 2026-05-06 - discard_card uses value comparison, not index

### Trigger
User reported: placing a building causes wrong card to be removed from hand.

### Lesson
- GDScript `Array.erase()` uses value comparison. If multiple cards share the same dictionary keys/values, the wrong card may be erased.
- Use `remove_at(idx)` with an explicit index to guarantee correct removal.

### Do Not Repeat
- Do not use `hand.erase(card)` when the specific card instance must be removed.
- Do not assume `erase()` removes the intended card when hand contains similar cards.

### Required Future Behavior
- Use `discard_card_at(idx)` or `exclude_card_at(idx)` for hand removal.
- Use `add_to_discard(card)` when the card is already removed from hand.

### Scope
- Applies to: EconDeckManager.gd, all hand manipulation in EconBattle.gd, EconMain.gd.
