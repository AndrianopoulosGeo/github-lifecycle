---
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent, Skill, TaskCreate, TaskUpdate, TaskList]
---

# Automated Feature Development Workflow

Execute the full development lifecycle for a feature. This command reads plan files (design doc + implementation plan) if they exist, or **generates them automatically** from the GitHub Issue body and sub-issue hierarchy.

**This is a two-level orchestration**: an outer workflow (tracked via TaskCreate/TaskUpdate) drives 10 phases. Plan files guide implementation — they can come from `/feature` or be generated inline in Phase 2.

**If `$ARGUMENTS` contains a feature issue number, use that. Otherwise, auto-detect the next feature to develop.**

---

## PHASE 0: CREATE ORCHESTRATION TASK LIST

**Before doing ANYTHING else**, create the full workflow task list using `TaskCreate`. You MUST complete every task in order.

Create these 10 tasks (no `blockedBy` needed — the checkpoints enforce sequential execution):

| # | Subject | activeForm |
|---|---------|------------|
| 1 | Phase 1: Setup & Context Loading | Loading project context and plan files |
| 2 | Phase 2: Plan Revalidation & Generation | Validating plans, generating implementation plan if missing |
| 3 | Phase 3: Environment Preparation | Preparing branch and environment |
| 4 | Phase 4: Implementation | Implementing feature code from plan |
| 5 | Phase 5: Build & Test | Running builds and tests |
| 6 | Phase 6: Code Simplification [MANDATORY] | Running code simplifier |
| 7 | Phase 7: PR Review [MANDATORY] | Running PR review |
| 8 | Phase 8: Commit | Creating commits |
| 9 | Phase 9: Close Sub-Issues & Update Knowledge | Closing sub-issues and updating docs |
| 10 | Phase 10: Push, PR, and CI Gate | Pushing branch, creating PR, and passing CI pipeline |

**After creating all 10 tasks, call `TaskList` to confirm the full list is visible. Then proceed to Phase 1.**

---

## PHASE 0.5: CHECKPOINT PATTERN

Every phase ends with the same checkpoint pattern. When you see **"CHECKPOINT N"**, execute these steps:

1. Mark Phase N as `completed` via `TaskUpdate`
2. Call `TaskList` to see remaining phases
3. Mark Phase N+1 as `in_progress` via `TaskUpdate`
4. Proceed immediately to the next phase

**Never stop between phases.** If the task list shows pending phases, you are not done.

---

## PHASE 1: SETUP & CONTEXT LOADING

**Mark Phase 1 as `in_progress` via `TaskUpdate`.**

### 1.0 Load configuration

Source all shared fragments:

- `commands/_shared/load-config.md` — loads `.env.claude`, resolves `GITHUB_OWNER`/`GITHUB_REPO`, verifies `gh auth status`
- `commands/_shared/github-labels.md` — `create_canonical_labels()`, `set_state_label()`
- `commands/_shared/github-issues.md` — `create_parent_issue()`, `create_sub_issue()`, `list_sub_issues()`, `close_sub_issue()`
- `commands/_shared/state-management.md` — `set_state()`, `reconcile_state()`
- `commands/_shared/load-decisions.md` — ADR index loader

Reconcile state at startup:

```bash
# Read PARENT from .state.md if not provided in $ARGUMENTS
if [ -n "${ARGUMENTS:-}" ]; then
  PARENT="$ARGUMENTS"
else
  PARENT="$(awk -F': *' '/^issue:/{print $2; exit}' .state.md 2>/dev/null)"
fi
reconcile_state "$PARENT"
```

### 1.1 Fetch the target feature

If `$ARGUMENTS` contains a feature issue number, use it. Otherwise, query open `type:feature` issues and pick the oldest:

```bash
gh issue list \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --state open \
  --label "type:feature" \
  --json number,title,createdAt \
  --limit 20
```

**Display to the user**: "Next feature to develop: #[PARENT] - [Title]". Ask for confirmation before proceeding.

Store `PARENT` (the parent issue number) and `FEATURE_TITLE` for use throughout this workflow.

### 1.2 Fetch all sub-issues

```bash
list_sub_issues "$PARENT"
```

This outputs JSON-per-line rows of `{number, title, state}`. Build a list of all sub-issues that need to be implemented.

### 1.3 Derive feature slug from title

```bash
SLUG="$(echo "$FEATURE_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')"
```

The feature branch will be `feature/${PARENT}-${SLUG}`.

### 1.4 Locate and read the 2 plan files

Search for temporary working plan files created by `/feature`. Derive `<feature-name>` from the feature title (kebab-case) and search:

```bash
ls docs/plans/<feature-name>*.md 2>/dev/null
```

