---
allowed-tools: [Read, Bash, Glob, Grep]
description: Validate that .env.claude and the project environment are correctly configured. Use to diagnose configuration problems before running lifecycle commands.
---

# /validate-env — Environment Health Check

> **Expert Voice:** DevOps Auditor — methodical, checklist-driven, reports pass/fail with remediation.

You are a DevOps Auditor running a comprehensive health check on the project setup. Check every aspect of the configuration, report results clearly, and provide actionable remediation for any failures.

## Load Configuration

First, attempt to load `.env.claude`:

```bash
if [ ! -f .env.claude ]; then
  echo "[FAIL] .env.claude not found"
  echo "  → Create from template: cp ${CLAUDE_PLUGIN_ROOT:-.}/templates/.env.claude.example .env.claude"
  exit 1
fi
```

Then load all fields:

```bash
if [ -f .env.claude ]; then
  set -a; . ./.env.claude; set +a
fi

# Resolve GITHUB_OWNER / GITHUB_REPO (fall back to gh repo view)
if [ -z "${GITHUB_OWNER:-}" ] || [ -z "${GITHUB_REPO:-}" ]; then
  REPO_NAMEWITHOWNER="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  GITHUB_OWNER="${REPO_NAMEWITHOWNER%%/*}"
  GITHUB_REPO="${REPO_NAMEWITHOWNER##*/}"
fi
```

## Checks

Run ALL checks, even if earlier ones fail. Collect all results and present them together at the end. Use a `fail` counter to track failures.

```bash
fail=0
warn=0
pass=0
```

### 1. Configuration File Checks

| Check | Command | Pass | Fail |
|-------|---------|------|------|
| `.env.claude` exists | `test -f .env.claude` | [PASS] | [FAIL] → Create from template |
| `DEPLOY_TARGET` set | `test -n "$DEPLOY_TARGET"` | [PASS] | [FAIL] → Add to .env.claude |
| `TECH_STACK` set | `test -n "$TECH_STACK"` | [PASS] | [FAIL] → Add to .env.claude |

### 2. GitHub CLI Authentication

```bash
if gh auth status >/dev/null 2>&1; then
  echo "[PASS] gh CLI authenticated"
  pass=$((pass+1))
else
  echo "[FAIL] gh CLI not authenticated → Run: gh auth login"
  fail=$((fail+1))
fi
```

### 3. GitHub Repo Access

```bash
if gh repo view "${GITHUB_OWNER}/${GITHUB_REPO}" >/dev/null 2>&1; then
  echo "[PASS] Repo ${GITHUB_OWNER}/${GITHUB_REPO} accessible"
  pass=$((pass+1))
else
  echo "[FAIL] Cannot access repo ${GITHUB_OWNER}/${GITHUB_REPO} → Check GITHUB_OWNER/GITHUB_REPO in .env.claude and gh auth"
  fail=$((fail+1))
fi
```

### 4. Git Branch Checks

```bash
git branch -a
```

| Check | Pass | Fail |
|-------|------|------|
| `main` branch exists | [PASS] | [FAIL] → Run: git branch main |
| `develop` branch exists | [PASS] | [FAIL] → Run: git branch develop OR run /init-project |
| `staging` branch exists | [PASS] | [WARN] → Run: git branch staging OR run /init-project |

### 5. Canonical Labels Present

```bash
for label in type:feature type:task type:hotfix type:quickfix \
             state:in-progress state:blocked state:awaiting-review state:ready-to-promote; do
  if ! gh label list --repo "${GITHUB_OWNER}/${GITHUB_REPO}" --json name -q '.[].name' | grep -qx "$label"; then
    echo "[FAIL] MISSING label: $label  (run /init-project to create the canonical label set)" >&2
    fail=$((fail+1))
  else
    echo "[PASS] Label ${label} exists"
    pass=$((pass+1))
  fi
done
```

### 6. Branch Protection

```bash
for branch in main develop; do
  if gh api "repos/${GITHUB_OWNER}/${GITHUB_REPO}/branches/${branch}/protection" >/dev/null 2>&1; then
    echo "[PASS] Branch protection enabled on ${branch}"
    pass=$((pass+1))
  else
    echo "[WARN] MISSING branch protection on ${branch} → Run /init-project or set protection manually"
    warn=$((warn+1))
  fi
done
```

### 7. Docs Checks

| Check | Pass | Fail |
|-------|------|------|
| `docs/` exists | [PASS] | [FAIL] → Run /init-project |
| `docs/architecture.md` exists | [PASS] | [FAIL] → Run /init-project |
| `docs/decisions/INDEX.md` exists | [PASS] | [FAIL] → Run /init-project |

To check if a doc file is populated vs template, read the `status` field in the frontmatter:
- `template` = not populated
- `draft` or `reviewed` = has content

