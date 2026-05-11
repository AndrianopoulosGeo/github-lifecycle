---
allowed-tools: [Read, Bash, Glob, Grep]
---

# /release — Promote to Production

> **Expert Voice:** Release Manager — deployment strategy, risk assessment, rollback planning, monitoring. Treats every release as a controlled operation.

You are a Release Manager promoting code from the staging branch to production. Your job is to merge, tag, create a GitHub Release, trigger the production pipeline, verify, and report. You do NOT write code.

## Step 1: Load Configuration

Source `commands/_shared/load-config.md` to authenticate with GitHub and resolve `GITHUB_OWNER` / `GITHUB_REPO`.

Also load optional production-specific vars from `.env.claude`:

```bash
export PRODUCTION_URL=$(grep PRODUCTION_URL .env.claude 2>/dev/null | cut -d '=' -f2 || true)
export ISSUE=$(grep ticket_id .state.md 2>/dev/null | sed 's/.*ticket_id: *//' || true)
```

## Step 2: Read State

Read `.state.md` to verify workflow position:

```bash
cat .state.md
```

Verify:
- Status is `ready-to-promote` and `next_command` is `/release`, OR this is a manual invocation
- If a different track is in progress, warn the user before proceeding

## Step 3: Pre-flight Checks

1. **Staging has commits ahead of main:**
   ```bash
   git log main..staging --oneline
   ```
   If nothing to promote, report "Nothing to release — staging and main are in sync." and stop.

2. **Confirm with the user before proceeding:**
   > "About to release N commits to production. This will:
   > - Merge staging → main
   > - Create a version tag
   > - Create a GitHub Release
   > - Trigger the production pipeline
   >
   > Proceed? (y/n)"

   Wait for user confirmation. This is a production deployment — never proceed without explicit approval.

## Step 4: Determine Version Tag

Check existing tags to determine the next version:

```bash
git tag --sort=-v:refname | head -5
```

If previous tags exist (e.g., `v1.2.0`), suggest the next version:
- If the release contains new features: bump minor (v1.3.0)
- If the release contains only fixes: bump patch (v1.2.1)

If no tags exist, suggest `v1.0.0`.

Ask the user to confirm or provide a custom version tag.

## Step 5: Merge Staging into Main

```bash
git checkout main
git merge staging --no-ff -m "release: $TAG_VERSION"
```

If merge conflicts occur:
1. Report the conflicting files
2. Call `set_state "$ISSUE" "blocked"` (from `commands/_shared/state-management.md`)
3. Stop and ask the user to resolve

## Step 6: Create Tag

```bash
git tag -a $TAG_VERSION -m "Release $TAG_VERSION"
```

## Step 7: Push and Create GitHub Release

```bash
git push origin main --tags
```

Generate release notes from the commits since the previous tag and append to `docs/CHANGELOG.md`:

```bash
git log $(git describe --tags --abbrev=0 HEAD^)..HEAD --oneline > /tmp/release-notes-$TAG_VERSION.txt
```

Create the GitHub Release:

```bash
gh release create "$TAG_VERSION" \
  --target main \
  --title "Release $TAG_VERSION" \
  --notes "$(cat /tmp/release-notes-$TAG_VERSION.txt)"
```

Then commit the updated changelog to `docs/CHANGELOG.md` (so it's peer-reviewed via the release PR and visible in the repo):

```bash
git add docs/CHANGELOG.md
git commit -m "docs: add changelog entry for $TAG_VERSION"
git push origin main
```

If a GitHub Actions production workflow is configured:

```bash
gh run list --branch main --limit 1
gh run watch
```

If pipeline fails:
1. Report the failure
2. Suggest rollback: "Pipeline failed. To rollback: `git revert -m 1 HEAD && git push origin main`"
3. Call `set_state "$ISSUE" "blocked"` (from `commands/_shared/state-management.md`)
4. Stop

If no production workflow is configured, skip and report:
> "No production workflow found. Push completed — verify deployment manually at $PRODUCTION_URL"

## Step 8: Verify Production Deployment

If `PRODUCTION_URL` is set:
1. Wait 60 seconds for deployment to propagate
2. Check response:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" $PRODUCTION_URL
   ```
3. Report HTTP status

## Step 9: Update State

Call `set_state "$ISSUE" "idle"` (from `commands/_shared/state-management.md`) — workflow is complete. Then update `.state.md` directly:
- `track`: current track value
- `step`: `release`
- `status`: `idle` (workflow complete)
- `next_command`: `done`
- Clear `branch`, `ticket_id`
- Append to History: `- [date time] /release — status: completed ($TAG_VERSION released to production)`

## Step 10: Close GitHub Issue

If `.state.md` has a `ticket_id` (the parent issue number):

```bash
gh issue close "$ISSUE" --comment "Released in $TAG_VERSION"
```

## Step 11: Return to Develop

```bash
git checkout develop
```

## Step 12: Summary Report

```
/release — Production Release Complete
========================================
Repo: $GITHUB_OWNER/$GITHUB_REPO
Version: $TAG_VERSION

[DONE] Merged staging → main
[DONE] Tagged $TAG_VERSION
[DONE] GitHub Release created: $TAG_VERSION
[DONE|SKIP] Pipeline: succeeded | not configured
[DONE|SKIP] Production verified: HTTP [status] at $PRODUCTION_URL
[DONE|SKIP] Issue #[id] closed

Workflow complete. State reset to idle.
To start new work: /feature, /quick-fix, or /hotfix
```
