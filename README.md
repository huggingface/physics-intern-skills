# PhysicsIntern

A methodology package for using AI coding agents (Claude Code, Pi, OpenAI Codex CLI, OpenCode) to conduct theoretical physics and mathematics research. Drop a research question into `problem.md`, run a single bootstrap command, launch your agent, and run `/survey` to begin. The agent handles the rest — surveying the literature, drafting a plan, dispatching analytical derivations and numerical computations to fresh-context sub-agents, reviewing each result, and synthesising the final answer into `answer.md`.

PhysicsIntern is **host-agnostic**: the same methodology runs on four coding-agent hosts, with the host chosen at workspace-creation time. Files are durable state, the session is ephemeral — you can clear the context at any time and the agent picks up from `research_log.md` and `plan.md`.

> **Working on the methodology itself?** See [DOCUMENTATION.md](DOCUMENTATION.md) for the developer documentation: render pipeline, agent/skill authoring contracts, host glue, and the audit workflow.


## Prerequisites

- **Git** and **Python 3.11+** (the renderer uses `tomllib`; no third-party packages).
- One of the supported coding-agent hosts installed:
  - **[Claude Code](https://claude.com/claude-code)** (default) — `claude` on your PATH.
  - **[Pi](https://pi.dev)** — `pi` on your PATH.
  - **[OpenAI Codex CLI](https://github.com/openai/codex)** — `codex` on your PATH.
  - **[OpenCode](https://opencode.ai)** — `opencode` on your PATH.

The agent host provides web search, Python execution, and sub-agent dispatch. PhysicsIntern does not need any API keys of its own.


## Quick start

```bash
git clone <this-repo> physics-intern
cd physics-intern

./init-physics-intern.sh ../my-new-workspace    # prompts you to pick a host (default: Claude Code)
cd ../my-new-workspace

# Edit problem.md — fill in the '### Problem setup' and '### Main question' blocks.
$EDITOR problem.md

claude                                          # launch Claude Code in this directory
> /survey                                       # begin (the agent reads problem.md directly)
```

That's it. The agent will work through the research arc, dispatching sub-agents, integrating their results, and committing after each step. You can intervene at any point: edit files directly, ask the main agent a question, or run a slash command yourself.

> **Prefer not to clone?** Claude Code and Codex have **one-command install plugins** that scaffold a workspace for you — no clone needed:
> - [`huggingface/physics-intern-claude-plugin`](https://github.com/huggingface/physics-intern-claude-plugin) (Claude Code)
> - [`huggingface/physics-intern-codex-plugin`](https://github.com/huggingface/physics-intern-codex-plugin) (Codex CLI)
>
> See the per-host instructions under [Hosts](#hosts) below.


## Hosts

Pick a host at workspace-creation time via `--host`. If you omit it, the bootstrap prompts you to choose one interactively (defaulting to Claude Code when run non-interactively). Same methodology in every case; the launch sequence differs.

### Claude Code (default)

```bash
./init-physics-intern.sh --host=claude ../my-workspace
cd ../my-workspace
claude
> /survey
```

**Or install the Claude Code plugin** for a discoverable, one-command bootstrap (no clone needed):

```
/plugin marketplace add huggingface/physics-intern-claude-plugin
/plugin install physics-intern@physics-intern-claude
```

Restart Claude Code, then run `/init-physics-intern` in an empty folder for your problem. (Plugin repo: [`huggingface/physics-intern-claude-plugin`](https://github.com/huggingface/physics-intern-claude-plugin), built from this one via `build-plugin.sh`; see [DOCUMENTATION.md](DOCUMENTATION.md#distribution-as-a-claude-code-plugin).)

### Pi

```bash
./init-physics-intern.sh --host=pi ../my-workspace
cd ../my-workspace
pi install -l .                                 # register the workspace as a local Pi package
pi                                              # auto-installs pi-subagents + pi-web-access
> /survey
```

### OpenAI Codex CLI

```bash
./init-physics-intern.sh --host=codex ../my-workspace
cd ../my-workspace
codex                                           # on first run, accept the "trust this project" prompt
                                                # — otherwise .codex/config.toml (sandbox + web search) is ignored
> $survey
```

Sub-agent roles auto-discover from the rendered `.codex/agents/*.toml` files (no config registration). Dispatch uses `spawn_agent` + `wait_agent`; subagents are enabled by default in current Codex.

**Or install the Codex plugin** for a discoverable, one-command bootstrap (no clone needed):

```
codex plugin marketplace add huggingface/physics-intern-codex-plugin
codex plugin add physics-intern@physics-intern-codex
```

Restart Codex, then run `$physics-intern:init-physics-intern` in an empty folder for your problem. (Plugin repo: [`huggingface/physics-intern-codex-plugin`](https://github.com/huggingface/physics-intern-codex-plugin), built from this one via `build-codex-plugin.sh`; see [DOCUMENTATION.md](DOCUMENTATION.md#distribution-as-a-codex-cli-plugin).)

### OpenCode

```bash
./init-physics-intern.sh --host=opencode ../my-workspace
cd ../my-workspace
opencode                                        # commands and sub-agents auto-discovered from .opencode/
> /survey
```

Sub-agent dispatch on OpenCode uses the native `Task` tool with `subagent_type` (the same shape as Claude Code). Commands (`.opencode/commands/`) and agents (`.opencode/agents/`) are auto-discovered — no registration step.


## What `init-physics-intern.sh` does

The bootstrap script renders a workspace from this repo's templates:

- Creates `CLAUDE.md` (Claude) or `AGENTS.md` (Pi, Codex, OpenCode) — the main-agent prompt encoding the entire research methodology.
- Renders the seven sub-agent role prompts and eight workflow skills into the host's expected layout.
- Scaffolds `problem.md` with empty `### Problem setup` and `### Main question` blocks if you haven't written one.
- Creates artefact directories (`derivations/`, `computations/`, `critiques/`, `notes/`, `references/`, `data/`, plus `.briefs/` under `derivations/` and `computations/`).
- Seeds `notes/flags.md` (where the main agent logs its handling of sub-agent flags).
- Initialises git and makes the first commit.

Re-running on an existing workspace prompts for a reset (preserves `problem.md`, wipes everything else and re-renders from the current templates).


## Workspace layout

After `init-physics-intern.sh`, your workspace looks like this:

```
my-workspace/
├── problem.md             the research question (you write this)
├── CLAUDE.md / AGENTS.md  the main-agent prompt (don't edit during a run)
├── research_log.md        primary durable state — Working Claims, Established Results, …
├── plan.md                research plan (written by /research-plan)
├── survey.md              landscape orientation (written by /survey)
├── answer.md              final synthesis (written by /finalize)
├── derivations/           D-NNN.md analytical derivations + D-NNN_R*.md reviews
│   └── .briefs/           dispatch briefs the main agent writes before /derive
├── computations/          C-NNN.{md,py,out} symbolic + numerical work + reviews
│   └── .briefs/           dispatch briefs the main agent writes before /compute
├── critiques/             CR-NNN.md strategic critiques
├── notes/                 main-agent scratch + notes/flags.md (flag-disposition log)
├── references/            papers / textbooks the agent fetches and summarises
└── data/                  numerical inputs/outputs of computations
```

You only ever need to edit `problem.md` (and optionally any of the above if you want to intervene). The agent handles the rest.


## Skills (slash commands)

| Skill | What it does |
|---|---|
| `/survey` | Landscape orientation. Writes `survey.md`. Provisional — later evidence overrides it. |
| `/research-plan` | Drafts or updates `plan.md`. Pauses for your approval before continuing. |
| `/derive <claim>` | Analytical derivation in a fresh-context sub-agent. Writes `derivations/D-NNN.md`. |
| `/compute <claim>` | Symbolic + numerical work (SymPy + NumPy by default). Writes `computations/C-NNN.{md,py,out}`. Disagreement between symbolic and numerical is flagged. |
| `/review <D-NNN \| C-NNN>` | Fresh-context adversarial review of a derivation or computation. Writes a sibling `_R<M>.md` with verdict `confirmed` / `refuted` / `inconclusive`. |
| `/critique` | Fresh-context strategic critique of the whole research state. Writes `critiques/CR-NNN.md`. |
| `/finalize` | Synthesises `answer.md` from Established Results. |
| `/autoresearch` | Drives the whole pipeline autonomously, skipping the three HITL gates. Records each skipped decision in `notes/auto-decisions.md`. Use for methodology validation or problems where course correction is unlikely. |


## How a workspace runs (high-level)

A workspace is a git repository. You fill in `problem.md`, talk to the main agent, and it acts as a **coordinator only** — every substantive step (survey, derivation, computation, review, critique) is dispatched to a fresh-context sub-agent.

After each sub-agent return, the main agent runs the **integration loop**:

1. Read the sub-agent's `## Summary` / `## Result` / `## Flags`.
2. Update `research_log.md` — Working Claims, Established Results, source lists, dependencies.
3. Log each flag in `notes/flags.md` with a one-line disposition (accepted / dismissed / deferred).
4. Update `plan.md` if a step is done, obsolete, or revised.
5. Commit everything as one logical step.
6. Decide the next dispatch — or hand back to you.

A Working Claim becomes an Established Result only when its evidence is robust against typical failure modes — usually **≥2 independent dispatch contexts** (a second derivation from a different angle, a computation cross-check, or both). No single sub-agent verdict moves the research forward.

The full operational rules live in `CLAUDE.md` / `AGENTS.md` inside your workspace; the agent reads them at every turn.


## Intervening during a run

You can edit any file, ask the main agent a question, or run a slash command yourself at any time. After a context clear, the main agent resumes from `research_log.md` and `plan.md` alone — no other handoff state.

If you want to inspect what the agent has been doing, `git log` is authoritative: there's one commit per integration step, with the artefact, the research-log update, and the flag dispositions bundled together.


## Limitations and next steps

- **No MCP integrations ship today.** `/compute` uses SymPy + NumPy; `/survey` uses the host's built-in web search. Planned but not implemented: `mcp-arxiv`, `mcp-papers` (index `references/`), `mcp-mathematica` (symbolic backend for licence-holders), tensor-algebra backends.
- **Four hosts supported.** Claude Code, Pi, OpenAI Codex CLI, OpenCode. Gemini CLI, Goose are not implemented yet — adding one is a folder under `hosts/`; see [DOCUMENTATION.md](DOCUMENTATION.md#adding-a-new-host).
- **No workspace upgrade path.** Changes to the methodology propagate to **new** workspaces on the next `init-physics-intern.sh` run. Existing workspaces keep whatever version they were created with, unless you re-run the bootstrap with reset (which preserves `problem.md` only).
