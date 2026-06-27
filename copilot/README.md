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
| **Team** | Convenes your personas as a panel and moderates them: a quick **panel** of independent takes, or a full **debate** (opening, clash rounds, synthesis with a verdict). Casts for real disagreement, not theater. |
| **Creator** | Authors a new persona for you: a short interview, a draft you approve, then it writes the `.agent.md` file. The easy way to make your own. |

## Make your own

**Easiest: use the Creator agent.** Pick **Creator** from the dropdown and describe the persona you want. It interviews you, drafts it, and writes the file for you.

By hand, a persona is just a file. Create `~/.copilot/agents/<name>.agent.md`:

```markdown
---
description: Shown as placeholder text in the chat input.
name: Analyst
---
You are a data-driven analyst. Lead with the numbers...
```

Reload VS Code (**Developer: Reload Window**) and it appears in the agent dropdown. That's the whole process.

### Add it to the Team

The **Team** agent only convenes personas it knows about. Two ways to include yours:

- **Permanent:** add its `name` to the `agents:` list in [`agents/team.agent.md`](agents/team.agent.md):
  ```yaml
  agents: ['Senior', 'Contrarian', 'Analyst']
  ```
- **One-off:** just name it when you start a debate ("debate this with Senior and Analyst"). Team convenes any agent you name that exists.

Names must match the `name:` field in each persona file, not the filename.

## What's different from the Claude version

Copilot custom agents are single-select and persistent-by-platform. So persistence is free (no hook), and a single persona just works. The Claude plugin's `team`/`parallel` are reproduced by the **Team** agent, which orchestrates the others rather than running them ambiently. What doesn't carry over is the `/personas` command surface and live mode-switching (`off`, `suspend`/`resume`); you switch agents from the dropdown instead.

The persona files are the Claude personas, adapted: the Claude-specific bits (the persistence preamble, `/personas off`, caveman interaction) are stripped because Copilot doesn't need them.

> **Maintainer note:** these `.agent.md` files are hand-maintained, not generated. If you edit a persona in [`../plugins/personas/personas/`](../plugins/personas/personas), update its `.agent.md` here too, or they drift.
