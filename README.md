# Super Ralph

Autonomous agentic loop plugin for Claude Code. Give it a query, answer 4 setup questions, and walk away. It decomposes your request into tasks, writes tests first, implements with fresh sub-agents, self-debugs when stuck, and learns from every run.

## How It Works

```
You: "/super-ralph build me a REST API with auth and rate limiting"

Super Ralph:
  1. Pre-Flight ── asks 4 setup questions (workspace scope + retry limit)
  2. Plan       ── decomposes query into independent tasks with high quality bar
  3. Per Task   ── test agent writes strict tests → worker implements → tests validate
  4. Debug      ── if stuck at halfway mark, writes debug.md → fresh debugger analyzes cold → retry
  5. Learn      ── every outcome (pass or fail) logged to learnings.md
  6. Merge      ── combines all task outputs into one cohesive deliverable
  7. Deliver    ── summary report + merged output in workspace/final/
```

After pre-flight, the entire loop runs **fully autonomously** with zero user interaction. Failed tasks are auto-skipped and logged. No escalations, no confirmations, no interruptions.

---

## Architecture

### The Loop

```
User Query
  -> Pre-Flight: scope workspace + set MAX_RETRIES (only user interaction)
  -> ralph-planner: decompose into tasks (reads learnings.md first)
  -> Per Task (parallel if independent):
      -> ralph-tester: write strict tests before any code exists
      -> ralph-worker: implement until tests pass
         -> attempt 1..MAX_RETRIES/2: normal retries with failure context
         -> at MAX_RETRIES/2: worker writes debug.md (full reasoning trail)
         -> ralph-debugger: cold analysis, identifies root cause, writes fix plan
         -> attempt MAX_RETRIES/2+1..MAX_RETRIES: fresh worker follows fix plan
         -> still failing at MAX_RETRIES? auto-skip, log to learnings
      -> Pass -> capture learnings, clear debug.md
  -> ralph-merger: combine all outputs + summary report
```

### Agents

Super Ralph uses 5 specialized sub-agents, each dispatched as a fresh process with no shared context (prevents bias and sunk-cost reasoning):

| Agent | Type | Role |
|-------|------|------|
| **ralph-planner** | `opus` | Decomposes queries into tasks with strict success criteria, quality standards, and anti-patterns. Reads `learnings.md` to avoid past mistakes. Outputs JSON task array. |
| **ralph-tester** | `opus` | Writes adversarial tests before any implementation exists. Covers happy path, edge cases, and failure modes. All tests runnable with a single command. |
| **ralph-worker** | `opus` | Reads tests first, then implements production-grade code. On retries, gets failure context. At the debug trigger, writes `debug.md` with full reasoning trail. |
| **ralph-debugger** | `opus` | Cold failure analyst. Reads `debug.md` with zero bias. Identifies the shared wrong assumption across all failed attempts. Writes a concrete, step-by-step fix plan. |
| **ralph-merger** | `opus` | Combines independently-built task outputs into one cohesive deliverable. Resolves import conflicts, naming collisions, and missing glue code. Produces summary report. |

---

## Pre-Flight Setup

When you invoke Super Ralph, it asks exactly 4 questions before running autonomously:

**1. Writable directories** -- Where should it create and modify files?
- Current directory (default)
- Specific paths you list

**2. Read-only context** -- Files to read for context but never modify?
- None (figure it out)
- Specific files you list

**3. Off-limits** -- Files/folders it must never touch?
- Nothing off-limits
- Specific exclusions you list

**4. Retry limit** -- How many retries per task before auto-skipping?
- 4 (2 normal + debug + 2 more)
- 6 (3 normal + debug + 3 more) -- default
- 10 (5 normal + debug + 5 more)
- Or type any number

These answers become `WORKSPACE_RULES` injected into every sub-agent prompt. After this, the loop runs without asking anything else.

---

## Task Decomposition

The planner doesn't just split work -- it sets a quality bar. Each task includes:

```json
{
  "task_id": 1,
  "title": "User authentication endpoint",
  "description": "POST /auth/login accepting email+password, returning JWT...",
  "quality_standard": "Production-grade. Proper bcrypt hashing, constant-time comparison, token expiry...",
  "success_criteria": [
    "Returns 200 with valid JWT for correct credentials",
    "Returns 401 with JSON error body for wrong password",
    "Returns 422 for missing email field",
    "JWT expires after configured TTL"
  ],
  "anti_patterns": [
    "Don't store passwords in plaintext",
    "Don't skip input validation",
    "Don't use hardcoded secrets"
  ],
  "dependencies": [],
  "test_strategy": "pytest with httpx test client, mock database layer"
}
```

