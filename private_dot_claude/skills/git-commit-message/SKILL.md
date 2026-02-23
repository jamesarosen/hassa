---
name: git-commit-message
description: This skill should be used when the user asks to "write a commit message", "draft the commit message", "compose the commit", "/git-commit-message", or wants a rich commit message generated for staged changes.
version: 1.1.0
---

# Git Commit Message

Generate a structured commit message for staged changes. This skill delegates to a sub-agent so the diff output and composition work don't consume the parent context window.

## Invocation

- `/git-commit-message` — generate a commit message for the currently staged changes

## Behavior

### Step 1: Prepare Context for Sub-Agent

Before launching the sub-agent, gather context from the current conversation that the sub-agent will need:

1. **Review findings** — scan the conversation for `/review` output since the last commit. Extract the list of findings with their severities and dispositions (addressed, rebutted, deferred). If there are no review findings, note "none."
2. **Conversation summary** — note: what the user asked for, key decisions or discoveries, the number of user messages since the last commit, and the number of times the user was explicitly asked to approve or reject a tool call (do not count auto-approved calls or policy blocks).

These will be passed to the sub-agent as `REVIEW_CONTEXT` and `CONVERSATION_CONTEXT` in the prompt below.

### Step 2: Launch Sub-Agent

Use the **Task tool** with `subagent_type: "general-purpose"` to launch a single sub-agent.

Pass the following prompt verbatim to the sub-agent, replacing `REVIEW_CONTEXT` and `CONVERSATION_CONTEXT` with the text gathered in Step 1:

---

**Sub-agent prompt:**

You are writing a git commit message for the currently staged changes. Do NOT create the commit — only output the message text.

#### Step A: Gather Data

Run these in parallel:

1. `git diff --cached --stat` — summary of changed files
2. `git diff --cached` — the staged changes
3. `git log --oneline -10` — recent commits for style reference

If there are no staged changes, report this and stop.

**Size check:** If `git diff --cached --stat` shows more than ~500 changed lines or 20+ files, warn the user and offer to proceed with a file-group summary instead of the full diff.

#### Step B: Compose the Subject Line

Write a subject line that:

- Is **~50 characters** (hard max: 72)
- Uses **conventional commit** format matching the project's recent history (e.g., `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`)
- Includes a scope in parentheses when the change is scoped to a clear module (e.g., `fix(auth):`)
- Uses imperative mood ("add", "fix", "update" — not "added", "fixes", "updated")
- Does NOT end with a period

If the staged changes address GitHub issues, reference them in the body (e.g., `Fixes #3`), not in the subject.

#### Step C: Compose the Body

After a blank line following the subject, write these sections in order:

**## Summary**

A concise description of what changed and why. 1-5 sentences or a short bulleted list. Reference issue numbers with `Fixes #N` if applicable. Focus on the motivation and approach, not a line-by-line narration of the diff.

**## Review**

Use the following review context provided by the parent agent:

```
REVIEW_CONTEXT
```

For each finding, write approximately one sentence indicating:

- What the finding was (briefly)
- Whether it was **addressed**, **rebutted**, or **deferred**
- If deferred, include the issue number (e.g., "deferred to #7")

Format as a bullet list. If the context says "none," write: "No review findings in this session."

**## Conversation**

Use the following conversation context provided by the parent agent:

```
CONVERSATION_CONTEXT
```

Write a brief narrative summary that includes what the user asked for, key decisions or discoveries, the number of user turns, and the number of permission prompts.

#### Step D: Append Co-Author

End the message with:

```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

#### Step E: Hard-Wrap and Output

Hard-wrap all body lines at **72 characters**. When a markdown list item wraps, indent continuation lines to align with the first word after the bullet:

```
- Permission-prompt counting was unreliable when delegated to
  the sub-agent — addressed by moving counting to the parent
  agent and refining to explicit approve/reject only.
```

Output the complete commit message as a single fenced code block. Do not include any commentary outside the code block. The message should be ready to pass directly to `git commit -m`.

---

### Step 2.5: Handle Sub-Agent Failure

If the sub-agent fails, times out, or returns empty/malformed output:

- Report the failure to the user with any available error details.
- Offer to retry, or to generate the message inline (without sub-agent delegation) as a fallback.
- Do not proceed to Step 3 with empty or malformed output.

### Step 3: Present the Message

When the sub-agent returns, display the commit message to the user. Then ask:

1. **Use this message?** — Yes / Revise / Regenerate
2. If "Yes": run `git commit` with the message (use a HEREDOC to preserve formatting).
3. If "Revise": ask the user what to change, then re-run the sub-agent with their feedback incorporated into the prompt. Do not ask the user to paste back a full modified message.
4. If "Regenerate": re-run the sub-agent with any feedback the user provides.

If `git commit` fails (e.g., pre-commit hook rejection, GPG signing error), display the error output and offer to re-stage, adjust the message, or abort.

## Example

The body of commit `07259e5` demonstrates the target format — a Summary that describes scope and motivation, a Review section with numbered findings and clear outcomes, and a Conversation section with highlights and metrics:

```
## Summary

Set up chezmoi to manage shell configs (zsh), git configuration, ~/bin
scripts, and Claude Code settings/hooks/skills/agents. Secrets in .zshenv
reference 1Password via onepasswordRead templates. Migrated from iCloud
symlink-based dotfile management.

## Review findings

All 5 review agents (Architect, User-Advocate, Adversary, Standards,
Operator) ran in parallel before first push. Findings and outcomes:

1. Commit author email leaked employer domain — resolved (reset author)
2. Bash(echo *) and Bash(grep *) in allow-list too broad — resolved (removed)
3. README.md deployed to ~/README.md by chezmoi — resolved (added to .chezmoiignore)
4. PLAN.md with employer names committed to public repo — resolved (removed from git)
5. [github] token in gitconfig writes PAT to disk — resolved (removed section; use gh auth login)
6. Commented GPG keys with employer email in gitconfig — resolved (removed)
7. .claude/settings.local.json missing from .chezmoiignore — resolved (added)
8. dot_zshrc missing private_ prefix, inconsistent with other shell files — resolved (renamed)
9. Unguarded sources in .zshrc (oh-my-zsh, cargo, pyenv) — deferred (#1)
10. Unguarded brew shellenv in .zshenv — deferred (#2)
11. Git aliases reference origin/master instead of origin/main — deferred (#3)
12. Stale gitignore entries (.nvmrc, Thumbs.db.claude, .bpm) — resolved (removed)
13. Added CLAUDE.local.md to global gitignore — resolved

## Conversation

Initial prompt: "let's walk through @PLAN.md together. we're working with
sensitive keys, so let's go slow and check our work"

Highlights: Discovered chezmoi add stores symlink targets (not content)
without --follow. Hit chezmoi secret detection blocking add of .zshenv.
1Password op:// URIs reject colons in item names — switched to item IDs,
then back to renamed items. chezmoi diff hangs when PAGER is set. Full
5-agent review before first push caught employer email in commit metadata,
overly broad Claude Code allow-list, and several files that shouldn't go
public.

Turns: ~40 | Duration: ~2.5 hours

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Error Handling

| Failure | Recovery |
| --- | --- |
| No staged changes | Inform the user and stop |
| Staged diff exceeds ~500 lines | Warn and offer file-group summary |
| Sub-agent fails or times out | Report error, offer retry or inline fallback |
| Sub-agent returns empty output | Report, offer retry |
| `git commit` fails (hook, GPG, etc.) | Display error, offer to re-stage, adjust message, or abort |
| User selects "Revise" | Re-run sub-agent with user's feedback |
