---
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent, Skill]
---

Create a fully planned feature: brainstorm the design, write implementation plans, then create GitHub Issues with sub-issues. Produces 2 plan files that `/develop` consumes.

**Design mode**: When the feature involves UI/frontend work, pass `--design` or include "design" / "UI" / "frontend" / "page" / "component" in your description to activate the **Design Toolchain** — this triggers frontend-design, ui-ux-pro-max, and 21st magic MCP tools during brainstorming and planning.

---

## STEP 1: LOAD CONFIGURATION & AUTHENTICATE

Source all shared fragments:

- `commands/_shared/load-config.md` — loads `.env.claude`, resolves `GITHUB_OWNER`/`GITHUB_REPO`, verifies `gh auth status`
- `commands/_shared/github-labels.md` — `create_canonical_labels()`, `set_state_label()`
- `commands/_shared/github-issues.md` — `create_parent_issue()`, `create_sub_issue()`, `list_sub_issues()`, `close_sub_issue()`
- `commands/_shared/state-management.md` — `set_state()`, `reconcile_state()`
- `commands/_shared/load-decisions.md` — ADR index loader

---

## STEP 2: GATHER INPUT

If `$ARGUMENTS` contains a description, use it. Otherwise ask the user to describe what they want to build.

Then ask (use `AskUserQuestion` with options):

1. **Starting level**: What is the top-level issue to create?
   - Feature (breakdown: Feature > Sub-issues/Tasks)
   - Attach to existing parent (provide parent issue number)

2. **Parent issue number** (if attaching): Which existing issue should this be linked under?

3. **Priority**: 1 (Critical), 2 (High), 3 (Medium), 4 (Low) — default 2

4. **Feature type**: Is this a UI/design feature?
   - Yes — activates Design Toolchain (frontend-design, ui-ux-pro-max, 21st magic, component inspiration)
   - No — standard backend/infra/cross-cutting feature

**Auto-detect**: If `$ARGUMENTS` contains `--design`, or keywords like "design", "UI", "frontend", "page", "component", "layout", "dashboard", "form", "widget", "screen", skip this question and activate Design Toolchain automatically.

---

## STEP 3: LOAD ARCHITECTURAL REFERENCES

Read the project's **architectural and convention reference docs**. These define HOW we build — the brainstorming design MUST conform to these rules.

### 3.1 Architecture & Conventions (REQUIRED — read all)

| File | What it provides |
|------|-----------------|
| `CLAUDE.md` | Project conventions, code standards, naming rules, test commands |
| `docs/architecture.md` | **PRIMARY reference** — component hierarchy, server vs client components, data flow, styling architecture, API architecture, directory conventions |
| `docs/decisions/INDEX.md` | Architecture Decision Records — compressed one-line summary of every accepted decision. Load full ADR files (`docs/decisions/<NNNN>-*.md`) only on demand, per `commands/_shared/load-decisions.md`. |
| `docs/TESTING.md` | **Testing reference** — test runners, commands, file structure, mocking patterns, E2E conventions, CI pipeline |

> **Portability note:** These paths refer to the **target project**, not the plugin. Read whatever exists — not all projects have all files. Let `TECH_STACK` from `.env.claude` guide which config files to look for (e.g., `package.json` for nextjs, `.csproj` for dotnet, `pyproject.toml` for python).

### 3.2 Project Configuration (read for context — read whatever exists)

| File | What it provides |
|------|-----------------|
| `package.json` or `*.csproj` or `pyproject.toml` | Dependencies, scripts, tech stack |
| Framework config (`next.config.ts`, `appsettings.json`, etc.) | Framework-specific configuration |
| `tsconfig.json` | TypeScript configuration (if applicable) |
| Test config (`vitest.config.ts`, `playwright.config.ts`, etc.) | Test runner configuration (if applicable) |

### 3.3 What to extract for brainstorming

After reading these files, prepare a **concise architectural brief** covering:

- **Component rules**: Server vs. client component guidelines (from architecture.md)
- **Patterns to follow**: Styling conventions (Tailwind utilities, `cn()` helper, CSS variables), animation patterns (Framer Motion, `prefers-reduced-motion`)
- **Testing strategy**: What test types are required (unit, integration, E2E) and how they're structured (from TESTING.md)
- **Existing components**: What already exists in `src/components/` that the new feature might reuse or extend
- **Directory conventions**: Where files go (`src/app/`, `src/components/sections/`, `src/components/ui/`, `src/lib/`)
- **Data flow**: Static data in `src/lib/constants.ts`, environment variables pattern

