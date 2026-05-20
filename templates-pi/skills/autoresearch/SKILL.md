---
name: autoresearch
description: Run the research pipeline autonomously without human-in-the-loop gates. Can only be invoked by the user.
---

# Autoresearch

Run the `/autoresearch` workflow. The slash command expands the full workflow instructions in the active session.

Agents used: `surveyor`, `planner`, `deriver`, `computer`, `reviewer`, `critic`, `finalizer` (driven from the main-agent loop).

Output: the full set of workspace artefacts a normal session would produce, plus `notes/auto-decisions.md` recording each skipped HITL gate.
