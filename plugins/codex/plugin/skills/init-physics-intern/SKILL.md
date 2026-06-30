---
name: init-physics-intern
description: Scaffold a PhysicsIntern research workspace in the current folder. Run only when the user explicitly invokes it to set up a new physics/maths research workspace.
---

This is a purely mechanical bootstrap. Do **exactly** the following and nothing more — do not read, copy, render, or create any files yourself, and do not narrate steps:

1. First, print this line **verbatim** to the user:

   > ⏳ Initializing the PhysicsIntern workspace. This needs **one permission approval** — the script writes `.codex/` and runs `git init`, which the sandbox keeps read-only by default. Please approve it when prompted.

2. Then run the bundled init script, with no arguments, using the shell tool — a single command:

   ```
   bash "${PLUGIN_ROOT}/scripts/plugin-init.sh"
   ```

   The script renders the workspace, scaffolds the directories, and makes the first git commit — it does the entire job in one command. It writes to `.codex/` and runs `git init`/`git commit`, which the workspace-write sandbox blocks, so Codex will ask for approval — that is expected; approve it. Do not fall back to doing the work by hand if it is denied — just re-run the same script with approval.

3. Read the script's final `RESULT:` line, then:

   - If it contains **`RESULT: initialized`**, print the following message **verbatim** and then stop — add nothing else, no file lists, no extra suggestions:

     > ✅ **PhysicsIntern workspace initialized.** Two steps to begin:
     >
     > 1. **Edit `problem.md`** — fill in the problem setup and main question.
     > 2. **Exit and restart Codex in this folder** (accept the project-trust prompt on first launch), then run `$survey`.

   - If it contains **`RESULT: already-initialized`**, tell the user this folder already contains a PhysicsIntern workspace and was left untouched, and stop.

   - If there is no `RESULT:` line, show the script's output to the user and stop.
