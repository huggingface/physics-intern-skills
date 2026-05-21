---
name: derive
description: Perform an analytical derivation for a target claim or open question, in a fresh-context sub-agent that uses only what is dispatched via a brief file. Writes derivations/D-NNN.md with the derivation, assumptions, and sanity checks.
context: fork
agent: deriver
arguments: [artefact_id]
---

Perform an analytical derivation for the target artefact $artefact_id (a `D-NNN` identifier).

Read the dispatch brief at `derivations/.briefs/$artefact_id-brief.md`. The brief contains the target claim, relevant Established Results, Conventions, and specific reference file paths. Use only the brief, the named references, prior derivations/computations explicitly cited in it, and the workspace `problem.md`. Do not browse `references/`, `notes/`, or other artefacts. If the brief is insufficient, report back via `## Flags` rather than expanding scope.

Follow your role definition (see `.claude/agents/deriver.md`).

Write `derivations/$artefact_id.md` and return the structured reply.

The main agent runs the integration loop (see `CLAUDE.md`) after this skill returns. Your responsibility ends with the structured reply — do not commit, do not edit `research_log.md` or `notes/flags.md`.
