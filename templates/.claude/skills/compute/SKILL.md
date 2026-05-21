---
name: compute
description: Perform symbolic and numerical computation for a target claim, in a fresh-context sub-agent that uses only what is dispatched via a brief file. Default backend SymPy + NumPy. Runs symbolic and numerical paths together when both are feasible and flags disagreements. Writes computations/C-NNN.{md,py}.
context: fork
agent: computer
arguments: [artefact_id]
---

Perform a symbolic + numerical computation for the target artefact $artefact_id (a `C-NNN` identifier).

Read the dispatch brief at `computations/.briefs/$artefact_id-brief.md`. The brief contains the target claim, relevant Established Results, Conventions, and specific reference file paths. Use only the brief, the named references, prior derivations/computations explicitly cited in it, and the workspace `problem.md`. Do not browse `references/`, `notes/`, or other artefacts. If the brief is insufficient, report back via `## Flags` rather than expanding scope.

Follow your role definition (see `.claude/agents/computer.md`). Run both symbolic and numerical paths when both are feasible; report agreement or disagreement explicitly.

Write `computations/$artefact_id.py` and `computations/$artefact_id.md`. Execute the script. Return the structured reply.

The main agent runs the integration loop (see `CLAUDE.md`) after this skill returns. Your responsibility ends with the structured reply — do not commit, do not edit `research_log.md` or `notes/flags.md`.
