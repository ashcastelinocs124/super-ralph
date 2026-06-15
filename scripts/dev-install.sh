#!/bin/bash
# Super Ralph — Dev Install Script
# Symlinks the LIVE repo into local tool paths so edits take effect immediately.
# Use this to dogfood Super Ralph from this repo while developing it — no copy,
# no reinstall after each change.
#
# Usage:
#   bash scripts/dev-install.sh            # project-local Claude Code + Cursor
#   bash scripts/dev-install.sh --global   # also link into ~/.claude

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

echo "=== Super Ralph Dev Installer ==="
echo "Repo: $REPO"
echo ""

# link_skill / link_glob write force symlinks (idempotent — safe to re-run).
link_target() {
  # $1 = source path, $2 = destination path
  ln -sfn "$1" "$2"
  echo "  ✓ $2 → $1"
}

install_into() {
  # $1 = base dir for skills/agents/commands (Claude Code layout)
  local base="$1"
  mkdir -p "$base/skills" "$base/agents" "$base/commands"

  # Skill (orchestrator)
  link_target "$REPO/skills/super-ralph" "$base/skills/super-ralph"

  # Agents (includes lightweight variants via the glob)
  for f in "$REPO"/agents/ralph-*.md; do
    link_target "$f" "$base/agents/$(basename "$f")"
  done

  # Commands (/ralph, /super-ralph)
  for f in "$REPO"/commands/*.md; do
    link_target "$f" "$base/commands/$(basename "$f")"
  done
}

# 1) Project-local Claude Code
echo "[1/3] Linking project-local Claude Code (.claude)..."
install_into "$REPO/.claude"

# 2) Project-local Cursor
echo ""
echo "[2/3] Linking project-local Cursor (.cursor)..."
mkdir -p "$REPO/.cursor/skills"
link_target "$REPO/skills/super-ralph" "$REPO/.cursor/skills/super-ralph"

# 3) Optional global Claude Code
echo ""
if [ "$GLOBAL" -eq 1 ]; then
  echo "[3/3] Linking global Claude Code (~/.claude) — RALPH_DIR=$REPO..."
  install_into "$HOME/.claude"
else
  echo "[3/3] Skipping global install (pass --global to also link ~/.claude)."
fi

echo ""
echo "=== Dev install complete ==="
echo ""
echo "Edits in $REPO now take effect immediately — symlinks, no copy."
echo ""
echo "Invoke from this repo in Claude Code:"
echo "  /ralph <query>        — oneshot mode"
echo "  /super-ralph <query>  — choose oneshot vs brainstorm"
echo "In Cursor (or any skill-aware tool): \"use the super-ralph skill\"."
echo ""
echo "Verify:  ls -la $REPO/.claude/skills/super-ralph"
if [ "$GLOBAL" -eq 1 ]; then
  echo "Remove:  bash scripts/dev-uninstall.sh --global"
else
  echo "Remove:  bash scripts/dev-uninstall.sh"
fi