If not found by name, list all plan files and ask the user to confirm:

```bash
ls -la docs/plans/*.md
```

**Read whatever plan files exist:**
- **Design doc**: `docs/plans/<feature-name>-design.md` — architecture decisions, approaches, component breakdown, edge cases
- **Implementation plan**: `docs/plans/<feature-name>.md` — task-by-task TDD implementation steps with exact file paths and code

**Note what is found vs missing.** Do NOT stop here. Phase 2 will handle missing plans:
- Both files found → Phase 2 revalidates them
- Design doc found, implementation plan missing → Phase 2 generates the implementation plan
- Neither found → Phase 2 generates both from the GitHub Issue body + sub-issue hierarchy

### 1.5 Load Architectural References

Read these files — they MUST inform all implementation decisions:

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project conventions, code standards, test commands |
| `docs/architecture.md` | **PRIMARY reference** — component hierarchy, server vs client components, data flow, styling, API architecture, directory conventions |
| `docs/decisions/INDEX.md` | Architecture Decision Records — compressed one-line summary. Load full ADR files only on demand per `commands/_shared/load-decisions.md`. |
| `docs/TESTING.md` | **Testing reference** — test runners, commands, file structure, mocking patterns, E2E conventions, CI pipeline |

**Cheap-context rule:** Always read `INDEX.md` first. Open a full ADR
(`docs/decisions/<NNNN>-*.md`) only when the implementation plan
references it, or when Phase 2.5/2.6 finds a discrepancy that touches a
decision. This keeps the working context window small and reduces
hallucination risk.

### CHECKPOINT 1

---

## PHASE 2: PLAN REVALIDATION & GENERATION (AUTONOMOUS)

**This phase ensures both plan files exist, are valid, and are verified against current documentation.** It runs autonomously — no user intervention required unless MAJOR conflicts are found.

It handles three scenarios:

### Scenario A: Both plan files exist (happy path)

Skip to **2.4 Revalidate** below.

### Scenario B: Design doc exists, implementation plan missing

Generate the implementation plan from the design doc + GitHub sub-issues.

### Scenario C: Neither plan file exists

Generate both from the GitHub Issue body + sub-issue hierarchy.

---

### 2.1 Generate Design Doc (only if missing — Scenario C)

If no design doc exists, create one at `docs/plans/<feature-name>-design.md` by synthesizing:

- The **Feature issue body** from GitHub (fetched in Phase 1.1)
- The **sub-issue titles and bodies** (from Phase 1.2)
- The **project context** loaded in Phase 1.5 (architecture.md, decisions/)

The design doc should cover:
- Problem statement and goal (from the Feature issue body)
- Architecture approach (informed by architecture.md patterns)
- Component breakdown (derived from the sub-issues)
- Data flow and integration points
- Edge cases and error handling strategy
- Testing strategy overview (referencing docs/TESTING.md)

**Keep it concise** — this is a synthesis of existing approved issues, not a brainstorming session.

### 2.2 Generate Implementation Plan (if missing — Scenarios B and C)

Create the implementation plan at `docs/plans/<feature-name>.md` using the `superpowers:writing-plans` pattern.

**Input sources (in priority order):**

1. **Design doc** (from 2.1 or existing) — architecture decisions, component breakdown
2. **GitHub sub-issue bodies** — concrete implementation steps with file paths
3. **Project context** — architecture.md patterns, existing component conventions
4. **Testing reference** — docs/TESTING.md for test structure and mocking patterns
5. **Context7 library docs** — fetch up-to-date docs for libraries referenced in the design (Next.js, Framer Motion, Tailwind CSS, etc.)

**Plan structure** — follow the same format as `/feature` Step 6:

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** [One sentence]

**Architecture:** [2-3 sentences — component structure, data flow, animation approach]

**Tech Stack:** Next.js, React, Framer Motion, Tailwind CSS, TypeScript

**Design Doc:** `docs/plans/<feature-name>-design.md`

**Testing Reference:** `docs/TESTING.md`

---
```

Each task follows TDD with bite-sized steps:

```markdown
### Task N: [Component Name]

**Files:**
- Create: `src/components/[component].tsx`
- Create: `src/app/[route]/page.tsx`
- Test (unit): `src/__tests__/[component].test.tsx`
- Test (E2E): `e2e/[feature].spec.ts`

**Step 1: Write the failing test**
[Complete test code — follow patterns from docs/TESTING.md]

**Step 2: Run test to verify it fails**
Run: npm test -- [test-file]
Expected: FAIL with "[reason]"

**Step 3: Write minimal implementation**
[Complete implementation code]

