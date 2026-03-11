---
name: worktree
description: Use when the user says "/worktree", "create a worktree for X", or "set up a worktree named X". Manages git worktrees with automatic env file copying.
version: 1.0.0
---

# Worktree

Manage git worktrees without memorizing syntax. Env files and local settings are copied automatically.

## Commands

### Create

**Trigger:** `/worktree <name>` or `/worktree create <name>`

Use the built-in `EnterWorktree` tool:

```
EnterWorktree(name: "<name>")
```

The `WorktreeCreate` hook in `~/.claude/settings.json` runs automatically and:

1. Creates a git worktree at `.claude/worktrees/<name>` with a new branch
2. Copies `.env`, `.env.local`, `.env.*.local` from the main worktree root
3. Copies `.claude/settings.local.json`
4. Detects `pnpm-workspace.yaml` and copies env files from workspace package directories

After creation, the session switches to the new worktree directory.

Report what was created and which files were copied.

### List

**Trigger:** `/worktree list`

```bash
git worktree list
```

Worktrees created via this skill appear under `.claude/worktrees/` in the output.

### Remove

**Trigger:** `/worktree remove <name>`

First find the main worktree root, then remove by absolute path:

```bash
MAIN=$(git worktree list --porcelain | grep '^worktree ' | head -1 | sed 's/^worktree //')
git worktree remove "$MAIN/.claude/worktrees/<name>"
```

If the branch was created by the worktree, offer to delete it:

```bash
git branch -d <name>
```

Use `-d` (safe delete, only if merged). If the user explicitly wants to force-delete an unmerged branch, use `-D` after confirming.

## What Gets Copied

| Source pattern | Where copied from |
| --- | --- |
| `.env` | Root and each pnpm workspace package |
| `.env.local` | Root and each pnpm workspace package |
| `.env.*.local` | Root and each pnpm workspace package |
| `.claude/settings.local.json` | Root only |

Workspace packages are discovered by reading glob patterns from `pnpm-workspace.yaml`. Negation patterns (starting with `!`) are skipped.

Files like `.env.development` or `.env.test` (without `.local`) are not copied. Only `.local` variants and the base `.env` are included.

## Error Handling

| Failure | Recovery |
| --- | --- |
| `EnterWorktree` fails | Report the error. Suggest running `git worktree list` to check state. |
| Hook exits non-zero | Include stderr output in report. Do not proceed as if the worktree is ready. The hook cleans up orphaned worktrees on failure. |
| Name is invalid for git | Report that the name must be a valid git branch name. |

## Notes

- The hook only fires when a worktree is created via `claude --worktree`, `EnterWorktree`, or `isolation: "worktree"` subagents. Direct `git worktree add` commands bypass the hook.
- If a branch with the given name already exists, it is checked out (not recreated).
- The worktree is stored under `.claude/worktrees/` in the main worktree root.
- On session exit, Claude Code may prompt to keep or remove the worktree.
