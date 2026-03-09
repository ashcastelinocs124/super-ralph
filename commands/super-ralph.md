---
description: "Autonomous agentic loop — decompose, test, build, debug, learn, merge"
argument-hint: "QUERY"
---

# /super-ralph

The user wants to run the Super Ralph autonomous agentic loop.

**Invoke the `super-ralph` skill immediately** with the user's query. The skill handles everything:

1. Pre-flight scoping (ask user about workspace boundaries — **only user interaction**)
2. Once user says "go ahead" → **fully autonomous from here, zero questions**
3. Decompose the query into tasks with high quality standards
4. For each task: write tests first, then implement until tests pass
5. Self-debug on failure (debug.md → cold analysis → retry)
6. Auto-skip tasks that fail after 6 attempts (log to learnings)
7. Capture learnings to learnings.md
8. Merge all outputs into a cohesive deliverable

The user's query is: ${ARGUMENTS}

**Start by invoking the super-ralph skill now.**
