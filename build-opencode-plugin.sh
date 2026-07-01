#!/usr/bin/env bash
#
# build-opencode-plugin.sh — assemble the publishable OpenCode plugin from this repo.
#
# Source of truth lives here: commons/ + hosts/opencode/ (methodology) and
# plugins/opencode/ (the authored files: README.md, install.sh, the global
# /init-physics-intern command, and plugin-init.sh).
#
# This script writes a COMPLETE, self-contained tree into the output dir, which
# is the working copy of the separate `physics-intern-opencode-plugin` repo you
# commit and push to publish. The output dir is a pure build artifact — never
# hand-edit it; edit the sources here and rebuild.
#
# Unlike Claude/Codex there is no marketplace: distribution is a global command
# file + a vendored scaffolder kit installed by install.sh (see plugins/opencode/README.md).
#
# Usage: build-opencode-plugin.sh [output-dir]
#   output-dir defaults to ../physics-intern-opencode-plugin

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$REPO/../physics-intern-opencode-plugin}"
SRC="$REPO/plugins/opencode"

if [[ ! -d "$SRC" ]]; then
  echo "Error: $SRC not found." >&2
  exit 1
fi

# rsync excludes build cruft (__pycache__, .DS_Store) so it never ships.
EXCLUDES=(--exclude='__pycache__' --exclude='.DS_Store')

# 1. Authored files: README.md, install.sh, and the kit (commands/ + scripts/).
mkdir -p "$OUT"
cp "$SRC/README.md" "$OUT/README.md"
cp "$SRC/install.sh" "$OUT/install.sh"
rm -rf "$OUT/physics-intern"
rsync -a "${EXCLUDES[@]}" "$SRC/physics-intern/" "$OUT/physics-intern/"

# 2. Vendor the methodology templates from the single source of truth, into the
#    kit so plugin-init.sh finds them at $KIT_ROOT/commons and $KIT_ROOT/hosts/opencode.
rsync -a "${EXCLUDES[@]}" "$REPO/commons/" "$OUT/physics-intern/commons/"   # includes render.py
mkdir -p "$OUT/physics-intern/hosts/opencode"
rsync -a "${EXCLUDES[@]}" "$REPO/hosts/opencode/" "$OUT/physics-intern/hosts/opencode/"

echo "Built OpenCode plugin → $OUT"
echo
echo "Publish steps:"
echo "  1. cd \"$OUT\" && git add -A && git commit -m \"...\" && git push"
echo "  2. Ensure the published repo is PUBLIC (git clone over HTTPS must work)."
