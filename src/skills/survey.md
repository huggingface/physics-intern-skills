---
name: survey
description: Research-landscape survey for the problem in problem.md. Forks a fresh-context surveyor sub-agent.
agent: surveyor
arguments_hint: "[optional user hints]"
dispatch_kind: direct
output_pattern: survey.md
---

Run a research-landscape survey for the problem stated in `./problem.md`. The substantive work happens inside the `surveyor` sub-agent (fresh context). You stay in the loop only as coordinator.

## Steps

1. **Confirm the workspace is ready.** `./problem.md` must exist and `./{{workspace_doc}}` must no longer contain `{{PROBLEM_ONELINER}}`. If the placeholder is still present, tell the user to run `/start-research` first and stop.

2. **Dispatch the `surveyor` sub-agent**, passing any user hints inline. See {{workspace_doc}} §3 (Dispatch syntax) for the exact tool invocation. The surveyor reads `./problem.md`, follows its role definition in `{{agents_dir}}/surveyor.md`, runs web/arxiv search, and writes `./survey.md` with sections: Background, Question framing (only if there is a load-bearing disagreement), Known approaches, Known pitfalls, Key references. The structured `## Summary` / `## Result` / `## Flags` goes at the top of `survey.md`.

   Do **not** put multi-paragraph instructions in the dispatch prompt; the role definition already lives in `{{agents_dir}}/surveyor.md` and the surveyor will read it.

3. **Run the integration loop** when the surveyor returns:
   - Read the `## Summary` / `## Result` / `## Flags` from `survey.md`.
   - Disposition every flag in `notes/flags.md`.
   - Commit as `survey: <one-line summary>`.
   - Present the result to the user. Suggested next step: `/research-plan`. Pause for user input — `/survey` is the first HITL gate.
