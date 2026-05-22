# PhysicsIntern project

In this repo we develop and maintain the core methodology and skills for PhysicsIntern, a framework for using AI agents to conduct physics research. See `README.md` for the full repo layout, methodology, and how a workspace runs.

## Rules

- **Do not over-engineer the skills.** The goal is a robust system that works on new problems. Skill prompts should be as simple as possible while still being effective. Avoid complex, verbose, or ad-hoc instructions that aren't essential to the core methodology.
- **Source-of-truth is `commons/` + `hosts/<host>/`.** Methodology edits go there — `commons/` for host-agnostic agents, skills, and workspace doc; `hosts/<host>/` for host-specific glue (tool names, frontmatter shape, dispatch syntax). Rendered workspaces (e.g. under `workspaces/`) are snapshots — re-render rather than backporting edits.
- **Render before testing changes.** After editing anything under `commons/` or `hosts/`, run `bash init-physics-intern.sh --host=<host> <tmpdir>` (or call `commons/render.py` directly) to verify the output before committing.

## Development skills

The `investigate-run` skill (`.claude/skills/investigate-run/SKILL.md`) audits an existing PhysicsIntern workspace and produces a post-mortem of the research process — strengths, weaknesses, methodology adherence, areas for improvement.
