# /factory-resume — Resume a Paused Factory Run

Push and open a PR for a factory run that paused due to critical review findings.

**Arguments**: `$ARGUMENTS` — issue number (required).

**When to use**: After responding to the critical-findings comment on the GitHub issue, and optionally pushing any fixes to the feature branch yourself.

---

## Steps

1. If `$ARGUMENTS` is empty: print "Usage: /factory-resume <issue-number>" and stop.

2. Run `git status --short` and `git branch --show-current` to confirm you're on a `factory/issue-N` or `factory/issue-N-*` branch in the right project directory.

3. Read `FACTORY_REVIEW.md`. If missing: print "No FACTORY_REVIEW.md found — wrong directory or the factory run was already completed." and stop.

4. Display the CRITICAL findings that were raised.

5. Check for uncommitted changes:

   ```bash
   git status --short
   ```

   - **If there are uncommitted changes**: stage and commit them:
     ```bash
     git add -- ':!FACTORY_PLAN.md' ':!FACTORY_TASKS.md' ':!FACTORY_REVIEW.md' ':!FACTORY_BLOCKERS.md'
     git commit -m "fix: address review findings for issue #N"
     ```

6. Push and create the PR:

   ```bash
   git push -u origin HEAD
   gh pr create \
     --title "[issue title from FACTORY_PLAN.md Goal line]" \
     --body "$(cat FACTORY_REVIEW.md)

   Closes #N"
   ```

7. Cleanup:

   ```bash
   rm -f FACTORY_PLAN.md FACTORY_TASKS.md FACTORY_REVIEW.md
   ```

Report: "Factory run complete. PR: [URL]"
