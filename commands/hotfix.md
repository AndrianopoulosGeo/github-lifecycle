---
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent, Skill]
description: Apply an urgent production fix directly to main with TDD, then backmerge to develop. Use for critical production bugs that cannot wait for the release cycle.
---

# /hotfix — Emergency Production Fix

> **Expert Voice:** On-call SRE / DevOps — production-first mindset, minimal blast radius, systematic root cause analysis, fast and safe resolution.

You are an on-call SRE responding to a production emergency. Your priorities are: diagnose, fix, deploy, verify. Minimal ceremony — but you NEVER skip testing the fix.

**Usage:** `/hotfix <description of the production issue>`

The `$ARGUMENTS` parameter contains the issue description.

## Source Fragments

Source these helpers at the start of this command:

- `commands/_shared/load-config.md` — resolves `GITHUB_OWNER`/`GITHUB_REPO`, verifies `gh auth status`
- `commands/_shared/github-labels.md` — provides `create_canonical_labels`, `set_state_label`
- `commands/_shared/github-issues.md` — provides `create_parent_issue`
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

## Step 2: Read State & Warn

Read `.state.md` if it exists. If another workflow is in progress, warn but proceed — hotfixes take priority:

```bash
if [ -f .state.md ]; then
  CURRENT_TRACK="$(awk -F': *' '/^track:/{print $2; exit}'  .state.md)"
  CURRENT_BRANCH="$(awk -F': *' '/^branch:/{print $2; exit}' .state.md)"
fi
```

If a non-idle track is found, display:
> "Note: [track] is in progress on branch [branch]. This hotfix takes priority and will be handled separately."

Save the previous state values so they can be restored after the hotfix.

## Step 3: Create GitHub Issue

If `$ARGUMENTS` is empty, ask:
> "What's the production issue? Describe the symptoms."

Derive `HOTFIX_TITLE` (short, ≤60 chars) and `HOTFIX_BODY` from `$ARGUMENTS`.

```bash
ISSUE="$(create_parent_issue "HOTFIX: $HOTFIX_TITLE" "$HOTFIX_BODY" "type:hotfix")"
echo "Created issue #${ISSUE}: HOTFIX: ${HOTFIX_TITLE}"
set_state "$ISSUE" "in-progress"
```

## Step 4: Branch from Main

Derive `SLUG` (kebab-case, ≤40 chars) from `$HOTFIX_TITLE`.

```bash
git checkout main
git pull origin main
git checkout -b "hotfix/${ISSUE}-${SLUG}"
```

## Step 5: Update State

Update `.state.md`:

```bash
cat > .state.md <<STATEEOF
# github-lifecycle workflow state
# Edit via /feature, /develop, /quick-fix, /hotfix — do not hand-edit

track: hotfix
step: hotfix
status: in-progress
issue: ${ISSUE}
branch: hotfix/${ISSUE}-${SLUG}

## History
- [$(date '+%Y-%m-%d %H:%M')] /hotfix — status: in-progress (issue #${ISSUE} created, branch hotfix/${ISSUE}-${SLUG})
STATEEOF
```

## Step 6: Root Cause Analysis

Use the `superpowers:systematic-debugging` skill to investigate:

1. Search the codebase for the area related to the issue
2. Identify the root cause (not just the symptom)
3. Determine the minimal fix needed

Present findings to the user:
> "Root cause: [explanation]. Fix: [approach]. Files: [list]. Proceed? (y/n)"

## Step 6.5: Load Architectural Decisions

Follow `commands/_shared/load-decisions.md` (cheap path):

1. Read `docs/decisions/INDEX.md` if present.
2. Do NOT open full ADR files unless the fix touches a decision (rare for hotfixes).
3. If `adr_count >= 15`, print the threshold notice and continue.

This guarantees the fix doesn't accidentally reintroduce a rejected
alternative or violate an accepted pattern.

## Step 7: Implement Fix with Targeted Tests

1. Write a test that reproduces the bug
2. Run the test to confirm it fails
3. Implement the minimal fix — change as few lines as possible
4. Run the test to confirm it passes
5. Run the full test suite:
   ```bash
   npm test 2>&1
   ```

## Step 8: Verify Build

```bash
npm run build 2>&1
```

If build fails, fix it. A hotfix that doesn't build is worse than no fix.

## Step 9: Commit

Invoke via the **`Skill` tool with `skill: "github-lifecycle:commit"`** (or `skill: "commit"` if using the standalone commit-commands plugin) with a hint describing the hotfix:

> `/commit hotfix(<scope>): <summary of root cause and fix>`

The `/commit` skill handles: Conventional Commits format, AI-attribution stripping, issue references from the branch name, and auto-updating context management docs (`CLAUDE.md`, `docs/architecture.md`, `docs/testing.md`).

## Step 10: Open PR to Main

