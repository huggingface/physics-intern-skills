---
description: Adversarial review of a derivation (D-NNN) or computation (C-NNN), in a fresh-context reviewer sub-agent that sees only the target's # Task and ## Derivation / ## Computation sections — never prior reviews.
args: <D-NNN | C-NNN target id>
section: PhysicsIntern Workflows
topLevelCli: true
---

## Tool discipline (read first)

Tool names are literal and lowercase. Sub-agent dispatch uses the `subagent` tool from `pi-subagents`. Do **not** use `Task`.

## What this skill does

Run an independent adversarial review on a target artefact. The `reviewer` sub-agent appends a verdict (`confirmed` / `refuted` / `inconclusive`) under the target's `## Reviews` section. Each review starts fresh — no prior verdicts are passed.

Target ID: $@

## Steps

1. **Resolve the target path.** If the target is `D-NNN`, the path is `derivations/D-NNN.md`. If `C-NNN`, the path is `computations/C-NNN.md`. Confirm the file exists.

2. **Write a small dispatch brief** *inline in the task string* (no separate file needed for reviews — the relevant ER + Conventions are short). Include only:
   - The target file path.
   - Relevant **Established Results** from `research_log.md` (by ID + one-line restatement) the reviewer needs as cross-checks.
   - Relevant **Conventions** from `research_log.md`.
   - Specific reference file paths cited in the target.

   **No priors.** Do not leak prior reviewer verdicts, objections, or framing for follow-up reviews on the same target. Target file path and named references only.

3. **Dispatch the `reviewer` sub-agent** via the `subagent` tool:

   ```json
   {
     "tasks": [
       {
         "agent": "reviewer",
         "task": "Review the target file <derivations/D-NNN.md | computations/C-NNN.md> per .pi/agents/reviewer.md. Read the entire file but skip its ## Reviews section. Form an independent verdict (confirmed / refuted / inconclusive). Append your verdict under ## Reviews using the edit tool. Return the structured ## Summary / ## Result / ## Flags directly to me; do not write a separate review file. Cross-check inputs (Established Results, Conventions, references) follow."
       }
     ],
     "concurrency": 1,
     "failFast": false
   }
   ```

   Note: no `output` field — the reviewer edits the target file rather than producing a new artefact. Append the cross-check inputs (ER, Conventions, references) as additional text in the `task` string.

4. **Second-opinion reviews** are separate `subagent` calls. On key results, refutations, or major critique findings that would change direction, dispatch a fresh `/review` to a different sub-agent without leaking the prior verdict.

5. **Run the integration loop** when the reviewer returns:
   - Read the verdict from the reviewer's structured return.
   - Update the source list in `research_log.md` (e.g., `sources: D-007 (review: confirmed)`).
   - On `refuted` or `inconclusive`, do **not** unilaterally demote — seek a second opinion before acting (see AGENTS.md §3 Checks and balances).
   - Disposition every flag in `notes/flags.md`.
   - Commit as `review(<target-id>): <verdict, one line>`.
