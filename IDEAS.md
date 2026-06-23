# Ideas

Methodology patterns observed in workspace runs that are worth promoting into the templates. Each entry: what it is, why it helps, where it should live.

## Two-role critique pattern

**Idea.** `/critique` has two distinct uses, and a good run does both:

- **Steering critique** — mid-stream, after the first computational result. Its output feeds concrete refinements into the *next* dispatch brief (extra regressions, alternative method, sharper scope).
- **Audit critique** — pre-finalize, after all Established Results are in. Endorses or refutes the pipeline as a whole; gatekeeps `/finalize`.

**Why.** A single late critique can only audit; it cannot shape the work. A mid-stream critique that feeds the next brief produces materially better downstream computations (observed in qec-pi: CR-001 added an 8-bin classifier, 3 regressions, and a 32×32 spot-check to the C-002 brief).

**Where.** Rewrite `templates/CLAUDE.md` §1 to describe the two roles explicitly, and `templates-pi/AGENTS.md` likewise. The current "every few state changes" guidance is too vague to produce this pattern reliably.
