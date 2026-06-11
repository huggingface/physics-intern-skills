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

This repo holds the **methodology** — the prompts, the render pipeline, and the workspace template — that turn an AI coding harness (Claude Code, Pi, Codex CLI, Hermes Agent) into a research collaborator for theoretical physics and mathematics. The host already provides tool-use loops, sub-agent dispatch, sandboxed Python, web search, and slash-command-as-skill; we don't rebuild those. We layer on top: structured survey, explicit plan, fresh-context derivations and adversarial reviews, strategic critique, systematic symbolic + numerical cross-checking, citation discipline.

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
├── init-physics-intern.sh             # workspace bootstrap / Hermes skill installer
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
│   └── skills/                        # 9 main-agent workflow files
│       ├── start-research.md
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
│       ├── host.toml                  # agent_format="toml"; tools collapse onto shell_command + apply_patch
│       ├── preamble.md                # Codex tool discipline
│       ├── dispatch_example.md        # spawn_agent + wait_agent example
│       └── extras/.codex/config.toml  # sandbox + web_search; renderer appends [agent_roles.*] blocks
│   └── hermes/
│       ├── host.toml                  # Hermes AGENTS.md + .hermes/skills + delegate_task dispatch
│       ├── preamble.md                # Hermes tool discipline
│       └── dispatch_example.md        # delegate_task example
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
3. **Render skills** — one file (Claude / Codex / Hermes single-file `SKILL.md`) or two (Pi: stub under `skills/<name>/SKILL.md` + workflow under `prompts/<name>.md`) per `commons/skills/<name>.md`. For Hermes installation (`./init-physics-intern.sh host=hermes`), the bootstrap script renders to a temporary directory and copies the rendered PhysicsIntern skills into the active Hermes home (`~/.hermes/skills/` by default, or `$HERMES_HOME/skills` when set), then discards the temporary render.
4. **Render the workspace doc** — `commons/workspace-doc.md` → `CLAUDE.md` (Claude) or `AGENTS.md` (Pi, Codex, Hermes). Placeholders like `{{workspace_doc}}` and `{{dispatch_example}}` are substituted from the host config.
5. **Render `research_log.md`** — substituted from the same template.
6. **Render `.gitignore`** — `commons/gitignore` plus optional `hosts/<host>/gitignore.extra`.
7. **Copy host extras** — every file under `hosts/<host>/extras/` is copied to the workspace, preserving relative paths.
8. **(Codex only)** **Register agent roles** — append `[agent_roles.<name>]` blocks to `.codex/config.toml` so Codex discovers the rendered TOML role files.

The renderer requires Python 3.11+ (`tomllib`), no third-party deps. Frontmatter parsing is intentionally minimal (top-level scalars, flow and block lists); if we ever need nested mappings or anchors we'll swap in PyYAML.

### Placeholder substitution

`substitute(text, ctx)` replaces `{{key}}` with `ctx[key]`. Unknown placeholders raise — the renderer fails fast rather than emit broken files. The available keys come from the merged host dict (everything in `host.toml` plus all `file_backed` values). Frequently used: `workspace_doc`, `agents_dir`, `agent_ext`, `dispatch_example`, `preamble`.

### Capability → tool mapping

Sub-agent role files in `commons/agents/<name>.md` declare a list of **capabilities** (`file_read`, `file_write`, `file_edit`, `shell`, `glob`, `grep`, `web_search`, `web_fetch`). The renderer translates these per-host:

| Capability | Claude | Pi | Codex | Hermes |
|---|---|---|---|---|
| `file_read` | `Read` | `read` | `shell_command` (cat / head) | `file` |
| `file_write` | `Write` | `write` | `apply_patch` | `file` |
| `file_edit` | `Edit` | `edit` | `apply_patch` | `file` |
| `shell` | `Bash` | `bash` | `shell_command` | `terminal` |
| `glob` | `Glob` | `ls, find` | `shell_command` (find / ls) | `file` |
| `grep` | `Grep` | `grep` | `shell_command` (grep / rg) | `file` |
| `web_search` | `WebSearch` | `web_search` | `web_search` | `web` |
| `web_fetch` | `WebFetch` | `fetch_content` | `shell_command` (curl) | `web` |

