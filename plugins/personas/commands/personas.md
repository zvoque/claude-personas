---
description: Manage persona modes -- activate, switch solo/parallel, create, list, delete, or convene a team debate.
argument-hint: "[<name> | list | off [name] | solo | parallel | new | team [topic] | delete <name>]"
allowed-tools: Read, Bash(node:*)
---

You are the `/personas` control surface. The argument is: `$ARGUMENTS`

`personas-ctl.js` is the ONLY writer of state and persona files -- always go through it; never hand-edit `~/.claude/.personas-active` or persona files yourself. Relay the CLI's output.

Dispatch on the FIRST token of `$ARGUMENTS`:

- empty or `list` -> run `node "${CLAUDE_PLUGIN_ROOT}/hooks/personas-ctl.js" list` and show output.
- `off` -> run `node "${CLAUDE_PLUGIN_ROOT}/hooks/personas-ctl.js" off <name>` where `<name>` is the token after `off` in `$ARGUMENTS` if present (disables one), or omit it to clear all. Report.
- `solo` / `parallel` -> run the CLI with that verb. For `parallel`, if the active set will exceed ~4, warn that replies grow long and cost scales per persona, then proceed. Report.
- `new` -> use the `create-persona` skill: run its guided interview, then it writes the persona via the CLI. Pass any name the user already gave.
- `team [topic]` -> use the `team` skill: it casts a debate panel from your personas on the topic, runs the rounds, and delivers a moderated synthesis. Pass the topic from `$ARGUMENTS`.
- `delete <name>` -> run the CLI `delete <name>`; relay the result (including any "bundled" / "now active again" message).
- any other bare token -> a **persona name to activate**: run `node "${CLAUDE_PLUGIN_ROOT}/hooks/personas-ctl.js" enable <token>`. If it succeeds, **read the persona file (`~/.claude/personas/<token>.md`, else `${CLAUDE_PLUGIN_ROOT}/personas/<token>.md`) and adopt that persona for the rest of this turn**, so it's active immediately (later turns are kept active by the hook). If the CLI says "no such persona", relay that and suggest `/personas list`.
