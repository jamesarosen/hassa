# /factory — Software Factory Pipeline

Run a complete implementation cycle from a GitHub issue to a pull request ready for your review.

**Arguments**: `$ARGUMENTS` — issue number, or leave empty to pick from a list.

---

## Phase 0 — Identify the Issue

**If `$ARGUMENTS` is empty or blank:**
Run `gh issue list --state open --limit 20 --json number,title` and display the results. Use `AskUserQuestion` to ask which issue to work on. Use the chosen number as N.

**If `$ARGUMENTS` is a number:**
Run `gh issue view $ARGUMENTS --json number,title,body,labels` and display the title and body summary. Use `AskUserQuestion` to confirm: "Run /factory on issue #$ARGUMENTS: [title]? This creates a branch, implements the feature, runs code review, and opens a PR for your review." If the answer is no: stop.

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
  model: haiku,
  subagent_type: factory-planner,
  prompt: |
    Issue #N: [title]

    [full issue body]

    Project CLAUDE.md: [contents, or "none"]
)
```

After the agent completes, Read `FACTORY_PLAN.md` and `FACTORY_TASKS.md`.
If either is missing or empty: display "Planner failed to produce required artifacts" and stop.
Show the plan and task list to the user.

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
- **If it exists**: Read and display its contents. Tell the user what the factory needs. Stop — do not clean up artifact files.
- **If it does not exist**: continue to Phase 4.

---

## Phase 4 — Review

In a single response, launch all three reviewer agents simultaneously (three Agent tool calls in one message):

```
Agent(model: sonnet, subagent_type: architect,     prompt: "Review changes on this branch. Diff range: origin/main...HEAD")
Agent(model: sonnet, subagent_type: user-advocate, prompt: "Review changes on this branch. Diff range: origin/main...HEAD")
Agent(model: sonnet, subagent_type: standards,     prompt: "Review changes on this branch. Diff range: origin/main...HEAD")
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
(Or `Decision: NEEDS_ATTENTION: [reason]` if there are CRITICAL findings.)

**If any CRITICAL finding exists**: display `FACTORY_REVIEW.md` and use `AskUserQuestion` to ask the user whether to proceed or stop. If they say stop: leave all artifact files in place and stop.

---

## Phase 6 — Commit, Push, Create PR

Stage implementation work, explicitly excluding factory artifact files:

```bash
git add -- ':!FACTORY_PLAN.md' ':!FACTORY_TASKS.md' ':!FACTORY_REVIEW.md' ':!FACTORY_BLOCKERS.md'
git status --short
```

Verify the staged files look right (no artifact files, no unrelated changes). Then commit:

```bash
git commit -m "$(cat <<'EOF'
feat: [issue title]

Closes #N
EOF
)"
```

Push and open a PR:

```bash
git push -u origin HEAD
gh pr create \
  --title "[issue title]" \
  --body "$(cat <<'EOF'
[paste FACTORY_REVIEW.md contents here]

Closes #N
EOF
)"
```

Display the PR URL to the user.

---

## Phase 7 — Cleanup

```bash
rm -f FACTORY_PLAN.md FACTORY_TASKS.md FACTORY_REVIEW.md
```

(Leave `FACTORY_BLOCKERS.md` if it exists — it signals an incomplete run.)

Report: "Factory run complete. PR: [URL]"
