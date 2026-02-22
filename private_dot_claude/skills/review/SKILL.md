---
name: review
description: This skill should be used when the user asks to "review code", "review this plan", "review my changes", "review the diff", "review this file", "review this ADR", "/review", or wants expert feedback on code, architecture, plans, or design documents. Supports multi-perspective review using specialized agents.
version: 1.1.0
---

# Multi-Perspective Code & Design Review

This skill orchestrates parallel reviews from specialized reviewer agents and synthesizes their feedback into actionable guidance. Treat the synthesized output as informed input to decision-making, not as authoritative directives — project context, team conventions, and business requirements may override any finding.

## Inputs

The review target defaults to `main...HEAD` (the current branch diff). The user may specify:

- **A file path**: `/review src/app.ts` or `/review docs/ADR-001.md`
- **A git diff range**: `/review main...feature-branch`
- **A plan from context**: `/review the plan` (reviews the most recent plan discussed in conversation)

### Specifying Reviewers

Override automatic selection with natural language:

- `/review with all reviewers` — uses all 5
- `/review src/app.ts with Architect and Operator` — uses only those two
- `/review the plan with Adversary` — uses only Adversary

If a requested reviewer name doesn't match an available reviewer, list the available options and ask for clarification.

Reviewer names: **Architect**, **User-Advocate**, **Adversary**, **Standards**, **Operator**

## Reviewer Selection

### Available Reviewers

| Reviewer      | Subagent Type   | Focus                                                        |
| ------------- | --------------- | ------------------------------------------------------------ |
| Architect     | `architect`     | Structure, layering, coupling, abstractions, system design   |
| User-Advocate | `user-advocate` | API ergonomics, error messages, naming, DX, end-user impact  |
| Adversary     | `adversary`     | Breaks assumptions, finds holes, challenges decisions        |
| Standards     | `standards`     | Project conventions, linter rules, consistency with codebase |
| Operator      | `operator`      | Observability, error handling, failure modes, debuggability  |

### Selection Rules

1. **If the user specifies reviewers**, use exactly those.
2. **Otherwise**, use all reviewers

## Execution

### Step 1: Validate and Identify the Target

**For git diff targets** (`main...HEAD` or a specified range):

1. Run `git rev-parse --verify main 2>/dev/null` to confirm the base branch exists. If it fails, try `master`. If neither exists, ask the user for the base branch.
2. Run `git rev-parse --abbrev-ref HEAD` — if on the base branch, inform the user there is no branch diff and suggest specifying a file or range instead.
3. Run `git diff main...HEAD --stat` to understand scope.
4. If the diff is empty, inform the user: "No committed changes between main and HEAD. Check `git status` for uncommitted work, or specify a file to review."
5. **Size check**: If the diff exceeds ~500 changed lines or touches 20+ files, inform the user and offer options:
   - Review only the most impactful files (auto-select top 5-10)
   - Narrow scope: `/review src/components/`
   - Proceed with full review (may be slower or truncated)

**For file targets**: Read the file. If it doesn't exist, inform the user and ask for clarification. If the file is binary, skip review and note it.

**For plans/documents from conversation**: Locate the plan content in the conversation context. If ambiguous, ask the user to clarify which plan.

### Step 2: Launch Parallel Reviews

Announce the reviewers before launching:

> Launching 3 reviewers: Architect (structure), Standards (conventions), Adversary (assumptions)

Use the **Task tool** to launch each selected reviewer as a parallel subagent. Each Task call must:

- Set `subagent_type` to the reviewer's agent type from the table above
- Provide a clear prompt that includes:
  - What to review (the target content or how to access it)
  - The reviewer's specific focus area
  - Instructions to categorize findings by severity: **CRITICAL**, **HIGH**, **MEDIUM**, **LOW**
  - Instructions to be specific — cite file paths, line numbers, and concrete suggestions
- For the **Standards** reviewer, additionally instruct: "Read CLAUDE.md, linter configs, and nearby code to discover project conventions. Skip style and formatting issues already enforced by linters."

Example prompt structure for each reviewer:

```
Review the following [code changes / plan / file] from the perspective of [focus area].

Target: [description of what to review, e.g., "the diff from main...HEAD" or "the file at path/to/file"]

Categorize each finding by severity:
- CRITICAL: Would cause production failure, data loss, security breach, or break existing users
- HIGH: Significant design flaw, major usability issue, or missing critical functionality
- MEDIUM: Code quality concerns, naming issues, minor design improvements
- LOW: Style nits, optional improvements, nice-to-haves

For each finding, provide:
1. Severity level
2. Location (file:line when applicable)
3. Description of the issue
4. Suggested fix or alternative

Be specific and actionable. Cite file paths and line numbers.
```

### Step 2.5: Handle Reviewer Failures

After launching, check that each reviewer completes:

- **Single failure**: Note in synthesis that the reviewer was unavailable and continue with remaining reviews.
- **Multiple failures**: Warn the user that coverage is limited; offer to retry.
- **All failures**: Abort with a clear error and suggest retrying or narrowing scope.
- **Empty output**: If a reviewer returns no findings or only generic praise, note "[Reviewer] produced no findings" in the output.

### Step 3: Synthesize Results

After all reviewers complete (or fail gracefully), produce a unified review:

1. **Read all reviewer outputs** carefully.
2. **Deduplicate** — if multiple reviewers flag the same issue (same file/location, same root cause), consolidate into one finding. If their recommendations differ, present both.
3. **Prioritize** — order findings by severity (CRITICAL first, then HIGH, MEDIUM, LOW).
4. **Acknowledge every CRITICAL and HIGH finding** — for each one, either:
   - Agree and recommend action
   - Disagree with rationale (explain why it's not actually critical/high)
   - Partially agree and suggest a modified approach
5. **When reviewers conflict** (e.g., Architect says "add abstraction", Operator says "keep it simple"), present both perspectives with attribution and identify the tradeoff.
6. **Curate MEDIUM and LOW findings** — include those that add value; omit noise.
7. **Add lead perspective** — note anything the reviewers missed, or provide overarching guidance.

### Output Format

Present the final review as:

```
## Review Summary

**Target:** [what was reviewed]
**Reviewers:** Architect (structure) ✓, Standards (conventions) ✓, Operator (reliability) ✗ timed out

### Critical & High Priority

1. **CRITICAL** | `src/auth.ts:42` | [Description]
   - **Reviewers:** [who raised it]
   - **Disposition:** Agree / Disagree / Partially agree — [rationale]
   - **Recommendation:** [specific action]

2. **HIGH** | `src/api.ts:15` | [Description]
   - **Reviewers:** [who raised it]
   - **Disposition:** [...]
   - **Recommendation:** [...]

### Notable Findings

[Curated MEDIUM/LOW findings worth addressing, with reviewer attribution]

### Overall Assessment

[1-3 sentences: overall quality, key themes, recommended next steps]
```
