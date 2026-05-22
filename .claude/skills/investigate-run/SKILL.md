---
name: investigate-run
description: Post-mortem analysis of a PhysicsIntern workspace run (Claude Code, Pi, or Codex host). Reconstructs the trajectory from the session JSONL(s), audits methodology adherence against the workspace's own CLAUDE.md / AGENTS.md and skill/agent prompts, checks commit discipline and flag dispositions, and assesses substantive quality. Produces a thorough evidence-anchored markdown report. Use after a workspace has been worked on to identify what went well, where the methodology slipped, and what prompts to improve.
context: fork
agent: general-purpose
arguments: [workspace_path, session_id]
---

# Investigate PhysicsIntern Run

You are auditing a PhysicsIntern workspace run. Three sources:

1. **The workspace** at `$workspace_path` — files, git history, and the actual skills/agents and methodology file the run was operating under (`.claude/` + `CLAUDE.md` for Claude Code, `.pi/` + `AGENTS.md` for Pi, `.codex/` + `AGENTS.md` for Codex).
2. **The session JSONL(s)** — every prompt, response, and tool call from the run. Single file for Claude Code; main-agent file plus per-skill sub-agent files for Pi; main-agent file plus per-spawned-agent files for Codex (see *Host detection and session locations* below).
3. **The methodology contract** — the workspace's own methodology file and `(.claude|.pi|.codex)/agents/`, `(.claude/skills|skills|.agents/skills)/`. These are the rules the run is being audited against. (Optional: the canonical templates in the parent `commons/` and `hosts/<host>/` dirs for cross-reference.)
4. **Reference solution** (if available) — the known-correct answer to the problem, if it exists, can be documented in `references/`. This is a quality check, not a methodology requirement; the audit should be honest about whether the run produced a correct, partially correct, or incorrect answer, but the main focus is on the process rather than the outcome.

The methodology promises:

1. **Main agent is coordinator only** — never performs substantive surveys, derivations, computations, reviews, or critiques itself.
2. **`research_log.md` invariants**: every Working Claim & Established Result lists ≥1 source; canonical section order (Open Questions → Working Claims → Established Results → Dead Ends → Conventions → Sanity Checks); Dead Ends compacted but never removed; every Open Question has a status line; every sub-agent flag dispositioned in `notes/flags.md` before the integration commit.
3. **Robust evidence before promotion**: a Working Claim becomes Established only when evidence is robust against typical failure modes (conceptual / transcription / sign-factor). Usually that means ≥2 sources from **independent dispatch contexts** — a single artefact's internal sym/num cross-check counts as one source for conceptual-bug protection. If only one approach is genuinely available, the reasoning must be recorded explicitly in `research_log.md` alongside the source list.
4. **Fresh context for /review and /critique** — reviewers do not read sibling review files (`D-NNN_R*.md` / `C-NNN_R*.md`) for the same target; critics receive only one-line summaries of prior critiques. (Workspaces predating 2026-05 use an in-file `## Reviews` section on the target; the audit accepts either convention.)
5. **Review is part of standard flow** — after `/derive` or `/compute`, the next dispatch should be `/review` (unless trivial; batching is permitted but must be recorded in `notes/flags.md`).
6. **Integration loop**: every sub-agent return is followed by (i) `research_log.md` integration, (ii) per-flag disposition in `notes/flags.md`, (iii) any `plan.md` edits, (iv) **one commit** that bundles the artefact + main-agent edits. Sub-agents do not commit.
7. **Main agent edits**: `research_log.md`, `notes/` (incl. `notes/flags.md`), `critiques/CR-NNN.md` (Resolution + status), and **targeted edits to `plan.md`** (mark done / drop / retitle / revise upcoming step). Strategy-level plan changes re-invoke `/research-plan`. Sub-agents own their artefacts.
8. **Sub-agent return schema**: both (8a) the artefact file on disk and (8b) the reply-channel message (Claude Code `tool_result.content`, Pi `subagent` return body, Codex `wait_agent` reply / `last_task_message`) carry `## Summary` / `## Result` / `## Flags` (empty Flags rendered as `- (none)`). Extra sections (e.g. `## Integration actions`, `## Recommended next steps`) violate the schema. The two channels drift independently — usually the artefact is fine and the reply is prose. Flags are proposals; the main agent must record the disposition in `notes/flags.md`.
9. **HITL for /research-plan** (strategy-level) — the sub-agent drafts, the main agent presents to the user for approval before continuing. Targeted plan edits by the main agent do not require user approval.

