---
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

# /init-project — Project Bootstrap

> **Expert Voice:** Platform Engineer — scaffolds infrastructure, ensures standards, sets up automation.

You are a Platform Engineer bootstrapping a new project for the GitHub lifecycle. Your job is to detect or gather configuration, create `.env.claude`, set up labels, docs, branch protection, and everything the team needs to use the github-lifecycle commands.

## Prerequisites

Before starting, verify:
1. Git is initialized in this directory
2. The `gh` CLI is installed and authenticated (`gh auth status`)

If any prerequisite is missing, stop and provide clear instructions to fix it.

## Step 1: Create or Load `.env.claude`

### If `.env.claude` already exists:

Load all configuration from it:

```bash
if [ -f .env.claude ]; then
  set -a; . ./.env.claude; set +a
fi
```

Validate required fields. If any are missing, proceed to the auto-detection flow below.

### If `.env.claude` does NOT exist — Auto-Detect and Ask:

#### 1.1 Detect `GITHUB_OWNER` and `GITHUB_REPO` from git remote

```bash
REPO_NAMEWITHOWNER="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
if [ -n "$REPO_NAMEWITHOWNER" ]; then
  GITHUB_OWNER="${REPO_NAMEWITHOWNER%%/*}"
  GITHUB_REPO="${REPO_NAMEWITHOWNER##*/}"
fi
```

If detected, present to the user for confirmation:
> "Detected GitHub repo: `[owner]/[repo]`. Is this correct? (y/n)"

If not detected or user says no, ask:
> "Enter your GitHub username or organization name:"
> "Enter your GitHub repository name:"

#### 1.2 Detect `TECH_STACK` from project files

Check for these files in order:
- `package.json` exists AND contains `"next"` in dependencies → `nextjs`
- `*.csproj` or `*.sln` exists → `dotnet`
- `pyproject.toml` or `requirements.txt` or `setup.py` exists → `python`
- `go.mod` exists → `go`

If detected, present to the user:
> "Detected tech stack: `nextjs` (found Next.js in package.json). Is this correct? (y/n)"

If not detected or user says no, ask:
> "What is your tech stack? Options: `nextjs` | `node` | `dotnet` | `python` | `go` | other"

#### 1.3 Ask for values that cannot be auto-detected

Ask the user for each of these:

1. **`DEPLOY_TARGET`** (required):
   > "Where do you deploy? (e.g., vercel, hetzner, aws, gcp, fly.io, render — or enter your own)"

2. **`STAGING_URL`** (optional):
   > "Enter your staging environment URL (or press Enter to skip):"

3. **`PRODUCTION_URL`** (optional):
   > "Enter your production environment URL (or press Enter to skip):"

#### 1.4 Write `.env.claude`

Generate the file with all values (detected + user-provided). No PAT is needed — `gh` CLI handles auth.

```
# GitHub
GITHUB_OWNER=<detected or entered>
GITHUB_REPO=<detected or entered>

# Project
DEPLOY_TARGET=<entered by user>
TECH_STACK=<detected or entered>

# URLs (optional)
STAGING_URL=<entered or empty>
PRODUCTION_URL=<entered or empty>

# (no GITHUB_PAT — gh CLI handles auth)
```

#### 1.5 Confirm with user

Display the generated `.env.claude` contents and ask:
> "Here's your configuration. Look correct? (y/n)"

If no, let them edit specific fields. Then load all values into environment variables.

## Step 2: Verify GitHub CLI Auth

```bash
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

gh repo view "${GITHUB_OWNER}/${GITHUB_REPO}" >/dev/null 2>&1 || {
  echo "ERROR: Cannot access repo ${GITHUB_OWNER}/${GITHUB_REPO}. Check GITHUB_OWNER/GITHUB_REPO and your gh auth." >&2
  exit 1
}
echo "[PASS] GitHub connection verified: ${GITHUB_OWNER}/${GITHUB_REPO}"
```

## Step 2.5: Ensure `.env.claude` is Gitignored

`.env.claude` must NOT be committed.

