---
name: branch-cleanup
description: This skill should be used when the user says "/branch-cleanup", "clean up branches", "prune branches", or wants to identify and delete local (and optionally remote) branches that no longer have value.
version: 1.1.0
---

# Branch Cleanup

Identify and delete branches that no longer have value. Logic lives in
`~/bin/git-branch-cleanup` (source: `bin/executable_git-branch-cleanup` in the
chezmoi repo); this skill handles interactive triage and deletion.

## Invocation

- `/branch-cleanup` — analyze and clean local branches
- `/branch-cleanup -R` — also include remote-only branches (on origin but not local)
- `/branch-cleanup --dry-run` / `/branch-cleanup -n` — analyze and show buckets but
  do not delete anything

## Flags

| Flag | Forwarded to script? | Notes |
|---|---|---|
| `-R` | Yes | Adds remote-only branches to analysis |
| `--dry-run` / `-n` | No | Consumed by this skill; suppresses all deletions |

## Intentional v1 limitations

- Only `main` is a protected branch. Long-running branches on other names
  (e.g. `develop`, `staging`) are not yet auto-protected.
- Remote deletions target the `origin` remote only.

## Flow

```
Fetch → Analyze → Show buckets → Confirm → Execute
```

Show all three buckets **before** any deletion. The user must confirm before
anything is deleted.

---

### Step 1: Fetch

```bash
git fetch --prune
```

This ensures remote branch data is current before analysis. Stale fetch data
can misclassify remote-only branches.

---

### Step 2: Run the analysis script

```bash
git branch-cleanup [-R]
```

(The script is installed as `~/bin/git-branch-cleanup` and aliased as
`git branch-cleanup` / `git bc` via gitconfig. Do NOT pass `--dry-run` or `-n`
to the script — those flags are handled by this skill only.)

Capture the JSON output. If the script exits non-zero, surface the error and stop.

---

### Step 3: Triage candidates

For each branch in `candidates`, use the following signals to classify it as
**Suggest-Delete** or **Suggest-Keep**:

| Signal | Suggests Delete | Suggests Keep |
|---|---|---|
| `age_days` | > 60 days | < 14 days |
| `lines_changed` | Small (< 30) | Large |
| `has_empty_commits` | — | Yes (intentional annotation) |
| `memos` | — | Non-empty (explicit note left by author) |
| `recent_commit` subject | Exploratory / stale label | Active / in-progress label |
| Branch name prefix | `wip/`, `spike/`, `tmp/`, `test/` | `feat/`, `fix/`, `refactor/` |
| `is_current` | — | Yes — never auto-delete the current branch |

Use judgment — these are heuristics, not hard rules. A branch with a memo is
almost always Suggest-Keep regardless of age. Never put an `is_current == true`
branch in auto_delete or Suggest-Delete.

Note: `candidates` from the script are the pool from which Suggest-Delete and
Suggest-Keep are drawn. No branch is in both.

---

### Step 4: Present the three buckets

Show results in this order **before taking any action**:

```
── Would Auto-Delete ─────────────────────────────────────────────────────────
  allow-colon          (local,  18d)
  deliver-git-message  (both,   18d)  ← local + origin/deliver-git-message

  All commits from these branches are already in main.

  Recovery commands (copy these before confirming):
    git branch allow-colon d3ae79e
    git branch deliver-git-message a1b2c3d

── Suggest-Delete ────────────────────────────────────────────────────────────
  feat/old-spike  (local, 72d, 3 commits, 45 lines)
    Last commit: "add experimental rate limiter"

── Suggest-Keep ──────────────────────────────────────────────────────────────
  feat/worktree-skill  (local, 17d, 1 commit, 266 lines)
    Last commit: "feat(worktree): add worktree skill"
```

In `--dry-run` mode, label sections "Would Auto-Delete", "Would Suggest-Delete",
"Would Suggest-Keep" and stop here — do not prompt or delete anything.

---

### Step 5: Confirm and execute auto-deletes

After presenting the buckets, prompt:

```
Auto-delete these N branches? [y/N]
```

If the user says yes, delete each branch in `auto_delete` (skipping any with
`is_current == true` — warn if skipped):

Before each deletion, verify the SHA still matches (guards against the branch
receiving new commits since analysis):

```bash
# Verify SHA hasn't changed since analysis
current_sha=$(git rev-parse <name> 2>/dev/null || git rev-parse origin/<name> 2>/dev/null)
# If current_sha != recorded sha: skip and warn

# scope == "local"
git branch -D <name>

# scope == "both"
git branch -D <name>
git push origin --delete <name>

# scope == "remote"
git push origin --delete <name>
```

---

### Step 6: Confirm and execute Suggest-Delete

Prompt:

```
Which Suggest-Delete branches to delete? (names, 'all', or Enter to skip)
>
```

For each named branch (or all, if 'all'), verify SHA and delete using the same
scope logic as Step 5.

---

### Step 7: Review Suggest-Keep

Prompt:

```
Any Suggest-Keep branches to delete? (names or Enter to skip)
>
```

For each named branch, verify SHA and delete using the same scope logic.

---

### Step 8: Report

Summarize:

```
Deleted 2 branches (auto), 1 branch (confirmed).
Kept 3 branches.
```

---

## Error Handling

| Failure | Recovery |
|---|---|
| `git-branch-cleanup` not found | Remind user to run `chezmoi apply` |
| `jq` not found | Script will error with install hint; surface it |
| `git fetch` fails | Warn and continue — analysis will use cached remote data |
| SHA mismatch before deletion | Skip branch, warn: "Skipping <name>: branch changed since analysis" |
| `git branch -D` fails | Surface error; continue with remaining branches |
| `git push origin --delete` fails | Surface error; continue with remaining branches |
| Script exits non-zero | Show exact error output; stop |
| `is_current == true` in auto_delete | Skip silently; note it at the end: "<name> skipped (currently checked out)" |
