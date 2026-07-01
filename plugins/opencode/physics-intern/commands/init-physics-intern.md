---
description: Scaffold a PhysicsIntern research workspace in the current folder
agent: build
---
The bundled bootstrap script has just run; its output is below.

!`bash "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/physics-intern/scripts/plugin-init.sh"`

This is a purely mechanical bootstrap. The script above already rendered the workspace, scaffolded the directories, and made the first git commit — the entire job in one command. Do **exactly** the following and nothing more: do not read, copy, render, or create any files yourself, and do not narrate steps.

Read the script's final `RESULT:` line, then:

- If it contains **`RESULT: initialized`**, print the following message **verbatim** and then stop — add nothing else, no file lists, no extra suggestions:

  > ✅ **PhysicsIntern workspace initialized.** Two steps to begin:
  >
  > 1. **Edit `problem.md`** — fill in the problem setup and main question.
  > 2. **Exit and restart OpenCode in this folder**, then run `/survey`.

- If it contains **`RESULT: already-initialized`**, tell the user this folder already contains a PhysicsIntern workspace and was left untouched, and stop.

- If there is no `RESULT:` line, show the script's output to the user and stop. (If OpenCode declined to run the shell command, re-run this command and approve the `bash` prompt — do not fall back to doing the work by hand.)
