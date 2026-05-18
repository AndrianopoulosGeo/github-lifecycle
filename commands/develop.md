---
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent, Skill, TaskCreate, TaskUpdate, TaskList]
description: Execute the full feature development lifecycle — implement from plan files (auto-generated if absent), build, test, simplify, review, commit, and open a PR. Use when implementing a feature tracked as a GitHub Issue.
---

# Automated Feature Development Workflow

> **Expert Voice:** Delivery Engineer — drives a feature from plan to merged PR through quality gates.

Execute the full development lifecycle for a feature. Reads plan files (design doc + implementation plan) if they exist, or **generates them automatically** from the GitHub Issue body and sub-issue hierarchy. An outer workflow (tracked via TaskCreate/TaskUpdate) drives 10 phases.

**If `$ARGUMENTS` contains a feature issue number, use it. Otherwise, auto-detect the next feature to develop.**

## PHASE 0: CREATE ORCHESTRATION TASK LIST

**Before doing ANYTHING else**, create these 10 tasks via `TaskCreate` (no `blockedBy` — checkpoints enforce sequence). You MUST complete every task in order.

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

## PHASE 0.5: CHECKPOINT PATTERN

When you see **"CHECKPOINT N"**: mark Phase N `completed` via `TaskUpdate`, call `TaskList` to see remaining phases, mark Phase N+1 `in_progress`, and proceed immediately to the next phase.

**Never stop between phases.** If the task list shows pending phases, you are not done.

## PHASE 1: SETUP & CONTEXT LOADING

**Mark Phase 1 as `in_progress` via `TaskUpdate`.**

### 1.0 Load configuration

Source all shared fragments from `commands/_shared/`: `load-config.md` (loads `.env.claude`, resolves `GITHUB_OWNER`/`GITHUB_REPO`, verifies `gh auth status`), `github-labels.md`, `github-issues.md` (`list_sub_issues()`, `close_sub_issue()`, etc.), `state-management.md` (`set_state()`, `reconcile_state()`), `load-decisions.md` (ADR index loader). Reconcile state at startup:

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

**Display**: "Next feature to develop: #[PARENT] - [Title]" and ask for confirmation. Store `PARENT` and `FEATURE_TITLE`.

### 1.2 Fetch all sub-issues

```bash
list_sub_issues "$PARENT"
```

Outputs JSON-per-line rows of `{number, title, state}`.

### 1.3 Derive feature slug from title

```bash
SLUG="$(echo "$FEATURE_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')"
```

The feature branch will be `feature/${PARENT}-${SLUG}`.

### 1.4 Locate and read the 2 plan files

Derive `<feature-name>` from the title (kebab-case) and search for plan files from `/feature`:

```bash
ls docs/plans/<feature-name>*.md 2>/dev/null || ls -la docs/plans/*.md
```

If not found by name, ask the user to confirm from the listing. Read whatever exists:
- **Design doc**: `docs/plans/<feature-name>-design.md` — architecture, approaches, component breakdown, edge cases
- **Implementation plan**: `docs/plans/<feature-name>.md` — task-by-task TDD steps with file paths and code

**Note found vs missing — do NOT stop here.** Phase 2 handles missing plans (revalidates if present, generates the implementation plan and/or design doc if absent).

### 1.5 Load Architectural References

Read these — they MUST inform all implementation decisions:

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project conventions, code standards, test commands |
| `docs/architecture.md` | **PRIMARY reference** — component hierarchy, data flow, styling, API architecture, directory conventions |
| `docs/decisions/INDEX.md` | ADR one-line summaries. Load full ADR files only on demand per `commands/_shared/load-decisions.md`. |
| `docs/TESTING.md` | **Testing reference** — test runners, commands, file structure, mocking, E2E conventions, CI pipeline |

**Cheap-context rule:** Read `INDEX.md` first. Open a full ADR (`docs/decisions/<NNNN>-*.md`) only when the plan references it or Phase 2.5/2.6 finds a discrepancy touching a decision.

### CHECKPOINT 1

## PHASE 2: PLAN REVALIDATION & GENERATION (AUTONOMOUS)

