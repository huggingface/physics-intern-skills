---
name: review
description: Adversarial review of a derivation (D-NNN) or computation (C-NNN), in a fresh-context reviewer sub-agent that sees only the target's # Task and ## Derivation / ## Computation — never prior reviews. Writes a sibling review file (derivations/D-NNN_RM.md or computations/C-NNN_RM.md) carrying the verdict.
---

# Review

Run the `/review` workflow. The slash command expands the full workflow instructions in the active session.

Agents used: `reviewer`.

Output: a new sibling review file `derivations/D-NNN_RM.md` (or `computations/C-NNN_RM.md`).
