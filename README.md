# PhysicsIntern

A methodology package for using AI coding agents (currently Claude Code) to conduct theoretical physics and mathematics research. This repo holds the methodology — workspace template, skills, agents, and the audit skill — plus a small set of sample workspaces and a benchmark corpus used to iterate on the methodology.

Modern AI coding harnesses already provide tool-use loops, fresh-context sub-agent dispatch, sandboxed Python, web search, and slash-command-as-skill. We don't rebuild those. The package layers a research methodology on top: structured survey, explicit plan, fresh-context derivations and adversarial reviews, strategic critique, systematic symbolic + numerical cross-checking, citation discipline.

State lives in plain markdown files. The main agent reads and edits those files, and interacts with user; sub-agents handle substantive work in fresh contexts. Discipline is prose-encoded (in the workspace `CLAUDE.md` and agent prompts).

## How to use

1. Create a workspace folder
2. Run `init-physics-intern.sh` on it to copy the template and scaffold the initial commit
3. Edit `problem.md` to set up the problem statement and main question
4. Start a Claude Code session in that folder, and run `/start-research` to substitute the placeholders and make the first commit
5. Run `/survey` to begin, then follow the plan and integration loop from there. The main agent will dispatch to sub-agents for the heavy lifting, then integrate their returns into the workspace state and commit after every step. The user can intervene at any time to edit files, hand off to the main agent, or run a skill directly.


```bash
./init-physics-intern.sh ../my-new-workspace    # or path of choice
cd ../my-new-workspace
# edit problem.md (### Problem setup, ### Main question)
claude                                          # then in Claude Code:
> /start-research                               # substitutes the placeholders, commits
> /survey                                       # begin
```

The bootstrap script copies `templates/` into the target, scaffolds `problem.md` if missing, creates the artefact directories (`derivations/`, `computations/`, `critiques/`, `notes/`, `references/`), seeds `notes/flags.md`, initialises git, and makes the first commit. Re-running on an existing workspace prompts for a reset (preserves `problem.md`, wipes everything else).


## Repo layout

```
physics-intern/
├── README.md                          # this file
├── CLAUDE.md                          # repo-level dev instructions (not workspace)
├── init-physics-intern.sh             # workspace bootstrap script
├── templates/                         # what init-physics-intern.sh copies into a new workspace
│   ├── CLAUDE.md                      # workspace main-agent system prompt
│   ├── research_log.md                # skeleton with canonical sections
│   ├── gitignore
│   └── .claude/
│       ├── settings.json
│       ├── agents/                    # 7 fresh-context role prompts
│       │   ├── surveyor.md
│       │   ├── planner.md
│       │   ├── deriver.md
│       │   ├── computer.md
│       │   ├── reviewer.md
│       │   ├── critic.md
│       │   └── finalizer.md
│       └── skills/                    # 9 slash-command dispatchers
│           ├── start-research/        # one-time workspace header init
│           ├── survey/
│           ├── research-plan/
│           ├── derive/
│           ├── compute/
│           ├── review/
│           ├── critique/
│           ├── finalize/
│           └── autoresearch/          # autonomous full-pipeline driver
├── .claude/skills/
│   └── investigate-run/               # repo-level audit skill (used while iterating here)
├── workspaces/                        # sample workspaces — methodology test runs and real research
└── references/                        # benchmark problem corpus + helper scripts
```

## How a workspace runs

A workspace is a git repository. The user fills in `problem.md`, then talks to the main agent (Claude Code, started in the workspace directory). The main agent is a **coordinator only** — it never performs substantive surveys, derivations, computations, reviews, or critiques itself. Every skill forks to a fresh-context sub-agent that does the heavy lifting and writes its own artefact.

After each sub-agent return, the main agent runs the **integration loop**:

1. Read the sub-agent's `## Summary` / `## Result` / `## Flags`.
2. Integrate into `research_log.md` — update Working Claims / Established Results, source lists, dependencies.
3. Disposition every flag in `notes/flags.md` (one line per flag).
4. Update `plan.md` if a step is now done, obsolete, or revised.
5. Commit everything as one logical step.
6. Decide the next dispatch (or hand to the user).

Sub-agents do not commit. The integration loop is the load-bearing operational discipline; most of the methodology either feeds into it or is checked against it. The full rules live in `templates/CLAUDE.md` (which is what every workspace gets) — not duplicated here.

## Skills

