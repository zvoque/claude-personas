---
name: create-persona
description: Create a new persistent persona for the personas plugin through a short guided interview. Use when the user wants to make, author, or define a new persona or mode, or runs `/personas new`.
---

# Create a persona

Author a new persona for the `personas` plugin. A persona is a data file the plugin injects every turn while active. You **gather** the details; the CLI **writes** the file — never hand-write the persona file yourself (`personas-ctl.js` is the sole writer of state and persona files).

## 1. Get the name
If the user supplied a name, use it; otherwise ask. It must be lowercase `a-z 0-9 -`, start with a letter or digit, and must NOT be one of the reserved verbs: `list off on solo parallel team new delete help`. If it's invalid or reserved, ask for another.

## 2. Interview (use AskUserQuestion — keep it tight, 2–4 questions, offer sensible defaults)
Gather:
- **Description** — one line: who this persona is / when to use it. (Becomes the persona's `description`, shown in `/personas list`.)
- **Role** — what it does on every turn: what it pressure-tests, optimizes for, or produces. Its job.
- **Voice** — tone and speaking style (e.g. terse and blunt; warm and encouraging; numbers-driven).
- **Steps aside for** — when it should drop the persona and answer plainly. Default: irreversible/destructive actions, and explicit clarify/repeat requests.

Do NOT ask about deactivation — turning a persona off is always `/personas off`, uniform across all personas.

## 3. Assemble the body
Write the persona as direct instructions **addressed to Claude** (second person), built from the answers: an opening line stating the role, a short "on every response" structure if the role implies one, the voice, and a "step aside (plain mode) for" section. Keep it tight and concrete. Do NOT include any "deactivate by saying ..." clause (off is uniform).

## 4. Write it via the CLI (never hand-write the file)
Write the assembled body to a temp file with the Write tool, then create the persona:

```bash
node "${CLAUDE_PLUGIN_ROOT}/hooks/personas-ctl.js" create <name> --desc "<description>" < /tmp/persona-body.md
```

The CLI validates the name, rejects reserved/duplicate names, writes valid frontmatter atomically to `~/.claude/personas/<name>.md`, and warns if it overrides a bundled persona. Relay its output verbatim. If it errors (reserved name, already exists, empty body), tell the user and fix.

## 5. Confirm
Tell the user it's created, that they activate it with `/personas <name>` (and deactivate any persona with `/personas off`), and that it's automatically eligible as a debater in `/personas team`.
