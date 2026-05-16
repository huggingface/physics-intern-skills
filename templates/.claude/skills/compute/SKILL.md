---
name: compute
description: Perform symbolic and numerical computation for a target claim, in a fresh-context sub-agent. Default backend SymPy + NumPy. Runs symbolic and numerical paths together when both are feasible and flags disagreements. Writes computations/C-NNN.{md,py}.
context: fork
agent: computer
arguments: [target]
---

Perform a symbolic + numerical computation. Target: $target

Dispatched context (provided below by the main agent — the computer uses ONLY this, the named references, and the workspace `problem.md`):

$ARGUMENTS

Follow your role definition (see `.claude/agents/computer.md`). Run both symbolic and numerical paths when both are feasible; report agreement or disagreement explicitly. Use only the target, dispatched context, named references, and prior artefacts explicitly cited.

Write `computations/C-NNN.py` and `computations/C-NNN.md` (next available number). Execute the script. Return the structured reply.

The main agent runs the integration loop (see `CLAUDE.md`) after this skill returns. Your responsibility ends with the structured reply — do not commit, do not edit `research_log.md` or `notes/flags.md`.
