# PhysicsIntern — Claude Code plugin

Bootstrap a **PhysicsIntern** research workspace in one command, from inside Claude Code.

PhysicsIntern is a methodology for using an AI coding agent to conduct theoretical physics and mathematics research. You write a question into `problem.md`; the agent then surveys the literature, drafts a plan, dispatches analytical derivations and numerical computations to fresh-context sub-agents, reviews each result, and synthesises an answer — committing after every step.

## Install

```
/plugin marketplace add huggingface/physics-intern-claude-plugin
/plugin install physics-intern@physics-intern-claude
```

Restart Claude Code afterwards so the command registers.

## Use

In a fresh, empty folder for your research problem:

```
claude
> /init-physics-intern        # scaffolds the workspace (asks for one permission approval)
```

Then:

1. **Edit `problem.md`** — fill in the problem setup and the main question.
2. **Exit and restart Claude Code in the folder** — so the workspace's `CLAUDE.md`, skills, and sub-agents load.
3. Run **`/survey`** to begin.

Files are durable state and the session is ephemeral: you can clear the context at any time and the agent resumes from `research_log.md` and `plan.md`.

## What `/init-physics-intern` scaffolds

A self-contained workspace in the current folder:

- `CLAUDE.md` — the main-agent methodology (auto-loaded each session).
- `.claude/skills/` — `/survey`, `/research-plan`, `/derive`, `/compute`, `/review`, `/critique`, `/finalize`, `/autoresearch`.
- `.claude/agents/` — the sub-agent role definitions.
- `problem.md`, `research_log.md`, and artefact directories (`derivations/`, `computations/`, `critiques/`, `notes/`, `references/`, `data/`).
- An initial git commit.

The one permission approval is expected: the script writes `.claude/` and runs `git init`, which Claude Code's sandbox blocks by default.

## Notes

- The plugin only adds the global `/init-physics-intern` command. The methodology skills and sub-agents are scaffolded **into each workspace**, not added to your other projects.
- This repository is a generated build artifact. The methodology source of truth lives upstream and is assembled here by `build-plugin.sh` — edit upstream, not here.
