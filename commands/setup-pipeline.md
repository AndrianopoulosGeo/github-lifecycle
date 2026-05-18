---
allowed-tools: Bash, Read, Write
description: Generate GitHub Actions workflow stubs and configure staging/production environments
---

# /setup-pipeline — GitHub Actions workflow stubs

> **Expert Voice:** CI/CD Engineer — wires up GitHub Actions workflows and environments.

Generates three workflow YAMLs under `.github/workflows/` and creates two GitHub Environments (`staging`, `production`) with required-reviewer rules on `production`.

## Steps

1. Source `commands/_shared/load-config.md` and `commands/_shared/github-labels.md`.
2. Verify `.env.infra` exists; if not, suggest `/setup-infra`.
3. Create the workflows directory: `mkdir -p .github/workflows`.

4. Write `.github/workflows/ci.yml`:

```bash
cat > .github/workflows/ci.yml <<'EOF'
name: CI
on:
  pull_request:
    branches: [main, develop, staging]
  push:
    branches: [main, develop]

jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # TODO: install your stack
      # TODO: build
      # TODO: run tests
EOF
```

5. Write `.github/workflows/deploy-staging.yml`:

```bash
cat > .github/workflows/deploy-staging.yml <<'EOF'
name: Deploy staging
on:
  push:
    branches: [staging]

permissions:
  id-token: write   # for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      # TODO: cloud auth (OIDC) — e.g. azure/login@v2, aws-actions/configure-aws-credentials@v4, google-github-actions/auth@v2
      # TODO: deploy step for your stack
EOF
```

6. Write `.github/workflows/deploy-prod.yml`:

```bash
cat > .github/workflows/deploy-prod.yml <<'EOF'
name: Deploy production
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      # TODO: cloud auth (OIDC)
      # TODO: deploy step for your stack
EOF
```

7. Create the GitHub Environments and require reviewer on production:

```bash
gh api --method PUT "repos/${GITHUB_OWNER}/${GITHUB_REPO}/environments/staging" >/dev/null

# Attempt to set required-reviewer on production (requires GitHub Pro/Team/Enterprise or a public repo).
# On free private repos this returns HTTP 422 — we create the environment without the reviewer rule and warn.
USER_ID="$(gh api user -q '.id')"
if ! gh api --method PUT "repos/${GITHUB_OWNER}/${GITHUB_REPO}/environments/production" \
     --input - <<EOF 2>/dev/null
{"reviewers":[{"type":"User","id":$USER_ID}]}
EOF
then
  gh api --method PUT "repos/${GITHUB_OWNER}/${GITHUB_REPO}/environments/production" >/dev/null
  echo "⚠ Production environment created WITHOUT required-reviewer rule (upgrade to GitHub Pro/Team/Enterprise or use a public repo to enable approval gates)."
fi
```

(For team-based approval, the user can later edit the environment to add a team reviewer; this stub seeds the repo owner as the default approver when the plan allows it.)

8. Print a summary: `"Wrote ci.yml, deploy-staging.yml, deploy-prod.yml. Created staging + production environments. Fill in TODO markers per your cloud."`
