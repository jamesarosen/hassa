---
name: defer
description: This skill should be used when the user asks to "defer this", "add to later", "do this later", "punt this", "/defer", or when the /deliver skill triages a review finding as "will fix later". Creates a GitHub Issue to track the deferred work.
version: 2.0.0
---

# Defer

Create a GitHub Issue for a deferred task. This is a quick, low-ceremony operation — not a planning session.

## Invocation

- `/defer refactor the auth module` — defaults to `later` priority
- `/defer --next refactor the auth module` — explicit priority
- `/defer --now fix the broken migration` — explicit priority
- Called directly by the user, or by the `/deliver` lead agent during review triage

Sub-agents (e.g., `/review` reviewers) do NOT call this skill directly. They report findings to the lead agent, who triages and defers as needed.

## Behavior

### Step 1: Pre-flight Check

Verify the current directory is a GitHub repository with Issues enabled:

```bash
gh repo view --json name,hasIssuesEnabled
```

If this fails or `hasIssuesEnabled` is false, stop with a clear message: "Cannot defer: this directory is not a GitHub repository with Issues enabled. Run `gh auth login` if not authenticated."

### Step 2: Ensure Labels Exist

Check which labels already exist:

```bash
gh label list --json name
```

For each of `deferred`, `now`, `next`, `later` — only create labels that are missing:

```bash
gh label create deferred --description "Deferred task" --color "ededed"
gh label create now --description "Do now" --color "d73a4a"
gh label create next --description "Do next" --color "fbca04"
gh label create later --description "Do later" --color "c5def5"
```

Skip any that already exist. Do not overwrite existing labels.

### Step 3: Determine Priority

Default: **later**.

Override with `--now`, `--next`, or `--later` in the invocation. If the caller specifies a priority explicitly, use it.

### Step 4: Compose the Issue

**Title:** A concise imperative description of the task (e.g., "Refactor auth module to use middleware pattern"). Do not include priority or labels in the title.

**Body:** Keep it brief. Include:

- One or two sentences describing what should be done and why.
- Context line if the source is clear — e.g., "Spotted during signup feature work" or "Flagged by Operator reviewer." Omit when there's no meaningful context.
- When called by `/deliver`, include a back-reference: "Identified during review of PR #N" or "Identified during work on branch `feat/foo`."

### Step 5: Check for Duplicates

Search for existing open issues with similar titles:

```bash
gh issue list --state open --search "<2-4 distinctive words from the title>"
```

If a potential match is found, show it to the caller and ask: "Possible duplicate: #N — <title>. Create a new issue anyway?"

If called by `/deliver`, bias toward creating the issue (duplicates are cheaper than lost work items).

### Step 6: Create the Issue

```bash
gh issue create \
  --assignee @me \
  --label "deferred" \
  --label "<priority>" \
  --title "$(cat <<'TITLE'
<title>
TITLE
)" \
  --body "$(cat <<'BODY'
<body>
BODY
)"
```

### Step 7: Confirm

Print what was created, including the URL returned by `gh issue create`:

```
Deferred: "Refactor auth module to use middleware pattern" → #42 (later)
https://github.com/owner/repo/issues/42
```

## Error Handling

| Failure | Recovery |
| --- | --- |
| `gh` not authenticated | Inform user to run `gh auth login` |
| No GitHub remote or Issues disabled | Inform user; stop (do not create issue) |
| `gh issue create` fails (user invocation) | Show error output, suggest retrying |
| `gh issue create` fails (`/deliver` invocation) | Log warning in triage output, continue without stopping |
| `gh issue list --search` fails | Skip duplicate check, proceed with creation |
| `gh label create` fails | Proceed with issue creation anyway (labels are optional) |