### 3.4 Load Architectural Decisions (cheap)

Follow `commands/_shared/load-decisions.md`:

1. Read `docs/decisions/INDEX.md` if present.
2. Include the index in the architectural brief passed to brainstorming.
3. If `adr_count >= 15`, print the threshold notice and continue.
4. Do NOT read individual ADR files unless the feature challenges or
   supersedes one.

---

## STEP 4: BRAINSTORM (invoke superpowers:brainstorming)

**Invoke the `superpowers:brainstorming` skill** to run the full collaborative design flow. This skill handles:
- Exploring project context (files, docs, recent commits)
- Asking clarifying questions one at a time
- Proposing 2-3 approaches with trade-offs
- Presenting the design section by section with user approval gates
- Writing the spec to `docs/superpowers/specs/`
- Running spec review loop
- User review gate

**Pass this context to brainstorming:**
- The user's feature description from Step 2
- The **architectural brief** from Step 3.3 — so the brainstorming skill knows:
  - Which component patterns to follow (server vs. client, Tailwind, Framer Motion)
  - What tests are required and how to structure them (from TESTING.md)
  - What existing components to reuse or extend
  - Which directory conventions to follow
- Whether Design Toolchain is active (from Step 2)

The brainstorming skill should use this architectural context to:
1. **Constrain proposals** — only propose approaches that fit the existing architecture
2. **Map components to structure** — every proposed component must have a clear home (section component? UI primitive? layout component? hook?)
3. **Include test strategy** — the design must specify what test types each component needs (unit, integration, E2E)
4. **Reference existing patterns** — "this follows the same pattern as [existing component X]"

**Wait for brainstorming to complete and produce an approved spec before proceeding.**

---

## STEP 4.5: CONTEXT GATHERING (MANDATORY — always runs)

**This step runs for EVERY feature, not just UI features.** Before writing any implementation plan, gather current documentation, best practices, and tool context for all technologies the feature touches.

### 4.5.1 Fetch Library Documentation (Context7 — mandatory)

Use `resolve-library-id` + `query-docs` to fetch up-to-date documentation for **every library and framework** the feature touches. This is NOT optional — plans written without verified library docs risk using deprecated or non-existent APIs.

Examples by tech stack:
- **nextjs**: Next.js, React, Tailwind CSS, Framer Motion, any ORM (Prisma, Drizzle)
- **dotnet**: ASP.NET Core, Entity Framework, any NuGet packages the feature introduces
- **python**: FastAPI/Django/Flask, SQLAlchemy, any pip packages the feature introduces
- Any new libraries the feature introduces regardless of stack

### 4.5.2 Best Practices Research (WebSearch — targeted)

Search for current best practices on specific patterns the feature requires:
- New integration patterns not yet used in the project
- Complex architectural patterns (e.g., real-time features, file upload, caching, auth strategies)
- Security considerations for the feature's domain
- Accessibility (WCAG) guidelines if UI elements are involved

### 4.5.3 MCP Coding Tools (use ALL available)

Discover and use **any MCP server tools available in the session** that can provide coding context. These tools fill the context window with project-specific intelligence before writing the plan.

**How to discover:** Check which MCP tools are available (they appear in system reminders). Use any that are relevant to the feature's tech stack.

Common examples:
| MCP Tool | When to use |
|----------|-------------|
| `context7` | Always — library documentation |
| `pyright-lsp` | Python features — type checking, symbol resolution, diagnostics |
| `typescript-lsp` | TypeScript features — type info, diagnostics, completions |
| `microsoft-docs` | .NET features — official Microsoft documentation |
| `playwright` | Features that need browser testing context |
| Any language server | Read type signatures, find usages, check diagnostics for files the feature will modify |

**The goal:** By the end of this step, you should have verified, current documentation for every API you'll use in the implementation plan. No guessing.

### 4.5.4 Update the Spec

Incorporate research findings into the approved brainstorming spec:
- Add a **Libraries Verified** section listing libraries + versions confirmed
- Add relevant API signatures, patterns, or constraints discovered
- Flag any deprecated patterns or breaking changes that affect the design

