# PhysicsIntern project

In this repo we develop and maintain the core methodology and skills for PhysicsIntern, a framework for using AI agents to conduct physics research. It currently supports Claude Code, OpenAI Codex CLI, Pi, and Hermes Agent hosts.

- **For user-facing context** (what PhysicsIntern is, install/launch, hosts, slash-command reference, what a workspace looks like at runtime): see [`README.md`](README.md).
- **For developer documentation** (repo layout, render pipeline, agent/skill authoring contracts, host glue, design choices, how to add a new host/agent/skill, the audit workflow): see [`DOCUMENTATION.md`](DOCUMENTATION.md).

When the user asks a "how does this work" question, decide which doc fits before answering — if they're using PhysicsIntern, read `README.md`; if they're editing the methodology, read `DOCUMENTATION.md`. Most methodology-edit tasks are covered there in detail.

## Rules

- **Maintenance.** Update this file CLAUDE.md, README.md, DOCUMENTATION.md after any major change. 
- **Do not over-engineer the skills.** The goal is a robust system that works on new problems. Skill prompts should be as simple as possible while still being effective. Avoid complex, verbose, or ad-hoc instructions that aren't essential to the core methodology.
- **Source-of-truth is `commons/` + `hosts/<host>/`.** Methodology edits go there — `commons/` for host-agnostic agents, skills, and workspace doc; `hosts/<host>/` for host-specific glue (tool names, frontmatter shape, dispatch syntax). Rendered workspaces (e.g. under `workspaces/`) are snapshots — re-render rather than backporting edits.
- **Render before testing changes.** After editing anything under `commons/` or `hosts/`, run `bash init-physics-intern.sh --host=<host> <tmpdir>` (or call `commons/render.py` directly) to verify the output before committing.

## Development skills

The `investigate-run` skill (`.claude/skills/investigate-run/SKILL.md`) audits an existing PhysicsIntern workspace and produces a post-mortem of the research process — strengths, weaknesses, methodology adherence, areas for improvement. See [`DOCUMENTATION.md`](DOCUMENTATION.md#auditing-a-run-investigate-run) for when and how to use it.
