# Learnings: building a Claude Code plugin

Notes from building the `physics-intern` Claude Code plugin (`/init-physics-intern`). Captures the non-obvious things — the traps that cost time — so the next plugin (e.g. a Codex variant) is faster. Items marked **(verified)** we confirmed empirically in this repo; others are from current Claude Code docs and may drift.

## The core mental model

A plugin distributes **capabilities** (skills, sub-agents, hooks, MCP servers), **not a persistent role**. There is no way for a plugin to inject a `CLAUDE.md`-style always-on system prompt — `CLAUDE.md` at a plugin root is explicitly *not* loaded as context. The "agent is immediately in its role" effect only comes from a `CLAUDE.md`/`AGENTS.md` file in the working directory.

Consequence for us: the plugin can't *be* the methodology. It can only **scaffold a workspace** (write `CLAUDE.md` + folder-local skills/agents into the current folder), exactly like the old bash script. We called this **Design A**. We rejected:

- **Design B** (ship the methodology as plugin-global skills/agents): they'd then be active in *every* project — namespace clutter + context cost everywhere. Plugin enablement *can* be scoped per-project (`enabledPlugins` in `.claude/settings.json`, `defaultEnabled:false`), but the bootstrap-vs-enable chicken-and-egg made it more machinery than it's worth.
- **A `SessionStart` hook** to auto-scaffold: hooks bundled in a plugin fire in *every* session of *every* project. Not acceptable.

## Commands are skills now

