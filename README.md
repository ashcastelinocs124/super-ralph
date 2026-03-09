# Super Ralph

Autonomous agentic loop plugin for Claude Code. Like the Ralph Wiggum loop, but it learns over time.

## What It Does

Super Ralph receives a user query, decomposes it into independent tasks, and dispatches fresh sub-agents to build each one using a test-first approach. When things fail, it self-debugs. When things succeed, it captures learnings for next time.

```
User Query
  -> Pre-Flight: scope workspace (what to touch, what to read, what's off-limits)
  -> Planner: decompose into tasks with high quality standards
  -> Per Task (parallel if independent):
      -> Test Agent: write strict tests first
      -> Worker Agent: implement until tests pass
      -> Fail 3x? -> debug.md -> Debug Agent -> fresh Worker
      -> Fail 6x? -> auto-skip + log to learnings
      -> Pass -> capture learnings, clear debug.md
  -> Merger: combine all outputs + summary report
```

## Agents

| Agent | Role |
|-------|------|
| **ralph-planner** | Decomposes queries into tasks with high quality bar and anti-patterns |
| **ralph-tester** | Writes adversarial tests before any implementation exists |
| **ralph-worker** | Implements until tests pass. Writes debug.md on attempt 3 |
| **ralph-debugger** | Cold analysis of failures. Reads reasoning trail with fresh eyes |
| **ralph-merger** | Combines independently-built outputs into one cohesive deliverable |

## Usage

```
/super-ralph build me a REST API with auth and rate limiting
```

Or just say "ralph this" or "break this down and build it" in any conversation.

## How It Learns

After every task (pass or fail), Super Ralph appends to `learnings.md`:
- What approach worked
- What approaches failed and why
- Reusable patterns for future runs

Before every new run, the Planner reads `learnings.md` to avoid repeating past mistakes.

## Self-Debugging

When a worker fails 3 times:
1. Worker writes `debug.md` — full reasoning trail for all 3 attempts
2. Fresh Debug Agent reads it cold (no bias, no sunk cost)
3. Debug Agent identifies root cause and writes a concrete fix plan
4. Fresh Worker follows the fix plan exactly
5. On success: learnings captured, `debug.md` cleared

## Install

Clone this repo and add it as a Claude Code plugin, or copy the files into your `~/.claude/skills/` directory.

## Structure

```
super-ralph/
  .claude-plugin/plugin.json     # Plugin manifest
  commands/super-ralph.md        # /super-ralph slash command
  skills/super-ralph/SKILL.md    # Orchestrator
  agents/                        # 5 dedicated sub-agents
  learnings.md                   # Persistent memory
```

## License

MIT
