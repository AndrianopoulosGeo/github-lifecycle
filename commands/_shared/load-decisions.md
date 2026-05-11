## Shared: Load Architectural Decisions (ADRs)

> Used by: `/feature` Step 3, `/develop` Phase 1.5, `/quick-fix`, `/hotfix`.
> Goal: load architectural-memory context cheaply, without bloating the
> context window with every full ADR.

### How to load

#### 1. Always load the index

```bash
INDEX="docs/decisions/INDEX.md"
if [ -f "$INDEX" ]; then
  cat "$INDEX"
else
  echo "(no ADRs yet — proceed without ADR context)"
fi
```

If `INDEX.md` does not exist, the project has no ADRs yet — proceed without
ADR context. Do NOT scan the folder by hand; that defeats the compression.

#### 2. Load specific ADRs ONLY on demand

A full ADR file should be read with the `Read` tool only when:

- The brainstorm or implementation challenges an existing decision (you must
  read the full ADR to honor its alternatives + consequences before proposing
  to supersede).
- The user references an ADR by ID (`ADR-0007`).
- An auto-fix in `/develop` Phase 2.6.3 finds a discrepancy that touches a
  decision.

In all other cases, the one-line summary in `INDEX.md` is sufficient.

#### 3. Threshold notice

After reading `INDEX.md`, count active ADRs:

```bash
ADR_COUNT=$(grep -E '^adr_count:' "$INDEX" | awk '{print $2}')
[ -z "$ADR_COUNT" ] && ADR_COUNT=$(grep -cE '^\| 0[0-9]{3}' "$INDEX")
```

Then check the threshold:

- If `adr_count >= 15`, print a one-line notice to the user:

  `Heads-up: this project has N ADRs. Consider running /compress-decisions to keep the index summaries tight.`

- Do NOT auto-run `/compress-decisions` — it would surprise the user mid-workflow.

### Output to brainstorming / planning

When passing ADR context downstream (e.g., to `superpowers:brainstorming` or
the architectural brief), include:

1. The full INDEX.md contents (cheap).
2. **Only** the full text of ADRs that are directly relevant to the current
   feature's domain. Use the `tags` frontmatter field to filter.

This keeps the context tight while preserving the decisions that actually
constrain the new work.
