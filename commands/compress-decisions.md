---
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

# /compress-decisions — Regenerate ADR Index

> **Expert Voice:** Information Architect — keeps Claude's context window small while preserving every architectural decision in full.

Regenerate `docs/decisions/INDEX.md` from the source ADR files in
`docs/decisions/`. The INDEX is the cheap, always-loaded summary used
by `/feature`, `/develop`, `/quick-fix`, and `/hotfix`. Running this command
after any ADR add/supersede/deprecate keeps the index in sync.

ADRs live in the `/docs folder in the main repo` alongside the code.
No separate wiki or publish step is needed — the docs are part of the repo.

**Usage:**
- `/compress-decisions` — Regenerate INDEX from all ADRs
- `/compress-decisions --check` — Print what would change but do not write
- `/compress-decisions --archive-superseded` — Move superseded ADRs (older
  than 12 months) to `docs/decisions/archive/` to reduce folder
  noise. Their summary stays in INDEX as a single line.

The `$ARGUMENTS` parameter contains optional flags.

## Guard

```bash
if [ ! -d docs/decisions ]; then
  echo "ERROR: docs/decisions/ not found. Run /init-project first."
  exit 1
fi
```

## Step 1: Discover ADR files

```bash
ADR_FILES=$(ls docs/decisions/ 2>/dev/null | grep -E '^[0-9]{4}-.*\.md$' | grep -v '^0000-template' | sort)
```

If no ADR files (other than the template), write a minimal INDEX
indicating an empty state and exit.

## Step 2: Parse each ADR file

For each file, read its frontmatter and body. Extract:

| Field | Source |
|-------|--------|
| `id` | from filename (`NNNN`) |
| `title` | frontmatter `title` |
| `status` | frontmatter `status` (`accepted` / `superseded` / `deprecated`) |
| `date` | frontmatter `date` |
| `tags` | frontmatter `tags` |
| `supersedes` | frontmatter `supersedes` (or empty) |
| `superseded_by` | frontmatter `superseded_by` (or empty) |
| `decision_one_liner` | the first sentence of the `## Decision` section, capped at 120 characters |

If a field is missing, mark it `(missing)` and continue. Do not fail.

## Step 3: Build the new INDEX content

Use this exact structure:

```markdown
---
title: Architecture Decision Records — Index
last_updated: <today>
status: reviewed
adr_count: <N_active>
---

# Architecture Decision Records

> **For Claude:** This index is the cheap, always-loaded summary of every
> architectural decision in this project. Each row is one decision compressed
> to a single sentence. Load a full ADR file only when a decision is being
> challenged, superseded, or directly quoted. Regenerate this index by
> running `/compress-decisions` after any ADR change.

## Active Decisions

| ID | Title | Date | Decision (one sentence) | Tags |
|----|-------|------|-------------------------|------|
| [0001](0001-<slug>.md) | <title> | <date> | <decision_one_liner> | <tags-comma-sep> |
| ... | | | | |

## Superseded Decisions

| ID | Title | Superseded By | Date |
|----|-------|---------------|------|
| [0003](0003-<slug>.md) | <title> | [0007](0007-<slug>.md) | <date> |
| ... | | | |

## Deprecated Decisions

| ID | Title | Reason | Date |
|----|-------|--------|------|
| [0005](0005-<slug>.md) | <title> | <reason from deprecation admonition> | <date> |
| ... | | | |

---

**Total ADRs:** <total>
**Active:** <N_active>  •  **Superseded:** <N_superseded>  •  **Deprecated:** <N_deprecated>
**Last regenerated:** <today>

How to read this index:
1. Skim the **Active Decisions** table — these are the constraints currently
   in force.
2. If a decision row is relevant to your work, open the full file at
   `docs/decisions/<NNNN>-<slug>.md` for context, alternatives, and
   consequences.
3. Superseded decisions are kept for historical reasoning but should NOT
   guide new work — follow the superseder.

How to write a new ADR:
- Run `/decision new "<short title>"` — scaffolds a new file with the next
  available number.
- Or, during `/feature` brainstorming, an ADR is auto-drafted when an
  architectural decision is reached.
- After saving, run `/compress-decisions` to refresh this index.
```

## Step 4: Write the file

Write the new INDEX content to `docs/decisions/INDEX.md`. Overwrite
unconditionally — the source ADR files are the truth, the INDEX is
derived.

## Step 5: `--check` mode

If the user passed `--check`:
- Compute the new content as above but do NOT write.
- Compare against existing INDEX.md.
- Print a unified diff.
- Exit without modifying any file.

## Step 6: `--archive-superseded` mode

If the user passed `--archive-superseded`:

```bash
mkdir -p docs/decisions/archive
TODAY_EPOCH=$(date +%s)
TWELVE_MONTHS_AGO=$((TODAY_EPOCH - 31536000))

# Portable date parser — handle BSD (macOS) and GNU (Linux)
if date -d "2020-01-01" +%s >/dev/null 2>&1; then
  to_epoch() { date -d "$1" +%s 2>/dev/null; }     # GNU
else
  to_epoch() { date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null; }  # BSD/macOS
fi
```

For each ADR with `status: superseded`:

1. Read its `date:` frontmatter.
2. If `date:` is missing or unparseable, do NOT archive — log the filename
   to stderr (`echo "WARN: ADR-NNNN has missing/unparseable date — skipping archive" >&2`) and continue with the next file.
3. Convert the date to an epoch via `to_epoch "$ADR_DATE"`. If conversion
   fails (returns empty), treat as missing per step 2 above.
4. If the resulting epoch is older than `$TWELVE_MONTHS_AGO`:
   - Move the file to `docs/decisions/archive/<NNNN>-<slug>.md`
   - Update the INDEX entry to point to `archive/<NNNN>-<slug>.md`
   - The INDEX still shows the row; the file just lives in a quieter folder

This keeps the active decisions folder visually clean while the index
remains complete. The conservative "skip on missing/unparseable date"
policy avoids accidentally archiving an ADR whose date metadata is
incomplete.

## Step 7: Print summary

```
/compress-decisions completed:

Active:        <N>
Superseded:    <N>
Deprecated:    <N>
Total:         <N>

INDEX.md regenerated at docs/decisions/INDEX.md
Archived (this run): <N> files moved to archive/
```

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| INDEX write fails | folder permissions | Print path + permission error |
| ADR file unreadable | malformed frontmatter | Log filename, continue with next file, mark row as `(parse error)` |
| Conflicting ADR numbers | two files share NNNN | List both, ask user which to keep, do not overwrite |
