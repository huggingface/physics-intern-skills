# Research Log: {{PROBLEM_ONELINER}}

## Open Questions

<!--
Q-NNN entries — concrete questions awaiting resolution.

Format:
- Q1: <one-line statement>
  - status: pending /derive | pending /compute | resolved → W3 | dropped
-->

## Working Claims

<!--
W-NNN entries — claims with ≥1 source, not yet promoted to Established.
Promotion to Established requires evidence robust against typical failure modes
(conceptual, transcription, sign/factor) — usually ≥2 independent dispatch contexts.
See hygiene rule 2 in {{workspace_doc}}.

Format:
- W1: <claim, with concrete value or expression>
  - sources: D-002 (review: confirmed), C-001 (no review yet)
  - depends on: E2

If a target has multiple reviews, list each by R-number with its verdict:
  - sources: D-002 (R1: refuted, R2: confirmed), C-001 (review: confirmed)

Review evidence lives in sibling files (`derivations/D-NNN_RM.md`, `computations/C-NNN_RM.md`).
The annotation above is the index; the evidence file is the record.
-->

## Established Results

<!--
E-NNN entries — claims promoted via robust evidence (see hygiene rule 2).
Kept to one-liners once stable. If only one approach was available, record why
alongside the source list.

Format:
- E1: <claim>
  - sources: D-001 (review: confirmed), MTW §31.2, C-003 (cross-check)
-->

## Dead Ends

<!--
Approaches that did not work, compacted to one-liners.
NEVER remove entries here — they prevent re-walking.

Example:
- Euclidean Wick rotation on time coordinate — metric goes complex at horizon. See notes/wick-attempt.md.
-->

## Conventions

<!--
Notation, units, signature, etc. Stable across the run.
Example:
- ℏ = c = 1
- Metric signature (−,+,+,+)
- Greek indices: spacetime 0..3; Latin indices: spatial 1..3
-->

## Sanity Checks

<!--
Properties the final answer must satisfy. Useful as guardrails.
Example:
- The answer must reduce to <known limit> when <parameter> → 0.
- Dimensional analysis: result has units of [...].
-->
