---
name: finalize
description: Synthesise answer.md — the final research deliverable — from Established Results and supporting artefacts. Runs in a fresh-context finalizer sub-agent.
agent: finalizer
arguments_hint: "[optional emphasis from main agent]"
dispatch_kind: direct
output_pattern: answer.md
---

Synthesise the final answer. The `finalizer` sub-agent reads `research_log.md`, `problem.md`, `plan.md`, and selectively traces into `derivations/`, `computations/`, `critiques/`, `references/`. The load-bearing inputs are the **Established Results** in `research_log.md`.

## Steps

1. **Sanity-check before dispatch.** The Established Results in `research_log.md` should carry the answer. If they don't — if the answer depends on Working Claims that haven't been promoted — pause and tell the user. `/finalize` will still produce an honest partial answer, but the user should know.

2. **Dispatch the `finalizer` sub-agent**, passing any optional emphasis (areas to highlight, audience hints, length guidance) inline. See {{workspace_doc}} §3 (Dispatch syntax) for the exact tool invocation. The finalizer follows its role definition in `{{agents_dir}}/finalizer.md`, traces citations into the relevant artefacts and references, and writes `./answer.md`. The structured `## Summary` / `## Result` / `## Flags` goes at the top of `answer.md`.

3. **Run the integration loop** when the finalizer returns:
   - Read `## Summary` / `## Result` / `## Flags` from `answer.md`.
   - Disposition every flag in `notes/flags.md`. Suggestions for additional review before publishing may translate to one more `/review` or `/critique` cycle.
   - Commit as `finalize: <one-line summary>`.
   - Present the headline result to the user.