```bash
# Secrets
git check-ignore -q .env.claude 2>/dev/null || echo ".env.claude" >> .gitignore

# Plugin state file (not a secret, but no value tracking it)
git check-ignore -q .state.md 2>/dev/null || echo ".state.md" >> .gitignore
```

## Step 2.6: Configure Local Project Settings

Create `.claude/settings.local.json` with the required settings for this project:

```bash
mkdir -p .claude
```

Write `.claude/settings.local.json`:

```json
{
  "defaultMode": "bypassPermissions",
  "outputStyle": "Explanatory"
}
```

If the file already exists, read it and merge the settings (preserve any existing keys, only add/overwrite `defaultMode` and `outputStyle`).

## Step 3: Create Git Branches

Check which branches exist and create any that are missing:

```bash
# Check existing branches
git branch -a

# Create develop if missing (via GitHub API to avoid local push issues)
if ! gh api "repos/${GITHUB_OWNER}/${GITHUB_REPO}/branches/develop" >/dev/null 2>&1; then
  git checkout main && git pull && git checkout -b develop && git push -u origin develop
  echo "[DONE] Created 'develop' branch"
else
  echo "[SKIP] 'develop' branch already exists"
fi

# Create staging if missing
if ! gh api "repos/${GITHUB_OWNER}/${GITHUB_REPO}/branches/staging" >/dev/null 2>&1; then
  git checkout develop && git checkout -b staging && git push -u origin staging
  echo "[DONE] Created 'staging' branch"
else
  echo "[SKIP] 'staging' branch already exists"
fi
```

## Step 4: Bootstrap Label Taxonomy

Source `commands/_shared/github-labels.md` and create all canonical labels. This is idempotent — safe to run on an existing repo.

```bash
create_canonical_labels
echo "[DONE] Canonical labels created (type:feature, type:task, type:hotfix, type:quickfix, state:*)"
```

## Step 5: Configure Branch Protection

Require PRs on `main` and `develop` before merging:

```bash
for branch in main develop; do
  gh api --method PUT "repos/${GITHUB_OWNER}/${GITHUB_REPO}/branches/${branch}/protection" \
    -F required_pull_request_reviews.required_approving_review_count=1 \
    -F required_status_checks=null \
    -F enforce_admins=true \
    -F restrictions=null \
  && echo "[DONE] Branch protection set on ${branch}" \
  || echo "[WARN] Could not set branch protection on ${branch} — you may need admin rights"
done
```

## Step 6: Scaffold Docs

Copy `templates/docs/` from the plugin installation root to `./docs/`. The following files are created (template placeholders replaced with values from `.env.claude`):

```
docs/README.md
docs/architecture.md
docs/api-reference.md
docs/configuration.md
docs/conventions.md
docs/data-model.md
docs/deployment.md
docs/services.md
docs/testing.md
docs/decisions/0000-template.md
docs/decisions/INDEX.md
docs/decisions/README.md
```

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
DOCS_TEMPLATE="${PLUGIN_ROOT}/templates/docs"

if [ -d "$DOCS_TEMPLATE" ]; then
  if [ -d docs ] && [ "$(ls -A docs 2>/dev/null)" ]; then
    echo "docs/ already exists and has content. Overwrite with plugin templates? (y/n)"
    # Wait for user confirmation before proceeding
  fi
  cp -r "$DOCS_TEMPLATE/." ./docs/
  TODAY=$(date +%Y-%m-%d)
  # Replace placeholders in all copied files
  for f in $(find docs -name '*.md'); do
    sed -i.bak \
      -e "s/{{GITHUB_OWNER}}/${GITHUB_OWNER}/g" \
      -e "s/{{GITHUB_REPO}}/${GITHUB_REPO}/g" \
      -e "s/{{TECH_STACK}}/${TECH_STACK}/g" \
      -e "s/{{DEPLOY_TARGET}}/${DEPLOY_TARGET}/g" \
      -e "s/{{STAGING_URL}}/${STAGING_URL:-}/g" \
      -e "s/{{PRODUCTION_URL}}/${PRODUCTION_URL:-}/g" \
      -e "s/{{DATE}}/$TODAY/g" \
      "$f" && rm -f "${f}.bak"
  done
  echo "[DONE] docs/ scaffold created (12 files)"
