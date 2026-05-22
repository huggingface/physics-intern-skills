---
name: derive
description: Analytical derivation for a target claim or open question, in a fresh-context sub-agent that uses only what is dispatched via a brief file. Writes derivations/D-NNN.md with the derivation, assumptions, and sanity checks.
agent: deriver
arguments_hint: <target claim>
artefact_kind: D-NNN
brief: derivations/.briefs/D-NNN-brief.md
output_pattern: derivations/D-NNN.md
---

Perform an analytical derivation. The `deriver` sub-agent works only from what you put in a brief file plus the workspace `problem.md`. You write the brief; you dispatch; you integrate.

## Steps

1. **Determine the next `D-NNN` number.** List `derivations/D-*.md` and add 1; zero-pad to 3 digits (`D-001`, `D-002`, …).

2. **Write the brief** at `derivations/.briefs/D-NNN-brief.md`. Include only:
   - The target claim or question, stated concretely.
   - Relevant **Established Results** from `research_log.md` the deriver may need (by ID and one-line restatement).
   - Relevant **Conventions** from `research_log.md`.
   - Specific reference file paths (`references/<id>.{md,pdf,tex}`) that bear on the target.
   - Any prior `D-NNN.md` or `C-NNN.md` whose result is a load-bearing input — by path, not by re-statement.

   **No steering, no priors.** Do not signal an expected answer or preferred direction.

3. **Dispatch the `deriver` sub-agent**, passing the brief path and the output path. See {{workspace_doc}} §3 (Dispatch syntax) for the exact tool invocation. The deriver reads the brief, follows its role definition in `{{agents_dir}}/deriver{{agent_ext}}`, and writes `derivations/D-NNN.md` with the structured `## Summary` / `## Result` / `## Flags` at the top.

4. **Run the integration loop** when the deriver returns:
   - Read `## Summary` / `## Result` / `## Flags` from `derivations/D-NNN.md`.
   - Add or update a Working Claim in `research_log.md` citing `D-NNN`.
   - Disposition every flag in `notes/flags.md`.
   - Commit as `derive(D-NNN): <one-line summary>`.

5. **Next dispatch is `/review D-NNN`** unless the integration loop surfaced a reason to defer. Do not chain another `/derive` or `/compute` without intervening review.
