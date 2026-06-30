#!/usr/bin/env bash
#
# plugin-init.sh — non-interactive PhysicsIntern workspace bootstrap (Codex CLI).
#
# Invoked by the init-physics-intern skill (see
# ../skills/init-physics-intern/SKILL.md), which tells the model to run this one
# script via the shell tool. It renders the bundled host=codex templates into the
# target directory, scaffolds artefact dirs + problem.md, and makes the first git
# commit. It is fully non-interactive and REFUSES (no-op) if the target already
# contains a PhysicsIntern workspace.
#
# The script self-locates the plugin root from its own path, so it does not
# depend on ${PLUGIN_ROOT} being present in the shell environment.
#
# Usage: plugin-init.sh [target-dir]   (defaults to $PWD)
#
# stdout contract — exactly ONE line, which the skill keys off:
#   RESULT: initialized at <dir>          workspace created
#   RESULT: already-initialized at <dir>  left untouched
#   (on error: nonzero exit, diagnostics on stderr, no RESULT line)

set -euo pipefail

# The plugin root is the parent of this script's scripts/ dir. The bundled
# commons/ (incl. render.py) and hosts/codex/ live directly under it.
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-$PWD}"

mkdir -p "$TARGET"
cd "$TARGET"
TARGET_ABS="$(pwd)"

# Refuse if this folder already holds a PhysicsIntern workspace (any prior run).
if [[ -d .codex && -f AGENTS.md ]] && grep -q "PhysicsIntern workspace" AGENTS.md; then
  echo "RESULT: already-initialized at $TARGET_ABS"
  exit 0
fi

# Render the workspace files (commons/ + hosts/codex/ bundled in the plugin).
# Capture render's chatter (it logs a summary to stderr) so stdout stays clean;
# surface it only if the render fails.
if ! render_out="$(python3 "$PLUGIN_ROOT/commons/render.py" --host=codex --target="$TARGET_ABS" 2>&1)"; then
  echo "ERROR: workspace render failed:" >&2
  echo "$render_out" >&2
  exit 1
fi

# Scaffold a problem.md skeleton if the user has not written one yet.
if [[ ! -f problem.md ]]; then
  cat > problem.md <<'EOF'
# Problem

### Problem setup

<describe the system, conventions, and any given equations or definitions>

### Main question

<state the question to be answered, including what counts as an answer>
EOF
fi

# Artefact directories the sub-agents deposit into (.gitkeep keeps them tracked).
for d in derivations computations critiques notes references data; do
  mkdir -p "$d"
  touch "$d/.gitkeep"
done
mkdir -p derivations/.briefs computations/.briefs
touch derivations/.briefs/.gitkeep computations/.briefs/.gitkeep

# Seed notes/flags.md — the main agent's ledger of sub-agent flag dispositions.
if [[ ! -f notes/flags.md ]]; then
  cat > notes/flags.md <<'EOF'
# Flag dispositions

<!--
One line per sub-agent flag, written by the main agent during the integration loop:
  [skill][artefact-id] <flag summary> → accepted/dismissed/deferred (one-line reason)
See AGENTS.md → Integration loop.
-->
EOF
fi

# Initialise git (if needed) and make the bootstrap commit.
if [[ ! -d .git ]]; then
  git init -q
fi
git add -A
git commit -q -m "Initialize PhysicsIntern workspace (Codex CLI plugin)" \
              -m "Bootstrapped by the init-physics-intern skill."

echo "RESULT: initialized at $TARGET_ABS"
