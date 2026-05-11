---
allowed-tools: Bash, Read
description: List documents under /docs with their titles and first paragraph
---

# /wiki — Docs navigator

Prints a table of all `.md` files under `docs/` (excluding `docs/decisions/`, which has its own index). Each row shows the file path, the H1 title, and the first non-empty paragraph as a description.

## Steps

1. Source `commands/_shared/load-config.md`.
2. Verify `docs/` exists; if not, suggest running `/init-project`.
3. Run:

```bash
print_docs_table() {
  printf "| File | Title | Description |\n|---|---|---|\n"
  find docs -type f -name '*.md' ! -path 'docs/decisions/*' | sort | while read -r f; do
    title="$(awk '/^# /{sub(/^# /,""); print; exit}' "$f")"
    desc="$(awk '/^[^# ]/{print; exit}' "$f" | tr '|' '/' | cut -c1-80)"
    printf "| %s | %s | %s |\n" "$f" "${title:-(no title)}" "${desc:-(empty)}"
  done
}
print_docs_table
```

4. Print a follow-up suggestion: "To browse a doc, open it directly. To browse ADRs, see `docs/decisions/INDEX.md`."