**Ensures both plan files exist, are valid, and verified against current docs.** Runs autonomously — no user intervention unless MAJOR conflicts are found. Three scenarios: **A** both files exist → skip to 2.4; **B** design doc exists, plan missing → generate the plan from the design doc + sub-issues, then 2.4; **C** neither exists → generate both, then 2.4.

### 2.1 Generate Design Doc (only if missing — Scenario C)

Create `docs/plans/<feature-name>-design.md` by synthesizing the Feature issue body (1.1), sub-issue titles/bodies (1.2), and project context (1.5). Cover: problem statement and goal, architecture approach, component breakdown, data flow and integration points, edge cases and error handling, testing strategy overview. **Keep it concise** — synthesis of approved issues, not a brainstorming session.

### 2.2 Generate Implementation Plan (if missing — Scenarios B and C)

**Input sources (priority order):** design doc (2.1 or existing) → GitHub sub-issue bodies → project context (architecture.md patterns, component conventions) → docs/TESTING.md → Context7 docs for every library the design references.

Generate the plan at `docs/plans/<feature-name>.md` by following `commands/_shared/plan-template.md` (read it inline). Read `commands/_shared/stack-$TECH_STACK.md` alongside it for stack-specific paths and commands.

**Plan requirements:** read the actual source files referenced by sub-issues first (real line numbers, signatures, import paths); each plan task should map to one or more sub-issues.

### 2.3 Commit Generated Plan Files

If any plan files were generated, commit them: `docs(plans): add <feature-name> implementation plan` with `Refs: #${PARENT}`.

### 2.4 Autonomous Revalidation (NO user intervention)

Verify everything the plan claims against the current codebase and library docs (fixes happen in 2.5):

- **Codebase:** referenced file paths exist with accurate line ranges; function signatures unchanged; import paths valid; plan patterns match the codebase; `git log --since` on referenced files for recent changes.
- **Docs & tools:** Context7 (mandatory) `resolve-library-id` + `query-docs` for every library — flag deprecations, signature changes, new approaches. Use available MCP coding tools (language servers, `microsoft-docs` for .NET). WebSearch newer patterns for best practice, breaking changes, WCAG compliance.
- **Sub-issue alignment:** sub-issues match the plan's task breakdown; account for any added, removed, or rescoped since the plan was written.

### 2.5 Auto-Fix Discrepancies

Fix issues automatically instead of asking. For each discrepancy found in 2.4:

| Severity | Action |
|----------|--------|
| **Minor** (wrong line numbers, slight API changes, updated import paths) | Fix automatically in the plan file. No user notification needed. |
| **Medium** (deprecated API replaced with new equivalent, pattern evolved but same intent) | Fix automatically. Log the change for the Phase 2 summary. |
| **MAJOR** (architectural change, missing feature, broken core assumption, security concern) | **STOP and ask the user.** Present: what the plan assumed, what reality is, and your recommended fix. |

**After auto-fixing**, update the plan file on disk and commit: `docs(plans): revalidate <feature-name> implementation plan` with an `Auto-fixed:` body line and `Refs: #${PARENT}`.

### 2.6 Quality Evaluation (SOLID, Best Practices, Architecture)

After revalidation, evaluate the entire plan for engineering quality using MCP coding tools, WebSearch, and Context7:

- **2.6.1 SOLID:** review every component/class/module against all five SOLID principles (single responsibility, open/closed, Liskov, interface segregation, dependency inversion).
- **2.6.2 Best practices:** framework-version-recommended patterns, security (input validation, auth, injection/XSS prevention), performance anti-patterns, consistent error handling, testability.
- **2.6.3 Architecture alignment:** cross-check against `docs/architecture.md` and `docs/decisions/INDEX.md` (load a specific ADR only if a row suggests a conflict) — established patterns followed, new patterns justified/documented, directory conventions respected.

#### 2.6.4 Auto-Fix Quality Issues

For each issue found:

| Severity | Action |
|----------|--------|
| **Minor** (naming, small pattern improvements) | Fix automatically in the plan. |
| **Medium** (SOLID violation with clear fix, missing error handling) | Fix automatically. Log for summary. |
| **MAJOR** (fundamental architecture issue, security concern) | **STOP and ask the user.** |

