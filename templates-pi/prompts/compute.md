---
description: Symbolic + numerical computation for a target claim, in a fresh-context computer sub-agent. SymPy + NumPy by default. Symbolic and numerical run together when feasible; disagreement is flagged.
args: <target claim>
section: PhysicsIntern Workflows
topLevelCli: true
---

## Tool discipline (read first)

Tool names are literal and lowercase. Use only tools visible in the current tool set. Sub-agent dispatch uses the `subagent` tool from `pi-subagents`. Shell: `bash` with explicit timeout. Do **not** use `Task`.

## What this skill does

Perform symbolic + numerical computation. The `computer` sub-agent writes a script and executes it; you write the brief and integrate the result.

Target: $@

## Steps

1. **Determine the next `C-NNN` number.** Use `ls computations/C-*.md 2>/dev/null` to find the highest; add 1; zero-pad.

2. **Write the brief** at `computations/.briefs/C-NNN-brief.md`. Include only:
   - The target claim or quantity to compute, stated concretely.
   - Relevant **Established Results** from `research_log.md` (by ID and one-line restatement).
   - Relevant **Conventions** from `research_log.md` (units, signatures, normalizations).
   - Specific reference file paths (`references/<id>.{md,pdf,tex}`) that bear on the target.
   - Any prior `D-NNN.md` or `C-NNN.md` whose result is a load-bearing input — by path, not by re-statement.
   - Any prior `data/<slug>.*` files the computer may reuse — by path only.

   **No steering, no priors.** Do not signal an expected answer or preferred direction.

3. **Dispatch the `computer` sub-agent** via the `subagent` tool:

   ```json
   {
     "tasks": [
       {
         "agent": "computer",
         "task": "Read computations/.briefs/C-NNN-brief.md. Compute the target per .pi/agents/computer.md. Run symbolic and numerical paths together when both are feasible; flag disagreement. Execute the script via bash with an explicit timeout. Write computations/C-NNN.py and computations/C-NNN.md; place the structured ## Summary / ## Result / ## Flags at the top of the .md.",
         "output": "computations/C-NNN.md"
       }
     ],
     "concurrency": 1,
     "failFast": false
   }
   ```

   Substitute the actual `NNN` value in both `task` and `output`.

4. **Run the integration loop** when the computer returns:
   - Read `## Summary` / `## Result` / `## Flags` from `computations/C-NNN.md`.
   - Add or update a Working Claim in `research_log.md` citing `C-NNN`.
   - Note any new `data/<slug>.*` files mentioned in `## Data outputs` in `research_log.md` Conventions or near the relevant claim.
   - Disposition every flag in `notes/flags.md`.
   - Commit as `compute(C-NNN): <one-line summary>` — include the `.py` script in the commit.

5. **Next dispatch is `/review C-NNN`** unless the integration loop surfaced a reason to defer.