## Inputs

- `$workspace_path` (required): path to the workspace directory (e.g. `/Users/david/projects/theoretical-physics/physics-agent/qec`).
- `$session_id` (optional): UUID of the session. If omitted, auto-discover based on host (see below).

If `$ARGUMENTS` is empty, ask the user for the workspace path.

## Host detection and session locations

First detect which host the workspace was run under by checking which methodology dir exists:

- **Claude Code**: `<workspace>/.claude/` and `CLAUDE.md` present. Single main-agent JSONL at `~/.claude/projects/<encoded>/<uuid>.jsonl`. Sub-agent activity (Skill forks) is journaled inline in the same JSONL.
- **Pi**: `<workspace>/.pi/` and `AGENTS.md` present. **Both main and sub-agent JSONLs live under `~/.pi/agent/sessions/`** — main-agent at `~/.pi/agent/sessions/<encoded>/<timestamp>_<uuid>.jsonl`, and per-sub-agent JSONLs **nested under a sibling dir with the same basename** (timestamp + uuid, no `.jsonl`): `~/.pi/agent/sessions/<encoded>/<timestamp>_<uuid>/<short-id>/run-N/session.jsonl` (one `<short-id>` subdir per dispatched sub-agent, `run-N` for retries). Legacy Pi placed sub-agent logs at `<workspace>/.pi/sessions/<skill>/run-N/` — fall back to that if the nested layout is empty. Audit both files: the main-agent shows orchestration decisions, the sub-agents show what each fork actually did. A sibling `<encoded>/subagent-artifacts/` dir holds `<short-id>_<agent>_<n>_{input,output,meta}` triples — useful as a fast summary parallel to the JSONLs.
- **Codex**: `<workspace>/.codex/` and `AGENTS.md` present. Sessions are **date-organised, not workspace-organised** — JSONLs live at `${CODEX_HOME:-~/.codex}/sessions/YYYY/MM/DD/rollout-<ts>-<uuid>.jsonl`. Discover the main-agent session by reading the first record of candidate files and matching `cwd` against the workspace absolute path. **Two schemas exist**: current Codex (`multi_agents_v2`, GPT-5) uses top-level `type=="response_item"` / `type=="event_msg"` / `type=="session_meta"` with `cwd` at `.payload.cwd`; legacy Codex uses `item.type` tags (`SessionMeta`/`FunctionCall`/`EventMsg`) with `cwd` at `.item.cwd`. Sub-agent activity lives in **separate JSONL files** under the same date tree; linkage is the child UUID inside `close_agent.arguments.target` (current) or `CollabAgentSpawnBegin.child_thread_id` (legacy), which matches the child JSONL's filename suffix.

The encoded path uses `/` → `-`. Claude Code drops the leading `/`; Pi preserves it with a leading `--` (verify by `ls ~/.pi/agent/sessions/`). Codex does not encode the workspace path into the filename at all — filter by `.payload.cwd` (current) / `.item.cwd` (legacy) instead.

### Auto-discovery snippet (bash)

