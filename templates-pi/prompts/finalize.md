---
description: Synthesise answer.md — the final research deliverable — from Established Results and supporting artefacts. Runs in a fresh-context finalizer sub-agent.
args: [optional emphasis from main agent]
section: PhysicsIntern Workflows
topLevelCli: true
---

## Tool discipline (read first)

Tool names are literal and lowercase. Sub-agent dispatch uses the `subagent` tool from `pi-subagents`. Do **not** use `Task`.

## What this skill does

Synthesise the final answer. The `finalizer` sub-agent reads `research_log.md`, `problem.md`, `plan.md`, and selectively traces into `derivations/`, `computations/`, `critiques/`, `references/`. The load-bearing inputs are the **Established Results** in `research_log.md`.

Optional emphasis from main agent (areas to highlight, audience hints, length guidance): $@

## Steps

1. **Sanity-check before dispatch.** The Established Results in `research_log.md` should carry the answer. If they don't — if the answer depends on Working Claims that haven't been promoted — pause and tell the user. `/finalize` will still produce an honest partial answer, but the user should know.

2. **Dispatch the `finalizer` sub-agent** via the `subagent` tool:

   ```json
   {
     "tasks": [
       {
         "agent": "finalizer",
         "task": "Synthesise the final answer per .pi/agents/finalizer.md. Load-bearing inputs are problem.md and the Established Results in research_log.md. Trace citations into derivations/, computations/, critiques/, references/ as needed. Be honest about Working Claims and Open Issues. Write ./answer.md and place the structured ## Summary / ## Result / ## Flags at the top. Optional emphasis from main agent: <verbatim $@ or 'none'>.",
         "output": "answer.md"
       }
     ],
     "concurrency": 1,
     "failFast": false
   }
   ```

3. **Run the integration loop** when the finalizer returns:
   - Read `## Summary` / `## Result` / `## Flags` from `answer.md`.
   - Disposition every flag in `notes/flags.md`. Suggestions for additional review before publishing may translate to one more `/review` or `/critique` cycle.
   - Commit as `finalize: <one-line summary>`.
   - Present the headline result to the user.
