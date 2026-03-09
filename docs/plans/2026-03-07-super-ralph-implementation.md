# Super Ralph Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Claude Code skill that decomposes user queries into tasks, dispatches fresh sub-agents (test-first), retries with self-debugging, and learns over time via learnings.md.

**Architecture:** Single SKILL.md orchestrator that uses AskUserQuestion for pre-flight scoping, then Task tool to spawn Planner → Test/Worker pairs → Merger agents. Learnings persist in learnings.md. Debug failures dump to debug.md for cold analysis.

**Tech Stack:** Claude Code skill (SKILL.md), Task tool sub-agents, Bash for test execution

---

### Task 1: Initialize skill directory

**Files:**
- Create: `skills/super-ralph/SKILL.md`
- Create: `skills/super-ralph/learnings.md`

**Step 1: Create skill directory**

```bash
mkdir -p /Users/ash/.claude/skills/.claude/skills/super-ralph
```

**Step 2: Create empty learnings.md**

```markdown
# Super Ralph Learnings

_No learnings yet. This file grows as Super Ralph completes tasks._
```

Write to: `skills/super-ralph/learnings.md`

**Step 3: Create SKILL.md with frontmatter only (body comes in later tasks)**

```markdown
---
name: super-ralph
description: Autonomous agentic loop that decomposes any user query into tasks, writes tests first, implements with fresh sub-agents, self-debugs on failure, and learns over time. Use when the user says "super ralph", "ralph this", "break this down and build it", or wants autonomous multi-task execution with quality enforcement.
---
```

Write just the frontmatter. Body will be built up in Tasks 2-7.

**Step 4: Commit**

```bash
git add skills/super-ralph/
git commit -m "feat: initialize super-ralph skill directory"
```

---

### Task 2: Write Pre-Flight Scoping section

**Files:**
- Modify: `skills/super-ralph/SKILL.md`

**Step 1: Append the Pre-Flight section to SKILL.md**

Add after frontmatter:

```markdown
# Super Ralph

Autonomous agentic loop: decompose → test → build → debug → learn → merge.

## Phase 0: Pre-Flight Scoping (BLOCKING)

Before any agent runs, scope the workspace using `AskUserQuestion`:

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
```

**Step 2: Commit**

```bash
git add skills/super-ralph/SKILL.md
git commit -m "feat(super-ralph): add pre-flight scoping phase"
```

---

### Task 3: Write Planner Agent section

**Files:**
- Modify: `skills/super-ralph/SKILL.md`

**Step 1: Append the Planner phase to SKILL.md**

```markdown
## Phase 1: Plan & Decompose

Read `learnings.md` from the super-ralph skill directory. Then read the scoped codebase files.

Dispatch a **Planner Agent** using the Task tool:

```
subagent_type: general-purpose
prompt: |
  You are the Super Ralph Planner. Your job is to decompose a user query into independent, high-quality tasks.

  USER QUERY: {query}

  PAST LEARNINGS (apply these — avoid past mistakes, reuse what worked):
  {learnings_md_contents}

  CODEBASE CONTEXT:
  {scoped_file_summaries}

  {WORKSPACE_RULES}

  INSTRUCTIONS:
  1. Break the query into the smallest independent tasks possible
  2. For each task, set the bar HIGH — the output should impress a senior engineer
  3. Mark dependencies between tasks (which must complete before others)
  4. Output valid JSON array

  OUTPUT FORMAT (strict JSON):
  [
    {
      "task_id": 1,
      "title": "Short descriptive title",
      "description": "Detailed description of what to build",
      "quality_standard": "What 'excellent' looks like for this task. Be specific. No shortcuts, no TODOs, no stubs.",
      "success_criteria": [
        "Specific testable outcome 1",
        "Specific testable outcome 2"
      ],
      "anti_patterns": [
        "Don't do X",
        "Don't skip Y"
      ],
      "dependencies": [],
      "test_strategy": "How to verify this task — what tests to write, what to assert"
    }
  ]

  QUALITY RULES:
  - Each task must produce work you'd be proud to ship
  - Success criteria must be specific and testable, not vague
  - Anti-patterns should prevent the most common lazy shortcuts
  - If a task seems too big, break it further
  - Mark dependencies: if task 3 needs task 1's output, set "dependencies": [1]
```

Parse the JSON output. Create a `workspace/` directory with subdirs per task:

```bash
mkdir -p workspace/task-{id}/tests workspace/task-{id}/output
```

Dispatch independent tasks in parallel. Sequential tasks wait for dependencies.
```

**Step 2: Commit**

```bash
git add skills/super-ralph/SKILL.md
git commit -m "feat(super-ralph): add planner agent phase"
```

---

### Task 4: Write Test Agent + Worker Agent + Validator loop

**Files:**
- Modify: `skills/super-ralph/SKILL.md`

**Step 1: Append the per-task execution loop to SKILL.md**

