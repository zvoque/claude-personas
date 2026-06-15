---
name: create-persona
description: Create a new persistent persona for the personas plugin through a short guided interview, then a draft review. Use when the user wants to make, author, or define a new persona or mode, or runs `/personas new`.
---

# Create a persona

Author a new persona for the `personas` plugin through a short interview, then show a draft for approval before it's written. You **gather + draft**; the CLI **writes** (never hand-write the persona file — `personas-ctl.js` is the sole writer of state and persona files).

**Adapt to the user — don't re-ask what they already told you.** Read what the invocation already gives and skip those steps:
- `/personas new` (bare) → run the full guided flow (Steps 1–4).
- `/personas new <name>` → skip the name step.
- `/personas new <name> "<what it should do>"` or a natural-language request ("make a persona that …") → skip intent **and** name; infer the shape; go straight to the draft.

The **only step you never skip is the draft review (Step 4).** Keep momentum: one question at a time, smart defaults, no interrogation.

## 1. Intent — one open question (skip if already clear)
If the invocation didn't make the intent clear, ask ONE open question in chat (plain text, not AskUserQuestion — this answer should be free-form):
> "In a sentence or two: what should this persona *do*, and when would you switch it on?"
This is the spine — everything else hangs off it. Don't move on until you understand the job.

## 2. Shape it — one `AskUserQuestion` (skip any the intent already settles)
Ask only what you can't confidently infer. Put the questions you still need into a **single `AskUserQuestion`** (it holds several), each with the most likely option **pre-selected as the default** — so a power user accepts in one screen, while the options themselves show a newbie what's possible:
- **Voice** — terse & blunt · warm & encouraging · rigorous & numbers-driven · Socratic (questions before answers) · *(Other)*
- **Response shape** — free-form · a fixed structure every turn (you'll draft the sections) · always ends with a verdict/recommendation · *(Other)*
- **Steps aside for** — the safe default (irreversible/destructive actions + explicit clarify/repeat requests) · that, plus something specific · *(Other)*
Infer defaults from the intent. Never ask a question the intent already answers.

## 3. Name (skip if given)
If there's no name yet, **propose** one derived from the intent and ask the user to accept or change it — don't make them invent it cold. It must be lowercase `a-z 0-9 -`, start with a letter/digit, and must NOT be a reserved verb (`list off on solo parallel team new delete help`). Re-propose if invalid or taken.

## 4. Draft + review — NEVER skip
Assemble the persona body as direct, second-person instructions to Claude: an opening line stating the role, the response shape (a short labeled structure if they chose one), the voice, and a "step aside (plain mode) for" section. Tight and concrete. Do NOT add any "deactivate by saying …" clause (off is uniform: `/personas off`).

**Show the full draft to the user**, then ask via `AskUserQuestion`: **Use it as-is · Change something (they say what) · Regenerate**. Loop until they approve. This review is the difference between a persona they love and a generic one — never write without it.

## 5. Write via the CLI — never hand-write the file
On approval, write the approved body to a temp file with the Write tool, then:

```bash
node "${CLAUDE_PLUGIN_ROOT}/hooks/personas-ctl.js" create <name> --desc "<one-line description>" < /tmp/persona-body.md
```

The CLI validates the name, rejects reserved/duplicate names, writes valid frontmatter atomically to `~/.claude/personas/<name>.md`, and warns if it overrides a bundled persona. Relay its output. On error (reserved name, already exists, empty body), fix and retry.

## 6. Confirm + offer to activate
Tell the user it's live: activate with `/personas <name>`, deactivate any persona with `/personas off`, and it's automatically eligible as a debater in `/personas team`. Offer to activate it now — if they say yes, run `node "${CLAUDE_PLUGIN_ROOT}/hooks/personas-ctl.js" enable <name>` and adopt the persona for the rest of this turn so it takes effect immediately.
