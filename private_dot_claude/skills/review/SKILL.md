---
name: review
description: This skill should be used when the user asks to "review code", "review this plan", "review my changes", "review the diff", "review this file", "review this ADR", "/review", or wants expert feedback on code, architecture, plans, or design documents. Supports multi-perspective review using specialized agents.
version: 2.0.0
---

# Multi-Perspective Code & Design Review

This skill orchestrates parallel reviews from two specialized reviewer agents and synthesizes their feedback into actionable guidance. Treat the synthesized output as informed input to decision-making, not as authoritative directives — project context, team conventions, and business requirements may override any finding.

## Inputs

The review target defaults to `main...HEAD` (the current branch diff). The user may specify:

- **A file path**: `/review src/app.ts` or `/review docs/ADR-001.md`
- **A git diff range**: `/review main...feature-branch`
- **A plan from context**: `/review the plan` (reviews the most recent plan discussed in conversation)

### Specifying Reviewers

Override automatic selection with natural language:

- `/review with both reviewers` — uses both (default)
- `/review src/app.ts with User Advocate` — uses only that reviewer
- `/review the plan with Lead Engineer` — uses only Lead Engineer

If a requested reviewer name doesn't match an available reviewer, list the available options and ask for clarification.

Reviewer names: **User Advocate**, **Lead Engineer**

## Reviewer Selection

### Available Reviewers

| Reviewer       | Subagent Type   | Focus                                                                          |
| -------------- | --------------- | ------------------------------------------------------------------------------ |
| User Advocate  | `user-advocate` | Feature completeness, accessibility, data privacy, API ergonomics, naming, DX  |
| Lead Engineer  | `adversary`     | Security, performance, testing, layer violations, coupling, missing edge cases  |

### Selection Rules

1. **If the user specifies reviewers**, use exactly those.
2. **Otherwise**, use both reviewers.

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

> Launching 2 reviewers: User Advocate (features, accessibility, privacy), Lead Engineer (security, performance, testing)

Use the **Agent tool** to launch both reviewers in parallel. Each Agent call must:

- Set `subagent_type` to the reviewer's agent type from the table above
- Provide a clear prompt that includes:
  - What to review (the target content or how to access it)
  - The reviewer's specific focus area
  - An explicit **scope boundary** (what NOT to comment on)
  - Instructions to categorize findings by severity: **CRITICAL**, **HIGH**, **MEDIUM**, **LOW**
  - Instructions to be specific — cite file paths, line numbers, and concrete suggestions

#### Prompt template for User Advocate

```
You are a senior product engineer and accessibility specialist who has shipped features to millions of users. Review the following [code changes / plan / file] from the perspective of the people who will use this software.

Target: [description of what to review, e.g., "the diff from main...HEAD" or "the file at path/to/file"]

Your focus areas:
- Feature completeness: are there obvious missing cases, incomplete flows, or unhandled states a user would encounter?
- Accessibility: ARIA roles, keyboard navigation, screen reader support, color contrast, focus management
- Data privacy: PII exposure, unnecessary data collection, insecure storage of sensitive data, missing consent
- API ergonomics (if applicable): naming clarity, error message quality, developer experience
- Documentation gaps that would confuse consumers of this code

Do NOT comment on: security vulnerabilities, performance/algorithmic complexity, test coverage, architectural coupling, or layer violations — those are handled by another reviewer.

Categorize each finding by severity:
- CRITICAL: Would harm or exclude users, expose PII, or cause data loss
- HIGH: Significant usability gap, accessibility blocker, or major feature incompleteness
- MEDIUM: Confusing UX, unclear error messages, missing edge case visible to users
- LOW: Minor naming improvements, optional accessibility enhancements, nice-to-haves

For each finding, provide:
1. Severity level
2. Location (file:line when applicable)
3. Description of the issue
4. Suggested fix or alternative

Be specific and actionable. Cite file paths and line numbers.
```

#### Prompt template for Lead Engineer

```
You are a skeptical senior engineer who has been burned by production incidents. Review the following [code changes / plan / file] with a critical eye toward engineering quality and correctness.

Target: [description of what to review, e.g., "the diff from main...HEAD" or "the file at path/to/file"]

Your focus areas:
- Security: injection risks, authentication/authorization flaws, OWASP Top 10, secrets in code, input validation
- Performance: algorithmic complexity, N+1 queries, unnecessary allocations, blocking calls, missing indexes
- Testing: missing test coverage for critical paths, untested edge cases, flaky test patterns, missing error case tests
- Layer violations: business logic leaking into views/controllers, persistence concerns in domain layer, wrong abstraction level
- Missing edge cases: null/undefined handling, race conditions, off-by-one errors, integer overflow, empty state

Do NOT comment on: user experience, accessibility, API naming/ergonomics, feature completeness from a user perspective, or data privacy consent flows — those are handled by another reviewer.

Categorize each finding by severity:
- CRITICAL: Would cause production failure, data loss, security breach, or break existing users
- HIGH: Significant design flaw, exploitable security issue, serious performance problem, or missing critical test
- MEDIUM: Code quality concern, minor security hardening, performance improvement, missing non-critical tests
- LOW: Style nits, optional refactors, nice-to-have edge case coverage

For each finding, provide:
1. Severity level
2. Location (file:line when applicable)
3. Description of the issue
4. Suggested fix or alternative

Be specific and actionable. Cite file paths and line numbers. Challenge assumptions — if something looks wrong, say so even if it might be intentional.
```

### Step 2.5: Handle Reviewer Failures

After launching, check that each reviewer completes:

- **Single failure**: Note in synthesis that the reviewer was unavailable and continue with remaining review.
- **Both failures**: Abort with a clear error and suggest retrying or narrowing scope.
- **Empty output**: If a reviewer returns no findings or only generic praise, note "[Reviewer] produced no findings" in the output.

### Step 3: Synthesize Results

After all reviewers complete (or fail gracefully), produce a unified review:

1. **Read all reviewer outputs** carefully.
2. **Deduplicate** — if both reviewers flag the same issue (same file/location, same root cause), consolidate into one finding. If their recommendations differ, present both.
3. **Prioritize** — order findings by severity (CRITICAL first, then HIGH, MEDIUM, LOW).
4. **Acknowledge every CRITICAL and HIGH finding** — for each one, either:
   - Agree and recommend action
   - Disagree with rationale (explain why it's not actually critical/high)
   - Partially agree and suggest a modified approach
5. **When reviewers conflict**, present both perspectives with attribution and identify the tradeoff.
6. **Curate MEDIUM and LOW findings** — include those that add value; omit noise.

### Output Format

Present the final review as:

```
## Review Summary

**Target:** [what was reviewed]
**Reviewers:** User Advocate (features, accessibility, privacy) ✓, Lead Engineer (security, performance, testing) ✓

### Critical & High Priority

1. **CRITICAL** | `src/auth.ts:42` | [Description]
   - **Reviewer:** [who raised it]
   - **Disposition:** Agree / Disagree / Partially agree — [rationale]
   - **Recommendation:** [specific action]

2. **HIGH** | `src/api.ts:15` | [Description]
   - **Reviewer:** [who raised it]
   - **Disposition:** [...]
   - **Recommendation:** [...]

### Notable Findings

[Curated MEDIUM/LOW findings worth addressing, with reviewer attribution]

### Overall Assessment

[1-3 sentences: overall quality, key themes, recommended next steps]
```
