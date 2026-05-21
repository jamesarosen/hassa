Always use context7 when I need code generation, setup or configuration steps, or
documentation for any library, tool, API, or configuration format — including Claude
Code itself. Before writing configuration syntax you're not certain about, look it up.
If docs are unclear or unavailable, ask me to verify before applying.

This means you should automatically use the Context7 MCP tools to resolve library id
and get library docs without me having to explicitly ask.

## Data analysis
For data analysis tasks, prefer SQLite or DuckDB over writing Python scripts.
DuckDB can query CSV files directly (`SELECT * FROM 'file.csv'`). If the data
will be queried repeatedly, import it into a SQLite database first to bake in
parsing and classification logic, then query that.

## Shell commands
- Don't use `git -C`, `npm --prefix`, or similar working-directory flags when already in the correct directory. They bypass allow-listed command patterns.
- Don't `cd` into the working directory before running commands — you're already there. Prefixing with `cd` breaks allow-listed patterns just like `-C` does.
- When suggesting Bash permissions, use spaces, not colons: `Bash(ls *)` not `Bash(ls:*)`.
- Prefer `echo "==="` over `echo "---"` as a separator in chained commands. Quoted dashes trigger a false-positive permission prompt ([anthropics/claude-code#16946](https://github.com/anthropics/claude-code/issues/16946)).

## Auto-approvals
- Bash(pnpm install)

## Software Factory

`/factory [issue-number]` runs a full implementation pipeline on any repo:

1. **Plan** — haiku planner agent reads the GitHub issue, discovers test/lint commands, writes `FACTORY_PLAN.md` and `FACTORY_TASKS.md`
2. **Implement** — sonnet implementer agent works through each task, runs tests after each one, marks tasks complete
3. **Review** — architect, user-advocate, and standards agents review in parallel
4. **PR** — pushes the branch and opens a PR for human review (never auto-merges)

Artifact files (`FACTORY_PLAN.md`, `FACTORY_TASKS.md`, `FACTORY_REVIEW.md`) are written to the project root and cleaned up after the PR is created. `FACTORY_BLOCKERS.md` is left in place on failure so you can diagnose what went wrong.

The factory is an environment-level tool — run it from any project directory.
