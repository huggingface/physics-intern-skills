---
name: compute
description: Symbolic and numerical computation for a target claim, in a fresh-context sub-agent. Default backend SymPy + NumPy. Runs symbolic and numerical paths together when both are feasible and flags disagreements. Writes computations/C-NNN.{md,py}.
---

# Compute

Run the `/compute` workflow. The slash command expands the full workflow instructions in the active session.

Agents used: `computer`.

Output: `computations/C-NNN.md` (narrative) + `computations/C-NNN.py` (executed script). Brief written to `computations/.briefs/C-NNN-brief.md` before dispatch.
