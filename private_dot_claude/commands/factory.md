# /factory — Software Factory Pipeline

Run a complete implementation cycle from a GitHub issue to a pull request ready for your review.

**Arguments**: `$ARGUMENTS` — issue number, or leave empty to pick from a list.

---

## Phase 0 — Identify the Issue

**If `$ARGUMENTS` is empty or blank:**
Run `gh issue list --state open --limit 20 --json number,title` and display the results. Use `AskUserQuestion` to ask which issue to work on. Use the chosen number as N.

**If `$ARGUMENTS` is a number:**
Run `gh issue view $ARGUMENTS --json number,title,body,labels,state` and display the title, state, and body summary.

- If `state` is `"closed"`: run `gh pr list --search "closes #$ARGUMENTS" --state merged --limit 3` to show any merged PRs. Use `AskUserQuestion` to warn: "Issue #$ARGUMENTS is already closed. Continue anyway?" If no: stop.

Use `AskUserQuestion` to confirm: "Run /factory on issue #$ARGUMENTS: [title]? This creates a branch, implements the feature, runs code review, and opens a PR." If the answer is no: stop.

Set N = the issue number. Hold the full issue body text for the planner.

---

## Phase 1 — Create a Feature Branch

```bash
git fetch origin main
git checkout -b factory/issue-N origin/main
```

If that checkout fails because the branch already exists:
```bash
git checkout -b factory/issue-N-$(date +%s) origin/main
```

---

## Phase 2 — Plan

Read `CLAUDE.md` if it exists and note the contents.

Spawn the planner:

```
Agent(
  model: opus,
  subagent_type: factory-planner,
  prompt: |
    Issue #N: [title]

    [full issue body]

    Project CLAUDE.md: [contents, or "none"]
)
```

After the agent completes, Read `FACTORY_PLAN.md` and `FACTORY_TASKS.md`.
If either is missing or empty: display "Planner failed to produce required artifacts" and stop.

Check FACTORY_PLAN.md for any Stop Condition containing `ALREADY_IMPLEMENTED`. If found: display it and use `AskUserQuestion` to ask whether to continue or stop.

Show the plan and task list.

---

## Phase 3 — Implement

Spawn the implementer:

```
Agent(
  model: sonnet,
  subagent_type: factory-implementer,
  prompt: "Implement the tasks in FACTORY_TASKS.md following FACTORY_PLAN.md."
)
```

After the agent completes, check whether `FACTORY_BLOCKERS.md` exists:
- **If it exists**: Read and display its contents. Tell the user what the factory is blocked on. Stop — do not clean up artifact files.
- **If it does not exist**: continue.

---

## Phase 3.5 — Commit Implementation

Stage and commit the implementation, excluding factory artifact files:

```bash
git add -- ':!FACTORY_PLAN.md' ':!FACTORY_TASKS.md' ':!FACTORY_REVIEW.md' ':!FACTORY_BLOCKERS.md'
git status --short
```

Verify the staged files look correct. Then commit:

```bash
git commit -m "$(cat <<'EOF'
feat: [issue title]

Closes #N
EOF
)"
```

---

## Phase 4 — Review

In a single response, launch all three reviewer agents simultaneously (three Agent tool calls in one message):

```
Agent(model: sonnet, subagent_type: architect,     prompt: "Review changes on this branch vs main. Diff range: origin/main...HEAD")
Agent(model: sonnet, subagent_type: user-advocate, prompt: "Review changes on this branch vs main. Diff range: origin/main...HEAD")
Agent(model: sonnet, subagent_type: standards,     prompt: "Review changes on this branch vs main. Diff range: origin/main...HEAD")
```

Collect all three results.

---

## Phase 5 — Synthesize Reviews

Combine the three reviewer outputs into `FACTORY_REVIEW.md`:

```markdown
# Factory Review — Issue #N: [title]

## CRITICAL / HIGH

[findings from all three reviewers, with severity label and which reviewer raised it]

## MEDIUM / LOW

[findings from all three reviewers]

## Decision: PROCEED
```
(Or `Decision: NEEDS_ATTENTION` if there are CRITICAL findings.)

---

## Phase 5.5 — Write the Delivery Document

Write `FACTORY_DOC.md` using all artifacts (FACTORY_PLAN.md, FACTORY_TASKS.md, FACTORY_REVIEW.md). This document becomes both the commit message body and the PR description.

```markdown
## Summary

[1–3 sentences describing what this implements and why. Based on the FACTORY_PLAN.md goal and what was actually built.]

## Analysis

[The approach taken, key decisions made during implementation, any notable alternatives that were considered or rejected.]

## Future Work

[Each MEDIUM/LOW finding from FACTORY_REVIEW.md that was deferred. Format as a bulleted list. Omit this section entirely if all findings were addressed or there were none.]
```

---

## Phase 5.6 — Handle CRITICAL Findings (if any)

**If any CRITICAL finding exists:**

Post a comment on the GitHub issue:

```bash
gh issue comment N --body "$(cat <<'EOF'
## 🏭 Factory Review: Needs Your Input

Implementation is complete but the review found critical issues that need a decision before opening a PR.

[list each CRITICAL finding with: what was found, why it matters, what decision is needed]

After responding here, run `/factory-resume N` in your Claude Code session to continue.
EOF
)"
```

Then print: "Critical findings posted as a comment on issue #N. Run `/factory-resume N` after you've reviewed and responded."

Stop. Leave all artifact files in place.

**If no CRITICAL findings:**

Amend the commit to include the full delivery document:

```bash
git commit --amend -m "$(cat <<'EOF'
feat: [issue title]

[paste FACTORY_DOC.md contents here]

Closes #N
EOF
)"
```

---

## Phase 6 — Push and Create PR

```bash
git push -u origin HEAD
gh pr create \
  --title "[issue title]" \
  --body "$(cat FACTORY_DOC.md)

Closes #N"
```

Display the PR URL.

---

## Phase 7 — Cleanup

```bash
rm -f FACTORY_PLAN.md FACTORY_TASKS.md FACTORY_REVIEW.md FACTORY_DOC.md
```

(Leave `FACTORY_BLOCKERS.md` if it exists — it signals an incomplete run.)

Report: "Factory run complete. PR: [URL]"
