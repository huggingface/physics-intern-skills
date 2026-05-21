---
name: review
description: Adversarial review of a derivation (D-NNN) or computation (C-NNN), in a fresh-context sub-agent that sees only the target's # Task and ## Derivation / ## Computation — never prior reviews. Writes a sibling review file (derivations/D-NNN_RM.md or computations/C-NNN_RM.md) carrying the verdict.
context: fork
agent: reviewer
arguments: [target_id]
---

Review the target artefact: $target_id (a `D-NNN` or `C-NNN` identifier).

Dispatched context (relevant Established Results and Conventions from `research_log.md`, plus any references the target cites):

$ARGUMENTS

Follow your role definition (see `.claude/agents/reviewer.md`). Read the target file in full. Do **not** read any sibling `D-NNN_R*.md` or `C-NNN_R*.md` review files. Form an independent verdict.

Determine your output path: `derivations/D-NNN_R<M>.md` for `D-NNN`, or `computations/C-NNN_R<M>.md` for `C-NNN`, where `M = (count of existing matching sibling files) + 1`. Write your verdict file there with YAML frontmatter (`target`, `review_id`, `date`, `verdict`) and the prose body specified in your role definition.

Return the structured reply with the verdict in `## Result`.

The main agent runs the integration loop (see `CLAUDE.md`) after this skill returns. Your responsibility ends with the structured reply — do not commit, do not edit `research_log.md` or `notes/flags.md`.
