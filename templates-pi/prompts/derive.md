---
description: Analytical derivation for a target claim, in a fresh-context deriver sub-agent that uses only what is dispatched via a brief file.
args: <target claim>
section: PhysicsIntern Workflows
topLevelCli: true
---

## Tool discipline (read first)

Tool names are literal and lowercase. Use only tools visible in the current tool set. Sub-agent dispatch uses the `subagent` tool from `pi-subagents`. Do **not** use `Task`.

## What this skill does

Perform an analytical derivation. The `deriver` sub-agent works only from what you put in a brief file plus the workspace `problem.md`. You write the brief; you dispatch; you integrate.

Target: $@

## Steps

1. **Determine the next `D-NNN` number.** Use `ls derivations/D-*.md 2>/dev/null` to find the highest existing; add 1; zero-pad to 3 digits (`D-001`, `D-002`, …).

2. **Write the brief** at `derivations/.briefs/D-NNN-brief.md`. Include only:
   - The target claim or question, stated concretely.
   - Relevant **Established Results** from `research_log.md` the deriver may need (by ID and one-line restatement).
   - Relevant **Conventions** from `research_log.md`.
   - Specific reference file paths (`references/<id>.{md,pdf,tex}`) that bear on the target.
   - Any prior `D-NNN.md` or `C-NNN.md` whose result is a load-bearing input — by path, not by re-statement.

   **No steering, no priors.** Do not signal an expected answer or preferred direction. Do not leak prior reviewer verdicts or critique framing. The deriver follows the math.

3. **Dispatch the `deriver` sub-agent** via the `subagent` tool:

   ```json
   {
     "tasks": [
       {
         "agent": "deriver",
         "task": "Read derivations/.briefs/D-NNN-brief.md. Derive the target claim per .pi/agents/deriver.md. Write derivations/D-NNN.md with sections # Task, ## Derivation, ## Assumptions, ## Sanity checks, and place the structured ## Summary / ## Result / ## Flags at the top.",
         "output": "derivations/D-NNN.md"
       }
     ],
     "concurrency": 1,
     "failFast": false
   }
   ```

   Substitute the actual `NNN` value in both `task` and `output`. Keep the JSON compact.

4. **Run the integration loop** when the deriver returns:
   - Read `## Summary` / `## Result` / `## Flags` from `derivations/D-NNN.md`.
   - Add or update a Working Claim in `research_log.md` citing `D-NNN`.
   - Disposition every flag in `notes/flags.md`.
   - Commit as `derive(D-NNN): <one-line summary>`.

5. **Next dispatch is `/review D-NNN`** unless the integration loop surfaced a reason to defer. Do not chain another `/derive` or `/compute` without intervening review.