- `commands/*.md` and `skills/<name>/SKILL.md` are unified; both create `/<name>` and work the same way.
- A **user-only command** (model can't auto-invoke it) = a skill with `disable-model-invocation: true` in frontmatter.
- Plugin skills are **namespaced**: invocable as `/<plugin>:<skill>`, but the UI shows them as `/<skill> (<plugin>)`. So `plugin=physics-intern`, `skill=init-physics-intern` → displays `/init-physics-intern (physics-intern)`.
- **Naming:** avoid bare names that collide with built-ins (`/init`, `/review`, …). Even namespaced, fuzzy-autocomplete surfaces both. **(verified — a leftover user-level `/init-physics-intern` command shadowed our intent for several test rounds; always check `~/.claude/commands` and `~/.claude/skills` for stale same-name commands.)**

## The two gotchas that cost the most time

### 1. The command sandbox blocks writes to `.claude/` and `.git/` **(verified)**
Any command/bash execution runs sandboxed by default, and that sandbox **refuses to create or write `.claude/` and to run `git init`**. So a scaffolder that writes those will fail unless run outside the sandbox. There is **no way for a plugin to pre-authorize itself** out of this — it costs the user **one irreducible permission approval** per run. Budget for it; warn the user before it happens.

### 2. `${CLAUDE_PLUGIN_ROOT}` is available in `!`-blocks, NOT in model-issued Bash **(verified)**
- It **does** expand inside a command's `` !`…` `` block (which runs at skill-expansion time, before the model acts) — and in hooks/MCP configs.
- It is **not** reliably present in the environment of Bash tool calls the *model* issues.

These two combine into the working pattern below.

## The working pattern (deterministic, not agentic)

A `SKILL.md` body is a *prompt*; the model will "helpfully" improvise — especially if a step fails. Our first version put the *writing script* in a `!`-block; the sandbox killed the `.claude/` write, and the model then reconstructed the whole bootstrap file-by-file (confabulating steps). The fix:

1. **`!`-block does only sandbox-safe work** — resolve the plugin path with `` !`echo "${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh"` ``. No writes there.
2. **One script does everything** (render + scaffold + `git init` + commit). The model runs it via the **Bash tool** (where the normal permission flow lets it escape the sandbox), as a single command.
3. **Forceful, minimal instructions:** "Do exactly this and nothing more. Do not read/copy/create files yourself. Run this one script. Print this message verbatim." Hardcode the user-facing message; never let the model compose it.
4. **Warn first:** print the "needs one approval" heads-up line *before* running, so the permission prompt isn't a surprise.

### Script contract that makes this robust **(verified)**
- **Non-interactive** — no `read`/prompts (sandboxed subprocesses have no stdin).
- **Clean stdout** — emit exactly one machine-parseable line the skill keys off (`RESULT: initialized` / `RESULT: already-initialized`). Use **distinct, non-substring tokens** (don't make one a prefix of the other).
- **Capture the renderer's chatter** — our `render.py` logs to *stderr*; a `!`-block may interleave it ahead of the status line. Capture stdout+stderr of sub-steps, surface only on failure, keep the script's own stdout to the one `RESULT` line.
- **Idempotent / safe** — detect an existing workspace and refuse (no clobber), non-interactively.

## Packaging

- **Self-contained:** an installed plugin **cannot reference files outside its own root** (no `../`). Vendor everything it needs (we copy `commons/` incl. `render.py`, and `hosts/claude/`).
- **Build, don't hand-maintain the vendored copies.** Source of truth stays upstream; a `build-plugin.sh` assembles the publishable tree. Edit upstream + rebuild; never hand-edit the built repo.
- **Exclude build cruft:** `rsync -a --exclude='__pycache__' --exclude='.DS_Store'` (plain `cp -R` also chokes on sandbox-unreadable `__pycache__`). **(verified)**
- **Executable bit:** git tracks mode `100755`; it survives clone/build, so the bundled script stays runnable. Verify with `git ls-files -s`. **(verified)**

### Layout (marketplace + plugin in one repo)
```
<repo-root>/                       # the marketplace AND the plugin
├── .claude-plugin/marketplace.json   # name, owner, plugins:[{name, source:"./plugin", description}]
├── README.md                         # the repo's GitHub landing page
└── plugin/
    ├── .claude-plugin/plugin.json    # name, version (semver), description, author, homepage, repository
    ├── skills/<cmd>/SKILL.md         # the command (disable-model-invocation:true)
    ├── scripts/<init>.sh             # non-interactive scaffolder
    └── <vendored templates>          # whatever the script needs, all under plugin root
```
Note: `marketplace.json` goes in `.claude-plugin/`; the command/skill/agent dirs do **not** — they sit at the plugin root.

## Publish & update

- **Install (user side):**
  ```
  /plugin marketplace add <owner>/<repo>
  /plugin install <plugin-name>@<marketplace-name>
  ```
  `<marketplace-name>` is the `name` field in `marketplace.json` (not the repo name). For us: `/plugin install physics-intern@physics-intern-claude`.
- **Versioning is all-or-nothing:** if `plugin.json` sets `version`, you **must bump it every release** or `/plugin update` reports "already latest". (Alternative: omit `version` → every commit SHA counts as an update, no human-readable version.)
- **Author update flow:** edit upstream → `build-plugin.sh` → bump `version` → commit + push the plugin repo. Users get it at session start or via `/plugin update`.

## Reload / restart semantics (why our flow needs a restart)

- **`CLAUDE.md`**: read at startup; re-read on `/clear` (and `/compact`). Not hot-reloaded.
- **Standalone (folder) `.claude/skills` + `.claude/agents`**: discovered **only on full restart**. No hot-reload, and `/clear` doesn't pick them up.
- **Plugin skills/agents**: `/reload-plugins` (or restart) after install/enable changes.

Because Design A writes *folder-local* skills/agents, the bootstrap command tells the user to **exit and restart Claude Code** in the folder — that's what registers them and loads the new `CLAUDE.md`. `/clear` alone is not enough here.

## Testing & pitfalls

- **Local test without publishing:** `claude --plugin-dir <path>/plugin` in a scratch folder, then invoke the command. `claude plugin validate <path>` checks the manifest.
- **Test OUTSIDE the dev repo.** A scratch folder *inside* this repo inherits the repo's `.claude/settings*` sandbox rules and behaves differently. **(verified — this masked the real behavior early on.)**
- **Pointing `--plugin-dir` at the wrong path fails silently** — the namespaced command just won't exist (`Unknown command`), and a stale same-name command may run instead. If a command "doesn't behave like your code," first confirm *which* command actually ran (check the `(plugin)` vs `(user)` tag in autocomplete). **(verified — this wasted a couple rounds.)**

## Building the Codex plugin (verified on Codex v0.136.0-alpha.1)

We built the Codex variant (`/physics-intern:init-physics-intern` → `$physics-intern:init-physics-intern`). The headline: **Codex has converged hard with Claude Code** — it now ships a first-class plugin + marketplace system, Skills, lifecycle Hooks, and Subagents. So the Codex plugin is a near-mechanical port of the Claude one, same **Design A** (plugin = thin delivery vehicle for the workspace bootstrap; Design B rejected for the same reasons).

### What carried over unchanged
- **Design A.** A plugin still can't inject an always-on role (`AGENTS.md`, like `CLAUDE.md`, is a working-dir file, not a plugin capability). Scaffold the workspace; don't ship the methodology as global skills.
- **One irreducible approval.** Codex's `workspace-write` sandbox keeps `.codex/` and `.git/` read-only, so the scaffolder's `.codex/` writes + `git init`/commit cost exactly one approval. Warn first, same as Claude.
- **The script-does-everything pattern.** One non-interactive `plugin-init.sh`, single `RESULT:` line, idempotent no-clobber. Reused verbatim (only `host=codex`, the `.codex`+`AGENTS.md` workspace probe, and the success message differ).
- **Self-contained vendoring + build script.** `build-codex-plugin.sh` mirrors `build-plugin.sh`; vendors `commons/` + `hosts/codex/`; exec bit survives (`100755`).

### The Codex-specific differences that matter
- **`${PLUGIN_ROOT}` IS available in model-issued shell.** This is the big one: the Claude gotcha (`${CLAUDE_PLUGIN_ROOT}` only expands in an expansion-time `` !`…` `` block, not in model Bash) **does not apply to Codex** — `${PLUGIN_ROOT}` expanded correctly in the skill's shell call (`bash "${PLUGIN_ROOT}/scripts/plugin-init.sh"`). No `!`-block trick needed. (Codex also keeps `CLAUDE_PLUGIN_ROOT` for back-compat.) We still self-locate from `${BASH_SOURCE[0]}` in the script as a belt-and-braces measure.
- **User-only = `agents/openai.yaml`, not frontmatter.** Codex `SKILL.md` frontmatter is just `name` + `description`; there is no `disable-model-invocation`. To make the scaffolder user-only, drop a sibling `agents/openai.yaml` with `policy.allow_implicit_invocation: false`. Verified: the skill never auto-fired and ran only on explicit `$physics-intern:init-physics-intern`.
- **Manifest + marketplace paths differ.** `plugin.json` lives in `.codex-plugin/` (JSON, paths relative + `./`-prefixed, `"skills": "./skills/"`); the marketplace file is `.agents/plugins/marketplace.json` (`plugins[].source = {source:"local", path:"./plugin"}` for local, `git-subdir` for published). Install CLI: `codex plugin marketplace add <owner>/<repo>` (or a local dir) → `codex plugin add <name>@<marketplace>`; also `list` / `marketplace upgrade` / `remove`. Installed cache: `~/.codex/plugins/cache/$MARKETPLACE/$PLUGIN/$VERSION/`.
- **Skills are `$name`, invoked explicitly OR implicitly OR by plain language.** Codex matches a skill by its `description` — our test run kicked off the methodology with literally "please perform the autoresearch" (no slash, no `$`). The repo's `/survey`-style notation is just a label the agent resolves; the real explicit form is `$survey`.
- **Subagents drifted, then we re-aligned.** Current Codex auto-discovers roles from `.codex/agents/*.toml` (`name`/`description`/`developer_instructions`) — **no `config.toml` registration**, enabled by default. The old `[agent_roles.*]` table and `multi_agents_v2` namespace are gone. Real dispatch signatures (confirmed from a session log, not docs): `spawn_agent({agent_type, message, fork_context})` → returns an agent id; `wait_agent({targets:[id], timeout_ms})`. Subagent completions arrive as `<subagent_notification>` user-injected messages carrying `agent_path`.
- **Custom prompts (`~/.codex/prompts/`) are deprecated** in favour of Skills — don't build distribution on them.

### Lesson reinforced
The single highest-value verification step was **reading the live session JSONL** (`~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`): it exposed that our `dispatch_example.md` had drifted params (`task_name`/`fork_turns`) that the docs alone wouldn't have caught — the run only worked because Codex's model read the real tool schema and ignored our wrong example.

## Caveat: remaining hosts

OpenCode/Pi have analogous but different mechanisms. Their plugin/reload specifics were researched but **not empirically verified here** — re-check against live docs before building those variants. (Codex, above, *is* now verified.)
