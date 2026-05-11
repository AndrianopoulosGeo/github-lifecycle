# GitHub Lifecycle

Full development lifecycle automation with GitHub — feature planning, TDD, staging, release, hotfix, docs and ADRs with Gitflow (`main` + `develop`).

## Installation

```bash
# Add the marketplace
/plugin marketplace add AndrianopoulosGeo/claude-marketplace

# Install the plugin
/plugin install github-lifecycle@pgsquare
```

## Prerequisites

- **`gh` CLI** authenticated (`gh auth status`)
- **`superpowers` plugin** (`/plugin install superpowers@claude-plugins-official`)
- **`pr-review-toolkit` plugin** (`/plugin install pr-review-toolkit@claude-plugins-official`)
- **`commit-commands` plugin** (`/plugin install commit-commands@claude-plugins-official`)
- Git with Gitflow branching (`main`, `develop`, `staging`)

## Quick start

```
/init-project       # bootstrap .env.claude, labels, /docs, branch protection
/feature            # plan a new feature (creates parent Issue + sub-issues)
/develop            # TDD implementation, opens PR to develop
/staging            # promote develop → staging
/release            # promote staging → main + create GitHub Release
```

For hotfixes: `/hotfix` (branches off `main`, backmerges to `develop`).
For small fixes: `/quick-fix` (branches off `develop`).

See [INSTALLATION.md](./INSTALLATION.md) for the long version.

## License

MIT — see [LICENSE](./LICENSE).
