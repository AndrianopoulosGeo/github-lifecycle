## Interaction Language

This project supports a per-developer interaction language, configured via
`PREFERRED_LANGUAGE` in `.env.claude`.

**At the start of every session, read `PREFERRED_LANGUAGE` from `.env.claude`.**

- If it is set to a language other than English (e.g. `Greek`), conduct **all
  conversation with the user in that language**: chat replies, explanations,
  the questions you ask, status updates, summaries, and error explanations.
- If it is unset, empty, or `English`, use English — no behavior change.
- Interpret the value flexibly — `Greek`, `greek`, and `el` all mean Greek.
- This is a default, not a lock — if the user explicitly asks for a reply in
  another language, honor that request.

**All persisted and shared artifacts MUST remain in English, regardless of
`PREFERRED_LANGUAGE`:**

- Source code and code comments
- Commit messages, branch names, PR titles and descriptions
- GitHub Issues, project boards, and PR fields
- Implementation plans (`docs/superpowers/plans/`) and specs (`docs/superpowers/specs/`)
- Architecture Decision Records and their index (`docs/wiki/decisions/`)
- All wiki content (`docs/wiki/`)
- `.state.md` and `CLAUDE.md`

The language setting governs only the live conversation. Everything written to
disk or to GitHub stays in English so the codebase remains consistent
for all contributors.
