---
name: start-research
description: Bootstrap research from problem.md. One-time prep that extracts a one-line summary and substitutes the {{PROBLEM_ONELINER}} placeholders in AGENTS.md and research_log.md. Runs in main-agent context (no fork).
---

# Start research

Run the `/start-research` workflow. The slash command expands the full workflow instructions in the active session.

Agents used: none (runs in main-agent context).

Output: substituted `AGENTS.md` and `research_log.md`, plus one commit.