```bash
WS="$workspace_path"
if [ -d "$WS/.claude" ]; then
  HOST=claude
  ENCODED=$(echo "$WS" | sed 's|/|-|g')
  SESSION_DIR="$HOME/.claude/projects/${ENCODED}"
  if [ -n "$session_id" ]; then
    JSONL="${SESSION_DIR}/${session_id}.jsonl"
  else
    JSONL=$(ls -t "${SESSION_DIR}"/*.jsonl 2>/dev/null | head -1)
  fi
  SUBAGENT_LOGS=""   # inline in $JSONL
elif [ -d "$WS/.pi" ]; then
  HOST=pi
  # Pi encodes the workspace path with `/` → `-` and a `--` wrap on each side
  # (e.g. `--Users-david-...-qec-pi--`). Glob rather than reconstruct.
  WS_BASENAME=$(basename "$WS")
  SESSION_DIR=$(ls -d "$HOME/.pi/agent/sessions/"*"${WS_BASENAME}"* 2>/dev/null | head -1)
  JSONL=$(ls -t "${SESSION_DIR}"/*.jsonl 2>/dev/null | head -1)
  # Current Pi nests sub-agent JSONLs under a sibling dir named after the full
  # JSONL basename (timestamp + uuid, no .jsonl extension):
  #   $SESSION_DIR/<timestamp>_<uuid>/<short-id>/run-N/session.jsonl
  SUBAGENT_LOGS_NEW="${JSONL%.jsonl}"   # full basename, including timestamp prefix
  SUBAGENT_LOGS_LEGACY="$WS/.pi/sessions"   # legacy per-skill layout
  if compgen -G "${SUBAGENT_LOGS_NEW}/*/run-*/session.jsonl" >/dev/null 2>&1; then
    SUBAGENT_LOGS="${SUBAGENT_LOGS_NEW}"   # contains <short-id>/run-N/session.jsonl
  else
    SUBAGENT_LOGS="${SUBAGENT_LOGS_LEGACY}"  # contains <skill>/run-N/session.jsonl
  fi
elif [ -d "$WS/.codex" ]; then
  HOST=codex
  # Codex sessions are date-organised under ~/.codex/sessions/YYYY/MM/DD/
  # — not keyed by workspace. Filter all candidates by cwd, then pick the most
  # recently-modified. Current schema puts cwd at .payload.cwd; legacy at .item.cwd.
  SESSION_ROOT="${CODEX_HOME:-$HOME/.codex}/sessions"
  if [ -n "$session_id" ]; then
    JSONL=$(find "$SESSION_ROOT" -name "*${session_id}*.jsonl" 2>/dev/null | head -1)
  else
    matches=$(find "$SESSION_ROOT" -name "rollout-*.jsonl" 2>/dev/null | while read -r f; do
      cwd=$(head -1 "$f" 2>/dev/null | jq -r '.payload.cwd // .item.cwd // empty' 2>/dev/null)
      [ "$cwd" = "$WS" ] && echo "$f"
    done)
    JSONL=$(printf '%s\n' "$matches" | xargs ls -t 2>/dev/null | head -1)
  fi
  # Sub-agent JSONLs are discovered from spawn/close events in the main JSONL
  # (each carries a child UUID matching the per-child filename suffix).
  SUBAGENT_LOGS="$SESSION_ROOT"
fi
```

If `$JSONL` is missing or empty, do the analysis from the workspace + git history alone and note the gap in the report. For Pi, also enumerate `$SUBAGENT_LOGS/*/run-*/session.jsonl` since those exist independently of the main-agent JSONL.

## Procedure

Execute in order. Use `jq`, `grep`, `git`, and `Read` liberally.

### Step 1 — Sanity checks and scope

- Confirm `$workspace_path` exists and contains `problem.md` plus the host's methodology file: `CLAUDE.md` + `.claude/` for Claude Code, `AGENTS.md` + `.pi/` for Pi, or `AGENTS.md` + `.codex/` for Codex.
- Read the workspace's methodology file and `(.claude|.pi|.codex)/agents/*` (Markdown for Claude/Pi, TOML for Codex) and `(.claude/skills|skills|.agents/skills)/*/SKILL.md` — these are the **actual prompts the run was using**. The audit's contract is what these say, not what the canonical drafts say. Note any divergence from the canonical drafts.
- `wc -l "$JSONL"` to size the transcript. If >100k lines, plan to sample.
- Capture run shape: number of artefacts, number of commits, wall-clock from first to last JSONL timestamp.

### Step 2 — Trajectory reconstruction

The schema differs by host — pick the right extractor.

**Claude Code.** Tool calls are top-level events with `type=="tool_use"`; sub-agent dispatches use `name=="Skill"`; results are separate `tool_result` events. Sub-agent activity (Reads, Edits, etc. inside the fork) is journaled inline in the same JSONL.

```bash
jq -c 'select(.type=="assistant" or .type=="user" or .type=="tool_use" or .type=="tool_result") | {type, ts:.timestamp, name:.tool_name, inp:.tool_input, out:.tool_result}' "$JSONL" > /tmp/events.jsonl
```

For each `tool_use` with `name=="Skill"`: capture `dispatch_ts`, skill name, `$ARGUMENTS`, the matching `tool_result` `return_ts` and content.

**Pi.** Tool calls are nested inside `message` events: `.message.content[].type == "toolCall"`. Sub-agent dispatches use `name == "subagent"`, with `.arguments.tasks[].agent` (e.g. `surveyor`, `deriver`), `.arguments.tasks[].task` (the dispatch brief), and `.arguments.sessionDir` (relative path to the per-skill sub-agent JSONL, e.g. `.pi/sessions/survey`). The sub-agent's full activity log is **in that per-skill JSONL**, not in the main-agent JSONL.

