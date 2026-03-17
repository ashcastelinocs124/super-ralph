---
name: super-ralph
description: Autonomous agentic loop that decomposes any user query into tasks, writes tests first, implements with fresh sub-agents, self-debugs on failure, and learns over time. Use when the user says "super ralph", "ralph this", "break this down and build it", or wants autonomous multi-task execution with quality enforcement.
---

# Super Ralph

Autonomous agentic loop: decompose → test → build → debug → learn → merge.

## Quick Reference

```
User Query
  → Brainstorm: interactive Q&A to explore intent, scope, edge cases (AskUserQuestion loop)
  → Pre-Flight: scope workspace + set MAX_RETRIES (AskUserQuestion)
  → ralph-planner: decompose into tasks with high quality bar (reads learnings.md + brainstorm summary)
  → Per Task (parallel if independent):
      → ralph-tester: write strict tests
      → ralph-worker: implement until tests pass
      → Fail MAX_RETRIES/2? → debug.md → ralph-debugger → fresh ralph-worker
      → Fail MAX_RETRIES? → auto-skip + log to learnings
      → Pass → clear debug.md
  → ralph-merger: combine outputs + write consolidated learnings entry + summary report
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

## Phase -1: Brainstorm (BLOCKING — interactive Q&A before anything else)

Before scoping the workspace or planning tasks, **explore the user's idea through conversation**. The goal is to deeply understand what the user actually wants — not just what they typed.

**This phase is interactive.** Use `AskUserQuestion` in a loop until both sides are aligned.

### How it works

1. **Restate the query** — show the user your understanding of what they're asking for in 2-3 sentences. This surfaces misunderstandings early.

2. **Ask clarifying questions** — use `AskUserQuestion` to explore:

```
question: "[Specific question about the user's intent, scope, or approach]"
header: "Clarify"
options:
  - label: "[Most likely answer]"
    description: "[What this means for the build]"
  - label: "[Alternative interpretation]"
    description: "[What this means for the build]"
  - label: "[Simpler/narrower version]"
    description: "[What this means for the build]"
multiSelect: false
```

3. **Explore iteratively** — after each answer, ask follow-up questions if new ambiguities surface. Cover these areas:

| Area | Example Questions |
|------|-------------------|
| **Intent** | "Is this a prototype or production-grade?" |
| **Scope** | "Should this include X, or is that out of scope?" |
| **Edge cases** | "What should happen when Y occurs?" |
| **Users** | "Who will use this — just you, your team, or end users?" |
| **Constraints** | "Any specific tech stack, libraries, or patterns to use/avoid?" |
| **Existing work** | "Is this building on something that already exists, or greenfield?" |

4. **Produce a brainstorm summary** — when you have enough clarity, write a summary:

```markdown
## Brainstorm Summary

**Query:** {original user query}
**Intent:** {what the user actually wants, in your words}

