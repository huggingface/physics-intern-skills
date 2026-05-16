---
name: critique
description: Strategic critique of the overall research state, in a fresh-context sub-agent. Reads research_log.md (esp. Established Results, Working Claims, Dead Ends), plan.md, and may spot-check artefacts. Identifies strategic drift, plan-viability issues, coherence problems, under-sourced claims, citation gaps. Writes critiques/CR-NNN.md.
context: fork
agent: critic
---

Run a strategic critique of the research state.

Dispatched context (one-line summaries of prior critiques, plus any specific focus the main agent has):

$ARGUMENTS

Follow your role definition (see `.claude/agents/critic.md`). Read `research_log.md` (with particular attention to Established Results), `plan.md`, and the prior-critique one-liners. Spot-check individual artefacts as needed. Findings must be concrete and actionable.

Write `critiques/CR-NNN.md` (next available number, YAML frontmatter `filed:` + `status: pending`, then `## Findings` and an empty `## Resolution`). Return the structured reply with findings in `## Result`.

The main agent runs the integration loop (see `CLAUDE.md`) after this skill returns. Your responsibility ends with the structured reply — do not commit, do not edit `research_log.md` or `notes/flags.md`.
