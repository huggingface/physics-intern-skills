#!/usr/bin/env bash
#
# init-physics-intern.sh — bootstrap a PhysicsIntern research workspace.
#
# Usage:
#   init-physics-intern.sh [--host=claude|pi] [target-dir]
#
# If target-dir is omitted, the current directory is used. The target dir is
# created if missing. The script renders workspace files from src/ (shared
# methodology) plus hosts/<host>/ (host-specific config and extras) via
# bootstrap/render.py, scaffolds a problem.md skeleton, creates artefact dirs,
# and makes the first git commit. It does NOT extract a problem one-liner —
# the user fills in problem.md, then launches their coding agent and runs
# /start-research, which reads problem.md and substitutes the
# {{PROBLEM_ONELINER}} placeholders.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HOST="claude"
TARGET_DIR="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host=*) HOST="${1#--host=}" ;;
    --host)   HOST="$2"; shift ;;
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

case "$HOST" in
  claude|pi) ;;
  *)
    echo "Error: --host must be 'claude' or 'pi' (got '$HOST')" >&2
    exit 1 ;;
esac

if [[ ! -d "$SCRIPT_DIR/src" || ! -d "$SCRIPT_DIR/hosts/$HOST" ]]; then
  echo "Error: src/ or hosts/$HOST/ not found in $SCRIPT_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"
TARGET_ABS="$(pwd)"

# Detect an existing PhysicsIntern workspace (either host) and offer reset.
# Claude workspaces are marked by CLAUDE.md; Pi workspaces by AGENTS.md.
RESET=0
EXISTING_HOST=""
if [[ -f CLAUDE.md ]] && grep -q "PhysicsIntern workspace" CLAUDE.md; then
  EXISTING_HOST="claude"
elif [[ -f AGENTS.md ]] && grep -q "PhysicsIntern workspace" AGENTS.md; then
  EXISTING_HOST="pi"
fi

if [[ -n "$EXISTING_HOST" ]]; then
  echo "$TARGET_ABS already contains a PhysicsIntern workspace (host: $EXISTING_HOST)."
  echo
  echo "Reset will REMOVE every file and directory here EXCEPT problem.md,"
  echo "then re-initialize from templates (host: $HOST). This discards:"
  echo "  - .git/ (all commit history, including uncommitted work)"
  echo "  - .claude/ or .pi/, .gitignore, CLAUDE.md or AGENTS.md, research_log.md"
  echo "  - plan.md, survey.md, answer.md (if present)"
  echo "  - derivations/, computations/, critiques/, notes/, references/, data/"
  echo "  - skills/, prompts/, package.json (if pi)"
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

# Render workspace files from src/ + hosts/<host>/ via the bootstrap renderer.
python3 "$SCRIPT_DIR/bootstrap/render.py" --host="$HOST" --target="$TARGET_ABS"

if [[ ! -f problem.md ]]; then
  cat > problem.md <<'EOF'
# Problem

### Problem setup

<describe the system, conventions, and any given equations or definitions>

### Main question

<state the question to be answered, including what counts as an answer>
EOF
fi

ARTEFACT_DIRS="derivations computations critiques notes references data"
for d in $ARTEFACT_DIRS; do
  mkdir -p "$d"
  touch "$d/.gitkeep"
done

# Per-dispatch brief files under .briefs/ within derivations/ and computations/.
mkdir -p derivations/.briefs computations/.briefs
touch derivations/.briefs/.gitkeep computations/.briefs/.gitkeep

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

if [[ $RESET -eq 1 ]]; then
  HEADER="PhysicsIntern workspace reset and re-initialized (host: $HOST) at:"
else
  HEADER="PhysicsIntern workspace initialized (host: $HOST) at:"
fi

case "$HOST" in
  claude)
    LAUNCH_HINT="Launch Claude Code in this directory."
    HEADER_FILES="CLAUDE.md and research_log.md"
    ;;
  pi)
    LAUNCH_HINT="Register the workspace as a local Pi package, then launch Pi:
       pi install -l .            # makes /survey, /derive, etc. visible
       pi                         # launch (Pi auto-installs pi-subagents + pi-web-access from .pi/settings.json)"
    HEADER_FILES="AGENTS.md and research_log.md"
    ;;
esac

cat <<EOF

$HEADER
  $TARGET_ABS

Next steps:
  1. Edit problem.md — fill in '### Problem setup' and '### Main question'.
  2. $LAUNCH_HINT
  3. Run /start-research to extract the problem one-liner, substitute the
     {{PROBLEM_ONELINER}} placeholders in $HEADER_FILES, and
     point the main agent at /survey.
     (Or run /autoresearch to drive the full pipeline autonomously — it will
     invoke /start-research itself if the placeholder is still present.)

EOF
