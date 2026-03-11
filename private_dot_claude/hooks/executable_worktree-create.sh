#!/bin/bash
# WorktreeCreate hook: creates a git worktree and copies env files + local settings.
# Replaces Claude Code's default git worktree behavior.
#
# Input (stdin JSON): { "name": "<slug>", "cwd": "<path>", ... }
# Output (stdout):    absolute path to the created worktree directory
# All diagnostic output goes to stderr.
#
# Worktree path convention: .claude/worktrees/<name> under the main worktree root.
# This path is also referenced in skills/worktree/SKILL.md — keep them in sync.

set -euo pipefail

# --- Dependency check ---

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: worktree-create hook requires jq. Install with: brew install jq" >&2
  exit 1
fi

# --- Parse and validate input ---

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
echo "WorktreeCreate hook: name=$NAME cwd=$CWD" >&2

if [ -z "$NAME" ]; then
  echo "Error: missing or empty 'name' in hook input" >&2
  exit 1
fi

if ! git check-ref-format --branch "$NAME" >/dev/null 2>&1; then
  echo "Error: invalid branch/worktree name: $NAME" >&2
  exit 1
fi

if [ -z "$CWD" ]; then
  CWD="$(pwd)"
fi

# --- Find the main worktree ---

MAIN_WORKTREE=$(git -C "$CWD" worktree list --porcelain | grep '^worktree ' | head -1 | sed 's/^worktree //')
if [ -z "$MAIN_WORKTREE" ]; then
  echo "Error: could not determine main worktree path (is this a git repo?)" >&2
  exit 1
fi

WORKTREE_DIR="$MAIN_WORKTREE/.claude/worktrees/$NAME"

# --- Create the git worktree ---

if [ -d "$WORKTREE_DIR" ]; then
  echo "Error: worktree directory already exists: $WORKTREE_DIR" >&2
  exit 1
fi

# Track whether we created a new branch so cleanup can remove it
CREATED_BRANCH=false

# Clean up on failure so we don't leave orphaned worktrees or branches
cleanup() {
  echo "Error during worktree setup; cleaning up" >&2
  if git -C "$CWD" worktree remove --force "$WORKTREE_DIR" 2>/dev/null; then
    echo "  Removed worktree $WORKTREE_DIR" >&2
  else
    echo "  Warning: could not remove worktree $WORKTREE_DIR" >&2
  fi
  if [ "$CREATED_BRANCH" = "true" ]; then
    if git -C "$CWD" branch -D "$NAME" 2>/dev/null; then
      echo "  Removed branch $NAME" >&2
    fi
  fi
}
trap cleanup ERR

if git -C "$CWD" rev-parse --verify "refs/heads/$NAME" >/dev/null 2>&1; then
  # Branch already exists — check it out into the new worktree
  git -C "$CWD" worktree add "$WORKTREE_DIR" "$NAME" >&2
else
  # Create a new branch from HEAD
  CREATED_BRANCH=true
  git -C "$CWD" worktree add "$WORKTREE_DIR" -b "$NAME" HEAD >&2
fi

# --- Copy env files and local settings ---

COPIED=0

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  Copied $(echo "$dst" | sed "s|^$WORKTREE_DIR/||")" >&2
    COPIED=$((COPIED + 1))
  fi
}

copy_env_from_dir() {
  local src_dir="$1"
  local dst_dir="$2"

  copy_if_exists "$src_dir/.env" "$dst_dir/.env"
  copy_if_exists "$src_dir/.env.local" "$dst_dir/.env.local"

  for f in "$src_dir"/.env.*.local; do
    [ -f "$f" ] || continue
    copy_if_exists "$f" "$dst_dir/$(basename "$f")"
  done
}

# Root env files
copy_env_from_dir "$MAIN_WORKTREE" "$WORKTREE_DIR"

# .claude/settings.local.json
copy_if_exists "$MAIN_WORKTREE/.claude/settings.local.json" "$WORKTREE_DIR/.claude/settings.local.json"

# pnpm workspace packages
MAX_WORKSPACE_PATTERNS=50
if [ -f "$MAIN_WORKTREE/pnpm-workspace.yaml" ]; then
  # Extract list items from the packages: section only.
  # Stop at the next top-level key (line starting with a non-space, non-comment, non-dash character).
  PACKAGE_LINES=$(grep -A 1000 '^packages:' "$MAIN_WORKTREE/pnpm-workspace.yaml" 2>/dev/null \
    | tail -n +2 \
    | awk '/^[^[:space:]#-]/ { exit } /^[[:space:]]*-/ { print }' \
    || true)

  PATTERN_COUNT=$(echo "$PACKAGE_LINES" | grep -c . || true)
  if [ "$PATTERN_COUNT" -gt "$MAX_WORKSPACE_PATTERNS" ]; then
    echo "Warning: found $PATTERN_COUNT workspace patterns; only processing first $MAX_WORKSPACE_PATTERNS" >&2
  fi

  while IFS= read -r line; do
    pattern=$(echo "$line" | sed "s/^[[:space:]]*-[[:space:]]*//; s/['\"]//g; s/[[:space:]]*$//")
    [ -z "$pattern" ] && continue
    [[ "$pattern" == !* ]] && continue

    # Expand the glob pattern relative to the main worktree.
    # Quote the prefix to handle spaces; leave $pattern unquoted for glob expansion.
    matched=0
    for pkg_dir in "$MAIN_WORKTREE"/$pattern; do
      [ -d "$pkg_dir" ] || continue
      matched=$((matched + 1))
      rel_pkg="${pkg_dir#$MAIN_WORKTREE/}"
      copy_env_from_dir "$pkg_dir" "$WORKTREE_DIR/$rel_pkg"
    done
    if [ "$matched" -eq 0 ]; then
      echo "  Warning: workspace pattern '$pattern' matched no directories" >&2
    fi
  done < <(echo "$PACKAGE_LINES" | head -"$MAX_WORKSPACE_PATTERNS")
fi

if [ "$COPIED" -gt 0 ]; then
  echo "Copied $COPIED file(s) to worktree" >&2
else
  echo "No env files found to copy" >&2
fi

# Disable the ERR trap now that setup is complete
trap - ERR

# --- Output the worktree path (Claude Code reads this from stdout) ---
echo "Emitting worktree path: $WORKTREE_DIR" >&2
echo "$WORKTREE_DIR"