**Step 4: Run test to verify it passes**
Run: npm test -- [test-file]
Expected: PASS

**Step 5: Commit**
[exact git commands]
```

**Plan requirements:**
- **Read the actual source files** referenced by sub-issues before writing plan steps — use real line numbers, real function signatures, real import paths
- **Exact file paths** matching architecture.md directory conventions
- **Complete code** in the plan (not "add validation" — show the actual code)
- **Dependency order**: shared utils/types → components → pages → API routes → animations/polish
- **Test code follows docs/TESTING.md** — Vitest for unit tests in `src/__tests__/`, Playwright for E2E in `e2e/`, mocking patterns from `src/__tests__/setup.tsx`
- **Align tasks with sub-issues** — each plan task should map to one or more sub-issues
- **DRY, YAGNI, TDD** — frequent commits

### 2.3 Commit Generated Plan Files

If any plan files were generated, commit them:

```
docs(plans): add <feature-name> implementation plan

Refs: #${PARENT}
```

### 2.4 Autonomous Revalidation (NO user intervention)

**This step runs automatically and fixes issues on its own.** The goal is to verify that EVERYTHING the plan claims is still accurate against the current codebase and current library documentation.

#### 2.4.1 Codebase Verification

Check each claim in the plan against reality:

- **File paths**: Do all referenced files exist? Are the line ranges still accurate?
- **Function signatures**: Do the functions/methods referenced in the plan still have the same signatures?
- **Import paths**: Are all import paths valid in the current codebase?
- **Existing patterns**: Do the patterns the plan follows match what the codebase currently uses? (e.g., if other components use a new pattern, the plan should too)
- **Recent changes**: Have any relevant files been modified since the plan was written? (`git log --since` on referenced files)

#### 2.4.2 Documentation & Tool Re-Verification

Re-verify all library and framework usage in the plan using **every available MCP coding tool**:

**Context7 (mandatory):** Use `resolve-library-id` + `query-docs` for every library the plan references. Cross-check that API usage matches CURRENT docs. Flag deprecated methods, changed signatures, or new recommended approaches.

**MCP coding tools (use ALL available):** Check which MCP tools are available in the session and use any relevant ones:
- Language servers (pyright-lsp, typescript-lsp, etc.) — verify type signatures, check diagnostics on referenced files
- `microsoft-docs` — for .NET API verification
- Any other coding MCP tools — use them to validate the plan's assumptions

**WebSearch (targeted):** For complex or newer patterns, verify:
- Architectural patterns are still current best practice
- No known issues or breaking changes in referenced library versions
- Accessibility patterns match current WCAG recommendations (if applicable)

#### 2.4.4 Sub-Issue Alignment

- Do the GitHub sub-issues match the implementation plan's task breakdown?
- Are there new sub-issues added since the plan was written?
- Are there sub-issues that were removed or changed scope?

### 2.5 Auto-Fix Discrepancies

**This is the key difference from the old flow: fix issues automatically instead of asking the user.**

For each discrepancy found in 2.4:

| Severity | Action |
|----------|--------|
| **Minor** (wrong line numbers, slight API changes, updated import paths) | Fix automatically in the plan file. No user notification needed. |
| **Medium** (deprecated API replaced with new equivalent, pattern evolved but same intent) | Fix automatically. Log the change for the Phase 2 summary. |
| **MAJOR** (architectural change, missing feature, broken core assumption, security concern) | **STOP and ask the user.** Present: what the plan assumed, what reality is, and your recommended fix. |

**After auto-fixing**, update the plan file on disk and commit:

```
docs(plans): revalidate <feature-name> implementation plan