| Skill | Role |
|---|---|
| `/start-research` | One-time prep: verify `problem.md` is filled in, extract a one-line summary, substitute `{{PROBLEM_ONELINER}}` placeholders, commit. Runs in main-agent context (no fork). |
| `/survey` | Landscape orientation. Writes `survey.md`. Provisional — later evidence overrides it. |
| `/research-plan` | Drafts or updates `plan.md`. HITL for strategy-level changes; targeted edits are the main agent's job. |
| `/derive <claim>` | Analytical derivation in a fresh-context sub-agent. Writes `D-NNN.md`. |
| `/compute <claim>` | Symbolic + numerical work (SymPy + NumPy default). Writes `C-NNN.{md,py}`. Symbolic and numerical run together when both are feasible; disagreement is flagged. |
| `/review <D-NNN \| C-NNN>` | Fresh-context adversarial review. Reviewer reads the whole target file but skips its `## Reviews` section. |
| `/critique` | Fresh-context strategic critique of the overall research state. Writes `CR-NNN.md`. |
| `/finalize` | Synthesises `answer.md` from Established Results. |
| `/autoresearch` | Drives the pipeline autonomously, skipping the three HITL gates. Records each skipped decision in `notes/auto-decisions.md`. Intended for methodology validation and problems where course correction is unlikely. |

The 7 substantive skills (`/survey` through `/finalize`) are thin dispatchers; the agent prompt in `templates/.claude/agents/<role>.md` carries the substance.


## Working on the methodology

The unit of change is usually one of:

- **`templates/CLAUDE.md`** — the workspace main-agent prompt. Anything affecting how the main agent integrates returns, edits which files, dispatches with what context, or runs the checks-and-balances rule goes here.
- **`templates/.claude/agents/<role>.md`** — the substantive prompts. One role per file (surveyor, planner, deriver, computer, reviewer, critic, finalizer). The skill dispatchers are thin and reference these.
- **`templates/.claude/skills/<name>/SKILL.md`** — only edit when changing what the dispatcher passes to the sub-agent, the structured return contract, or the description visible to the main agent.
- **`init-physics-intern.sh`** and `templates/research_log.md` — for new files seeded into the workspace skeleton, or new placeholders.
- **`.claude/skills/investigate-run/SKILL.md`** — when the methodology contract changes, the audit rules need to follow.

Changes propagate to **new** workspaces on the next `init-physics-intern.sh` run. Existing workspaces carry the methodology baked into their `.claude/` at the time they were created — there is no upgrade skill, so older workspaces are patched by hand if needed.

After making prompt changes, the validation loop is: bootstrap a fresh workspace from `references/` (pick a benchmark problem), run it through, then `investigate-run` against the resulting workspace + session JSONL, compare findings to prior runs.


### Auditing a run: `investigate-run`

`.claude/skills/investigate-run/` is a repo-level audit skill (not part of `templates/` — it's used while iterating on the methodology). Given a workspace path and a Claude Code session JSONL, it produces a post-mortem report covering:

- Trajectory reconstruction (skills dispatched, returns, integration actions).
- Methodology adherence against the 9 rules baked into the workspace's `CLAUDE.md` and agent prompts. (See its `SKILL.md` for the rule list.)
- Commit discipline (one commit per integration step bundling artefact + main-agent edits).
- Flag-disposition trace (every `## Flags` entry must have a line in `notes/flags.md`).
- Prompt-vs-behaviour deltas (did sub-agents stay inside their declared tool list and scope?).
- Substantive quality (does `answer.md` answer `problem.md`?).

Run after a workspace session to see where the methodology slipped and which prompts to fix. Output lands in `/tmp/audit-<workspace>.md`.


### Design choices worth remembering

- **The host is a deployment decision, not an architectural one.** Skill prompts and agent prompts are portable; only the host adapter (Claude Code agent/skill frontmatter, dispatch syntax) is host-specific. Pi or another harness can host the same methodology with a different L3 layer.
- **Files are durable state; context is ephemeral.** The user may `/clear` at any time. After `/clear`, the main agent must resume from `research_log.md` and `plan.md` alone. This is what allows the integration loop to be the only handoff mechanism.
- **Fresh context for `/review` and `/critique` is non-negotiable.** Reviewers don't see prior reviews on the same target. Critics get only one-line summaries of prior critiques. Sub-agents don't see the main agent's reasoning.
- **No single sub-agent verdict moves research forward.** Before acting on a refutation or a strategy-changing critique finding, the main agent seeks a second opinion. A verdict is a *proposal*, not an order.
- **Robust evidence before promotion.** A Working Claim becomes Established only with evidence robust against typical failure modes — usually ≥2 independent dispatch contexts. A single artefact's internal symbolic + numerical cross-check counts as one source for conceptual-bug protection.
- **Prose-encoded discipline, not a state machine.** Promotion = the main agent editing a heading. Refutation = the main agent moving an entry to Dead Ends with a reason. No JSON state, no enum verdicts, no auto-promotion cascades. The bet: modern models follow prose-encoded rules well enough that the harness complexity isn't worth it. The audit skill catches drift.

## Next Steps

### MCP integrations

None ship today. `/compute` uses SymPy + NumPy; `/survey` uses host-provided web search.

Planned but not implemented: `mcp-arxiv` (arxiv search/fetch), `mcp-papers` (index `references/`), `mcp-mathematica` (symbolic backend for license-holders), and tensor-algebra backends.

### Other hosts
- **Pi adapter** — only Claude Code is supported today.