Duplicate-after-mapping tools are deduped (Codex collapses several capabilities onto `apply_patch` and `shell_command`; Hermes collapses file operations onto the `file` toolset). Codex sub-agent roles don't carry a per-role tools allowlist — permissions are sandbox-scoped at the workspace level — so the `tools_map` for Codex is informational, kept in `host.toml` to document which capability lands on which tool. Hermes role files likewise use the rendered `tools:` field as documentation; the main agent chooses `delegate_task(..., toolsets=[...])` at dispatch time.

### Frontmatter shaping

Each host emits frontmatter in its own order and adds its own extras:

- **Claude**: `name`, `description`, `tools`. No `output:` (Claude has no native concept). No agent extras.
- **Hermes**: `name`, `description`, `tools` (informational toolset names). No `output:`; dispatch uses `delegate_task` with explicit context and `toolsets`.
- **Pi**: `name`, `description`, `thinking`, `tools`, `output`. `thinking: high` is appended via `agent_extra_fields`. `output:` is the per-artefact path pattern; agents without a fixed output (e.g. reviewer) omit it.
- **Codex**: not YAML — the entire role is a TOML file with `name`, `description`, and a `developer_instructions = """…"""` multi-line string. Roles are registered in `.codex/config.toml` under `[agent_roles.<name>]`.


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
- `agent` — the sub-agent role this skill dispatches. Omit for main-agent-only skills (`/start-research`, `/autoresearch`).
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

- **Claude / Codex / Hermes** — a single `SKILL.md` under `.claude/skills/<name>/SKILL.md`, `.agents/skills/<name>/SKILL.md`, or `.hermes/skills/<name>/SKILL.md`. Claude uses `argument-hint:` (singular, hyphenated).
- **Pi** — split into two files: a thin stub at `skills/<name>/SKILL.md` (generated from `hosts/pi/skill_stub.md.tmpl`) plus the full workflow at `prompts/<name>.md`, with the Pi preamble prepended.

### Main-agent-only skills

`/start-research` and `/autoresearch` are different: they run in the main-agent context (no fork). `/start-research` reads `problem.md`, extracts a one-line summary, and substitutes the `{{PROBLEM_ONELINER}}` placeholders in the workspace doc and `research_log.md`. `/autoresearch` drives the full pipeline autonomously, skipping the three HITL gates (`/research-plan` review, `/critique` strategy review, and any strategy-changing edit) and logging each skipped decision in `notes/auto-decisions.md`.


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

- **`preamble.md`** — injected at the top of skill prompts (Pi, Codex, Hermes). Carries host-specific tool discipline (e.g. "use `apply_patch` for any file write; `shell_command` for everything else"). Substituted into the `{{preamble}}` placeholder in the workspace doc.
- **`dispatch_example.md`** — the canonical dispatch syntax for the host. Substituted into the `{{dispatch_example}}` placeholder in the workspace doc and referenced from every skill workflow.
- **`gitignore.extra`** — appended to the workspace `.gitignore`. Pi adds `node_modules/`.
- **`skill_stub.md.tmpl`** (Pi only) — template for the thin `skills/<name>/SKILL.md` stubs. Uses placeholders `{{title}}`, `{{name}}`, `{{agents_used_line}}`, `{{output_block}}`.
- **`extras/<rel-path>`** — copied verbatim into the workspace. Claude ships `.claude/settings.json`; Pi ships `package.json` + `.pi/settings.json`; Codex ships `.codex/config.toml`.

### Host-specific notes