```bash
# Main-agent dispatches
jq -c 'select(.type=="message") | .message.content[]? | select(.type=="toolCall" and .name=="subagent")' "$JSONL" > /tmp/dispatches.jsonl

# For each dispatch, the sub-agent journal is at $WS/<sessionDir>/run-0/session.jsonl
# (or run-1, run-2 for retries — list them)
```

For each Pi `subagent` call: capture `dispatch_ts` (from the enclosing message), agent name, task body, and read the per-skill `session.jsonl` (`$SUBAGENT_LOGS/<basename>/run-*/session.jsonl`) for the full sub-agent trajectory and the structured return.

**Codex.** Two schemas exist — sniff before extracting:

```bash
jq -r '.type // .item.type' "$JSONL" 2>/dev/null | sort -u | head
```

If the top-level keys are `response_item` / `event_msg` / `session_meta` (lowercase tagged), the run is on **current Codex** (`multi_agents_v2`, GPT-5). If they're `SessionMeta` / `FunctionCall` / `EventMsg` (PascalCase under `.item.type`), it's **legacy Codex** — fall through to the legacy `jq` at the bottom.

**Current schema.** Main-agent tool calls split across two `payload.type` values:

- `function_call` — used by `exec_command`, `spawn_agent`, `wait_agent`, `close_agent`, and a few others.
- `custom_tool_call` — used by `apply_patch` (a freeform Lark-grammar tool, distinct from `function_call`).

