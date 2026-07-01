# PhysicsIntern — Developer Documentation

This document is for contributors working on the PhysicsIntern methodology itself: adding or editing agents, skills, and hosts; understanding the render pipeline; or auditing runs. For installation and end-user usage, see [README.md](README.md).

## Contents

1. [What this repo is (and isn't)](#what-this-repo-is-and-isnt)
2. [Repo layout](#repo-layout)
3. [Architecture: commons + hosts + render](#architecture-commons--hosts--render)
4. [The render pipeline](#the-render-pipeline)
5. [Authoring agents](#authoring-agents)
6. [Authoring skills](#authoring-skills)
7. [Host glue](#host-glue)
8. [The workspace doc and research log](#the-workspace-doc-and-research-log)
9. [The bootstrap script](#the-bootstrap-script)
10. [Workspace runtime: how the methodology executes](#workspace-runtime-how-the-methodology-executes)
11. [Design choices worth remembering](#design-choices-worth-remembering)
12. [Adding a new host](#adding-a-new-host)
13. [Adding a new agent or skill](#adding-a-new-agent-or-skill)
14. [Auditing a run: `investigate-run`](#auditing-a-run-investigate-run)
15. [Validation workflow](#validation-workflow)


## What this repo is (and isn't)

This repo holds the **methodology** — the prompts, the render pipeline, and the workspace template — that turn an AI coding harness (Claude Code, Pi, Codex CLI, OpenCode) into a research collaborator for theoretical physics and mathematics. The host already provides tool-use loops, sub-agent dispatch, sandboxed Python, web search, and slash-command-as-skill; we don't rebuild those. We layer on top: structured survey, explicit plan, fresh-context derivations and adversarial reviews, strategic critique, systematic symbolic + numerical cross-checking, citation discipline.

What lives here:

- **`commons/`** — host-agnostic methodology source. The workspace doc, the seven sub-agent role prompts, the nine skill workflows, the research-log template.
- **`hosts/<host>/`** — host-specific glue: tool-name maps, frontmatter shapes, dispatch syntax, and any settings/package files that ship into a workspace.
- **`init-physics-intern.sh`** + **`commons/render.py`** — bootstrap a new workspace by rendering `commons/` through `hosts/<host>/`.
- **`.claude/skills/investigate-run/`** — the post-mortem audit skill, used while iterating on the methodology.
- **`workspaces/`**, **`problems/`**, **`references/`**, **`results/`** — sample workspaces, benchmark problem corpus, and run outputs used to drive methodology iteration.

What does **not** live here: workspace-specific research artefacts. Those are produced inside a rendered workspace (`derivations/`, `computations/`, `critiques/`, `research_log.md`, `answer.md`, …).


## Repo layout

```
physics-intern/
├── README.md                          # user-facing: install, launch, how to use
├── DOCUMENTATION.md                   # this file: developer documentation
├── CLAUDE.md                          # repo-level instructions (not for workspaces)
├── init-physics-intern.sh             # workspace bootstrap script
├── commons/                           # host-agnostic source of truth
│   ├── render.py                      # renderer: reads commons/ + hosts/<host>/
│   ├── workspace-doc.md               # body of CLAUDE.md / AGENTS.md (with placeholders)
│   ├── research_log.md                # template for the workspace research log
│   ├── gitignore                      # base .gitignore for workspaces
│   ├── agents/                        # 7 fresh-context role prompts
│   │   ├── surveyor.md
│   │   ├── planner.md
│   │   ├── deriver.md
│   │   ├── computer.md
│   │   ├── reviewer.md
│   │   ├── critic.md
│   │   └── finalizer.md
│   └── skills/                        # 8 main-agent workflow files
│       ├── survey.md
│       ├── research-plan.md
│       ├── derive.md
│       ├── compute.md
│       ├── review.md
│       ├── critique.md
│       ├── finalize.md
│       └── autoresearch.md
├── hosts/                             # host-specific glue
│   ├── claude/
│   │   ├── host.toml                  # workspace_doc, tools_map, frontmatter shape
│   │   ├── dispatch_example.md        # Task tool syntax example
│   │   └── extras/.claude/settings.json
│   ├── pi/
│   │   ├── host.toml
│   │   ├── preamble.md                # Pi tool-discipline preamble
│   │   ├── dispatch_example.md        # subagent JSON example
│   │   ├── skill_stub.md.tmpl         # layout for Pi's skills/<name>/SKILL.md stubs
│   │   ├── gitignore.extra            # node_modules/
│   │   └── extras/
│   │       ├── package.json
│   │       └── .pi/settings.json
│   ├── codex/
│   │   ├── host.toml                  # agent_format="toml"; tools collapse onto shell_command + apply_patch
│   │   ├── preamble.md                # Codex tool discipline
│   │   ├── dispatch_example.md        # spawn_agent + wait_agent example
│   │   └── extras/.codex/config.toml  # sandbox + web_search (roles auto-discover from .codex/agents/)
│   └── opencode/
│       ├── host.toml                  # skills_layout="flat"; mode=subagent; YAML+md agents, native tools
│       ├── dispatch_example.md        # Task tool (subagent_type) example
│       └── extras/opencode.json       # project config (permissions); agents/commands auto-discovered
├── .claude/skills/
│   └── investigate-run/               # repo-level audit skill
├── workspaces/                        # sample workspaces (methodology test runs and real research)
├── problems/                          # problem corpus
├── references/                        # benchmark problem corpus + helper scripts
└── results/                           # run outputs / artefacts from past methodology iterations
```


## Architecture: commons + hosts + render

The methodology is **host-agnostic**: one source tree (`commons/`) is rendered per host (`hosts/<host>/`) by `commons/render.py`. The split is simple:

- **`commons/`** carries the substance. The workspace doc, the role prompts, the skill workflows, and the research-log template are all written once. They use mustache-style placeholders (`{{workspace_doc}}`, `{{agents_dir}}`, `{{agent_ext}}`, `{{dispatch_example}}`, …) for the few host-specific values they need to reference.
- **`hosts/<host>/`** carries the glue. `host.toml` declares paths, tool-name mappings, frontmatter shape, and which extra files to load. Optional companion files: `preamble.md` (injected at the top of skills/agents), `dispatch_example.md` (the canonical dispatch syntax string), `gitignore.extra` (appended to the workspace `.gitignore`), `extras/<rel-path>` files copied verbatim into the workspace, and (Pi only) `skill_stub.md.tmpl` for the Pi two-file skill layout.

Adding a new agent or skill is one file in `commons/`. Adding a new host is one folder under `hosts/`. The renderer is the only thing that knows both sides.


## The render pipeline

`commons/render.py` is invoked by `init-physics-intern.sh`:

```bash
python3 commons/render.py --host=<host> --target=<workspace-dir>
```

It performs, in order:

1. **Load the host config** — `hosts/<host>/host.toml` plus any `file_backed` entries (e.g. `preamble = "preamble.md"`).
2. **Render agents** — one file per `commons/agents/<name>.md`. The body is substituted (`{{…}}` placeholders), and the manifest fields (`name`, `description`, `capabilities`, `output_pattern`) are projected onto the host's frontmatter or TOML role file. Capabilities are mapped to host-specific tool names via `tools_map`.
3. **Render skills** — layout depends on the host: Claude / Codex write a single-file `<skills_dir>/<name>/SKILL.md`; OpenCode writes a single **flat** `<skills_dir>/<name>.md` command (`skills_layout = "flat"`); Pi writes two files (stub under `skills/<name>/SKILL.md` + workflow under `prompts/<name>.md`) per `commons/skills/<name>.md`.
4. **Render the workspace doc** — `commons/workspace-doc.md` → `CLAUDE.md` (Claude) or `AGENTS.md` (Pi, Codex, OpenCode). Placeholders like `{{workspace_doc}}` and `{{dispatch_example}}` are substituted from the host config.
5. **Render `research_log.md`** — substituted from the same template.
6. **Render `.gitignore`** — `commons/gitignore` plus optional `hosts/<host>/gitignore.extra`.
7. **Copy host extras** — every file under `hosts/<host>/extras/` is copied to the workspace, preserving relative paths.
There is no Codex-specific registration step: current Codex auto-discovers sub-agent roles from the `.codex/agents/*.toml` files written in step 2 (older Codex used a now-removed `[agent_roles.*]` config table).

The renderer requires Python 3.11+ (`tomllib`), no third-party deps. Frontmatter parsing is intentionally minimal (top-level scalars, flow and block lists); if we ever need nested mappings or anchors we'll swap in PyYAML.

### Placeholder substitution

`substitute(text, ctx)` replaces `{{key}}` with `ctx[key]`. Unknown placeholders raise — the renderer fails fast rather than emit broken files. The available keys come from the merged host dict (everything in `host.toml` plus all `file_backed` values). Frequently used: `workspace_doc`, `agents_dir`, `agent_ext`, `dispatch_example`, `preamble`.

### Capability → tool mapping

Sub-agent role files in `commons/agents/<name>.md` declare a list of **capabilities** (`file_read`, `file_write`, `file_edit`, `shell`, `glob`, `grep`, `web_search`, `web_fetch`). The renderer translates these per-host:

| Capability | Claude | Pi | Codex | OpenCode |
|---|---|---|---|---|
| `file_read` | `Read` | `read` | `shell_command` (cat / head) | `read` |
| `file_write` | `Write` | `write` | `apply_patch` | `write` |
| `file_edit` | `Edit` | `edit` | `apply_patch` | `edit` |
| `shell` | `Bash` | `bash` | `shell_command` | `bash` |
| `glob` | `Glob` | `ls, find` | `shell_command` (find / ls) | `glob` |
| `grep` | `Grep` | `grep` | `shell_command` (grep / rg) | `grep` |
| `web_search` | `WebSearch` | `web_search` | `web_search` | `websearch` |
| `web_fetch` | `WebFetch` | `fetch_content` | `shell_command` (curl) | `webfetch` |

Duplicate-after-mapping tools are deduped (Codex collapses several capabilities onto `apply_patch` and `shell_command`). Two hosts don't carry a per-role tools allowlist: **Codex** (permissions are sandbox-scoped at the workspace level) and **OpenCode** (per-agent gating intentionally omitted — file ownership is enforced by the `AGENTS.md` prose and the agent prompts, the same trade-off as Codex). For both, the `tools_map` is informational, kept in `host.toml` to document which capability lands on which tool; the renderer never emits a `tools` field for them because `tools` is absent from their `agent_frontmatter_order`.

### Frontmatter shaping

Each host emits frontmatter in its own order and adds its own extras:

- **Claude**: `name`, `description`, `tools`. No `output:` (Claude has no native concept). No agent extras.
- **Pi**: `name`, `description`, `thinking`, `tools`, `output`. `thinking: high` is appended via `agent_extra_fields`. `output:` is the per-artefact path pattern; agents without a fixed output (e.g. reviewer) omit it.
- **Codex**: not YAML — the entire role is a TOML file with `name`, `description`, and a `developer_instructions = """…"""` multi-line string. Roles are auto-discovered from `.codex/agents/*.toml` (filename matches `name`) — no `.codex/config.toml` registration step.
- **OpenCode**: `description`, `mode`. No `name` (OpenCode derives the agent name from the filename) and no `tools` (per-role gating omitted). `mode: subagent` is appended via `agent_extra_fields` to mark each role as Task-tool-invokable. Agents are auto-discovered from `.opencode/agents/` — no registration step.


## Authoring agents

Source file: `commons/agents/<name>.md`. One YAML-frontmatter markdown file per agent role.

### Manifest (frontmatter)

```yaml
---
name: deriver
description: Perform an analytical derivation for a target claim or open question…
capabilities: [file_read, file_write, glob]
output_pattern: derivations/D-NNN.md
---
```

- `name` (required) — kebab-case, matches the file stem.
- `description` (required) — used as the sub-agent description visible to the main agent at dispatch time.
- `capabilities` (required for agents that need tools) — list from `{file_read, file_write, file_edit, shell, glob, grep, web_search, web_fetch}`. The renderer maps these to host-specific tool names.
- `output_pattern` — the canonical artefact path (e.g. `derivations/D-NNN.md`). Pi emits it as `output:` in the frontmatter. Reviewer omits this because its output path is computed at runtime from the target ID.

### Body

The body is the agent role prompt. It is shown to the sub-agent verbatim (plus a host preamble for Pi/Codex, and an `# {{name_cap}}` heading for Claude). Every role body follows this contract:

- **What you do** — the substantive task, in plain prose.
- **Your sole artefact** — the file you write, with its section structure (`# Task`, `## Derivation`, `## Result`, `## Flags`, …).
- **Behaviour** — what to read, what not to read, what to flag instead of expanding scope.
- **Return channel** — the structured `## Summary` / `## Result` / `## Flags` block at the top of the artefact, byte-identical to the final reply message.
- **Constraints** — what the sub-agent must not edit (`research_log.md`, `plan.md`, `notes/flags.md` — main-agent territory).

The seven roles are `surveyor`, `planner`, `deriver`, `computer`, `reviewer`, `critic`, `finalizer`. They share the same return contract; the substance varies by role.


## Authoring skills

Source file: `commons/skills/<name>.md`. One file per slash-command workflow.

### Manifest

```yaml
---
name: derive
description: Analytical derivation for a target claim or open question…
agent: deriver
arguments_hint: <target claim>
artefact_kind: D-NNN
brief: derivations/.briefs/D-NNN-brief.md
output_pattern: derivations/D-NNN.md
---
```

Fields:

- `name` (required) — the slash-command name (`/derive`).
- `description` (required) — used by the host's skill discovery.
- `agent` — the sub-agent role this skill dispatches. Omit for main-agent-only skills (`/autoresearch`).
- `arguments_hint` — short usage hint shown by the host (Claude: `argument-hint`; Pi: `args`).
- `artefact_kind` — string like `D-NNN` / `C-NNN` / `CR-NNN`. Used by the Pi stub template to render "next available number" guidance.
- `brief` — path to the dispatch brief the main agent must write before dispatching (only for `/derive`, `/compute`).
- `output_pattern` — canonical artefact path produced by the sub-agent.
- `top_level_cli` (Pi only, defaults true) — set false to hide from Pi's top-level slash-command list (used for `/autoresearch`, which is intended to be driven from the main-agent context only).

### Body

The body is the **main-agent workflow** for that slash command. It tells the main agent what to do before dispatching, how to dispatch, and how to integrate the return. Standard sections:

1. **Determine the next ID** — glob the parent directory and add 1, zero-padded.
2. **Write the brief** (for `/derive`, `/compute`) — what to put in it, what *not* to put in it (no steering, no priors).
3. **Dispatch the sub-agent** — referencing the dispatch syntax from the workspace doc.
4. **Run the integration loop** — read `## Summary` / `## Result` / `## Flags`, update `research_log.md`, disposition flags, commit.
5. **Next dispatch** — the canonical follow-up (e.g. `/derive` is followed by `/review` unless explicitly deferred).

The skill body is rendered into either:

- **Claude / Codex** — a single `SKILL.md` under `.claude/skills/<name>/SKILL.md` or `.agents/skills/<name>/SKILL.md`. Claude uses `argument-hint:` (hyphenated, singular).
- **OpenCode** — a single **flat** command file at `.opencode/commands/<name>.md` (`skills_layout = "flat"`), with `description:` only (the command name comes from the filename; OpenCode has no argument-hint field).
- **Pi** — split into two files: a thin stub at `skills/<name>/SKILL.md` (generated from `hosts/pi/skill_stub.md.tmpl`) plus the full workflow at `prompts/<name>.md`, with the Pi preamble prepended.

### Main-agent-only skills

`/autoresearch` is different: it runs in the main-agent context (no fork). It drives the full pipeline autonomously, skipping the three HITL gates (`/research-plan` review, `/critique` strategy review, and any strategy-changing edit) and logging each skipped decision in `notes/auto-decisions.md`.


## Host glue

### `host.toml` fields

Required:

- `name` — must match the directory name.
- `workspace_doc` — filename of the rendered workspace doc (`CLAUDE.md` or `AGENTS.md`).
- `agents_dir` — where rendered agent role files go.
- `agent_ext` — extension (`.md` for Claude/Pi, `.toml` for Codex).
- `skills_dir` — where rendered skill files go.
- `agent_frontmatter_order` — list of frontmatter keys, in emit order. Codex skips this (TOML emit).
- `[tools_map]` — capability → tool-name dict (informational for Codex).

Optional:

- `prompts_dir` — Pi only, where workflow prompts go.
- `agent_format = "toml"` — Codex only, switches the emit path.
- `agent_body_prefix` — heading prepended to the agent body, with `{{name_cap}}` interpolation.
- `[agent_extra_fields]` — fields added to every agent frontmatter (Pi uses `thinking = "high"`).
- `[file_backed]` — `key = "filename"` entries; the renderer loads `hosts/<host>/<filename>` into the host dict under `key`. Used for `preamble`, `dispatch_example`, `skill_stub_template`.

### Companion files

- **`preamble.md`** — injected at the top of skill prompts (Pi, Codex). Carries host-specific tool discipline (e.g. "use `apply_patch` for any file write; `shell_command` for everything else"). Substituted into the `{{preamble}}` placeholder in the workspace doc.
- **`dispatch_example.md`** — the canonical dispatch syntax for the host. Substituted into the `{{dispatch_example}}` placeholder in the workspace doc and referenced from every skill workflow.
- **`gitignore.extra`** — appended to the workspace `.gitignore`. Pi adds `node_modules/`.
- **`skill_stub.md.tmpl`** (Pi only) — template for the thin `skills/<name>/SKILL.md` stubs. Uses placeholders `{{title}}`, `{{name}}`, `{{agents_used_line}}`, `{{output_block}}`.
- **`extras/<rel-path>`** — copied verbatim into the workspace. Claude ships `.claude/settings.json`; Pi ships `package.json` + `.pi/settings.json`; Codex ships `.codex/config.toml`; OpenCode ships `opencode.json`.

### Host-specific notes

- **Claude** — single-file skill layout, YAML+markdown agents. Dispatch via the `Task` tool with `subagent_type=<agent name>`. Settings file at `.claude/settings.json`.
- **Pi** — two-file skill layout (stub + prompt), YAML+markdown agents. Dispatch via Pi's `subagent` tool (JSON payload). Workspace launch: `pi install -l .` (registers the project as a local Pi package and installs `pi-subagents` + `pi-web-access` from `.pi/settings.json`), then `pi`.
- **Codex CLI** — single-file skill layout (like Claude), with agents as **TOML files** auto-discovered from `.codex/agents/*.toml` (`name`/`description`/`developer_instructions`; no `config.toml` registration). Dispatch via `spawn_agent` + `wait_agent`; subagents are enabled by default in current Codex (the legacy `[agent_roles.*]` table and `multi_agents_v2` namespace are gone). Workspace launch: `codex`, then accept the project-trust prompt on first run so `config.toml` (sandbox + web search) is honoured.
- **OpenCode** — close to Claude Code in file shapes. YAML+markdown agents under `.opencode/agents/` (`mode: subagent`, name derived from filename) and **flat single-file commands** under `.opencode/commands/<name>.md` (`skills_layout = "flat"`), both auto-discovered (no registration). Dispatch via the native `task` tool (`subagent_type="<role>"`) or an `@<role>` mention — **but custom sub-agent dispatch is version-dependent**: some builds hardcode `subagent_type` to the built-ins `explore`/`general`/`mary` and ignore custom roles ([opencode #29616](https://github.com/anomalyco/opencode/issues/29616)). `hosts/opencode/dispatch_example.md` carries the dispatch syntax plus the in-context fallback for builds that can't dispatch the roles — verify against the installed version. Native tool names match the methodology's generic references, so there is no `preamble.md`. Project config ships as `extras/opencode.json` (permission defaults, incl. `task`/`skill: allow`). Workspace launch: `opencode`. **OpenCode has no hard sandbox** — a permission model (`allow`/`ask`/`deny`), so scaffolding runs without Claude/Codex-style write-to-config friction. **Sessions are stored in a single SQLite DB** at `${XDG_DATA_HOME:-~/.local/share}/opencode/opencode.db` (not JSONL) — the `investigate-run` audit skill queries it via `session.directory` + `parent_id`. **Model choice dominates sub-agent reliability**: weak models stall after reading a brief instead of writing the artefact (the main agent re-dispatches and self-heals, but wastes work) — pin a strong model in `opencode.json` or via `opencode --model`.


## The workspace doc and research log

### `commons/workspace-doc.md`

This is the main-agent prompt that becomes `CLAUDE.md` (Claude) or `AGENTS.md` (Pi, Codex) in every workspace. It encodes the entire operational discipline: the integration loop, the workspace layout, the file ownership matrix, the `research_log.md` invariants, the dispatch model, the fresh-context rule for review and critique, the checks-and-balances rule.

Edit this file when the operational discipline changes — what files the main agent edits, how it integrates returns, how it handles flags, how it commits.

### `commons/research_log.md`

The template for the workspace's `research_log.md`. Carries the canonical section order — Open Questions, Working Claims, Established Results, Dead Ends, Conventions, Sanity Checks — with HTML comments documenting the entry format.

The invariants enforced on `research_log.md` (citation discipline, robust evidence before promotion, monotone Dead Ends, …) live in the workspace doc, not the template. The template is a starting scaffold.


## The bootstrap script

`init-physics-intern.sh` is a thin shell wrapper around `commons/render.py`. It:

1. Parses `--host` and the target directory (defaults to `.`). If `--host` is omitted it prompts interactively for one (claude / pi / codex / opencode) when run from a terminal, and falls back to `claude` for non-interactive (piped) runs.
2. Detects an existing PhysicsIntern workspace in the target (by probing for `.claude/` + `CLAUDE.md`, `.codex/` + `AGENTS.md`, or `.pi/` + `AGENTS.md` containing the marker `PhysicsIntern workspace`). If found, prompts for a reset (everything except `problem.md` is wiped).
3. Calls `python3 commons/render.py --host=<host> --target=<abs-path>`.
4. Scaffolds `problem.md` if missing (setup + main question headings).
5. Creates the artefact directories with `.gitkeep` (`derivations/`, `computations/`, `critiques/`, `notes/`, `references/`, `data/`, plus `.briefs/` under `derivations/` and `computations/`).
6. Seeds `notes/flags.md` with the flag-disposition format docstring.
7. Runs `git init` if needed, stages everything, and makes the bootstrap commit.
8. Prints a host-specific launch hint.

Reset path: triggered by the existing-workspace prompt. Removes `.git/`, all rendered host files, all artefact directories, and any other top-level entries — `problem.md` is preserved. The bootstrap commit message becomes "Re-initialize PhysicsIntern workspace (reset, problem.md preserved, host: …)".


## Distribution as a Claude Code plugin

`init-physics-intern.sh` is the canonical bootstrap (run before launching the agent). For Claude Code there is also a **plugin** that exposes the bootstrap as a single in-session command `/physics-intern:init-physics-intern` (shown in the UI as `/init-physics-intern (physics-intern)`), for discoverable install + auto-updates. It does **not** carry the methodology as plugin-global skills (that would pollute every project); it only scaffolds a workspace into the current folder, exactly like the bash script. The skills and sub-agents are folder-local, so after running it the user must **restart Claude Code in the folder** for them to register (the command's own output tells them so).

### Layout

Authored sources live under `plugins/claude/` (committed here):

```
plugins/claude/
├── .claude-plugin/marketplace.json     marketplace manifest (lists the plugin)
└── plugin/
    ├── .claude-plugin/plugin.json      plugin manifest (name "physics-intern", semver version)
    ├── skills/init-physics-intern/SKILL.md   the /physics-intern:init-physics-intern command
    └── scripts/plugin-init.sh          non-interactive renderer+scaffolder (refuses if a workspace exists)
```

How the command works: `SKILL.md` carries `disable-model-invocation: true` (user-typed only) and a `` !`…` `` block that runs `plugin-init.sh` at expansion time, where `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PROJECT_DIR}` are shell-expanded. The script renders `host=claude` from the bundled `commons/` + `hosts/claude/`, scaffolds the workspace, commits, and prints exactly one `RESULT: initialized` / `RESULT: already-initialized` line; the rest of `SKILL.md` instructs the agent to relay the edit-`problem.md` + restart message.

### Build and publish

`build-plugin.sh` assembles a complete, self-contained plugin into a separate published repo (the build is a pure artifact — never hand-edit it):

```
bash build-plugin.sh [output-dir]    # default: ../physics-intern-claude-plugin
```

It copies the authored files from `plugins/claude/` and **vendors** `commons/` (incl. `render.py`) and `hosts/claude/` into `plugin/` (rsync, excluding `__pycache__`/`.DS_Store`) so the plugin is self-contained — installed plugins cannot reference files outside their own root. Source of truth stays `commons/` + `hosts/claude/`; the plugin's per-harness repo is `physics-intern-claude-plugin` (other hosts get their own, e.g. `physics-intern-codex-plugin`).

Publish: push the built tree to the plugin repo. Users run `/plugin marketplace add <owner>/physics-intern-claude-plugin` then `/plugin install physics-intern@physics-intern-claude`. Updates: bump `version` in `plugins/claude/plugin/.claude-plugin/plugin.json` (semver, must bump every release or `/plugin update` is a no-op), rebuild, push.

Local test before publishing: `bash build-plugin.sh /tmp/out` then `claude --plugin-dir /tmp/out/plugin` in a scratch folder **outside this repo** (so the dev repo's sandbox rules don't apply), and run `/physics-intern:init-physics-intern`.


## Distribution as a Codex CLI plugin

Codex (since ~v0.136) has a first-class plugin + marketplace system that mirrors Claude Code's, so the Codex plugin follows the same **Design A**: it does not carry the methodology as global skills (that would pollute every project) — it only scaffolds a workspace into the current folder, exactly like the bash script. The user invokes it explicitly as `$physics-intern:init-physics-intern`; after it runs they **restart Codex in the folder** and accept the project-trust prompt so the workspace's `AGENTS.md`, `.agents/skills/`, `.codex/agents/`, and `.codex/config.toml` load.

### Layout

Authored sources live under `plugins/codex/` (committed here):

```
plugins/codex/
├── .agents/plugins/marketplace.json        marketplace manifest (lists the plugin)
├── README.md                               published-repo landing page
└── plugin/
    ├── .codex-plugin/plugin.json           plugin manifest (name "physics-intern", semver, "skills":"./skills/")
    ├── skills/init-physics-intern/
    │   ├── SKILL.md                        the $physics-intern:init-physics-intern skill
    │   └── agents/openai.yaml              policy.allow_implicit_invocation:false → user-only, never auto-fired
    └── scripts/plugin-init.sh              non-interactive renderer+scaffolder (refuses if a workspace exists)
```

How the skill works: `SKILL.md` (frontmatter `name` + `description`) tells the model to run `bash "${PLUGIN_ROOT}/scripts/plugin-init.sh"` via the shell tool. Unlike Claude (where `${CLAUDE_PLUGIN_ROOT}` is only available in an expansion-time `` !`…` `` block, **not** in model-issued shell), Codex **does** expose `${PLUGIN_ROOT}` in the model-issued shell command (verified on v0.136), so no `!`-block trick is needed. The script also self-locates its plugin root from `${BASH_SOURCE[0]}`, so it works regardless. It renders `host=codex` from the bundled `commons/` + `hosts/codex/`, scaffolds the workspace, commits, and prints exactly one `RESULT: initialized` / `RESULT: already-initialized` line; the rest of `SKILL.md` instructs the agent to relay the edit-`problem.md` + restart message. The one approval is for writing `.codex/` and running `git init`, which Codex's workspace-write sandbox keeps read-only by default.

### Build and publish

`build-codex-plugin.sh` assembles a complete, self-contained plugin into a separate published repo (a pure artifact — never hand-edit it):

```
bash build-codex-plugin.sh [output-dir]    # default: ../physics-intern-codex-plugin
```

It copies the authored files from `plugins/codex/` and **vendors** `commons/` (incl. `render.py`) and `hosts/codex/` into `plugin/` (rsync, excluding `__pycache__`/`.DS_Store`). Source of truth stays `commons/` + `hosts/codex/`; the plugin's per-harness repo is `physics-intern-codex-plugin`.

Publish: push the built tree to the plugin repo. Users run `codex plugin marketplace add <owner>/physics-intern-codex-plugin` then `codex plugin add physics-intern@physics-intern-codex` (`<marketplace>` is the `name` in `marketplace.json`). Updates: bump `version` in `plugins/codex/plugin/.codex-plugin/plugin.json`, rebuild, push, and `codex plugin marketplace upgrade`.

Local test before publishing: `bash build-codex-plugin.sh /tmp/out` then `codex plugin marketplace add /tmp/out` + `codex plugin add physics-intern@physics-intern-codex`, restart Codex in a scratch folder **outside this repo**, and run `$physics-intern:init-physics-intern`.


## Distribution as an OpenCode plugin

OpenCode is the odd one out: it has **no plugin marketplace**, and its JS/TS plugin API can register only tools and lifecycle hooks — **not slash commands or skills**. So the Claude/Codex "marketplace add → install → run a command" path can't be reproduced. Instead the bootstrap ships as a **global command file + a vendored scaffolder kit**, installed by a small `install.sh`. Same **Design A** intent (scaffold a workspace into the current folder; don't pollute other projects), delivered differently. After running `/init-physics-intern` the user **restarts OpenCode in the folder** so the workspace's `AGENTS.md`, `.opencode/commands/`, `.opencode/agents/`, and `opencode.json` load.

### Layout

Authored sources live under `plugins/opencode/` (committed here):

```
plugins/opencode/
├── README.md                              published-repo landing page
├── install.sh                             copies the command + kit into ~/.config/opencode/
└── physics-intern/                        the "kit" (everything the command needs at runtime)
    ├── commands/init-physics-intern.md    the global /init-physics-intern command
    └── scripts/plugin-init.sh             non-interactive renderer+scaffolder (refuses if a workspace exists)
```

How it works: `install.sh` rsyncs the kit to `${XDG_CONFIG_HOME:-~/.config}/opencode/physics-intern/` and copies the command to `${XDG_CONFIG_HOME:-~/.config}/opencode/commands/init-physics-intern.md`, making `/init-physics-intern` available in every project. The command's body runs the scaffolder via an expansion-time `` !`…` `` shell block (OpenCode injects the shell output into the prompt), referencing the script at its fixed install path (`${XDG_CONFIG_HOME:-$HOME/.config}/opencode/physics-intern/scripts/plugin-init.sh`) — there is no plugin-root variable because it is a plain command file, not a plugin. `plugin-init.sh` self-locates its kit root from `${BASH_SOURCE[0]}`, renders `host=opencode` from the bundled `commons/` + `hosts/opencode/`, scaffolds the workspace, commits, and prints exactly one `RESULT: initialized` / `RESULT: already-initialized` line; the rest of the command instructs the agent to relay the edit-`problem.md` + restart message. OpenCode has no hard sandbox, so at most the user approves the single `bash` shell block (depending on their `permission.bash` setting) — milder than Claude/Codex's config-write approval.

### Build and publish

`build-opencode-plugin.sh` assembles a complete, self-contained tree into a separate published repo (a pure artifact — never hand-edit it):

```
bash build-opencode-plugin.sh [output-dir]    # default: ../physics-intern-opencode-plugin
```

It copies the authored files from `plugins/opencode/` and **vendors** `commons/` (incl. `render.py`) and `hosts/opencode/` into the kit (`physics-intern/`, rsync excluding `__pycache__`/`.DS_Store`). Source of truth stays `commons/` + `hosts/opencode/`; the published repo is `physics-intern-opencode-plugin`.

Publish: push the built tree to the repo (must be **public** — `git clone` over HTTPS must work). There is no version field to bump and no marketplace to upgrade — users re-run `git pull && ./install.sh` to update.

Local test before publishing: `bash build-opencode-plugin.sh /tmp/out` then `XDG_CONFIG_HOME=/tmp/fakecfg bash /tmp/out/install.sh`, and run `/tmp/fakecfg/opencode/physics-intern/scripts/plugin-init.sh` in a scratch folder to confirm it renders + commits and is idempotent on re-run.


## Workspace runtime: how the methodology executes

This is the high-level shape of what happens **inside** a rendered workspace. The authoritative rules live in `commons/workspace-doc.md` (which becomes the workspace's `CLAUDE.md` / `AGENTS.md`); the summary below is for orientation.

A workspace is a git repository. The user fills in `problem.md`, then talks to the main agent (Claude Code, Pi, or Codex CLI, started in the workspace directory). The main agent is a **coordinator only** — it never performs substantive surveys, derivations, computations, reviews, or critiques itself. Every workflow skill dispatches a fresh-context sub-agent that does the heavy lifting and writes its own artefact.

### The arc

`/survey` → `/research-plan` → loop of (`/derive` or `/compute`) → `/review` → integrate, with `/critique` every few state changes and before any major direction change → `/finalize`.

### The integration loop

After each sub-agent return, the main agent runs the integration loop:

1. Read the sub-agent's `## Summary` / `## Result` / `## Flags`.
2. Integrate into `research_log.md` — Working Claims / Established Results, source lists, dependencies.
3. Disposition every flag in `notes/flags.md` (one line per flag, with a one-line reason).
4. Update `plan.md` if a step is now done, obsolete, or revised.
5. Commit everything as one logical step.
6. Decide the next dispatch (or hand to the user).

Sub-agents do not commit. The integration loop is the load-bearing operational discipline; most of the methodology either feeds into it or is checked against it.

### File ownership

- **Main agent edits**: `research_log.md`, `notes/`, `notes/flags.md`, `derivations/.briefs/`, `computations/.briefs/`, `critiques/CR-NNN.md` (`## Resolution` and `status:` only), `plan.md` (targeted edits).
- **Sub-agent territory** (main agent does not edit): `derivations/D-NNN.md` and `D-NNN_R*.md`, `computations/C-NNN.{md,py,out}` and `C-NNN_R*.md`, `survey.md`, `answer.md`, `references/<id>.md` summaries, `critiques/CR-NNN.md` body.

### HITL gates

Three places the main agent normally pauses for the user:

- After `/research-plan` produces a draft, before continuing into derivations.
- After `/critique` returns findings that would change strategy.
- Before any strategy-level edit to `plan.md` (targeted edits don't require approval).

`/autoresearch` skips these gates (logging each skipped decision in `notes/auto-decisions.md`). Intended for methodology validation and for problems where course correction is unlikely.


## Design choices worth remembering

- **The host is a deployment decision, not an architectural one.** The methodology source lives in `commons/`; per-host glue (tool names, frontmatter shapes, dispatch syntax) lives in `hosts/<host>/`. Adding Codex, OpenCode, or Gemini CLI meant (or means) writing a `hosts/<host>/host.toml` plus a small `dispatch_example.md`.
- **Files are durable state; context is ephemeral.** The user may clear the session at any time. After a clear, the main agent must resume from `research_log.md` and `plan.md` alone. This is what allows the integration loop to be the only handoff mechanism.
- **Explicit dispatch, no auto-fork.** Both hosts use the same dispatch model: main agent reads the skill workflow, writes the brief, calls the dispatch tool (`Task` for Claude, `subagent` for Pi, `spawn_agent` for Codex), integrates the return. Claude Code's `context: fork` auto-fork shortcut is not used — the symmetry is more valuable than the keystroke saved.
- **Fresh context for `/review` and `/critique` is non-negotiable.** Reviewers don't see prior reviews on the same target. Critics get only one-line summaries of prior critiques. Sub-agents don't see the main agent's reasoning.
- **No single sub-agent verdict moves research forward.** Before acting on a refutation or a strategy-changing critique finding, the main agent seeks a second opinion. A verdict is a *proposal*, not an order.
- **Robust evidence before promotion.** A Working Claim becomes Established only with evidence robust against typical failure modes — usually ≥2 independent dispatch contexts. A single artefact's internal symbolic + numerical cross-check counts as one source for conceptual-bug protection.
- **Prose-encoded discipline, not a state machine.** Promotion = the main agent editing a heading. Refutation = the main agent moving an entry to Dead Ends with a reason. No JSON state, no enum verdicts, no auto-promotion cascades. The bet: modern models follow prose-encoded rules well enough that the harness complexity isn't worth it. The audit skill catches drift.
- **Do not over-engineer the skills.** Skill prompts should be as simple as possible while still being effective. Avoid complex, verbose, or ad-hoc instructions that aren't essential to the core methodology.


## Adding a new host

Adding a host (Gemini CLI, Goose, …) is a folder under `hosts/`:

1. **`host.toml`** — declare `name`, `workspace_doc`, `agents_dir`, `agent_ext`, `skills_dir`, `agent_frontmatter_order`, and `[tools_map]`. Add `[agent_extra_fields]` if the host needs extras. Add `[file_backed]` entries for any companion files you ship.
2. **`dispatch_example.md`** — the exact syntax the main agent uses to dispatch a sub-agent for `/derive D-007`. This string is substituted into the workspace doc, so be precise.
3. **`preamble.md`** (optional) — host-specific tool discipline. Injected at the top of skill prompts and into the workspace doc via `{{preamble}}`.
4. **`gitignore.extra`** (optional) — appended to the workspace `.gitignore`.
5. **`extras/<rel-path>`** (optional) — settings files, package manifests, etc., copied verbatim into every rendered workspace.
6. **Update `init-physics-intern.sh`** — add the new host to the `case "$HOST" in claude|pi|codex|opencode)` check, the existing-workspace detection block, and the launch-hint switch at the bottom.
7. **Update `commons/render.py`** — add the new host to the `--host` choices argument and any host-specific branches in `render_skill` / agent emit paths if the host needs a layout the current paths don't cover.

For hosts that use a non-YAML-frontmatter role format (like Codex's TOML roles), set `agent_format = "toml"` (or add a new value and a new emit path in `render.py`).

Render and inspect a fresh workspace under `/tmp/` before committing the new host.


## Adding a new agent or skill

**A new agent** is one file: `commons/agents/<name>.md`. Pick a kebab-case name, write the manifest (`name`, `description`, `capabilities`, `output_pattern`), write the role body following the contract in [Authoring agents](#authoring-agents). Render against every supported host (`claude`, `pi`, `codex`, `opencode`) and confirm the rendered frontmatter is well-formed.

**A new skill** is one file: `commons/skills/<name>.md`. Pick a kebab-case name, write the manifest, write the main-agent workflow body following the structure in [Authoring skills](#authoring-skills). If the skill dispatches a sub-agent, that agent must already exist in `commons/agents/`. Add the skill to the table in [README.md](README.md) and the listing in `commons/workspace-doc.md` §4.

Render before committing:

```bash
bash init-physics-intern.sh --host=claude   /tmp/test-claude
bash init-physics-intern.sh --host=pi       /tmp/test-pi
bash init-physics-intern.sh --host=codex    /tmp/test-codex
bash init-physics-intern.sh --host=opencode /tmp/test-opencode
```


## Auditing a run: `investigate-run`

`.claude/skills/investigate-run/SKILL.md` is a **repo-level** audit skill — not part of any workspace template; used while iterating on the methodology in this repo. Given a workspace path and its session record — a JSONL for Claude/Pi/Codex, or the SQLite store (`opencode.db`, queried by `session.directory` + `parent_id`) for OpenCode — it produces a post-mortem report covering:

- **Trajectory reconstruction** — skills dispatched, returns, integration actions.
- **Methodology adherence** — against the rules baked into the workspace's `CLAUDE.md` / `AGENTS.md` and agent prompts.
- **Commit discipline** — one commit per integration step bundling artefact + main-agent edits.
- **Flag-disposition trace** — every `## Flags` entry must have a line in `notes/flags.md`.
- **Prompt-vs-behaviour deltas** — did sub-agents stay inside their declared tool list and scope?
- **Substantive quality** — does `answer.md` answer `problem.md`?

Run after a workspace session to see where the methodology slipped and which prompts to fix. Output lands in `/tmp/audit-<workspace>.md`.

When the methodology contract changes (workspace doc, integration loop rules, return-channel format), update `investigate-run/SKILL.md` so its audit rules follow.


## Validation workflow

Iteration loop when changing prompts:

1. **Edit source** — `commons/workspace-doc.md`, `commons/agents/<role>.md`, `commons/skills/<name>.md`, or `hosts/<host>/…`.
2. **Render and inspect** — `bash init-physics-intern.sh --host=<host> /tmp/scratch` (or call `commons/render.py` directly). Read the rendered files; check frontmatter, placeholders, and any host-specific shaping.
3. **Run a benchmark problem** — bootstrap a fresh workspace from a problem in `problems/` or `references/`, run it through (often via `/autoresearch` for speed, then manually for HITL).
4. **Audit** — run `investigate-run` against the resulting workspace + session JSONL.
5. **Compare** — diff findings against prior runs in `results/`. Look for recurring failure modes; those are signal that a prompt needs editing.
6. **Commit** — source change + (if relevant) `investigate-run` rule change, in one commit.

Changes propagate to **new** workspaces on the next `init-physics-intern.sh` run. Existing workspaces carry the methodology baked into their `.claude/`, `.pi/`, `.codex/`, or `.opencode/` at the time they were created — there is no upgrade skill, so older workspaces are patched by hand if needed.
