---
name: critique
description: Strategic critique of the overall research state, in a fresh-context critic sub-agent. Identifies strategic drift, plan-viability issues, coherence problems, under-sourced claims, citation gaps.
agent: critic
arguments_hint: "[optional focus from main agent]"
dispatch_kind: critique
artefact_kind: CR-NNN
artefact_dir: critiques
output_pattern: critiques/CR-NNN.md
---

Run a strategic critique. The `critic` sub-agent reads `research_log.md` and `plan.md`, spot-checks artefacts as needed, and files findings in `critiques/CR-NNN.md`. Findings are proposals — you disposition each.

## Steps

1. **Determine the next `CR-NNN` number.** List `critiques/CR-*.md` and add 1; zero-pad.

2. **Collect one-line summaries of prior critiques** to pass to the new critic. For each existing `critiques/CR-MMM.md`, extract one line: the filed date and headline finding. This prevents repetition but does not leak full prior analyses.

3. **Dispatch the `critic` sub-agent**, passing the prior-critique one-liners and any focus from the user inline. See {{workspace_doc}} §3 (Dispatch syntax) for the exact tool invocation. The critic reads `research_log.md` (esp. Established Results), `plan.md`, spot-checks artefacts as needed, follows its role definition in `{{agents_dir}}/critic.md`, and writes `critiques/CR-NNN.md` with YAML frontmatter (`filed: YYYY-MM-DD`, `status: pending`), `## Findings`, and an empty `## Resolution`. The structured `## Summary` / `## Result` / `## Flags` goes at the top.

4. **Run the integration loop** when the critic returns:
   - Read `## Summary` / `## Result` / `## Flags` from `critiques/CR-NNN.md`.
   - **Do not act on findings unilaterally.** Disposition each finding inline in the critique file's `## Resolution` section (resolve / dismiss / defer with a reason). Update the YAML `status:` field accordingly.
   - For findings that imply a strategy-level change, re-invoke `/research-plan` after the critique commit lands.
   - Disposition any general flags in `notes/flags.md`.
   - Commit as `critique(CR-NNN): <one-line summary>`.

5. **Checks and balances.** Before acting on a major critique finding that would substantially change direction, seek a second opinion — another `/critique` or a confirming `/review` — per {{workspace_doc}} §3.
