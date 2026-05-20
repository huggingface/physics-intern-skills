# PhysicsIntern project

In this repo, we develop and maintain the core methodology and skills for PhysicsIntern, a framework for using AI agents (like Claude Code) to conduct physics research.

## Rules

- **Do not over-engineer the skills**. The goal is to have a robust system that works with new problems. The skills prompts should be as simple as possible while still being effective. Avoid adding complex, verbose or ad-hoc instructions that are not essential to the core methodology.

## Repository structure

- `init-physics-intern.sh` is the bootstrapping script that sets up a new PhysicsIntern workspace. It takes a `--host=claude|pi` flag (default `claude`) and copies the matching template into the target directory, then initializes git version control.
- `templates/` is the Claude Code template (workspace `CLAUDE.md`, `.claude/agents/`, `.claude/skills/`, `research_log.md`).
- `templates-pi/` is the experimental Pi template (workspace `AGENTS.md`, `.pi/agents/`, `.pi/settings.json`, `package.json`, `skills/`, `prompts/`, `research_log.md`). Mirrors `templates/` in methodology content; differs only in host-specific glue. See README §Next Steps.
- `workspaces/` contains example PhysicsIntern workspaces.

## Development skills

The `investigate-run` skill allows you to audit an existing PhysicsIntern workspace and do a post-mortem analysis of the research process, identifying strengths, weaknesses, and areas for improvement.