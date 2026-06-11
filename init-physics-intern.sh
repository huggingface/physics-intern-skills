#!/usr/bin/env bash
#
# init-physics-intern.sh — bootstrap a PhysicsIntern research workspace.
#
# Usage:
#   init-physics-intern.sh [--host=claude|pi|codex|hermes] [target-dir]
#   init-physics-intern.sh host=hermes
#
# If target-dir is omitted, the current directory is used, except for
# `host=hermes`: that form installs the PhysicsIntern skills into the active
# Hermes home (~/.hermes/skills, or $HERMES_HOME/skills) without creating a
# workspace. When a workspace target is used, the target dir is created if
# missing. The script renders workspace files from commons/ (shared methodology)
# plus hosts/<host>/ (host-specific config and extras) via commons/render.py,
# scaffolds a problem.md skeleton, creates artefact dirs, and makes the first
# git commit. It does NOT extract a problem one-liner —
# the user fills in problem.md, then launches their coding agent and runs
# /start-research, which reads problem.md and substitutes the
# {{PROBLEM_ONELINER}} placeholders.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse CLI args: --host selects the agent host (claude, pi, codex, or hermes), positional arg
# is the target directory (defaults to current dir).
HOST="claude"
TARGET_DIR="."
TARGET_SPECIFIED=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host=*) HOST="${1#--host=}" ;;
    host=*)   HOST="${1#host=}" ;;
    --host)
      if [[ $# -lt 2 ]]; then
        echo "Error: --host requires a value (claude, pi, codex, or hermes)" >&2
        exit 1
      fi
      HOST="$2"; shift ;;
    -h|--help)
      sed -n '2,15p' "${BASH_SOURCE[0]}"
      exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1 ;;
    *)        TARGET_DIR="$1"; TARGET_SPECIFIED=1 ;;
  esac
  shift
done

# Validate host selection — claude, pi, codex, and hermes are supported.
case "$HOST" in
  claude|pi|codex|hermes) ;;
  *)
    echo "Error: --host must be 'claude', 'pi', 'codex', or 'hermes' (got '$HOST')" >&2
    exit 1 ;;
esac

# Sanity-check that the template sources this script needs are present.
if [[ ! -d "$SCRIPT_DIR/commons" || ! -d "$SCRIPT_DIR/hosts/$HOST" ]]; then
  echo "Error: commons/ or hosts/$HOST/ not found in $SCRIPT_DIR" >&2
  exit 1
fi

