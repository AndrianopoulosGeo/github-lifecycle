---
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

# /set-language — Set Interaction Language

> **Expert Voice:** Platform Engineer — configures per-developer preferences without touching shared artifacts.

You configure the language Claude uses when **talking to the user**. The
conversation — chat replies, explanations, the questions you ask, status
updates, summaries — follows this preference. **Every persisted or shared
artifact stays in English**: code, comments, commit messages, branch names,
PR text, GitHub Issues, plans, specs, ADRs, wiki content,
`.state.md`, and `CLAUDE.md`.

This command writes two things:
- `PREFERRED_LANGUAGE` in `.env.claude` (gitignored — a per-developer value)
- A generic `## Interaction Language` block in the project `CLAUDE.md`
  (committed — it tells Claude to read the value; it never names a language)

## Step 1: Precondition — `.env.claude` must exist

```bash
if [ ! -f .env.claude ]; then
  echo "ERROR: .env.claude not found. Run /init-project first."
  exit 1
fi
```

If `.env.claude` is missing, stop here and tell the user:
> ".env.claude not found. Run `/init-project` first, then re-run `/set-language`."

Do not create a partial `.env.claude` — it needs the GitHub
configuration that `/init-project` gathers.

## Step 2: Read the current value (if any)

```bash
CURRENT=$(grep '^PREFERRED_LANGUAGE=' .env.claude | cut -d '=' -f2)
echo "Current PREFERRED_LANGUAGE: ${CURRENT:-(unset - defaults to English)}"
```

## Step 3: Ask the user for their preferred language

Use `AskUserQuestion` (when available). If `CURRENT` is set, mention it ("currently: <value>").

> "Which language should Claude use when talking to you? All code, docs,
> tickets, plans, and decisions stay in English regardless."

Offer common options — English, Greek, German, Spanish, French — plus Other
(free text). Record the answer as a full English language name (e.g. `Greek`).
If the user picks English, that is valid — it resets to the default behavior.

## Step 4: Write `PREFERRED_LANGUAGE` into `.env.claude`

Let `LANG_VALUE` be the language name chosen in Step 3. Add or replace the line:

```bash
LANG_VALUE="<language chosen in Step 3>"
if grep -q '^PREFERRED_LANGUAGE=' .env.claude; then
  sed -i.bak "s|^PREFERRED_LANGUAGE=.*|PREFERRED_LANGUAGE=${LANG_VALUE}|" .env.claude && rm .env.claude.bak
else
  echo "PREFERRED_LANGUAGE=${LANG_VALUE}" >> .env.claude
fi
```

## Step 5: Append the language block to `CLAUDE.md`

```bash
if [ ! -f CLAUDE.md ]; then
  printf '# %s\n\nProject guidance for Claude Code.\n' "$(basename "$PWD")" > CLAUDE.md
fi

if grep -q '^## Interaction Language' CLAUDE.md; then
  echo "CLAUDE.md already has the Interaction Language block - skipping."
else
  printf '\n' >> CLAUDE.md
  cat "${CLAUDE_PLUGIN_ROOT:-.}/templates/claude-md-language-block.md" >> CLAUDE.md
  echo "Appended the Interaction Language block to CLAUDE.md."
fi
```

The block is generic — it never names a language, so it does not need to be
rewritten when the language changes. Only Step 4's `.env.claude` line changes
on a re-run.

## Step 6: Confirm — in the newly chosen language

Print a short confirmation **in the language the user just chose** (this is a
live demonstration that the setting works). Cover:
- `PREFERRED_LANGUAGE` is now set to `<value>` in `.env.claude`
- From now on the conversation will be in that language
- All code, commits, tickets, plans, ADRs, and wiki content stay in English

If the chosen language is English, confirm in English.

**Remind the user to commit `CLAUDE.md`.** This command appended the
Interaction Language block to `CLAUDE.md`, a tracked file — commit it (e.g.
with `/commit`) so the whole team gets the instruction. The
`PREFERRED_LANGUAGE` value in `.env.claude` is gitignored and stays local to
this developer.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| `.env.claude` not found | `/init-project` not run | Run `/init-project` first |
| `CLAUDE.md` write fails | permissions | Check file permissions in the repo root |
