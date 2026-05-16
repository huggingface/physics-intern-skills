---
name: derive
description: Perform an analytical derivation for a target claim or open question, in a fresh-context sub-agent that uses only what is dispatched. Writes derivations/D-NNN.md with the derivation, assumptions, and sanity checks.
context: fork
agent: deriver
arguments: [target]
---

Perform an analytical derivation. Target: $target

Dispatched context (provided below by the main agent — the deriver uses ONLY this context, the named references, and the workspace `problem.md`):

$ARGUMENTS

Follow your role definition (see `.claude/agents/deriver.md`). Use only the target, dispatched context, named references, and prior derivations/computations explicitly cited. Do not browse `references/`, `notes/`, or other artefacts. If the dispatch is insufficient, report back via `## Flags` rather than expanding scope.

Write `derivations/D-NNN.md` (next available number) and return the structured reply.

The main agent runs the integration loop (see `CLAUDE.md`) after this skill returns. Your responsibility ends with the structured reply — do not commit, do not edit `research_log.md` or `notes/flags.md`.