install_hermes_skills() {
  local rendered_root="$1"
  local hermes_home_dir="${HERMES_HOME:-$HOME/.hermes}"
  local install_dir="$hermes_home_dir/skills"

  if [[ ! -d "$rendered_root/.hermes/skills" ]]; then
    echo "Error: rendered Hermes skills not found at $rendered_root/.hermes/skills" >&2
    exit 1
  fi

  mkdir -p "$install_dir"

  local count=0
  local skill_dir skill_name
  for skill_dir in "$rendered_root/.hermes/skills"/*; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    rm -rf "$install_dir/$skill_name"
    cp -R "$skill_dir" "$install_dir/$skill_name"
    count=$((count + 1))
  done

  HERMES_SKILLS_INSTALL_DIR="$install_dir"
  HERMES_SKILLS_INSTALL_COUNT="$count"
}

# `./init-physics-intern.sh host=hermes` is an installation command for Hermes:
# install/copy the PhysicsIntern slash-command skills into Hermes' active skills
# directory without creating a research workspace in the current directory.
if [[ "$HOST" == "hermes" && "$TARGET_SPECIFIED" -eq 0 ]]; then
  HERMES_RENDER_TMP="$(mktemp -d "${TMPDIR:-/tmp}/physics-intern-hermes-install.XXXXXX")"
  trap 'rm -rf "$HERMES_RENDER_TMP"' EXIT

  HERMES_RENDER_LOG="$HERMES_RENDER_TMP/render.log"
  if ! python3 "$SCRIPT_DIR/commons/render.py" --host=hermes --target="$HERMES_RENDER_TMP" >"$HERMES_RENDER_LOG" 2>&1; then
    cat "$HERMES_RENDER_LOG" >&2
    exit 1
  fi
  HERMES_SKILLS_INSTALL_DIR=""
  HERMES_SKILLS_INSTALL_COUNT=0
  install_hermes_skills "$HERMES_RENDER_TMP"

  cat <<EOF
PhysicsIntern Hermes skills installed.

Installed $HERMES_SKILLS_INSTALL_COUNT skills to:
  $HERMES_SKILLS_INSTALL_DIR

Next steps:
  1. Restart any already-running Hermes session so it reloads installed skills.
  2. Launch Hermes in the project/research directory where you want to work:
       hermes
  3. Run /start-research, /survey, /derive, etc. as needed.

EOF
  exit 0
fi

# Create the target dir if needed and cd into it; record its absolute path.
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"
TARGET_ABS="$(pwd)"

# Guard against accidentally bootstrapping over the methodology source checkout.
# Running this script from the repo root without a target is an easy mistake; a
# reset there would remove the source repo itself.
if [[ "$TARGET_SPECIFIED" -eq 0 && "$TARGET_ABS" == "$SCRIPT_DIR" ]]; then
  echo "Error: refusing to initialize in the PhysicsIntern source checkout:" >&2
  echo "  $SCRIPT_DIR" >&2
  echo >&2
  echo "Pass a target workspace directory instead, for example:" >&2
  echo "  $0 --host=$HOST ../my-workspace" >&2
  exit 1
fi

# Detect an existing PhysicsIntern workspace (any host) and offer reset. Pi,
# Codex, and Hermes use AGENTS.md as the workspace doc, so we disambiguate by
# probing the host-specific directory (.pi/, .codex/, or .hermes/) in addition to the
# "PhysicsIntern workspace" marker in the workspace doc.
RESET=0
EXISTING_HOST=""
if [[ -d .claude ]] && [[ -f CLAUDE.md ]] && grep -q "PhysicsIntern workspace" CLAUDE.md; then
  EXISTING_HOST="claude"
elif [[ -d .codex ]] && [[ -f AGENTS.md ]] && grep -q "PhysicsIntern workspace" AGENTS.md; then
  EXISTING_HOST="codex"
elif [[ -d .hermes ]] && [[ -f AGENTS.md ]] && grep -q "PhysicsIntern workspace" AGENTS.md; then
  EXISTING_HOST="hermes"
elif [[ -d .pi ]] && [[ -f AGENTS.md ]] && grep -q "PhysicsIntern workspace" AGENTS.md; then
  EXISTING_HOST="pi"
fi

# If a prior workspace is detected, prompt the user before wiping it.
# problem.md is preserved so the user doesn't lose the question they wrote.
if [[ -n "$EXISTING_HOST" ]]; then
  echo "$TARGET_ABS already contains a PhysicsIntern workspace (host: $EXISTING_HOST)."
  echo
  echo "Reset will REMOVE every file and directory here EXCEPT problem.md,"
  echo "then re-initialize from templates (host: $HOST). This discards:"
  echo "  - .git/ (all commit history, including uncommitted work)"
  echo "  - .claude/, .pi/, .codex/, or .hermes/, .gitignore, CLAUDE.md or AGENTS.md, research_log.md"
  echo "  - plan.md, survey.md, answer.md (if present)"
  echo "  - derivations/, computations/, critiques/, notes/, references/, data/"
  echo "  - skills/, prompts/, package.json (if pi); .agents/skills/ (if codex); .hermes/skills/ (if hermes)"
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

# Hermes discovers installed skills under the active Hermes home. Keep the
# rendered workspace copy for provenance, but install/copy the PhysicsIntern
# slash-command skills into ~/.hermes/skills/ (or $HERMES_HOME/skills when set)
# so /survey, /derive, etc. are visible through Hermes' normal skill discovery.
HERMES_SKILLS_INSTALL_DIR=""
if [[ "$HOST" == "hermes" ]]; then
  HERMES_SKILLS_INSTALL_COUNT=0
  install_hermes_skills "$TARGET_ABS"
fi

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
    HEADER_FILES="CLAUDE.md and research_log.md"
    ;;
  pi)
    LAUNCH_HINT="Register the workspace as a local Pi package, then launch Pi:
       pi install -l .            # makes /survey, /derive, etc. visible
       pi                         # launch (Pi auto-installs pi-subagents + pi-web-access from .pi/settings.json)"
    HEADER_FILES="AGENTS.md and research_log.md"
    ;;
  codex)
    LAUNCH_HINT="Launch Codex in this directory:
       codex                       # first run will prompt to trust the project — accept it,
                                   # otherwise .codex/config.toml (incl. agent_roles) is ignored
       Sub-agent dispatch uses spawn_agent + wait_agent (multi_agents_v2)."
    HEADER_FILES="AGENTS.md and research_log.md"
    ;;
  hermes)
    LAUNCH_HINT="Launch Hermes in this directory:
       hermes                       # PhysicsIntern skills were copied to $HERMES_SKILLS_INSTALL_DIR
       Sub-agent dispatch uses delegate_task. Restart any already-running Hermes session
       so it reloads the installed skills."
    HEADER_FILES="AGENTS.md and research_log.md"
    ;;
esac

# Print final summary and next-steps guidance.
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
