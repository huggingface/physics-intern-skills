#!/usr/bin/env bash
#
# init-physics-intern.sh — bootstrap a PhysicsIntern research workspace.
#
# Usage:
#   init-physics-intern.sh [--host=claude|pi|codex|opencode] [target-dir]
#
# If --host is omitted, the script prompts for one interactively (when run from
# a terminal; otherwise it defaults to claude).
# If target-dir is omitted, the current directory is used. The target dir is
# created if missing. The script renders workspace files from commons/ (shared
# methodology) plus hosts/<host>/ (host-specific config and extras) via
# commons/render.py, scaffolds a problem.md skeleton, creates artefact dirs,
# and makes the first git commit. The user then fills in problem.md, launches
# their coding agent, and runs /survey to begin — the agent reads problem.md
# directly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse CLI args: --host selects the agent host, positional arg is the target
# directory (defaults to current dir). If --host is omitted we ask interactively
# (see below) when run from a terminal.
HOST=""
HOST_SET=0
TARGET_DIR="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host=*) HOST="${1#--host=}"; HOST_SET=1 ;;
    --host)   HOST="$2"; HOST_SET=1; shift ;;
    -h|--help)
      sed -n '2,15p' "${BASH_SOURCE[0]}"
      exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1 ;;
    *)        TARGET_DIR="$1" ;;
  esac
  shift
done

# No --host given: ask interactively when attached to a terminal; otherwise keep
# the historical default of claude so piped / non-interactive runs never hang.
if [[ $HOST_SET -eq 0 ]]; then
  if [[ -t 0 ]]; then
    echo "Select an agent host:" >&2
    echo "  1) claude   — Claude Code (default)" >&2
    echo "  2) pi       — Pi" >&2
    echo "  3) codex    — OpenAI Codex CLI" >&2
    echo "  4) opencode — OpenCode" >&2
    while :; do
      printf "Host [1-4, Enter for 1]: " >&2
      read -r reply || reply=""
      case "${reply:-1}" in
        1|claude)   HOST="claude";   break ;;
        2|pi)       HOST="pi";       break ;;
        3|codex)    HOST="codex";    break ;;
        4|opencode) HOST="opencode"; break ;;
        *) echo "Please enter 1, 2, 3, or 4 (or a host name)." >&2 ;;
      esac
    done
  else
    HOST="claude"
  fi
fi

# Validate host selection — claude, pi, codex, opencode are supported.
case "$HOST" in
  claude|pi|codex|opencode) ;;
  *)
    echo "Error: --host must be 'claude', 'pi', 'codex', or 'opencode' (got '$HOST')" >&2
    exit 1 ;;
esac

# Sanity-check that the template sources this script needs are present.
if [[ ! -d "$SCRIPT_DIR/commons" || ! -d "$SCRIPT_DIR/hosts/$HOST" ]]; then
  echo "Error: commons/ or hosts/$HOST/ not found in $SCRIPT_DIR" >&2
  exit 1
fi

# Create the target dir if needed and cd into it; record its absolute path.
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"
TARGET_ABS="$(pwd)"

# Detect an existing PhysicsIntern workspace (any host) and offer reset. Pi,
# Codex and OpenCode all use AGENTS.md as the workspace doc, so we disambiguate
# by probing the host-specific directory (.pi/ vs .codex/ vs .opencode/) in
# addition to the "PhysicsIntern workspace" marker in the workspace doc.
RESET=0
EXISTING_HOST=""
if [[ -d .claude ]] && [[ -f CLAUDE.md ]] && grep -q "PhysicsIntern workspace" CLAUDE.md; then
  EXISTING_HOST="claude"
elif [[ -d .codex ]] && [[ -f AGENTS.md ]] && grep -q "PhysicsIntern workspace" AGENTS.md; then
  EXISTING_HOST="codex"
elif [[ -d .pi ]] && [[ -f AGENTS.md ]] && grep -q "PhysicsIntern workspace" AGENTS.md; then
  EXISTING_HOST="pi"
elif [[ -d .opencode ]] && [[ -f AGENTS.md ]] && grep -q "PhysicsIntern workspace" AGENTS.md; then
  EXISTING_HOST="opencode"
fi