---

## STEP 4.6: DESIGN TOOLCHAIN (only if UI/design feature)

**Skip this step if the feature is NOT a UI/design feature.**

When Design Toolchain is active, enrich the spec with **visual design research** using available design MCP tools:

1. **`ui-ux-pro-max`** — Invoke the `Skill` tool with `skill: "ui-ux-pro-max"` for:
   - Design system decisions (color palette, typography, spacing)
   - Component design patterns (buttons, modals, cards, forms, charts)
   - Style direction (glassmorphism, minimalism, dark mode, etc.)

2. **`frontend-design`** — Invoke the `Skill` tool with `skill: "frontend-design:frontend-design"` for:
   - Production-grade component code generation
   - Distinctive, polished UI that avoids generic AI aesthetics
   - Creative design approaches

3. **`21st magic`** — Use `mcp__magic__21st_magic_component_inspiration` for:
   - Component inspiration and reference designs
   - Modern UI patterns and trends
   - Use `mcp__magic__21st_magic_component_builder` for building components with modern patterns

Update the spec with:
- **Visual Design** section with chosen styles, colors, typography
- **Component Specifications** with exact component hierarchy and props
- **Responsive Breakpoints** and layout behavior

**Do NOT proceed until the user approves the enriched design spec.**

---

## STEP 5: CREATE DESIGN DOCUMENT

Derive `<feature-name>` from the feature title (kebab-case, e.g., `blog-section`, `service-detail-pages`).

Save the approved design as a **temporary working file**:

```
docs/plans/<feature-name>-design.md
```

Include:
- Feature title and one-sentence goal
- Architecture decisions and approach chosen (from brainstorming)
- Component breakdown
- Data flow and integration points
- Edge cases and error handling strategy
- Testing strategy overview (referencing docs/TESTING.md patterns)
- Constraints and open questions resolved during brainstorm

**These files are working documents** — they'll be consumed by `/develop` and then cleaned up after merge. GitHub Issues are the permanent record.

---

## STEP 5.5: EMIT ADR (only if an architectural decision was reached)

After brainstorming + design-doc creation, decide whether the feature
introduces or changes an architectural decision. **Most features do NOT** —
they implement existing patterns.

### Trigger conditions (any one is enough)

- The brainstorming chose between 2+ approaches at the architectural level
  (e.g., "client component vs. server component" for a class of features,
  "SignalR vs. polling", "JWT vs. session cookies", "raw SQL vs. ORM").
- The feature introduces a new library, service, or external dependency.
- The feature changes how a layer interacts with another layer.
- The feature deliberately departs from an existing pattern (and is not
  expected to be one-off).

### If NO trigger fires

Skip this step. Do not write an ADR for routine implementation work.

### If a trigger fires

0. **Precondition** — verify the decisions folder is scaffolded:

```bash
if [ ! -d docs/decisions ] || [ ! -f docs/decisions/0000-template.md ]; then
  echo "ERROR: docs/decisions/ not scaffolded. Run /init-project first."
  exit 1
fi
```

1. Determine the next ADR number:

```bash
LAST=$(ls docs/decisions/ 2>/dev/null | grep -E '^[0-9]{4}-' | sort | tail -1 | cut -d'-' -f1)
NEXT=$(printf "%04d" $((10#${LAST:-0} + 1)))
SLUG="<kebab-case slug from decision title>"
ADR_PATH="docs/decisions/${NEXT}-${SLUG}.md"
```

2. Copy the template and fill it in:

```bash
cp docs/decisions/0000-template.md "$ADR_PATH"
```

Edit `$ADR_PATH` with:
- Title (NNNN — present-tense imperative)
- `status: accepted`
- `date: <today>`
- `feature_id: <PARENT>` (the GitHub issue number)
- `tags`: relevant area (e.g., `[realtime, dashboard, signalr]`)
- The four canonical sections filled with the brainstorm output

3. If this ADR supersedes another, set `supersedes: NNNN` in the new ADR
   frontmatter and update the old ADR's `superseded_by: NNNN` and
   `status: superseded`.

4. Regenerate the index by invoking the `Skill` tool with
   `skill: "github-lifecycle:compress-decisions"` (or running `/compress-decisions`).

