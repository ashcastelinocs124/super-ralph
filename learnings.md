# Super Ralph Learnings

_No learnings yet. This file grows as Super Ralph completes runs._

### 2026-03-26 — Intent-driven judging design
- **What:** Added INTENT_PROFILE (priority/audience/lifespan) and JUDGE_RUBRIC to separate "what to build" from "how strictly to grade." The judge now adapts strictness per dimension based on user intent.
- **Why it matters:** Without this, the judge always demands production-grade quality regardless of whether the user wants a quick prototype or a ship-ready system. This caused unnecessary rejections and wasted retries.
- **Fix/Pattern:** Capture intent through direct questions to the user (they know what they want), map answers to a strictness matrix, inject the rubric into every judge dispatch. Use "highest tier from any answer" for blended profiles as a safety floor.

### 2026-03-26 — Two-tier learning system
- **What:** Replaced the single consolidated learnings entry with two tiers: (1) per-task entries written in real-time to learnings.md during execution + run summary with timing at the end, (2) per-agent learnings files (ralph-*-learnings.md) for role-specific insights.
- **Why it matters:** The old system waited until the merger to write learnings, which meant dependent tasks couldn't benefit from what earlier tasks discovered. Also, agent-specific insights (e.g., testing patterns vs debugging patterns) were being mixed together in one file.
- **Fix/Pattern:** Each task writes to learnings.md immediately after completing. Dependent tasks get prerequisite learnings injected. Each agent reads/writes its own learnings file. All entries must be generalizable, not task-specific.

### 2026-03-27 — Additive runtime compatibility beats prompt forking
- **What:** Added a runtime-compatibility mapping (Claude primitives -> Codex equivalents) directly into shared orchestration docs instead of splitting into separate Claude and Codex prompt files.
- **Why it matters:** Prompt forks drift quickly and create behavior divergence. A single source with explicit tool mapping keeps semantics aligned across runtimes.
- **Fix/Pattern:** Keep Claude wording intact, add Codex equivalents at tool-dependent points (`AskUserQuestion`, agent dispatch, parallelization, skill discovery paths), and avoid changing loop behavior.