else
  echo "[WARN] templates/docs/ not found at ${DOCS_TEMPLATE} — skipping docs scaffold (Phase 5 will create templates)"
  mkdir -p docs/decisions
fi
```

> **Note:** `templates/docs/` is created in Phase 5. Until then, the bash above degrades gracefully and creates the folder manually.

### 6.1 Scaffold the Decisions Subfolder

If `docs/decisions/` already contains files, check whether they have been modified before overwriting:

```bash
NEEDS_PROMPT=0
for f in INDEX.md README.md 0000-template.md; do
  LOCAL="docs/decisions/$f"
  SOURCE="${CLAUDE_PLUGIN_ROOT:-.}/templates/docs/decisions/$f"
  if [ -f "$LOCAL" ]; then
    if [ "$f" = "INDEX.md" ] && ! grep -q "^status: template" "$LOCAL" 2>/dev/null; then
      NEEDS_PROMPT=1
    fi
    if [ "$f" != "INDEX.md" ] && [ -f "$SOURCE" ] && ! cmp -s "$SOURCE" "$LOCAL"; then
      NEEDS_PROMPT=1
    fi
  fi
done
```

If `NEEDS_PROMPT=1`, ask the user:
> "Decisions files in `docs/decisions/` appear to have local content. Overwrite with plugin templates? (y/n)"

> **Note on re-runs:** `INDEX.md` should normally be regenerated via `/compress-decisions` rather than this scaffolding flow.

## Step 7: Update CLAUDE.md

Read the `${CLAUDE_PLUGIN_ROOT:-.}/templates/claude-md-docs-block.md` template and append it to the project's `CLAUDE.md`.

1. Check if `CLAUDE.md` exists — if not, create it with a basic header first
2. Check if the docs reference block already exists (search for "## Project Docs Reference") — if so, skip
3. Append the docs reference block to the end of `CLAUDE.md`

## Step 8: Initialize State File

Write the canonical `.state.md` to the repository root with all fields at their default idle values:

```bash
cat > .state.md <<'STATEEOF'
# github-lifecycle workflow state
# Edit via /feature, /develop, /quick-fix, /hotfix — do not hand-edit

track: idle
step: idle
status: idle
issue:
branch:

## History
STATEEOF
echo "[DONE] .state.md initialized (flat key:value format)"
```

## Step 9: Summary Report

```
/init-project completed:
========================

Repo:    ${GITHUB_OWNER}/${GITHUB_REPO}
Target:  ${DEPLOY_TARGET} (${TECH_STACK})

[DONE] GitHub connection verified
[DONE] Branch 'develop' — existed | created
[DONE] Branch 'staging' — existed | created
[DONE] Canonical labels created (8 labels: type:* + state:*)
[DONE] Branch protection on main and develop
[DONE] docs/ scaffold created (12 files incl. docs/decisions/)
[DONE] .state.md initialized
[TODO] Run /setup-pipeline to generate CI/CD workflow stubs
[DONE] CLAUDE.md updated with docs references
[DONE] Settings configured (bypassPermissions, Explanatory output)
[DONE] .gitignore updated

Next steps:
1. Run /validate-env to verify everything is correct
2. Populate docs/ sections (start with docs/architecture.md)
3. Run /setup-pipeline to generate GitHub Actions workflow stubs
4. Start developing with /feature or /quick-fix
```

## Step 10: Commit

```bash
git add docs/ CLAUDE.md .claude/settings.local.json .gitignore
git commit -m "chore: bootstrap project with init-project (docs, labels, settings, CLAUDE.md)"
```

## Step 11: Invoke /setup-pipeline

After committing the bootstrap files, invoke `/setup-pipeline` to generate GitHub Actions workflow stubs (`.github/workflows/ci.yml`, `deploy-staging.yml`, `deploy-prod.yml`) with TODO markers for the user's cloud auth.
