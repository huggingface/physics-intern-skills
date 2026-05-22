# PhysicsIntern

A methodology package for using AI coding agents (Claude Code, Pi, and other compatible harnesses) to conduct theoretical physics and mathematics research. This repo holds the methodology — workspace template, skills, agents, and the audit skill — plus a small set of sample workspaces and a benchmark corpus used to iterate on the methodology.

Modern AI coding harnesses already provide tool-use loops, fresh-context sub-agent dispatch, sandboxed Python, web search, and slash-command-as-skill. We don't rebuild those. The package layers a research methodology on top: structured survey, explicit plan, fresh-context derivations and adversarial reviews, strategic critique, systematic symbolic + numerical cross-checking, citation discipline.

State lives in plain markdown files. The main agent reads and edits those files, and interacts with the user; sub-agents handle substantive work in fresh contexts. Discipline is prose-encoded (in the workspace `CLAUDE.md` / `AGENTS.md` and the agent prompts).

The methodology is **host-agnostic**: one source tree (`src/`) is rendered per host (`hosts/<host>/`) by `bootstrap/render.py`. Adding a new agent or skill is one file; adding a new host is one folder.

## How to use

1. Create a workspace folder.
2. Run `init-physics-intern.sh` on it to render the template and scaffold the initial commit.
3. Edit `problem.md` to set up the problem statement and main question.
4. Start a session in that folder, and run `/start-research` to substitute the placeholders and make the first commit.
5. Run `/survey` to begin, then follow the plan and integration loop from there. The main agent dispatches sub-agents for the heavy lifting, integrates each return into the workspace state, and commits after every step. The user can intervene at any time to edit files, hand off to the main agent, or run a skill directly.


```bash
./init-physics-intern.sh ../my-new-workspace    # or path of choice (Claude Code by default)
cd ../my-new-workspace
# edit problem.md (### Problem setup, ### Main question)
claude                                          # then in Claude Code:
> /start-research                               # substitutes the placeholders, commits
> /survey                                       # begin
```

The bootstrap script renders the workspace files from `src/` + `hosts/<host>/`, scaffolds `problem.md` if missing, creates the artefact directories (`derivations/`, `computations/`, `critiques/`, `notes/`, `references/`, `data/`, plus `.briefs/` under `derivations/` and `computations/`), seeds `notes/flags.md`, initialises git, and makes the first commit. Re-running on an existing workspace prompts for a reset (preserves `problem.md`, wipes everything else).

The script also accepts `--host=pi` for the Pi target — same methodology, different conventions: `AGENTS.md` instead of `CLAUDE.md`, sub-agent dispatch via Pi's `subagent` tool, etc. Launch sequence for Pi is `pi install -l .` then `pi`. See §Hosts below.


## Repo layout

```
physics-intern/
├── README.md                          # this file
├── CLAUDE.md                          # repo-level dev instructions (not for workspaces)
├── init-physics-intern.sh             # workspace bootstrap script
├── src/                               # host-agnostic source of truth
│   ├── workspace-doc.md               # body of CLAUDE.md / AGENTS.md (with placeholders)
│   ├── research_log.md
│   ├── gitignore
│   ├── agents/                        # 7 fresh-context role prompts
│   │   ├── surveyor.md
│   │   ├── planner.md
│   │   ├── deriver.md
│   │   ├── computer.md
│   │   ├── reviewer.md
│   │   ├── critic.md
│   │   └── finalizer.md
│   └── skills/                        # 9 workflow files (main-agent workflows)
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
│   │   ├── host.py                    # workspace_doc, tools_map, frontmatter shape
│   │   ├── dispatch_example.md        # Task tool syntax example
│   │   └── extras/.claude/settings.json
│   └── pi/
│       ├── host.py
│       ├── preamble.md                # tool-discipline preamble injected at top
│       ├── dispatch_example.md        # subagent JSON example
│       ├── gitignore.extra            # node_modules/
│       └── extras/
│           ├── package.json
│           └── .pi/settings.json
├── bootstrap/                         # renderer
│   ├── render.py                      # reads src/ + hosts/<host>/, emits workspace
│   └── frontmatter.py                 # ~70-line stdlib YAML mini-parser
├── templates/, templates-pi/          # legacy reference (no longer used by bootstrap)
├── .claude/skills/
│   └── investigate-run/               # repo-level audit skill
├── workspaces/                        # sample workspaces — methodology test runs and real research
└── references/                        # benchmark problem corpus + helper scripts
```

