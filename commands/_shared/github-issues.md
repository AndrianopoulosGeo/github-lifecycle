## GitHub issue & sub-issue helpers

Encapsulates issue creation, sub-issue linking, and listing. Hides the GraphQL surface from individual command prompts.

### Create a parent issue

```bash
# Args: title, body, label
# Echoes the issue number.
create_parent_issue() {
  local title="$1"
  local body="$2"
  local label="$3"
  gh issue create \
    --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
    --title "$title" \
    --body "$body" \
    --label "$label" \
    | sed -E 's#.*/([0-9]+)$#\1#'
}
```

### Create a sub-issue and link it to a parent

GitHub sub-issues are added via the REST API (`/repos/{owner}/{repo}/issues/{issue}/sub_issues`).

```bash
# Args: parent_issue, sub_title, sub_body
# Echoes the sub-issue number.
create_sub_issue() {
  local parent="$1"
  local sub_title="$2"
  local sub_body="$3"

  # 1) Create the sub-issue as a normal issue with type:task
  local sub_number
  sub_number="$(gh issue create \
    --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
    --title "$sub_title" \
    --body "$sub_body" \
    --label "type:task" \
    | sed -E 's#.*/([0-9]+)$#\1#')"

  # 2) Resolve sub-issue's integer database ID (the REST endpoint requires an integer, not a node_id)
  local sub_int_id
  sub_int_id="$(gh api "repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues/${sub_number}" -q .id)"

  # 3) Link as sub-issue of parent via REST
  gh api --method POST \
    "repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues/${parent}/sub_issues" \
    -F sub_issue_id="$sub_int_id" >/dev/null

  echo "$sub_number"
}
```

### List sub-issues of a parent

```bash
list_sub_issues() {
  local parent="$1"
  gh api "repos/${GITHUB_OWNER}/${GITHUB_REPO}/issues/${parent}/sub_issues" \
    -q '.[] | {number, title, state}'
}
```

### Close a sub-issue (after task complete)

```bash
close_sub_issue() {
  local number="$1"
  gh issue close "$number" --repo "${GITHUB_OWNER}/${GITHUB_REPO}"
}
```

Note: the sub-issues REST endpoint was generally available in 2024 and is the recommended path. If a future GitHub API change deprecates it, this is the only file to update.