Commit any fixes: `docs(plans): quality evaluation fixes for <feature-name>` with an `Applied:` body line and `Refs: #${PARENT}`.

### 2.7 Revalidation Summary (informational only — no gate)

Log a brief console summary: design doc title, plan task count + scope, plan source (pre-existing vs generated), auto-fixes applied, quality-evaluation issues found/fixed, SOLID compliance, major issues, libraries + MCP tools verified.

**If no MAJOR issues, proceed immediately to Phase 3. Do not wait for user input.**

### CHECKPOINT 2

## PHASE 3: ENVIRONMENT PREPARATION (WORKTREE-BASED)

**All implementation work happens in an isolated git worktree.** The main working directory stays on `develop`.

### 3.0 Ensure Docker is running

If Docker is not running, start Docker Desktop and wait until ready:

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

**Store `WORKTREE_PATH`** — all subsequent phases (4-9) execute inside it:

```bash
cd "$WORKTREE_PATH"
```

### 3.3 Install dependencies in worktree

Run the install command from `commands/_shared/stack-$TECH_STACK.md` (read it inline).

### 3.4 Verify clean baseline

Run the build, lint, and test commands from `commands/_shared/stack-$TECH_STACK.md` (read it inline). **If tests fail:** report failures, ask the user whether to proceed or investigate, and do NOT continue with a broken baseline.

### 3.5 Set Feature to "in-progress"

```bash
set_state "$PARENT" "in-progress"
```

### 3.6 Fill context with MCP coding tools

Load context before implementing: Context7 (mandatory) `resolve-library-id` + `query-docs` for every library the plan references; available MCP coding tools (language servers for types/diagnostics on files the plan touches); WebSearch for any new patterns, libraries, or integrations.

### CHECKPOINT 3

**IMPORTANT:** From here (Phases 4-9), ALL file edits, builds, tests, and commits happen inside the worktree at `$WORKTREE_PATH`; the main working directory stays untouched on `develop`.

## PHASE 4: IMPLEMENTATION

### 4.1 Implement Feature (following the implementation plan)

**Follow the implementation plan strictly** — task-by-task TDD steps with exact file paths, code, and test commands.

Iterate over sub-issues (`list_sub_issues` outputs `{number, title, state}`):

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
  # 1. Follow the plan exactly: failing test → verify fails → implement → verify passes → commit.
  # 2. Before writing code, verify with MCP tools: Context7 for API signatures,
  #    language servers for types/diagnostics, WebSearch for uncovered patterns.
  # 3. Before closing each sub-issue, verify quality: SOLID, architecture.md
  #    patterns, docs/TESTING.md test conventions, no security anti-patterns.
  # --- end per-task body ---

  close_sub_issue "$SUB_NUMBER"
  echo "  Closed sub-issue #${SUB_NUMBER}"