### Scope
- {what's in scope}
- {what's explicitly out of scope}

### Key Decisions
- {decision 1 from the Q&A}
- {decision 2 from the Q&A}

### Edge Cases Discussed
- {edge case and agreed handling}

### Constraints
- {any tech/approach constraints from the user}
```

5. **Confirm the summary** — show the summary to the user with one final `AskUserQuestion`:

```
question: "Here's what I'll build. Does this capture it?"
header: "Confirm"
options:
  - label: "Yes, go ahead"
    description: "This is right — proceed to workspace setup and autonomous execution"
  - label: "Almost — let me adjust"
    description: "I'll clarify what needs changing"
multiSelect: false
```

If "Almost" → incorporate feedback, update summary, re-confirm. If "Yes" → store the summary as `BRAINSTORM_SUMMARY` and proceed to Phase 0.

### Rules

- Ask **2-5 questions total** — enough to remove ambiguity, not so many it feels like an interrogation
- Batch related questions into a single `AskUserQuestion` when possible (up to 4 per call)
- Don't ask questions the user already answered in their original query
- Don't ask about workspace scope here — that's Phase 0's job
- If the query is dead simple and unambiguous (e.g., "add a .gitignore"), skip brainstorming entirely

### Passing the summary forward

The `BRAINSTORM_SUMMARY` is injected into the **ralph-planner** prompt alongside learnings and workspace rules. This ensures the planner decomposes based on the *explored, confirmed intent* — not just the raw query.

---

## Phase 0: Pre-Flight Scoping (BLOCKING — second user interaction)

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

**Question 4 — Retry limit per task:**
```
question: "How many retries per task before giving up?"
header: "Max retries"
options:
  - label: "6 (default)"
    description: "3 normal attempts + debug analysis + 3 more attempts"
  - label: "4"
    description: "2 normal attempts + debug analysis + 2 more attempts"
  - label: "10"
    description: "5 normal attempts + debug analysis + 5 more attempts"
multiSelect: false
```

Store the retry limit as `MAX_RETRIES`. The debug trigger fires at `MAX_RETRIES / 2` (halfway). After `MAX_RETRIES` total attempts, auto-skip.

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
3. Dispatch **ralph-planner** with: user query + BRAINSTORM_SUMMARY + learnings + codebase context + WORKSPACE_RULES
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
debug_trigger = MAX_RETRIES / 2   # e.g. 3 if MAX_RETRIES=6

while true:
    attempt += 1

    if attempt == 1:
        failure_context = ""
    else:
        failure_context = "PREVIOUS ATTEMPT FAILED:\n{last_test_output}\n\nFix the root cause."

    if attempt == debug_trigger:
        Add to prompt: "This is attempt {debug_trigger}. You MUST write debug.md before exiting."

    Dispatch fresh ralph-worker with:
      task definition + test locations + failure_context + WORKSPACE_RULES

    Run tests via Bash: {test_command}

    if tests pass:
        break → clear debug.md if it exists

    if attempt == debug_trigger and tests still fail:
        enter Phase 2c (self-debugging)

    if attempt >= MAX_RETRIES:
        enter Phase 2c Step 4 (auto-skip)
```

### Step 2c: Validator

Run tests via Bash after each worker attempt:
- **Pass** → clear debug.md, continue to next task
- **Fail** → retry worker with failure output

---

## Phase 2c: Self-Debugging (after MAX_RETRIES/2 failed attempts)

### Step 1: debug.md already written
The worker at attempt `MAX_RETRIES/2` writes `debug.md` with all attempts so far, reasoning, and pattern analysis.

### Step 2: Fresh Debug Agent
Dispatch **ralph-debugger** — reads debug.md cold, identifies root cause, appends fix plan.

### Step 3: Fresh Worker follows fix plan
Dispatch fresh **ralph-worker** (attempts `MAX_RETRIES/2 + 1` through `MAX_RETRIES`) with debug.md. Worker follows the fix plan exactly.

Run tests again:
- **Pass** → clear debug.md, continue to next task
- **Fail after attempt MAX_RETRIES** → auto-skip (Step 4)

### Step 4: Auto-Skip (MAX_RETRIES reached, still failing)

**Do NOT ask the user.** The loop is fully autonomous after pre-flight.

1. Mark the task as **FAILED**
2. Keep the task's failure trail (attempts, debug analysis) in memory for the merger
3. Continue with remaining tasks — do not stop the loop

---

## Phase 3: Merge, Learn & Deliver

After ALL tasks complete, dispatch **ralph-merger** with:
- All task titles, statuses, attempt counts, and output directories
- Per-task notes: what worked, what failed, debug insights (passed in prompt, not in learnings.md)
- WORKSPACE_RULES

### Step 3a: Merge outputs

Merger combines outputs into `workspace/final/`, resolves integration issues.

### Step 3b: Write ONE consolidated learnings entry

The merger synthesizes all per-task insights into **a single entry** appended to `learnings.md`:

```markdown
## {date} — {original user query (shortened)}

**Result:** {passed}/{total} tasks passed ({total_attempts} total attempts)

### Key Learnings
- {insight that transfers to future runs — from any task}
- {another generalizable insight}
- {root cause from debug sessions, if any}

### Patterns to Reuse
- {architectural pattern that worked well}
- {library/tool choice that proved effective}

### Anti-Patterns to Avoid
- {approach that failed and why — only if it's a trap others would fall into}
```

**Rules for this entry:**
- Only include insights that would help a **different future query** — skip task-specific noise
- If debug mode was used, extract the root cause as a learning (the shared wrong assumption)
- Keep it concise — aim for 5-15 bullet points total, not a wall of text
- Task-specific details (individual attempt logs, test output) stay in the summary report only

### Step 3c: Clear debug.md

If debug.md was used during the run, clear it:
```
_Empty — ready for next debug session._
```

debug.md is a scratch pad. learnings.md is the permanent record.

### Step 3d: Summary report

Produce the summary report and present it to the user. The merged output in `workspace/final/` is the deliverable.