Auto-fixed: [brief list of changes]
Refs: #${PARENT}
```

### 2.6 Quality Evaluation (SOLID, Best Practices, Architecture)

After revalidation and auto-fixes, evaluate the **entire implementation plan** for engineering quality. Use MCP coding tools, WebSearch, and Context7 to assess:

#### 2.6.1 SOLID Principles Check

Review every component, class, and module in the plan against SOLID:

| Principle | What to check |
|-----------|--------------|
| **Single Responsibility** | Does each component/module do one thing? Are concerns separated (data fetching vs. rendering vs. business logic)? |
| **Open/Closed** | Are components extensible without modification? Are hooks, props, or config used for variation instead of conditionals? |
| **Liskov Substitution** | Can interfaces/abstractions be swapped without breaking consumers? |
| **Interface Segregation** | Are interfaces/props lean? No component forced to depend on things it doesn't use? |
| **Dependency Inversion** | Do high-level modules depend on abstractions, not concrete implementations? |

#### 2.6.2 Best Practices Verification

Use **WebSearch** and **MCP coding tools** to verify the plan follows current best practices:

- **Framework-specific patterns**: Are we using the recommended patterns for the framework version? (e.g., Server Components vs Client Components in Next.js, async patterns in .NET, type hints in Python)
- **Security**: Input validation, auth patterns, SQL injection prevention, XSS prevention — are they handled correctly?
- **Performance**: Are there obvious performance anti-patterns? (N+1 queries, unnecessary re-renders, missing caching, unoptimized data fetching)
- **Error handling**: Is error handling consistent and appropriate? Are edge cases covered?
- **Testability**: Is the code structured for easy testing? Are dependencies injectable?

#### 2.6.3 Architecture Alignment

Cross-check the plan against `docs/architecture.md` and the ADR index
at `docs/decisions/INDEX.md` (load specific ADRs only if a row in the
index suggests a conflict with the plan):
- Does the plan follow the project's established patterns?
- If it introduces new patterns, are they justified and documented?
- Are directory conventions respected?

#### 2.6.4 Auto-Fix Quality Issues

For each issue found:

| Severity | Action |
|----------|--------|
| **Minor** (naming, small pattern improvements) | Fix automatically in the plan. |
| **Medium** (SOLID violation with clear fix, missing error handling) | Fix automatically. Log for summary. |
| **MAJOR** (fundamental architecture issue, security concern) | **STOP and ask the user.** |

Commit any fixes:

```
docs(plans): quality evaluation fixes for <feature-name>

Applied: [brief list of SOLID/best-practice improvements]
Refs: #${PARENT}
```

### 2.7 Revalidation Summary (informational only — no gate)

Log a brief summary to the console (do NOT wait for user confirmation unless MAJOR issues were found):

```
Plan Revalidation Complete:
- Design doc: [title] — [1-sentence summary]
- Implementation plan: [N tasks] covering [scope summary]
- Plan source: [pre-existing from /feature | generated in this session]
- Auto-fixes applied: [count] ([brief descriptions])
- Quality evaluation: [N issues found, M auto-fixed]
- SOLID compliance: [pass | N violations fixed]
- Major issues: [none | BLOCKED — see above]
- Library docs verified: [list of libraries checked]
- MCP tools used: [list of tools used for verification]
- Proceeding to Phase 3...
```

**If no MAJOR issues, proceed immediately to Phase 3. Do not wait for user input.**

### CHECKPOINT 2

---

## PHASE 3: ENVIRONMENT PREPARATION (WORKTREE-BASED)

**All implementation work happens in an isolated git worktree.** Your main working directory stays on `develop` so VS Code is never disrupted.

### 3.0 Ensure Docker is running

Check if Docker is running. If not, start Docker Desktop and wait for it to be ready:

```bash
docker info > /dev/null 2>&1 || echo "WARNING: Docker is not running. If the project requires Docker, start Docker Desktop before continuing."
```

### 3.1 Ensure worktree directory is git-ignored

```bash
git check-ignore -q .worktrees 2>/dev/null || echo ".worktrees/" >> .gitignore && git add .gitignore && git commit -m "chore: add .worktrees to gitignore"
```

### 3.2 Create feature branch in a worktree

```bash
git fetch origin develop
git reset --hard origin/develop
BRANCH_NAME="feature/${PARENT}-${SLUG}"
FLAT_BRANCH=$(echo "$BRANCH_NAME" | tr '/' '--')
WORKTREE_PATH=".worktrees/$FLAT_BRANCH"
git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
```

**Store the worktree path** — all subsequent phases (4 through 9) execute inside this directory:

```bash
cd "$WORKTREE_PATH"
```

### 3.3 Install dependencies in worktree

Run the appropriate install command for the project's `TECH_STACK`:
- `nextjs`: `npm install`
- `dotnet`: `dotnet restore`
- `python`: `pip install -r requirements.txt` (or equivalent)

### 3.4 Verify clean baseline

Run the appropriate build/test commands for the project's `TECH_STACK`:
- `nextjs`: `npm run build && npm run lint && npx tsc --noEmit`, then `npm test && npm run test:e2e`
- `dotnet`: `dotnet build`, then `dotnet test`
- `python`: `python -m pytest`

Or read the exact commands from the project's `CLAUDE.md`.

**If tests fail:** Report failures and ask the user whether to proceed or investigate. Do NOT continue with a broken baseline.

### 3.5 Set Feature to "in-progress"

```bash
set_state "$PARENT" "in-progress"
```

### 3.6 Fill context with MCP coding tools

Use **every available MCP coding tool** to load context before implementation:

**Context7 (mandatory):** Use `resolve-library-id` + `query-docs` to fetch up-to-date documentation for every library/framework the implementation plan references.

**MCP coding tools (use ALL available):** Check which MCP tools are available in the session and use any relevant ones:
- Language servers (pyright-lsp, typescript-lsp, etc.) — load type info, check diagnostics for files the plan will modify
- Any other coding MCP tools — use them to build implementation context

**WebSearch (targeted):** If the plan introduces patterns, libraries, or integrations not previously used in the project, search for current best practices.

### CHECKPOINT 3

**IMPORTANT:** From this point forward (Phases 4-9), ALL file edits, builds, tests, and commits happen inside the worktree at `$WORKTREE_PATH`. The main working directory remains untouched on `develop`.

---

## PHASE 4: IMPLEMENTATION

**REMINDER: All Phase 4 work happens inside the worktree directory (`$WORKTREE_PATH`), NOT the main working directory.**

### 4.1 Implement Feature (following the implementation plan)

**Follow the implementation plan from Phase 1.4 strictly.** The plan contains task-by-task TDD steps with exact file paths, code, and test commands.

Iterate over sub-issues using the helper (matches `list_sub_issues` output shape of `{number, title, state}`):

```bash
while IFS= read -r line; do
  SUB_NUMBER="$(echo "$line" | jq -r .number)"
  SUB_TITLE="$(echo "$line"  | jq -r .title)"
  SUB_STATE="$(echo "$line"  | jq -r .state)"

  # Skip already-closed sub-issues (idempotent on resume)
  if [ "$SUB_STATE" = "closed" ]; then
    echo "  Skipping #${SUB_NUMBER} (already closed): ${SUB_TITLE}"
    continue
  fi

  echo "  Implementing sub-issue #${SUB_NUMBER}: ${SUB_TITLE}"

  # --- per-task TDD loop body (preserve project-specific steps from plan) ---

  # 1. Follow the plan's steps exactly: write failing test → verify it fails
  #    → implement → verify it passes → commit

  # 2. Per-task verification with MCP tools before writing implementation code:
  #    - Use Context7 to verify API signatures you're about to use
  #    - Use language server MCP tools if available — check types, get diagnostics
  #    - Use WebSearch if the task involves a pattern not fully covered in the plan

  # 3. Verify quality before closing each sub-issue:
  #    - Components follow SOLID principles
  #    - Code follows the project's established patterns from architecture.md
  #    - Test patterns match docs/TESTING.md conventions
  #    - No security anti-patterns

  # --- end per-task body ---

  close_sub_issue "$SUB_NUMBER"
  echo "  Closed sub-issue #${SUB_NUMBER}"