done < <(list_sub_issues "$PARENT")
```

`close_sub_issue` runs after each sub-issue is implemented and committed. The parent issue is NOT auto-closed here — it closes on `/release`.

### 4.2 Handle Plan Deviations

If the plan needs adjustment: note the deviation clearly. If minor (wrong line numbers, slight API differences), adapt and continue. If major (architectural change, missing feature, broken assumption), stop and ask the user before proceeding.

### 4.3 Update Acceptance Criteria

Comment the parent issue with what was delivered:

```bash
gh issue comment "$PARENT" \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --body "Implementation complete. [2-3 sentences: what was delivered, any deviation from the plan]"
```

### CHECKPOINT 4

**STOP AND VERIFY**: Call `TaskList`. Phases 5-10 must still be pending — implementation is NOT the end of the workflow.

## PHASE 5: BUILD & TEST

Run the build, lint, and test commands from `commands/_shared/stack-$TECH_STACK.md` (read it inline) as separate calls to isolate failures. Fix compilation, type, and lint errors before tests. If tests fail, analyze, fix, and re-run failing tests until all pass. Then display a summary: total tests, passed, failed, coverage (if available).

### CHECKPOINT 5

**CRITICAL — DO NOT STOP HERE.** Phases 6-10 must still be pending. The feature is NOT done. Proceed immediately to Phase 6.

## PHASE 6: CODE SIMPLIFICATION [MANDATORY QUALITY GATE]

**This phase is MANDATORY. You MUST NOT skip it. The feature is incomplete without code simplification.**

1. **Summarize context for handoff:** files created/modified, the feature's purpose and architecture decisions, known areas of complexity.
2. **Run the code simplifier** — invoke the **`Agent` tool with `subagent_type: "pr-review-toolkit:code-simplifier"`**, passing the modified-file list and feature context.
3. **Apply suggestions:** remove unnecessary complexity, improve naming/readability, ensure consistent patterns, remove dead code and unused imports.
4. **Re-run build & tests** from `commands/_shared/stack-$TECH_STACK.md` (read it inline). Fix any regressions.

### CHECKPOINT 6

## PHASE 7: PR REVIEW [MANDATORY QUALITY GATE]

**This phase is MANDATORY. You MUST NOT skip it. The feature is incomplete without PR review.**

1. **Run PR review** — invoke the **`Skill` tool with `skill: "pr-review-toolkit:review-pr"`** (code quality, security vulnerabilities, logic errors and edge cases, project-convention adherence).
2. **Apply review fixes:** fix all HIGH and MEDIUM severity issues; document why any LOW severity issues were left.
3. **Run the code simplifier again (second pass)** — invoke the **`Agent` tool with `subagent_type: "pr-review-toolkit:code-simplifier"`** so the fixes maintain code quality.
4. **Final build & test run** from `commands/_shared/stack-$TECH_STACK.md` (read it inline) one last time.

**All tests MUST pass before proceeding. Do not continue if any test fails.**

### CHECKPOINT 7

## PHASE 8: COMMIT

### 8.1 Create Commits

Invoke the **`Skill` tool with `skill: "commit"`** multiple times with targeted staging, grouping related changes into logical commits: shared types/utils/lib → components and hooks → pages and layouts → API routes → polish → tests.

`/commit` handles Conventional Commits format, AI-attribution stripping, issue references from the branch name, and auto-updating context docs (`CLAUDE.md`, `docs/architecture.md`, `docs/TESTING.md`, `docs/`).

### CHECKPOINT 8

## PHASE 9: CLOSE SUB-ISSUES & UPDATE KNOWLEDGE

### 9.1 Verify Sub-Issues Closed

Phase 4.1 should have closed all sub-issues. Confirm with `list_sub_issues "$PARENT"`. Any still-open sub-issue means a task was skipped — investigate and close it, or document why it was not completed.

### 9.2 Leave Closing Comment on Parent Issue

```bash
gh issue comment "$PARENT" \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --body "Feature implementation complete and merged to develop. $(date +%Y-%m-%d)"
```

**Do NOT close the parent issue.** It stays open until `/release` reaches `main`.

### 9.3 Update Knowledge

Update these **living architectural docs** only if the feature changed the architecture:

1. **Update `docs/architecture.md`** — only if new components, layers, or patterns were introduced.
2. **Write a new ADR** — only if implementation forced a NEW architectural decision. Follow `commands/_shared/adr-emit.md` (read it inline). Add the ADR link to the parent issue's Phase 9.2 closing comment.
3. **Update `docs/TESTING.md`** — only if new test patterns, mocks, or conventions were introduced.

If docs were changed, commit: `docs: update architecture for <feature-name>` with `Refs: #${PARENT}`.

### CHECKPOINT 9

## PHASE 10: PUSH, PR, AND CI GATE

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

Store the PR number, then set state to awaiting-review:

```bash
set_state "$PARENT" "awaiting-review"
```

### 10.3 CI Gate Loop (retry until green)

Poll the PR's check status, then act on the result:

```bash
gh pr checks "feature/${PARENT}-${SLUG}" --repo "${GITHUB_OWNER}/${GITHUB_REPO}" --watch
```

**If checks PASS** — squash-merge, sync local develop (protected — never push directly), clean up plan files, remove the worktree:

