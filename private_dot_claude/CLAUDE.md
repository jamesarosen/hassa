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
- When suggesting Bash permissions, use spaces, not colons: `Bash(ls *)` not `Bash(ls:*)`.

## Auto-approvals
- Bash(pnpm install)