## How a workspace runs

A workspace is a git repository. The user fills in `problem.md`, then talks to the main agent (Claude Code or Pi, started in the workspace directory). The main agent is a **coordinator only** — it never performs substantive surveys, derivations, computations, reviews, or critiques itself. Every workflow skill dispatches a fresh-context sub-agent that does the heavy lifting and writes its own artefact.

After each sub-agent return, the main agent runs the **integration loop**:

1. Read the sub-agent's `## Summary` / `## Result` / `## Flags`.
2. Integrate into `research_log.md` — update Working Claims / Established Results, source lists, dependencies.
3. Disposition every flag in `notes/flags.md` (one line per flag).
4. Update `plan.md` if a step is now done, obsolete, or revised.
5. Commit everything as one logical step.
6. Decide the next dispatch (or hand to the user).

Sub-agents do not commit. The integration loop is the load-bearing operational discipline; most of the methodology either feeds into it or is checked against it. The full rules live in the rendered workspace doc (`CLAUDE.md` / `AGENTS.md`) — not duplicated here.

## Skills

| Skill | Role |
|---|---|
| `/start-research` | One-time prep: verify `problem.md` is filled in, extract a one-line summary, substitute `{{PROBLEM_ONELINER}}` placeholders, commit. Runs in main-agent context. |
| `/survey` | Landscape orientation. Writes `survey.md`. Provisional — later evidence overrides it. |
| `/research-plan` | Drafts or updates `plan.md`. HITL for strategy-level changes; targeted edits are the main agent's job. |
| `/derive <claim>` | Analytical derivation in a fresh-context sub-agent. Writes `D-NNN.md`. Requires a dispatch brief at `derivations/.briefs/D-NNN-brief.md`. |
| `/compute <claim>` | Symbolic + numerical work (SymPy + NumPy default). Writes `C-NNN.{md,py,out}`. Symbolic and numerical run together when both are feasible; disagreement is flagged. Requires a brief at `computations/.briefs/C-NNN-brief.md`. |
| `/review <D-NNN \| C-NNN>` | Fresh-context adversarial review. Writes a sibling `_R<M>.md` carrying the verdict (`confirmed` / `refuted` / `inconclusive`). |
| `/critique` | Fresh-context strategic critique of the overall research state. Writes `CR-NNN.md`. |
| `/finalize` | Synthesises `answer.md` from Established Results. |
| `/autoresearch` | Drives the pipeline autonomously, skipping the three HITL gates. Records each skipped decision in `notes/auto-decisions.md`. Intended for methodology validation and problems where course correction is unlikely. |

The 7 substantive skills (`/survey` through `/finalize`) dispatch a named sub-agent; the agent prompt in `src/agents/<role>.md` carries the substance.


## Working on the methodology

The unit of change is usually one of:

- **`src/workspace-doc.md`** — the workspace main-agent prompt. Anything affecting how the main agent integrates returns, edits which files, dispatches with what context, or runs the checks-and-balances rule goes here.
- **`src/agents/<role>.md`** — the substantive prompts. One role per file (surveyor, planner, deriver, computer, reviewer, critic, finalizer). The skill workflows reference these.
- **`src/skills/<name>.md`** — the per-skill main-agent workflow. Edit when changing what the dispatcher passes to the sub-agent, the structured return contract, or the description visible to the main agent.
- **`hosts/<host>/`** — host-specific glue. Edit when a host's tool vocabulary, frontmatter shape, or dispatch syntax changes.
- **`init-physics-intern.sh`** and **`src/research_log.md`** — for new files seeded into the workspace skeleton, or new placeholders.
- **`.claude/skills/investigate-run/SKILL.md`** — when the methodology contract changes, the audit rules need to follow.

Changes propagate to **new** workspaces on the next `init-physics-intern.sh` run. Existing workspaces carry the methodology baked into their `.claude/` or `.pi/` at the time they were created — there is no upgrade skill, so older workspaces are patched by hand if needed.

After making prompt changes, the validation loop is: bootstrap a fresh workspace from `references/` (pick a benchmark problem), run it through, then `investigate-run` against the resulting workspace + session JSONL, compare findings to prior runs.


### Auditing a run: `investigate-run`

