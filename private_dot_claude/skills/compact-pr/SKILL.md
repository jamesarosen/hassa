---
name: compact-pr
description: This skill should be used when the user asks to "compact PR", "update PR description", "regenerate PR body", "squash and update PR", "/compact-pr", or wants the PR title and description refreshed to reflect the current state of the branch after multiple rounds of review.
version: 1.0.0
---

# Compact PR

Regenerate a PR's title and description to reflect the full body of work — not just the first draft. Optionally squash commits.

## Invocation

- `/compact-pr` — update the current branch's PR
- `/compact-pr 123` — update PR #123
- `/compact-pr --squash` — squash commits into one, then update the PR

`$ARGUMENTS` is an optional PR number. `--squash` squashes all branch commits before updating.

## Behavior

### Step 1: Identify the PR

If a PR number is given in `$ARGUMENTS`, use it. Otherwise detect from the current branch:

```bash
gh pr view --json number,title,body,baseRefName,state
```

- If no open PR is found, inform the user and stop.
- If the PR is closed or merged, warn the user and stop.

### Step 2: Gather Context

Run these in parallel:

1. **PR metadata** — `gh pr view [number] --json title,body,baseRefName,headRefName,state,reviews,comments`
2. **Full diff** — `gh pr diff [number]`
3. **Commit log** — `git log [base]...HEAD --format='%h %s%n%b'`
4. **Review comments** — `gh pr view [number] --comments`

Use the base branch from PR metadata (e.g., `main`) as `[base]` for the commit log.

### Step 3: Generate New Description

Synthesize a new PR body covering:

- **Summary**: 1-5 bullets describing what the PR achieves in its current state (not just the first commit). Reference the problem/motivation and the solution.
- **Test Plan**: How to verify the changes. Update from original if scope changed.
- **Review Notes**: Key decisions made, findings addressed, any remaining follow-ups.
- Footer: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

Also generate a suggested new title in conventional commit format: `type(scope): description`.

### Step 4: Show Draft for Approval

Print the proposed title and body. Then ask the user two questions:

1. **Update title?** Show `old title → new title`. Default: keep old.
2. **Apply this description?** Yes/no.

If the user declines both, stop — no changes made.

### Step 5: Apply

If the user approved the description:

```bash
gh pr edit [number] --body "$(cat <<'EOF'
[new body]
EOF
)"
```

If the user approved the title:

```bash
gh pr edit [number] --title "[new title]"
```

### Step 6 (if `--squash`): Squash Commits

This runs **after** generating the description (Step 3 needs the full commit history) but **before** applying to GitHub (Step 5).

**Order when `--squash` is used:** Gather (Step 2) → Generate (Step 3) → Draft (Step 4) → Squash (this step) → Apply (Step 5).

1. Determine base: use `baseRefName` from PR metadata
2. Count commits: `git rev-list --count [base]...HEAD`
3. If only 1 commit, skip the squash
4. Squash:

   ```bash
   git reset --soft $(git merge-base [base] HEAD)
   git commit -m "$(cat <<'EOF'
   [PR title]

   [PR body]

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   EOF
   )"
   ```

5. Force push with lease: `git push --force-with-lease`

## Error Handling

| Failure                | Recovery                                       |
| ---------------------- | ---------------------------------------------- |
| No PR found            | Inform user, stop                              |
| PR is closed/merged    | Warn user, stop                                |
| `gh` not authenticated | Inform user to run `gh auth login`             |
| Force push rejected    | Suggest `git pull` first, or manual resolution |
| User declines draft    | Stop, no changes made                          |
