# PhysicsIntern — OpenCode plugin

Bootstrap a **PhysicsIntern** research workspace in one command, from inside OpenCode.

PhysicsIntern is a methodology for using an AI coding agent to conduct theoretical physics and mathematics research. You write a question into `problem.md`; the agent then surveys the literature, drafts a plan, dispatches analytical derivations and numerical computations to fresh-context sub-agents, reviews each result, and synthesises an answer — committing after every step.

## Install

OpenCode has no plugin marketplace, and its JS plugins can register only tools and hooks — not slash commands. So this ships as a **global command + a one-time installer**: clone this repo and run the installer.

```
git clone https://github.com/huggingface/physics-intern-opencode-plugin
cd physics-intern-opencode-plugin
./install.sh
```

This copies a global `/init-physics-intern` command and a vendored scaffolder kit into your OpenCode config dir (`${XDG_CONFIG_HOME:-~/.config}/opencode/`). Restart OpenCode afterwards so the command registers. Re-running `./install.sh` upgrades an existing install in place.

## Use

In a fresh, empty folder for your research problem:

```
opencode
> /init-physics-intern    # scaffolds the workspace (may ask once to run a shell command)
```

Then:

1. **Edit `problem.md`** — fill in the problem setup and the main question.
2. **Exit and restart OpenCode in the folder** — so the workspace's `AGENTS.md`, commands, sub-agent roles, and `opencode.json` load.
3. Run **`/survey`** to begin (or just tell OpenCode to start the autoresearch).

Files are durable state and the session is ephemeral: you can clear the context at any time and the agent resumes from `research_log.md` and `plan.md`.

## What `/init-physics-intern` scaffolds

A self-contained workspace in the current folder:

- `AGENTS.md` — the main-agent methodology (loaded each session).
- `.opencode/commands/` — `/survey`, `/research-plan`, `/derive`, `/compute`, `/review`, `/critique`, `/finalize`, `/autoresearch`.
- `.opencode/agents/` — the sub-agent role definitions (`mode: subagent`, auto-discovered).
- `opencode.json` — workspace permissions.
- `problem.md`, `research_log.md`, and artefact directories (`derivations/`, `computations/`, `critiques/`, `notes/`, `references/`, `data/`).
- An initial git commit.

## Notes

- **Sub-agent dispatch is version-dependent.** Dispatching *custom* sub-agents (the roles above) via the `task` tool or `@mention` has been limited in some OpenCode builds — `subagent_type` was hardcoded to the built-ins `explore`/`general`/`mary` (see opencode issue #29616). If your build can't dispatch the custom roles, the workspace `AGENTS.md` explains the fallback: run each role in the main-agent context from its role file. Verify on your version.
- The installer only adds the user-invoked `/init-physics-intern` command globally. The methodology commands and sub-agent roles are scaffolded **into each workspace**, not added to your other projects.
- This repository is a generated build artifact. The methodology source of truth lives upstream and is assembled here by `build-opencode-plugin.sh` — edit upstream, not here.
