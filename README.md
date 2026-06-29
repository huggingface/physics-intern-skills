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

./init-physics-intern.sh ../my-new-workspace    # Claude Code by default
cd ../my-new-workspace

# Edit problem.md — fill in the '### Problem setup' and '### Main question' blocks.
$EDITOR problem.md

claude                                          # launch Claude Code in this directory
> /start-research                               # substitutes placeholders, makes the first commit
> /survey                                       # begin
```

That's it. The agent will work through the research arc, dispatching sub-agents, integrating their results, and committing after each step. You can intervene at any point: edit files directly, ask the main agent a question, or run a slash command yourself.


## Hosts

Pick a host at workspace-creation time via `--host`. Same methodology in every case; the launch sequence differs.

### Claude Code (default)

```bash
./init-physics-intern.sh ../my-workspace        # --host=claude is the default
cd ../my-workspace
claude
> /start-research
> /survey
```

### Pi

```bash
./init-physics-intern.sh --host=pi ../my-workspace
cd ../my-workspace
pi install -l .                                 # register the workspace as a local Pi package
pi                                              # auto-installs pi-subagents + pi-web-access
> /start-research
> /survey
```

### OpenAI Codex CLI

```bash
./init-physics-intern.sh --host=codex ../my-workspace
cd ../my-workspace
codex                                           # on first run, accept the "trust this project" prompt
                                                # — otherwise .codex/config.toml (incl. agent_roles) is ignored
> /start-research
> /survey
```

Sub-agent dispatch on Codex uses `spawn_agent` + `wait_agent` from the `multi_agents_v2` namespace, which is under active OpenAI development.

### OpenCode

```bash
./init-physics-intern.sh --host=opencode ../my-workspace
cd ../my-workspace
opencode                                        # commands and sub-agents auto-discovered from .opencode/
> /start-research
> /survey
```

Sub-agent dispatch on OpenCode uses the native `Task` tool with `subagent_type` (the same shape as Claude Code). Commands (`.opencode/commands/`) and agents (`.opencode/agents/`) are auto-discovered — no registration step.


## What `init-physics-intern.sh` does

The bootstrap script renders a workspace from this repo's templates:

- Creates `CLAUDE.md` (Claude) or `AGENTS.md` (Pi, Codex, OpenCode) — the main-agent prompt encoding the entire research methodology.
- Renders the seven sub-agent role prompts and nine workflow skills into the host's expected layout.
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
| `/start-research` | One-time prep: read `problem.md`, extract a one-line summary, substitute `{{PROBLEM_ONELINER}}` placeholders, commit. |
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
