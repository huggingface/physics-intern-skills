---
name: review
description: Adversarial review of a derivation (D-NNN) or computation (C-NNN), in a fresh-context sub-agent that sees only the # Task and ## Derivation / ## Computation sections — never prior reviews. Appends a verdict (confirmed / refuted / inconclusive) to the target file under ## Reviews.
---

# Review

Run the `/review` workflow. The slash command expands the full workflow instructions in the active session.

Agents used: `reviewer`.

Output: appended `## Reviews` entry on the target `D-NNN.md` or `C-NNN.md`.
