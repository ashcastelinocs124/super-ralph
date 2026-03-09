# Super Ralph — Design Document

**Date:** 2026-03-07
**Status:** Approved

## Overview

Super Ralph is a Claude Code skill that receives a user query, decomposes it into independent tasks, and dispatches fresh sub-agents to implement each task using a test-first approach. The system learns over time by reading/writing to a persistent `learnings.md`. All sub-agents run with full permissions — fully autonomous.

## Architecture

```
User Query
    │
    ▼
┌──────────────┐
│  PRE-FLIGHT  │  Ask user: writable dirs, read-only context, off-limits
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   PLANNER    │  Reads learnings.md + scoped codebase
│              │  Decomposes into tasks with high quality standards
└──────┬───────┘
       │ JSON task array
       ▼
┌──────────────────────────────────────────┐
│  PER-TASK LOOP (parallel if independent) │
│                                          │
│  Test Agent → writes strict tests        │
│       │                                  │
│  Worker Agent → implements solution      │
│       │                                  │
│  Run tests → pass? → learnings.md        │
│       │       fail? → retry (up to 3)    │
│       │                                  │
│  3 fails? → debug.md reasoning dump      │
│       │  → fresh Debug Agent analyzes    │
│       │  → fresh Worker follows fix plan │
│       │  → success? learnings + clear    │
│       │    debug.md                      │
│       │  → 6 fails? ask user             │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────┐
│   MERGER     │  Combines all outputs + learnings summary
└──────────────┘
       │
       ▼
  Final Deliverable + Learnings Report
```

## Pre-Flight Scoping

Before any agent runs, ask the user:

1. **Writable directories** — where agents can create/modify files
2. **Read-only context** — files to read for understanding but not modify
3. **Off-limits paths** — never touch these

Scope is injected into every sub-agent prompt as WORKSPACE RULES.

## Task Definition Format

```json
{
  "task_id": 1,
  "title": "Build user auth system",
  "description": "What to build",
  "quality_standard": "Production-grade. Handle edge cases. Clean code.",
  "success_criteria": [
    "All auth flows work end-to-end",
    "Edge cases handled with clear error messages",
    "No security vulnerabilities",
    "Code is clean, well-structured, no shortcuts"
  ],
  "anti_patterns": [
    "Don't stub or mock the hard parts",
    "Don't skip error handling",
    "Don't leave TODOs"
  ],
  "dependencies": []
}
```

The planner sets expectations HIGH — each task should produce work a senior engineer would approve.

## Agent Types

| Agent | Task Tool Type | Input | Output |
|-------|---------------|-------|--------|
| Planner | general-purpose | User query + learnings.md + scoped files | JSON task array |
| Test Agent | code-implementation | Single task definition | Test files on disk |
| Worker Agent | code-implementation | Task + test locations + failure output (retries) | Implementation files |
| Debug Agent | root-cause-hunter | debug.md (reasoning trail) | Fix plan appended to debug.md |
| Merger | general-purpose | All task outputs + test results + learnings | Final deliverable |

## Retry & Self-Debugging

### Standard retries (1-3)
- Fresh worker each attempt
- Gets task definition + test locations + previous failure output

### Debug mode (after attempt 3)
- Worker writes debug.md: all 3 attempts, reasoning, expected vs actual
- Fresh Debug Agent reads debug.md cold, identifies root cause, writes fix plan
- Fresh Worker follows the fix plan (attempts 4-6)
- On success: extract learnings → append to learnings.md → clear debug.md

### Escalation (after attempt 6)
- Ask user: keep going, skip, or provide guidance

## Learnings Format

```markdown
## 2026-03-07 — [Task Title]

**Query:** Original user query
**Task:** What this specific task was
**Result:** pass/fail
**Attempts:** N

### What worked
- Approach X solved the core problem

### What failed
- Attempt A failed because B

### Patterns
- When doing X, always check Y first
```

## File Structure

```
super-ralph/
  SKILL.md              ← Skill definition
  learnings.md          ← Persistent memory (append-only)
  debug.md              ← Ephemeral scratch pad (cleared after use)
  workspace/
    task-1/tests/
    task-1/output/
    task-2/tests/
    task-2/output/
    final/              ← Merged deliverable
```

## Key Properties

- All sub-agents are **fresh** — clean context per invocation
- All permissions granted — fully autonomous execution
- `learnings.md` persists across runs — system improves over time
- `debug.md` is ephemeral — always cleared after use
- Planner reads past learnings before decomposing
- Quality bar is set high in task definitions, enforced by strict tests
- Independent tasks run in parallel
