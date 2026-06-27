# Personas for GitHub Copilot

The same personas, packaged as **GitHub Copilot custom agents** (`.agent.md`). Unlike the Claude Code plugin, persistence is native here: Copilot re-applies the selected agent every turn, so there's no hook and nothing to install. These are just two files.

## Install

A persona is one `.agent.md` file in `~/.copilot/agents/` (the folder Copilot scans). Drop them in, reload, done.

**Easiest: ask your agent.** Paste this into Copilot (or any coding agent):

> Install the Copilot personas from https://github.com/zvoque/claude-personas: for each `.agent.md` file under `copilot/agents/`, write it into my `~/.copilot/agents/` directory (create the directory if needed). Then tell me to reload VS Code.

**Manual.** From a clone of this repo:

```sh
mkdir -p ~/.copilot/agents
cp copilot/agents/*.agent.md ~/.copilot/agents/
```

Then reload VS Code (**Developer: Reload Window**) and pick the agent from the dropdown in a new Copilot chat.

**For a team.** Commit the `.agent.md` files into a repo's `.github/agents/` instead. Everyone who opens that repo gets them automatically, no per-person install.

## Bundled agents

| Agent | What it does |
|---|---|
| **Senior** | Reads your code and docs before writing, reuses code instead of reinventing it, assumes nothing, writes compact code, keeps docs current. Blunt and terse. |
| **Contrarian** | Pressure-tests every decision instead of validating it: load-bearing assumption, three counterarguments, a superior alternative, the blind-spot risk, and a verdict (Proceed / Reconsider / Stop). |

## What's different from the Claude version

Copilot custom agents are single-select and persistent-by-platform, so the Claude plugin's `parallel`, `team` debates, and `/personas` command surface don't carry over. These files are the personas themselves, adapted: the Claude-specific bits (the persistence preamble, `/personas off`, caveman interaction) are stripped because Copilot doesn't need them.

> **Maintainer note:** these `.agent.md` files are hand-maintained, not generated. If you edit a persona in [`../plugins/personas/personas/`](../plugins/personas/personas), update its `.agent.md` here too, or they drift.