```markdown
## Phase 2: Per-Task Execution Loop

For each task from the planner, run this sequence. **Parallelize independent tasks** (no shared dependencies).

### Step 2a: Test Agent

Dispatch a fresh **Test Agent** per task:

```
subagent_type: code-implementation
prompt: |
  You are the Super Ralph Test Agent. Write strict tests FIRST — before any implementation exists.

  TASK:
  Title: {task.title}
  Description: {task.description}
  Quality Standard: {task.quality_standard}
  Success Criteria: {task.success_criteria}
  Test Strategy: {task.test_strategy}

  {WORKSPACE_RULES}

  WRITE TESTS TO: workspace/task-{task.task_id}/tests/

  INSTRUCTIONS:
  1. Write tests that enforce EVERY success criterion
  2. Test the happy path, edge cases, AND failure modes
  3. Tests should be strict — if they pass, the implementation is genuinely good
  4. Do NOT write lenient tests that pass with a half-baked implementation
  5. Use the appropriate test framework for the language/project
  6. Tests must be runnable with a single command

  OUTPUT: Report the exact command to run the tests (e.g., "pytest workspace/task-1/tests/ -v")
```

Capture the test command from the agent's output.

### Step 2b: Worker Agent (with retry loop)

```
attempt = 0

while true:
    attempt += 1

    if attempt == 1:
        failure_context = ""
    else:
        failure_context = "PREVIOUS ATTEMPT FAILED:\n{last_test_output}\n\nFix the root cause. Don't patch around the error."

    Dispatch fresh Worker Agent:
    ```
    subagent_type: code-implementation
    prompt: |
      You are the Super Ralph Worker. Implement a solution that passes ALL tests.

      TASK:
      Title: {task.title}
      Description: {task.description}
      Quality Standard: {task.quality_standard}
      Anti-Patterns (DO NOT DO THESE): {task.anti_patterns}

      {WORKSPACE_RULES}

      TEST FILES: workspace/task-{task.task_id}/tests/
      WRITE OUTPUT TO: workspace/task-{task.task_id}/output/

      {failure_context}

      INSTRUCTIONS:
      1. Read the tests first — understand what "done" looks like
      2. Implement the solution in the output directory
      3. Your code must be clean, well-structured, and production-grade
      4. Handle edge cases and errors properly
      5. No TODOs, no stubs, no shortcuts
      6. All permissions granted — install deps, run commands, do whatever is needed
    ```

    # Run tests via Bash
    test_result = run("{test_command}")

    if tests pass:
        break  # Success — move to learning capture

    if attempt == 3 and tests still fail:
        enter Debug Mode (Phase 2c)
```

### Step 2c: Validator

After the Worker Agent completes, run the tests via Bash:

```bash
{test_command}
```

- **Pass** → Capture learnings (Phase 2d), move to next task
- **Fail** → Retry Worker with failure output (back to Step 2b)
```

**Step 2: Commit**

```bash
git add skills/super-ralph/SKILL.md
git commit -m "feat(super-ralph): add test/worker/validator execution loop"
```

---

### Task 5: Write Self-Debugging section

**Files:**
- Modify: `skills/super-ralph/SKILL.md`

**Step 1: Append the debug mode section to SKILL.md**

```markdown
## Phase 2c: Self-Debugging (after 3 failed attempts)

When a worker fails 3 times, enter debug mode.

### Step 1: Worker writes debug.md

The 3rd worker attempt MUST write `debug.md` in the skill root before exiting:

Include this in the 3rd worker's prompt:
```
ADDITIONAL INSTRUCTION (attempt 3):
Before finishing, write a file called debug.md with this exact format:

# Debug Report — {task.title}

## Attempt 1
**Approach:** What you tried
**Result:** Test output / error
**Reasoning:** Why you thought this would work

## Attempt 2
**Approach:** What you tried
**Result:** Test output / error
**Reasoning:** Why you thought this would work

## Attempt 3
**Approach:** What you tried
**Result:** Test output / error
**Reasoning:** Why you thought this would work

## Pattern Analysis
- What assumption did all 3 attempts share?
- What keeps failing and why?
- What haven't you tried yet?
```

### Step 2: Fresh Debug Agent analyzes

Dispatch a fresh **Debug Agent**:

```
subagent_type: root-cause-hunter
prompt: |
  You are the Super Ralph Debug Agent. A worker failed 3 times on a task.
  You are reading their reasoning trail COLD — with fresh eyes and no bias.

  Read the file: debug.md

  Also read the test files in: workspace/task-{task.task_id}/tests/
  And the failed implementation in: workspace/task-{task.task_id}/output/

  YOUR JOB:
  1. Read the debug report carefully
  2. Identify the ROOT CAUSE — what fundamental assumption or approach was wrong?
  3. Don't just suggest "try harder" — identify specifically what needs to change
  4. Write a concrete fix plan

  APPEND to debug.md under a new section:

  ## Fix Plan
  **Root cause identified:** [specific root cause]
  **Why previous attempts failed:** [the shared wrong assumption]
  **Correct approach:** [what to do differently]
  **Step-by-step:**
  1. [First thing to do]
  2. [Second thing to do]
  3. [etc.]