5. Stage but do NOT commit yet — Step 6 (implementation plan) and Step 10
   (issue creation) are still ahead. Plan files and ADR get committed
   together by `/develop` later.

---

## STEP 6: CREATE IMPLEMENTATION PLAN (superpowers:writing-plans pattern)

**Context gathering was completed in Step 4.5.** All library docs, best practices, and MCP tool context are already available. Use them to write the plan with verified, current API usage.

### 6.1 Write the Implementation Plan

Using the approved design, write a detailed implementation plan. **Assume the implementing engineer has zero codebase context** — document everything they need.

Save as a **temporary working file**:

```
docs/plans/<feature-name>.md
```

### Plan Header (REQUIRED)

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** [One sentence]

**Architecture:** [2-3 sentences — component structure, data flow, animation approach]

**Tech Stack:** Next.js, React, Framer Motion, Tailwind CSS, TypeScript

**Design Doc:** `docs/plans/<feature-name>-design.md`

**Testing Reference:** `docs/TESTING.md`

**Library Versions Verified:** [List libraries + versions confirmed via Context7]

---
```

### Task Structure

Each task follows TDD with bite-sized steps (2-5 minutes each):

```markdown
### Task N: [Component Name]

**Files:**
- Create: `src/components/[component].tsx`
- Create: `src/app/[route]/page.tsx`
- Test (unit): `src/__tests__/[component].test.tsx`
- Test (E2E): `e2e/[feature].spec.ts`

**Step 1: Write the failing test**
[Complete test code — follow patterns from docs/TESTING.md]

**Step 2: Run test to verify it fails**
Run: npm test -- [test-file]
Expected: FAIL with "[reason]"

**Step 3: Write minimal implementation**
[Complete implementation code]

**Step 4: Run test to verify it passes**
Run: npm test -- [test-file]
Expected: PASS

**Step 5: Commit**
[exact git commands]
```

**Build/test commands vary by TECH_STACK:**
- `nextjs`: `npm run build`, `npm test`, `npm run test:e2e`
- `dotnet`: `dotnet build`, `dotnet test`
- `python`: `python -m pytest`, `python -m pytest e2e/`

Alternatively, read the exact build/test commands from the project's `CLAUDE.md` if they are documented there.

### Plan Requirements

- **Exact file paths** matching Next.js project structure (`src/app/`, `src/components/sections/`, `src/components/ui/`, `src/components/layout/`, `src/lib/`, `src/hooks/`)
- **Complete code** in the plan (not "add validation" — show the actual code)
- **Dependency order**: shared utils/types → components → pages → API routes → animations/polish
- **DRY, YAGNI, TDD** — frequent commits
- **Testing follows docs/TESTING.md**: Unit tests in `src/__tests__/`, E2E tests in `e2e/`, mocking patterns from `src/__tests__/setup.tsx`
- **Verified APIs**: All library API usage must match the docs fetched in Step 6.0 — no guessing deprecated or non-existent methods

---

## STEP 7: CHECK EXISTING ISSUES & IDENTIFY BLOCKERS

Query open issues to understand what already exists, avoid duplicates, and **detect potential blocking dependencies**:

```bash
gh issue list \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --state open \
  --json number,title,state,labels,assignees \
  --limit 50
```

### 7.1 Check for Overlapping Issues

Check for overlapping or related issues. Warn the user if similar items already exist.

### 7.2 Identify Blocking Dependencies

Analyze the existing open issues against the new feature's implementation plan to find **potential blockers** — issues that must complete first or that work on shared code/components in parallel:

**Look for conflicts in these areas:**
- **Shared files**: Other issues modifying the same files (components, pages, utils, styles) the new feature touches
- **Shared data**: Other issues changing constants, types, API routes, or data structures the new feature depends on
- **Shared infrastructure**: Other issues modifying build config, CI/CD, shared hooks, or middleware
- **UI conflicts**: Other issues working on the same page sections, layout areas, or navigation elements
- **Feature dependencies**: Other issues implementing APIs, components, or utilities that the new feature needs

For each potential blocker found, determine the relationship:
- **Blocked by** (must finish first): e.g., the new feature needs an API that another issue is building
- **Blocks** (other issue needs this first): e.g., the new feature creates a shared component another issue is waiting for
- **Related / parallel risk** (no hard dependency but merge conflict risk): e.g., both modify the same file

### 7.3 Present Dependencies

If potential blockers are found, present them to the user before proceeding:

```
Potential Dependencies Detected:
├── [BLOCKED BY] #123 "Create user API endpoint" (open, assigned to @dev)
│   └── Reason: New feature needs the /api/users endpoint this issue creates
├── [PARALLEL RISK] #456 "Redesign navigation bar" (open, assigned to @dev2)
│   └── Reason: Both modify src/components/layout/Navbar.tsx — merge conflicts likely
└── [RELATED] #789 "Add analytics tracking" (open, unassigned)
    └── Reason: Both add event handlers to the same page section
