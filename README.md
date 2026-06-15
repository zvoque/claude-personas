# claude-modes

Persistent **persona modes** for [Claude Code](https://docs.claude.com/en/docs/claude-code) — personas that stay active on *every* turn until you switch them off.

A normal skill only applies to the turn it's invoked on; the next message, Claude is back to default. `modes` fixes that with two hooks that re-assert the active persona on every prompt, so a mode like `contrarian` keeps challenging you for the whole conversation until you say `stop contrarian`.

Ships one mode today:

- **`contrarian`** — a sharp, skeptical advisor that pressure-tests every decision, plan, or claim instead of validating it. Names the load-bearing assumption, fires three concrete counterarguments, proposes a superior alternative, surfaces the blind-spot risk, and ends with a verdict: **Proceed / Reconsider / Stop**. (It steps aside for genuinely destructive or clarifying requests.)

## Install

```
/plugin marketplace add zvoque/claude-modes
/plugin install modes@claude-modes
```

That's it — no install script, no `settings.json` edits. The plugin registers its own hooks. Start a new session, or just send your next prompt; the `UserPromptSubmit` hook is live immediately.

**No runtime dependencies.** The hooks are plain **bash + awk** — no Node, `jq`, or Python — so they run on every Claude Code install method (npm *or* the native binary, where `node` isn't guaranteed on `PATH`). bash is the only interpreter Claude Code guarantees for hooks.

## Usage

| Type this | Effect |
|---|---|
| `/contrarian` or `contrarian mode` | activate — persona applies from this turn on |
| `/contrarian off` or `stop contrarian` | deactivate contrarian |
| `normal mode` | deactivate whatever mode is active |

Triggers are case-insensitive. Deactivation is checked before activation, so `stop contrarian` never reads as "start". Natural-language triggers (`contrarian mode`, `stop contrarian`) only fire for a mode that actually exists, so ordinary phrases like "in CSS, normal mode means…" won't trip it — except `normal mode`, which is treated as a global off when it's the whole message.

## How it works

| Event | Hook | What it does |
|---|---|---|
| `UserPromptSubmit` | `modes-tracker.sh` | Runs every prompt. Detects on/off triggers, manages the active-mode flag at `~/.claude/.modes-active`, and while a mode is active re-injects the persona each turn via `hookSpecificOutput.additionalContext`. Re-injecting every turn is what makes the persona persist; on "off" it stops re-asserting and injects a one-time override telling Claude to drop the persona. |
| `SessionStart` | `modes-activate.sh` | Injects the persona up front on session start / resume / clear / compact when a mode is already active, so it's in context before your first prompt. |

- **`modes-lib.sh`** — shared core (bash + awk): flag I/O, mode-name validation (path-traversal guard), mode-skill resolution, persona reading (YAML frontmatter stripped before injection), and JSON-escaped context emission.
- **`skills/<mode>/SKILL.md`** — the single source of truth for each persona. Because it's a real skill, `/<mode>` also works as a one-shot native invocation; the hooks read the same file for persistence.

Every hook swallows all errors and exits 0 — it can never block a prompt or a session start. The active mode is a single flag at `~/.claude/.modes-active` (user-level, so it persists across projects). Set `MODES_DEBUG=1` in your environment to log hook decisions to `~/.claude/.modes-debug.log`.

## Adding a new mode

A mode is just a skill whose frontmatter declares `mode: true`. The tracker dispatches **any** mode name dynamically — **you never edit a hook or `hooks.json` to add one.** There are two ways to add one, depending on whether it's just for you or you want to ship it.

### A. Personal mode (just for you — no fork)

Drop a skill into your user skills directory:

```
~/.claude/skills/<name>/SKILL.md
```

```markdown
---
name: <name>
description: <when Claude should offer this skill>
mode: true
---

<persona instructions — written as if addressed to Claude>
```

The hooks resolve modes from **both** the installed plugin **and** `~/.claude/skills`, so a mode you drop here works immediately — activate with `/<name>` or `<name> mode`, turn off with `stop <name>`. Nothing to reinstall; the installed marketplace plugin stays untouched.

### B. Bundled mode (ship it in this repo)

Add the skill to the plugin and open a PR:

```
plugins/modes/skills/<name>/SKILL.md
```

Same frontmatter as above. Then `bash tests/run.sh` to confirm it loads, commit, and push. Users pick it up with `/plugin update`. (A bundled mode of the same name wins over a personal one.)

### Rules for either path

- Frontmatter **must** include `mode: true`. Without it the skill still works as a one-shot `/<name>`, but it won't *persist* — the hooks ignore any skill not marked as a mode, so ordinary skills can never be hijacked into a persistent persona.
- Mode names must be lowercase, start with a letter or digit, and use only `a–z`, `0–9`, and `-`.
- Write the body as instructions addressed to Claude (see [`contrarian/SKILL.md`](plugins/modes/skills/contrarian/SKILL.md) for a worked example). Give it a **persistence** clause and an **off** clause so the persona knows it's meant to stick and when to stand down.

## Coexistence with the caveman plugin

If you also run the [caveman](https://github.com/) persona plugin (the one this is modeled on), the two are independent and additive: `modes` uses the flag `~/.claude/.modes-active`, caveman uses `~/.claude/.caveman-active`, and neither touches the other. Both emit `SessionStart` context, so both rulesets stack when both are on. caveman is not required.

## Caveat

Whether an unregistered slash command's raw text reaches the `UserPromptSubmit` hook is undocumented in Claude Code. It doesn't matter here: `/contrarian` is a real skill (so it loads natively even if the hook never sees the text), and the natural-language triggers always pass through. If you add a mode whose name collides with a built-in slash command, prefer the natural-language trigger (`<name> mode`).

## Development

```
bash tests/run.sh
```

The suite runs the hooks against a throwaway sandbox `HOME` (your real `~/.claude` is never touched) and verifies activation, persistence, `SessionStart` resume, deactivation, the `normal mode` global off, false-positive guards, path-traversal rejection, and the personal-mode (`~/.claude/skills`) fallback.

## License

MIT
