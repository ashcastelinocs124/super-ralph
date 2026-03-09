# Super Ralph Learnings

## 2026-03-09 — Full Stack AI Data Analyst

**Query:** Build a full stack AI data analyst
**Result:** pass
**Attempts:** 1 (all tasks completed first try)

### What worked
- Direct execution from main agent after subagents hit permission issues
- Writing tests first for each service, then implementing until tests pass
- Building backend and frontend scaffolds in parallel as Wave 1
- Parallel service development (file_service, analysis_service, ai_service) as Wave 3
- TypeScript interfaces mirroring Pydantic models exactly prevented integration issues
- Using `npx tsc --noEmit` for frontend verification, `pytest -v` for backend

### What failed
- Subagent dispatch (code-implementation agents) failed because they lack Bash/Write permissions in background mode
- create-next-app interactive prompt blocked non-interactive execution (needed --yes flag)
- Running `npm run build` from wrong directory (parent dir instead of frontend/)
- Recharts PieLabel type requires optional `name?: string` not `name: string`

### Patterns
- Always use `--yes` flag with create-next-app for non-interactive scaffolding
- Run frontend commands from the frontend directory explicitly
- When subagents hit permission barriers, switch to direct execution immediately rather than retrying
- Pydantic v2 `model_config` not `class Config` for model configuration
- pandas 3.x warns about `select_dtypes(include=["object"])` — add `"str"` explicitly
- For Recharts Pie label prop, use optional types: `{ name?: string; percent?: number }`
