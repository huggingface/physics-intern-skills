---
name: research-plan
description: Draft or update plan.md — the numbered research strategy. Forks a fresh-context planner sub-agent. HITL after return.
agent: planner
arguments_hint: "[optional feedback or scope hints]"
output_pattern: plan.md
---

Draft or update `plan.md` for the problem in `./problem.md`, using `survey.md` and `research_log.md` as inputs. The substantive work happens inside the `planner` sub-agent (fresh context).

## Steps

1. **Dispatch the `planner` sub-agent**, passing any user feedback or scope hints inline. See {{workspace_doc}} §3 (Dispatch syntax) for the exact tool invocation. The planner reads `./problem.md`, `./survey.md` (if it exists), and `./research_log.md`; follows its role definition in `{{agents_dir}}/planner.md`; and writes `./plan.md`. If `plan.md` already exists, the planner marks completed steps, drops or revises as warranted. The structured `## Summary` / `## Result` / `## Flags` goes at the top of `plan.md`.

2. **Run the integration loop** when the planner returns:
   - Read the `## Summary` / `## Result` / `## Flags` from `plan.md`.
   - Disposition every flag in `notes/flags.md`. Suggested Conventions/Sanity Checks from the planner go to the appropriate `research_log.md` sections.
   - Commit as `research-plan: <one-line summary>`.
   - **Present the plan to the user for approval.** This is the post-plan HITL gate — do not start dispatching `/derive` or `/compute` until the user confirms.

## Notes

- Targeted edits to `plan.md` (marking a step done, dropping an obsolete step, retitling) are handled by you directly without re-invoking this skill. Re-invoke only for strategy-level changes.
