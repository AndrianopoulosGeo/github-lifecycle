---
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent, Skill]
description: Implement a small fix or improvement with TDD on a fix branch. Use for bug fixes and minor changes that do not need full feature planning.
---

# /quick-fix — Fast Track Development

> **Expert Voice:** Pragmatic Developer — efficient, minimal ceremony, gets the fix done right with tests but without unnecessary overhead.

You are a pragmatic developer handling a small fix or improvement that doesn't need the full feature lifecycle. You create an issue, branch, implement with tests, get a review, and merge — all in one flow.

**Usage:** `/quick-fix <description of what needs to be fixed or improved>`

The `$ARGUMENTS` parameter contains the description of the fix.

## Source Fragments

Source these helpers at the start of this command (they provide the bash functions used below):

- `commands/_shared/load-config.md` — resolves `GITHUB_OWNER`/`GITHUB_REPO`, verifies `gh auth status`
- `commands/_shared/github-labels.md` — provides `create_canonical_labels`, `set_state_label`
- `commands/_shared/github-issues.md` — provides `create_parent_issue`, `create_sub_issue`, `list_sub_issues`, `close_sub_issue`
- `commands/_shared/state-management.md` — provides `set_state`, `reconcile_state`
- `commands/_shared/load-decisions.md` — loads `docs/decisions/INDEX.md`

## Step 1: Load Configuration

Follow `commands/_shared/load-config.md`:

```bash
if [ -f .env.claude ]; then
  set -a; . ./.env.claude; set +a
fi

if [ -z "${GITHUB_OWNER:-}" ] || [ -z "${GITHUB_REPO:-}" ]; then
  REPO_NAMEWITHOWNER="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  GITHUB_OWNER="${REPO_NAMEWITHOWNER%%/*}"
  GITHUB_REPO="${REPO_NAMEWITHOWNER##*/}"
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

export GITHUB_OWNER GITHUB_REPO
```

## Step 2: Read State

Read `.state.md` if it exists:

```bash
if [ -f .state.md ]; then
  CURRENT_TRACK="$(awk -F': *' '/^track:/{print $2; exit}'  .state.md)"
  CURRENT_BRANCH="$(awk -F': *' '/^branch:/{print $2; exit}' .state.md)"
  CURRENT_STATUS="$(awk -F': *' '/^status:/{print $2; exit}' .state.md)"
fi
```

If another track is `in-progress`, warn the user:
> "There's already a [track] in progress on branch [branch]. Continue anyway? (y/n)"

## Step 3: Create GitHub Issue

If the user didn't provide `$ARGUMENTS`, ask:
> "What needs to be fixed? Describe the issue or improvement."

Derive `FIX_TITLE` (short, ≤60 chars) and `FIX_BODY` (full description with acceptance criteria) from `$ARGUMENTS`.

```bash
ISSUE="$(create_parent_issue "$FIX_TITLE" "$FIX_BODY" "type:quickfix")"
echo "Created issue #${ISSUE}: ${FIX_TITLE}"
set_state "$ISSUE" "in-progress"
```

## Step 4: Create Branch

Derive `SLUG` (kebab-case, ≤40 chars) from `$FIX_TITLE`.

```bash
git checkout develop
git pull origin develop
git checkout -b "quick-fix/${ISSUE}-${SLUG}"
```

## Step 5: Update State

Update `.state.md`:

```bash
cat > .state.md <<STATEEOF
# github-lifecycle workflow state
# Edit via /feature, /develop, /quick-fix, /hotfix — do not hand-edit

track: quick-fix
step: quick-fix
status: in-progress
issue: ${ISSUE}
branch: quick-fix/${ISSUE}-${SLUG}

## History
- [$(date '+%Y-%m-%d %H:%M')] /quick-fix — status: in-progress (issue #${ISSUE} created, branch quick-fix/${ISSUE}-${SLUG})
STATEEOF
```

## Step 6: Investigate

Before implementing, understand the issue:

1. Search the codebase for relevant files:
   - Use Grep/Glob to find files related to the fix description
   - Read the most relevant files

2. Identify:
   - Which files need to change
   - What the expected behavior should be
   - How to test the fix

Present a brief summary to the user:
> "I'll fix [issue] by modifying [files]. The approach is [approach]. Proceed? (y/n)"

## Step 6.5: Load Architectural Decisions

Follow `commands/_shared/load-decisions.md` (cheap path):

1. Read `docs/decisions/INDEX.md` if present.
2. Do NOT open full ADR files unless the fix touches a decision (rare for quick-fixes).
3. If `adr_count >= 15`, print the threshold notice and continue.

This guarantees the fix doesn't accidentally reintroduce a rejected
alternative or violate an accepted pattern.

## Step 7: Implement with TDD

Use the `superpowers:test-driven-development` skill:

1. Write a failing test that reproduces the issue or verifies the improvement
2. Run the test to confirm it fails
3. Implement the minimal fix
4. Run tests to confirm they pass
5. Run the full test suite:
   ```bash
   npm test 2>&1
   ```

## Step 8: Verify

Use the `superpowers:verification-before-completion` skill:

1. Run build:
   ```bash
   npm run build 2>&1
   ```
2. Run all tests
3. Check for lint errors if applicable

If anything fails, fix it before proceeding.

## Step 9: Code Review

Use the `superpowers:requesting-code-review` skill to dispatch a code review subagent.

If the reviewer finds issues, fix them and re-request review.

## Step 10: Commit

Invoke via the **`Skill` tool with `skill: "github-lifecycle:commit"`** (or `skill: "commit"` if using the standalone commit-commands plugin).

The `/commit` skill handles: Conventional Commits format, AI-attribution stripping, issue references from the branch name, and auto-updating context management docs (`CLAUDE.md`, `docs/architecture.md`, `docs/testing.md`).

## Step 11: Open PR to Develop

```bash
PR_BODY="## Summary

Fix: ${FIX_TITLE}

Closes #${ISSUE}

## Changes

- [describe change 1]
- [describe change 2]

## Test plan

- [ ] Unit tests passing
- [ ] Integration tests passing"

gh pr create \
  --base develop \
  --head "quick-fix/${ISSUE}-${SLUG}" \
  --title "fix: ${FIX_TITLE} (#${ISSUE})" \
  --body "$PR_BODY" \
  --label "state:awaiting-review"
```

Update state:

```bash
set_state "$ISSUE" "awaiting-review"
```

## Step 12: After PR Merges

Once the PR is approved and merged:

```bash
git checkout develop
git pull origin develop
git branch -d "quick-fix/${ISSUE}-${SLUG}"
```

Close the issue:

```bash
gh issue close "$ISSUE" --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --comment "Fix implemented and merged to develop."
```

## Step 13: Update State

Update `.state.md` to reflect completion:

```bash
set_state "$ISSUE" "ready-to-promote"
```

Append to History in `.state.md`:
```
- [YYYY-MM-DD HH:MM] /quick-fix — status: completed (quick-fix/${ISSUE}-${SLUG} merged to develop)
```

Also update the flat fields:
```bash
sed -i.bak -E "s/^step:.*/step: quick-fix/" .state.md && rm -f .state.md.bak
sed -i.bak -E "s/^next_command:.*/next_command: \/staging/" .state.md && rm -f .state.md.bak
```

## Step 14: Summary

```
/quick-fix — Complete
======================
Issue:  #${ISSUE} — ${FIX_TITLE}
Branch: quick-fix/${ISSUE}-${SLUG} → merged to develop
Tests:  all passing
Review: approved

Next: Run /staging to promote to staging, or /next to auto-advance.
```
