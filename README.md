<div align="center">

# 🎭 claude-personas

**Give Claude a mindset that sticks.**

Persistent personas for [Claude Code](https://docs.claude.com/en/docs/claude-code): pick a persona and Claude holds it on *every* turn, not just the message you invoked it on. Run one, several in **parallel**, or convene them as a **team** that debates a topic and reports back.

*Built for Claude Code; also installable as [GitHub Copilot custom agents](copilot).*

[![CommitCrimes](https://commitcrimes.dev/badge/zvoque.svg)](https://commitcrimes.dev/u/zvoque)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-d97757)](https://docs.claude.com/en/docs/claude-code)
![Node](https://img.shields.io/badge/node-%E2%89%A518-5fa04e)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

</div>

---

A normal skill or prompt shapes a single reply, then Claude drifts back to default. A persona doesn't. A hook re-asserts it each turn, so `contrarian` keeps pressure-testing you for the whole session. Personas are plain Markdown files you own, and you can author new ones through a guided interview.

## Install

```
/plugin marketplace add zvoque/claude-personas
/plugin install personas@claude-personas
```

No install scripts, no manual `settings.json` edits; the plugin registers its own hooks. **Requires Node** (the hooks and CLI are plain Node.js).

To remove it later: `claude plugin uninstall personas@claude-personas`.

### Using GitHub Copilot instead?

The same personas are packaged as Copilot custom agents (`.agent.md`). They're just files in `~/.copilot/agents/`, so the easiest install is to ask your agent:

> Install the Copilot personas from https://github.com/zvoque/claude-personas: write each `.agent.md` under `copilot/agents/` into my `~/.copilot/agents/` directory, then tell me to reload VS Code.

Manual steps and team setup in [`copilot/`](copilot).

## Quick start

```text
/personas <persona>       # activate one (e.g. contrarian, senior); Claude adopts it and stays that way
/personas off             # back to normal
/personas list            # what's available, what's active, current mode
/personas new             # build your own persona, guided
/personas parallel        # let several run at once
/personas team "Postgres vs Mongo at our scale"   # your personas debate it
```

## Bundled personas

Ships with two to start. Create your own with `/personas new` or drop a file into `~/.claude/personas/`.

| Persona | What it does |
|---|---|
| **`contrarian`** | A sharp, skeptical advisor that pressure-tests every decision instead of validating it: names the load-bearing assumption, fires three concrete counterarguments, proposes a superior alternative, surfaces the blind-spot risk, and ends with a verdict: **Proceed / Reconsider / Stop**. Persists every turn; steps aside for destructive actions and direct questions. |
| **`senior`** | An elite senior developer that assumes nothing: states its understanding and assumptions, reads the project's docs and code before touching anything, reuses existing code over reinventing it (extracting shared functions when it finds duplication), writes compact high-quality code, and keeps docs current. Blunt and terse. Persists every turn; steps aside for destructive actions, direct questions, and urgent fixes. |

## Usage

Everything runs through the **`/personas`** command; there are **no natural-language triggers** (the hooks never parse your prompts for control, so nothing fires by accident). Each row below is a `<verb>` you pass to it, e.g. `/personas off`:

| `<verb>` | Effect |
|---|---|
| `<name>` | Activate a persona. **solo** replaces the current one; **parallel** appends it. |
| `off [name]` | Deactivate everything, or just one persona. |
| `solo` · `parallel` | Switch operating mode (parallel warns past ~4 active). |
| *(empty)* · `status` | Status report: the current mode and which personas are active. |
| `list` | List all available personas (`*` = active). |
| `new` | Create a persona through a guided interview. |
| `team [topic]` | Convene your personas as a debate panel, then synthesize. |
| `delete <name>` | Delete a personal persona (bundled ones are protected). |

## How it works

**Personas are plain data files, not skills**: a Markdown file with `name` + `description` frontmatter and the instructions. Bundled ones ship in the plugin; yours live at `~/.claude/personas/<name>.md` and override a bundled one of the same name.

| Event | Hook | What it does |
|---|---|---|
| `UserPromptSubmit` | `personas-tracker.js` | Re-injects the active persona(s) every turn; that's what makes them stick. Self-suppresses on `/personas` turns so commands run clean. |
| `SessionStart` | `personas-activate.js` | Injects the active persona(s) before the first prompt of a new or resumed session. |

`personas-ctl.js` is the **sole writer** of state and persona files; the command and hooks both go through it. State lives at `~/.claude/.personas-active`.

Injection defaults to the **full** persona body each turn. Set `PERSONAS_TERSE=1` for a short re-assertion instead; validate it holds the persona over a long session first.

## Team debates

`/personas team [topic]` turns your personas into a panel that argues a question. Claude acts as **moderator**: casts the panel, runs the rounds, and hands you a synthesis. Your active personas are **auto-paused** for the duration so they can't bias the moderator, then restored when it's done. Your enabled set and solo/parallel mode are never touched (and if a debate ever dies before cleanup, the pause self-heals on its own; it auto-expires, no restart needed).

1. **Cast the roster.** You pick which personas debate (your currently-active ones are pre-selected). The panel is independent of solo/parallel mode; convening a team doesn't change what's active.
2. **Fill the gaps (auto-cast).** A debate is only useful if the sides genuinely disagree. If your picks are too aligned, or one is a pure *style* with no stance to argue, it offers to **auto-cast** extra debaters drawn for the topic (a skeptic, an opposing stakeholder) to create real friction. These are ephemeral: used for this debate only, never saved. Want to keep one? `/personas new`.
3. **They argue.** Each debater is spawned as its own agent, and they go at it via native inter-agent messaging (opening positions, direct clashes, a pressure round) rather than one model puppeting every side.
4. **You get a synthesis.** Key tensions, where they converged, the strongest point each side landed, what the answer depends on, and a verdict.

**Requires agent-teams support.** The full version spawns real sub-agents (Claude Code's agent teams). Where that isn't available it falls back to a single-context role-play of the same rounds; still useful, just less independent. This plugin's own personas pause automatically during the debate; for the cleanest result, also pause *other* persona plugins ([caveman](https://github.com/JuliusBrussee/caveman), [ponytail](https://github.com/DietrichGebert/ponytail)); it can only control its own.

## Adding a persona

Fastest: `/personas new`, a guided interview that drafts the persona and writes it for you. Or by hand, drop this at `~/.claude/personas/<name>.md`:

```markdown
---
name: <name>
description: <short description>
---

<persona instructions, written as if addressed to Claude>
```

The hooks pick it up immediately, no reinstall. To contribute a bundled persona, add it under `plugins/personas/personas/` and open a PR.

## Coexistence with other plugins

`claude-personas` uses isolated state (`.personas-active`) and its own `/personas` namespace, and never edits `settings.json`. It stacks additively with other persona/lifecycle plugins ([caveman](https://github.com/JuliusBrussee/caveman), [ponytail](https://github.com/DietrichGebert/ponytail)); when they're active too, all their rules apply alongside these. For a clean `/personas team` debate, pause the others; this plugin only guarantees *its own* persona is suppressed on the moderator turn.

## Credits

Inspired by [caveman](https://github.com/JuliusBrussee/caveman), the persona-mode plugin that pioneered the hook-driven "stay in character every turn" pattern this builds on. `claude-personas` generalizes it: any number of user-defined personas, solo / parallel / team modes, and a guided creator.

## More Claude Code plugins

Other plugins I've built, same philosophy: low-friction, safe, and they never touch your `settings.json`.

- **[passive-adr](https://github.com/zvoque/passive-adr)**: decision memory. It watches for architecturally-significant choices (made by you or the agent), records each as an ADR with its rationale, and feeds them back into every future session so settled decisions are honored instead of silently reversed. No prompts; a background sweep does it at session end.
- **[groundskeeper](https://github.com/zvoque/groundskeeper)**: skill-set housekeeping. It tracks which skills you actually invoke, flags the ones that have gone cold, and helps you reversibly prune the unused ones. Zero token cost during normal work; speaks up at most once a week, and only when something's gone stale.
- **[wtf-claude](https://github.com/zvoque/wtf-claude)**: a read-only post-mortem for when a session gets messy. Run `/wtf` and it reconstructs what the agent tried, what actually changed, what broke, what it guessed, and exactly what to do next. Never runs destructive git; it only diagnoses.

## License

[MIT](LICENSE)
