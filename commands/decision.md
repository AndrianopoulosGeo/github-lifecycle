---
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

# /decision — Manual ADR Operations

> **Expert Voice:** Architect — captures decisions immutably, prevents re-litigation, keeps the index tight.

You manage Architecture Decision Records (ADRs) at `docs/decisions/`.
Use this command to create, list, supersede, or show ADRs **outside** the
`/feature` workflow (e.g., when you've reached a decision in a meeting and
want to record it before any feature work begins).

ADRs live in the `/docs folder in the main repo`, not in a separate wiki.
This means they are version-controlled alongside the code and visible on
GitHub.com as rendered markdown.

**Usage:**
- `/decision new "<title>"` — Scaffold a new ADR with the next number
- `/decision list` — List all ADRs grouped by status
- `/decision show <ID>` — Print a specific ADR (e.g., `/decision show 7`)
- `/decision supersede <OLD_ID> "<new title>"` — Create a new ADR that
  supersedes an old one
- `/decision deprecate <ID> "<reason>"` — Mark an ADR as deprecated (no
  longer applies but no replacement)

The `$ARGUMENTS` parameter contains the subcommand and its args.

## Guard: ensure decisions folder is scaffolded

```bash
if [ ! -d docs/decisions ] || [ ! -f docs/decisions/0000-template.md ] || [ ! -f docs/decisions/INDEX.md ]; then
  echo "ERROR: docs/decisions/ not scaffolded. Run /init-project first."
  exit 1
fi
```

## Subcommand: `new "<title>"`

1. Compute next ADR number:

```bash
LAST=$(ls docs/decisions/ 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-' | sort | tail -1 | cut -d'-' -f1)
NEXT=$(printf "%04d" $((10#${LAST:-0} + 1)))
```

2. Compute slug from title (kebab-case, lowercase, alphanumeric + hyphens
   only). Cap at 50 chars.

3. Create file at `docs/decisions/${NEXT}-${SLUG}.md` by copying
   `docs/decisions/0000-template.md` and replacing:
   - Title placeholder → "ADR-${NEXT}: <user-provided title>"
   - `date:` → today (YYYY-MM-DD)
   - `status:` → `accepted`

4. Open the file for editing (use `Edit` tool to fill in Context, Decision,
   Alternatives, Consequences with the user — ask one question per section
   if the user has not provided content).

5. Run `/compress-decisions` to refresh `docs/decisions/INDEX.md`.

6. Print:
```
Created ADR-NNNN at docs/decisions/NNNN-<slug>.md
```

## Subcommand: `list`

1. Read `docs/decisions/INDEX.md`. If it exists and is current, print it.
2. If it doesn't exist or is stale, print a notice:
```
INDEX.md missing or stale. Run /compress-decisions to regenerate.
```

## Subcommand: `show <ID>`

1. Pad ID to 4 digits.
2. Find file: `ls docs/decisions/${PADDED}-*.md`.
3. Print full file contents with the `Read` tool.
4. If not found, print:
```
No ADR with ID <ID>. Run /decision list to see available ADRs.
```

## Subcommand: `supersede <OLD_ID> "<new title>"`

1. Pad OLD_ID. Find old file. If not found → error.
2. Read the target ADR's `status:` frontmatter. If it is already `superseded` or `deprecated`, refuse the operation:

```
ERROR: ADR-<OLD_ID> is already <status>. Refusing to modify.
If the situation has changed, write a new ADR via /decision new instead.
```

3. Compute NEXT number (as in `new`).
4. Compute slug from new title.
5. Create new file from template at `docs/decisions/${NEXT}-${SLUG}.md`
   with frontmatter `supersedes: ${OLD_ID}`.
6. Edit the **old** ADR file:
   - Set `superseded_by: ${NEXT}` in frontmatter
   - Set `status: superseded`
   - Append a `> **Superseded by ADR-${NEXT}**` admonition at the top of
     the body (after the H1)
7. Open the new file for editing (same flow as `new`).
8. Run `/compress-decisions`.

## Subcommand: `deprecate <ID> "<reason>"`

1. Pad ID. Find file. If not found → error.
2. Read the target ADR's `status:` frontmatter. If it is already `superseded` or `deprecated`, refuse the operation:

```
ERROR: ADR-<ID> is already <status>. Refusing to modify.
```

3. Edit the ADR file:
   - Set `status: deprecated` in frontmatter
   - Append a `> **Deprecated** — <reason>` admonition at the top of the
     body
4. Run `/compress-decisions`.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| Decisions folder not found | `/init-project` not run | Run `/init-project` first or create `docs/decisions/` manually |
| ADR ID not found | typo or wrong padding | Run `/decision list` to see available IDs |