```bash
gh pr merge "feature/${PARENT}-${SLUG}" \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --squash \
  --delete-branch

cd "$(git worktree list | head -1 | awk '{print $1}')"
git fetch origin develop
git reset --hard origin/develop

rm -f docs/plans/<feature-name>-design.md docs/plans/<feature-name>.md

FLAT_BRANCH=$(echo "feature/${PARENT}-${SLUG}" | tr '/' '--')
git worktree remove ".worktrees/$FLAT_BRANCH" --force
git branch -D "feature/${PARENT}-${SLUG}"
```

**If checks FAIL** — view details, find the root cause (specific test failure, build error, or lint violation), fix in the worktree, commit, and push (re-triggers CI), then **loop back** to polling:

```bash
gh pr checks "feature/${PARENT}-${SLUG}" --repo "${GITHUB_OWNER}/${GITHUB_REPO}"
gh run view --repo "${GITHUB_OWNER}/${GITHUB_REPO}" --log-failed

cd "$WORKTREE_PATH"
git add -A && git commit -m "fix([scope]): [description of CI fix]"
git push origin "feature/${PARENT}-${SLUG}"
```

**Max retries: 3** — if CI still fails after 3 fix attempts, **STOP and ask the user**, presenting the failure history (per-attempt failing check + root-cause summary).

### 10.x Update Workflow State

```bash
set_state "$PARENT" "ready-to-promote"
```

If `.state.md` exists, update it: `step: develop`, `status: ready-to-promote`, `next_command: /staging`, `last_command: /develop`, `last_updated` to current ISO timestamp, and append to History: `- [date time] /develop — status: completed (feature merged to develop)`.

#### 10.x.1 ADR Threshold Check

Count active ADRs by source files (format-independent, safer than parsing INDEX.md):

```bash
ADR_COUNT=$(ls docs/decisions/ 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-' | wc -l | tr -d ' ')
ADR_COUNT=${ADR_COUNT:-0}
```

If `ADR_COUNT >= 15`, print a heads-up suggesting the user run `/compress-decisions` to keep index summaries tight. Do NOT auto-run.

### CHECKPOINT 10 (FINAL)

Mark Phase 10 as `completed`. Call `TaskList` to confirm ALL 10 phases are completed.

## COMPLETION

Display a summary: feature (#PARENT, title) merged to develop with parent issue still open until `/release`; plan files used and cleaned up; branch PR'd to `develop`, CI passed, squash merged, worktree removed; sub-issues closed count; plan deviations; test pass/total + coverage; code quality passes (Simplifier 2x + PR Review 1x); commits created; architectural docs updated; ADR emitted; next feature.

## WORKFLOW ENFORCEMENT RULES

1. **Task list is the source of truth.** If pending phases remain, you are not done — call `TaskList` at every checkpoint.
2. **Plan files are the implementation guide.** Follow them; Phase 2 generates them if absent. Don't reinvent the plan.
3. **Phases 6 and 7 are mandatory quality gates.** If about to commit without running them, STOP and go back.
4. **Never combine phases.** Each phase has its own checkpoint.
5. **Build + tests run 3 times minimum** — Phase 5 (initial), Phase 6 (after simplification), Phase 7 (after PR review fixes).
6. **Code Simplifier runs 2 times** — Phase 6 (first pass) and Phase 7 (after PR review fixes).
7. **Always work on a feature branch in a worktree.** Never commit directly to develop/main or switch the main working directory off `develop`.
8. **Phase 10 pushes, creates a PR, and waits for CI.** CI must pass before merge. If CI fails, fix and push (re-triggers automatically); max 3 retries before asking the user.
9. **Plan deviations must be documented** in the parent issue comment (Phase 9.2).
10. **GitHub Issues are the single source of truth.** All history, decisions, and deviations go into issue comments.
11. **Plan files are temporary.** They exist only during development; Phase 10 cleans them up after merge.
12. **Testing follows docs/TESTING.md.** All test code follows its patterns, structure, and conventions.
13. **Parent issue is NOT closed here.** Sub-issues close in Phase 4; the parent issue closes only at `/release`.

## ERROR RECOVERY

If a phase fails critically: do not skip it — stop and report to the user. Ask whether to (a) continue debugging, (b) revert that phase's changes, or (c) proceed with a documented exception. **Never proceed past a quality gate (Phase 6 or 7) with known failures.**
