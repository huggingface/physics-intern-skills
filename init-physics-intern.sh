#!/usr/bin/env bash
#
# init-physics-intern.sh — bootstrap a PhysicsIntern research workspace.
#
# Usage:
#   init-physics-intern.sh [target-dir]
#
# If target-dir is omitted, the current directory is used. The target dir is
# created if missing. The script copies the bundled templates/ into it,
# scaffolds a problem.md skeleton, creates artefact dirs, and makes the first
# git commit. It does NOT extract a problem one-liner — the user fills in
# problem.md, then launches Claude Code and runs /start-research, which reads
# problem.md and substitutes the {{PROBLEM_ONELINER}} placeholders.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

if [[ ! -d "$TEMPLATES_DIR" ]]; then
  echo "Error: templates directory not found at $TEMPLATES_DIR" >&2
  exit 1
fi

TARGET_DIR="${1:-.}"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"
TARGET_ABS="$(pwd)"

RESET=0
if [[ -f CLAUDE.md ]] && grep -q "PhysicsIntern workspace" CLAUDE.md; then
  echo "$TARGET_ABS already contains a PhysicsIntern workspace."
  echo
  echo "Reset will REMOVE every file and directory here EXCEPT problem.md,"
  echo "then re-initialize from templates. This discards:"
  echo "  - .git/ (all commit history, including uncommitted work)"
  echo "  - .claude/, .gitignore, CLAUDE.md, research_log.md"
  echo "  - plan.md, survey.md, answer.md (if present)"
  echo "  - derivations/, computations/, critiques/, notes/, references/, data/"
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

cp "$TEMPLATES_DIR/CLAUDE.md"       ./CLAUDE.md
cp "$TEMPLATES_DIR/gitignore"       ./.gitignore
cp "$TEMPLATES_DIR/research_log.md" ./research_log.md

if [[ ! -f problem.md ]]; then
  cat > problem.md <<'EOF'
# Problem

### Problem setup

<describe the system, conventions, and any given equations or definitions>

### Main question

<state the question to be answered, including what counts as an answer>
EOF
fi

for d in derivations computations critiques notes references data; do
  mkdir -p "$d"
  touch "$d/.gitkeep"
done

if [[ ! -f notes/flags.md ]]; then
  cat > notes/flags.md <<'EOF'
# Flag dispositions

<!--
One line per sub-agent flag, written by the main agent during the integration loop:
  [skill][artefact-id] <flag summary> → accepted/dismissed/deferred (one-line reason)
See CLAUDE.md → Integration loop.
-->
EOF
fi

cp -R "$TEMPLATES_DIR/.claude" ./

if [[ ! -d .git ]]; then
  git init -q
fi
git add -A
if [[ $RESET -eq 1 ]]; then
  git commit -q -m "Re-initialize PhysicsIntern workspace (reset, problem.md preserved)" \
                -m "Bootstrapped from init-physics-intern.sh."
else
  git commit -q -m "Initialize PhysicsIntern workspace" \
                -m "Bootstrapped from init-physics-intern.sh."
fi

if [[ $RESET -eq 1 ]]; then
  HEADER="PhysicsIntern workspace reset and re-initialized at:"
else
  HEADER="PhysicsIntern workspace initialized at:"
fi

cat <<EOF

$HEADER
  $TARGET_ABS

Next steps:
  1. Edit problem.md — fill in '### Problem setup' and '### Main question'.
  2. Launch Claude Code in this directory.
  3. Run /start-research to extract the problem one-liner, substitute the
     {{PROBLEM_ONELINER}} placeholders in CLAUDE.md and research_log.md, and
     point the main agent at /survey.
     (Or run /autoresearch to drive the full pipeline autonomously — it will
     invoke /start-research itself if the placeholder is still present.)

EOF
