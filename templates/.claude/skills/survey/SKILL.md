---
name: survey
description: Survey the research landscape for the problem stated in problem.md. Produces survey.md covering background, known approaches, pitfalls, and key references. May fetch papers into references/. Provisional orientation — later evidence overrides it.
context: fork
agent: surveyor
---

Run a research-landscape survey for the problem stated in `./problem.md`.

Additional user hints (optional): $ARGUMENTS

Follow your role definition (see `.claude/agents/surveyor.md`). Write `survey.md` and return the structured reply (`## Summary` / `## Result` / `## Flags`) to the main agent.

The main agent runs the integration loop (see `CLAUDE.md`) after this skill returns. Your responsibility ends with the structured reply — do not commit, do not edit `research_log.md` or `notes/flags.md`.
