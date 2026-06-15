# claude-personas

Persistent personas for [Claude Code](https://docs.claude.com/en/docs/claude-code) -- personas that stay active on every turn until you switch them off.

## Install

```
/plugin marketplace add zvoque/claude-personas
/plugin install personas@claude-personas
```

No install scripts, no manual `settings.json` edits. The plugin registers its own hooks. Start a new session (or just send your next prompt) and the hooks are live.

**Requires Node.** The hooks and CLI are plain Node.js scripts. bash is used only by the test harness.

## Usage

Control is via the `/personas` command. There are no natural-language triggers; the hooks never parse prompts for control.

| Command | Effect |
|---|---|
| `/personas <name>` | Activate a persona. In solo mode, replaces the current one. In parallel mode, appends it. |
| `/personas off` | Deactivate all active personas. |
| `/personas off <name>` | Deactivate one specific persona. |
| `/personas solo` | Switch to solo mode (only one persona active at a time). |
| `/personas parallel` | Switch to parallel mode (multiple personas active; a soft warning fires past ~4). |
| `/personas list` | List available personas; active ones are marked with `*`. Shows current mode. |
| `/personas delete <name>` | Delete a personal persona. Refuses to delete bundled-only personas. |
| `/personas new` | Create a persona through a guided interview. |
| `/personas team [topic]` | Convene your personas as a debate panel on a topic, then synthesize. |

## How it works

**Personas are plain data files, not skills.** Each persona is a Markdown file with `name` and `description` in its frontmatter followed by the persona instructions. Bundled personas live at `plugins/personas/personas/<name>.md`. Personal personas live at `~/.claude/personas/<name>.md`. A personal persona with the same name as a bundled one overrides it.

**Two hooks manage persistence:**

| Event | Hook | What it does |
|---|---|---|
| `UserPromptSubmit` | `personas-tracker.js` | Runs on every prompt. While a persona is active, re-injects the full persona body into `hookSpecificOutput.additionalContext`. That re-injection each turn is what makes the persona stick. The hook self-suppresses on `/personas` command turns so the command itself runs cleanly. |
| `SessionStart` | `personas-activate.js` | Injects the active persona(s) on turn 0 of a new or resumed session, so the persona is in context before the first prompt. |

**`personas-ctl.js` is the sole writer of state and persona files.** Both the `/personas` command and the hooks go through it. State is stored at `~/.claude/.personas-active` (JSON).

**Default injection is the full persona body each turn.** Set `PERSONAS_TERSE=1` in your environment to switch to a short re-assertion instead. Validate that terse mode holds the persona over a long session before relying on it.

## Adding a persona

The fastest path is `/personas new` -- a guided interview that writes the persona for you. Or drop a Markdown file into `~/.claude/personas/` by hand:

```
~/.claude/personas/<name>.md
```

Frontmatter must include `name` and `description`:

```markdown
---
name: <name>
description: <short description>
---

<persona instructions -- written as if addressed to Claude>
```

The hooks pick up personal personas immediately. No reinstall needed.

To contribute a bundled persona, add the file to `plugins/personas/personas/<name>.md` and open a PR.

## Coexistence with other plugins

`claude-personas` uses isolated state (`.personas-active`) and its own `/personas` namespace; it never edits `settings.json`. It stacks additively with other persona or lifecycle plugins (caveman, ponytail, etc.) -- that is the platform's nature. When those other plugins are also active, their rules and this plugin's rules all apply.

For a clean `/personas team` debate, you will want to pause other persona plugins for that session. This plugin only guarantees that its own persona injection is suppressed on the moderator turn; it cannot silence other plugins.

## Upgrading from v1 (claude-modes)

v2 (this repo) supersedes `claude-modes`. The hook architecture changed from bash to Node, and the `/personas` command replaces the old natural-language triggers and mode-specific slash commands.

v2 never edits `settings.json`, so leftover v1 entries will not break anything, but to keep things tidy remove them by hand:

1. Open `~/.claude/settings.json` and delete any hook entries that reference `modes-*.js` or `modes-*.sh`.
2. Delete `~/.claude/hooks/modes-tracker.js`, `modes-activate.js`, `modes-lib.js`, and `patch-settings.js` if they exist.

Then reinstall as described above.

## License

MIT
