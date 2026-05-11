## Canonical label taxonomy

Single source of truth for the labels used by lifecycle commands. `/init-project` creates them; every other command references them by name. **Do not add labels outside this list** — keep the surface small.

### type:* labels

| Label | Color | Used on |
|---|---|---|
| `type:feature` | `#0E8A16` | Parent Issue created by `/feature` |
| `type:task` | `#BFD4F2` | Sub-issues created under a `type:feature` parent |
| `type:hotfix` | `#B60205` | Issue created by `/hotfix` |
| `type:quickfix` | `#FBCA04` | Issue created by `/quick-fix` |

### state:* labels

Workflow state on the parent Issue. **Mutually exclusive** by convention. The local `.state.md` file is the source of truth; the label is a projection for visibility on the web UI. The state `idle` is represented by the **absence** of any `state:*` label.

| Label | Color | Meaning |
|---|---|---|
| `state:in-progress` | `#1D76DB` | Implementation underway |
| `state:blocked` | `#D93F0B` | Blocked on external decision |
| `state:awaiting-review` | `#5319E7` | PR open, awaiting review |
| `state:ready-to-promote` | `#0E8A16` | Merged to develop, awaiting `/staging` |

### Bash helpers

```bash
# Create the entire label taxonomy (idempotent — used by /init-project)
create_canonical_labels() {
  gh label create "type:feature"             --color "0E8A16" --description "Feature (parent)"    --force
  gh label create "type:task"                --color "BFD4F2" --description "Sub-task of a feature" --force
  gh label create "type:hotfix"              --color "B60205" --description "Hotfix"               --force
  gh label create "type:quickfix"            --color "FBCA04" --description "Quick fix"            --force
  gh label create "state:in-progress"        --color "1D76DB" --description "Implementation underway"  --force
  gh label create "state:blocked"            --color "D93F0B" --description "Blocked on external decision" --force
  gh label create "state:awaiting-review"    --color "5319E7" --description "PR open, awaiting review" --force
  gh label create "state:ready-to-promote"   --color "0E8A16" --description "Merged to develop, awaiting /staging" --force
}

# Set state label on an issue (replaces any existing state:* label)
set_state_label() {
  local issue_number="$1"
  local new_state="$2"   # empty = idle, otherwise one of: in-progress, blocked, awaiting-review, ready-to-promote
  local existing
  existing="$(gh issue view "$issue_number" --json labels -q '.labels[].name' | grep -E '^state:' || true)"
  if [ -n "$existing" ]; then
    gh issue edit "$issue_number" --remove-label "$existing"
  fi
  if [ -n "$new_state" ]; then
    gh issue edit "$issue_number" --add-label "state:${new_state}"
  fi
}
```
