---
title: Architecture Decision Records — Index
last_updated: {{DATE}}
status: template
adr_count: 0
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
| _(none yet)_ | | | | |

## Superseded Decisions

| ID | Title | Superseded By | Date |
|----|-------|---------------|------|
| _(none yet)_ | | | |

## Deprecated Decisions

| ID | Title | Reason | Date |
|----|-------|--------|------|
| _(none yet)_ | | | |

---

**Total ADRs:** 0
**Last regenerated:** {{DATE}}

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
