---
name: ship
description: This skill should be used when the user asks to "ship this", "ship it", "/ship", or wants to push a branch, wait for CI to pass, and merge to main — without opening a real PR.
version: 1.1.0
---

# Ship

Lightweight merge workflow for personal projects: quality gate, commit any staged work, push, wait for CI to pass, merge to main, clean up.

No code review. No permanent PR. Just CI protection before merging.

## When to use

Use `/ship` when:
- Changes are already implemented on a feature branch
- You want CI to pass before merging (but don't need review)
- You don't want the overhead of a real PR

Use `/deliver` instead when changes haven't been implemented yet, or when you want a real PR with code review.

## Autonomy

Full autonomy. Keep going unless:
- Working tree has unstaged tracked changes (ask: stage and commit, stash, or abort?)
- CI fails (report run names and URLs; do not merge; leave branch for debugging)
- Merge fails (investigate; ask if non-trivial)
- `pseudo-pr` exits non-zero for any other reason (surface exact error and exit code; do not continue)

## Flow

```
Quality gate → Commit (if needed) → pseudo-pr --skip-quality-gate
```

### 1. Quality gate

If `bin/quality-gate.sh` exists, run it first:

```bash
bin/quality-gate.sh
```

Fix any failures before proceeding. Do not commit if the quality gate fails.

### 2. Check working tree

```bash
git status --short
```

| State | Action |
|---|---|
| Clean | Proceed |
| Only staged changes | Run `/git-commit-message` to commit them, then proceed |
| Unstaged tracked changes | **Stop and ask**: stage and commit, stash, or abort? |
| Untracked files only | Proceed; warn the user these files will not be included |

### 3. Run pseudo-pr

```bash
pseudo-pr --skip-quality-gate
```

(`--skip-quality-gate` avoids re-running the gate since step 1 already ran it.)

This handles: pushing, CI detection and watching, fast-forward merging to `$TARGET`, and branch cleanup.

**Flags and env vars:**
- `--target <branch>` or `PSEUDO_PR_TARGET` — merge target (default: `main`)
- `--allow-no-ci` — merge even if no CI runs appear (for repos with no CI configured)
- `--skip-quality-gate` — skip the quality gate in the script

If CI fails, `pseudo-pr` exits non-zero and leaves the branch on the remote for debugging. The branch is not deleted. Do not attempt to merge manually.

### 4. Report

Tell the user: which branch was shipped, which CI runs were watched (visible in `pseudo-pr` stdout), and that it's now on main.

If CI failed, surface the run names and URLs from the `pseudo-pr` output and confirm the branch remains at `origin/<branch>` for debugging.

## Error recovery

| Failure | Recovery |
|---|---|
| Quality gate fails | Fix the reported issues; re-run `/ship` |
| Push rejected | `git fetch origin && git rebase origin/main`, then re-run `/ship` |
| No CI runs appeared | Check that the repo has CI workflows; pass `--allow-no-ci` if no CI is configured |
| CI failed | Report run names and URLs from `pseudo-pr` output; leave branch for debugging |
| Fast-forward not possible | `git rebase origin/main` on the branch, then re-run `/ship` |
| `pseudo-pr` fails for other reason | Surface exact error message and exit code; do not continue |
