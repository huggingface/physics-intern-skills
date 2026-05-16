---
name: research-plan
description: Draft or update plan.md — the numbered research strategy. Reads problem.md, survey.md, and research_log.md. On re-run, marks completed steps, drops obsolete ones, and revises remaining steps. HITL — the main agent presents the draft to the user for approval after this skill returns.
context: fork
agent: planner
---

Draft or update `plan.md` for the problem in `./problem.md`, using `survey.md` and `research_log.md` as inputs.

User feedback or scope hints (optional, may be empty on first run): $ARGUMENTS

Follow your role definition (see `.claude/agents/planner.md`). If `plan.md` already exists, this is a re-run — mark completed steps, drop or revise as warranted by `research_log.md`. Return the structured reply (`## Summary` / `## Result` / `## Flags`) to the main agent, who will present the plan to the user for approval.

The main agent runs the integration loop (see `CLAUDE.md`) after this skill returns. Your responsibility ends with the structured reply — do not commit, do not edit `research_log.md` or `notes/flags.md`. Note: targeted plan.md edits (marking a step done, dropping an obsolete step) are handled by the main agent without re-invoking this skill.
