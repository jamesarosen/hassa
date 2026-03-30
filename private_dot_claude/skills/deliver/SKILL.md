---
name: deliver
description: This skill should be used when the user asks to "deliver this", "implement and PR", "build this feature", "fix this bug and open a PR", "/deliver", or wants autonomous end-to-end implementation from understanding through pull request.
version: 1.1.0
---

# Deliver

Single workflow: understand the goal, get there, deliver a PR. Works the same for bugs, features, and refactors.

## Autonomy

**Default: full autonomy to PR.** The user can interrupt at any time by typing in chat.

Do not pause between steps. Do not ask "Ready to proceed?" Keep going until the PR is created or a genuine blocker is hit.

**Valid reasons to stop:**

- Requirements are ambiguous and only the user can clarify
- Multiple approaches with significantly different tradeoffs the user should weigh
- Unrecoverable failure after 2 retry attempts
- A review finding marked as needing discussion that requires user-only information

**Not valid reasons to stop:**

- Task seems complex (start, iterate)
- Unsure which approach is "best" (pick one, document why)
- Git conflicts (resolve them)

## Flow

```
Understand → Plan → Branch → Implement → Review → Iterate → Quality Gate → Commit → Push → PR
```

Steps are not rigid phases. Use judgment — skip what's unnecessary, revisit what needs it.

---

### Understand

Absorb the desired end state from the user's chat message.

1. Restate the goal in one sentence before proceeding
2. If the task involves a bug, form 2-3 hypotheses about possible causes and gather evidence before implementing
3. Clarify acceptance criteria if implicit
4. Search for existing patterns: look for similar code in the codebase

### Plan

For straightforward tasks, skip this — go to Branch.

For complex tasks:

- Outline 2-3 approaches with tradeoffs
- Pick one, or ask the user if tradeoffs are significant
- Note the decision briefly

### Branch

```bash
git fetch origin
git checkout -b {type}/short-description origin/main
```

Types: `fix/`, `feat/`, `refactor/`, `chore/`

If the branch name already exists, append `-v2` (or `-v3`, etc.).

### Implement

Build it. Follow existing codebase patterns. Read CLAUDE.md and any project-specific instructions when available.

### Review

Invoke the `/review` skill to review the changes before committing. The `/review` skill will auto-select appropriate reviewers based on the change type.

After reviewers complete, respond to each finding:

| Response       | Meaning             | Action                                  |
| -------------- | ------------------- | --------------------------------------- |
| Will fix       | Agree               | Implement immediately                   |
| Will fix later | Valid, not blocking | Use `/defer` to create a GitHub Issue (pass `--next` for CRITICAL/HIGH findings, `--later` for MEDIUM/LOW) |
| Won't fix      | Disagree            | Explain why                             |
| Discuss        | Need user input     | **Stop and ask**                        |

### Iterate

After fixing review findings, re-review **unless all of these are true:**

- Fixes were purely cosmetic (typos, formatting)
- No CRITICAL or HIGH issues in round 1
- Already completed round 2

**Maximum 2 review rounds.** After round 2, commit and note "further review recommended" if issues remain.

### Quality Gate

Before committing, run the project's quality checks so issues are caught before push.

1. Look for `bin/quality-gate.sh` in the project root
2. If it exists, run it. Fix any failures it reports.
3. Re-run until it passes (max 2 attempts, then stop and explain the blocker)
4. If it doesn't exist, skip this step

### Commit

Stage specific files with `git add`, then follow the `/git-commit-message` skill to generate and create the commit. When gathering context for Step 1, use the review findings and conversation summary from this session. Since `/deliver` operates autonomously, auto-accept the generated message — skip the "Yes / Revise / Regenerate" prompt in `/git-commit-message` Step 3.

### Push and PR

Use `git log -1 --format='%s'` to retrieve the committed subject line for the PR title.

```bash
git push -u origin HEAD

gh pr create --title "$(git log -1 --format='%s')" --body "$(cat <<'EOF'
## Summary

[1-3 bullets]

## Test Plan

- [ ] [How to verify]

## Review Notes

Self-reviewed via deliver skill.
[Note any unresolved findings or follow-ups here]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Report

Tell the user: what was done, PR URL, and any follow-up items.

---

## Error Recovery

When things go wrong, recover and continue.

| Failure                           | Recovery                                                                         |
| --------------------------------- | -------------------------------------------------------------------------------- |
| **Git push rejected**             | `git fetch origin && git rebase origin/main` then push again                     |
| **Git branch already exists**     | `git checkout -b {name}-v2 origin/main`                                          |
| **Merge conflicts during rebase** | Resolve conflicts, `git rebase --continue`                                       |
| **Lint/typecheck failures**       | Fix the reported issues. Do not commit with errors.                              |
| **Test failures**                 | Read output, fix failures. If flaky, re-run once. If still failing, investigate. |
| **Quality gate fails**            | Fix reported issues, re-run gate. After 2 failures, stop and explain.            |

**General principle:** Retry once on transient failures. On persistent failures, try an alternative approach. After 2 failed attempts at the same operation, stop and explain the blocker to the user.
