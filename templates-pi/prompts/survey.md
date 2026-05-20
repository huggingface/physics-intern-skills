---
description: Survey the research landscape for the problem in problem.md. Forks a fresh-context surveyor sub-agent.
args: [optional user hints]
section: PhysicsIntern Workflows
topLevelCli: true
---

## Tool discipline (read first)

Tool names are literal and lowercase. Use only tools visible in the current tool set.

- File I/O: `read`, `write`. Shell: `bash`. Web: `web_search`, `fetch_content`.
- Sub-agent dispatch: the `subagent` tool from `pi-subagents`. Do **not** use `Task` — that tool does not exist here.

## What this skill does

Run a research-landscape survey for the problem stated in `./problem.md`. The substantive work happens inside the `surveyor` sub-agent (fresh context). You stay in the loop only as coordinator.

Additional user hints (optional): $@

## Steps

1. **Confirm the workspace is ready.** `./problem.md` must exist and `./AGENTS.md` must no longer contain `{{PROBLEM_ONELINER}}`. If the placeholder is still present, tell the user to run `/start-research` first and stop.

2. **Dispatch the `surveyor` sub-agent** via the `subagent` tool:

   ```json
   {
     "tasks": [
       {
         "agent": "surveyor",
         "task": "Read ./problem.md. Run a research-landscape survey per .pi/agents/surveyor.md. Write ./survey.md with sections: Background, Question framing (only if there is a load-bearing disagreement), Known approaches, Known pitfalls, Key references. Place the structured ## Summary / ## Result / ## Flags at the top of survey.md. Optional user hints from main agent: <verbatim copy of $@, or 'none'>.",
         "output": "survey.md"
       }
     ],
     "concurrency": 1,
     "failFast": false
   }
   ```

   Do **not** put multi-paragraph instructions inside the `subagent` JSON; the role definition already lives in `.pi/agents/surveyor.md` and the surveyor will read it via its frontmatter.

3. **Run the integration loop** (see `AGENTS.md` §3) when the surveyor returns:
   - Read the `## Summary` / `## Result` / `## Flags` from `survey.md`.
   - Disposition every flag in `notes/flags.md`.
   - Commit as `survey: <one-line summary>`.
   - Present the result to the user. Suggested next step: `/research-plan`. Pause for user input — `/survey` is the first HITL gate.