### 8. GitHub Actions Workflows

```bash
if gh workflow list --repo "${GITHUB_OWNER}/${GITHUB_REPO}" >/dev/null 2>&1; then
  WORKFLOW_COUNT=$(gh workflow list --repo "${GITHUB_OWNER}/${GITHUB_REPO}" | wc -l | tr -d ' ')
  if [ "$WORKFLOW_COUNT" -gt 0 ]; then
    echo "[PASS] GitHub Actions workflows present ($WORKFLOW_COUNT workflow(s))"
    pass=$((pass+1))
  else
    echo "[WARN] No GitHub Actions workflows found → Run /setup-pipeline to generate workflow stubs"
    warn=$((warn+1))
  fi
else
  echo "[WARN] Could not list workflows (may need Actions enabled on repo)"
  warn=$((warn+1))
fi
```

### 9. CLAUDE.md Checks

| Check | Pass | Fail |
|-------|------|------|
| `CLAUDE.md` exists | [PASS] | [FAIL] → Run /init-project |
| Docs references present | Search for "Project Docs Reference" | [WARN] → Run /init-project |

### 10. .gitignore Checks

| Check | Pass | Fail |
|-------|------|------|
| `.env.claude` is gitignored | `grep -q '.env.claude' .gitignore` | [PASS] | [WARN] → Add `.env.claude` to .gitignore to prevent secret leaks |
| `.state.md` is gitignored | `grep -q '.state.md' .gitignore` | [PASS] | [WARN] → Add `.state.md` to .gitignore |

### 11. State File Check

| Check | Pass | Fail |
|-------|------|------|
| `.state.md` exists | [PASS] | [WARN] → Run /init-project to create state file |
| `.state.md` uses flat format | `grep -q '^status:' .state.md` | [PASS] | [WARN] → Re-run /init-project to regenerate state file |

### 12. Plugin Dependency Checks

| Check | Command | Pass | Fail |
|-------|---------|------|------|
| `gh` CLI installed | `gh --version 2>/dev/null` | [PASS] | [FAIL] → Install gh CLI: https://cli.github.com |
| `superpowers` plugin | Check if superpowers skills are loadable | [PASS] | [WARN] → Install: `/plugin install superpowers@claude-plugins-official` |
| `pr-review-toolkit` plugin | Check if pr-review-toolkit skills are loadable | [PASS] | [WARN] → Install: `/plugin install pr-review-toolkit@claude-plugins-official` |
| `commit-commands` plugin | Check if commit-commands skills are loadable | [PASS] | [WARN] → Install: `/plugin install commit-commands@claude-plugins-official` |

## Output Format

Present all results in a clean table:

```
/validate-env — Environment Health Check
==========================================
Repo:    ${GITHUB_OWNER}/${GITHUB_REPO}
Target:  ${DEPLOY_TARGET} (${TECH_STACK})

Configuration
  [PASS] .env.claude exists
  [PASS] All required fields present
  [PASS] DEPLOY_TARGET=vercel (valid)
  [PASS] TECH_STACK=node (valid)

GitHub CLI
  [PASS] gh CLI authenticated
  [PASS] Repo AndrianopoulosGeo/my-app accessible

Git Branches
  [PASS] main exists
  [PASS] develop exists
  [WARN] staging missing → Run: git branch staging

Labels (8/8)
  [PASS] type:feature
  [PASS] type:task
  [PASS] type:hotfix
  [PASS] type:quickfix
  [PASS] state:in-progress
  [PASS] state:blocked
  [PASS] state:awaiting-review
  [PASS] state:ready-to-promote

Branch Protection
  [PASS] main — protection enabled
  [PASS] develop — protection enabled

Docs (5/12 populated)
  [PASS] docs/ exists
  [PASS] docs/decisions/INDEX.md exists
  [WARN] docs/api-reference.md — template (not populated)
  [WARN] docs/data-model.md — template (not populated)

GitHub Actions
  [PASS] 3 workflow(s) found

CLAUDE.md
  [PASS] CLAUDE.md exists
  [PASS] Docs references present

State
  [PASS] .state.md exists
  [PASS] Flat key:value format

Plugin Dependencies
  [PASS] gh CLI installed (v2.x.x)
  [WARN] superpowers plugin not detected → /plugin install superpowers@claude-plugins-official
  [WARN] pr-review-toolkit plugin not detected → /plugin install pr-review-toolkit@claude-plugins-official

Security
  [PASS] .env.claude is gitignored
  [PASS] .state.md is gitignored

==========================================
Result: 18 PASS | 0 FAIL | 5 WARN

Action Required:
  1. [WARN] Create staging branch: git branch staging
  2. [WARN] Populate docs sections: docs/api-reference.md, docs/data-model.md
```

If all checks pass, end with:
```
All checks passed. Environment is ready for development.
```
