# PhysicsIntern project

In this repo, we develop and maintain the core methodology and skills for PhysicsIntern, a framework for using AI agents (like Claude Code) to conduct physics research.

## Repository structure

- `DESIGN.md` outlines the overall design and philosophy of the PhysicsIntern methodology, including the role of the main agent, sub-agents, and the research workflow.
- `init-physics-intern.sh` is the bootstrapping script that sets up a new PhysicsIntern workspace. It copies the necessary template files and directories from `templates`, including a dedicated `CLAUDE.md`, `research_log.md`, the `.claude/` skill and agent definitions, and initializes git version control.
- `workspaces` contains example PhysicsIntern workspaces.

## Development skills

The `investigate-run` skill allows you to audit an existing PhysicsIntern workspace and do a post-mortem analysis of the research process, identifying strengths, weaknesses, and areas for improvement.