#!/bin/bash
# Super Ralph — Dev Uninstall Script
# Removes the dev symlinks created by dev-install.sh. Does NOT delete the repo.
#
# Usage:
#   bash scripts/dev-uninstall.sh            # remove project-local links
#   bash scripts/dev-uninstall.sh --global   # also remove ~/.claude links

set -euo pipefail

# Resolve repo root from the script location (not cwd), following symlinks.
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"
REPO="$(cd -P "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

GLOBAL=0
for arg in "$@"; do
  case "$arg" in
    --global) GLOBAL=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

echo "=== Super Ralph Dev Uninstaller ==="
echo "Repo: $REPO (kept — only symlinks are removed)"
echo ""

# unlink_symlink removes a path only if it is a symlink (never a real file/dir).
unlink_symlink() {
  if [ -L "$1" ]; then
    rm -f "$1"
    echo "  ✓ removed $1"
  fi
}

remove_from() {
  # $1 = base dir for skills/agents/commands (Claude Code layout)
  local base="$1"
  unlink_symlink "$base/skills/super-ralph"
  for f in "$base"/agents/ralph-*.md; do
    unlink_symlink "$f"
  done
  unlink_symlink "$base/commands/ralph.md"
  unlink_symlink "$base/commands/super-ralph.md"
}

# Project-local Claude Code
echo "[1/3] Removing project-local Claude Code links (.claude)..."
remove_from "$REPO/.claude"

# Project-local Cursor
echo ""
echo "[2/3] Removing project-local Cursor links (.cursor)..."
unlink_symlink "$REPO/.cursor/skills/super-ralph"

# Optional global Claude Code
echo ""
if [ "$GLOBAL" -eq 1 ]; then
  echo "[3/3] Removing global Claude Code links (~/.claude)..."
  remove_from "$HOME/.claude"
else
  echo "[3/3] Skipping global (pass --global to also remove ~/.claude links)."
fi

echo ""
echo "=== Dev symlinks removed (repo untouched) ==="
