---
name: init-physics-intern
description: Scaffold a PhysicsIntern research workspace in the current folder.
disable-model-invocation: true
---

The PhysicsIntern initializer script is located at:

!`echo "${CLAUDE_PLUGIN_ROOT}/scripts/plugin-init.sh"`

This is a purely mechanical bootstrap. Do **exactly** the following and nothing more — do not read, copy, render, or create any files yourself, and do not narrate steps:

1. First, print this line **verbatim** to the user:

   > ⏳ Initializing the PhysicsIntern workspace. This needs **one permission approval** — the script writes `.claude/` and runs `git init`, which the sandbox blocks by default. Please approve it when prompted.

2. Then run that one script, with no arguments, using the Bash tool. The script renders the workspace, scaffolds the directories, and makes the first git commit — it does the entire job in one command. It writes to `.claude/` and runs `git init`, which the sandbox blocks, so Claude Code will ask to run it outside the sandbox (or for permission) — that is expected; approve it. Do not fall back to doing the work by hand if it is denied — just re-run the same script with permission.

3. Read the script's final `RESULT:` line, then:

   - If it contains **`RESULT: initialized`**, print the following message **verbatim** and then stop — add nothing else, no file lists, no extra suggestions:

     > ✅ **PhysicsIntern workspace initialized.** Two steps to begin:
     >
     > 1. **Edit `problem.md`** — fill in the problem setup and main question.
     > 2. **Exit and restart Claude Code in this folder**, then run `/survey`.

   - If it contains **`RESULT: already-initialized`**, tell the user this folder already contains a PhysicsIntern workspace and was left untouched, and stop.

   - If there is no `RESULT:` line, show the script's output to the user and stop.