done < <(list_sub_issues "$PARENT")
```

Note: `close_sub_issue` is called after each sub-issue's implementation is complete and committed. This marks the sub-issue done on GitHub. The parent issue is NOT auto-closed here — it will be closed on `/release`.

### 4.2 Handle Plan Deviations

If during implementation you discover the plan needs adjustment (wrong assumptions, missing steps, unexpected complexity):

1. Note the deviation clearly
2. If minor (wrong line numbers, slight API differences): adapt and continue
3. If major (architectural change, missing feature, broken assumption): stop and ask the user before proceeding

### 4.3 Update Acceptance Criteria

After implementation, update the parent issue with a completion comment summarizing what was delivered:

```bash
gh issue comment "$PARENT" \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --body "Implementation complete. [2-3 sentences: what was delivered, any deviation from the plan]"
```

### CHECKPOINT 4

**STOP AND VERIFY**: Call `TaskList`. You should see Phases 5, 6, 7, 8, 9, and 10 still pending. There are **6 more phases** to complete. Implementation is NOT the end of the workflow.

---

## PHASE 5: BUILD & TEST

### 5.1 Build, typecheck, and lint

Run the appropriate build/test commands for the project's `TECH_STACK` as separate calls to isolate failures:
- `nextjs`: `npm run build && npm run lint && npx tsc --noEmit`, then `npm test && npm run test:e2e`
- `dotnet`: `dotnet build`, then `dotnet test`
- `python`: `python -m pytest`

Or read the exact commands from the project's `CLAUDE.md`.

Fix any compilation errors, type errors, or lint violations before proceeding to tests.

### 5.2 Run All Tests

Run the appropriate build/test commands for the project's `TECH_STACK`:
- `nextjs`: `npm run build && npm run lint && npx tsc --noEmit`, then `npm test && npm run test:e2e`
- `dotnet`: `dotnet build`, then `dotnet test`
- `python`: `python -m pytest`

Or read the exact commands from the project's `CLAUDE.md`.

### 5.3 Fix Any Failures

If tests fail: analyze, fix, re-run failing tests, repeat until all pass.

### 5.4 Report Test Results

Display a summary: total tests, passed, failed, coverage (if available).

### CHECKPOINT 5

**CRITICAL — DO NOT STOP HERE.** You MUST see Phases 6, 7, 8, 9, and 10 still pending. The feature is NOT done. Proceed immediately to Phase 6.

---

## PHASE 6: CODE SIMPLIFICATION [MANDATORY QUALITY GATE]

**This phase is MANDATORY. You MUST NOT skip it. The feature is incomplete without code simplification.**

### 6.1 Summarize Context for Handoff

Prepare a summary of:
- Which files were created or modified in this feature
- The feature's purpose and architecture decisions
- Known areas of complexity

### 6.2 Run Code Simplifier

Invoke via the **`Agent` tool with `subagent_type: "pr-review-toolkit:code-simplifier"`**:

- Pass the list of modified files and feature context in the prompt
- The agent simplifies code for clarity, consistency, and maintainability
- It preserves all functionality while improving code quality

### 6.3 Apply Fixes

Apply suggestions from the code-simplifier. Focus on: removing unnecessary complexity, improving naming/readability, ensuring consistent patterns, removing dead code or unused imports.

### 6.4 Re-run Build & Tests

After simplification changes, verify nothing broke. Run the appropriate build/test commands for the project's `TECH_STACK`:
- `nextjs`: `npm run build && npm run lint && npx tsc --noEmit`, then `npm test && npm run test:e2e`
- `dotnet`: `dotnet build`, then `dotnet test`
- `python`: `python -m pytest`

Or read the exact commands from the project's `CLAUDE.md`.

Fix any regressions.

### CHECKPOINT 6

---

## PHASE 7: PR REVIEW [MANDATORY QUALITY GATE]

**This phase is MANDATORY. You MUST NOT skip it. The feature is incomplete without PR review.**

### 7.1 Run PR Review

Invoke via the **`Skill` tool with `skill: "pr-review-toolkit:review-pr"`**:

- Code quality and best practices
- Security vulnerabilities
- Logic errors and edge cases
- Adherence to project conventions (Next.js, Tailwind, Framer Motion patterns)

### 7.2 Apply Review Fixes

Address all HIGH and MEDIUM severity issues:

1. Fix each issue
2. Document why LOW severity issues were left (if any)

### 7.3 Run Code Simplifier Again (Second Pass)

After fixing PR review issues, invoke **`Agent` tool with `subagent_type: "pr-review-toolkit:code-simplifier"`** one more time to ensure fixes maintain code quality.

### 7.4 Final Build & Test Run

Run the complete build + test suite one last time. Run the appropriate build/test commands for the project's `TECH_STACK`:
- `nextjs`: `npm run build && npm run lint && npx tsc --noEmit`, then `npm test && npm run test:e2e`
- `dotnet`: `dotnet build`, then `dotnet test`
- `python`: `python -m pytest`

Or read the exact commands from the project's `CLAUDE.md`.

**All tests MUST pass before proceeding. Do not continue if any test fails.**

### CHECKPOINT 7

---

## PHASE 8: COMMIT

### 8.1 Create Commits

Invoke via the **`Skill` tool with `skill: "commit"`**.

Group related changes into logical commits by invoking `/commit` multiple times with targeted staging:

1. Shared types, utils, and lib
2. Components and hooks
3. Pages and layouts
4. API routes
5. Animations and polish
6. Tests

The `/commit` skill handles: Conventional Commits format, AI-attribution stripping, issue references from the branch name, and auto-updating context management docs (`CLAUDE.md`, `docs/architecture.md`, `docs/TESTING.md`, `docs/`).

### CHECKPOINT 8

---

## PHASE 9: CLOSE SUB-ISSUES & UPDATE KNOWLEDGE

### 9.1 Verify Sub-Issues Closed

All sub-issues should already be closed by the loop in Phase 4.1. Confirm with:

```bash
list_sub_issues "$PARENT"
```

Any sub-issue still open means a task was skipped — investigate and close it or document why it was not completed.

### 9.2 Leave Closing Comment on Parent Issue

Add a comment summarizing what was accomplished:

```bash
gh issue comment "$PARENT" \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --body "Feature implementation complete and merged to develop. $(date +%Y-%m-%d)"
```

**Do NOT close the parent issue.** It stays open until `/release` when the feature reaches `main`.

### 9.3 Update Knowledge

Only update these **living architectural docs** if the feature changed the architecture:

1. **Update `docs/architecture.md`** — only if new components, layers, or patterns were introduced
2. **Write a new ADR to `docs/decisions/`** — only if implementation
   forced a NEW architectural decision (e.g., the plan said "use approach A"
   but reality required approach B, and the change is non-trivial enough to
   constrain future work). Use the same number-and-template flow as
   `/feature` Step 5.5:
   - **Precondition** — verify the decisions folder is scaffolded:

     ```bash
     if [ ! -d docs/decisions ] || [ ! -f docs/decisions/0000-template.md ]; then
       echo "ERROR: docs/decisions/ not scaffolded. Run /init-project first."
       exit 1
     fi
     ```

   - Determine the next ADR number:

     ```bash
     LAST=$(ls docs/decisions/ 2>/dev/null | grep -E '^[0-9]{4}-' | sort | tail -1 | cut -d'-' -f1)
     NEXT=$(printf "%04d" $((10#${LAST:-0} + 1)))
     SLUG="<kebab-case slug from decision title>"
     ADR_PATH="docs/decisions/${NEXT}-${SLUG}.md"
     ```

   - Copy the template:

     ```bash
     cp docs/decisions/0000-template.md "$ADR_PATH"
     ```

   - Fill in the four canonical sections, `feature_id: ${PARENT}`,
     `tags`, and link in the `References` section.
   - If superseding an existing ADR, set `supersedes` on the new file and
     update the old file's `superseded_by` + `status: superseded`.
   - Run the `/compress-decisions` skill to regenerate
     `docs/decisions/INDEX.md`.
3. **Update `docs/TESTING.md`** — only if new test patterns, mocks, or conventions were introduced

### 9.4 Commit Knowledge Updates (only if docs were changed)

```
docs: update architecture for <feature-name>

Refs: #${PARENT}
```

### CHECKPOINT 9

---

## PHASE 10: PUSH, PR, AND CI GATE

**Push the feature branch, create a PR, and wait for CI to pass before completing the merge.**

### 10.1 Push feature branch to remote

From the worktree directory:

```bash
git push -u origin "feature/${PARENT}-${SLUG}"
```

### 10.2 Create PR to develop

```bash
PR_BODY="$(cat <<PRBODY
## Summary

Implements #${PARENT}: ${FEATURE_TITLE}

## Changes

[Brief description of what was implemented]

## Test plan

- [ ] All unit tests pass
- [ ] All E2E tests pass
- [ ] Code simplifier run (2x)
- [ ] PR review gates passed

Refs: #${PARENT}
PRBODY
)"

gh pr create \
  --base develop \
  --head "feature/${PARENT}-${SLUG}" \
  --title "feat: ${FEATURE_TITLE} (#${PARENT})" \
  --body "$PR_BODY" \
  --label "state:awaiting-review"
```

Store the PR number from the output for subsequent steps.

Set state to awaiting-review:

```bash
set_state "$PARENT" "awaiting-review"
```

### 10.3 CI Gate Loop (retry until green)

Poll the PR's check status. When it completes, take action based on the result.

```bash
gh pr checks "feature/${PARENT}-${SLUG}" --repo "${GITHUB_OWNER}/${GITHUB_REPO}" --watch
```

**If checks PASS:**

1. Squash and merge the PR:
   ```bash
   gh pr merge "feature/${PARENT}-${SLUG}" \
     --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
     --squash \
     --delete-branch
   ```

2. Return to main working directory and sync local develop to origin (protected branch — never push directly):
   ```bash
   cd "$(git worktree list | head -1 | awk '{print $1}')"
   git fetch origin develop
   git reset --hard origin/develop
   ```

3. Clean up temporary plan files locally (do NOT commit or push — develop is protected):
   ```bash
   rm -f docs/plans/<feature-name>-design.md docs/plans/<feature-name>.md
   ```

4. Remove worktree and delete local feature branch:
   ```bash
   FLAT_BRANCH=$(echo "feature/${PARENT}-${SLUG}" | tr '/' '--')
   git worktree remove ".worktrees/$FLAT_BRANCH" --force
   git branch -D "feature/${PARENT}-${SLUG}"
   ```

**If checks FAIL:**

1. View the failing check details:
   ```bash
   gh pr checks "feature/${PARENT}-${SLUG}" --repo "${GITHUB_OWNER}/${GITHUB_REPO}"
   gh run view --repo "${GITHUB_OWNER}/${GITHUB_REPO}" --log-failed
   ```

2. Analyze the root cause — identify the specific test failure, build error, or lint violation.

3. Fix the issue in the worktree (`$WORKTREE_PATH`).

4. Commit the fix:
   ```bash
   cd "$WORKTREE_PATH"
   git add -A && git commit -m "fix([scope]): [description of CI fix]"
   ```

5. Push to the feature branch (this updates the PR automatically and re-triggers CI):
   ```bash
   git push origin "feature/${PARENT}-${SLUG}"
   ```

6. **Loop back** to polling the check status.

**Max retries: 3** — if CI still fails after 3 fix attempts, **STOP and ask the user** for guidance. Present the failure history:
```
CI Gate — 3 attempts failed:
  Attempt 1: [failing check] — [root cause summary]
  Attempt 2: [failing check] — [root cause summary]
  Attempt 3: [failing check] — [root cause summary]

Please review and advise how to proceed.
```

### 10.x Update Workflow State

Update state after merge:

```bash
set_state "$PARENT" "ready-to-promote"
```

If `.state.md` exists, update it:
- `step`: `develop`
- `status`: `ready-to-promote`
- `next_command`: `/staging`
- `last_command`: `/develop`
- `last_updated`: current ISO timestamp
- Append to History: `- [date time] /develop — status: completed (feature merged to develop)`

#### 10.x.1 ADR Threshold Check

After updating `.state.md`, count active ADRs by counting source files (this
is format-independent and safer than parsing INDEX.md):

```bash
ADR_COUNT=$(ls docs/decisions/ 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-' | wc -l | tr -d ' ')
ADR_COUNT=${ADR_COUNT:-0}
```

If `ADR_COUNT >= 15`, print:

> "Heads-up: this project has $ADR_COUNT ADRs. Run `/compress-decisions`
>  to keep the index summaries tight and reduce context-window load."

Do NOT auto-run — let the user choose.

### CHECKPOINT 10 (FINAL)

Mark Phase 10 as `completed`. Call `TaskList` to confirm ALL 10 phases are completed.

---

## COMPLETION

Display a summary:

- **Feature**: #${PARENT} - [Title] -> Implementation merged to develop; parent issue remains open until `/release`
- **Plan files**: Used and cleaned up (GitHub Issue + sub-issue comments are the permanent record)
- **Branch**: `feature/${PARENT}-${SLUG}` -> PR to `develop`, CI passed, squash merged, worktree removed, branch deleted
- **Sub-issues closed**: [count] / [total]
- **Plan deviations**: [none / documented in GitHub Issue comments]
- **Tests**: [passed] / [total] (coverage %)
- **Code quality passes**: Code Simplifier (2x) + PR Review (1x)
- **Commits created**: [count]
- **Architectural docs updated**: [architecture.md / docs/decisions/ / TESTING.md / none]
- **ADR emitted**: [ADR-NNNN — <title> / none]
- **Next feature**: #[ID] - [Title] (or "All features complete!")

---

## WORKFLOW ENFORCEMENT RULES

1. **Task list is the source of truth.** If pending phases remain, you are not done. Always call `TaskList` at checkpoints.
2. **Plan files are the implementation guide.** Follow them. If they don't exist, Phase 2 generates them. Once generated, follow them — don't reinvent the plan.
3. **Phases 6 and 7 are mandatory quality gates.** If you find yourself about to commit without having run them, STOP and go back.
4. **Never combine phases.** Each phase has its own checkpoint.
5. **Build + tests run 3 times minimum.** Phase 5 (initial), Phase 6 (after simplification), Phase 7 (after PR review fixes).
6. **Code Simplifier runs 2 times.** Phase 6 (first pass) and Phase 7 (after PR review fixes).
7. **Always work on a feature branch in a worktree.** Never commit directly to develop/main. Never switch the main working directory away from `develop`.
8. **Phase 10 pushes, creates a PR, and waits for CI.** The feature branch is pushed to remote, a PR is created to `develop`, and CI checks must pass before the PR is merged. If CI fails, fix and push — the pipeline re-triggers automatically on the PR. Max 3 retry attempts before asking the user.
9. **Plan deviations must be documented.** If you deviate from the plan, note what changed and why in the GitHub Issue comment (Phase 9.2).
10. **GitHub Issues are the single source of truth.** All history, decisions, and deviations go into issue comments — not local files.
11. **Plan files are temporary.** They exist only during development. Phase 10 cleans them up after merge.
12. **Testing follows docs/TESTING.md.** All test code must follow the patterns, structure, and conventions documented there.
13. **Parent issue is NOT closed here.** Sub-issues are closed in Phase 4 as tasks complete. The parent issue closes only when the feature reaches `main` via `/release`.

## ERROR RECOVERY

If a phase fails critically:

1. **Do not skip the phase.** Stop and report the issue to the user.
2. **Ask the user** whether to: (a) continue debugging, (b) revert changes from that phase, or (c) proceed with a documented exception.
3. **Never proceed past a quality gate (Phase 6 or 7) with known failures.**
