---
name: finalize
description: Synthesise answer.md — the final research deliverable — from Established Results and supporting artefacts. Runs in a fresh-context sub-agent. Reads research_log.md, problem.md, plan.md, and selectively reads derivations/, computations/, critiques/, references/ as needed.
context: fork
agent: finalizer
---

Synthesise the final research answer.

Dispatched context (optional emphasis from the main agent — areas to highlight, audience hints, length guidance):

$ARGUMENTS

Follow your role definition (see `.claude/agents/finalizer.md`). The load-bearing inputs are `problem.md` and the Established Results in `research_log.md`. Trace citations into `derivations/`, `computations/`, `critiques/`, and `references/` as needed. Be honest about Working Claims and Open Issues — do not present them as settled.

Write `./answer.md`. Return the structured reply with the headline result in `## Result`.

The main agent runs the integration loop (see `CLAUDE.md`) after this skill returns. Your responsibility ends with the structured reply — do not commit, do not edit `research_log.md` or `notes/flags.md`.
