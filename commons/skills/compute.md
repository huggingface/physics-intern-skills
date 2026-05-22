---
name: compute
description: Symbolic + numerical computation for a target claim, in a fresh-context sub-agent that uses only what is dispatched via a brief file. SymPy + NumPy by default. Symbolic and numerical run together when feasible; disagreement is flagged.
agent: computer
arguments_hint: <target claim>
artefact_kind: C-NNN
brief: computations/.briefs/C-NNN-brief.md
output_pattern: computations/C-NNN.md
---

Perform symbolic + numerical computation. The `computer` sub-agent writes a script, executes it, and captures the output; you write the brief and integrate the result.

## Steps

1. **Determine the next `C-NNN` number.** List `computations/C-*.md` and add 1; zero-pad to 3 digits.

2. **Write the brief** at `computations/.briefs/C-NNN-brief.md`. Include only:
   - The target claim or quantity to compute, stated concretely.
   - Relevant **Established Results** from `research_log.md` (by ID and one-line restatement).
   - Relevant **Conventions** from `research_log.md` (units, signatures, normalizations).
   - Specific reference file paths (`references/<id>.{md,pdf,tex}`) that bear on the target.
   - Any prior `D-NNN.md` or `C-NNN.md` whose result is a load-bearing input — by path, not by re-statement.
   - Any prior `data/<slug>.*` files the computer may reuse — by path only.

   **No steering, no priors.** Do not signal an expected answer or preferred direction.

3. **Dispatch the `computer` sub-agent**, passing the brief path and the output path. See {{workspace_doc}} §3 (Dispatch syntax) for the exact tool invocation. The computer reads the brief, follows its role definition in `{{agents_dir}}/computer{{agent_ext}}`, runs both symbolic and numerical paths together when feasible (flagging disagreement), writes `computations/C-NNN.py` and `computations/C-NNN.md`, and captures stdout+stderr to `computations/C-NNN.out`.

4. **Run the integration loop** when the computer returns:
   - Read `## Summary` / `## Result` / `## Flags` from `computations/C-NNN.md`.
   - Add or update a Working Claim in `research_log.md` citing `C-NNN`.
   - Note any new `data/<slug>.*` files mentioned in `## Data outputs` in `research_log.md` Conventions or near the relevant claim.
   - Disposition every flag in `notes/flags.md`.
   - Commit as `compute(C-NNN): <one-line summary>` — include the `.py` script and the `.out` log in the commit.

5. **Next dispatch is `/review C-NNN`** unless the integration loop surfaced a reason to defer.
