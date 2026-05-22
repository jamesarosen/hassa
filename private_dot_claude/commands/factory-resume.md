# /factory-resume — Resume a Paused Factory Run

Push and open a PR for a factory run that paused due to critical review findings.

**Arguments**: `$ARGUMENTS` — issue number (required).

**When to use**: After responding to the critical-findings comment on the GitHub issue, and optionally pushing any fixes to the feature branch yourself.

---

## Steps

1. If `$ARGUMENTS` is empty: print "Usage: /factory-resume <issue-number>" and stop.

2. Confirm you're in the right directory and on a `factory/issue-N` or `factory/issue-N-*` branch:
   ```bash
   git branch --show-current
   ```

3. Pull any remote changes to the feature branch (in case someone else pushed fixes):
   ```bash
   git fetch origin
   git pull --rebase origin $(git branch --show-current)
   ```

4. Check how far behind main this branch is:
   ```bash
   git rev-list HEAD..origin/main --count
   ```
   If the count is greater than 0: print "Note: origin/main has N commits not in this branch. You may want to rebase before merging, but this resume will proceed as-is."

5. Read `FACTORY_REVIEW.md`. If missing: print "No FACTORY_REVIEW.md found — wrong directory or the factory run was already completed." and stop.

6. Display the CRITICAL findings from FACTORY_REVIEW.md.

7. Check for uncommitted local changes:
   ```bash
   git status --short
   ```
   If there are uncommitted changes: stage and commit them:
   ```bash
   git add -- ':!FACTORY_PLAN.md' ':!FACTORY_TASKS.md' ':!FACTORY_REVIEW.md' ':!FACTORY_BLOCKERS.md' ':!FACTORY_DOC.md'
   git commit -m "fix: address review findings for issue #N"
   ```

8. Read `FACTORY_DOC.md` if it exists. If missing, read `FACTORY_PLAN.md` and `FACTORY_REVIEW.md` and synthesize a delivery document with the same structure:

   ```markdown
   ## Summary
   [what was implemented and why]

   ## Analysis
   [approach and key decisions]

   ## Future Work
   [deferred MEDIUM/LOW findings, if any]
   ```

   Write this to `FACTORY_DOC.md`.

9. Push and create the PR:
   ```bash
   git push -u origin HEAD
   gh pr create \
     --title "[issue title from FACTORY_PLAN.md Goal line]" \
     --body "$(cat FACTORY_DOC.md)

   Closes #N"
   ```

10. Cleanup:
    ```bash
    rm -f FACTORY_PLAN.md FACTORY_TASKS.md FACTORY_REVIEW.md FACTORY_DOC.md
    ```

Report: "Factory run complete. PR: [URL]"
