---
name: super-ralph
description: Autonomous agentic loop that decomposes any user query into tasks, writes tests first, implements with fresh sub-agents, self-debugs on failure, and learns over time. Use when the user says "super ralph", "ralph this", "break this down and build it", or wants autonomous multi-task execution with quality enforcement.
---

# Super Ralph

Autonomous agentic loop: decompose → test → build → debug → learn → merge.

## Quick Reference

```
User Query
  → Pre-Flight: scope workspace (AskUserQuestion)
  → ralph-planner: decompose into tasks with high quality bar (reads learnings.md)
  → Per Task (parallel if independent):
      → ralph-tester: write strict tests
      → ralph-worker: implement until tests pass
      → Fail 3x? → debug.md → ralph-debugger → fresh ralph-worker
      → Fail 6x? → auto-skip + log to learnings
      → Pass → capture learnings, clear debug.md
  → ralph-merger: combine outputs + summary report
```

## Agents

| Agent | File | Role |
|-------|------|------|
| ralph-planner | `agents/ralph-planner.md` | Decomposes query into tasks with high quality bar |
| ralph-tester | `agents/ralph-tester.md` | Writes strict tests before implementation |
| ralph-worker | `agents/ralph-worker.md` | Implements until tests pass, writes debug.md on attempt 3 |
| ralph-debugger | `agents/ralph-debugger.md` | Cold analysis of failures, writes fix plan |
| ralph-merger | `agents/ralph-merger.md` | Combines outputs into cohesive deliverable |

---

## IMPORTANT: Fully Autonomous After Pre-Flight

After Phase 0, the entire loop runs **without any user interaction**. No `AskUserQuestion` calls, no confirmations, no escalations. If something fails after max retries, auto-skip it and log to learnings. The user said "go ahead" — respect that.

---

## Phase 0: Pre-Flight Scoping (BLOCKING — only user interaction)

Before any agent runs, scope the workspace using `AskUserQuestion`. **This is the ONLY phase that asks the user anything.**

**Question 1 — Writable directories:**
```
question: "Which files/folders should I work in? (I'll create and modify files here)"
header: "Work in"
options:
  - label: "Current directory"
    description: "Work in the current project root and subdirectories"
  - label: "Specific paths"
    description: "I'll list the exact directories/files"
multiSelect: false
```

**Question 2 — Read-only context:**
```
question: "Any files I should read for context but NOT modify?"
header: "Read-only"
options:
  - label: "None — figure it out"
    description: "Explore the codebase yourself"
  - label: "I'll list them"
    description: "Specific files/dirs to read but not touch"
multiSelect: false
```

**Question 3 — Off-limits:**
```
question: "Anything off-limits? (files/folders I must never touch)"
header: "Off-limits"
options:
  - label: "Nothing off-limits"
    description: "You can work anywhere within the writable scope"
  - label: "I'll list exclusions"
    description: "Specific paths to avoid"
multiSelect: false
```

Store the answers as `WORKSPACE_RULES` — inject into every sub-agent prompt:

```
WORKSPACE RULES:
- You may READ and WRITE files in: [writable paths]
- You may READ (not modify): [read-only paths]
- Do NOT touch: [off-limits paths]
- All permissions granted — do not ask for confirmation on any action.
```

---

## Phase 1: Plan & Decompose

1. Read `learnings.md` from the super-ralph skill directory
2. Read the scoped codebase files
3. Dispatch **ralph-planner** with: user query + learnings + codebase context + WORKSPACE_RULES
4. Parse the JSON task array output
5. Create workspace directories:

```bash
mkdir -p workspace/task-{id}/tests workspace/task-{id}/output
```

6. Dispatch independent tasks in parallel. Sequential tasks wait for dependencies.

---

## Phase 2: Per-Task Execution Loop

For each task from the planner. **Parallelize independent tasks** (no shared dependencies).

### Step 2a: Test Agent

Dispatch **ralph-tester** with: task definition + WORKSPACE_RULES

Tester writes tests to `workspace/task-{id}/tests/` and reports the test command.

### Step 2b: Worker Agent (with retry loop)

```
attempt = 0

while true:
    attempt += 1

    if attempt == 1:
        failure_context = ""
    else:
        failure_context = "PREVIOUS ATTEMPT FAILED:\n{last_test_output}\n\nFix the root cause."

    if attempt == 3:
        Add to prompt: "This is attempt 3. You MUST write debug.md before exiting."

    Dispatch fresh ralph-worker with:
      task definition + test locations + failure_context + WORKSPACE_RULES

    Run tests via Bash: {test_command}

    if tests pass:
        break → Phase 2d (capture learnings)

    if attempt == 3 and tests still fail:
        enter Phase 2c (self-debugging)
```

### Step 2c: Validator

Run tests via Bash after each worker attempt:
- **Pass** → Phase 2d (capture learnings)
- **Fail** → retry worker with failure output

---

## Phase 2c: Self-Debugging (after 3 failed attempts)

### Step 1: debug.md already written
The 3rd ralph-worker writes `debug.md` with all 3 attempts, reasoning, and pattern analysis.

### Step 2: Fresh Debug Agent
Dispatch **ralph-debugger** — reads debug.md cold, identifies root cause, appends fix plan.

### Step 3: Fresh Worker follows fix plan
Dispatch fresh **ralph-worker** (attempts 4-6) with debug.md. Worker follows the fix plan exactly.

Run tests again:
- **Pass** → capture learnings + clear debug.md
- **Fail after attempt 6** → auto-skip (Step 4)

### Step 4: Auto-Skip (attempt 6 still failing)

**Do NOT ask the user.** The loop is fully autonomous after pre-flight.

1. Mark the task as **FAILED**
2. Log the full failure trail to `learnings.md` (all 6 attempts, debug analysis, what was tried)
3. Continue with remaining tasks — do not stop the loop
4. The merger will note skipped tasks in the final summary report

---

## Phase 2d: Capture Learnings

After each task completes (pass or fail), append to `learnings.md`:

```markdown
## {date} — {task.title}

**Query:** {original user query}
**Task:** {task.description}
**Result:** {pass/fail}
**Attempts:** {attempt_count}

### What worked
- {approach that succeeded}

### What failed
- {approach that failed and why — for each failed attempt}

### Patterns
- {reusable insight for future runs}
```

**If debug mode was used and succeeded:**
1. Extract the root cause and fix from debug.md → include in "What failed" and "Patterns"
2. **Clear debug.md** — write it back to just: `_Empty — ready for next debug session._`

debug.md is a scratch pad. learnings.md is the permanent record.

---

## Phase 3: Merge & Deliver

After ALL tasks complete, dispatch **ralph-merger** with:
- All task titles, statuses, and output directories
- WORKSPACE_RULES

Merger combines outputs into `workspace/final/`, resolves integration issues, and produces a summary report.

Present the summary to the user. The merged output in `workspace/final/` is the deliverable.
