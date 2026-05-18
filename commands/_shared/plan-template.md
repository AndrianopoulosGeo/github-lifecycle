## Shared: Implementation Plan Template

> Used by: `/feature` Step 6, `/develop` Phase 2. Read inline alongside
> `_shared/stack-<TECH_STACK>.md` — this file gives the structure, the stack
> fragment gives the stack-specific commands and paths.

Write the implementation plan to `docs/plans/<feature-name>.md`. Assume the
implementing engineer has zero codebase context — document everything.

### Plan Header (REQUIRED)

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** [One sentence]

**Architecture:** [2-3 sentences — component structure, data flow]

**Tech Stack:** [the tech-stack line from _shared/stack-<TECH_STACK>.md]

**Design Doc:** `docs/plans/<feature-name>-design.md`

**Testing Reference:** `docs/TESTING.md`

**Library Versions Verified:** [libraries + versions confirmed via Context7]

---
```

### Task Structure

Each task follows TDD with bite-sized steps:

```markdown
### Task N: [Component Name]

**Files:**
- Create: [exact path — use the directory conventions from the stack fragment]
- Test: [exact test path — use the test conventions from the stack fragment]

**Step 1: Write the failing test**
[Complete test code — follow patterns from docs/TESTING.md]

**Step 2: Run test to verify it fails**
Run: [test command from _shared/stack-<TECH_STACK>.md]
Expected: FAIL with "[reason]"

**Step 3: Write minimal implementation**
[Complete implementation code]

**Step 4: Run test to verify it passes**
Run: [test command from _shared/stack-<TECH_STACK>.md]
Expected: PASS

**Step 5: Commit**
[exact git commands]
```

### Plan Requirements

- **Exact file paths** matching the directory conventions in the stack fragment
- **Complete code** in the plan (not "add validation" — show the actual code)
- **Dependency order:** shared utils/types → components → pages → API routes → polish
- **DRY, YAGNI, TDD** — frequent commits
- **Testing follows `docs/TESTING.md`** and the stack fragment's test conventions
- **Verified APIs:** all library usage must match docs fetched during context gathering — no guessing deprecated or non-existent methods
