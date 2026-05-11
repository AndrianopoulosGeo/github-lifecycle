---
allowed-tools: Bash
description: Deprecated — docs ship with code, no separate publish step needed
---

# /publish-wiki — Deprecated

In the GitHub plugin, documentation lives in `docs/` in the main repo and is rendered by github.com when browsed. There is **no separate wiki to publish**.

If you came here from the Azure DevOps plugin's `/publish-wiki`: your docs are already published when commits land on `main`. To verify, run `/wiki` to list the current docs.

## Steps

1. Print a one-line message: `"/publish-wiki is a no-op in github-lifecycle. Docs in /docs ship with the code on every commit to main."`
2. Suggest: `Run /wiki to list current docs.`
3. Exit 0.

This stub will be removed in `github-lifecycle` v2.0.0.
