---
allowed-tools: Bash, Read, Write
description: Generate a cloud-agnostic .env.infra template and a README documenting required variables
---

# /setup-infra — Cloud-agnostic env template

> **Expert Voice:** Platform Engineer — scaffolds cloud-agnostic infrastructure configuration.

Generates `.env.infra` (a placeholder env file) and `.env.infra.README.md` (a doc explaining what each variable is for and pointers to cloud-specific docs the user should consult). The user fills in the values for their cloud.

This is intentionally cloud-agnostic for v1.0.0. Cloud-specific scaffolding (`--cloud=azure|aws|gcp`) is deferred to a future minor version.

## Steps

1. Source `commands/_shared/load-config.md`.
2. Refuse to overwrite an existing `.env.infra` unless `--force` is passed.
3. Write `.env.infra`:

```bash
cat > .env.infra <<'EOF'
# Cloud / infra variables consumed by .github/workflows/* — fill in for your cloud.
# Cloud-agnostic skeleton; see .env.infra.README.md for guidance.

DEPLOY_TARGET=          # e.g. azure, aws, gcp
ENVIRONMENT_STAGING=    # logical name of the staging environment
ENVIRONMENT_PRODUCTION= # logical name of the production environment
APP_NAME=               # app/service name used by your cloud provider

# Cloud-specific credentials — set these as GitHub Actions repo secrets, NOT here.
# Examples (do not commit values):
#   AZURE: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID (use OIDC)
#   AWS:   AWS_ROLE_ARN (use OIDC)
#   GCP:   GCP_WORKLOAD_IDENTITY_PROVIDER, GCP_SERVICE_ACCOUNT (use OIDC)
EOF
```

4. Write `.env.infra.README.md` explaining:
   - Why this file is a stub (cloud-agnostic v1.0.0).
   - That cloud-specific secrets belong as `gh secret set NAME --body '...'` on the repo, not in `.env.infra`.
   - Links to GitHub Actions OIDC docs for each cloud (mention by name, do not embed external URLs — users will look them up).
5. Add `.env.infra` to `.gitignore` if not already present.
6. Print: `".env.infra and .env.infra.README.md generated. Edit and fill in for your cloud, then run /setup-pipeline to generate the workflow stubs."`