# If a prior workspace is detected, prompt the user before wiping it.
# problem.md is preserved so the user doesn't lose the question they wrote.
if [[ -n "$EXISTING_HOST" ]]; then
  echo "$TARGET_ABS already contains a PhysicsIntern workspace (host: $EXISTING_HOST)."
  echo
  echo "Reset will REMOVE every file and directory here EXCEPT problem.md,"
  echo "then re-initialize from templates (host: $HOST). This discards:"
  echo "  - .git/ (all commit history, including uncommitted work)"
  echo "  - .claude/, .pi/, or .codex/, .gitignore, CLAUDE.md or AGENTS.md, research_log.md"
  echo "  - plan.md, survey.md, answer.md (if present)"
  echo "  - derivations/, computations/, critiques/, notes/, references/, data/"
  echo "  - skills/, prompts/, package.json (if pi); .agents/skills/ (if codex)"
  echo "  - anything else in this directory"
  echo
  printf "Reset? [y/N] "
  read -r REPLY
  case "$REPLY" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
  find . -mindepth 1 -maxdepth 1 ! -name 'problem.md' -exec rm -rf {} +
  RESET=1
  echo "Reset complete. Re-initializing..."
fi

# Render workspace files from commons/ + hosts/<host>/ via the bootstrap renderer.
python3 "$SCRIPT_DIR/commons/render.py" --host="$HOST" --target="$TARGET_ABS"

# Scaffold a problem.md skeleton if the user hasn't written one yet.
# They will fill in the setup and main question before launching the agent.
if [[ ! -f problem.md ]]; then
  cat > problem.md <<'EOF'
# Problem

### Problem setup

<describe the system, conventions, and any given equations or definitions>

### Main question

<state the question to be answered, including what counts as an answer>
EOF
fi

# Create the artefact directories where sub-agents will deposit their outputs.
# .gitkeep files ensure the empty dirs are tracked by git.
ARTEFACT_DIRS="derivations computations critiques notes references data"
for d in $ARTEFACT_DIRS; do
  mkdir -p "$d"
  touch "$d/.gitkeep"
done

# Per-dispatch brief files under .briefs/ within derivations/ and computations/.
mkdir -p derivations/.briefs computations/.briefs
touch derivations/.briefs/.gitkeep computations/.briefs/.gitkeep

# Seed notes/flags.md — the main agent's ledger of sub-agent flag dispositions.
if [[ ! -f notes/flags.md ]]; then
  cat > notes/flags.md <<'EOF'
# Flag dispositions

<!--
One line per sub-agent flag, written by the main agent during the integration loop:
  [skill][artefact-id] <flag summary> → accepted/dismissed/deferred (one-line reason)
See SYSTEM.md / CLAUDE.md → Integration loop.
-->
EOF
fi

# Initialize git (if needed) and make the bootstrap commit so the user has a
# clean baseline before the agent starts modifying files.
if [[ ! -d .git ]]; then
  git init -q
fi
git add -A
if [[ $RESET -eq 1 ]]; then
  git commit -q -m "Re-initialize PhysicsIntern workspace (reset, problem.md preserved, host: $HOST)" \
                -m "Bootstrapped from init-physics-intern.sh."
else
  git commit -q -m "Initialize PhysicsIntern workspace (host: $HOST)" \
                -m "Bootstrapped from init-physics-intern.sh."
fi

# Build the success message: header line plus host-specific launch instructions.
if [[ $RESET -eq 1 ]]; then
  HEADER="PhysicsIntern workspace reset and re-initialized (host: $HOST) at:"
else
  HEADER="PhysicsIntern workspace initialized (host: $HOST) at:"
fi

case "$HOST" in
  claude)
    LAUNCH_HINT="Launch Claude Code in this directory."
    ;;
  pi)
    LAUNCH_HINT="Register the workspace as a local Pi package, then launch Pi:
       pi install -l .            # makes /survey, /derive, etc. visible
       pi                         # launch (Pi auto-installs pi-subagents + pi-web-access from .pi/settings.json)"
    ;;
  codex)
    LAUNCH_HINT="Launch Codex in this directory:
       codex                       # first run will prompt to trust the project — accept it,
                                   # otherwise .codex/config.toml (sandbox + web search) is ignored
       Sub-agent roles auto-discover from .codex/agents/*.toml; dispatch uses spawn_agent + wait_agent."
    ;;
  opencode)
    LAUNCH_HINT="Launch OpenCode in this directory:
       opencode                    # commands (/survey, /derive, …) and sub-agents are
                                   # auto-discovered from .opencode/ — no registration step
       Sub-agent dispatch uses the 'task' tool (subagent_type=\"<role>\") or an @<role> mention.
       Note: dispatching custom sub-agents is version-dependent (opencode #29616) — if your
       build can't, run the role in-context per the role file. See AGENTS.md."
    ;;
esac

# Print final summary and next-steps guidance.
cat <<EOF

$HEADER
  $TARGET_ABS

Next steps:
  1. Edit problem.md — fill in '### Problem setup' and '### Main question'.
  2. $LAUNCH_HINT
  3. Run /survey to begin — the agent reads problem.md directly.
     (Or run /autoresearch to drive the full pipeline autonomously.)

EOF
