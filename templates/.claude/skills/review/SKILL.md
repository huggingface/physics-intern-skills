---
name: review
description: Adversarial review of a derivation (D-NNN) or computation (C-NNN), in a fresh-context sub-agent that sees only the # Task and ## Derivation / ## Computation sections — never prior reviews. Appends a verdict (confirmed / refuted / inconclusive) to the target file under ## Reviews.
context: fork
agent: reviewer
arguments: [target_id]
---

Review the target artefact: $target_id (a `D-NNN` or `C-NNN` identifier).

Dispatched context (relevant Established Results and Conventions from `research_log.md`, plus any references the target cites):

$ARGUMENTS

Follow your role definition (see `.claude/agents/reviewer.md`). You see the target's `# Task` and `## Derivation` (or `## Computation`) sections only — **NOT any existing `## Reviews`**. Form an independent verdict.

Append your verdict to the target file under `## Reviews` (create the section if absent). Return the structured reply with the verdict in `## Result`.

The main agent runs the integration loop (see `CLAUDE.md`) after this skill returns. Your responsibility ends with the structured reply — do not commit, do not edit `research_log.md` or `notes/flags.md`.