```

**Ask the user** which dependencies to note in the parent issue body.

---

## STEP 8: DESIGN THE ISSUE HIERARCHY

Use the brainstorm design (Step 4) and implementation plan (Step 6) to create informed, accurate issues.

### Parent Issue (Feature)
- Title: Deliverable functionality name
- Body: What capability this delivers, which components/pages it touches, key technical decisions
- **Embed the design summary and implementation plan overview in the body**.
- **If an ADR was emitted in Step 5.5**, include this block in the body:

  ```markdown
  ## Architecture Decision

  **ADR-NNNN — <title>**
  Status: accepted (<date>)
  Decision: <one-sentence summary>

  Full record: docs/decisions/NNNN-<slug>.md
  ```

### Sub-Issues (Tasks)
- Title: Concrete implementation step (imperative verb)
- Body: What, Where (file paths), Pattern, Tests
- **Align sub-issues with the implementation plan's task breakdown from Step 6**

### Rules

- Each sub-issue represents a concrete developer task
- Sub-issues reference concrete files/modules from the implementation plan
- Build order: shared utils → components → pages → API routes → animations → tests
- Testing is not optional — every feature includes testing sub-issues
- No duplicate scope between sub-issues

---

## STEP 9: PRESENT THE HIERARCHY

Show the full tree structure:

```
[Feature] Title (Parent Issue)
├── [Task] Create component for...
├── [Task] Add animation for...
├── [Task] Write unit tests for...
└── [Task] Write E2E tests for...
```

**Wait for user confirmation before creating.** The user may want to modify items.

---

## STEP 10: CREATE ISSUES & LINK SUB-ISSUES

Create the parent issue first, then all sub-issues linked beneath it:

```bash
# Create the parent feature issue
FEATURE_TITLE="<title from Step 9>"
FEATURE_BODY="<body from Step 8>"
PARENT="$(create_parent_issue "$FEATURE_TITLE" "$FEATURE_BODY" "type:feature")"
echo "Created parent issue #${PARENT}"

# Create sub-issues and link to parent
TASKS=("<task 1 title>" "<task 2 title>" ...)
for task in "${TASKS[@]}"; do
  SUB="$(create_sub_issue "$PARENT" "$task" "")"
  echo "  Sub-issue #${SUB}: $task"
done
```

The `create_parent_issue` and `create_sub_issue` helpers are defined in `commands/_shared/github-issues.md`.

---

## STEP 11: SUMMARY

Display:

1. **Full tree view** with all created issue numbers
2. **Stats**: Total issues created (1 parent + N sub-issues)
3. **Issue link**: `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/issues/${PARENT}`
4. **Working plan files** (temporary — will be cleaned up after `/develop` completes):
   ```
   Design:         docs/plans/<feature-name>-design.md
   Implementation: docs/plans/<feature-name>.md
   ```
5. **Next step**: "Run `/develop ${PARENT}` to start implementing this feature. The develop command will read the plan files and clean them up after merge."

---

## STEP 12: Update Workflow State

Derive the feature branch slug from the feature title (kebab-case):

```bash
SLUG="$(echo "$FEATURE_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')"
BRANCH="feature/${PARENT}-${SLUG}"
```

Set initial state:

```bash
set_state "$PARENT" "in-progress"
```

If `.state.md` exists (or create it from template), update:
- `track`: `feature`
- `step`: `feature`
- `branch`: `feature/${PARENT}-${SLUG}`
- `issue_number`: the parent issue number (`$PARENT`)
- `started_at`: current ISO timestamp
- `last_command`: `/feature`
- `status`: `ready-to-promote`
- `next_command`: `/develop`
- Append to History: `- [date time] /feature — status: completed (Feature #${PARENT} planned, issues created)`