The current tool inventory in `commons/` / `hosts/codex/` exposes essentially: `exec_command` (shell — Codex's **only file-read primitive**, used via `sed -n`, `cat`, `rg`, `ls`, `find`, `git`), `apply_patch` (the dedicated edit tool), and the `spawn_agent` / `wait_agent` / `close_agent` triple for sub-agent orchestration. **There is no native `read_file` / `edit_file` / `write_file` / `grep` / `glob`** — every file read is a shell call.

```bash
# All main-agent tool calls (both payload kinds)
jq -c 'select(.type=="response_item" and (.payload.type=="function_call" or .payload.type=="custom_tool_call"))
       | {ts:.timestamp, name:.payload.name, kind:.payload.type, args:.payload.arguments}' "$JSONL" > /tmp/calls.jsonl

# Sub-agent dispatch lifecycle (spawn / wait / close)
jq -c 'select(.type=="response_item" and .payload.type=="function_call"
              and (.payload.name=="spawn_agent" or .payload.name=="wait_agent" or .payload.name=="close_agent"))' "$JSONL" > /tmp/dispatches.jsonl

# For each close_agent, the child UUID locates the per-agent JSONL:
#   target=$(echo "$args" | jq -r '.target')
#   find "${CODEX_HOME:-$HOME/.codex}/sessions" -name "*${target}*.jsonl"
```

**Legacy schema** (older Codex builds). Each line is `{timestamp, item}` with `item.type` in `FunctionCall` / `FunctionCallOutput` / `EventMsg`. Sub-agent dispatches appear as `EventMsg` items with `msg.type` in `CollabAgentSpawnBegin` / `CollabAgentSpawnEnd` etc., carrying the child `thread_id`. The current `jq` above will return nothing on legacy — use:

```bash
jq -c 'select(.item.type=="FunctionCall") | {ts:.timestamp, name:.item.name, args:.item.arguments}' "$JSONL" > /tmp/calls.jsonl
jq -c 'select(.item.type=="EventMsg" and (.item.msg.type | startswith("CollabAgent")))' "$JSONL" > /tmp/dispatches.jsonl
```

For all three hosts, for each sub-agent return:

- Wall-clock = `return_ts - dispatch_ts`.
- Was the return the canonical `## Summary / ## Result / ## Flags` schema, or did it invent sections?
- Identify main-agent activity *between* this return and the next skill dispatch: which files were edited, which user messages came in, which AskUserQuestion fired.

Produce a numbered trajectory table.

### Step 3 — Commit discipline

```bash
cd "$WS" && git log --all --pretty='%h %ai %s'
git status --porcelain
```

For each skill invocation in step 2: was there a commit between `dispatch_ts` and `return_ts` (or shortly after) that touched the expected artefact (e.g. `survey.md` for `/survey`, `derivations/D-NNN.md` for `/derive`, etc.)? Build a table:

| Skill | Expected artefact | Commit? | Files left uncommitted |
|---|---|---|---|

End-of-run `git status` is the ground truth for which files are uncommitted. Any non-empty entry there is a finding.

### Step 4 — Methodology adherence (rule-by-rule)

For each rule above (Rule 8 split into 8a artefact + 8b reply channel — 10 checks total), decide **pass / partial / fail** with specific evidence. Don't be charitable. Cite JSONL line numbers (or `jq` queries) and commit hashes.

Mechanical checks:

- **Rule 1 (coordinator-only)**: count main-agent tool calls by type. Flag any main-agent Write/Edit to `derivations/`, `computations/`, `critiques/CR-NNN.md` `## Findings`, `survey.md`, `answer.md`. Also scan main-agent text turns for inline derivations or substantive maths/code — heuristic: text turn with multiple equations not framed as quoted sub-agent output. **Tool-count caveat**: raw tool counts are *not comparable across hosts* — Claude Code has dedicated `Read`/`Edit`/`Write`, Pi has structured `read`/`edit`/`write`, Codex has only `exec_command` + `apply_patch` (so every file read is a `sed -n` shell). For Codex, classify each `exec_command` by command stem (`sed`/`cat`/`rg`/`find`/`ls`/`git`/`mkdir`/`python`/`curl`) before counting — a `git commit` and a `sed -n` view are not the same logical operation. Report both the raw count and the normalised count of **logical operations** (file-reads, file-writes, sub-agent dispatches, commits, HITL prompts).
- **Rule 2 (research_log invariants)**: parse the final `research_log.md`. Check:
  - Canonical section order.
  - Every `W-` and `E-` entry has a `sources:` line.
  - Every Open Question has a status line.
  - Dead Ends section never shrank across commits (`git log -p -- research_log.md | grep -c "Dead End"` over time should be monotonic non-decreasing).
  - **`notes/flags.md` exists** and contains a disposition for every sub-agent flag returned during the run (cross-check against step 5).
- **Rule 3 (robust evidence before promotion)**: for each ER, extract cited sources and group by **dispatch context** — two paths inside the same `C-NNN.md` artefact count as one. An ER with all sources in one dispatch context is flagged UNLESS the entry explicitly records why only one approach is available. The audit should not be charitable about this: vague "no other method available" without a stated reason → still a finding.
- **Rule 4 (fresh-context for /review and /critique)**: spot-check the dispatch argument passed to `/review`. Did it include prior reviews of the same target (the target's `## Reviews` section in legacy workspaces, or any sibling `_R*.md` file in current workspaces)? It should not. For `/critique`, were only one-line summaries of prior critiques passed (not full bodies)?
- **Rule 5 (review-after-derive/compute)**: for every `D-NNN.md` and `C-NNN.md`, check that **at least one** of the following holds: (i) a `## Reviews` heading exists in the target (legacy convention), or (ii) a sibling `D-NNN_R*.md` / `C-NNN_R*.md` file exists (current convention). Missing both → flag with the artefact ID. If review was batched (multiple `/derive` or `/compute` before `/review`), check `notes/flags.md` for the recorded reasoning.
- **Rule 6 (integration loop / commits)**: tally from step 3. Each skill invocation should produce one commit that bundles the sub-agent's artefact, the `research_log.md` update, the `notes/flags.md` dispositions, and any `plan.md` edits. Missing commits, or commits that touch only the artefact without the main-agent edits, → flag.
- **Rule 7 (main-agent edit scope)**: parse all main-agent `Edit`/`Write` tool calls. Allowed paths: `research_log.md`, `notes/*` (incl. `notes/flags.md`), `critiques/CR-NNN.md` (Resolution/status only — not the original findings), `plan.md` (targeted edits: mark done, drop, retitle, revise upcoming step). Edits to `derivations/` (incl. `D-NNN_R*.md` review files), `computations/` (incl. `C-NNN_R*.md`), `survey.md`, `answer.md`, legacy `## Reviews` sections in target files, or wholesale rewrites of `plan.md` → finding.
- **Rule 8a (artefact schema)**: every artefact file (`survey.md`, `D-NNN.md`, `C-NNN.md`, `D/C-NNN_R*.md`, `CR-NNN.md`, `answer.md`) should match the agent's declared heading structure — usually `## Summary` / `## Result` / `## Flags` (critiques: `## Findings` / `## Resolution`). Extra sections (`## Recommended next steps`, etc.) are findings. Check by `grep -E '^## ' <artefact>`.
- **Rule 8b (reply-channel schema)**: the sub-agent's **reply message** — the body the main agent actually sees inline as the dispatch return — should *also* be the canonical `## Summary` / `## Result` / `## Flags` block, not a narrative summary. Locations: Claude Code → `tool_result.content` in the main JSONL; Pi → the `subagent` tool's return body (also visible at the head of the per-sub-agent `session.jsonl`); Codex → the `wait_agent` reply / `last_task_message`. Schema drift on 8b is **independent** of 8a — artefacts are usually fine; replies are where drift lives, and it causes flags to be silently dropped because the main agent integrates from the reply, not the file. Empty Flags should be `## Flags\n- (none)\n`, not omitted.
- **Rule 9 (HITL for /research-plan)**: between a strategy-level `/research-plan` return and the next non-research-plan skill dispatch, look for `AskUserQuestion`, user message, or main-agent text presenting the plan for approval. Missing → flag. Targeted plan edits by the main agent (not via `/research-plan`) do not require approval; do not flag those.

### Step 5 — Flag-disposition trace

For every sub-agent return that contained a `## Flags` block:

- Extract each flag (one bullet per flag).
- **Primary check**: is there a corresponding line in `notes/flags.md`? The canonical disposition record is:
  `[skill][artefact-id] <flag summary> → accepted/dismissed/deferred (one-line reason)`
- Verify the disposition matches subsequent main-agent activity within ~5 minutes / before next skill dispatch:
  - **accepted** → a `research_log.md` edit, a follow-up skill dispatch, or a `notes/*` file created.
  - **dismissed** → reason in the `notes/flags.md` line is sufficient; no further action needed.
  - **deferred** → reason names what's being waited on or when to revisit.
- Flags with no entry in `notes/flags.md` → finding ("silently dropped"), regardless of any incidental activity afterwards.

If `notes/flags.md` is missing entirely, that is itself a finding — `init-physics-intern` seeds it, and the integration loop mandates its use.

### Step 6 — Prompt-vs-behaviour delta

Compare what the workspace's `(.claude|.pi|.codex)/agents/*` (Markdown / Markdown / TOML) and `(.claude/skills|skills|.agents/skills)/*/SKILL.md` *claim* against what actually happened:

- For each agent's declared `tools:` list: did the sub-agent run any tool outside that list? (Possible — Claude Code may not strictly enforce.) Note for each agent.
- For each agent's declared artefact heading structure (e.g. "writes `## Derivation`"): does the produced artefact actually use those headings? Mismatches are findings.
- For each agent's "Do NOT" constraints: any violations?
- For each agent's "report back via `## Flags` rather than expanding scope": any cases where the sub-agent silently expanded scope (Read other artefacts, browsed `references/`)?
- **Brief priors-leakage** (main-agent side): scan the dispatch briefs (the `$ARGUMENTS` / `task` / `prompt` body the main agent passes to `/derive`, `/compute`, `/review`, `/critique`) for explicit numeric targets ("This should give 16/25"), pre-stated sub-claim values ("Sub-claim: u_1 = 7"), or worked hints. The sub-agent is supposed to discover those independently — pre-stating them defeats the cross-check. This is distinct from Rule 4 (leaking prior **reviews**); this leaks author-supplied **priors**. Flag with the brief file path or JSONL event ID and quote the offending line.

### Step 7 — Substantive quality (lighter pass)

- Does `answer.md` exist? Does it cite ER IDs inline? Does it name assumptions and sanity checks?
- Cross-check `research_log.md` ER citations against actual artefact files: `grep -E 'D-[0-9]+|C-[0-9]+' research_log.md` → does each cited file exist? Open it; does its `# Task` match the claim?
- Reconcile `plan.md` final state with `research_log.md`: completed plan steps should map to ERs or Dead Ends; dropped steps should have a stated reason.
- Note if any unresolved critique findings (`status: pending` in `critiques/`) bear on the answer.

### Step 8 — Compile the report

Write to `/tmp/audit-<workspace-basename>.md`. Structure:

```markdown
# <Workspace> Run Post-Mortem

## Run shape
<wall-clock; # skill invocations; # commits; # artefacts; headline judgement (substantive answer correct/partial/wrong)>

## Trajectory
<numbered list with timestamps, dispatch args, return summary, integration actions>

## Methodology adherence
<table: rule → pass/partial/fail with evidence>

## Prompt-quality issues
<numbered findings; each with file:line, current text, observed behaviour, proposed fix>

## Workflow observations

### Per-dispatch wall-clock

| # | Skill | Agent | Dispatched at | Returned at | Duration | Artefact |
|---|---|---|---|---|---|---|

### Main-agent tool inventory

Report logical operations (comparable across hosts) and raw tool calls (host-dependent) separately.

| Logical operation | Count |
|---|---|
| Sub-agent dispatches | |
| File reads | |
| File writes/edits | |
| Commits | |
| Shell (other) | |
| HITL prompts | |

| Raw tool / command stem | Count | Notes |
|---|---|---|

### Backtracks, retries, recoveries
<list any: deriver re-runs, apply_patch retries, `close_agent` thread-limit recoveries, HITL clarifications, sub-agent timeouts>

## Substantive quality
<short prose: does answer.md actually answer problem.md; are artefacts well-formed>

## Recommended fixes (prioritised)
1. <highest impact, with specific files to edit>
2. ...
```

Then return a tight summary (under 800 words) to the caller covering:

- Headline verdict (substantive correctness + methodology score)
- Top 5 findings with evidence anchors
- Top 5 recommended fixes
- Anything systemic (e.g. "the heading-slice spec is fiction" applies across multiple sub-agents)

## Heuristics to bake in

- **"Did not commit per integration loop"** = no commit between `dispatch_ts` and `return_ts` (or within ~30s after) that touches both the expected artefact AND the main-agent integration edits (`research_log.md`, `notes/flags.md`, optionally `plan.md`).
- **"Flag silently dropped"** = a flag returned in a `## Flags` block has no corresponding line in `notes/flags.md`. Subsequent incidental activity does not redeem it; the disposition record is the canonical signal.
- **"Single-context ER"** = the union of cited artefact files spans ≤1 dispatch context, AND the entry does not record an explicit "only one approach available because …" reason. Multiple paths inside one `C-NNN.md` or one `D-NNN.md` is still one context.
- **"Missing review"** = an ER-cited source artefact (`D-NNN.md` or `C-NNN.md`) has neither a `## Reviews` heading (legacy) nor any sibling `_R*.md` file (current).
- **"Scope expansion"** = a sub-agent Read a file outside its dispatch (`grep` the JSONL for `Read` tool calls inside the fork; cross-check against what was named in the dispatch).
- **"Artefact schema drift"** (Rule 8a) = the on-disk artefact file (`D-NNN.md`, etc.) contains sections outside the agent's declared schema, or is missing the canonical `## Summary` / `## Result` / `## Flags` block.
- **"Reply-channel schema drift"** (Rule 8b) = the sub-agent's **reply message** (what the main agent sees inline as the dispatch return) is narrative prose without `## Summary` / `## Result` / `## Flags` headers — even when the on-disk artefact is canonical. Most common on Codex (`wait_agent` reply) and on long-artefact returns in Claude Code. Causes flags to be silently dropped because the main agent integrates from the reply, not the file.
- **"Brief priors-leakage"** = the main agent's dispatch brief pre-states the expected answer numerically ("This should give 16/25") or names a sub-claim's value. Distinct from Rule 4 — Rule 4 is about leaking prior **reviews**; this is leaking author-supplied **priors**.

## Constraints

- **Be evidence-anchored.** Cite file paths, line numbers, JSONL events, commit hashes. Findings without evidence are useless.
- **Don't be charitable.** A "soft" violation is still a violation; flag it as partial rather than passing.
- **Don't propose generic fixes** ("be more rigorous"). Propose specific edits to specific files with the current text and the replacement.
- **Stateless and idempotent** — runnable any time, any workspace + session JSONL pair. Do not edit the workspace, the JSONL, or any global files. Only write to `/tmp/audit-*.md`.
- **Honest about gaps.** If the session JSONL is missing or truncated, say so and report only what the workspace + git can tell you.

## Tools required

`Read`, `Bash` (for `jq`, `grep`, `git`, `wc`, `ls`), `Write` (only to `/tmp/`).
