---
description: Strategic critique of the overall research state, in a fresh-context critic sub-agent. Identifies strategic drift, plan-viability issues, coherence problems, under-sourced claims, citation gaps.
args: [optional focus from main agent]
section: PhysicsIntern Workflows
topLevelCli: true
---

## Tool discipline (read first)

Tool names are literal and lowercase. Sub-agent dispatch uses the `subagent` tool from `pi-subagents`. Do **not** use `Task`.

## What this skill does

Run a strategic critique. The `critic` sub-agent reads `research_log.md` and `plan.md`, spot-checks artefacts as needed, and files findings in `critiques/CR-NNN.md`. Findings are proposals — you disposition each.

Optional focus from main agent: $@

## Steps

1. **Determine the next `CR-NNN` number.** Use `ls critiques/CR-*.md 2>/dev/null` to find the highest; add 1; zero-pad.

2. **Collect one-line summaries of prior critiques** to pass to the new critic. For each existing `critiques/CR-MMM.md`, extract one line: the filed date and headline finding. This prevents repetition but does not leak full prior analyses.

3. **Dispatch the `critic` sub-agent** via the `subagent` tool. Include the prior-critique one-liners and any focus from the user inline in the `task` string:

   ```json
   {
     "tasks": [
       {
         "agent": "critic",
         "task": "Run a strategic critique per .pi/agents/critic.md. Read research_log.md (esp. Established Results), plan.md, and spot-check individual artefacts as needed. Write critiques/CR-NNN.md with YAML frontmatter (filed: YYYY-MM-DD, status: pending), ## Findings, and an empty ## Resolution. Place the structured ## Summary / ## Result / ## Flags at the top. Prior critique one-liners follow. Optional focus from main agent: <verbatim $@ or 'none'>.",
         "output": "critiques/CR-NNN.md"
       }
     ],
     "concurrency": 1,
     "failFast": false
   }
   ```

   Substitute the actual `NNN`.

4. **Run the integration loop** when the critic returns:
   - Read `## Summary` / `## Result` / `## Flags` from `critiques/CR-NNN.md`.
   - **Do not act on findings unilaterally.** Disposition each finding inline in the critique file's `## Resolution` section (resolve / dismiss / defer with a reason). Update the YAML `status:` field accordingly.
   - For findings that imply a strategy-level change, re-invoke `/research-plan` after the critique commit lands.
   - Disposition any general flags in `notes/flags.md`.
   - Commit as `critique(CR-NNN): <one-line summary>`.

5. **Checks and balances.** Before acting on a major critique finding that would substantially change direction, seek a second opinion — another `/critique` or a confirming `/review` — per AGENTS.md §3.