- **Claude** — single-file skill layout, YAML+markdown agents. Dispatch via the `Task` tool with `subagent_type=<agent name>`. Settings file at `.claude/settings.json`.
- **Pi** — two-file skill layout (stub + prompt), YAML+markdown agents. Dispatch via Pi's `subagent` tool (JSON payload). Workspace launch: `pi install -l .` (registers the project as a local Pi package and installs `pi-subagents` + `pi-web-access` from `.pi/settings.json`), then `pi`.
- **Codex CLI** — single-file skill layout (like Claude), but agents are **TOML files** registered as `[agent_roles.<name>]` blocks in `.codex/config.toml`. Dispatch via `spawn_agent` + `wait_agent` (Codex's `multi_agents_v2` namespace, under active OpenAI development). Workspace launch: `codex`, then accept the project-trust prompt on first run so `config.toml` is honoured.
- **Hermes Agent** — single-file skill layout rendered under `.hermes/skills`, YAML+markdown role prompts under `.hermes/agents`, and project context in `AGENTS.md` when an explicit Hermes workspace target is rendered. Normal Hermes setup is install-only: `./init-physics-intern.sh host=hermes` renders to a temporary directory, copies the nine PhysicsIntern skills into the active Hermes home (`~/.hermes/skills/` by default, or `$HERMES_HOME/skills` when set), and does not create a workspace in the current directory. Dispatch via `delegate_task`; the main agent passes the role file path, task context, and appropriate `toolsets`, then verifies the written artefact before integration. Restart any already-running Hermes session after installation, then run `hermes` from the directory where you want to work.


## The workspace doc and research log

### `commons/workspace-doc.md`

This is the main-agent prompt that becomes `CLAUDE.md` (Claude) or `AGENTS.md` (Pi, Codex, and explicit Hermes workspace renders). It encodes the entire operational discipline: the integration loop, the workspace layout, the file ownership matrix, the `research_log.md` invariants, the dispatch model, the fresh-context rule for review and critique, the checks-and-balances rule.

Edit this file when the operational discipline changes — what files the main agent edits, how it integrates returns, how it handles flags, how it commits.

### `commons/research_log.md`

The template for the workspace's `research_log.md`. Carries the canonical section order — Open Questions, Working Claims, Established Results, Dead Ends, Conventions, Sanity Checks — with HTML comments documenting the entry format. The `{{PROBLEM_ONELINER}}` placeholder is substituted by `/start-research` after the user fills in `problem.md`.

The invariants enforced on `research_log.md` (citation discipline, robust evidence before promotion, monotone Dead Ends, …) live in the workspace doc, not the template. The template is a starting scaffold.


## The bootstrap script

`init-physics-intern.sh` is a thin shell wrapper around `commons/render.py`. It:

1. Parses `--host` (defaults to `claude`; `host=<name>` is accepted as a shorthand) and the target directory (defaults to `.`).
2. If invoked as `./init-physics-intern.sh host=hermes` (or `--host=hermes`) with no target, renders Hermes files into a temporary directory, copies the PhysicsIntern skills into the active Hermes home (`~/.hermes/skills/` by default, or `$HERMES_HOME/skills` when set), removes the temporary render, and exits without creating a workspace.
3. Refuses no-target initialization from the PhysicsIntern methodology source checkout for non-Hermes workspace bootstraps, which prevents accidentally resetting the repository itself when the user meant to pass a target workspace directory.
4. Detects an existing PhysicsIntern workspace in the target (by probing for `.claude/` + `CLAUDE.md`, `.codex/` + `AGENTS.md`, `.hermes/` + `AGENTS.md`, or `.pi/` + `AGENTS.md` containing the marker `PhysicsIntern workspace`). If found, prompts for a reset (everything except `problem.md` is wiped).
5. Calls `python3 commons/render.py --host=<host> --target=<abs-path>`.
6. For Hermes with an explicit target, also copies the rendered PhysicsIntern skills into the active Hermes home so `/survey`, `/derive`, etc. are installed through Hermes' normal skill discovery.
7. Scaffolds `problem.md` if missing (setup + main question headings).
8. Creates the artefact directories with `.gitkeep` (`derivations/`, `computations/`, `critiques/`, `notes/`, `references/`, `data/`, plus `.briefs/` under `derivations/` and `computations/`).
9. Seeds `notes/flags.md` with the flag-disposition format docstring.
10. Runs `git init` if needed, stages everything, and makes the bootstrap commit.
11. Prints a host-specific launch hint.

Reset path: triggered by the existing-workspace prompt. Removes `.git/`, all rendered host files, all artefact directories, and any other top-level entries — `problem.md` is preserved. The bootstrap commit message becomes "Re-initialize PhysicsIntern workspace (reset, problem.md preserved, host: …)".


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

- **The host is a deployment decision, not an architectural one.** The methodology source lives in `commons/`; per-host glue (tool names, frontmatter shapes, dispatch syntax) lives in `hosts/<host>/`. Adding OpenCode, Gemini CLI, or Goose means writing a `hosts/<host>/host.toml` plus a small `dispatch_example.md`.
- **Files are durable state; context is ephemeral.** The user may clear the session at any time. After a clear, the main agent must resume from `research_log.md` and `plan.md` alone. This is what allows the integration loop to be the only handoff mechanism.
- **Explicit dispatch, no auto-fork.** All hosts use the same dispatch model: main agent reads the skill workflow, writes the brief, calls the host dispatch mechanism (`Task` for Claude, `subagent` for Pi, `spawn_agent` for Codex, `delegate_task` for Hermes), integrates the return. Claude Code's `context: fork` auto-fork shortcut is not used — the symmetry is more valuable than the keystroke saved.
- **Fresh context for `/review` and `/critique` is non-negotiable.** Reviewers don't see prior reviews on the same target. Critics get only one-line summaries of prior critiques. Sub-agents don't see the main agent's reasoning.
- **No single sub-agent verdict moves research forward.** Before acting on a refutation or a strategy-changing critique finding, the main agent seeks a second opinion. A verdict is a *proposal*, not an order.
- **Robust evidence before promotion.** A Working Claim becomes Established only with evidence robust against typical failure modes — usually ≥2 independent dispatch contexts. A single artefact's internal symbolic + numerical cross-check counts as one source for conceptual-bug protection.
- **Prose-encoded discipline, not a state machine.** Promotion = the main agent editing a heading. Refutation = the main agent moving an entry to Dead Ends with a reason. No JSON state, no enum verdicts, no auto-promotion cascades. The bet: modern models follow prose-encoded rules well enough that the harness complexity isn't worth it. The audit skill catches drift.
- **Do not over-engineer the skills.** Skill prompts should be as simple as possible while still being effective. Avoid complex, verbose, or ad-hoc instructions that aren't essential to the core methodology.


## Adding a new host

Adding a host (OpenCode, Gemini CLI, Goose, …) is a folder under `hosts/`:

1. **`host.toml`** — declare `name`, `workspace_doc`, `agents_dir`, `agent_ext`, `skills_dir`, `agent_frontmatter_order`, and `[tools_map]`. Add `[agent_extra_fields]` if the host needs extras. Add `[file_backed]` entries for any companion files you ship.
2. **`dispatch_example.md`** — the exact syntax the main agent uses to dispatch a sub-agent for `/derive D-007`. This string is substituted into the workspace doc, so be precise.
3. **`preamble.md`** (optional) — host-specific tool discipline. Injected at the top of skill prompts and into the workspace doc via `{{preamble}}`.
4. **`gitignore.extra`** (optional) — appended to the workspace `.gitignore`.
5. **`extras/<rel-path>`** (optional) — settings files, package manifests, etc., copied verbatim into every rendered workspace.
6. **Update `init-physics-intern.sh`** — add the new host to the `case "$HOST" in claude|pi|codex|hermes)` check, the existing-workspace detection block, and the launch-hint switch at the bottom.
7. **Update `commons/render.py`** — add the new host to the `--host` choices argument and any host-specific branches in `render_skill` / agent emit paths if the host needs a layout the current paths don't cover.

For hosts that use a non-YAML-frontmatter role format (like Codex's TOML roles), set `agent_format = "toml"` (or add a new value and a new emit path in `render.py`).

Render and inspect a fresh workspace under `/tmp/` before committing the new host.


## Adding a new agent or skill

**A new agent** is one file: `commons/agents/<name>.md`. Pick a kebab-case name, write the manifest (`name`, `description`, `capabilities`, `output_pattern`), write the role body following the contract in [Authoring agents](#authoring-agents). Render against every supported host (`claude`, `pi`, `codex`) and confirm the rendered frontmatter is well-formed.

**A new skill** is one file: `commons/skills/<name>.md`. Pick a kebab-case name, write the manifest, write the main-agent workflow body following the structure in [Authoring skills](#authoring-skills). If the skill dispatches a sub-agent, that agent must already exist in `commons/agents/`. Add the skill to the table in [README.md](README.md) and the listing in `commons/workspace-doc.md` §4.

Render before committing:

```bash
bash init-physics-intern.sh --host=claude /tmp/test-claude
bash init-physics-intern.sh --host=pi     /tmp/test-pi
bash init-physics-intern.sh --host=codex  /tmp/test-codex
bash init-physics-intern.sh --host=hermes /tmp/test-hermes
```


## Auditing a run: `investigate-run`

`.claude/skills/investigate-run/SKILL.md` is a **repo-level** audit skill — not part of any workspace template; used while iterating on the methodology in this repo. Given a workspace path and a Claude Code session JSONL (or equivalent), it produces a post-mortem report covering:

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

Changes propagate to **new** workspaces on the next `init-physics-intern.sh` run. Existing workspaces carry the methodology baked into their `.claude/`, `.pi/`, or `.codex/` at the time they were created — there is no upgrade skill, so older workspaces are patched by hand if needed.