Independent tasks run in parallel. Tasks with dependencies wait.

---

## Self-Debugging

The most interesting part. When a worker fails at the halfway mark (e.g., attempt 3 of 6):

**Step 1 -- Worker writes `debug.md`**

A full reasoning trail: what was tried in each attempt, why, and what failed. Plus a pattern analysis asking "what assumption did all attempts share?"

**Step 2 -- Fresh debugger reads it cold**

A brand new agent with zero context reads `debug.md`. No ego, no sunk cost. It reads the actual tests, actual code, and actual errors. Then identifies the root cause -- not "the test failed" but "the function assumes UTC but receives local time."

**Step 3 -- Fix plan**

The debugger appends a concrete, step-by-step fix plan to `debug.md`:

```markdown
## Fix Plan

**Root cause identified:** Parser assumes single-line input but test sends multiline
**Why previous attempts failed:** All 3 used line-by-line processing
**Correct approach:** Read entire input as buffer, split on record delimiter
**Step-by-step:**
1. Replace readline() with read()
2. Split on '\n\n' (record separator)
3. Process each record as a unit
```

**Step 4 -- Fresh worker follows the plan exactly**

A new worker gets `debug.md` and follows the fix plan. If this succeeds, learnings are captured and `debug.md` is cleared. If it still fails after `MAX_RETRIES`, the task is auto-skipped and the failure trail is logged to `learnings.md`.

---

## Learning System

Two files with different purposes:

| File | Purpose | Lifecycle |
|------|---------|-----------|
| `debug.md` | Scratch pad for active debugging | Written during debug, cleared after resolution |
| `learnings.md` | Permanent memory across runs | Append-only, read by planner before every run |

After every task (pass or fail), Super Ralph appends to `learnings.md`:

```markdown
## 2026-03-07 -- JWT Authentication

**Query:** Build a REST API with auth and rate limiting
**Task:** Implement JWT token generation and validation
**Result:** pass
**Attempts:** 4

### What worked
- Used python-jose library with HS256 algorithm
- Separated token generation from validation logic

### What failed
- Attempt 1: Used PyJWT but wrong import path for decode options
- Attempt 2: Token expiry was set in seconds instead of datetime

### Patterns
- Always check library-specific parameter names for decode/verify
- Use datetime.utcnow() not datetime.now() for token timestamps
```

The planner reads this before every new run. Over time, Super Ralph avoids past mistakes and reuses successful patterns.

---

## Usage

### Slash Command

```
/super-ralph build a CLI tool that converts CSV to JSON with streaming support
```

### Natural Language

Just say "ralph this" or "break this down and build it" in any conversation.

### Examples

```
/super-ralph add user authentication with JWT, refresh tokens, and rate limiting

/super-ralph refactor the payment module into separate services with proper error handling

/super-ralph build a real-time notification system with WebSocket, email, and SMS channels

/super-ralph create a CLI that scaffolds new projects from templates with plugin support
```

---

## Install

### As a Claude Code Plugin

Clone and add to your Claude Code configuration:

```bash
git clone https://github.com/ashcastelinocs124/super-ralph.git ~/.claude/skills/super-ralph
```

### Manual

Copy the files into your `~/.claude/skills/` directory and ensure the plugin manifest is recognized by Claude Code.

---

## Project Structure

```
super-ralph/
  .claude-plugin/
    plugin.json              # Plugin manifest (name, description, version)
  commands/
    super-ralph.md           # /super-ralph slash command entry point
  skills/
    super-ralph/
      SKILL.md               # Orchestrator — the full loop logic
  agents/
    ralph-planner.md         # Task decomposition with quality bar
    ralph-tester.md          # Adversarial test-first agent
    ralph-worker.md          # Implementation agent with retry + debug.md
    ralph-debugger.md        # Cold failure analysis agent
    ralph-merger.md          # Integration and merge agent
  docs/
    plans/                   # Design docs and implementation plans
  learnings.md               # Persistent cross-run memory
  README.md                  # This file
```

---

## Design Principles

- **Fresh agents per task** -- no context pollution between tasks. Each sub-agent starts clean.
- **Test-first** -- tests are written before implementation. They define "done," not the worker's opinion.
- **Adversarial quality** -- anti-patterns in task definitions prevent common lazy shortcuts before they happen.
- **Cold debugging** -- the debugger has zero context from failed attempts. That's its superpower -- no bias.
- **One-shot autonomy** -- after 4 setup questions, zero user interaction. Failed tasks are auto-skipped, not escalated.
- **Persistent learning** -- `learnings.md` accumulates insights across runs. The planner reads it every time.
- **Configurable retry depth** -- you control how many attempts per task. Debug triggers at the halfway point.

---

## License

MIT