```bash
PR_BODY="## Summary

Emergency hotfix: ${HOTFIX_TITLE}

Closes #${ISSUE}

## Root Cause

[describe root cause]

## Fix

[describe fix approach]

## Test plan

- [ ] Reproduces the bug before fix
- [ ] Bug is resolved after fix
- [ ] Full test suite passing"

gh pr create \
  --base main \
  --head "hotfix/${ISSUE}-${SLUG}" \
  --title "hotfix: ${HOTFIX_TITLE} (#${ISSUE})" \
  --body "$PR_BODY" \
  --label "state:awaiting-review"
```

Update state:

```bash
set_state "$ISSUE" "awaiting-review"
```

## Step 11: After Main PR Merges

Once the PR is approved and merged into `main`:

```bash
git checkout main
git pull origin main
```

Determine the next patch version tag from existing tags:

```bash
git tag --sort=-v:refname | head -3
```

Create a patch version bump tag (e.g., if latest is `v1.2.0`, tag as `v1.2.1`):

```bash
git tag -a "$HOTFIX_TAG" -m "Hotfix ${HOTFIX_TAG}: ${HOTFIX_TITLE}"
git push origin main --tags
```

Create a GitHub Release:

```bash
gh release create "$HOTFIX_TAG" \
  --target main \
  --title "Hotfix ${HOTFIX_TAG}: ${HOTFIX_TITLE}" \
  --notes "Emergency fix for issue #${ISSUE}: ${HOTFIX_TITLE}"
```

## Step 12: Backmerge to Develop

This is critical — hotfixes MUST be backmerged to `develop` to prevent regression. Use a PR rather than a direct push (branch protection):

```bash
gh pr create \
  --base develop \
  --head main \
  --title "chore: backmerge hotfix #${ISSUE} to develop" \
  --body "Backmerge of hotfix #${ISSUE} (${HOTFIX_TAG}) into develop.

Hotfix: ${HOTFIX_TITLE}

If there are merge conflicts, resolve them before merging — do not skip this step."
```

If there are merge conflicts that cannot be resolved automatically, report them to the user. These MUST be resolved — do not skip this step.

## Step 13: Hotfix ADR (rare)

If the hotfix forced a NEW architectural decision (e.g., emergency switch
to a different cache backend), write an ADR using the same flow as
`/feature` Step 5.5 or `/develop` Phase 9.5:

```bash
if [ ! -d docs/decisions ] || [ ! -f docs/decisions/0000-template.md ]; then
  echo "ERROR: docs/decisions/ not scaffolded. Run /init-project first."
  exit 1
fi
LAST=$(ls docs/decisions/ 2>/dev/null | grep -E '^[0-9]{4}-' | sort | tail -1 | cut -d'-' -f1)
NEXT=$(printf "%04d" $((10#${LAST:-0} + 1)))
SLUG_ADR="<kebab-case slug from decision title>"
ADR_PATH="docs/decisions/${NEXT}-${SLUG_ADR}.md"
cp docs/decisions/0000-template.md "$ADR_PATH"
```

Then:
- Fill in the four canonical sections, with `tags: [hotfix, ...]` and a
  clear note in the Context section that the decision was made under
  emergency conditions.
- Set `feature_id: <ISSUE>` (or the incident issue number) in frontmatter.
- Run `/compress-decisions` to regenerate `docs/decisions/INDEX.md`.
- Add the ADR link to the incident issue comment.

Most hotfixes will NOT need this — only fixes that change architecture do.

## Step 14: Cleanup

```bash
git branch -d "hotfix/${ISSUE}-${SLUG}"
```

## Step 15: Verify Production

If `PRODUCTION_URL` is set in `.env.claude`:
1. Wait for deployment to complete
2. Check response:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" "$PRODUCTION_URL"
   ```
3. Report status

## Step 16: Close Issue

```bash
gh issue close "$ISSUE" --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --comment "Hotfix deployed in ${HOTFIX_TAG}. Root cause: [summary]."
```

## Step 17: Restore State

Update `.state.md`:
- If there was a previous workflow in progress, restore those values
- If not, set to idle:

```bash
set_state "$ISSUE" "idle"
```

Update flat fields in `.state.md`:

```bash
sed -i.bak -E "s/^track:.*/track: idle/"  .state.md && rm -f .state.md.bak
sed -i.bak -E "s/^step:.*/step: idle/"    .state.md && rm -f .state.md.bak
sed -i.bak -E "s/^issue:.*/issue:/"       .state.md && rm -f .state.md.bak
sed -i.bak -E "s|^branch:.*|branch:|"     .state.md && rm -f .state.md.bak
```

Append to History in `.state.md`:
```
- [YYYY-MM-DD HH:MM] /hotfix — status: completed (${HOTFIX_TAG} deployed, issue #${ISSUE} closed)
```

## Step 18: Summary

```
/hotfix — Emergency Fix Deployed
==================================
Issue:  #${ISSUE} — HOTFIX: ${HOTFIX_TITLE}
Tag:    ${HOTFIX_TAG}
Root Cause: <brief explanation>

[DONE] Fix implemented and tested
[DONE] PR merged to main + tagged ${HOTFIX_TAG}
[DONE] GitHub Release created
[DONE] Backmerge PR opened to develop (no regression)
[DONE|SKIP] Production verified: HTTP [status]
[DONE] Issue closed

Previous workflow state has been restored.
```
