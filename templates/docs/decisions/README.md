---
title: Decisions Folder — How It Works
last_updated: {{DATE}}
status: reviewed
---

# Architecture Decision Records (ADRs)

This folder is the project's architectural memory. Every significant
architectural decision is recorded as one immutable file.

## File naming

`<NNNN>-<short-slug>.md` — e.g., `0007-realtime-via-signalr.md`.

## What goes here

- **Yes:** decisions that change which patterns the codebase will follow,
  what libraries we depend on, how layers interact, where security boundaries
  live, what trade-offs we accept.
- **No:** implementation details, bug fixes, refactors, naming choices,
  one-off configuration tweaks.

## Lifecycle

1. A decision is reached (during `/feature` brainstorming, or recorded
   manually with `/decision new "<title>"`).
2. The ADR is written to `<NNNN>-<slug>.md` with `status: accepted`.
3. The GitHub issue description gets a one-line link to the ADR (hybrid).
4. Decisions never get edited. To change one, write a new ADR with
   `supersedes: NNNN` in frontmatter; the old one's status becomes
   `superseded`.
5. Run `/compress-decisions` after any add/supersede to refresh `INDEX.md`.

## Why we keep ADRs

- They give Claude (and humans) a fast way to learn what is settled and why.
- They prevent re-litigating the same decision every quarter.
- They prevent reintroducing rejected alternatives.
- They are the historical record of architectural evolution.
