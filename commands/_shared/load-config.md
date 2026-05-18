## Load configuration

Load `.env.claude` from the project root and verify `gh` CLI auth before any GitHub API call.

```bash
# Source .env.claude if present
if [ -f .env.claude ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env.claude
  set +a
fi

# Resolve GITHUB_OWNER / GITHUB_REPO (fall back to gh repo view)
if [ -z "${GITHUB_OWNER:-}" ] || [ -z "${GITHUB_REPO:-}" ]; then
  REPO_NAMEWITHOWNER="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  if [ -z "$REPO_NAMEWITHOWNER" ]; then
    echo "ERROR: cannot determine GitHub repo. Set GITHUB_OWNER and GITHUB_REPO in .env.claude or run inside a gh-aware git clone." >&2
    exit 1
  fi
  GITHUB_OWNER="${REPO_NAMEWITHOWNER%%/*}"
  GITHUB_REPO="${REPO_NAMEWITHOWNER##*/}"
fi

# Verify gh auth
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

export GITHUB_OWNER GITHUB_REPO
```

Every lifecycle command sources this fragment before issuing any `gh` call.

`.env.claude` may also define `PREFERRED_LANGUAGE` — the language Claude
converses in (set via `/set-language`). It is optional and defaults to English
when unset. Because the block above sources `.env.claude` wholesale,
`PREFERRED_LANGUAGE` is loaded automatically with no extra wiring.
