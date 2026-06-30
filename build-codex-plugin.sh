#!/usr/bin/env bash
#
# build-codex-plugin.sh — assemble the publishable Codex CLI plugin from this repo.
#
# Source of truth lives here: commons/ + hosts/codex/ (methodology) and
# plugins/codex/ (the plugin-specific authored files: marketplace.json under
# .agents/plugins/, plugin.json, the init-physics-intern skill, and
# plugin-init.sh).
#
# This script writes a COMPLETE, self-contained plugin tree into the output dir,
# which is the working copy of the separate `physics-intern-codex-plugin` repo
# you commit and push to publish. The output dir is a pure build artifact — never
# hand-edit it; edit the sources here and rebuild.
#
# Usage: build-codex-plugin.sh [output-dir]
#   output-dir defaults to ../physics-intern-codex-plugin

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$REPO/../physics-intern-codex-plugin}"
SRC="$REPO/plugins/codex"

if [[ ! -d "$SRC" ]]; then
  echo "Error: $SRC not found." >&2
  exit 1
fi

# rsync excludes build cruft (__pycache__, .DS_Store) so it never ships.
EXCLUDES=(--exclude='__pycache__' --exclude='.DS_Store')

# 1. Marketplace manifest (.agents/plugins/marketplace.json) + repo landing page
#    at the published repo root.
mkdir -p "$OUT/.agents/plugins"
cp "$SRC/.agents/plugins/marketplace.json" "$OUT/.agents/plugins/marketplace.json"
cp "$SRC/README.md" "$OUT/README.md"

# 2. Plugin static files (plugin.json, the init skill, plugin-init.sh).
rm -rf "$OUT/plugin"
mkdir -p "$OUT/plugin"
rsync -a "${EXCLUDES[@]}" "$SRC/plugin/" "$OUT/plugin/"

# 3. Vendor the methodology templates from the single source of truth.
rsync -a "${EXCLUDES[@]}" "$REPO/commons/" "$OUT/plugin/commons/"   # includes render.py
mkdir -p "$OUT/plugin/hosts/codex"
rsync -a "${EXCLUDES[@]}" "$REPO/hosts/codex/" "$OUT/plugin/hosts/codex/"

echo "Built Codex plugin → $OUT"
echo
echo "Publish steps:"
echo "  1. Bump \"version\" in plugins/codex/plugin/.codex-plugin/plugin.json (then rebuild)."
echo "  2. cd \"$OUT\" && git add -A && git commit -m \"...\" && git push"
