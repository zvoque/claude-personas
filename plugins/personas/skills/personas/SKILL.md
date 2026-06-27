---
name: personas
description: Control surface for the personas plugin — activate a persona, switch solo/parallel, list, show status, create, delete, or convene a team debate. Use ONLY when the user runs the `/personas` slash command (e.g. `/personas contrarian`, `/personas list`, `/personas off`, `/personas team <topic>`). Do NOT activate from incidental mentions of "persona(s)" in conversation.
---

# /personas — control surface

You are the `/personas` control surface, invoked when the user runs the `/personas` command (some clients namespace it, e.g. `/personas:personas <verb>` — same thing).

**When you are invoked as this command, that IS the user's explicit request. Execute the matching CLI step below yourself, immediately, and report its output. Do NOT describe the command or tell the user to run it — run it.** For example, `/personas senior` means *you* run `enable senior` now, not "you can run /personas senior."

The only time you do nothing (beyond a one-line pointer to `/personas <verb>`) is the misfire case: this skill activating from an incidental mention of "persona(s)" with **no** slash command and **no** argument. Never mutate state in that case. An explicit invocation with an argument is never a misfire.

The **argument** is whatever the user typed after `/personas` (for `/personas off contrarian` the argument is `off contrarian`; for a bare `/personas` it's empty). Read it from their message.

**`personas-ctl.js` is the ONLY writer** of state and persona files — always go through it; never hand-edit `~/.claude/.personas-active` or persona files yourself. Relay the CLI's output.

## Running the CLI

The CLI ships inside the plugin. Locate and run it with this self-contained form (works regardless of environment — no `${CLAUDE_PLUGIN_ROOT}` needed):

```bash
node "$(ls -t ~/.claude/plugins/cache/*/*/*/hooks/personas-ctl.js 2>/dev/null | head -1)" <verb> [args]
```

Only this plugin ships `personas-ctl.js`; `ls -t … | head -1` resolves the installed copy. Use this exact form for every CLI call below, substituting `<verb> [args]`.

## Dispatch on the FIRST token of the argument

- **empty or `status`** → run `status` and show it (current mode + which personas are active). If nothing is active, also point the user to `/personas list` (all available) and `/personas new` (create one).
- **`list`** → run `list`; show every persona (`*` marks active) with the current mode.
- **`off`** → run `off <name>` where `<name>` is the token after `off` if present (disables just that one), or omit it to clear all. Report.
- **`solo` / `parallel`** → run that verb. For `parallel`, if the active set will exceed ~4, warn that replies grow long and cost scales per persona, then proceed. Report.
- **`new`** → use the **`create-persona`** skill: it runs a guided interview, then writes the persona via the CLI. Pass any name the user already gave.
- **`team [topic]`** → use the **`team`** skill: it casts a debate panel from the user's personas on the topic, runs the rounds, and delivers a moderated synthesis. Pass the topic.
- **`delete <name>`** → run `delete <name>`; relay the result (including any "bundled" / "now active again" message).
- **any other bare token** → a **persona name to activate**: run `enable <token>`. If it succeeds, read the persona body and **adopt that persona for the rest of this turn** so it's active immediately (later turns are kept active by the hook). Read the body with:
  ```bash
  P="$(ls -t ~/.claude/plugins/cache/*/*/*/hooks/personas-ctl.js 2>/dev/null | head -1)"; cat ~/.claude/personas/<token>.md 2>/dev/null || cat "$(dirname "$(dirname "$P")")/personas/<token>.md"
  ```
  (personal override first, then the bundled copy in the plugin's `personas/` dir.) If the CLI says "no such persona", relay that and suggest `/personas list`.