`.claude/skills/investigate-run/` is a repo-level audit skill (not part of any workspace's template — it's used while iterating on the methodology). Given a workspace path and a Claude Code session JSONL, it produces a post-mortem report covering:

- Trajectory reconstruction (skills dispatched, returns, integration actions).
- Methodology adherence against the rules baked into the workspace's `CLAUDE.md` / `AGENTS.md` and agent prompts.
- Commit discipline (one commit per integration step bundling artefact + main-agent edits).
- Flag-disposition trace (every `## Flags` entry must have a line in `notes/flags.md`).
- Prompt-vs-behaviour deltas (did sub-agents stay inside their declared tool list and scope?).
- Substantive quality (does `answer.md` answer `problem.md`?).

Run after a workspace session to see where the methodology slipped and which prompts to fix. Output lands in `/tmp/audit-<workspace>.md`.


### Design choices worth remembering

- **The host is a deployment decision, not an architectural one.** The methodology source lives in `src/`; per-host glue (tool names, frontmatter shapes, dispatch syntax) lives in `hosts/<host>/`. Adding Codex, OpenCode, or Gemini CLI means writing a `hosts/<host>/host.py` plus a small dispatch_example file.
- **Files are durable state; context is ephemeral.** The user may clear the session at any time. After a clear, the main agent must resume from `research_log.md` and `plan.md` alone. This is what allows the integration loop to be the only handoff mechanism.
- **Explicit dispatch, no auto-fork.** Both hosts use the same dispatch model: main agent reads the skill workflow, writes the brief, calls the dispatch tool (`Task` for Claude, `subagent` for Pi), integrates the return. Claude Code's `context: fork` auto-fork shortcut is not used — the symmetry is more valuable than the keystroke saved.
- **Fresh context for `/review` and `/critique` is non-negotiable.** Reviewers don't see prior reviews on the same target. Critics get only one-line summaries of prior critiques. Sub-agents don't see the main agent's reasoning.
- **No single sub-agent verdict moves research forward.** Before acting on a refutation or a strategy-changing critique finding, the main agent seeks a second opinion. A verdict is a *proposal*, not an order.
- **Robust evidence before promotion.** A Working Claim becomes Established only with evidence robust against typical failure modes — usually ≥2 independent dispatch contexts. A single artefact's internal symbolic + numerical cross-check counts as one source for conceptual-bug protection.
- **Prose-encoded discipline, not a state machine.** Promotion = the main agent editing a heading. Refutation = the main agent moving an entry to Dead Ends with a reason. No JSON state, no enum verdicts, no auto-promotion cascades. The bet: modern models follow prose-encoded rules well enough that the harness complexity isn't worth it. The audit skill catches drift.


## Hosts

Two hosts are supported today; both render from the same `src/` tree.

- **Claude Code** (`--host=claude`, default). Workspace doc at `CLAUDE.md`, sub-agent prompts at `.claude/agents/<role>.md`, skills at `.claude/skills/<name>/SKILL.md`. Sub-agent dispatch via the `Task` tool with `subagent_type` set to the agent name.

- **Pi** (`--host=pi`). Workspace doc at `AGENTS.md`, sub-agent prompts at `.pi/agents/<role>.md`, project settings at `.pi/settings.json` (declares `pi-subagents` + `pi-web-access` packages), skill/prompt directories declared in `package.json` under the `pi:` block. Skills are split Pi-style into thin `skills/<name>/SKILL.md` stubs (generated) and full workflow files in `prompts/<name>.md` (rendered with a Pi tool-discipline preamble). Launch sequence after `init-physics-intern.sh --host=pi`: `pi install -l .`, then `pi`.

## Next Steps

### MCP integrations

None ship today. `/compute` uses SymPy + NumPy; `/survey` uses host-provided web search.

Planned but not implemented: `mcp-arxiv` (arxiv search/fetch), `mcp-papers` (index `references/`), `mcp-mathematica` (symbolic backend for license-holders), and tensor-algebra backends.

### Other hosts

Codex, OpenCode, Gemini CLI, Goose — not implemented yet. Each would be a new `hosts/<host>/` folder with `host.py` (tools_map, frontmatter shape, paths), `dispatch_example.md`, and any host-specific extras. Codex is the closest structural cousin to Claude Code and would likely port mechanically once we agree on its frontmatter conventions.
