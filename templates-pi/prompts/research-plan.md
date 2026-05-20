---
description: Draft or update plan.md — the numbered research strategy. Forks a fresh-context planner sub-agent. HITL after return.
args: [optional feedback or scope hints]
section: PhysicsIntern Workflows
topLevelCli: true
---

## Tool discipline (read first)

Tool names are literal and lowercase. Use only tools visible in the current tool set. Sub-agent dispatch uses the `subagent` tool from `pi-subagents`. Do **not** use `Task`.

## What this skill does

Draft or update `plan.md` for the problem in `./problem.md`, using `survey.md` and `research_log.md` as inputs. The substantive work happens inside the `planner` sub-agent (fresh context).

User feedback or scope hints (optional, may be empty on first run): $@

## Steps

1. **Dispatch the `planner` sub-agent** via the `subagent` tool:

   ```json
   {
     "tasks": [
       {
         "agent": "planner",
         "task": "Draft or update ./plan.md per .pi/agents/planner.md. Read ./problem.md, ./survey.md (if it exists), and ./research_log.md. If plan.md already exists, mark completed steps, drop or revise as warranted by research_log.md. Place the structured ## Summary / ## Result / ## Flags at the top of plan.md. User feedback from main agent: <verbatim copy of $@, or 'none'>.",
         "output": "plan.md"
       }
     ],
     "concurrency": 1,
     "failFast": false
   }
   ```

2. **Run the integration loop** when the planner returns:
   - Read the `## Summary` / `## Result` / `## Flags` from `plan.md`.
   - Disposition every flag in `notes/flags.md`. Suggested Conventions/Sanity Checks from the planner go to the appropriate `research_log.md` sections.
   - Commit as `research-plan: <one-line summary>`.
   - **Present the plan to the user for approval.** This is the post-plan HITL gate — do not start dispatching `/derive` or `/compute` until the user confirms.

## Notes

- Targeted edits to `plan.md` (marking a step done, dropping an obsolete step, retitling) are handled by you directly without re-invoking this skill. Re-invoke only for strategy-level changes.
