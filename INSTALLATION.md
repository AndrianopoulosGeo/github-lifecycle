# Installation Guide — GitHub Lifecycle

## Install via marketplace (recommended)

```bash
# In a Claude Code session:
/plugin marketplace add AndrianopoulosGeo/claude-marketplace
/plugin install github-lifecycle@pgsquare
```

Note: the marketplace is a private GitHub repo. You need `gh auth status` to show you are logged in with read access.

## Prerequisites

Before installing, make sure you have:

- **Claude Code** installed and working
- **Superpowers plugin** (`/plugin install superpowers@claude-plugins-official`)
- **`gh` CLI** authenticated (`gh auth status`)
- **GitHub** project repository
- **Git** initialized in your project

## Install from source (development)

### Step 1: Clone the Skills Repo

```bash
git clone https://github.com/AndrianopoulosGeo/github-lifecycle
```

Or if you already have it:
```bash
cd "github-lifecycle" && git pull origin main
```

### Step 2: Copy Commands to Your Project

From your project's root directory:

```bash
# Create the commands directory if it doesn't exist
mkdir -p .claude/commands/_shared

# Copy all commands
cp "/path/to/github-lifecycle/commands/"*.md .claude/commands/
cp "/path/to/github-lifecycle/commands/_shared/"*.md .claude/commands/_shared/

# Copy the state template
cp "/path/to/github-lifecycle/templates/.state.md.example" .
```

### Windows (PowerShell)

```powershell
$skills = "C:\Users\andri\Dev\github-lifecycle"

# Create directories
New-Item -ItemType Directory -Force -Path ".claude\commands\_shared"

# Copy commands
Copy-Item "$skills\commands\*.md" ".claude\commands\"
Copy-Item "$skills\commands\_shared\*.md" ".claude\commands\_shared\"

# Copy state template
Copy-Item "$skills\templates\.state.md.example" "."
```

### Quick Copy Script (Bash — works in Git Bash on Windows)

```bash
SKILLS_DIR="/c/Users/andri/Dev/github-lifecycle"
mkdir -p .claude/commands/_shared
cp "$SKILLS_DIR/commands/"*.md .claude/commands/
cp "$SKILLS_DIR/commands/_shared/"*.md .claude/commands/_shared/
cp "$SKILLS_DIR/templates/.state.md.example" .
echo "Commands installed. Run: claude then /init-project"
```

### Step 3: Create `.env.claude`

Copy the template and fill in your values:

```bash
cp "/path/to/github-lifecycle/templates/.env.claude.example" .env.claude
```

Then edit `.env.claude`:

```env
# REQUIRED — GitHub
GITHUB_OWNER=your-github-username-or-org
GITHUB_REPO=your-repo-name

# REQUIRED — Deploy target: hetzner | vercel | aws
DEPLOY_TARGET=hetzner

# REQUIRED — Tech stack: nextjs | dotnet | python
TECH_STACK=nextjs

# OPTIONAL — Environment URLs (leave empty if not set up yet)
STAGING_URL=https://staging.yourproject.com
PRODUCTION_URL=https://yourproject.com
```

### gh CLI auth

Run `gh auth login` if you are not already logged in. No PAT is stored in `.env.claude`.

### Security: Add to .gitignore

Make sure `.env.claude` is gitignored:

```bash
echo ".env.claude" >> .gitignore
```

If your `.gitignore` already has `.env*`, you're covered.

### Step 4: Run `/init-project`

Start Claude Code in your project and run:

```
/init-project
```

This will:
- Validate your `.env.claude` configuration
- Test the GitHub connection
- Create `develop` and `staging` branches (if missing)
- Scaffold `docs/` with template sections
- Generate `.github/workflows/*.yml` for your deploy target
- Update `CLAUDE.md` with docs references
- Create `.state.md` for workflow tracking

### Step 5: Verify Installation

```
/validate-env
```

You should see all checks passing:

```
/validate-env — Environment Health Check
==========================================
Project: Your Project Name
Org:     https://github.com/your-org

Configuration
  [PASS] .env.claude exists
  [PASS] All required fields present
  ...

Result: N PASS | 0 FAIL | M WARN
```

Fix any FAIL items before proceeding.

## You're Ready!

### Start a New Feature
```
/feature I want to add a user dashboard with analytics
```
Then follow the track: `/develop` → `/staging` → `/release`

Or use `/next` to auto-advance between steps.

### Quick Fix Something
```
/quick-fix the footer copyright year is wrong
```

### Emergency Production Fix
```
/hotfix the login page is returning 500 errors
```

### Check Workflow Status
```
/next
```

### Manage Documentation
```
/wiki
```

## Command Reference

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `/init-project` | Bootstrap project setup | Once per project |
| `/validate-env` | Health check | After setup or when things seem wrong |
| `/next` | Auto-advance workflow | Between pipeline steps |
| `/feature` | Plan + design + tickets | New features |
| `/develop` | 10-phase TDD implementation | After `/feature` |
| `/quick-fix` | Fast fix with ticket | Small bugs, typos, tweaks |
| `/hotfix` | Emergency production fix | Production is broken |
| `/staging` | Promote to staging | After `/develop` or `/quick-fix` |
| `/release` | Deploy to production | After `/staging` verification |
| `/wiki` | Manage project docs | Keep docs current |

## Workflow Diagram

```
Full Feature Track:
  /feature → /develop → /staging → /release
       ↓         ↓          ↓          ↓
   Plan + Design  TDD     QA + E2E   Tag + Deploy
   + Tickets    + Review  + Verify   + Verify

Quick Fix Track:
  /quick-fix → /staging → /release
       ↓           ↓          ↓
   Ticket + Fix   QA       Deploy
   + Tests

Hotfix Track (bypasses staging):
  /hotfix
     ↓
  Branch from main → Fix → Merge to main + develop → Deploy
```

## Files Created Per Project

| File | Purpose | Git? |
|------|---------|------|
| `.env.claude` | Project config | NO (gitignored) |
| `.state.md` | Workflow state tracking | YES |
| `docs/*.md` | Project documentation | YES |
| `.github/workflows/*.yml` | CI/CD pipeline | YES |
| `CLAUDE.md` | Updated with docs refs | YES |

## Updating Commands

When the github-lifecycle repo is updated:

```bash
cd "/path/to/github-lifecycle" && git pull origin main
cd "/path/to/your-project"
cp "/path/to/github-lifecycle/commands/"*.md .claude/commands/
cp "/path/to/github-lifecycle/commands/_shared/"*.md .claude/commands/_shared/
```

## Troubleshooting

### Commands not showing in Claude Code
- Verify files are in `.claude/commands/` (not `.claude/command/`)
- Restart Claude Code session (commands load at startup)

### GitHub connection fails
- Check `gh auth status` — re-run `gh auth login` if needed
- Verify GITHUB_OWNER and GITHUB_REPO values in `.env.claude`

### `/next` says "No active workflow"
- `.state.md` status is `idle` — start a workflow with `/feature`, `/quick-fix`, or `/hotfix`

### Pipeline not triggering
- Workflow must be configured in GitHub Actions to trigger on branch pushes
- Check `.github/workflows/` for the generated workflow stubs and ensure they reference the correct branches

### Docs templates not populated
- Run `/wiki` to list and review docs under `/docs/` with titles and descriptions
