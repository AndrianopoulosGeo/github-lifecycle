## Shared: Emit an Architecture Decision Record (ADR)

> Used by: `/feature` Step 5.5, `/develop` Phase 9. Read inline when the work
> introduces or changes an architectural decision. Most work does NOT — it
> implements existing patterns.

### Trigger conditions (any one is enough)

- A choice was made between 2+ approaches at the architectural level
  (e.g. client vs. server component as a class decision, SignalR vs. polling,
  JWT vs. session cookies, raw SQL vs. ORM).
- A new library, service, or external dependency is introduced.
- The way one layer interacts with another changes.
- The work deliberately departs from an existing pattern (not a one-off).

If no trigger fires, skip ADR emission entirely.

### Emit procedure

1. **Precondition** — verify the decisions folder is scaffolded:

   ```bash
   if [ ! -d docs/decisions ] || [ ! -f docs/decisions/0000-template.md ]; then
     echo "ERROR: docs/decisions/ not scaffolded. Run /init-project first."
     exit 1
   fi
   ```

2. Determine the next ADR number:

   ```bash
   LAST=$(ls docs/decisions/ 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-' | sort | tail -1 | cut -d'-' -f1)
   NEXT=$(printf "%04d" $((10#${LAST:-0} + 1)))
   SLUG="<kebab-case slug from the decision title>"
   ADR_PATH="docs/decisions/${NEXT}-${SLUG}.md"
   ```

3. Copy the template and fill it in:

   ```bash
   cp docs/decisions/0000-template.md "$ADR_PATH"
   ```

   Edit `$ADR_PATH` with: the title (`NNNN — present-tense imperative`),
   `status: accepted`, `date: <today>`, `feature_id: <PARENT>` (the GitHub
   Issue number), `tags` (relevant area), and the four canonical sections
   (Context, Decision, Alternatives, Consequences).

4. If this ADR supersedes another, set `supersedes: NNNN` in the new ADR's
   frontmatter, and update the old ADR's `superseded_by: NNNN` and
   `status: superseded`.

5. Regenerate the index by invoking the `Skill` tool with
   `skill: "compress-decisions"`.

6. Add a one-line ADR link to the parent GitHub Issue body or a comment (the
   decision record is the source of truth; the issue is the pointer):

   ```markdown
   ## Architecture Decision

   **ADR-NNNN — <title>**
   Status: accepted (<date>)
   Decision: <one-sentence summary>

   Full record: docs/decisions/NNNN-<slug>.md
   ```
