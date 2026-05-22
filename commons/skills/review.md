---
name: review
description: Adversarial review of a derivation (D-NNN) or computation (C-NNN), in a fresh-context reviewer sub-agent that sees only the target's # Task and ## Derivation / ## Computation — never prior reviews.
agent: reviewer
arguments_hint: <D-NNN | C-NNN target id>
---

Run an independent adversarial review on a target artefact. The `reviewer` sub-agent writes a sibling review file `derivations/D-NNN_RM.md` (or `computations/C-NNN_RM.md`) carrying the verdict (`confirmed` / `refuted` / `inconclusive`). Each review starts fresh — no prior verdicts are passed.

## Steps

1. **Resolve the target path.** For `D-NNN`, the path is `derivations/D-NNN.md`. For `C-NNN`, the path is `computations/C-NNN.md`. Confirm the file exists.

2. **Assemble a small dispatch context** (no separate brief file — the relevant ER + Conventions are short enough to pass inline). Include only:
   - The target file path.
   - Relevant **Established Results** from `research_log.md` (by ID + one-line restatement) the reviewer needs as cross-checks.
   - Relevant **Conventions** from `research_log.md`.
   - Specific reference file paths cited in the target.

   **No priors.** Do not leak prior reviewer verdicts, objections, or framing for follow-up reviews on the same target. Target file path and named references only.

3. **Dispatch the `reviewer` sub-agent**, passing the target file path inline plus the cross-check context. See {{workspace_doc}} §3 (Dispatch syntax) for the exact tool invocation. The reviewer reads the target file in full, does NOT read any sibling `_R*.md` review files, forms an independent verdict, computes its own output path (`derivations/D-NNN_R<M>.md` or `computations/C-NNN_R<M>.md` where `M = (count of existing matching siblings) + 1`), and writes the verdict file there with YAML frontmatter and prose body per `{{agents_dir}}/reviewer{{agent_ext}}`.

4. **Second-opinion reviews** are separate dispatches. On key results, refutations, or major critique findings that would change direction, dispatch a fresh `/review` to a different sub-agent without leaking the prior verdict. The second review will automatically claim the next `_R<M+1>` slot.

5. **Run the integration loop** when the reviewer returns:
   - Read the verdict from the reviewer's structured return (and confirm the new `_R<M>.md` file exists).
   - Update the source list in `research_log.md` (e.g., `sources: D-007 (review: confirmed)` for a single review, or `D-002 (R1: refuted, R2: confirmed)` for multiple).
   - On `refuted` or `inconclusive`, do **not** unilaterally demote — seek a second opinion before acting (see {{workspace_doc}} §3 Checks and balances).
   - Disposition every flag in `notes/flags.md`.
   - Commit as `review(<target-id>_R<M>): <verdict, one line>`.