```

### Step 3: Fresh Worker follows fix plan

Dispatch a fresh Worker (attempts 4-6) with the debug.md fix plan:

```
subagent_type: code-implementation
prompt: |
  You are the Super Ralph Worker. Previous attempts failed. A debug agent has
  analyzed the failures and written a fix plan.

  Read debug.md — follow the Fix Plan section EXACTLY. Do not improvise.

  TASK: {task definition}
  TEST FILES: workspace/task-{task.task_id}/tests/
  WRITE OUTPUT TO: workspace/task-{task.task_id}/output/

  {WORKSPACE_RULES}

  CRITICAL: Follow the debug agent's fix plan. It identified the root cause
  that you missed. Trust its analysis.
```

Run tests again. If pass → capture learnings + clear debug.md. If fail after attempt 6 → ask user.

### Step 4: Escalation (attempt 6 still failing)

```
AskUserQuestion:
  question: "Task '{task.title}' has failed 6 attempts including self-debugging. What should I do?"
  header: "Stuck task"
  options:
    - label: "Keep trying"
      description: "Reset debug.md and try another debug cycle"
    - label: "Skip this task"
      description: "Mark as failed, continue with other tasks"
    - label: "I'll provide guidance"
      description: "I'll tell you what to do differently"
```
```

**Step 2: Commit**

```bash
git add skills/super-ralph/SKILL.md
git commit -m "feat(super-ralph): add self-debugging mode with debug.md"
```

---

### Task 6: Write Learning Capture section

**Files:**
- Modify: `skills/super-ralph/SKILL.md`

**Step 1: Append the learning capture section to SKILL.md**

```markdown
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
```

**Step 2: Commit**

```bash
git add skills/super-ralph/SKILL.md
git commit -m "feat(super-ralph): add learning capture phase"
```

---

### Task 7: Write Merger Agent section

**Files:**
- Modify: `skills/super-ralph/SKILL.md`

**Step 1: Append the merger phase to SKILL.md**

```markdown
## Phase 3: Merge & Deliver

After ALL tasks complete, dispatch a **Merger Agent**:

```
subagent_type: general-purpose
prompt: |
  You are the Super Ralph Merger. All tasks are complete. Your job is to
  combine everything into one cohesive deliverable.

  COMPLETED TASKS:
  {for each task: task.title, status (pass/fail), output directory}

  TASK OUTPUTS: Read files from each workspace/task-{id}/output/ directory

  {WORKSPACE_RULES}

  INSTRUCTIONS:
  1. Read all task outputs
  2. Combine them into a cohesive final deliverable in workspace/final/
  3. Ensure outputs integrate properly (imports, references, shared state)
  4. Fix any integration issues between independently-built task outputs
  5. Run a final integration check — does everything work together?

  ALSO PRODUCE a summary report:

  # Super Ralph Run Summary

  **Query:** {original query}
  **Tasks:** {total} ({passed} passed, {failed} failed)
  **Total attempts:** {sum of all attempts}

  ## Task Results
  | Task | Status | Attempts | Key Learning |
  |------|--------|----------|-------------|
  | {title} | {pass/fail} | {N} | {one-liner} |

  ## Final Deliverable
  Located in: workspace/final/

  ## Learnings Added
  {count} new entries added to learnings.md
```

Present the summary to the user. The merged output in `workspace/final/` is the deliverable.
```

**Step 2: Commit**

```bash
git add skills/super-ralph/SKILL.md
git commit -m "feat(super-ralph): add merger agent phase"
```

---

### Task 8: Final assembly and validation

**Files:**
- Modify: `skills/super-ralph/SKILL.md`

**Step 1: Read the complete SKILL.md and verify**

Verify:
- Frontmatter has correct `name` and `description`
- All 4 phases are present: Pre-Flight → Plan → Execute → Merge
- Self-debugging flow is complete (attempts 1-3 → debug.md → attempts 4-6 → escalate)
- Learnings capture happens after every task
- debug.md gets cleared after successful debug
- WORKSPACE_RULES injected in every agent prompt
- All sub-agents get full permissions in their prompts

**Step 2: Add a quick-reference flow summary at the top of SKILL.md (after the one-liner)**

```markdown
## Quick Reference

```
User Query
  → Pre-Flight: scope workspace (AskUserQuestion)
  → Planner: decompose into tasks with high quality bar (reads learnings.md)
  → Per Task (parallel if independent):
      → Test Agent: write strict tests
      → Worker Agent: implement until tests pass
      → Fail 3x? → debug.md → Debug Agent → fresh Worker
      → Fail 6x? → ask user
      → Pass → capture learnings, clear debug.md
  → Merger: combine outputs + summary report
```
```

**Step 3: Commit**

```bash
git add skills/super-ralph/
git commit -m "feat(super-ralph): complete skill — ready for use"
```

---

## Execution Notes

- All tasks are sequential (each builds on the previous SKILL.md content)
- Each task appends to SKILL.md — never overwrites previous sections
- The skill lives at `skills/super-ralph/SKILL.md` in the global `.claude/skills/` directory
- No external dependencies — pure Claude Code skill using Task tool + Bash
