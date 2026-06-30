# PhysicsIntern — Codex CLI plugin

Bootstrap a **PhysicsIntern** research workspace in one command, from inside Codex.

PhysicsIntern is a methodology for using an AI coding agent to conduct theoretical physics and mathematics research. You write a question into `problem.md`; the agent then surveys the literature, drafts a plan, dispatches analytical derivations and numerical computations to fresh-context sub-agents, reviews each result, and synthesises an answer — committing after every step.

## Install

```
codex plugin marketplace add huggingface/physics-intern-codex-plugin
codex plugin add physics-intern@physics-intern-codex
```

Restart Codex afterwards so the skill registers.

## Use

In a fresh, empty folder for your research problem:

```
codex
> $init-physics-intern        # scaffolds the workspace (asks for one approval)
```

Then:

1. **Edit `problem.md`** — fill in the problem setup and the main question.
2. **Exit and restart Codex in the folder** and accept the project-trust prompt on first launch — so the workspace's `AGENTS.md`, skills, sub-agent roles, and `.codex/config.toml` (sandbox + web search) load.
3. Run **`$survey`** to begin (or just tell Codex to start the autoresearch).

Files are durable state and the session is ephemeral: you can clear the context at any time and the agent resumes from `research_log.md` and `plan.md`.

## What `$init-physics-intern` scaffolds

A self-contained workspace in the current folder:

- `AGENTS.md` — the main-agent methodology (loaded each session once the project is trusted).
- `.agents/skills/` — `$survey`, `$research-plan`, `$derive`, `$compute`, `$review`, `$critique`, `$finalize`, `$autoresearch`.
- `.codex/agents/` — the sub-agent role definitions (auto-discovered; dispatched via `spawn_agent`/`wait_agent`).
- `.codex/config.toml` — workspace sandbox + web-search settings.
- `problem.md`, `research_log.md`, and artefact directories (`derivations/`, `computations/`, `critiques/`, `notes/`, `references/`, `data/`).
- An initial git commit.

The one approval is expected: the script writes `.codex/` and runs `git init`, which Codex's workspace-write sandbox keeps read-only by default.

## Notes

- The plugin only adds the user-invoked `$init-physics-intern` skill. The methodology skills and sub-agent roles are scaffolded **into each workspace**, not added to your other projects.
- This repository is a generated build artifact. The methodology source of truth lives upstream and is assembled here by `build-codex-plugin.sh` — edit upstream, not here.
