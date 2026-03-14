---
name: branch-memo
description: This skill should be used when the user says "/branch-memo", "add a branch memo", "leave a note on this branch", or wants to annotate the current branch with a human-readable memo commit.
version: 1.0.0
---

# Branch Memo

Attach a human-readable note to the current branch as an empty commit.
Memos survive rebases and appear in `git log`, giving branches a
self-describing audit trail useful for cleanup and review.

## Invocation

- `/branch-memo` — show existing memos, then prompt for a message
- `/branch-memo <message>` — record the memo immediately

## Behavior

### Step 1: Show existing memos

Run:

```bash
git log --oneline --grep="^memo:" "$(git merge-base HEAD origin/main)"..HEAD
```

Display any memos found. If none, note that this is the first memo on the
branch.

### Step 2: Get the message

- If the user provided a message in the invocation arguments, use it directly.
- If not, ask the user for a message before proceeding.

The message must not be empty.

### Step 3: Create the memo

Run the `git-branch-memo` script (available as `git branch-memo` or `git bm`):

```bash
git branch-memo "<message>"
```

The script prepends `memo:` automatically — do not add it yourself.

If the script exits non-zero (staged changes, detached HEAD, empty message),
surface the error output and stop.

### Step 4: Confirm

Show the user the resulting `git log --oneline -1` output so they can see
the recorded memo.

## Example

```
User: /branch-memo waiting for design sign-off before merging

Existing memos on feat/checkout-redesign:
  a1b2c3d memo: initial spike — needs UX review

Memo recorded on feat/checkout-redesign:
  d4e5f6a memo: waiting for design sign-off before merging
```

## Error Handling

| Failure | Recovery |
| --- | --- |
| Staged changes exist | Inform the user; do not create the memo |
| Detached HEAD | Inform the user; do not create the memo |
| Empty message | Ask the user for a non-empty message |
| `git-branch-memo` not found | Remind the user to apply chezmoi (`chezmoi apply`) so `~/bin/git-branch-memo` is present |
