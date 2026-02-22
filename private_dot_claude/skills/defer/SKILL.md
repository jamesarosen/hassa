---
name: defer
description: This skill should be used when the user asks to "defer this", "add to later", "do this later", "punt this", "/defer", or when the /deliver skill triages a review finding as "will fix later". Appends deferred tasks to the project's Now/Next/Later document.
version: 1.0.0
---

# Defer

Append a deferred task to the project's `docs/_now-next-later.md`. This is a quick, low-ceremony operation — not a planning session.

## Invocation

- `/defer refactor the auth module` — adds to Later (default)
- `/defer --next refactor the auth module` — explicit placement
- `/defer --now fix the broken migration` — explicit placement
- Called directly by the user, or by the `/deliver` lead agent during review triage

Sub-agents (e.g., `/review` reviewers) do NOT call this skill directly. They report findings to the lead agent, who triages and defers as needed.

## Behavior

### Step 1: Locate the Document

Look for `docs/_now-next-later.md` in the project root.

- **If called by the user** and the file does not exist: ask "No `docs/_now-next-later.md` found. Where should deferred items go?" Do not create the file without approval.
- **If called by `/deliver`** and the file does not exist: skip the defer, log a warning in the review triage output ("Could not defer — no `docs/_now-next-later.md` found"), and continue without stopping.

### Step 2: Determine Placement

Default: **Later**.

Override with `--now`, `--next`, or `--later` in the invocation. If the caller specifies a section explicitly, use it.

### Step 3: Format the Item

Append a markdown list item to the chosen section. Keep descriptions concise — one line.

Context in parentheses is optional. Include it when the source is clear (e.g., during `/deliver` review triage). Omit it when the user provides no context and nothing is obvious from conversation.

**With context:**
```
- Refactor auth module to use middleware pattern (spotted during signup feature)
- Add rate limiting to public API (flagged by Operator reviewer)
```

**Without context:**
```
- Extract shared validation logic from controllers
```

Match the style of existing items in the document. If existing items don't use parenthetical context, prefer omitting it.

### Step 4: Append to the Correct Section

The document uses `# Now`, `# Next`, and `# Later` as section headers. It may contain additional sections (e.g., `# Decisions Log`) — leave those untouched.

**Parsing rules:**

1. Find the target section header: a line matching `^# (Now|Next|Later)$`
2. Find the section's end: the next `^# ` header line, or end of file
3. Within the section, skip any leading blank lines and `---` separators
4. Find the last list item (a line starting with `- `). If a list item wraps to continuation lines (indented non-`-` lines), those belong to the previous item.
5. Append the new item after the last list item (or after the header + blank line if the section is empty)

Before appending, scan the target section for an existing item with substantially similar text. If found, skip the append and note: "Similar item already exists in [section]: [existing item]"

### Step 5: Confirm

Print what was added and to which section:

```
Deferred: "Refactor auth module to use middleware pattern" → Later
```
